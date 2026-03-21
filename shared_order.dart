// lib/model/shared_order.dart

class OrderItem {
  final String category;
  final String brand;
  final String label;
  final int price;
  final int qty;
  final String section; // 例：案内所 / フロア
 
  const OrderItem({
    required this.category,
    required this.brand,
    required this.label,
    required this.price,
    required this.qty,
    this.section = '', // ← これで通常商品も壊れない
  });

  int get subtotal => price * qty;
}

class Order {
  final String id;
  final String tableId;
  final DateTime createdAt;
  final List<OrderItem> items;

  const Order({
    required this.id,
    required this.tableId,
    required this.createdAt,
    required this.items,
  });

  int get total =>
      items.fold(0, (sum, i) => sum + i.subtotal);
}
