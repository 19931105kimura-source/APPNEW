import 'package:flutter/foundation.dart';

class CartLine {
  final String category;
  final String brand;
  final String label;
  final int price;
  final String printGroup; // ★ 追加
  int qty;

  CartLine({
    required this.category,
    required this.brand,
    required this.label,
    required this.price,
    required this.qty,
    required this.printGroup,
  });

  // ★ 同一商品判定（印刷先は含めない）
  String get key => '$category|$brand|$label|$price';
}

class CartState extends ChangeNotifier {
  final List<CartLine> _lines = [];

  /// cart_side_panel.dart 用
  List<CartLine> get items => List.unmodifiable(_lines);

  /// 互換
  List<CartLine> get lines => List.unmodifiable(_lines);

  int get total {
    int sum = 0;
    for (final l in _lines) {
      sum += l.price * l.qty;
    }
    return sum;
  }

  /// =========================
  /// 追加（ゲスト・共通）
  /// =========================
  void add({
    required String category,
    required String brand,
    required String label,
    required int price,
    String? printGroup,
  }) {
    // ★ ここが最終ルール
    final fixedPrintGroup =
        category == 'キャストドリンク'
            ? 'kitchen'
            : (printGroup ?? 'kitchen');

    final key = '$category|$brand|$label|$price';
    final i = _lines.indexWhere((e) => e.key == key);

    if (i >= 0) {
      _lines[i].qty += 1;
    } else {
      _lines.add(
        CartLine(
          category: category,
          brand: brand,
          label: label,
          price: price,
          qty: 1,
          printGroup: fixedPrintGroup,
        ),
      );
    }
    notifyListeners();
  }

  /// =========================
  /// 数量操作
  /// =========================
  void increment(CartLine line) {
    line.qty += 1;
    notifyListeners();
  }

  void decrement(CartLine line) {
    line.qty -= 1;
    if (line.qty <= 0) {
      _lines.remove(line);
    }
    notifyListeners();
  }

  /// 互換メソッド
  void inc(CartLine line) => increment(line);
  void dec(CartLine line) => decrement(line);

  void remove(CartLine line) {
    _lines.remove(line);
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }
}
