import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/set_data.dart';
import '../utils/price_format.dart';

class OwnerSetEditPage extends StatefulWidget {
  const OwnerSetEditPage({super.key});

  @override
  State<OwnerSetEditPage> createState() => _OwnerSetEditPageState();
}

class _OwnerSetEditPageState extends State<OwnerSetEditPage> {
  // 表示中セット名
  String _selectedSetName = '通常';

  // 編集状態：null=閉 / -1=追加中 / 0以上=編集行
  int? _editingIndex;

  final TextEditingController _labelCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();

  @override
  void dispose() {
    _labelCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  // =========================
  // ★ セット名 → sectionKey 対応
  // =========================
  String _defaultSectionKeyForSet(String setName) {
    switch (setName) {
      case '案内所':
        return 'agency';
      case 'VIP':
        return 'extension';
      default:
        return 'normal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final setData = context.watch<SetData>();
    final sets = setData.sets;

    Map<String, dynamic>? findByName(String name) {
      for (final s in sets) {
        if ((s['name'] ?? '').toString() == name) return s;
      }
      return null;
    }

    final selectedSet =
        findByName(_selectedSetName) ??
            findByName('通常') ??
            findByName('案内所') ??
            findByName('VIP') ??
            (sets.isNotEmpty ? sets.first : null);

    if (selectedSet == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('セット編集')),
        body: const Center(child: Text('セットデータがありません')),
      );
    }

    // section を全部まとめて表示
    final sections =
        (selectedSet['sections'] as Map<String, dynamic>?) ?? {};
    final List<_ItemRef> viewItems = [];

    void collect(String key) {
      final list = (sections[key] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final item in list) {
        viewItems.add(_ItemRef(sectionKey: key, item: item));
      }
    }
   
    final sectionKey = _defaultSectionKeyForSet(
  (selectedSet['name'] ?? '').toString(),
);

collect(sectionKey);


   

    return Scaffold(
      appBar: AppBar(title: const Text('セット編集')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ---------- セット切替 ----------
            Row(
              children: [
                _setChip('通常'),
                _setChip('案内所'),
                _setChip('VIP'),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '編集対象：${selectedSet['name']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),

            // ---------- 一覧 ----------
            Expanded(
              child: ListView.builder(
                itemCount: viewItems.length + 1,
                itemBuilder: (_, index) {
                  // --- 追加行 ---
                  if (index == viewItems.length) {
                    if (_editingIndex == -1) {
                      return _editPanel(
                        title: '時間と料金を追加',
                        onCancel: _closeEditor,
                        onSave: () {
                          final label = _labelCtrl.text.trim();
                          final price =
                              int.tryParse(_priceCtrl.text.trim());
                          if (label.isEmpty || price == null) return;

                          final sectionKey =
                              _defaultSectionKeyForSet(
                                  (selectedSet['name'] ?? '').toString());

                          setData.addItem(
                              selectedSet, sectionKey, label, price);
                          _closeEditor();
                        },
                      );
                    }

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.add),
                        title: const Text('時間と料金を追加'),
                        onTap: _openAdd,
                      ),
                    );
                  }

                  // --- 通常行 ---
                  final ref = viewItems[index];
                  final item = ref.item;
                  final isOpen = _editingIndex == index;

                  return Card(
                    child: Column(
                      children: [
                        ListTile(
                          onTap: () =>
                              isOpen ? _closeEditor() : _openEdit(index, item),
                          leading: Text(
                            formatYen(item['price'] ?? 0),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          title: Text(item['label'] ?? ''),
                          trailing: Icon(isOpen
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down),
                        ),
                        if (isOpen)
                          _editPanel(
                            title: '編集',
                            onCancel: _closeEditor,
                            onSave: () {
                              final newLabel =
                                  _labelCtrl.text.trim();
                              final newPrice = int.tryParse(
                                  _priceCtrl.text.trim());
                              if (newLabel.isEmpty || newPrice == null) return;

                              setData.updateItem(
                                selectedSet,
                                ref.sectionKey,
                                item,
                                newLabel,
                                newPrice,
                              );
                              _closeEditor();
                            },
                            onDelete: () {
                              setData.removeItem(
                                selectedSet,
                                ref.sectionKey,
                                item,
                              );
                              _closeEditor();
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- UI部品 ----------
  Widget _setChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _selectedSetName == label,
        onSelected: (_) {
          setState(() {
            _selectedSetName = label;
            _closeEditor();
          });
        },
      ),
    );
  }

  Widget _editPanel({
    required String title,
    required VoidCallback onSave,
    required VoidCallback onCancel,
    VoidCallback? onDelete,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _labelCtrl,
            decoration:
                const InputDecoration(labelText: '時間（例：60分）'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _priceCtrl,
            decoration:
                const InputDecoration(labelText: '料金（円）'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (onDelete != null)
                TextButton(
                  onPressed: onDelete,
                  child: const Text('削除',
                      style: TextStyle(color: Colors.red)),
                ),
              const Spacer(),
              TextButton(
                  onPressed: onCancel, child: const Text('キャンセル')),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: onSave, child: const Text('保存')),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- 編集制御 ----------
  void _openEdit(int index, Map<String, dynamic> item) {
    setState(() {
      _editingIndex = index;
      _labelCtrl.text = item['label'] ?? '';
      _priceCtrl.text = (item['price'] ?? 0).toString();
    });
  }

  void _openAdd() {
    setState(() {
      _editingIndex = -1;
      _labelCtrl.clear();
      _priceCtrl.clear();
    });
  }

  void _closeEditor() {
    setState(() {
      _editingIndex = null;
      _labelCtrl.clear();
      _priceCtrl.clear();
    });
  }
}

// -------------------------
// 内部クラス
// -------------------------
class _ItemRef {
  final String sectionKey;
  final Map<String, dynamic> item;

  _ItemRef({required this.sectionKey, required this.item});
}
