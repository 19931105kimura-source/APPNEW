import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/order_state.dart';
import '../../billing/billing_calculator.dart';
import 'owner_add_order_page.dart';
import '../utils/price_format.dart';



class TableActionSheet extends StatelessWidget {
  final String table;
  const TableActionSheet({super.key, required this.table});

  @override
  Widget build(BuildContext context) {
    final orderState = context.watch<OrderState>();

    final order = orderState.orders
        .where((o) => o.table == table)
        .toList();

     final total = order.isEmpty
        ? 0
        : BillingCalculator.calculateFromLines(order.first.lines).total;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ===== タイトル =====
          Text(
            'テーブル $table',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          // ===== 会計 =====
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '現在の会計：${formatYen(total)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ===== 開始 =====
          ElevatedButton(
            onPressed: () {
              // 将来：開始時刻など
            },
            child: const Text('開始'),
          ),

          // ===== 終了（会計） =====
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: order.isEmpty
                ? null
                : () async {
                    await orderState.completeOrder(order.first.id);
                    Navigator.pop(context);
                  },
            child: const Text('終了（会計）'),
          ),

          // ===== 伝票 =====
          OutlinedButton(
            onPressed: order.isEmpty ? null : () {
              // 将来：伝票PDFなど
            },
            child: const Text('伝票を出す'),
          ),

          // ===== 注文追加 =====
          ElevatedButton(
  onPressed: () {
    Navigator.pop(context); // 中央パネルを閉じる
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerAddOrderPage(table: table),
      ),
    );
  },
  child: const Text('注文を追加'),
),

          // ===== 削除 =====
          TextButton(
            onPressed: order.isEmpty
                ? null
                : () async {
                    final ok = await orderState.removeOrder(order.first.id);
                    if (!ok) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('注文削除の同期に失敗しました。再試行してください。')),
                      );
                      return;
                    }
                    Navigator.pop(context);
                  },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('注文を削除'),
          ),
        ],
      ),
    );
  }
}