import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';


import '../utils/price_format.dart';
import '../data/menu_data.dart';
import '../state/app_state.dart';
import '../state/cart_state.dart';


import 'cart_side_panel.dart';
import 'guest_order_history_page.dart';
import 'owner_add_item_sheet.dart';

class BrandListPage extends StatefulWidget {
  final String category;
  final String? initialBrand;

   const BrandListPage({
    super.key,
    required this.category,
    this.initialBrand,
  });

  @override
  State<BrandListPage> createState() => _BrandListPageState();
}

class _BrandListPageState extends State<BrandListPage> {
  Map<String, dynamic>? selectedBrand;
  bool _didInitInitialBrandSelection = false;

 
  
 @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitInitialBrandSelection) return;
    _didInitInitialBrandSelection = true;

    final initialBrand = widget.initialBrand?.trim();
    if (initialBrand == null || initialBrand.isEmpty) return;

    final normalizedInitialBrand = initialBrand.toLowerCase();
    final menuData = context.read<MenuData>();

    for (final item in menuData.items) {
      final category = (item['category'] ?? '').toString();
      final brandName = (item['name'] ?? '').toString().trim();
      if (category != widget.category || brandName.isEmpty) continue;
      if (brandName.toLowerCase() == normalizedInitialBrand) {
        selectedBrand = item;
        return;
      }
    }
  }

  void _showAddedToCartNotice(String label) {
 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label をカートに追加しました'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void openCartSidePanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CartPage(),
    );
  }

  @override
   Widget build(BuildContext context) {
    final isOwner = context.watch<AppState>().mode == UserMode.owner;
    final menuData = context.watch<MenuData>();
    final cart = context.watch<CartState>();
    final hasCartItems = cart.items.isNotEmpty;
    final cartHighlightColor = Colors.orange.shade300;
    final table =
        context.select<AppState, String?>((s) => s.guestTable) ?? '-';

    final brands = menuData.items
        .where((i) =>
            i['category'] == widget.category &&
            (i['name'] as String).isNotEmpty)
        .toList();

    final variants = selectedBrand == null
        ? <dynamic>[]
        : (selectedBrand!['variants'] as List);

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/Image.png',
            repeat: ImageRepeat.repeat,
            fit: BoxFit.none,
            color: Colors.black.withValues(alpha: 0.32),
            colorBlendMode: BlendMode.darken,
          ),
        ),
        Positioned.fill(
          child: Container(
            color: const Color(0xFF0F0F12).withValues(alpha: 0.78),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leadingWidth: isOwner ? null : 170,
            leading: isOwner
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BackButton(),
                      _TableBadge(text: table),
                    ],
                  ),
            title: Text(widget.category),
            actions: [
              if (!isOwner) ...[
                IconButton(
                  icon: Icon(
                    Icons.shopping_cart,
                    color: hasCartItems ? cartHighlightColor : null,
                  ),
                  onPressed: () => openCartSidePanel(context),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Text(
                      '¥${NumberFormat('#,###').format(cart.total)}',
                      style: TextStyle(
                        color: hasCartItems ? cartHighlightColor : null,
                        fontWeight: hasCartItems ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.receipt_long),
                tooltip: '注文履歴',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GuestOrderHistoryPage(),
                    ),
                  );
                },
              ),
              
            ],
          ),
          body: Row(
            children: [
              // =========================
              // 左：銘柄一覧（brands）
              // =========================
              SizedBox(
                width: 260,
                child: isOwner
                    ? ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: brands.length + 1,
                        onReorder: (oldIndex, newIndex) {
                          if (oldIndex == brands.length) return;
                          if (newIndex > brands.length) {
                            newIndex = brands.length;
                          }
                          if (newIndex > oldIndex) newIndex--;
                          menuData.reorderBrands(
                              widget.category, oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          if (index == brands.length) {
                            return Padding(
                              key: const ValueKey('__add_brand__'),
                              padding:
                                  const EdgeInsets.fromLTRB(12, 8, 12, 16),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _PlusRow(
                                  text: '銘柄を追加',
                                  onTap: () => _addBrand(context),
                                ),
                              ),
                            );
                          }

                          final b = brands[index];

                          return ListTile(
                            key: ValueKey(b),
                            title: Text(
                              b['name'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            selected: selectedBrand == b,
                            onTap: () => setState(() => selectedBrand = b),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'edit') {
                                      _renameBrand(context, b);
                                    } else if (v == 'delete') {
                                      menuData.removeBrand(b);
                                      if (selectedBrand == b) {
                                        setState(() => selectedBrand = null);
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'edit', child: Text('名前変更')),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        '削除',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Icon(Icons.drag_handle),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : ListView(
                        children: brands.map((b) {
                          return ListTile(
                            title: Text(b['name']),
                            selected: selectedBrand == b,
                            onTap: () =>
                                setState(() => selectedBrand = b),
                          );
                        }).toList(),
                      ),
              ),

              // =========================
              // 右：種類（variants）
              // =========================
              Expanded(
                child: selectedBrand == null
                    ? const Center(child: Text('銘柄を選択してください'))
                    : isOwner
                        ? ReorderableListView.builder(
                            buildDefaultDragHandles: false,
                            itemCount: variants.length + 1,
                            onReorder: (oldIndex, newIndex) {
                              if (oldIndex == variants.length) return;
                              if (newIndex > variants.length) {
                                newIndex = variants.length;
                              }
                              if (newIndex > oldIndex) newIndex--;
                              menuData.reorderVariants(
                                  selectedBrand!, oldIndex, newIndex);
                            },
                            itemBuilder: (context, index) {
                              if (index == variants.length) {
                                return Padding(
                                  key:
                                      const ValueKey('__add_variant__'),
                                  padding:
                                      const EdgeInsets.fromLTRB(
                                          16, 8, 16, 16),
                                  child: Align(
                                    alignment:
                                        Alignment.centerLeft,
                                    child: _PlusRow(
                                      text: '種類を追加',
                                      onTap: () =>
                                          _addVariant(context),
                                    ),
                                  ),
                                );
                              }

                              final v = variants[index]
                                  as Map<String, dynamic>;

                              return ListTile(
                                key: ValueKey(v),
                                 title: Text(v['label']),
                                subtitle: Text(formatYen(v['price'])),
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => OwnerAddItemSheet(
                                      label: v['label'],
                                    ),
                                  );
                                },
                                trailing: Padding(
                                  padding: const EdgeInsets.only(right: 24),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      PopupMenuButton<String>(
                                        onSelected: (val) {
                                          if (val == 'edit') {
                                            _editVariant(context, v);
                                          } else if (val == 'delete') {
                                            menuData.removeVariant(
                                                selectedBrand!, v);
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                              value: 'edit',
                                              child: Text('編集')),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Text(
                                              '削除',
                                              style: TextStyle(
                                                  color: Colors.red),
                                            ),
                                          ),
                                        ],
                                      ),
                                      ReorderableDragStartListener(
                                        index: index,
                                        child: const Icon(Icons.drag_handle),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : ListView.separated(
                            itemCount: variants.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final v = variants[index]
                                  as Map<String, dynamic>;

                              return ListTile(
                                title: Text(v['label']),
                                 trailing: Text(
  formatYen(v['price']),
  style: const TextStyle(
    fontSize: 22,              // ← 大きく
    fontWeight: FontWeight.bold, // ← 太く
  ),
),

                               onTap: () {
                                  cart.add(
                                    category: widget.category,
                                    brand:
                                        selectedBrand!['name'],
                                    label: v['label'],
                                    price: v['price'],
                                    printGroup: (v['printGroup'] ?? 'kitchen')
                                        .toString(),
                                  );
                                  _showAddedToCartNotice(v['label'] as String);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================
  // dialogs
  // =========================

  void _addBrand(BuildContext context) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('銘柄追加'),
        content: TextField(controller: c),
        actions: [
          ElevatedButton(
            onPressed: () {
              context
                  .read<MenuData>()
                  .addBrand(widget.category, c.text);
              Navigator.pop(context);
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  void _renameBrand(BuildContext context, Map<String, dynamic> b) {
    final c = TextEditingController(text: b['name']);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('名前変更'),
        content: TextField(controller: c),
        actions: [
          ElevatedButton(
            onPressed: () {
              context
                  .read<MenuData>()
                  .renameBrand(b, c.text);
              Navigator.pop(context);
            },
            child: const Text('変更'),
          ),
        ],
      ),
    );
  }
  //////////////////////////////////////
  void _addVariant(BuildContext context) {
  if (selectedBrand == null) return;

  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  String printGroup = 'kitchen'; // ★ デフォルト

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('種類追加'),
      content: StatefulBuilder(
        builder: (context, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '名前'),
              ),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: '価格'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '印刷先',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              RadioListTile<String>(
                title: const Text('厨房（通常）'),
                value: 'kitchen',
                groupValue: printGroup,
                onChanged: (v) => setState(() => printGroup = v!),
              ),
              RadioListTile<String>(
                title: const Text('レジ（特殊・高額）'),
                value: 'register',
                groupValue: printGroup,
                onChanged: (v) => setState(() => printGroup = v!),
              ),
            ],
          );
        },
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            final price = int.tryParse(priceCtrl.text) ?? 0;

            context.read<MenuData>().addVariant(
              selectedBrand!,
              nameCtrl.text,
              price,
              printGroup: printGroup, // ★ 追加
            );

            Navigator.pop(context);
          },
          child: const Text('追加'),
        ),
      ],
    ),
  );
}

   ////////////////////////////
  void _editVariant(BuildContext context, Map<String, dynamic> v) {
  final nameCtrl = TextEditingController(text: v['label']);
  final priceCtrl =
      TextEditingController(text: v['price'].toString());

  String printGroup = v['printGroup'] ?? 'kitchen';

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('編集'),
      content: StatefulBuilder(
        builder: (context, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '印刷先',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              RadioListTile<String>(
                title: const Text('厨房（通常）'),
                value: 'kitchen',
                groupValue: printGroup,
                onChanged: (v) => setState(() => printGroup = v!),
              ),
              RadioListTile<String>(
                title: const Text('レジ（特殊・高額）'),
                value: 'register',
                groupValue: printGroup,
                onChanged: (v) => setState(() => printGroup = v!),
              ),
            ],
          );
        },
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            final price = int.tryParse(priceCtrl.text) ?? 0;
             final menu = context.read<MenuData>(); // ← ★これを必ず入れる
            context.read<MenuData>().updateVariant(
              v,
              nameCtrl.text,
              price,
              printGroup: printGroup, // ★ 追加
            );
             menu.save(); 
            Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}

}



class PrinterSettingsPage extends StatefulWidget {
  final Future<Map<String, dynamic>> Function() loadSettings;
  final Future<void> Function(Map<String, dynamic>) saveSettings;

  const PrinterSettingsPage({
    super.key,
    required this.loadSettings,
    required this.saveSettings,
  });

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}
class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  Map<String, dynamic> settings = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await widget.loadSettings();
    setState(() {
      settings = s;
      loading = false;
    });
  }

  Future<void> _save() async {
    await widget.saveSettings(settings);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('保存しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('プリンター設定'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
          )
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Kitchen Printer'),
            subtitle: Text(settings['kitchen'] ?? '-'),
          ),
          ListTile(
            title: const Text('Register Printer'),
            subtitle: Text(settings['register'] ?? '-'),
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
      margin: const EdgeInsets.only(left: 6),
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}
class _PlusRow extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _PlusRow({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 18),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}