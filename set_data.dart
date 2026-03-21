import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../data/server_config.dart';

class SetData extends ChangeNotifier {
  static const _storageKey = 'set_data';

  final List<Map<String, dynamic>> _sets = [];

  List<Map<String, dynamic>> get sets => _sets;

  SetData() {
    load();
  }

  // =========================
  // ロード（最重要）
  // =========================
  Future<void> load() async {
    await _loadFromLocal();
    await _loadFromServer();
    _ensureFixedSets();
    notifyListeners();
    await save();
  }

  // =========================
  // 保存
  // =========================
  Future<void> save() async {
    await _saveLocal();
    await _saveToServer();
  }

  // -------------------------
  // ローカル
  // -------------------------
  Future<void> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;

    try {
      final decoded = jsonDecode(raw);
      _sets
        ..clear()
        ..addAll(List<Map<String, dynamic>>.from(decoded));
    } catch (_) {
      _sets.clear();
    }
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_sets));
  }

  // -------------------------
  // サーバー
  // -------------------------
  Future<void> _loadFromServer() async {
    try {
      final res = await http.get(ServerConfig.api('/api/sets'));
      if (res.statusCode != 200) return;

      final decoded = jsonDecode(res.body);
      final list =
          List<Map<String, dynamic>>.from(decoded['sets'] ?? []);

      _sets
        ..clear()
        ..addAll(list);
    } catch (_) {
      // 無視
    }
  }

  Future<void> _saveToServer() async {
    try {
      await http.post(
        ServerConfig.api('/api/sets'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sets': _sets}),
      );
    } catch (_) {
      // 無視
    }
  }

  // =========================
  // ★ 3セット固定保証
  // =========================
  void _ensureFixedSets() {
    _ensureSet('通常');
    _ensureSet('案内所');
    _ensureSet('VIP');
  }

  void _ensureSet(String name) {
    final found = _sets.any((s) => s['name'] == name);
    if (found) return;

    _sets.add(_newSet(name));
  }

  // =========================
  // 編集（UIが使う）
  // =========================
  void addItem(
    Map<String, dynamic> set,
    String sectionKey,
    String label,
    int price,
  ) {
    final l = label.trim();
    if (l.isEmpty) return;

    final sections = set['sections'] as Map<String, dynamic>;
    final list =
        (sections[sectionKey] as List?) ?? <Map<String, dynamic>>[];
    sections[sectionKey] = list;

    list.add({'label': l, 'price': price});
    notifyListeners();
    save();
  }

  void updateItem(
    Map<String, dynamic> set,
    String sectionKey,
    Map<String, dynamic> item,
    String newLabel,
    int newPrice,
  ) {
    final l = newLabel.trim();
    if (l.isEmpty) return;

    item['label'] = l;
    item['price'] = newPrice;
    notifyListeners();
    save();
  }

  void removeItem(
    Map<String, dynamic> set,
    String sectionKey,
    Map<String, dynamic> item,
  ) {
    final sections = set['sections'] as Map<String, dynamic>;
    final list = (sections[sectionKey] as List?) ?? [];
    list.remove(item);
    notifyListeners();
    save();
  }

  // =========================
  // 内部：新規セット雛形
  // =========================
  static Map<String, dynamic> _newSet(String name) {
    return {
      'name': name,
      'sections': {
        'normal': <Map<String, dynamic>>[],
        'agency': <Map<String, dynamic>>[],
        'extension': <Map<String, dynamic>>[],
      },
    };
  }
}
