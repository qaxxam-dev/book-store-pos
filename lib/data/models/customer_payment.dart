class CustomerPayment {
  final int? id;
  final int customerId;
  final double amount;
  final String paymentDate;
  final String paymentMode;
  final String? notes;

  CustomerPayment({
    this.id,
    required this.customerId,
    required this.amount,
    required this.paymentDate,
    required this.paymentMode,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'amount': amount,
      'payment_date': paymentDate,
      'payment_mode': paymentMode,
      'notes': notes,
    };
  }

  factory CustomerPayment.fromMap(Map<String, dynamic> map) {
    return CustomerPayment(
      id: map['id'],
      customerId: map['customer_id'],
      amount: map['amount'],
      paymentDate: map['payment_date'],
      paymentMode: map['payment_mode'],
      notes: map['notes'],
    );
  }
}
