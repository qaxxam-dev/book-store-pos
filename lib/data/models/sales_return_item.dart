class SalesReturnItem {
  final int? id;
  final int returnId;
  final int bookId;
  final int quantity;
  final double refundAmount;

  SalesReturnItem({
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

  factory SalesReturnItem.fromMap(Map<String, dynamic> map) {
    return SalesReturnItem(
      id: map['id'],
      returnId: map['return_id'],
      bookId: map['book_id'],
      quantity: map['quantity'],
      refundAmount: map['refund_amount'],
    );
  }
}
