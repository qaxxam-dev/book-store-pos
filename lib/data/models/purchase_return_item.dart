class PurchaseReturnItem {
  final int? id;
  final int returnId;
  final int bookId;
  final int quantity;
  final double refundAmount;

  PurchaseReturnItem({
    this.id,
    required this.returnId,
    required this.bookId,
    required this.quantity,
    required this.refundAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'return_id': returnId,
      'book_id': bookId,
      'quantity': quantity,
      'refund_amount': refundAmount,
    };
  }

  factory PurchaseReturnItem.fromMap(Map<String, dynamic> map) {
    return PurchaseReturnItem(
      id: map['id'],
      returnId: map['return_id'],
      bookId: map['book_id'],
      quantity: map['quantity'],
      refundAmount: map['refund_amount'],
    );
  }
}
