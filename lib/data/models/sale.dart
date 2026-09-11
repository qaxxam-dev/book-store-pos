class Sale {
  final int? id;
  final int? customerId;
  final String? guestPhone;
  final double totalAmount;
  final double discount;
  final double discountPercent;
  final String paymentMethod;
  final String timestamp;
  final String billNumber;
  final double shippingAmount;
  final String? customerName;
  final String? customerMobile;
  final String? customerAddress;

  Sale({
    this.id,
    this.customerId,
    this.guestPhone,
    required this.totalAmount,
    this.discount = 0.0,
    this.discountPercent = 0.0,
    required this.paymentMethod,
    required this.timestamp,
    required this.billNumber,
    this.shippingAmount = 0.0,
    this.customerName,
    this.customerMobile,
    this.customerAddress,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'guest_phone': guestPhone,
      'total_amount': totalAmount,
      'discount': discount,
      'discount_percent': discountPercent,
      'payment_method': paymentMethod,
      'timestamp': timestamp,
      'bill_number': billNumber,
      'shipping_amount': shippingAmount,
      'customer_name': customerName,
      'customer_mobile': customerMobile,
      'customer_address': customerAddress,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'],
      customerId: map['customer_id'],
      guestPhone: map['guest_phone'],
      totalAmount: map['total_amount'],
      discount: map['discount'] ?? 0.0,
      discountPercent: map['discount_percent'] ?? 0.0,
      paymentMethod: map['payment_method'],
      timestamp: map['timestamp'],
      billNumber: map['bill_number'],
      shippingAmount: map['shipping_amount'] ?? 0.0,
      customerName: map['customer_name'],
      customerMobile: map['customer_mobile'],
      customerAddress: map['customer_address'],
    );
  }
  Sale copyWith({
    int? id,
    int? customerId,
    String? guestPhone,
    double? totalAmount,
    double? discount,
    double? discountPercent,
    String? paymentMethod,
    String? timestamp,
    String? billNumber,
    double? shippingAmount,
    String? customerName,
    String? customerMobile,
    String? customerAddress,
  }) {
    return Sale(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      guestPhone: guestPhone ?? this.guestPhone,
      totalAmount: totalAmount ?? this.totalAmount,
      discount: discount ?? this.discount,
      discountPercent: discountPercent ?? this.discountPercent,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      timestamp: timestamp ?? this.timestamp,
      billNumber: billNumber ?? this.billNumber,
      shippingAmount: shippingAmount ?? this.shippingAmount,
      customerName: customerName ?? this.customerName,
      customerMobile: customerMobile ?? this.customerMobile,
      customerAddress: customerAddress ?? this.customerAddress,
    );
  }
}
