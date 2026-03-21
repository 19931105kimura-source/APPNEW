import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/price_format.dart';

import '../state/order_state.dart';
import '../../billing/billing_calculator.dart';


class OwnerTableDetailPage extends StatelessWidget {
  final String table;

  const OwnerTableDetailPage({
    super.key,
    required this.table,
  });

     @override
Widget build(BuildContext context) {
  final orderState = context.watch<OrderState>();

  final order = orderState.orderForDisplay(table); 
    final bool isRealtimeOrder =
      order != null && order.id.startsWith('rt_');





    // ★ 会計計算（税・サービス料・切り捨て込み）
   final displayLines = order == null
        ? <OrderLine>[]
        : orderState.aggregateLinesForDisplay(order.lines);
    final billing = order == null
        ? null
        : BillingCalculator.calculateFromLines(order.lines);

    return Scaffold(
      appBar: AppBar(
        title: Text('テーブル $table'),
      ),
      body: order == null
          ? const Center(
              child: Text(
                '注文はありません',
                style: TextStyle(fontSize: 18),
              ),
            )
          : Column(
              children: [
                // =====================
                // 注文一覧
                // =====================
                Expanded(
                  child: ListView.builder(
                    itemCount: displayLines.length,
                    itemBuilder: (context, index) {
                      final line = displayLines[index];
                      return ListTile(
                        title: Text('${line.brand} / ${line.label}'),
                        subtitle: Text(formatYen(line.price)),

                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () {
                                 if (isRealtimeOrder) return; // ★ RTは編集禁止
                                final newQty = line.qty - 1;
                               if (newQty <= 0) {
                                  orderState.removeAggregatedLine(
                                    order.id,
                                    line,
                                  );
                                } else {
                                  orderState.updateAggregatedLineQty(
                                    order.id,
                                    line,
                                    newQty,
                                  );
                                }
                              },
                            ),
                            Text(
                              '${line.qty}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                 if (isRealtimeOrder) return; // ★ RTは編集禁止
                                orderState.updateAggregatedLineQty(
                                  order.id,
                                  line,
                                  line.qty + 1,
                                );
                              },
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                          ),
                          onPressed: () {
                             if (isRealtimeOrder) return; // ★ RTは編集禁止
                           orderState.removeAggregatedLine(order.id, line);
                          },
                        ),
                      );
                    },
                  ),
                ),

                // =====================
                // 合計 & 会計（オーナー用）
                // =====================
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '合計（税・サービス料込）',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                             formatYenTruncatedToTen(billing?.total ?? 0),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      if (billing != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '内訳：税 ${formatYen(billing.taxAmount)} / サ ${formatYen(billing.serviceAmount)}',

                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                          ),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('会計完了'),
                                content:
                                    const Text('会計を完了しますか？'),
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
                              await orderState.completeOrder(order.id);
                              Navigator.pop(context);
                            }
                          },
                          child: const Text(
                            '会計完了',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

