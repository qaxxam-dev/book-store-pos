class Book {
  final int? id;
  final String title;
  final String? subtitle;
  final double price;
  final String sku;
  final int stockQuantity;
  final String? author;
  final String? publisher;
  final String? category;
  final String? description;
  final String? isbn;

  Book({
    this.id,
    required this.title,
    this.subtitle,
    required this.price,
    required this.sku,
    required this.stockQuantity,
    this.author,
    this.publisher,
    this.category,
    this.description,
    this.isbn,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'price': price,
      'sku': sku,
      'stock_quantity': stockQuantity,
      'author': author,
      'publisher': publisher,
      'category': category,
      'description': description,
      'isbn': isbn,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      title: map['title'],
      subtitle: map['subtitle'],
      price: map['price'],
      sku: map['sku'],
      stockQuantity: map['stock_quantity'],
      author: map['author'],
      publisher: map['publisher'],
      category: map['category'],
      description: map['description'],
      isbn: map['isbn'],
    );
  }
  Book copyWith({
    int? id,
    String? title,
    String? subtitle,
    double? price,
    String? sku,
    int? stockQuantity,
    String? author,
    String? publisher,
    String? category,
    String? description,
    String? isbn,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      price: price ?? this.price,
      sku: sku ?? this.sku,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      author: author ?? this.author,
      publisher: publisher ?? this.publisher,
      category: category ?? this.category,
      description: description ?? this.description,
      isbn: isbn ?? this.isbn,
    );
  }
}
