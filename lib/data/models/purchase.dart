class Purchase {
  final int? id;
  final int distributorId;
  final String billNumber;
  final double totalAmount;
  final double discount;
  final String paymentMethod;
  final String timestamp;

  Purchase({
    this.id,
    required this.distributorId,
    required this.billNumber,
    required this.totalAmount,
    this.discount = 0.0,
    required this.paymentMethod,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'distributor_id': distributorId,
      'bill_number': billNumber,
      'total_amount': totalAmount,
      'discount': discount,
      'payment_method': paymentMethod,
      'timestamp': timestamp,
    };
  }

  factory Purchase.fromMap(Map<String, dynamic> map) {
    return Purchase(
      id: map['id'],
      distributorId: map['distributor_id'],
      billNumber: map['bill_number'],
      totalAmount: map['total_amount'],
      discount: map['discount'],
      paymentMethod: map['payment_method'],
      timestamp: map['timestamp'],
    );
  }
  Purchase copyWith({
    int? id,
    int? distributorId,
    String? billNumber,
    double? totalAmount,
    double? discount,
    String? paymentMethod,
    String? timestamp,
  }) {
    return Purchase(
      id: id ?? this.id,
      distributorId: distributorId ?? this.distributorId,
      billNumber: billNumber ?? this.billNumber,
      totalAmount: totalAmount ?? this.totalAmount,
      discount: discount ?? this.discount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
