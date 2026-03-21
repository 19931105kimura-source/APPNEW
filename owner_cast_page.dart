import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/cast_data.dart';

class OwnerCastPage extends StatefulWidget {
  const OwnerCastPage({super.key});

  @override
  State<OwnerCastPage> createState() => _OwnerCastPageState();
}

class _OwnerCastPageState extends State<OwnerCastPage> {
  String? _editingCastName;
  @override
  void initState() {
    super.initState();
    // 画面を開いた瞬間に1回だけロード
    Future.microtask(() {
      context.read<CastData>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final castData = context.watch<CastData>();
    final casts = castData.casts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('キャスト管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_by_alpha),
            tooltip: '50音順に並び替え',
            onPressed: () {
              context.read<CastData>().sortByKana();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addCast(context),
        child: const Icon(Icons.add),
      ),
      body: casts.isEmpty
          ? const Center(child: Text('キャストがいません'))
          : ReorderableListView.builder(
              itemCount: casts.length,
              onReorder: (o, n) => castData.reorder(o, n),
              itemBuilder: (context, index) {
                final name = casts[index];
                final isEditing = _editingCastName == name;
                return ListTile(
                  key: ValueKey(name),
                  selected: isEditing,
                  selectedTileColor: Colors.amber.withOpacity(0.18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isEditing
                          ? Colors.amber.shade700
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          isEditing ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _renameCast(context, name),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteCast(context, name),
                      ),
                      const Icon(Icons.drag_handle),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // =========================
  // 追加
  // =========================
  void _addCast(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('キャスト追加'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '例：れみ'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<CastData>().add(ctrl.text);
              Navigator.pop(context);
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  // =========================
  // 名前変更
  // =========================
  void _renameCast(BuildContext context, String oldName) {
    final ctrl = TextEditingController(text: oldName);
    setState(() => _editingCastName = oldName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('名前変更'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<CastData>().rename(oldName, ctrl.text);
              Navigator.pop(context);
            },
            child: const Text('変更'),
          ),
        ],
      ),
    ).whenComplete(() {
      if (mounted) {
        setState(() => _editingCastName = null);
      }
    });
  }

  // =========================
  // 削除
  // =========================
  void _deleteCast(BuildContext context, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('$name を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (ok == true) {
      context.read<CastData>().remove(name);
    }
  }
}