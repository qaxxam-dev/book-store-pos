class SalesReturn {
  final int? id;
  final int saleId;
  final String billNumber;
  final double totalRefund;
  final String timestamp;

  SalesReturn({
    this.id,
    required this.saleId,
    required this.billNumber,
    required this.totalRefund,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'bill_number': billNumber,
      'total_refund': totalRefund,
      'timestamp': timestamp,
    };
  }

  factory SalesReturn.fromMap(Map<String, dynamic> map) {
    return SalesReturn(
      id: map['id'],
      saleId: map['sale_id'],
      billNumber: map['bill_number'],
      totalRefund: map['total_refund'],
      timestamp: map['timestamp'],
    );
  }

  SalesReturn copyWith({
    int? id,
    int? saleId,
    String? billNumber,
    double? totalRefund,
    String? timestamp,
  }) {
    return SalesReturn(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      billNumber: billNumber ?? this.billNumber,
      totalRefund: totalRefund ?? this.totalRefund,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
