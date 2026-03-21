import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'server_config.dart';
 // ←後で実IPに変更

class CastData extends ChangeNotifier {
  final List<String> _casts = [];

  List<String> get casts => List.unmodifiable(_casts);

  // ====================␊
  // 初期化（起動時に復元）␊
  // ====================␊
  CastData() {
    load();
  }

  // ====================␊
  // 起動時ロード␊
  // ====================␊
  Future<void> load() async {
    await _loadFromLocal();
    await _loadFromServer();
  }

  // --------------------␊
  // ローカル読み込み␊
  // --------------------␊
  Future<void> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('casts');
    if (list != null) {
      _casts
        ..clear()
        ..addAll(list);
      _sort();
      notifyListeners();
    }
  }

  // --------------------␊
  // サーバー読み込み␊
  // --------------------␊
  Future<void> _loadFromServer() async {
    try {
      final res = await http.get(ServerConfig.api('/api/casts'));
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body);
      final list = List<String>.from(data['casts'] ?? []);

      _casts
        ..clear()
        ..addAll(list);
      _sort();
      await _saveLocal();
      notifyListeners();
    } catch (_) {
      // 失敗しても落とさない␊
    }
  }

  // ====================␊
  // 保存␊
  // ====================␊
  Future<void> save() async {
    await _saveLocal();
    await _saveToServer();
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('casts', _casts);
  }

  Future<void> _saveToServer() async {
    try {
      await http.post(
        ServerConfig.api('/api/casts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'casts': _casts}),
      );
    } catch (_) {
      // 通信失敗でも無視␊
    }
  }
  // ===== 50音順に並び替え（UI用）=====␊
   void sortByKana() {
  _sort();
  notifyListeners();
  save();
}

  // ====================␊
  // 内部：50音順ソート␊
  // ====================␊
  void _sort() {
    _casts.sort((a, b) => a.compareTo(b));
  }

  // ===== 追加 =====␊
  void add(String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    _casts.add(n);
    _sort();
    notifyListeners();
    save();
  }

  // ===== 名前変更 =====␊
  void rename(String oldName, String newName) {
    final n = newName.trim();
    if (n.isEmpty) return;
    final i = _casts.indexOf(oldName);
    if (i == -1) return;
    _casts[i] = n;
    _sort();
    notifyListeners();
    save();
  }

  // ===== 削除 =====␊
  void remove(String name) {
    _casts.remove(name);
    notifyListeners();
    save();
  }

  // ===== 並び替え =====␊
  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final item = _casts.removeAt(oldIndex);
    _casts.insert(newIndex, item);
    notifyListeners();
    save();
  }
}