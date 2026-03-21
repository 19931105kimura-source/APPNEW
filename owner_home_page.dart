import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'owner_category_page.dart';
import 'owner_tables_page.dart';
import 'login_page.dart';
import 'owner_promo_page.dart'; // ✅ 追加
import 'owner_cast_page.dart';
import 'owner_cast_drink_page.dart';
import 'set_edit_page.dart';
import 'owner_other_item_edit_page.dart'; // ✅ 追加
import 'owner_printer_settings.dart';
  


class OwnerHomePage extends StatelessWidget {
  const OwnerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<AppState>().mode;

    // =========================
    // 🔒 侵入防止（最重要）
    // =========================
    if (mode != UserMode.owner) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      });

      return const Scaffold(
        body: Center(child: Text('権限がありません')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('オーナーモード'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
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

              if (!context.mounted) return;

              if (ok == true) {
                context.read<AppState>().logout();
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

      // ✅ ここを「小さめカード」に最適化
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, c) {
            // 画面幅で列数を自動調整（PC=3 / 狭いと2）
            final cols = c.maxWidth >= 900 ? 3 : 2;

            return GridView(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
                mainAxisExtent: 140, // ✅ 箱の高さ（小さくしたいなら 120〜150 で調整）
              ),
              children: [
                _MenuCard(
                  icon: Icons.menu_book,
                  title: 'メニュー編集',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OwnerCategoryPage()),
                    );
                  },
                ),
                _MenuCard(
                  icon: Icons.table_bar,
                  title: 'テーブル管理',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OwnerTablePage()),
                    );
                  },
                ),
                _MenuCard(
                  icon: Icons.campaign,
                  title: '宣伝編集（画像）',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OwnerPromoPage()),
                    );
                  },
                ),
             _MenuCard(
  icon: Icons.people,
  title: 'キャスト管理',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OwnerCastPage()),
    );
  },
),
_MenuCard(
  icon: Icons.local_bar,
  title: 'キャストドリンク編集',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OwnerCastDrinkPage()),
    );
  },
),
   _MenuCard(
  icon: Icons.inventory_2,
  title: 'セット編集',
  onTap: () {


  Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const OwnerSetEditPage(),
  ),
);

},

),
       _MenuCard(
  icon: Icons.print,
  title: 'プリンターIP設定',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OwnerPrinterSettingsPage()),
    );
  },
),
       _MenuCard(
  icon: Icons.edit,
  title: 'その他編集',

  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OwnerOtherItemEditPage()),
    );
  },
),

             
             
             
              ],

            );
          },
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // ✅ 余白を最適化
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade400,
            width: 2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ ここは「アイコン」じゃなくても、表示をコンパクトにするため少し詰める
              Icon(icon, size: 28),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16, // ✅ 20→16（箱を小さくしても崩れない）
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
