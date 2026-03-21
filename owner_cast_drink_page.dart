import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/cast_drink_data.dart';
import '../utils/price_format.dart';

class OwnerCastDrinkPage extends StatelessWidget {
  const OwnerCastDrinkPage({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<CastDrinkData>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('キャストドリンク編集'),
      ),
      body: ReorderableListView.builder(
        itemCount: data.items.length + 1,
        onReorder: (oldIndex, newIndex) {
          if (oldIndex == data.items.length) return;
          if (newIndex > data.items.length) newIndex = data.items.length;
          if (newIndex > oldIndex) newIndex--;
          context.read<CastDrinkData>().reorderDrinks(oldIndex, newIndex);
        },
        itemBuilder: (context, index) {
          if (index == data.items.length) {
            return ListTile(
              key: const ValueKey('__add__'),
              leading: const Icon(Icons.add),
              title: const Text('キャストドリンク追加'),
              onTap: () => _addDrink(context),
            );
          }

          final item = data.items[index];

          return ListTile(
            key: ValueKey(item),
            title: Text(item.name),
            subtitle: Text(formatYen(item.price)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.drag_handle),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') {
                      _openEditDialog(context, item);
                    } else if (v == 'delete') {
                      context.read<CastDrinkData>().removeDrink(item);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('編集')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('削除', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // =========================
  // 新規追加
  // =========================
  void _addDrink(BuildContext context) {
    _openEditDialog(context, null);
  }

  // =========================
  // 追加・編集ダイアログ（完成版）
  // =========================
  Future<void> _openEditDialog(
    BuildContext context,
    CastDrinkItem? item,
  ) async {
    final isNew = item == null;

    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final priceCtrl = TextEditingController(
      text: item == null ? '' : item.price.toString(),
    );
    final strengthCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(isNew ? 'キャストドリンク追加' : 'キャストドリンク編集'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: '名前'),
                    ),
                    TextField(
                      controller: priceCtrl,
                      decoration: const InputDecoration(labelText: '金額'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    const Text('濃さ', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    if (!isNew)
                      Wrap(
                        spacing: 8,
                        children: item.strengths.map((s) {
                          return Chip(
                            label: Text(s),
                            deleteIcon: const Icon(Icons.close),
                            onDeleted: () {
                              context.read<CastDrinkData>().removeStrength(item, s);
                              setLocalState(() {});
                            },
                          );
                        }).toList(),
                      ),

                    if (!isNew)
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('濃さを追加'),
                        onPressed: () async {
                          final v = await showDialog<String>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('濃さ追加'),
                              content: TextField(
                                controller: strengthCtrl,
                                decoration: const InputDecoration(hintText: '例：薄め'),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('キャンセル'),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.pop(context, strengthCtrl.text),
                                  child: const Text('追加'),
                                ),
                              ],
                            ),
                          );
                          if (!context.mounted) return;
                          if (v != null && v.trim().isNotEmpty) {
                            context.read<CastDrinkData>().addStrength(item, v);
                            strengthCtrl.clear();
                            setLocalState(() {});
                          }
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final price = int.tryParse(priceCtrl.text) ?? 0;
                    if (name.isEmpty || price <= 0) return;

                    final data = context.read<CastDrinkData>();

                    if (isNew) {
                      data.addDrink(name, price);
                    } else {
                      data.renameDrink(item, name);
                      data.updatePrice(item, price);
                    }

                    Navigator.pop(context);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
