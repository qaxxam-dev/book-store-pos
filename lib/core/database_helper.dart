import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('book_shop_pos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 10,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullableType = 'TEXT';

    const integerType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';
    const realDefaultZero = 'REAL NOT NULL DEFAULT 0.0';

    // 1. Books Table
    await db.execute('''
      CREATE TABLE books (
        id $idType,
        title $textType,
        subtitle $textNullableType,
        price $realType,
        sku $textType UNIQUE,
        stock_quantity $integerType,
        author $textNullableType,
        publisher $textNullableType,
        category $textNullableType,
        description $textNullableType,
        isbn $textNullableType
      )
    ''');

    // 2. Customers Table
    await db.execute('''
      CREATE TABLE customers (
        id $idType,
        name $textType,
        phone $textType,
        balance $realDefaultZero
      )
    ''');

    // 3. Distributors Table
    await db.execute('''
      CREATE TABLE distributors (
        id $idType,
        name $textType,
        phone $textType,
        balance $realDefaultZero
      )
    ''');

    // 4. Sales Table
    await db.execute('''
      CREATE TABLE sales (
        id $idType,
        customer_id INTEGER,
        guest_phone $textNullableType,
        total_amount $realType,
        discount $realDefaultZero,
        discount_percent $realDefaultZero,
        payment_method $textType,
        timestamp $textType,
        bill_number $textType,
        shipping_amount $realDefaultZero,
        customer_name $textNullableType,
        customer_mobile $textNullableType,
        customer_address $textNullableType,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
      )
    ''');

    // 5. Sale Items Table
    await db.execute('''
      CREATE TABLE sale_items (
        id $idType,
        sale_id $integerType,
        book_id $integerType,
        quantity $integerType,
        price_at_sale $realType,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE NO ACTION
      )
    ''');

    // 6. Purchases Table
    await db.execute('''
      CREATE TABLE purchases (
        id $idType,
        distributor_id $integerType,
        bill_number $textType,
        total_amount $realType,
        discount $realDefaultZero,
        payment_method $textType,
        timestamp $textType,
        FOREIGN KEY (distributor_id) REFERENCES distributors (id) ON DELETE NO ACTION
      )
    ''');

    // 7. Purchase Items Table
    await db.execute('''
      CREATE TABLE purchase_items (
        id $idType,
        purchase_id $integerType,
        book_id $integerType,
        quantity $integerType,
        cost_price $realType,
        FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE NO ACTION
      )
    ''');

    // 8. Purchase Returns Table
    await db.execute('''
      CREATE TABLE purchase_returns (
        id $idType,
        purchase_id $integerType,
        bill_number $textType,
        total_refund $realType,
        timestamp $textType,
        FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE
      )
    ''');

    // 9. Purchase Return Items Table
    await db.execute('''
      CREATE TABLE purchase_return_items (
        id $idType,
        return_id $integerType,
        book_id $integerType,
        quantity $integerType,
        refund_amount $realType,
        FOREIGN KEY (return_id) REFERENCES purchase_returns (id) ON DELETE CASCADE,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE NO ACTION
      )
    ''');

    // 10. Distributor Payments Table
    await db.execute('''
      CREATE TABLE distributor_payments (
        id $idType,
        distributor_id $integerType,
        amount $realType,
        payment_date $textType,
        payment_mode $textType,
        notes $textNullableType,
        FOREIGN KEY (distributor_id) REFERENCES distributors (id) ON DELETE CASCADE
      )
    ''');

    // 11. Shop Settings Table
    await db.execute('''
      CREATE TABLE shop_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // 12. Customer Payments Table
    await db.execute('''
      CREATE TABLE customer_payments (
        id $idType,
        customer_id $integerType,
        amount $realType,
        payment_date $textType,
        payment_mode $textType,
        notes $textNullableType,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    // 13. Sales Returns Table
    await db.execute('''
      CREATE TABLE sales_returns (
        id $idType,
        sale_id $integerType,
        bill_number $textType,
        total_refund $realType,
        timestamp $textType,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    // 14. Sales Return Items Table
    await db.execute('''
      CREATE TABLE sales_return_items (
        id $idType,
        return_id $integerType,
        book_id $integerType,
        quantity $integerType,
        refund_amount $realType,
        FOREIGN KEY (return_id) REFERENCES sales_returns (id) ON DELETE CASCADE,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE NO ACTION
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add balance column to customers table if it doesn't exist
      try {
        await db.execute(
            'ALTER TABLE customers ADD COLUMN balance REAL NOT NULL DEFAULT 0.0');
      } catch (e) {
        print('Error adding balance column: $e');
      }

      // Create customer_payments table
      const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
      const integerType = 'INTEGER NOT NULL';
      const realType = 'REAL NOT NULL';
      const textType = 'TEXT NOT NULL';
      const textNullableType = 'TEXT';

      await db.execute('''
        CREATE TABLE customer_payments (
          id $idType,
          customer_id $integerType,
          amount $realType,
          payment_date $textType,
          payment_mode $textType,
          notes $textNullableType,
          FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 3) {
      // Add discount columns to sales table
      try {
        await db.execute(
            'ALTER TABLE sales ADD COLUMN discount REAL NOT NULL DEFAULT 0.0');
        await db.execute(
            'ALTER TABLE sales ADD COLUMN discount_percent REAL NOT NULL DEFAULT 0.0');
      } catch (e) {
        print('Error adding discount columns to sales: $e');
      }
    }

    if (oldVersion < 4) {
      // Create missing tables: shop_settings, distributor_payments, purchase_returns, purchase_return_items
      const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
      const integerType = 'INTEGER NOT NULL';
      const realType = 'REAL NOT NULL';
      const textType = 'TEXT NOT NULL';
      const textNullableType = 'TEXT';

      // Shop Settings
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS shop_settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      } catch (e) {
        print('Error creating shop_settings: $e');
      }

      // Distributor Payments
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS distributor_payments (
            id $idType,
            distributor_id $integerType,
            amount $realType,
            payment_date $textType,
            payment_mode $textType,
            notes $textNullableType,
            FOREIGN KEY (distributor_id) REFERENCES distributors (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        print('Error creating distributor_payments: $e');
      }

      // Purchase Returns
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS purchase_returns (
            id $idType,
            purchase_id $integerType,
            bill_number $textType,
            total_refund $realType,
            timestamp $textType,
            FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        print('Error creating purchase_returns: $e');
      }

      // Purchase Return Items
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS purchase_return_items (
            id $idType,
            return_id $integerType,
            book_id $integerType,
            quantity $integerType,
            refund_amount $realType,
            FOREIGN KEY (return_id) REFERENCES purchase_returns (id) ON DELETE CASCADE,
            FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE NO ACTION
          )
        ''');
      } catch (e) {
        print('Error creating purchase_return_items: $e');
      }
    }

    if (oldVersion < 5) {
      // Add guest_phone column to sales table
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN guest_phone TEXT');
      } catch (e) {
        print('Error adding guest_phone column: $e');
      }
    }
    if (oldVersion < 6) {
      // Add subtitle column to books table
      try {
        await db.execute('ALTER TABLE books ADD COLUMN subtitle TEXT');
      } catch (e) {
        print('Error adding subtitle column: $e');
      }
    }

    if (oldVersion < 7) {
      // Add category, description, isbn columns to books table
      try {
        await db.execute('ALTER TABLE books ADD COLUMN category TEXT');
        await db.execute('ALTER TABLE books ADD COLUMN description TEXT');
        await db.execute('ALTER TABLE books ADD COLUMN isbn TEXT');
      } catch (e) {
        print('Error adding missing columns to books: $e');
      }
    }

    if (oldVersion < 8) {
      // Create sales_returns and sales_return_items tables
      const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
      const integerType = 'INTEGER NOT NULL';
      const realType = 'REAL NOT NULL';
      const textType = 'TEXT NOT NULL';

      // Sales Returns
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sales_returns (
            id $idType,
            sale_id $integerType,
            bill_number $textType,
            total_refund $realType,
            timestamp $textType,
            FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        print('Error creating sales_returns: $e');
      }

      // Sales Return Items
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sales_return_items (
            id $idType,
            return_id $integerType,
            book_id $integerType,
            quantity $integerType,
            refund_amount $realType,
            FOREIGN KEY (return_id) REFERENCES sales_returns (id) ON DELETE CASCADE,
            FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE NO ACTION
          )
        ''');
      } catch (e) {
        print('Error creating sales_return_items: $e');
      }
    }

    if (oldVersion < 10) {
      // Add shipping columns to sales table
      // We wrap each in try-catch to allow partial successes if some columns exist
      try {
        await db.execute(
            'ALTER TABLE sales ADD COLUMN shipping_amount REAL NOT NULL DEFAULT 0.0');
      } catch (e) {
        // Column likely exists
      }
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN customer_name TEXT');
      } catch (e) {
        // Column likely exists
      }
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN customer_mobile TEXT');
      } catch (e) {
        // Column likely exists
      }
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN customer_address TEXT');
      } catch (e) {
        // Column likely exists
      }
    }
  }

  Future<List<Map<String, dynamic>>> findInvoicesByBookBarcode(
      String barcode) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT 
        p.id as purchase_id,
        p.bill_number, 
        p.timestamp,
        p.payment_method,
        p.distributor_id,
        d.name as distributor_name, 
        pi.book_id,
        pi.quantity as purchased_quantity,
        pi.cost_price
      FROM purchases p
      JOIN purchase_items pi ON p.id = pi.purchase_id
      JOIN distributors d ON p.distributor_id = d.id
      JOIN books b ON pi.book_id = b.id
      WHERE b.sku = ?
      ORDER BY p.timestamp DESC
    ''', [barcode]);
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
