import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/order_state.dart';
import 'owner_tables_page.dart';
import '../../billing/billing_calculator.dart';
import '../utils/price_format.dart';

class OwnerOrdersPage extends StatelessWidget {
  const OwnerOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final orderState = context.watch<OrderState>();
    final orders = orderState.orders;

    return Scaffold(
      appBar: AppBar(
        title: const Text('注文一覧（管理）'),
        actions: [
          // ★ テーブル別集計へ
          IconButton(
            icon: const Icon(Icons.table_bar),
            tooltip: 'テーブル別集計',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OwnerTablePage(),
                ),
              );
            },
          ),

          // 全削除
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: '全削除',
            onPressed: orders.isEmpty
                ? null
                : () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('全削除'),
                        content:
                            const Text('すべての注文を削除しますか？'),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(context, false),
                            child: const Text('キャンセル'),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.pop(context, true),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await context
                          .read<OrderState>()
                          .clearAll();
                    }
                  },
          ),
        ],
      ),
      body: orders.isEmpty
          ? const Center(child: Text('注文はありません'))
          : ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, idx) {
                final o = orders[idx];
                final billing = BillingCalculator.calculateFromLines(o.lines);
                return Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '席 ${o.table}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(formatYenTruncatedToTen(billing.total)),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                final ok = await context
                                    .read<OrderState>()
                                    .removeOrder(o.id);
                                if (!ok) return;
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          o.createdAt.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const Divider(),
                        ...o.lines.map((l) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                        '${l.brand} / ${l.label}'),
                                  ),
                                  Text('x${l.qty}'),
                                  const SizedBox(width: 12),
                                  Text(
  formatYen(l.price * l.qty),
)

                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}