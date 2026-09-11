class SaleItem {
  final int? id;
  final int saleId;
  final int bookId;
  final int quantity;
  final double priceAtSale;

  SaleItem({
    this.id,
    required this.saleId,
    required this.bookId,
    required this.quantity,
    required this.priceAtSale,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'book_id': bookId,
      'quantity': quantity,
      'price_at_sale': priceAtSale,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'],
      saleId: map['sale_id'],
      bookId: map['book_id'],
      quantity: map['quantity'],
      priceAtSale: map['price_at_sale'],
    );
  }
}
