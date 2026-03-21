import 'dart:convert';
import '../data/server_config.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../state/order_state.dart';
import 'owner_add_order_page.dart';
import '../../billing/billing_calculator.dart';
import '../utils/price_format.dart';
import '../state/realtime_state.dart';


class OwnerTableCenterPanel extends StatefulWidget {
  final String table;
  const OwnerTableCenterPanel({super.key, required this.table});

  @override
  State<OwnerTableCenterPanel> createState() => _OwnerTableCenterPanelState();
}

class _OwnerTableCenterPanelState extends State<OwnerTableCenterPanel> {
  bool _printing = false;

  Future<void> _rtRemoveOrderLines(Order order) async {
    for (final line in order.lines) {
      final lineId = line.lineId;
      if (lineId == null) continue;
      try {
        final uri = ServerConfig.api('/api/rt/tables/${widget.table}/items/$lineId');
        final res = await http.delete(uri);
        if (res.statusCode != 200) {
          debugPrint('RT DELETE FAILED ${res.statusCode}');
        }
      } catch (e) {
        debugPrint('RT DELETE ERROR: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderState = context.watch<OrderState>();
    final rtState = context.watch<RealtimeState>();

    final orderData = orderState.orderOf(widget.table);
   final displayOrder = orderState.realtimeOrderForDisplay(widget.table);
    final rtTable = rtState.tables[widget.table] as Map<String, dynamic>?;
    final status = (rtTable?['status'] ?? '').toString();
    final isActive = status == 'ordering';


    debugPrint('RT TABLE ${widget.table} status = $status');


    final billing = displayOrder == null
        ? null
        : BillingCalculator.calculateFromLines(displayOrder.lines);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.table,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            isActive ? '使用中' : '未開始',
            style: TextStyle(
              color: isActive ? Colors.amber : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),

          const Divider(height: 32),

          // ===== 会計表示 =====
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('現在の会計', style: TextStyle(fontSize: 16)),
                  Text(
                    formatYenTruncatedToTen(billing?.total ?? 0),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (billing != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '内訳：税 ${formatYen(billing.taxAmount)} / サ ${formatYen(billing.serviceAmount)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ],
          ),

         const SizedBox(height: 16),
          // ===== 注文一覧 =====
          if (orderData != null && orderData.lines.isNotEmpty)
            SizedBox(
              height: 180,
              child: Builder(
                builder: (context) {
                  final lines = orderState.aggregateLinesForDisplay(
                    orderData.lines,
                  );

                  bool isExtension(dynamic l) {
                    final b = (l.brand ?? '').toString();
                    final lab = (l.label ?? '').toString();
                    return b.contains('延長') || lab.contains('延長');
                  }

                  lines.sort((a, b) {
                    final aIsSet = a.category == 'セット';
                    final bIsSet = b.category == 'セット';
                    if (aIsSet && !bIsSet) return -1;
                    if (!aIsSet && bIsSet) return 1;

                    if (aIsSet && bIsSet) {
                      final aExt = isExtension(a);
                      final bExt = isExtension(b);
                      if (!aExt && bExt) return -1;
                      if (aExt && !bExt) return 1;
                    }
                    return 0;
                  });

                  return ListView.builder(
                    itemCount: lines.length,
                    itemBuilder: (context, i) {
                      final l = lines[i];
                      final name = l.label.trim().isEmpty
                          ? l.brand
                          : '${l.brand} ${l.label}';

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                formatYen(l.price),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '×${l.qty}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('注文はありません'),
            ),

          // ===== 操作ボタン =====
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              // ★ タイマー（正本はOrderState）
              ElevatedButton(
                onPressed: () => _openTimeDialog(context, widget.table),
                child: const Text('時間'),
              ),

              ElevatedButton(
                onPressed: isActive
    ? null
    : () async {
        try {
          await http.post(
            ServerConfig.api('/api/rt/tables/${widget.table}/start'),
          );
        } catch (e) {
          debugPrint('RT START ERROR: $e');
        }
      },

                child: const Text('注文開始'),
              ),

              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OwnerAddOrderPage(table: widget.table),
                    ),
                  );
                },
                child: const Text('注文を追加'),
              ),

              OutlinedButton(
                onPressed: (orderData == null || orderData.lines.isEmpty)
                    ? null
                    : () async {
                        final to = await _selectTableDialog(
                          context,
                          title: '移動先の席を選択',
                          exclude: widget.table,
                        );
                        if (to == null) return;
                        await orderState.moveTable(from: widget.table, to: to);
                        Navigator.pop(context);
                      },
                child: const Text('席移動'),
              ),

              OutlinedButton(
                onPressed: (orderData == null || orderData.lines.isEmpty)
                    ? null
                    : () async {
                        final to = await _selectTableDialog(
                          context,
                          title: '合算先の席を選択',
                          exclude: widget.table,
                          onlyWithOrder: true,
                        );
                        if (to == null) return;
                        await orderState.mergeTables(from: widget.table, to: to);
                        Navigator.pop(context);
                      },
                child: const Text('席合算'),
              ),

              ElevatedButton(
                onPressed: !_printing &&
                        orderData != null &&
                        orderData.lines.isNotEmpty
                    ? () async {
                        await _printReceipt(context, widget.table);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                ),
                child: _printing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('伝票印刷'),
              ),

            OutlinedButton(
  onPressed: isActive
      ? () async {
          try {
            await http.post(
              ServerConfig.api('/api/rt/tables/${widget.table}/end'),
            );
            Navigator.pop(context);
          } catch (e) {
            debugPrint('RT END ERROR: $e');
          }
        }
      : null,
  child: const Text('終了'),
),


             TextButton(
                onPressed: orderData != null
                    ? () async {
                        if (orderState.isRealtimeOrderId(orderData.id)) {
                          await _rtRemoveOrderLines(orderData);
                        }
                        final ok = await orderState.removeOrder(orderData.id);
                         if (!ok) return;
                        await orderState.endTable(widget.table);
                        Navigator.pop(context);
                      }
                    : null,
                child: const Text(
                  '注文削除',
                  style: TextStyle(color: Colors.red),
                ),
              ),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  

  // ===== 時間ダイアログ =====
  void _openTimeDialog(BuildContext context, String table) {
    showDialog(
      context: context,
      builder: (_) => _TimeDialog(table: table),
    );
  }

  // ===== テーブル選択ダイアログ =====
  Future<String?> _selectTableDialog(
    BuildContext context, {
    required String title,
    required String exclude,
    bool onlyWithOrder = false,
  }) async {
    final orderState = context.read<OrderState>();

    final tables = orderState.tables.where((t) {
      if (t == exclude) return false;
      if (onlyWithOrder) {
        final o = orderState.orderOf(t);
        return o != null && o.lines.isNotEmpty;
      }
      return true;
    }).toList();

    if (tables.isEmpty) return null;

    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: tables
                .map(
                  (t) => ListTile(
                    title: Text(t),
                    onTap: () => Navigator.pop(context, t),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _printReceipt(BuildContext context, String tableId) async {
    if (_printing) return;

    setState(() => _printing = true);

    try {
      final res = await http.post(
        ServerConfig.api('/api/print/receipt'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'tableId': tableId}),
      );

      if (res.statusCode != 200) throw Exception('http error');

      final data = jsonDecode(res.body);
      if (data['success'] != true) throw Exception('print failed');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('会計伝票を印刷しました')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('印刷に失敗しました')),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }
}

class _TimeDialog extends StatefulWidget {
  final String table;
  const _TimeDialog({required this.table});

  @override
  State<_TimeDialog> createState() => _TimeDialogState();
}

class _TimeDialogState extends State<_TimeDialog> {
  late final TextEditingController _startTimeCtrl;

  @override
  void initState() {
    super.initState();
    final saved = context.read<OrderState>().timerOf(widget.table);
    _startTimeCtrl = TextEditingController(text: saved?.startTime ?? '');
  }

  @override
  void dispose() {
    _startTimeCtrl.dispose();
    super.dispose();
  }

  String _formatSec(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ★ 修正：startTimeベースで終了時刻を計算
  String _formatEndTime(int totalSeconds, String? startTime) {
    if (startTime == null || startTime.isEmpty) {
      // startTime未入力のときだけ現在時刻ベースにフォールバック
      final end = DateTime.now().add(Duration(seconds: totalSeconds));
      return '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    }

    final parts = startTime.split(':');
    if (parts.length != 2) return '--:--';

    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;

    final startMinutes = h * 60 + m;
    final endMinutes = startMinutes + (totalSeconds ~/ 60);

    final endH = (endMinutes ~/ 60) % 24;
    final endM = endMinutes % 60;

    return '${endH.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final orderState = context.watch<OrderState>();
    final info = orderState.timerOf(widget.table);

    final autoExtend = info?.autoExtend ?? false;
    final remainingSeconds = info?.remainingSeconds ?? 0;
    // ★ 修正：終了時刻の計算にはtotalSecondsを使う
    final totalSeconds = info?.totalSeconds ?? remainingSeconds;
    final startTime = info?.startTime;

    Widget startTimeInput() => TextField(
          controller: _startTimeCtrl,
          keyboardType: TextInputType.number,
          maxLength: 5,
          decoration: const InputDecoration(
            labelText: '開始時刻（HH:MM）',
            hintText: '23:23',
            counterText: '',
          ),
          onChanged: (v) {
            // 数字キーのみで「23:23」へ寄せる
            if (v.length == 2 && !v.contains(':')) {
              _startTimeCtrl.text = '$v:';
              _startTimeCtrl.selection = TextSelection.fromPosition(
                TextPosition(offset: _startTimeCtrl.text.length),
              );
            }
            // 入力が完成形なら保存
            final reg = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');
            if (reg.hasMatch(_startTimeCtrl.text)) {
              orderState.setTableTimerStartTime(
  table: widget.table,
  startTime: _startTimeCtrl.text,
);

            }
            setState(() {});
          },
        );

    Widget autoBtn() => ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: autoExtend ? Colors.amber : null,
          ),
          onPressed: () async {
            final newAuto = !autoExtend;
            orderState.startTableTimer(
  table: widget.table,
  totalSeconds: remainingSeconds,
  remainingSeconds: remainingSeconds,
  autoExtend: false,
  startTime: _startTimeCtrl.text,
);

          },
          child: Text(autoExtend ? '自動延長：ON' : '自動延長：OFF'),
        );

   Widget addBtn(int m) => ElevatedButton(
  onPressed: autoExtend
      ? null
      : () {
          orderState.adjustTableTimerMinutes(
            table: widget.table,
            minutes: m,
          );

          // ★ 分を足したら即スタート
          final info = orderState.timerOf(widget.table);
          if (info != null && info.remainingSeconds > 0) {
            orderState.startTableTimer(
              table: widget.table,
              totalSeconds: info.totalSeconds ?? info.remainingSeconds,
              remainingSeconds: info.remainingSeconds,
              autoExtend: false,
              startTime: _startTimeCtrl.text,
            );
          }
        },
  child: Text('+${m}分'),
);


 Widget subBtn(int m) => OutlinedButton(
  onPressed: autoExtend
      ? null
      : () {
          orderState.adjustTableTimerMinutes(
            table: widget.table,
            minutes: -m,
          );

          final info = orderState.timerOf(widget.table);
          if (info != null && info.remainingSeconds > 0) {
            orderState.startTableTimer(
              table: widget.table,
              totalSeconds: info.totalSeconds ?? info.remainingSeconds,
              remainingSeconds: info.remainingSeconds,
              autoExtend: false,
              startTime: _startTimeCtrl.text,
            );
          }
        },
  child: Text('-${m}分'),
);




    Future<void> startPressed() async {
      if (autoExtend) return;

      if (remainingSeconds <= 0) return;

      orderState.startTableTimer(
  table: widget.table,
  totalSeconds: remainingSeconds,
  remainingSeconds: remainingSeconds,
  autoExtend: false,
  startTime: _startTimeCtrl.text,
);

    }

    return AlertDialog(
      title: const Text('時間'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          startTimeInput(),
          const SizedBox(height: 8),

          // 表示（自動延長OFFのみ）
          if (!autoExtend) ...[
            Text(
             '合計：${(totalSeconds ~/ 60)}分',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              // ★ 修正：totalSecondsとstartTimeで終了時刻を計算
              '終了：${_formatEndTime(totalSeconds, _startTimeCtrl.text.isNotEmpty ? _startTimeCtrl.text : startTime)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '残り：${_formatSec(remainingSeconds)}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
          ],

          autoBtn(),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              addBtn(60),
              addBtn(30),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              subBtn(60),
              subBtn(30),
            ],
          ),

          const Divider(height: 24),


        ],
      ),
    actions: [
        TextButton(
          onPressed: () {
            orderState.resetTableTimer(widget.table);
            _startTimeCtrl.text = '';
          },
          child: const Text('リセット'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}