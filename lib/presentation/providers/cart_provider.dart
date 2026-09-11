import 'package:flutter/material.dart';
import '../../data/models/book.dart';

class CartItem {
  final Book book;
  int quantity;

  CartItem({required this.book, this.quantity = 1});

  double get total => book.price * quantity;
}

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];

  double _discountPercentage = 0.0;

  List<CartItem> get items => _items;
  double get discountPercentage => _discountPercentage;

  double get totalAmount {
    final subtotal = _items.fold(0.0, (sum, item) => sum + item.total);
    return subtotal * (1 - _discountPercentage / 100);
  }

  void setDiscount(double percentage) {
    _discountPercentage = percentage;
    notifyListeners();
  }

  void addToCart(Book book) {
    final index = _items.indexWhere((item) => item.book.id == book.id);
    if (index >= 0) {
      _items[index].quantity++;
    } else {
      _items.add(CartItem(book: book));
    }
    notifyListeners();
  }

  void removeFromCart(Book book) {
    _items.removeWhere((item) => item.book.id == book.id);
    notifyListeners();
  }

  void updateQuantity(Book book, int quantity) {
    final index = _items.indexWhere((item) => item.book.id == book.id);
    if (index >= 0) {
      if (quantity > 0) {
        _items[index].quantity = quantity;
      } else {
        removeFromCart(book);
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    _discountPercentage = 0.0;
    notifyListeners();
  }
}
