import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/order_state.dart';
import '../state/app_state.dart';
import 'login_page.dart';
import 'owner_table_center_panel.dart';
import '../../billing/billing_calculator.dart';
import '../utils/price_format.dart';
import '../utils/order_sort.dart';
import '../state/realtime_state.dart';

class OwnerTablePage extends StatefulWidget {
  const OwnerTablePage({super.key});

  @override
  State<OwnerTablePage> createState() => _OwnerTablePageState();
}

class _OwnerTablePageState extends State<OwnerTablePage> {
  bool _editMode = false;
  @override
void initState() {
  super.initState();

  // ★ オーナーモード用：Realtime 接続開始
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<RealtimeState>().connect();
  });
}

  @override
  Widget build(BuildContext context) {
    final orderState = context.watch<OrderState>();
    final tables = orderState.tables;
    final realtime = context.watch<RealtimeState>();

    print('RT ordersByTable = ${orderState.realtimeOrdersByTable}');
    print('RT orderItems    = ${orderState.realtimeOrderItems}');
    print('OWNER SNAPSHOT tables = ${realtime.tables}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('テーブル管理'),
        actions: [
          IconButton(
            tooltip: _editMode ? '編集モードを終了' : '編集モード',
            icon: Icon(_editMode ? Icons.check_circle : Icons.edit),
            onPressed: () => setState(() => _editMode = !_editMode),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('ログアウト'),
                  content: const Text('ログアウトしますか？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('キャンセル'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );

              if (ok == true) {
                context.read<AppState>().logout();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addTable(context),
        icon: const Icon(Icons.add),
        label: const Text('テーブル追加'),
      ),

      body: Padding(
        padding: const EdgeInsets.all(50),
        child: GridView.builder(
          itemCount: tables.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 35,
            mainAxisSpacing: 35,
            childAspectRatio: 1.10,
          ),
          itemBuilder: (context, index) {
           
           final table = tables[index];
            final isActive = orderState.isActive(table);
            final hasOrder = orderState.hasOrder(table);
            final order = orderState.realtimeOrderForDisplay(table);

            final timer = orderState.timerOf(table);

            final total = order == null
                ? 0
                : BillingCalculator.calculateFromLines(
                    sortOrderLines(order.lines),
                  ).total;


            return _TableBigNumberCard(
              table: table,
              isActive: isActive,
              hasOrder: hasOrder,
              total: total,
              editMode: _editMode,
              timer: timer,
              onTap: () => _openTableDialog(context, table),
              onRename: () => _renameTable(context, table),
              onDelete: hasOrder ? null : () => orderState.removeTable(table),
            );         
          },
        ),
      ),
    );
  }

  Future<void> _addTable(BuildContext context) async {
    final ctrl = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('テーブル追加'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '例：A / VIP4'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('追加'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (name != null && name.isNotEmpty) {
      context.read<OrderState>().addTable(name);
    }
  }

  Future<void> _renameTable(BuildContext context, String table) async {
    final ctrl = TextEditingController(text: table);

    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('テーブル名変更'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('変更'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (newName != null && newName.isNotEmpty && newName != table) {
      context.read<OrderState>().renameTable(table, newName);
    }
  }
}

/// =======================
/// テーブルカード
/// =======================
class _TableBigNumberCard extends StatelessWidget {
  final String table;
  final bool isActive;
  final bool hasOrder;
  final int total;
 final bool editMode;
  final TableTimerInfo? timer;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback? onDelete;


  const _TableBigNumberCard({
    required this.table,
    required this.isActive,
    required this.hasOrder,
    required this.total,
    required this.editMode,
    required this.timer,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

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
    // ===== ★ 色判定ロジック =====
    Color borderColor = isActive ? Colors.amber : Colors.grey.shade400;
    Color bgColor = isActive
        ? Colors.amber.withValues(alpha: 0.16)
        : Colors.grey.shade200;

    if (timer != null && !timer!.autoExtend) {
      final sec = timer!.remainingSeconds;

      if (sec <= 5 * 60) {
        borderColor = Colors.red.shade900;
        bgColor = Colors.red.withValues(alpha: 0.30);
      } else if (sec <= 10 * 60) {
        borderColor = Colors.red.shade600;
        bgColor = Colors.red.withValues(alpha: 0.20);
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 2),
        ),
        padding: const EdgeInsets.all(14),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 6, right: 6),
                child: Text(
                  table,
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: hasOrder
                        ? Colors.amber.shade900
                        : Colors.black87,
                  ),
                ),
              ),
            ),
            if (timer != null && !timer!.autoExtend)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: editMode ? 42 : 6,
                    right: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '開始 ${timer!.startTime ?? "--:--"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: borderColor,
                        ),
                      ),
                      Text(
                        // ★ 修正：startTimeベースで終了時刻を計算
                        '終了 ${_formatEndTime(timer!.totalSeconds, timer!.startTime)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: borderColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
               child: isActive
    ? Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '使用中',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: borderColor,
            ),
          ),

          // ★ 残り時間（あるときだけ表示）
          if (timer != null && !timer!.autoExtend)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _formatSec(timer!.remainingSeconds),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: borderColor,
                ),
              ),
            ),

          const SizedBox(height: 4),

          if (hasOrder)
            Text(
              formatYenTruncatedToTen(total),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: borderColor,
              ),
            ),
        ],
      )
    : const Text(
        '空席',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Colors.grey,
        ),
      ),
              ),
            ),
            if (editMode)
              Align(
                alignment: Alignment.topRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '名前変更',
                      icon: const Icon(Icons.edit),
                      onPressed: onRename,
                    ),
                    IconButton(
                      tooltip: hasOrder ? '注文ありは削除不可' : '削除',
                      icon: Icon(
                        Icons.delete,
                        color: hasOrder ? Colors.grey : Colors.red,
                      ),
                      onPressed: onDelete,
                    ),
                  ],
                ),
          ),
           ],
        ),
      ),
    );
  }
}

void _openTableDialog(BuildContext context, String table) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: SizedBox(
        width: 520,
        child: OwnerTableCenterPanel(table: table),
      ),
    ),
  );
}