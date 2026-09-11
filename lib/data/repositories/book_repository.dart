import '../../core/database_helper.dart';
import '../models/book.dart';

class BookRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertBook(Book book) async {
    final db = await _dbHelper.database;
    return await db.insert('books', book.toMap());
  }

  Future<List<Book>> getAllBooks() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('books');
    return List.generate(maps.length, (i) => Book.fromMap(maps[i]));
  }

  Future<Book?> getBookById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Book.fromMap(maps.first);
    }
    return null;
  }

  Future<Book?> getBookBySku(String sku) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'sku = ?',
      whereArgs: [sku],
    );
    if (maps.isNotEmpty) {
      return Book.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateBook(Book book) async {
    final db = await _dbHelper.database;
    return await db.update(
      'books',
      book.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  Future<int> deleteBook(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Book>> searchBooks(String query) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'title LIKE ? OR sku LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );
    return List.generate(maps.length, (i) => Book.fromMap(maps[i]));
  }

  Future<List<Book>> getLowStockBooks({int threshold = 5}) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'stock_quantity <= ?',
      whereArgs: [threshold],
      orderBy: 'stock_quantity ASC',
    );
    return List.generate(maps.length, (i) => Book.fromMap(maps[i]));
  }
}
