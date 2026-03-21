// lib/state/shared_order_repository.dart
import '../model/order.dart';

abstract class SharedOrderRepository {
  Future<void> addOrder(Order order);

  Stream<List<Order>> watchOrdersByTable(String tableId);

  Stream<int> watchTotalByTable(String tableId);

  Future<void> clearByTable(String tableId);
}
