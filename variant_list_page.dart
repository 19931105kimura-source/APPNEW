import 'package:flutter/material.dart';

class VariantListPage extends StatelessWidget {
  final String brandName;
  final List variants;

  const VariantListPage({
    super.key,
    required this.brandName,
    required this.variants,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          brandName,
          style: const TextStyle(
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: variants.length,
        itemBuilder: (context, index) {
          final v = variants[index];
          return _VariantRow(
            label: v['label'],
            price: v['price'],
          );
        },
      ),
    );
  }
}

class _VariantRow extends StatelessWidget {
  final String label;
  final int price;

  const _VariantRow({
    required this.label,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            '$price 円',
            style: TextStyle(
              color: Colors.grey.shade300,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
