
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../data/server_config.dart';

class Promo {
  final String id;
  String title;
  String sub;
  String imageUrl;
  final double focalX; // -1.0(left) ~ 1.0(right)
  final double focalY; // -1.0(top) ~ 1.0(bottom)
  final String linkType; // none / category
  final String? category;
  final String? brand;
  Promo({
    required this.id,
      required this.title,
    required this.sub,
    required this.imageUrl,
    this.focalX = 0,
    this.focalY = 0,
    this.linkType = 'none',
    this.category,
     this.brand,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
         'sub': sub,
        'imageUrl': imageUrl,
        'focalX': focalX,
        'focalY': focalY,        'linkType': linkType,
        'category': category,
        'brand': brand,
      };

  static Promo fromJson(Map<String, dynamic> j) => Promo(
        id: j['id'] ?? '',
        title: j['title'] ?? '',
        sub: j['sub'] ?? '',
        imageUrl: j['imageUrl'] ?? '',
        focalX: (j['focalX'] as num?)?.toDouble() ?? 0,
        focalY: (j['focalY'] as num?)?.toDouble() ?? 0,
        linkType: j['linkType'] ?? 'none',
        category: j['category'],
         brand: j['brand'],
      );
}

class PromoState extends ChangeNotifier {
  static const _keyTop = 'promos_top_v2';
  static const _keyBottom = 'promos_bottom_v2';

  final List<Promo> _top = [];
  final List<Promo> _bottom = [];

  List<Promo> get top => List.unmodifiable(_top);
  List<Promo> get bottom => List.unmodifiable(_bottom);

  PromoState() {
    load();
  }

  // =====================
  // 起動時ロード（正本はサーバー）
  // =====================
  Future<void> load() async {
    await _loadFromServer();
    await _saveLocal(); // キャッシュ
    notifyListeners();
  }

  // =====================
  // 保存
  // =====================
  Future<void> save() async {
    await _saveLocal();
    await _saveToServer();
  }

  // ---------------------
  // ローカル（キャッシュ）
  // ---------------------
  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyTop,
      jsonEncode(_top.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _keyBottom,
      jsonEncode(_bottom.map((e) => e.toJson()).toList()),
    );
  }

  // ---------------------
  // サーバー
  // ---------------------
  Future<void> _loadFromServer() async {
    try {
      final res = await http.get(ServerConfig.api('/api/promos'));
      if (res.statusCode != 200) return;

      final decoded = jsonDecode(res.body);
      final t = decoded['top'] as List? ?? [];
      final b = decoded['bottom'] as List? ?? [];

      _top
        ..clear()
        ..addAll(t.map((e) => Promo.fromJson(Map<String, dynamic>.from(e))));
      _bottom
        ..clear()
        ..addAll(b.map((e) => Promo.fromJson(Map<String, dynamic>.from(e))));
    } catch (_) {}
  }

  Future<void> _saveToServer() async {
    try {
      await http.post(
        ServerConfig.api('/api/promos'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'top': _top.map((e) => e.toJson()).toList(),
          'bottom': _bottom.map((e) => e.toJson()).toList(),
        }),
      );
    } catch (_) {}
  }
  // =====================
  // CRUD
  // =====================
  Future<void> addTop(Promo p) async {
    _top.add(p);
    await save();
    notifyListeners();
  }

  Future<void> addBottom(Promo p) async {
    _bottom.add(p);
    await save();
    notifyListeners();
  }

  Future<void> updateTop(Promo p) async {
    final i = _top.indexWhere((x) => x.id == p.id);
    if (i == -1) return;
    _top[i] = p;
    await save();
    notifyListeners();
  }
  Future<void> updateBottom(Promo p) async {
    final i = _bottom.indexWhere((x) => x.id == p.id);
    if (i == -1) return;
    _bottom[i] = p;
    await save();
    notifyListeners();
  }
  // =====================
  // 削除（★サーバーファイルも削除）
  // =====================
  Future<void> removeTop(String id) async {
    final p = _top.where((x) => x.id == id).cast<Promo?>().firstOrNull;
    _top.removeWhere((x) => x.id == id);
    await save();
    notifyListeners();

    await _deleteServerFileIfNeeded(p);
  }
  Future<void> removeBottom(String id) async {
    final p = _bottom.where((x) => x.id == id).cast<Promo?>().firstOrNull;
    _bottom.removeWhere((x) => x.id == id);
    await save();
    notifyListeners();

    await _deleteServerFileIfNeeded(p);
  }

  Future<void> reorderTop(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _top.removeAt(oldIndex);
    _top.insert(newIndex, item);
    await save();
    notifyListeners();
  }

  Future<void> reorderBottom(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _bottom.removeAt(oldIndex);
    _bottom.insert(newIndex, item);
    await save();
    notifyListeners();
  }

  // =====================
  // サーバーファイル削除
  // =====================
  Future<void> _deleteServerFileIfNeeded(Promo? p) async {
    if (p == null) return;
    if (!p.imageUrl.startsWith('http')) return;

    try {
      final uri = Uri.parse(p.imageUrl);
      await http.post(
        ServerConfig.api('/api/promos/delete-file'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': uri.path}),
      );
    } catch (_) {}
  }
}

// Dart 3 用の簡易 firstOrNull
extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
 