class PurchaseReturn {
  final int? id;
  final int purchaseId;
  final String billNumber;
  final double totalRefund;
  final String timestamp;

  PurchaseReturn({
    this.id,
    required this.purchaseId,
    required this.billNumber,
    required this.totalRefund,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_id': purchaseId,
      'bill_number': billNumber,
      'total_refund': totalRefund,
      'timestamp': timestamp,
    };
  }

  factory PurchaseReturn.fromMap(Map<String, dynamic> map) {
    return PurchaseReturn(
      id: map['id'],
      purchaseId: map['purchase_id'],
      billNumber: map['bill_number'],
      totalRefund: map['total_refund'],
      timestamp: map['timestamp'],
    );
  }
  PurchaseReturn copyWith({
    int? id,
    int? purchaseId,
    String? billNumber,
    double? totalRefund,
    String? timestamp,
  }) {
    return PurchaseReturn(
      id: id ?? this.id,
      purchaseId: purchaseId ?? this.purchaseId,
      billNumber: billNumber ?? this.billNumber,
      totalRefund: totalRefund ?? this.totalRefund,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
