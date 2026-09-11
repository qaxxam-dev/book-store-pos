class DistributorPayment {
  final int? id;
  final int distributorId;
  final double amount;
  final String paymentDate;
  final String paymentMode;
  final String? notes;

  DistributorPayment({
    this.id,
    required this.distributorId,
    required this.amount,
    required this.paymentDate,
    required this.paymentMode,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'distributor_id': distributorId,
      'amount': amount,
      'payment_date': paymentDate,
      'payment_mode': paymentMode,
      'notes': notes,
    };
  }

  factory DistributorPayment.fromMap(Map<String, dynamic> map) {
    return DistributorPayment(
      id: map['id'],
      distributorId: map['distributor_id'],
      amount: map['amount'],
      paymentDate: map['payment_date'],
      paymentMode: map['payment_mode'],
      notes: map['notes'],
    );
  }
}
