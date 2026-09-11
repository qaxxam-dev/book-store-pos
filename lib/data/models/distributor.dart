class Distributor {
  final int? id;
  final String name;
  final String phone;
  final double balance;

  Distributor({
    this.id,
    required this.name,
    required this.phone,
    this.balance = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'phone': phone, 'balance': balance};
  }

  factory Distributor.fromMap(Map<String, dynamic> map) {
    return Distributor(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      balance: map['balance'] ?? 0.0,
    );
  }
}
