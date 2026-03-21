import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/cast_data.dart';
import '../data/cast_drink_data.dart';
import '../utils/price_format.dart';

// ===== 結果データ =====
class CastDrinkResult {
  final String drinkName;
  final String strength;
  final String castName;
  final int price;

  CastDrinkResult({
    required this.drinkName,
    required this.strength,
    required this.castName,
    required this.price,
  });
}

class CastDrinkFlowPage extends StatefulWidget {
  /// 表示・結果で使う価格
  final int price;

  /// 事前選択ドリンク名（オーナー用）
  final String? presetDrinkName;

  /// オーナー用：商品選択をスキップ
  final bool skipDrinkSelect;

  const CastDrinkFlowPage({
    super.key,
    this.price = 3000,
    this.presetDrinkName,
    this.skipDrinkSelect = false,
  });

  @override
  State<CastDrinkFlowPage> createState() => _CastDrinkFlowPageState();
}


class _CastDrinkFlowPageState extends State<CastDrinkFlowPage> {
  int step = 0;

  CastDrinkItem? selectedDrink;
  String? selectedStrength;
  String? selectedCast;

  CastDrinkItem? openedDrink;

  @override
  Widget build(BuildContext context) {
    // ✅ presetDrinkName がある場合は build で初期化（context参照OK）
    if (widget.presetDrinkName != null && selectedDrink == null) {
      final items = context.read<CastDrinkData>().items;
      final hit = items.where((e) => e.name == widget.presetDrinkName).toList();
      if (hit.isNotEmpty) {
        selectedDrink = hit.first;
        openedDrink = hit.first;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('キャストドリンク'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (step > 0) {
              setState(() => step--);
            } else {
              Navigator.pop(context); // キャンセル
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildStep(context),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (step) {
      case 0:
        return _stepDrinkWithStrength(context);
      case 1:
        return _stepCast(context);
      default:
        return const SizedBox();
    }
  }

  Widget _strengthOnly(BuildContext context, CastDrinkItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          item.name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: item.strengths.map((s) {
              return Card(
                child: ListTile(
                  title: Text(s),
                  subtitle: Text(formatYen(selectedDrink?.price ?? 0))
,
                  onTap: () {
                    setState(() {
                      selectedStrength = s;
                      step = 1; // 次はキャスト選択
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

  // =========================
  // STEP 1：ドリンク + 濃さ
  // =========================
  Widget _stepDrinkWithStrength(BuildContext context) {
    final castDrinkData = context.watch<CastDrinkData>();
    final items = castDrinkData.items;

    // オーナー用：商品選択をスキップして濃さから
    if (widget.skipDrinkSelect && selectedDrink != null) {
      return _strengthOnly(context, selectedDrink!);
    }

    if (items.isEmpty) {
      return const Center(child: Text('キャストドリンクがありません'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '飲み物を選択',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final opened = openedDrink == item;

              return Card(
                child: Column(
                  children: [
                    ListTile(
  title: Text(
    '${item.name}（${formatYen(item.price)}）',
    style: const TextStyle(fontSize: 18),
  ),
  trailing: Icon(opened ? Icons.expand_less : Icons.expand_more),
  onTap: () {
    setState(() {
      openedDrink = opened ? null : item;
      selectedDrink = item;
      selectedStrength = null;
    });
  },
),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: !opened
                          ? const SizedBox()
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Row(
                                children: item.strengths.map((s) {
                                  final selected = selectedStrength == s;
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              selected ? Colors.amber : Colors.grey.shade200,
                                          foregroundColor: Colors.black,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            selectedStrength = s;
                                            step = 1;
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          child: Text(
                                            s,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // =========================
  // STEP 2：キャスト選択 → 結果を返す
  // =========================
  Widget _stepCast(BuildContext context) {
    final casts = context.watch<CastData>().casts;

    final bool canSubmit =
        selectedDrink != null && selectedStrength != null && selectedCast != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'キャストを選択',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: casts.length,
            itemBuilder: (context, index) {
              final name = casts[index];
              final selected = selectedCast == name;

              return Card(
                child: ListTile(
                  title: Text(name, style: const TextStyle(fontSize: 18)),
                  trailing: selected ? const Icon(Icons.check, color: Colors.green) : null,
                  onTap: () => setState(() => selectedCast = name),
                ),
              );
            },
          ),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
  '飲み物：${selectedDrink?.name ?? '-'}（${formatYen(selectedDrink?.price ?? 0)}）',
),

                Text('濃さ：${selectedStrength ?? '-'}'),
                Text('キャスト：${selectedCast ?? '-'}'),
                const SizedBox(height: 8),
               Text(
              formatYen(selectedDrink?.price ?? 0),
  style: const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),

              ],
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
          ),
          onPressed: !canSubmit
              ? null
              : () {
                  final result = CastDrinkResult(
                    drinkName: selectedDrink!.name,
                    strength: selectedStrength!,
                    castName: selectedCast!,
                    price: selectedDrink!.price,

                  );

                  // ✅ 結果だけ返す（ここでカートにも伝票にも入れない）
                  Navigator.pop(context, result);
                },
          child: const Text(
            '確定',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
