import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'server_config.dart';


class OtherItemData extends ChangeNotifier {
  static const _storageKey = 'other_item_data';

  // =====================␊
  // デフォルトデータ␊
  // =====================␊
  static final List<Map<String, dynamic>> _defaultItems = [
    {'category': '本指名料', 'name': '本指名', 'price': 3000},
    {'category': '同伴料', 'name': '同伴', 'price': 3000},
    {'category': '場内指名料', 'name': '場内指名', 'price': 3000},
    {'category': 'チャーム', 'name': 'チャーム', 'price': 1500},
  ];

  List<Map<String, dynamic>> items = [];

  OtherItemData() {
    load();
  }

  // =====================␊
  // ロード（最重要）␊
  // =====================␊
  Future<void> load() async {
    await _loadFromLocal();
    await _loadFromServer();
    if (items.isEmpty) {
    items = _deepCopy(_defaultItems);
  }
    notifyListeners();
    await save();
  }

  // =====================␊
  // 保存␊
  // =====================␊
  Future<void> save() async {
    await _saveLocal();
    await _saveToServer();
  }

  // ---------------------␊
  // ローカル␊
  // ---------------------␊
  Future<void> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      items = _deepCopy(_defaultItems);
      return;
    }

    try {
      items = List<Map<String, dynamic>>.from(jsonDecode(raw));
    } catch (_) {
      items = _deepCopy(_defaultItems);
    }
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(items));
  }

  // ---------------------␊
  // サーバー␊
  // ---------------------␊
  Future<void> _loadFromServer() async {
    try {
      final res =
          await http.get(ServerConfig.api('/api/other-items'));
      if (res.statusCode != 200) return;

      final decoded = jsonDecode(res.body);
      final list =
          List<Map<String, dynamic>>.from(decoded['items'] ?? []);

      if (list.isNotEmpty) {
        items = list;
      }
    } catch (_) {
      // 失敗しても落とさない␊
    }
  }

  Future<void> _saveToServer() async {
    try {
      await http.post(
        ServerConfig.api('/api/other-items'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'items': items}),
      );
    } catch (_) {
      // 無視␊
    }
  }

  // =====================␊
  // カテゴリ一覧␊
  // =====================␊
  List<String> get categories =>
      items.map((e) => e['category'] as String).toSet().toList();

  // =====================␊
  // カテゴリ操作␊
  // =====================␊
  void addCategory(String name) {
    final n = name.trim();
    if (n.isEmpty) return;

    items.add({'category': n, 'name': '', 'price': 0});
    notifyListeners();
    save();
  }

  void renameCategory(String oldName, String newName) {
    final n = newName.trim();
    if (n.isEmpty) return;

    for (final item in items) {
      if (item['category'] == oldName) {
        item['category'] = n;
      }
    }

    notifyListeners();
    save();
  }

  void removeCategory(String name) {
    items.removeWhere((i) => i['category'] == name);
    notifyListeners();
    save();
  }

  // =====================␊
  // 商品操作␊
  // =====================␊
  void addItem(String category, String name, int price) {
    final n = name.trim();
    if (n.isEmpty || price <= 0) return;

    items.add({'category': category, 'name': n, 'price': price});
    notifyListeners();
    save();
  }

  void renameItem(Map<String, dynamic> item, String newName) {
    final n = newName.trim();
    if (n.isEmpty) return;

    item['name'] = n;
    notifyListeners();
    save();
  }

  void updatePrice(Map<String, dynamic> item, int price) {
    if (price <= 0) return;

    item['price'] = price;
    notifyListeners();
    save();
  }

  void removeItem(Map<String, dynamic> item) {
    items.remove(item);
    notifyListeners();
    save();
  }

  // =====================␊
  // 並び替え␊
  // =====================␊
  void reorderItemsInCategory(
    String category,
    int oldIndex,
    int newIndex,
  ) {
    if (newIndex > oldIndex) newIndex--;

    final list =
        items.where((i) => i['category'] == category).toList();

    if (oldIndex < 0 ||
        oldIndex >= list.length ||
        newIndex < 0 ||
        newIndex >= list.length) return;

    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);

    items.removeWhere((i) => i['category'] == category);
    items.addAll(list);

    notifyListeners();
    save();
  }

  void reorderCategories(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;

    final cats = categories.toList();
    if (oldIndex < 0 ||
        oldIndex >= cats.length ||
        newIndex < 0 ||
        newIndex >= cats.length) return;

    final moved = cats.removeAt(oldIndex);
    cats.insert(newIndex, moved);

    final reordered = <Map<String, dynamic>>[];
    for (final c in cats) {
      reordered.addAll(items.where((i) => i['category'] == c));
    }

    items = reordered;
    notifyListeners();
    save();
  }




  static List<Map<String, dynamic>> _deepCopy(
    List<Map<String, dynamic>> src,
  ) =>
      src.map((e) => Map<String, dynamic>.from(e)).toList();
}