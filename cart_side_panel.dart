import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/cart_state.dart';
import '../state/order_state.dart';
import '../state/app_state.dart';
import '../state/realtime_state.dart';
import '../utils/price_format.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  static const bgColor = Color(0xFF0E0E0E);
  static const cardColor = Color(0xFF1A1A1A);
  static const accent = Color(0xFFD4AF37);

  String _buildFailureDetail({
    required String? table,
    required bool isActive,
    required bool canSubmitOrders,
    required bool connected,
  }) {
    if (table == null || table.trim().isEmpty) {
      return '停止箇所: 送信前（席情報）\n原因候補: 席番号が取得できていません。ログインからやり直してください。';
    }
    if (!isActive) {
      return '停止箇所: 送信前（受付状態）\n原因候補: この席は受付終了です。';
    }
    if (!canSubmitOrders) {
      return '停止箇所: 送信前（同期状態）\n原因候補: 復帰直後の同期中です。同期完了後に再試行してください。';
    }
    if (!connected) {
      return '停止箇所: 送信処理（通信）\n原因候補: 一時的にサーバー接続が切れています。';
    }
    return '停止箇所: 送信後（サーバー応答）\n原因候補: payload不整合（tableId/items）やサーバー側バリデーション失敗の可能性があります。';
  }

  String _formatSyncTime(DateTime? dt) {
    if (dt == null) return '-';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    final orderState = context.watch<OrderState>();
    final table = context.select<AppState, String?>((s) => s.guestTable);

    final realtime = context.watch<RealtimeState>();

    final canOrder =
        table != null && orderState.isActive(table) && orderState.canSubmitOrders;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('カート'),
      ),
      body: cart.items.isEmpty
          ? const Center(
              child: Text(
                'カートは空です',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : Column(
              children: [
                if (!orderState.canSubmitOrders)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: const Text(
                      '復帰後の同期中です。最新情報取得まで注文できません。',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.brand} / ${item.label}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  formatYen(item.price),
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: canOrder
                                      ? () => context.read<CartState>().dec(item)
                                      : null,
                                ),
                                Text(
                                  '${item.qty}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: canOrder
                                      ? () => context.read<CartState>().inc(item)
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade800),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Text('合計', style: TextStyle(color: Colors.white)),
                          const Spacer(),
                          Text(
                            formatYen(cart.total),
                            style: const TextStyle(
                              color: accent,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '接続: ${realtime.connected ? 'オンライン' : '再接続中'}  /  最終同期: ${_formatSyncTime(orderState.lastSyncedAt)}',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canOrder ? accent : Colors.grey,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: canOrder ? () => _confirmOrder(context, cart) : null,
                        child: Text(canOrder ? '注文を確定する' : '受付終了'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmOrder(BuildContext context, CartState cart) async {
    final orderState = context.read<OrderState>();
    final table = context.read<AppState>().guestTable;
    final connected = context.read<RealtimeState>().connected;

    final isActive = table != null && orderState.isActive(table);
    final canSubmit = orderState.canSubmitOrders;

    if (!isActive || !canSubmit) {
      final detail = _buildFailureDetail(
        table: table,
        isActive: isActive,
        canSubmitOrders: canSubmit,
        connected: connected,
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detail)));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('注文確認'),
        content: Text('合計 ${formatYen(cart.total)}\n注文を確定しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確定'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final sent = await orderState.addFromCart(cart, table);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? '注文を受け付けました'
              : _buildFailureDetail(
                  table: table,
                  isActive: isActive,
                  canSubmitOrders: canSubmit,
                  connected: connected,
                ),
        ),
      ),
    );

    if (sent) {
      Navigator.pop(context);
    }
  }
}

// =========================
// カートサイドパネルを開く（ゲスト共通）
// =========================
void openCartSidePanel(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const CartPage(),
  );
}