import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../state/order_state.dart';

class GuestOrderHistoryPage extends StatelessWidget {
  const GuestOrderHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final table = context.select<AppState, String?>((s) => s.guestTable);

    return Scaffold(
      appBar: AppBar(
        title: const Text('注文履歴'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: _TableBadge(text: table ?? '-'),
            ),
          ),
        ],
      ),
      body: table == null || table.trim().isEmpty
          ? const Center(child: Text('席番号が未設定です'))
          : _HistoryBody(table: table),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  final String table;
  const _HistoryBody({required this.table});

  @override
  Widget build(BuildContext context) {
    final orderState = context.watch<OrderState>();
   final order = orderState.orderForDisplay(table);


         final guestLines = order == null
        ? <OrderLine>[]
        : order.lines.where((l) {
            if (l.category == 'セット') return false;
            if (l.subCategory == '本指名') return false;
            if (l.subCategory == '場内指名') return false;
           if (l.subCategory == '同伴') return false;
            return true;
          }).toList();
    final displayLines = orderState.aggregateLinesForDisplay(guestLines);

    if (order == null || displayLines.isEmpty) {
      return const Center(child: Text('まだ注文がありません'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // --- 上部情報（席のみ表示） ---
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                Text(
                  '席：$table',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // --- 明細（数量のみ） ---
          Expanded(
            child: ListView.separated(
              itemCount: displayLines.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final l = displayLines[i];

                final cleanBrand = l.brand.trim() == 'RT'
                    ? ''
                    : l.brand.trim();
                final cleanLabel = l.label.trim() == 'RT'
                    ? ''
                    : l.label.trim();
                final title = [cleanBrand, cleanLabel]
                    .where((e) => e.isNotEmpty)
                    .join(' ');
                final subtitle = l.category.trim() == 'RT'
                    ? ''
                    : l.category.trim();
                return ListTile(
                  dense: true,
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: subtitle.isEmpty ? null : Text(subtitle),
                  trailing: Text(
                    'x${l.qty}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // --- 注意文 ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: const Text(
              '※ この画面では注文の変更・削除はできません。',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableBadge extends StatelessWidget {
  final String text;
  const _TableBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chair, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
