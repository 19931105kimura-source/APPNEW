// lib/model/order.dart
class OrderLine {
  final String category;
  final String brand;
  final String label;
  final int price;
  final int qty;

  OrderLine({
    required this.category,
    required this.brand,
    required this.label,
    required this.price,
    required this.qty,
  });

  OrderLine copyWith({int? qty}) => OrderLine(
        category: category,
        brand: brand,
        label: label,
        price: price,
        qty: qty ?? this.qty,
      );

  Map<String, dynamic> toJson() => {
        'category': category,
        'brand': brand,
        'label': label,
        'price': price,
        'qty': qty,
      };

  static OrderLine fromJson(Map<String, dynamic> j) => OrderLine(
        category: j['category'],
        brand: j['brand'],
        label: j['label'],
        price: j['price'],
        qty: j['qty'],
      );
}

class Order {
  final String id;
  String table;
  final DateTime createdAt;
  final List<OrderLine> lines;

  Order({
    required this.id,
    required this.table,
    required this.createdAt,
    required this.lines,
  });

  int get total => lines.fold(0, (s, l) => s + l.price * l.qty);

  Map<String, dynamic> toJson() => {
        'id': id,
        'table': table,
        'createdAt': createdAt.toIso8601String(),
        'lines': lines.map((e) => e.toJson()).toList(),
      };

  static Order fromJson(Map<String, dynamic> j) => Order(
        id: j['id'],
        table: j['table'],
        createdAt: DateTime.parse(j['createdAt']),
        lines: (j['lines'] as List)
            .map((e) => OrderLine.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}
