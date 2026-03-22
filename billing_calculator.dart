import '../model/shared_order.dart';   // OrderItem
import '../state/order_state.dart';    // OrderLine

/// ===============================
/// 請求計算結果
/// ===============================
class BillingResult {
  final int subtotal;       // 課税対象小計
  final int nonTaxSubtotal; // 非課税小計
  final int taxAmount;      // 消費税
  final int serviceAmount;  // サービス料
  final int total;          // 最終合計（10円未満切捨）

  const BillingResult({
    required this.subtotal,
    required this.nonTaxSubtotal,
    required this.taxAmount,
    required this.serviceAmount,
    required this.total,
  });
}

/// ===============================
/// 請求計算ロジック
/// ===============================
class BillingCalculator {
  static const String _excludedFromBillingCategory = 'etc';
  /// デフォルト率
  static const double defaultTaxRate = 0.10;      // 10%
  static const double defaultServiceRate = 0.25;  // 25%

  // ===============================
  // OrderItem 用（ゲスト・伝票）
  // ===============================
  static BillingResult calculate(
    List<OrderItem> items, {
    double taxRate = defaultTaxRate,
    double serviceRate = defaultServiceRate,
  }) {
    int taxableSubtotal = 0;
    int nonTaxableSubtotal = 0;
 for (final item in items) {
      if (_isExcludedFromBilling(item.category)) continue;
      final lineTotal = item.price * item.qty;

      if (_isTaxableItem(item)) {
        taxableSubtotal += lineTotal;
      } else {
        nonTaxableSubtotal += lineTotal;
      }
    }

    return _buildResult(
      taxableSubtotal,
      nonTaxableSubtotal,
      taxRate,
      serviceRate,
    );
  }

  // ===============================
  // OrderLine 用（オーナー画面）
  // ===============================
  static BillingResult calculateFromLines(
    List<OrderLine> lines, {
    double taxRate = defaultTaxRate,
    double serviceRate = defaultServiceRate,
  }) {
    int taxableSubtotal = 0;
    int nonTaxableSubtotal = 0;

     for (final line in lines) {
      if (_isExcludedFromBilling(line.category)) continue;
      final lineTotal = line.price * line.qty;

      if (_isTaxableLine(line)) {
        taxableSubtotal += lineTotal;
      } else {
        nonTaxableSubtotal += lineTotal;
      }
    }

    return _buildResult(
      taxableSubtotal,
      nonTaxableSubtotal,
      taxRate,
      serviceRate,
    );
  }

  // ===============================
  // 共通：合計計算
  // ===============================
  static BillingResult _buildResult(
    int taxableSubtotal,
    int nonTaxableSubtotal,
    double taxRate,
    double serviceRate,
  ) {
    // ① 消費税（課税対象合計に対して）
    final tax = (taxableSubtotal * taxRate).floor();

    // ② 税込み金額
    final taxedTotal = taxableSubtotal + tax;

    // ③ サービス料（税込み金額に対して）
    final service = (taxedTotal * serviceRate).floor();

    // ④ 合計
    final rawTotal = nonTaxableSubtotal + taxableSubtotal + tax + service;

    // ⑤ 10円未満切り捨て
    final finalTotal = (rawTotal ~/ 10) * 10;

    return BillingResult(
      subtotal: taxableSubtotal,
      nonTaxSubtotal: nonTaxableSubtotal,
      taxAmount: tax,
      serviceAmount: service,
      total: finalTotal,
    );
  }

  // ===============================
  // 課税判定（OrderItem）
  // ===============================
  static bool _isTaxableItem(OrderItem item) {
    // セットは「案内所」だけ非課税
    if (item.category == 'セット' && item.brand == '案内所') {
      return false;
    }

    // それ以外は課税
    return true;
  }

  // ===============================
  // 課税判定（OrderLine）
  // ===============================
  static bool _isTaxableLine(OrderLine line) {
    // セットは「案内所」だけ非課税
    if (line.category == 'セット' && line.brand == '案内所') {
      return false;
    }

    // それ以外は課税
    return true;
 }

 static bool _isExcludedFromBilling(String category, [String subCategory = '']) {
    final excluded = _excludedFromBillingCategory.toLowerCase();
    return category.trim().toLowerCase() == excluded ||
        subCategory.trim().toLowerCase() == excluded;
  }
}
