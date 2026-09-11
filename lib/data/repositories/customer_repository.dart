import '../../core/database_helper.dart';
import '../models/customer.dart';
import '../models/customer_payment.dart';

class CustomerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertCustomer(Customer customer) async {
    final db = await _dbHelper.database;
    return await db.insert('customers', customer.toMap());
  }

  Future<List<Customer>> getAllCustomers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('customers');
    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  Future<List<Customer>> searchCustomers(String query) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      where: 'name LIKE ? OR phone LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );
    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  Future<Customer?> getCustomerById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Customer.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateCustomer(Customer customer) async {
    final db = await _dbHelper.database;
    return await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<int> deleteCustomer(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> addPayment(CustomerPayment payment) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      // 1. Insert Payment Record
      int paymentId = await txn.insert('customer_payments', payment.toMap());

      // 2. Update Customer Balance (Subtract payment amount)
      await txn.rawUpdate(
        'UPDATE customers SET balance = balance - ? WHERE id = ?',
        [payment.amount, payment.customerId],
      );

      return paymentId;
    });
  }

  Future<List<CustomerPayment>> getPaymentsForCustomer(int customerId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customer_payments',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'payment_date DESC',
    );
    return List.generate(
      maps.length,
      (i) => CustomerPayment.fromMap(maps[i]),
    );
  }

  Future<List<CustomerPayment>> getAllPayments() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customer_payments',
      orderBy: 'payment_date DESC',
    );
    return List.generate(
      maps.length,
      (i) => CustomerPayment.fromMap(maps[i]),
    );
  }
}
