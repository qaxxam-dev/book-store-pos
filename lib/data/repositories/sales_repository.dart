import '../../core/database_helper.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/sales_return.dart';
import '../models/sales_return_item.dart';

class SalesRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> createSale(Sale sale, List<SaleItem> items) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      // 0. Generate Bill Number
      // We need to generate it here to ensure it's unique at the time of insertion,
      // but strictly speaking, inside a transaction is best if we were locking,
      // but SQLite transaction is exclusive by default for writes.
      // However, we can't call the helper using `txn` easily unless we pass txn to helper,
      // or just trust that the helper query (read) is fine.
      // Ideally, we should do the read inside the transaction too.
      // Let's duplicate the logic or make helper accept txn?
      // Helper uses `_dbHelper.database` which might be the same instance.
      // But `txn` is the active transaction.
      // Let's inline the generation logic or make a static helper that takes an Executor.

      // For simplicity and to avoid locking issues, I'll do it inside the transaction block
      // by copying the logic or using a helper that takes the txn.
      // But `txn` type is `Transaction`.

      final now = DateTime.now();
      final yearMonth =
          '${now.year}${now.month.toString().padLeft(2, '0')}'; // YYYYMM
      final prefix = 'SL';
      final pattern = '$prefix-$yearMonth-';

      final List<Map<String, dynamic>> result = await txn.query(
        'sales',
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

      // 1. Insert Sale with new Bill Number
      final saleWithNewBillNumber = Sale(
        id: sale.id,
        customerId: sale.customerId,
        billNumber: newBillNumber,
        totalAmount: sale.totalAmount,
        discount: sale.discount,
        discountPercent: sale.discountPercent,
        paymentMethod: sale.paymentMethod,
        timestamp: sale.timestamp,
        guestPhone: sale.guestPhone,
        shippingAmount: sale.shippingAmount,
        customerName: sale.customerName,
        customerMobile: sale.customerMobile,
        customerAddress: sale.customerAddress,
        discountType: sale.discountType,
      );

      int saleId = await txn.insert('sales', saleWithNewBillNumber.toMap());

      // 2. Insert Sale Items and Update Stock
      for (var item in items) {
        final itemWithSaleId = SaleItem(
          saleId: saleId,
          bookId: item.bookId,
          quantity: item.quantity,
          priceAtSale: item.priceAtSale,
        );
        await txn.insert('sale_items', itemWithSaleId.toMap());

        // Update Stock
        await txn.rawUpdate(
          'UPDATE books SET stock_quantity = stock_quantity - ? WHERE id = ?',
          [item.quantity, item.bookId],
        );
      }
      return saleId;
    });
  }

  Future<List<Sale>> getAllSales() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sales',
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => Sale.fromMap(maps[i]));
  }

  Future<Sale?> getSaleById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Sale.fromMap(maps.first);
    }
    return null;
  }

  Future<List<SaleItem>> getItemsForSale(int saleId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
    return List.generate(maps.length, (i) => SaleItem.fromMap(maps[i]));
  }

  Future<List<Map<String, dynamic>>> getTopSellingBooks({int limit = 5}) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT 
        b.title,
        b.author,
        SUM(si.quantity) as total_sold
      FROM sale_items si
      JOIN books b ON si.book_id = b.id
      GROUP BY si.book_id
      ORDER BY total_sold DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<List<Map<String, dynamic>>> getDeadStock({int days = 30}) async {
    final db = await _dbHelper.database;
    final cutoffDate =
        DateTime.now().subtract(Duration(days: days)).toIso8601String();

    return await db.rawQuery('''
      SELECT 
        b.title,
        b.stock_quantity,
        MAX(s.timestamp) as last_sold_date
      FROM books b
      LEFT JOIN sale_items si ON b.id = si.book_id
      LEFT JOIN sales s ON si.sale_id = s.id
      GROUP BY b.id
      HAVING last_sold_date IS NULL OR last_sold_date < ?
      ORDER BY last_sold_date ASC
    ''', [cutoffDate]);
  }

  Future<SalesReturn> processReturn(
    SalesReturn returnRecord,
    List<SalesReturnItem> items,
    int customerId,
    bool isCreditSale,
  ) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      // 0. Generate Bill Number for Return
      final now = DateTime.now();
      final yearMonth =
          '${now.year}${now.month.toString().padLeft(2, '0')}'; // YYYYMM
      final prefix = 'SR';
      final pattern = '$prefix-$yearMonth-';

      final List<Map<String, dynamic>> result = await txn.query(
        'sales_returns',
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

      // 1. Insert Sales Return Record
      final returnWithNewBillNumber = SalesReturn(
        id: returnRecord.id,
        saleId: returnRecord.saleId,
        billNumber: newBillNumber,
        totalRefund: returnRecord.totalRefund,
        timestamp: returnRecord.timestamp,
      );

      int returnId =
          await txn.insert('sales_returns', returnWithNewBillNumber.toMap());

      // 2. Insert Return Items and Update Stock
      for (var item in items) {
        final itemWithReturnId = SalesReturnItem(
          returnId: returnId,
          bookId: item.bookId,
          quantity: item.quantity,
          refundAmount: item.refundAmount,
        );
        await txn.insert('sales_return_items', itemWithReturnId.toMap());

        // Update Stock (Add returned quantity back to stock)
        await txn.rawUpdate(
          'UPDATE books SET stock_quantity = stock_quantity + ? WHERE id = ?',
          [item.quantity, item.bookId],
        );
      }

      // 3. Update Customer Balance if it was a Credit Sale
      if (isCreditSale) {
        await txn.rawUpdate(
          'UPDATE customers SET balance = balance - ? WHERE id = ?',
          [returnRecord.totalRefund, customerId],
        );
      }

      // Return the complete object with the new ID
      return SalesReturn(
        id: returnId,
        saleId: returnWithNewBillNumber.saleId,
        billNumber: returnWithNewBillNumber.billNumber,
        totalRefund: returnWithNewBillNumber.totalRefund,
        timestamp: returnWithNewBillNumber.timestamp,
      );
    });
  }

  Future<List<SalesReturn>> getAllSalesReturns() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sales_returns',
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => SalesReturn.fromMap(maps[i]));
  }

  Future<List<SalesReturnItem>> getReturnItems(int returnId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sales_return_items',
      where: 'return_id = ?',
      whereArgs: [returnId],
    );
    return List.generate(maps.length, (i) => SalesReturnItem.fromMap(maps[i]));
  }

  Future<List<Sale>> getSalesByBook(int bookId) async {
    final db = await _dbHelper.database;
    // Join sales and sale_items to find sales containing the book
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT s.* 
      FROM sales s
      INNER JOIN sale_items si ON s.id = si.sale_id
      WHERE si.book_id = ?
      ORDER BY s.timestamp DESC
    ''', [bookId]);

    return List.generate(maps.length, (i) => Sale.fromMap(maps[i]));
  }

  Future<List<Sale>> getFilteredSales({
    int? customerId,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? paymentMethods,
  }) async {
    final db = await _dbHelper.database;
    String query = 'SELECT * FROM sales WHERE 1=1';
    List<dynamic> args = [];

    if (customerId != null) {
      query += ' AND customer_id = ?';
      args.add(customerId);
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

    if (paymentMethods != null && paymentMethods.isNotEmpty) {
      query +=
          ' AND payment_method IN (${List.filled(paymentMethods.length, '?').join(',')})';
      args.addAll(paymentMethods);
    }

    query += ' ORDER BY timestamp DESC';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    return List.generate(maps.length, (i) => Sale.fromMap(maps[i]));
  }

  Future<List<SalesReturn>> getFilteredSalesReturns({
    int? customerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;
    String query = '''
      SELECT sr.* 
      FROM sales_returns sr
      JOIN sales s ON sr.sale_id = s.id
      WHERE 1=1
    ''';
    List<dynamic> args = [];

    if (customerId != null) {
      query += ' AND s.customer_id = ?';
      args.add(customerId);
    }

    if (startDate != null) {
      query += ' AND sr.timestamp >= ?';
      args.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      final nextDay = endDate.add(const Duration(days: 1));
      query += ' AND sr.timestamp < ?';
      args.add(nextDay.toIso8601String());
    }

    query += ' ORDER BY sr.timestamp DESC';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    return List.generate(maps.length, (i) => SalesReturn.fromMap(maps[i]));
  }

  Future<void> deleteSale(int saleId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 1. Check for linked returns
      final returns = await txn.query(
        'sales_returns',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );

      if (returns.isNotEmpty) {
        throw Exception(
            'Cannot delete sale. Linked sales returns exist. Please delete them first.');
      }

      // 2. Get Sale Details for Reversal
      final saleResult = await txn.query(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
      );
      if (saleResult.isEmpty) throw Exception('Sale not found');
      final sale = Sale.fromMap(saleResult.first);

      // 3. Get Sale Items for Stock Reversal
      final itemsResult = await txn.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );
      final items = List.generate(
          itemsResult.length, (i) => SaleItem.fromMap(itemsResult[i]));

      // 4. Revert Stock (Add quantity back)
      for (var item in items) {
        await txn.rawUpdate(
          'UPDATE books SET stock_quantity = stock_quantity + ? WHERE id = ?',
          [item.quantity, item.bookId],
        );
      }

      // 5. Revert Customer Balance (Decrease balance by total amount if Credit)
      if (sale.paymentMethod == 'Credit' && sale.customerId != null) {
        await txn.rawUpdate(
          'UPDATE customers SET balance = balance - ? WHERE id = ?',
          [sale.totalAmount, sale.customerId],
        );
      }

      // 6. Delete Items and Sale
      await txn.delete('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
      await txn.delete('sales', where: 'id = ?', whereArgs: [saleId]);
    });
  }

  Future<void> deleteSalesReturn(int returnId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 1. Get Return Details
      final returnResult = await txn.query(
        'sales_returns',
        where: 'id = ?',
        whereArgs: [returnId],
      );
      if (returnResult.isEmpty) throw Exception('Return not found');
      final returnRecord = SalesReturn.fromMap(returnResult.first);

      // 2. Get Return Items
      final itemsResult = await txn.query(
        'sales_return_items',
        where: 'return_id = ?',
        whereArgs: [returnId],
      );
      final items = List.generate(
          itemsResult.length, (i) => SalesReturnItem.fromMap(itemsResult[i]));

      // 3. Revert Stock (Subtract quantity)
      for (var item in items) {
        await txn.rawUpdate(
          'UPDATE books SET stock_quantity = stock_quantity - ? WHERE id = ?',
          [item.quantity, item.bookId],
        );
      }

      // 4. Revert Customer Balance (Increase balance if original sale was Credit)
      final saleResult = await txn.query(
        'sales',
        columns: ['customer_id', 'payment_method'],
        where: 'id = ?',
        whereArgs: [returnRecord.saleId],
      );

      if (saleResult.isNotEmpty &&
          saleResult.first['payment_method'] == 'Credit' &&
          saleResult.first['customer_id'] != null) {
        final customerId = saleResult.first['customer_id'] as int;
        await txn.rawUpdate(
          'UPDATE customers SET balance = balance + ? WHERE id = ?',
          [returnRecord.totalRefund, customerId],
        );
      }

      // 5. Delete Items and Return
      await txn.delete('sales_return_items',
          where: 'return_id = ?', whereArgs: [returnId]);
      await txn.delete('sales_returns', where: 'id = ?', whereArgs: [returnId]);
    });
  }

  Future<List<SalesReturn>> getReturnsForSale(int saleId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sales_returns',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
    return List.generate(maps.length, (i) => SalesReturn.fromMap(maps[i]));
  }

  Future<void> updateSale(Sale sale) async {
    final db = await _dbHelper.database;
    await db.update(
      'sales',
      sale.toMap(),
      where: 'id = ?',
      whereArgs: [sale.id],
    );
  }

  Future<void> editSale(Sale updatedSale, List<SaleItem> newItems) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 1. Check for linked returns
      final returns = await txn.query(
        'sales_returns',
        where: 'sale_id = ?',
        whereArgs: [updatedSale.id],
      );
      if (returns.isNotEmpty) {
        throw Exception(
            'Cannot edit sale. Linked sales returns exist. Please delete or adjust them first.');
      }

      // 2. Fetch original sale
      final originalSaleResult = await txn.query(
        'sales',
        where: 'id = ?',
        whereArgs: [updatedSale.id],
      );
      if (originalSaleResult.isEmpty) {
        throw Exception('Sale not found');
      }
      final originalSale = Sale.fromMap(originalSaleResult.first);

      // 3. Fetch original items
      final originalItemsResult = await txn.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [updatedSale.id],
      );
      final originalItems = List.generate(
        originalItemsResult.length,
        (i) => SaleItem.fromMap(originalItemsResult[i]),
      );

      // 4. Revert original stock
      for (var item in originalItems) {
        await txn.rawUpdate(
          'UPDATE books SET stock_quantity = stock_quantity + ? WHERE id = ?',
          [item.quantity, item.bookId],
        );
      }

      // 5. Deduct new stock
      for (var item in newItems) {
        await txn.rawUpdate(
          'UPDATE books SET stock_quantity = stock_quantity - ? WHERE id = ?',
          [item.quantity, item.bookId],
        );
      }

      // 7. Adjust Customer Balance
      // Revert old credit if old sale was Credit
      if (originalSale.paymentMethod == 'Credit' &&
          originalSale.customerId != null) {
        await txn.rawUpdate(
          'UPDATE customers SET balance = balance - ? WHERE id = ?',
          [originalSale.totalAmount, originalSale.customerId],
        );
      }
      // Apply new credit if updated sale is Credit
      if (updatedSale.paymentMethod == 'Credit' &&
          updatedSale.customerId != null) {
        await txn.rawUpdate(
          'UPDATE customers SET balance = balance + ? WHERE id = ?',
          [updatedSale.totalAmount, updatedSale.customerId],
        );
      }

      // 8. Replace sale items
      await txn.delete('sale_items',
          where: 'sale_id = ?', whereArgs: [updatedSale.id]);
      for (var item in newItems) {
        final itemWithSaleId = SaleItem(
          saleId: updatedSale.id!,
          bookId: item.bookId,
          quantity: item.quantity,
          priceAtSale: item.priceAtSale,
        );
        await txn.insert('sale_items', itemWithSaleId.toMap());
      }

      // 9. Update the sales record
      await txn.update(
        'sales',
        updatedSale.toMap(),
        where: 'id = ?',
        whereArgs: [updatedSale.id],
      );
    });
  }

  Future<void> updateSalesReturn(SalesReturn salesReturn) async {
    final db = await _dbHelper.database;
    await db.update(
      'sales_returns',
      salesReturn.toMap(),
      where: 'id = ?',
      whereArgs: [salesReturn.id],
    );
  }

  Future<void> editSalesReturn(
      SalesReturn updatedReturn, List<SalesReturnItem> newItems) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 1. Fetch original return
      final origReturnResult = await txn.query(
        'sales_returns',
        where: 'id = ?',
        whereArgs: [updatedReturn.id],
      );
      if (origReturnResult.isEmpty) {
        throw Exception('Sales Return not found');
      }
      final origReturn = SalesReturn.fromMap(origReturnResult.first);

      // 2. Fetch parent sale to check payment method & customer
      final parentSaleResult = await txn.query(
        'sales',
        where: 'id = ?',
        whereArgs: [updatedReturn.saleId],
      );
      if (parentSaleResult.isEmpty) {
        throw Exception('Parent sale not found for this return');
      }
      final parentSale = Sale.fromMap(parentSaleResult.first);

      // 3. Fetch original return items
      final origItemsResult = await txn.query(
        'sales_return_items',
        where: 'return_id = ?',
        whereArgs: [updatedReturn.id],
      );
      final origItems = List.generate(
        origItemsResult.length,
        (i) => SalesReturnItem.fromMap(origItemsResult[i]),
      );

      // 4. Revert old return stock (Subtract what was previously added back to stock)
      for (var item in origItems) {
        await txn.rawUpdate(
          'UPDATE books SET stock_quantity = stock_quantity - ? WHERE id = ?',
          [item.quantity, item.bookId],
        );
      }

      // 5. Apply new return stock (Add new return quantities back to stock)
      for (var item in newItems) {
        await txn.rawUpdate(
          'UPDATE books SET stock_quantity = stock_quantity + ? WHERE id = ?',
          [item.quantity, item.bookId],
        );
      }

      // 6. Adjust Customer Balance if parent sale was Credit
      if (parentSale.paymentMethod == 'Credit' &&
          parentSale.customerId != null) {
        final balanceDelta = origReturn.totalRefund - updatedReturn.totalRefund;
        await txn.rawUpdate(
          'UPDATE customers SET balance = balance + ? WHERE id = ?',
          [balanceDelta, parentSale.customerId],
        );
      }

      // 7. Replace return items
      await txn.delete('sales_return_items',
          where: 'return_id = ?', whereArgs: [updatedReturn.id]);
      for (var item in newItems) {
        final itemWithReturnId = SalesReturnItem(
          returnId: updatedReturn.id!,
          bookId: item.bookId,
          quantity: item.quantity,
          refundAmount: item.refundAmount,
        );
        await txn.insert('sales_return_items', itemWithReturnId.toMap());
      }

      // 8. Update sales_returns record
      await txn.update(
        'sales_returns',
        updatedReturn.toMap(),
        where: 'id = ?',
        whereArgs: [updatedReturn.id],
      );
    });
  }

  /// Fetches consolidated sold items in date range, strictly excluding
  /// Credit and Complementary sales, and deducting sales returns in that range.
  Future<List<SoldItemSummary>> getConsolidatedSoldItems({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _dbHelper.database;
    final startStr = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      0,
      0,
      0,
    ).toIso8601String();

    final endStr = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
    ).toIso8601String();

    // 1. Fetch sales items excluding Credit and Complementary
    final List<Map<String, dynamic>> soldRows = await db.rawQuery('''
      SELECT 
        si.book_id,
        b.title,
        b.sku,
        b.price,
        SUM(si.quantity) as sold_qty
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      JOIN books b ON si.book_id = b.id
      WHERE s.payment_method NOT IN ('Credit', 'Complementary')
        AND s.timestamp >= ?
        AND s.timestamp <= ?
      GROUP BY si.book_id, b.title, b.sku, b.price
    ''', [startStr, endStr]);

    // 2. Fetch sales return items for sales excluding Credit and Complementary
    final List<Map<String, dynamic>> returnRows = await db.rawQuery('''
      SELECT 
        sri.book_id,
        SUM(sri.quantity) as return_qty
      FROM sales_return_items sri
      JOIN sales_returns sr ON sri.return_id = sr.id
      JOIN sales s ON sr.sale_id = s.id
      WHERE s.payment_method NOT IN ('Credit', 'Complementary')
        AND sr.timestamp >= ?
        AND sr.timestamp <= ?
      GROUP BY sri.book_id
    ''', [startStr, endStr]);

    final Map<int, int> returnMap = {};
    for (final row in returnRows) {
      final bookId = row['book_id'] as int;
      final returnQty = (row['return_qty'] as num?)?.toInt() ?? 0;
      returnMap[bookId] = returnQty;
    }

    final List<SoldItemSummary> results = [];
    for (final row in soldRows) {
      final bookId = row['book_id'] as int;
      final title = row['title'] as String? ?? 'Unknown';
      final sku = row['sku'] as String? ?? '';
      final price = (row['price'] as num?)?.toDouble() ?? 0.0;
      final soldQty = (row['sold_qty'] as num?)?.toInt() ?? 0;
      final returnedQty = returnMap[bookId] ?? 0;
      final netSold = soldQty - returnedQty;

      if (netSold > 0) {
        results.add(SoldItemSummary(
          bookId: bookId,
          title: title,
          sku: sku,
          totalSold: netSold,
          price: price,
        ));
      }
    }

    results.sort((a, b) => b.totalSold.compareTo(a.totalSold));
    return results;
  }
}

class SoldItemSummary {
  final int bookId;
  final String title;
  final String sku;
  final int totalSold;
  final double price;

  SoldItemSummary({
    required this.bookId,
    required this.title,
    required this.sku,
    required this.totalSold,
    required this.price,
  });
}
