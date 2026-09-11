import 'package:flutter/material.dart';
import '../../data/models/book.dart';
import '../../data/repositories/book_repository.dart';
import '../../core/utils/purchase_url_helper.dart';

class BookProvider with ChangeNotifier {
  final BookRepository _bookRepository = BookRepository();
  List<Book> _books = [];
  bool _isLoading = false;

  List<Book> get books => _books;
  bool get isLoading => _isLoading;

  Future<void> loadBooks() async {
    _isLoading = true;
    notifyListeners();
    try {
      _books = await _bookRepository.getAllBooks();
    } catch (e) {
      print('Error loading books: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addBook(Book book, {bool isDemo = false}) async {
    if (isDemo && _books.length >= 5) {
      throw {
        'type': 'purchase_required',
        'message':
            'Demo version is limited to 5 books. Please purchase a license to continue.',
        'url': PurchaseUrlHelper.kPurchaseUrl
      };
    }
    await _bookRepository.insertBook(book);
    await loadBooks();
  }

  Future<void> updateBook(Book book) async {
    await _bookRepository.updateBook(book);
    await loadBooks();
  }

  Future<void> deleteBook(int id) async {
    await _bookRepository.deleteBook(id);
    await loadBooks();
  }

  Future<void> searchBooks(String query) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (query.isEmpty) {
        await loadBooks();
      } else {
        _books = await _bookRepository.searchBooks(query);
      }
    } catch (e) {
      print('Error searching books: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Book?> getBookBySku(String sku) async {
    return await _bookRepository.getBookBySku(sku);
  }

  Future<List<Book>> getLowStockBooks() async {
    return await _bookRepository.getLowStockBooks();
  }

  Future<void> importBooks(List<Book> books) async {
    _isLoading = true;
    notifyListeners();
    try {
      for (var book in books) {
        // Check if SKU exists to avoid duplicates or update?
        // For now, we'll try to insert. If SKU exists, repository might throw or ignore depending on conflict resolution.
        // Ideally, we should check or use insertOrUpdate.
        // Let's assume insert. If it fails due to unique SKU, we catch it.
        try {
          final existing = await _bookRepository.getBookBySku(book.sku);
          if (existing != null) {
            // Update existing
            final updatedBook = book.copyWith(id: existing.id);
            await _bookRepository.updateBook(updatedBook);
          } else {
            await _bookRepository.insertBook(book);
          }
        } catch (e) {
          print('Error importing book ${book.title}: $e');
        }
      }
      await loadBooks();
    } catch (e) {
      print('Error importing books: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
