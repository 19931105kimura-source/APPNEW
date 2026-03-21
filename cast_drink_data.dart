import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'server_config.dart';
class CastDrinkData extends ChangeNotifier {
  static const _storageKey = 'cast_drinks';

  final List<CastDrinkItem> _items = [];

  List<CastDrinkItem> get items => List.unmodifiable(_items);

  // =========================
  // 初期化（起動時に復元）
  // =========================
  CastDrinkData() {
    load();
  }

  // =========================
  // 保存
  // =========================
  Future<void> save() async {
  final prefs = await SharedPreferences.getInstance();

  final data = _items.map((e) => {
    'name': e.name,
    'price': e.price,
    'strengths': e.strengths,
  }).toList();

  await prefs.setString(_storageKey, jsonEncode(data));

  await saveToServer(); // ★ これを追加
}


  // =========================
  // 読み込み
  // =========================
  Future<void> load() async {
  // ① まずサーバーから読む
  await loadFromServer();

  final prefs = await SharedPreferences.getInstance();
  final json = prefs.getString(_storageKey);
  if (json == null) return;

  final List list = jsonDecode(json);
  _items
    ..clear()
    ..addAll(
      list.map(
        (e) => CastDrinkItem(
          name: e['name'],
          price: e['price'],
          strengths: List<String>.from(e['strengths']),
        ),
      ),
    );

  notifyListeners();
}


  // =========================
  // ドリンク追加
  // =========================
  void addDrink(String name, int price) {
    final n = name.trim();
    if (n.isEmpty || price <= 0) return;

    _items.add(
      CastDrinkItem(
        name: n,
        price: price,
        strengths: ['普通'],
      ),
    );
    notifyListeners();
    save();
  }

  // =========================
  // ドリンク削除
  // =========================
  void removeDrink(CastDrinkItem item) {
    _items.remove(item);
    notifyListeners();
    save();
  }

  // =========================
  // 名前変更
  // =========================
  void renameDrink(CastDrinkItem item, String newName) {
    final n = newName.trim();
    if (n.isEmpty) return;

    item.name = n;
    notifyListeners();
    save();
  }

  // =========================
  // 価格変更
  // =========================
  void updatePrice(CastDrinkItem item, int price) {
    if (price <= 0) return;

    item.price = price;
    notifyListeners();
    save();
  }

  // =========================
  // 濃さ追加
  // =========================
  void addStrength(CastDrinkItem item, String strength) {
    final s = strength.trim();
    if (s.isEmpty) return;
    if (item.strengths.contains(s)) return;

    item.strengths.add(s);
    notifyListeners();
    save();
  }

  // =========================
  // 濃さ削除
  // =========================
  void removeStrength(CastDrinkItem item, String strength) {
    item.strengths.remove(strength);
    notifyListeners();
    save();
  }

  // =========================
  // 並び替え
  // =========================
  void reorderDrinks(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;

    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);

    notifyListeners();
    save();
  }
  Future<void> saveToServer() async {
  try {
    final uri = ServerConfig.api('/api/cast-drinks');

    final body = {
      'items': _items.map((e) => {
        'name': e.name,
        'price': e.price,
        'strengths': e.strengths,
      }).toList(),
    };

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      debugPrint('CastDrink server save failed: ${res.statusCode}');
    }
  } catch (e) {
    debugPrint('CastDrink server save error: $e');
  }
}
Future<void> loadFromServer() async {
  try {
    final uri = ServerConfig.api('/api/cast-drinks');
    final res = await http.get(uri);

    if (res.statusCode != 200) return;

    final List list = jsonDecode(res.body);

    _items
      ..clear()
      ..addAll(
        list.map(
          (e) => CastDrinkItem(
            name: e['name'],
            price: e['price'],
            strengths: List<String>.from(e['strengths']),
          ),
        ),
      );

    notifyListeners();
  } catch (e) {
    debugPrint('CastDrink loadFromServer error: $e');
  }
}

}

// =========================
// モデル
// =========================
class CastDrinkItem {
  String name;
  int price;
  final List<String> strengths;

  CastDrinkItem({
    required this.name,
    required this.price,
    required this.strengths,
  });
}