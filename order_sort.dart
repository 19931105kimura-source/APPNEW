import '../state/order_state.dart';

List<OrderLine> sortOrderLines(List<OrderLine> lines) {
  final list = List<OrderLine>.from(lines);

  int priority(OrderLine l) {
    if (l.category == 'セット') return 1;
    if (l.subCategory == '延長') return 2;
    if (l.subCategory == '本指名') return 3;
    if (l.subCategory == '場内指名') return 4;
    if (l.subCategory == '同伴') return 5;

    if (l.category == 'キャストドリンク') return 6;
    if (l.category == 'メニュー') return 7;

    return 99;
  }

  list.sort((a, b) {
    final pa = priority(a);
    final pb = priority(b);

    if (pa != pb) return pa.compareTo(pb);

    // キャストドリンク・通常メニューは金額順
    if (pa >= 6) {
      return b.price.compareTo(a.price);
    }

    return 0;
  });

  return list;
}
