import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/menu_data.dart';
import '../state/app_state.dart';
import 'brand_list_page.dart';
import 'login_page.dart';

class OwnerCategoryPage extends StatelessWidget {
  const OwnerCategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<AppState>().mode;

    // =========================
    // 🔒 侵入防止
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

    final menuData = context.watch<MenuData>();
    final categories = menuData.categories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CATEGORY（管理）'),
        actions: [
          // =========================
          // 💾 保存ボタン（完成版）
          // =========================
          TextButton(
            onPressed: () async {
              await context.read<MenuData>().save();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('保存しました')),
              );
            },
            child: const Text(
              '保存',
              style: TextStyle(color: Colors.white),
            ),
          ),

          // =========================
          // 🚪 ログアウト
          // =========================
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AppState>().logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),

      // =========================
      // ★ 左端から画面半分だけ使う
      // =========================
      body: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: 0.5,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 12,
              ),
              itemCount: categories.length + 1,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex == categories.length ||
                    newIndex > categories.length) {
                  return;
                }
                context
                    .read<MenuData>()
                    .reorderCategories(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                // ===== カテゴリ追加 =====
                if (index == categories.length) {
                  return Card(
                    key: const ValueKey('__add_category__'),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('カテゴリを追加'),
                      onTap: () => _addCategory(context),
                    ),
                  );
                }

                final category = categories[index];

                return Card(
                  key: ValueKey('cat_$category'),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              BrandListPage(category: category),
                        ),
                      );
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () =>
                              _editCategory(context, category),
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
            ),
          ),
        ),
      ),
    );
  }

  // =========================
  // カテゴリ追加
  // =========================
  void _addCategory(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('カテゴリ追加'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<MenuData>().addCategory(ctrl.text);
              Navigator.pop(context);
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  // =========================
  // 編集 / 削除
  // =========================
  void _editCategory(BuildContext context, String category) {
    final ctrl = TextEditingController(text: category);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(category),
        content: TextField(
          controller: ctrl,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              context
                  .read<MenuData>()
                  .renameCategory(category, ctrl.text);
              Navigator.pop(context);
            },
            child: const Text('名前変更'),
          ),
          TextButton(
            onPressed: () {
              context.read<MenuData>().removeCategory(category);
              Navigator.pop(context);
            },
            child: const Text(
              '削除',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
