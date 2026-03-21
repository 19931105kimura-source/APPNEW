import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/server_config.dart';

import '../state/order_state.dart';
import '../data/menu_data.dart';
import '../state/set_data.dart';
import '../data/cast_drink_data.dart';
import '../data/other_item_data.dart';
import 'cast_drink_flow_page.dart';
import '../../billing/billing_calculator.dart';
import '../utils/price_format.dart';
import '../utils/order_sort.dart'; // 追加
import 'owner_confirm_add_dialog.dart';
import 'dart:convert';                    // ← jsonEncode
import 'package:http/http.dart' as http; // ← http.patch


enum OwnerAddCategory {
  menu, // 通常メニュー
  cast, // キャストドリンク
  set, // セット
  other, // その他
  free, // ← ★ これを追加
}


class OwnerAddOrderPage extends StatefulWidget {
  final String table;


  const OwnerAddOrderPage({super.key, required this.table});
  @override
  State<OwnerAddOrderPage> createState() => _OwnerAddOrderPageState();
}

class _OwnerAddOrderPageState extends State<OwnerAddOrderPage> {
  OwnerAddCategory category = OwnerAddCategory.menu;
  final TextEditingController _freeNameCtrl = TextEditingController();
  final TextEditingController _freePriceCtrl = TextEditingController();
  // =========================
  // 通常メニュー（カテゴリ→銘柄→種類）
  // =========================
  String? _selectedMenuCategory;
  Map<String, dynamic>? _selectedMenuBrand;

  // =========================
  // キャストドリンク（商品→濃さ）
  // =========================
  CastDrinkItem? _selectedCastDrink;

  // =========================
  // セット
  // =========================
  Map<String, dynamic>? _selectedSet;


  // =========================
  // その他（カテゴリ→商品）
  // =========================
  String? _selectedOtherCategory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('注文追加（${widget.table}）'),
      ),
      body: Row(
        children: [
          // =====================
          // 左：カテゴリ
          // =====================
          SizedBox(
            width: 200,
            child: ListView(
              children: [
                _catTile('通常メニュー', OwnerAddCategory.menu),
                _catTile('キャストドリンク', OwnerAddCategory.cast),
                _catTile('セット', OwnerAddCategory.set),
                _catTile('その他', OwnerAddCategory.other),
                _catTile('自由入力', OwnerAddCategory.free),

              ],
            ),
          ),

          const VerticalDivider(width: 1),

          // =====================
          // 中央：商品一覧
          // =====================
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildItems(context),
            ),
          ),

          const VerticalDivider(width: 1),

          // =====================
          // 右：伝票
          // =====================
          Expanded(
            flex: 2,
            child: _OrderSlipPanel(table: widget.table),
          ),
        ],
      ),
    );
  }

  // =========================
  // カテゴリタイル
  // =========================
  Widget _catTile(String text, OwnerAddCategory c) {
    final selected = category == c;
    return ListTile(
      title: Text(
        text,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: selected,
      onTap: () => setState(() {
        category = c;

        // 事故防止：途中状態リセット
        _selectedMenuCategory = null;
        _selectedMenuBrand = null;

        _selectedCastDrink = null;

        _selectedSet = null;


        _selectedOtherCategory = null;
      }),
    );
  }

  // =========================
  // 中央：表示切り替え
  // =========================
  Widget _buildItems(BuildContext context) {
    switch (category) {
      case OwnerAddCategory.menu:
        return _menuItems(context);
      case OwnerAddCategory.cast:
        return _castDrinkItems(context);
      case OwnerAddCategory.set:
        return _setItems(context);
      case OwnerAddCategory.other:
        return _otherItems(context);
      case OwnerAddCategory.free:
        return _freeInputItems(context);

    }
  }

  // ============================================================
  // 通常メニュー（カテゴリ → 銘柄 → 種類）
  // ※ type == normal のみ表示（キャストドリンクは出さない）
  // ============================================================
  Widget _menuItems(BuildContext context) {
    final menuData = context.watch<MenuData>();

    // ✅ 通常メニューのみ抽出
    final normalItems = menuData.items.where((item) {
      final type = (item['type'] ?? 'normal').toString();
      return type == 'normal';
    }).toList();

    if (normalItems.isEmpty) {
      return const Center(child: Text('メニューがありません'));
    }

    // -------------------------
    // ① カテゴリ未選択：カテゴリ一覧
    // -------------------------
    if (_selectedMenuCategory == null) {
      final categories = normalItems
          .map((i) => (i['category'] ?? '').toString())
          .where((s) => s.trim().isNotEmpty)
          .toSet()
          .toList();

      categories.sort();

      return ListView(
        children: categories.map((cat) {
          return Card(
            child: ListTile(
              title: Text(
                cat,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                setState(() {
                  _selectedMenuCategory = cat;
                  _selectedMenuBrand = null; // 念のため
                });
              },
            ),
          );
        }).toList(),
      );
    }

    // -------------------------
    // ② 銘柄未選択：銘柄一覧
    // -------------------------
    final brandsInCategory = normalItems
        .where((i) => (i['category'] ?? '').toString() == _selectedMenuCategory)
        .where((i) => (i['name'] ?? '').toString().trim().isNotEmpty)
        .toList();

    if (_selectedMenuBrand == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedMenuCategory = null;
                _selectedMenuBrand = null;
              });
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('カテゴリー一覧に戻る'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _selectedMenuCategory!,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: brandsInCategory.isEmpty
                ? const Center(child: Text('銘柄がありません'))
                : GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: brandsInCategory.map((b) {
                      final name = (b['name'] ?? '').toString();
                      return Card(
                        child: ListTile(
                          title: Text(name),
                          subtitle: const Text('タップして種類へ'),
                          onTap: () {
                            setState(() {
                              _selectedMenuBrand = b;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      );
    }

    // -------------------------
    // ③ 種類（variants）一覧
    // -------------------------
    final brandName = (_selectedMenuBrand!['name'] ?? '').toString();
    final variants = (_selectedMenuBrand!['variants'] as List?) ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () {
            setState(() {
              _selectedMenuBrand = null;
            });
          },
          icon: const Icon(Icons.arrow_back),
          label: const Text('銘柄一覧に戻る'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            brandName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: variants.isEmpty
              ? const Center(child: Text('種類がありません'))
              : GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: variants.map((v) {
                    final vm = Map<String, dynamic>.from(v as Map);
                    final label = (vm['label'] ?? '').toString();
                    final price = (vm['price'] ?? 0) as int;

                    return Card(
                      child: ListTile(
                        title: Text(label),
                        subtitle: Text(formatYen(price)),

       /////////////////////////////////////////////////////
                       onTap: () async {
  final result =
      await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => OwnerConfirmAddDialog(
      label: label,
      price: price,
    ),
  );

  if (result == null) return;
  if (!context.mounted) return;
  final qty = result['qty'] as int;
  final shouldPrint = result['shouldPrint'] as bool;

  await _add(

    category: 'メニュー',
    brand: brandName,
    label: label,
    price: price,
    qty: qty,
    printGroup: (vm['printGroup'] ?? 'kitchen').toString(),
    // shouldPrint は次で OrderLine に入れる
    shouldPrint: shouldPrint, // ★ 追加
  );
}


                      ///////////////////////
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  // ============================================================
  // キャストドリンク（商品 → 濃さ → 注文追加）
  // ============================================================
  Widget _castDrinkItems(BuildContext context) {
    final castData = context.watch<CastDrinkData>();

    // ① 商品一覧
    if (_selectedCastDrink == null) {
      if (castData.items.isEmpty) {
        return const Center(child: Text('キャストドリンクがありません'));
      }

      return GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: castData.items.map((item) {
          final price = item.price;
// ←今は固定

          return Card(
            child: ListTile(
              title: Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(formatYen(price)),

                onTap: () async {
  // ① キャストドリンク選択画面を開く
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CastDrinkFlowPage(
        price: item.price,
        presetDrinkName: item.name,
        skipDrinkSelect: true,
      ),
    ),
  );

  // キャンセルされたら何もしない
  if (result == null) return;

  // ② 数量・印刷確認ダイアログを出す
  final dialogResult =
      await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => OwnerConfirmAddDialog(
      label: '${result.castName}（${result.strength}）',
      price: result.price,
    ),
  );

  // キャンセルされたら何もしない
  if (dialogResult == null) return;

  final qty = dialogResult['qty'] as int;
  final shouldPrint = dialogResult['shouldPrint'] as bool;

  // ③ ここで初めて注文を確定する
    await _add(

    category: 'キャストドリンク',
    brand: result.castName,
    label: '${result.drinkName}（${result.strength}）',
    price: result.price,
    qty: qty,
    shouldPrint: shouldPrint,
  );
                }



            ),
          );
        }).toList(),
      );
    }

    // ② 濃さ選択
    final drink = _selectedCastDrink!;
    final price = drink.price; // ← 修正// ←今は固定

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () {
            setState(() {
              _selectedCastDrink = null;
            });
          },
          icon: const Icon(Icons.arrow_back),
          label: const Text('商品一覧に戻る'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            drink.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: drink.strengths.map((strength) {
              return Card(
                child: ListTile(
                  title: Text(strength),
                  subtitle: Text(formatYen(price))
,
                  onTap: () async {
                   await _add(

                      category: 'キャストドリンク',
                      brand: drink.name,
                      label: strength,
                      price: price,
                    );
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }


// ============================================================
// セット（独立セット → 時間と料金）
// ・通常 / 案内所 / VIP は完全に別セット
// ・section（normal / agency / extension）は使わない
// ・選んだセット内の items をすべてまとめて表示
// ・行タップ＝即 注文追加
// ============================================================
 Widget _setItems(BuildContext context) {
  final setData = context.watch<SetData>();




  // -------------------------
  // ① セット未選択：セット一覧
  // -------------------------
  if (_selectedSet == null) {
 final sets = setData.sets;


    if (sets.isEmpty) {
      return const Center(child: Text('セットがありません'));
    }

    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: sets.map((set) {
        final name = (set['name'] ?? '').toString();

        return Card(
          child: ListTile(
            title: Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('タップして選択'),
            onTap: () {
              setState(() {
                _selectedSet = set;
              });
            },
          ),
        );
      }).toList(),
    );
  }

  // -------------------------
  // ② セット選択後：時間・料金一覧
  // （sections を全部まとめて表示）
  // -------------------------
  final setName = (_selectedSet!['name'] ?? '').toString();
  final sections = _selectedSet!['sections'] as Map<String, dynamic>;

  // section を跨いで全部集める
  final List<Map<String, dynamic>> items = [];
  for (final v in sections.values) {
    if (v is List) {
      for (final item in v) {
        if (item is Map<String, dynamic>) {
          items.add(item);
        }
      }
    }
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton.icon(
        onPressed: () {
          setState(() {
            _selectedSet = null;
          });
        },
        icon: const Icon(Icons.arrow_back),
        label: const Text('セット一覧に戻る'),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          setName,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      Expanded(
        child: items.isEmpty
            ? const Center(child: Text('項目がありません'))
            : GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: items.map((item) {
                  final label = (item['label'] ?? '').toString();
                  final price = (item['price'] ?? 0) as int;

                  return Card(
                    child: ListTile(
                      title: Text(label),
                      subtitle: Text(formatYen(price))
,
                     onTap: () async {
  // ★ 表示文言ではなく「固定キー」を決める
  String sub = '';
  if (label.contains('延長')) sub = '延長';
  if (label.contains('本指名')) sub = '本指名';
  if (label.contains('場内指名')) sub = '場内指名';
  if (label.contains('同伴')) sub = '同伴';

  // ★ 他のカテゴリと同様に確認ダイアログを出す
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => OwnerConfirmAddDialog(
      label: label,
      price: price,
    ),
  );
  if (result == null) return;
  if (!context.mounted) return;

  final qty = result['qty'] as int;
  final shouldPrint = result['shouldPrint'] as bool;

  await _add(
    category: 'セット',
    brand: setName,
    label: label,
    price: price,
    qty: qty,
    subCategory: sub,
    shouldPrint: shouldPrint,
  );
},

                    ),
                  );
                }).toList(),
              ),
      ),
    ],
  );
}




  // ============================================================
  // その他（カテゴリ → 商品）
  // ============================================================
  Widget _otherItems(BuildContext context) {
    final otherData = context.watch<OtherItemData>();

    if (_selectedOtherCategory == null) {
      final categories = otherData.categories;
      if (categories.isEmpty) {
        return const Center(child: Text('カテゴリがありません'));
      }

      return ListView(
        children: categories.map((cat) {
          return Card(
            child: ListTile(
              title: Text(
                cat,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                setState(() {
                  _selectedOtherCategory = cat;
                });
              },
            ),
          );
        }).toList(),
      );
    }

    final items = otherData.items
        .where((i) => i['category'] == _selectedOtherCategory)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () {
            setState(() {
              _selectedOtherCategory = null;
            });
          },
          icon: const Icon(Icons.arrow_back),
          label: const Text('カテゴリ一覧に戻る'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            _selectedOtherCategory!,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('商品がありません'))
              : GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: items.map((item) {
                    final name = (item['name'] ?? '').toString();
                    final price = (item['price'] ?? 0) as int;

                    return Card(
                      child: ListTile(
                        title: Text(name),
                        subtitle: Text(formatYen(price))
,
                                             onTap: ()async{
                          final skipPrint = name == '本指名' || name == '場内指名';
                          await _add(

                            category: 'その他',
                            brand: name,
                            label: '',
                            price: price,
                            subCategory: name, // ★ これを足すだけ
                            shouldPrint: !skipPrint,
                            printGroup: skipPrint ? 'none' : 'kitchen',
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  // =========================
  // 注文追加
  // =========================
 Future<void> _add(
 {
    required String category,
    required String brand,
    required String label,
    required int price,
    int qty = 1,
    String printGroup = 'kitchen',
    String subCategory = '', // ← 追加
    bool shouldPrint = true, // ★ 追加
  })  async{
    final ok = await context.read<OrderState>().addManual(
  table: widget.table,
  category: category,
  brand: brand,
  label: label,
  price: price,
  qty: qty,
  printGroup: printGroup,
  section: category == 'セット' ? '案内所' : '',
  subCategory: subCategory, // ← 追加
  shouldPrint: shouldPrint, // ★ 追加
);

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<OrderState>().buildSubmitErrorMessageJa()),
        ),
      );
    }

  }

Widget _freeInputItems(BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '自由入力（etc）',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),

      TextField(
        controller: _freeNameCtrl,
        decoration: const InputDecoration(
          labelText: '商品名',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),

      TextField(
        controller: _freePriceCtrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: '金額',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 16),
           ElevatedButton(
  onPressed: () async {
    final name = _freeNameCtrl.text.trim();
    final price = int.tryParse(_freePriceCtrl.text) ?? 0;

    if (name.isEmpty || price <= 0) return;

    await _add(

      category: 'その他',
      brand: name,
      label: '',
      price: price,
      subCategory: 'etc',
    );

    _freeNameCtrl.clear();
    _freePriceCtrl.clear();
  },
  child: const Text('伝票に追加'),
),

    ],
  );
}







}

// ===================================================
// 右側：伝票パネル
// ===================================================
class _OrderSlipPanel extends StatefulWidget {
  final String table;
  const _OrderSlipPanel({required this.table});

  @override
  State<_OrderSlipPanel> createState() => _OrderSlipPanelState();
}

class _OrderSlipPanelState extends State<_OrderSlipPanel> {
  bool _busy = false;

  void _showSyncFailedMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('変更を反映できませんでした。通信状態を確認して再試行してください。'),
      ),
    );
  }


  Future<bool> _rtUpdateQty({
  required String table,
  required OrderLine line,
  required int qty,
}) async {
  if (line.lineId == null) return false; // ★ 追加
  if (qty <= 0) {
    return _rtRemoveLine(table: table, line: line);
  }

  try {
    final uri = ServerConfig.api('/api/rt/tables/$table/items/${line.lineId}');

    final res = await http.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'qty': qty}),
    );

   if (res.statusCode != 200) {
      debugPrint('RT PATCH FAILED ${res.statusCode}');
      return false;
    }
    return true;
  } catch (e) {
    debugPrint('RT PATCH ERROR: $e');
    return false;
  }
}

Future<bool> _rtRemoveLine({
  required String table,
  required OrderLine line,
}) async {
  if (line.lineId == null) return false;

  try {
    final uri = ServerConfig.api('/api/rt/tables/$table/items/${line.lineId}');

    final res = await http.delete(uri);

     if (res.statusCode != 200) {
      debugPrint('RT DELETE FAILED ${res.statusCode}');
      return false;
    }
    return true;
  } catch (e) {
    debugPrint('RT DELETE ERROR: $e');
    return false;
  }
}

 int _orderPriority(OrderLine l) {
  // ★ その他の場合は subCategory で判定
  if (l.category == 'その他') {
    if (l.subCategory == '本指名') return 3;
    if (l.subCategory == '場内指名') return 4;
    if (l.subCategory == '同伴') return 5;
  }

  if (l.category == 'セット') return 1;
  if (l.category.contains('延長')) return 2;

  if (l.category == 'キャストドリンク') return 6;
  if (l.category == 'メニュー') return 7;

  return 99;
}



  @override
  Widget build(BuildContext context) {
    final orderState = context.watch<OrderState>();

final order = orderState.realtimeOrderForDisplay(widget.table);
    final billingTotal = order == null
        ? 0
        : BillingCalculator.calculateFromLines(order.lines).total;
    final lines = order == null
    ? <OrderLine>[]
    : sortOrderLines(order.lines);

lines.sort((a, b) {
  final pa = _orderPriority(a);
  final pb = _orderPriority(b);

  // 優先度が違う
  if (pa != pb) return pa.compareTo(pb);

  // キャストドリンク・通常メニューは金額順（高い→安い）
  if (pa >= 6) {
    return b.price.compareTo(a.price);
  }

  // それ以外は元の順
  return 0;
});


    return AbsorbPointer(
      absorbing: _busy,
      child: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.black12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '伝票',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: lines.isEmpty
                  ? const Center(child: Text('注文なし'))
                  : ListView.separated(
                      itemCount: lines.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 12),
                      itemBuilder: (context, i) {
                        final l = lines[i];
                         final cleanBrand = l.brand.trim() == 'RT'
                            ? ''
                            : l.brand.trim();
                        final cleanLabel = l.label.trim() == 'RT'
                            ? ''
                            : l.label.trim();
                        final title = [cleanBrand, cleanLabel]
                            .where((e) => e.isNotEmpty)
                            .join(' ');

                       return Row(
  children: [
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatYen(l.price),
            style: const TextStyle(color: Colors.amber),
          ),
        ],
      ),
    ),

    // − ボタン
   IconButton(
  icon: const Icon(Icons.remove),
  onPressed: () async {
    final isRT = context
        .read<OrderState>()
        .isRealtimeOrderId(order!.id);

    final newQty = l.qty - 1;

     if (isRT) {
      // ★ RT 注文 → サーバーに送る（後で中身を書く）
      final ok = await _rtUpdateQty(
        table: widget.table,
        line: l,
        qty: newQty,
      );
      if (!ok) _showSyncFailedMessage();
    } else {
      // ★ 従来どおり
      if (newQty <= 0) {
        final ok = await context.read<OrderState>().removeLine(order.id, l);
        if (!ok) _showSyncFailedMessage();
        if (!mounted) return;
      } else {
        final ok = await context.read<OrderState>().updateQty(order.id, l, newQty);
        if (!ok) _showSyncFailedMessage();
        if (!mounted) return;

      }
        }
  },
),

    // 削除ボタン
    IconButton(
      icon: const Icon(Icons.delete),
      onPressed: () async {
        final isRT = context
            .read<OrderState>()
            .isRealtimeOrderId(order!.id);

        if (isRT) {
          final ok = await _rtRemoveLine(
            table: widget.table,
            line: l,
          );
          if (!ok) _showSyncFailedMessage();
        } else {
          final ok = await context.read<OrderState>().removeLine(order.id, l);
          if (!ok) _showSyncFailedMessage();
          if (!mounted) return;
        }
      },
    ),


    // 数量表示
    Text(
      '${l.qty}',
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),

    // ＋ ボタン
   IconButton(
  icon: const Icon(Icons.add),
  onPressed: () async {
    final isRT = context
        .read<OrderState>()
        .isRealtimeOrderId(order!.id);

    if (isRT) {
      final ok = await _rtUpdateQty(
        table: widget.table,
        line: l,
        qty: l.qty + 1,
      );
      if (!ok) _showSyncFailedMessage();
    } else {
      final ok = await context
          .read<OrderState>()
          .updateQty(order.id, l, l.qty + 1);
      if (!ok) _showSyncFailedMessage();
      if (!mounted) return;
    }
  },
),

  ],
);

                      },
                    ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('合計'),
                Text(formatYenTruncatedToTen(billingTotal)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}