import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'owner_category_page.dart';
import 'guest_category_page.dart';

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<AppState>().mode;

    if (mode == UserMode.owner) {
      return const OwnerCategoryPage();
    } else {
      return const GuestCategoryPage();
    }
  }
}
