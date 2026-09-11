class PurchaseItem {
  final int? id;
  final int purchaseId;
  final int bookId;
  final int quantity;
  final double costPrice;

  PurchaseItem({
    this.id,
    required this.purchaseId,
    required this.bookId,
    required this.quantity,
    required this.costPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_id': purchaseId,
      'book_id': bookId,
      'quantity': quantity,
      'cost_price': costPrice,
    };
  }

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id'],
      purchaseId: map['purchase_id'],
      bookId: map['book_id'],
      quantity: map['quantity'],
      costPrice: map['cost_price'],
    );
  }
}
