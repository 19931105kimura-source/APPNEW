import 'package:flutter/material.dart';

class OwnerAddItemSheet extends StatelessWidget {
  final String label;

  const OwnerAddItemSheet({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }
}


