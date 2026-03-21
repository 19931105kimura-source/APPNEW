import 'package:flutter/material.dart';
import '../utils/price_format.dart';

class OwnerConfirmAddDialog extends StatefulWidget {
  final String label;
  final int price;

  const OwnerConfirmAddDialog({
    super.key,
    required this.label,
    required this.price,
  });

  @override
  State<OwnerConfirmAddDialog> createState() =>
      _OwnerConfirmAddDialogState();
}

class _OwnerConfirmAddDialogState
    extends State<OwnerConfirmAddDialog> {
  int qty = 1;
  bool shouldPrint = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.label),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatYen(widget.price)),

          const SizedBox(height: 16),

          // 数量
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: qty > 1
                    ? () => setState(() => qty--)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Text(
                qty.toString(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => qty++),
                icon: const Icon(Icons.add),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 印刷する／しない
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('印刷する'),
            value: shouldPrint,
            onChanged: (v) =>
                setState(() => shouldPrint = v ?? true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'qty': qty,
              'shouldPrint': shouldPrint,
            });
          },
          child: const Text('確定'),
        ),
      ],
    );
  }
}
