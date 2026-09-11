import 'package:flutter/material.dart';
import '../../data/models/sale.dart';
import '../../data/models/sale_item.dart';
import '../../data/repositories/sales_repository.dart';

import '../../data/models/sales_return.dart';
import '../../data/models/sales_return_item.dart';
import '../../core/utils/purchase_url_helper.dart';

class SalesProvider with ChangeNotifier {
  final SalesRepository _salesRepository = SalesRepository();
  List<Sale> _sales = [];
  List<SalesReturn> _salesReturns = [];
  bool _isLoading = false;

  List<Sale> get sales => _sales;
  List<SalesReturn> get salesReturns => _salesReturns;
  bool get isLoading => _isLoading;

  Future<void> loadSales() async {
    _isLoading = true;
    notifyListeners();
    try {
      _sales = await _salesRepository.getAllSales();
    } catch (e) {
      print('Error loading sales: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSalesReturns() async {
    _isLoading = true;
    notifyListeners();
    try {
      _salesReturns = await _salesRepository.getAllSalesReturns();
    } catch (e) {
      print('Error loading sales returns: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int> createSale(Sale sale, List<SaleItem> items,
      {bool isDemo = false}) async {
    if (isDemo) {
      // Check total sales count
      if (_sales.length >= 5) {
        throw {
          'type': 'purchase_required',
          'message':
              'Demo version is limited to 5 sales. Please purchase a license to continue.',
          'url': PurchaseUrlHelper.kPurchaseUrl
        };
      }
    }
    final id = await _salesRepository.createSale(sale, items);
    await loadSales();
    return id;
  }

  Future<Sale?> getSaleById(int id) async {
    return await _salesRepository.getSaleById(id);
  }

  Future<List<SaleItem>> getItemsForSale(int saleId) async {
    return await _salesRepository.getItemsForSale(saleId);
  }

  Future<List<Map<String, dynamic>>> getTopSellingBooks() async {
    return await _salesRepository.getTopSellingBooks();
  }

  Future<List<Map<String, dynamic>>> getDeadStock() async {
    return await _salesRepository.getDeadStock();
  }

  Future<SalesReturn> processReturn(
    SalesReturn returnRecord,
    List<SalesReturnItem> items,
    int customerId,
    bool isCreditSale, {
    bool isDemo = false,
  }) async {
    if (isDemo) {
      final returns = await getSalesReturns();
      if (returns.length >= 5) {
        throw {
          'type': 'purchase_required',
          'message':
              'Demo version is limited to 5 sales returns. Please purchase a license to continue.',
          'url': PurchaseUrlHelper.kPurchaseUrl
        };
      }
    }
    final newReturn = await _salesRepository.processReturn(
        returnRecord, items, customerId, isCreditSale);
    await loadSales(); // Reload to reflect changes if any
    return newReturn;
  }

  Future<List<SalesReturn>> getSalesReturns() async {
    return await _salesRepository.getAllSalesReturns();
  }

  Future<List<SalesReturnItem>> getReturnItems(int returnId) async {
    return await _salesRepository.getReturnItems(returnId);
  }

  Future<List<Sale>> getSalesByBook(int bookId) async {
    return await _salesRepository.getSalesByBook(bookId);
  }

  Future<List<Sale>> filterSales({
    int? customerId,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? paymentMethods,
  }) async {
    return await _salesRepository.getFilteredSales(
      customerId: customerId,
      startDate: startDate,
      endDate: endDate,
      paymentMethods: paymentMethods,
    );
  }

  Future<List<SalesReturn>> filterSalesReturns({
    int? customerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _salesRepository.getFilteredSalesReturns(
      customerId: customerId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<void> deleteSale(int id) async {
    await _salesRepository.deleteSale(id);
    await loadSales();
  }

  Future<void> deleteSalesReturn(int id) async {
    await _salesRepository.deleteSalesReturn(id);
    notifyListeners();
  }

  Future<bool> hasReturns(int saleId) async {
    final returns = await _salesRepository.getReturnsForSale(saleId);
    return returns.isNotEmpty;
  }

  Future<void> updateSale(Sale sale) async {
    await _salesRepository.updateSale(sale);
    await loadSales();
  }

  Future<void> editSale(Sale sale, List<SaleItem> items) async {
    await _salesRepository.editSale(sale, items);
    await loadSales();
  }

  Future<void> updateSalesReturn(SalesReturn salesReturn) async {
    await _salesRepository.updateSalesReturn(salesReturn);
    await loadSalesReturns();
  }

  Future<void> editSalesReturn(
      SalesReturn salesReturn, List<SalesReturnItem> items) async {
    await _salesRepository.editSalesReturn(salesReturn, items);
    await loadSalesReturns();
    await loadSales();
  }
}
