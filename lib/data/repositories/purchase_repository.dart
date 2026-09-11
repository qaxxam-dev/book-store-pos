import '../../core/database_helper.dart';
import '../models/purchase.dart';
import '../models/purchase_item.dart';
import '../models/purchase_return.dart';
import '../models/purchase_return_item.dart';

class PurchaseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Purchase> createPurchase(
    Purchase purchase,
    List<PurchaseItem> items,
  ) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      // 0. Generate Bill Number
      final now = DateTime.now();
      final yearMonth =
          '${now.year}${now.month.toString().padLeft(2, '0')}'; // YYYYMM
      final prefix = 'PU';
      final pattern = '$prefix-$yearMonth-';

      final List<Map<String, dynamic>> result = await txn.query(
        'purchases',
        columns: ['bill_number'],
        where: 'bill_number LIKE ?',
        whereArgs: ['$pattern%'],
        orderBy: 'bill_number DESC',
        limit: 1,
      );

      int sequence = 1;
      if (result.isNotEmpty) {
        final lastBillNumber = result.first['bill_number'] as String;
        final parts = lastBillNumber.split('-');
        if (parts.length == 3) {
          final lastSequence = int.tryParse(parts[2]) ?? 0;
          sequence = lastSequence + 1;
        }
      }

      final newBillNumber = '$pattern${sequence.toString().padLeft(5, '0')}';

      // 1. Insert Purchase
      final purchaseWithNewBillNumber = Purchase(
        id: purchase.id,
        distributorId: purchase.distributorId,
        billNumber: newBillNumber,
        totalAmount: purchase.totalAmount,
        discount: purchase.discount,
        paymentMethod: purchase.paymentMethod,
        timestamp: purchase.timestamp,
      );

      int purchaseId =
          await txn.insert('purchases', purchaseWithNewBillNumber.toMap());

      // 2. Insert Purchase Items and Update Stock
      for (var item in items) {
        final itemWithPurchaseId = PurchaseItem(
          purchaseId: purchaseId,
          bookId: item.bookId,
          quantity: item.quantity,
          costPrice: item.costPrice,
        );
        await txn.insert('purchase_items', itemWithPurchaseId.toMap());

        // Update Stock
        await txn.rawUpdate(
          'UPDATE books SET stock_quantity = stock_quantity + ? WHERE id = ?',
          [item.quantity, item.bookId],
        );
      }

      // 3. Update Distributor Balance if Credit
      if (purchase.paymentMethod == 'Credit') {
        await txn.rawUpdate(
          'UPDATE distributors SET balance = balance + ? WHERE id = ?',
          [purchase.totalAmount, purchase.distributorId],
        );
      }

      return purchaseWithNewBillNumber.copyWith(id: purchaseId);
    });
  }

  Future<List<Purchase>> getAllPurchases() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'purchases',
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => Purchase.fromMap(maps[i]));
  }

  Future<List<PurchaseItem>> getItemsForPurchase(int purchaseId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'purchase_items',
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
    );
    return List.generate(maps.length, (i) => PurchaseItem.fromMap(maps[i]));
  }

  Future<List<Purchase>> getPurchasesByBook(int bookId) async {
    final db = await _dbHelper.database;
    // Join purchases and purchase_items to find purchases containing the book
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.* 
      FROM purchases p
      INNER JOIN purchase_items pi ON p.id = pi.purchase_id
      WHERE pi.book_id = ?
      ORDER BY p.timestamp DESC
    ''', [bookId]);

    return List.generate(maps.length, (i) => Purchase.fromMap(maps[i]));
  }

  Future<PurchaseReturn> processReturn(
    PurchaseReturn returnRecord,
    List<PurchaseReturnItem> items,
    int distributorId,
    bool isCreditPurchase,
  ) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      // 0. Generate Bill Number for Return
      final now = DateTime.now();
      final yearMonth =
          '${now.year}${now.month.toString().padLeft(2, '0')}'; // YYYYMM
      final prefix = 'PR';
      final pattern = '$prefix-$yearMonth-';

      final List<Map<String, dynamic>> result = await txn.query(
        'purchase_returns',
        columns: ['bill_number'],
        where: 'bill_number LIKE ?',
        whereArgs: ['$pattern%'],
        orderBy: 'bill_number DESC',
        limit: 1,
      );

      int sequence = 1;
      if (result.isNotEmpty) {
        final lastBillNumber = result.first['bill_number'] as String;
        final parts = lastBillNumber.split('-');
        if (parts.length == 3) {
          final lastSequence = int.tryParse(parts[2]) ?? 0;
          sequence = lastSequence + 1;
        }
      }

      final newBillNumber = '$pattern${sequence.toString().padLeft(5, '0')}';

      // 1. Insert Purchase Return Record
      final returnWithNewBillNumber = PurchaseReturn(
        id: returnRecord.id,
        purchaseId: returnRecord.purchaseId,
        billNumber: newBillNumber,
        totalRefund: returnRecord.totalRefund,
        timestamp: returnRecord.timestamp,
      );

      int returnId =
          await txn.insert('purchase_returns', returnWithNewBillNumber.toMap());

      // 2. Insert Return Items and Update Stock
      for (var item in items) {
        final itemWithReturnId = PurchaseReturnItem(
          returnId: returnId,
          bookId: item.bookId,
          quantity: item.quantity,
          refundAmount: item.refundAmount,
        );
        await txn.insert('purchase_return_items', itemWithReturnId.toMap());

        // Update Stock (Subtract returned quantity)
        await txn.rawUpdate(
          'UPDATE books SET stock_quantity = stock_quantity - ? WHERE id = ?',
          [item.quantity, item.bookId],
        );
      }

      // 3. Update Distributor Balance if it was a Credit Purchase
      // If we return items from a credit purchase, we owe the distributor less, so we subtract from balance.
      if (isCreditPurchase) {
        await txn.rawUpdate(
          'UPDATE distributors SET balance = balance - ? WHERE id = ?',
          [returnRecord.totalRefund, distributorId],
        );
      }

      return returnWithNewBillNumber.copyWith(id: returnId);
    });
  }

  Future<List<PurchaseReturn>> getAllPurchaseReturns() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'purchase_returns',
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => PurchaseReturn.fromMap(maps[i]));
  }

  Future<List<PurchaseReturnItem>> getReturnItems(int returnId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'purchase_return_items',
      where: 'return_id = ?',
      whereArgs: [returnId],
    );
    return List.generate(
        maps.length, (i) => PurchaseReturnItem.fromMap(maps[i]));
  }

  Future<List<PurchaseReturn>> getFilteredPurchaseReturns({
    int? distributorId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;
    String query = '''
      SELECT pr.* 
      FROM purchase_returns pr
      JOIN purchases p ON pr.purchase_id = p.id
      WHERE 1=1
    ''';
    List<dynamic> args = [];

    if (distributorId != null) {
      query += ' AND p.distributor_id = ?';
      args.add(distributorId);
    }

    if (startDate != null) {
      query += ' AND pr.timestamp >= ?';
      args.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      // Add one day to include the end date fully
      final nextDay = endDate.add(const Duration(days: 1));
      query += ' AND pr.timestamp < ?';
      args.add(nextDay.toIso8601String());
    }

    query += ' ORDER BY pr.timestamp DESC';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    return List.generate(maps.length, (i) => PurchaseReturn.fromMap(maps[i]));
  }

  Future<List<Purchase>> getFilteredPurchases({
    int? distributorId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;
    String query = 'SELECT * FROM purchases WHERE 1=1';
    List<dynamic> args = [];

    if (distributorId != null) {
      query += ' AND distributor_id = ?';
      args.add(distributorId);
    }

    if (startDate != null) {
      query += ' AND timestamp >= ?';
      args.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      final nextDay = endDate.add(const Duration(days: 1));
      query += ' AND timestamp < ?';
      args.add(nextDay.toIso8601String());
    }

    query += ' ORDER BY timestamp DESC';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    return List.generate(maps.length, (i) => Purchase.fromMap(maps[i]));
  }

  Future<void> deletePurchase(int purchaseId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 1. Check for linked returns
      final returns = await txn.query(
        'purchase_returns',
        where: 'purchase_id = ?',
        whereArgs: [purchaseId],
      );

      if (returns.isNotEmpty) {
        throw Exception(
            'Cannot delete purchase. Linked purchase returns exist. Please delete them first.');
      }

      // 2. Get Purchase Details for Reversal
      final purchaseResult = await txn.query(
        'purchases',
        where: 'id = ?',
        whereArgs: [purchaseId],
      );
      if (purchaseResult.isEmpty) throw Exception('Purchase not found');
      final purchase = Purchase.fromMap(purchaseResult.first);

      // 3. Get Purchase Items for Stock Reversal
      final itemsResult = await txn.query(
        'purchase_items',
        where: 'purchase_id = ?',
        whereArgs: [purchaseId],
      );
      final items = List.generate(
          itemsResult.length, (i) => PurchaseItem.fromMap(itemsResult[i]));

      // 4. Revert Stock (Subtract quantity)
      // Purchase added to stock, so deleting purchase removes from stock.
      for (var item in items) {
        await txn.rawUpdate(
          'UPDATE books SET stock_quantity = stock_quantity - ? WHERE id = ?',
          [item.quantity, item.bookId],
        );
      }

      // 5. Revert Distributor Balance (Decrease balance)
      // Only if it was a credit purchase (or generally if we track balance).
      // "Decrease the Distributor Balance by the bill’s Total Amount"
      if (purchase.paymentMethod == 'Credit') {
        await txn.rawUpdate(
          'UPDATE distributors SET balance = balance - ? WHERE id = ?',
          [purchase.totalAmount, purchase.distributorId],
        );
      }

      // 6. Delete Items and Purchase
      await txn.delete('purchase_items',
          where: 'purchase_id = ?', whereArgs: [purchaseId]);
      await txn.delete('purchases', where: 'id = ?', whereArgs: [purchaseId]);
    });
  }

  Future<void> deletePurchaseReturn(int returnId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 1. Get Return Details
      final returnResult = await txn.query(
        'purchase_returns',
        where: 'id = ?',
        whereArgs: [returnId],
      );
      if (returnResult.isEmpty) throw Exception('Return not found');
      final returnRecord = PurchaseReturn.fromMap(returnResult.first);

      // 2. Get Return Items
      final itemsResult = await txn.query(
        'purchase_return_items',
        where: 'return_id = ?',
        whereArgs: [returnId],
      );
      final items = List.generate(itemsResult.length,
          (i) => PurchaseReturnItem.fromMap(itemsResult[i]));

      // 3. Revert Stock (Add quantity back)
      // Return removed from stock, so deleting return adds back to stock.
      for (var item in items) {
        await txn.rawUpdate(
          'UPDATE books SET stock_quantity = stock_quantity + ? WHERE id = ?',
          [item.quantity, item.bookId],
        );
      }

      // 4. Revert Distributor Balance (Increase balance)
      // Return reduced debt (balance), so deleting return increases debt.
      // Need to check if original purchase was credit?
      // The prompt says "Decrease the Distributor Balance..." but I noted the typo and plan to INCREASE.
      // Logic: Return reduces balance. Deleting Return reverses that -> Increases Balance.
      // But only if the original purchase affected balance (Credit).
      // However, the return itself might have reduced balance regardless?
      // Usually returns reduce balance if we owe them.
      // I'll check the original purchase to be safe, or just assume if return happened it affected balance?
      // In `processReturn` in repo:
      // if (isCreditPurchase) { update balance }
      // So I need to know if it was a credit purchase.
      // I can fetch the purchase.
      final purchaseResult = await txn.query(
        'purchases',
        where: 'id = ?',
        whereArgs: [returnRecord.purchaseId],
      );

      if (purchaseResult.isNotEmpty) {
        final purchase = Purchase.fromMap(purchaseResult.first);
        if (purchase.paymentMethod == 'Credit') {
          await txn.rawUpdate(
            'UPDATE distributors SET balance = balance + ? WHERE id = ?',
            [returnRecord.totalRefund, purchase.distributorId],
          );
        }
      }

      // 5. Delete Items and Return
      await txn.delete('purchase_return_items',
          where: 'return_id = ?', whereArgs: [returnId]);
      await txn
          .delete('purchase_returns', where: 'id = ?', whereArgs: [returnId]);
    });
  }

  Future<List<PurchaseReturn>> getReturnsForPurchase(int purchaseId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'purchase_returns',
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
    );
    return List.generate(maps.length, (i) => PurchaseReturn.fromMap(maps[i]));
  }

  Future<void> updatePurchase(Purchase purchase) async {
    final db = await _dbHelper.database;
    await db.update(
      'purchases',
      purchase.toMap(),
      where: 'id = ?',
      whereArgs: [purchase.id],
    );
  }

  Future<void> editPurchase(
    Purchase updatedPurchase,
    List<PurchaseItem> newItems,
  ) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 1. Check for linked returns
      final returns = await txn.query(
        'purchase_returns',
        where: 'purchase_id = ?',
        whereArgs: [updatedPurchase.id],
      );
      if (returns.isNotEmpty) {
        throw Exception(
            'Cannot edit purchase. Linked purchase returns exist. Please delete or adjust them first.');
      }

      // 2. Fetch original purchase
      final originalPurchaseResult = await txn.query(
        'purchases',
        where: 'id = ?',
        whereArgs: [updatedPurchase.id],
      );
      if (originalPurchaseResult.isEmpty) {
        throw Exception('Purchase not found');
      }
      final originalPurchase = Purchase.fromMap(originalPurchaseResult.first);

      // 3. Fetch original items
      final originalItemsResult = await txn.query(
        'purchase_items',
        where: 'purchase_id = ?',
        whereArgs: [updatedPurchase.id],
      );
      final originalItems = List.generate(
        originalItemsResult.length,
        (i) => PurchaseItem.fromMap(originalItemsResult[i]),
      );

      // 4. Revert original stock (Subtract what was previously added)
      for (var item in originalItems) {
        await txn.rawUpdate(
          'UPDATE books SET stock_quantity = stock_quantity - ? WHERE id = ?',
          [item.quantity, item.bookId],
        );
      }

      // 5. Apply new stock (Add new purchase quantities)
      for (var item in newItems) {
        await txn.rawUpdate(
          'UPDATE books SET stock_quantity = stock_quantity + ? WHERE id = ?',
          [item.quantity, item.bookId],
        );
      }

      // 6. Reconcile Distributor Balance
      // If original was Credit: reduce old debt
      if (originalPurchase.paymentMethod == 'Credit') {
        await txn.rawUpdate(
          'UPDATE distributors SET balance = balance - ? WHERE id = ?',
          [originalPurchase.totalAmount, originalPurchase.distributorId],
        );
      }
      // If updated is Credit: increase new debt
      if (updatedPurchase.paymentMethod == 'Credit') {
        await txn.rawUpdate(
          'UPDATE distributors SET balance = balance + ? WHERE id = ?',
          [updatedPurchase.totalAmount, updatedPurchase.distributorId],
        );
      }

      // 7. Replace purchase items
      await txn.delete('purchase_items',
          where: 'purchase_id = ?', whereArgs: [updatedPurchase.id]);
      for (var item in newItems) {
        final itemWithPurchaseId = PurchaseItem(
          purchaseId: updatedPurchase.id!,
          bookId: item.bookId,
          quantity: item.quantity,
          costPrice: item.costPrice,
        );
        await txn.insert('purchase_items', itemWithPurchaseId.toMap());
      }

      // 8. Update purchases table
      await txn.update(
        'purchases',
        updatedPurchase.toMap(),
        where: 'id = ?',
        whereArgs: [updatedPurchase.id],
      );
    });
  }

  Future<void> updatePurchaseReturn(PurchaseReturn purchaseReturn) async {
    final db = await _dbHelper.database;
    await db.update(
      'purchase_returns',
      purchaseReturn.toMap(),
      where: 'id = ?',
      whereArgs: [purchaseReturn.id],
    );
  }

  Future<void> editPurchaseReturn(
    PurchaseReturn updatedReturn,
    List<PurchaseReturnItem> newItems,
  ) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 1. Fetch original return
      final origReturnResult = await txn.query(
        'purchase_returns',
        where: 'id = ?',
        whereArgs: [updatedReturn.id],
      );
      if (origReturnResult.isEmpty) {
        throw Exception('Purchase return not found');
      }
      final origReturn = PurchaseReturn.fromMap(origReturnResult.first);

      // 2. Fetch parent purchase
      final parentPurchaseResult = await txn.query(
        'purchases',
        where: 'id = ?',
        whereArgs: [updatedReturn.purchaseId],
      );
      if (parentPurchaseResult.isEmpty) {
        throw Exception('Parent purchase not found for this return');
      }
      final parentPurchase = Purchase.fromMap(parentPurchaseResult.first);

      // 3. Fetch original return items
      final origItemsResult = await txn.query(
        'purchase_return_items',
        where: 'return_id = ?',
        whereArgs: [updatedReturn.id],
      );
      final origItems = List.generate(
        origItemsResult.length,
        (i) => PurchaseReturnItem.fromMap(origItemsResult[i]),
      );

      // 4. Revert old return stock (Purchase return subtracted from stock, so reverting ADDS back)
      for (var item in origItems) {
        await txn.rawUpdate(
          'UPDATE books SET stock_quantity = stock_quantity + ? WHERE id = ?',
          [item.quantity, item.bookId],
        );
      }

      // 5. Apply new return stock (Subtract new return quantities from stock)
      for (var item in newItems) {
        await txn.rawUpdate(
          'UPDATE books SET stock_quantity = stock_quantity - ? WHERE id = ?',
          [item.quantity, item.bookId],
        );
      }

      // 6. Reconcile Distributor Balance if parent was Credit
      if (parentPurchase.paymentMethod == 'Credit') {
        final balanceDelta = origReturn.totalRefund - updatedReturn.totalRefund;
        await txn.rawUpdate(
          'UPDATE distributors SET balance = balance + ? WHERE id = ?',
          [balanceDelta, parentPurchase.distributorId],
        );
      }

      // 7. Replace return items
      await txn.delete('purchase_return_items',
          where: 'return_id = ?', whereArgs: [updatedReturn.id]);
      for (var item in newItems) {
        final itemWithReturnId = PurchaseReturnItem(
          returnId: updatedReturn.id!,
          bookId: item.bookId,
          quantity: item.quantity,
          refundAmount: item.refundAmount,
        );
        await txn.insert('purchase_return_items', itemWithReturnId.toMap());
      }

      // 8. Update purchase_returns record
      await txn.update(
        'purchase_returns',
        updatedReturn.toMap(),
        where: 'id = ?',
        whereArgs: [updatedReturn.id],
      );
    });
  }
}
