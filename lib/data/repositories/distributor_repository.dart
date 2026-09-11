import '../../core/database_helper.dart';
import '../models/distributor.dart';
import '../models/distributor_payment.dart';

class DistributorRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertDistributor(Distributor distributor) async {
    final db = await _dbHelper.database;
    return await db.insert('distributors', distributor.toMap());
  }

  Future<List<Distributor>> getAllDistributors() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('distributors');
    return List.generate(maps.length, (i) => Distributor.fromMap(maps[i]));
  }

  Future<Distributor?> getDistributorById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'distributors',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Distributor.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateDistributor(Distributor distributor) async {
    final db = await _dbHelper.database;
    return await db.update(
      'distributors',
      distributor.toMap(),
      where: 'id = ?',
      whereArgs: [distributor.id],
    );
  }

  Future<int> deleteDistributor(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('distributors', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> addPayment(DistributorPayment payment) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      // 1. Insert Payment Record
      int paymentId = await txn.insert('distributor_payments', payment.toMap());

      // 2. Update Distributor Balance (Subtract payment amount)
      await txn.rawUpdate(
        'UPDATE distributors SET balance = balance - ? WHERE id = ?',
        [payment.amount, payment.distributorId],
      );

      return paymentId;
    });
  }

  Future<List<DistributorPayment>> getPaymentsForDistributor(
    int distributorId,
  ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'distributor_payments',
      where: 'distributor_id = ?',
      whereArgs: [distributorId],
      orderBy: 'payment_date DESC',
    );
    return List.generate(
      maps.length,
      (i) => DistributorPayment.fromMap(maps[i]),
    );
  }

  Future<List<DistributorPayment>> getAllPayments() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'distributor_payments',
      orderBy: 'payment_date DESC',
    );
    return List.generate(
      maps.length,
      (i) => DistributorPayment.fromMap(maps[i]),
    );
  }
}
