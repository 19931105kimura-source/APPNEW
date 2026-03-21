import 'package:flutter/material.dart';

class TableSelectPage extends StatefulWidget {
  const TableSelectPage({super.key});

  @override
  State<TableSelectPage> createState() => _TableSelectPageState();
}

class _TableSelectPageState extends State<TableSelectPage> {
  String? selected;

  @override
  Widget build(BuildContext context) {
    final tables = List.generate(12, (i) => 'T${i + 1}'); // 例：T1〜T12

    return Scaffold(
      appBar: AppBar(title: const Text('席を選択')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: tables.map((t) {
                final on = selected == t;
                return ChoiceChip(
                  label: Text(t),
                  selected: on,
                  onSelected: (_) => setState(() => selected = t),
                );
              }).toList(),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selected == null
                    ? null
                    : () => Navigator.pop(context, selected),
                child: const Text('決定'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
