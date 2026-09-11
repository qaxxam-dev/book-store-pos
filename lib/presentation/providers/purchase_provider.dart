import 'package:flutter/material.dart';
import '../../data/models/purchase.dart';
import '../../data/models/purchase_item.dart';
import '../../data/models/purchase_return.dart';
import '../../data/models/purchase_return_item.dart';
import '../../data/repositories/purchase_repository.dart';
import '../../core/utils/purchase_url_helper.dart';

class PurchaseProvider with ChangeNotifier {
  final PurchaseRepository _repository = PurchaseRepository();
  List<Purchase> _purchases = [];
  List<PurchaseReturn> _purchaseReturns = [];
  bool _isLoading = false;

  List<Purchase> get purchases => _purchases;
  List<PurchaseReturn> get purchaseReturns => _purchaseReturns;
  bool get isLoading => _isLoading;

  Future<void> loadPurchases() async {
    _isLoading = true;
    notifyListeners();
    try {
      _purchases = await _repository.getAllPurchases();
    } catch (e) {
      debugPrint('Error loading purchases: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPurchaseReturns() async {
    _isLoading = true;
    notifyListeners();
    try {
      _purchaseReturns = await _repository.getAllPurchaseReturns();
    } catch (e) {
      debugPrint('Error loading purchase returns: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Purchase> createPurchase(Purchase purchase, List<PurchaseItem> items,
      {bool isDemo = false}) async {
    if (isDemo && _purchases.length >= 5) {
      throw {
        'type': 'purchase_required',
        'message':
            'Demo version is limited to 5 purchases. Please purchase a license to continue.',
        'url': PurchaseUrlHelper.kPurchaseUrl
      };
    }
    final newPurchase = await _repository.createPurchase(purchase, items);
    await loadPurchases();
    return newPurchase;
  }

  Future<List<PurchaseItem>> getPurchaseItems(int purchaseId) async {
    return await _repository.getItemsForPurchase(purchaseId);
  }

  Future<List<Purchase>> getPurchasesByBook(int bookId) async {
    return await _repository.getPurchasesByBook(bookId);
  }

  Future<PurchaseReturn> processReturn(
    PurchaseReturn returnRecord,
    List<PurchaseReturnItem> items,
    int distributorId,
    bool isCreditPurchase, {
    bool isDemo = false,
  }) async {
    if (isDemo) {
      final returns = await getPurchaseReturns();
      if (returns.length >= 5) {
        throw {
          'type': 'purchase_required',
          'message':
              'Demo version is limited to 5 purchase returns. Please purchase a license to continue.',
          'url': PurchaseUrlHelper.kPurchaseUrl
        };
      }
    }
    final newReturn = await _repository.processReturn(
        returnRecord, items, distributorId, isCreditPurchase);
    await loadPurchases(); // Reload to reflect changes if any
    return newReturn;
  }

  Future<List<PurchaseReturn>> getPurchaseReturns() async {
    return await _repository.getAllPurchaseReturns();
  }

  Future<List<PurchaseReturnItem>> getReturnItems(int returnId) async {
    return await _repository.getReturnItems(returnId);
  }

  Future<List<PurchaseReturn>> filterPurchaseReturns({
    int? distributorId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _repository.getFilteredPurchaseReturns(
      distributorId: distributorId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<List<Purchase>> filterPurchases({
    int? distributorId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _repository.getFilteredPurchases(
      distributorId: distributorId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<void> deletePurchase(int id) async {
    await _repository.deletePurchase(id);
    await loadPurchases();
  }

  Future<void> deletePurchaseReturn(int id) async {
    await _repository.deletePurchaseReturn(id);
    notifyListeners();
  }

  Future<bool> hasReturns(int purchaseId) async {
    final returns = await _repository.getReturnsForPurchase(purchaseId);
    return returns.isNotEmpty;
  }

  Future<void> updatePurchase(Purchase purchase) async {
    await _repository.updatePurchase(purchase);
    await loadPurchases();
  }

  Future<void> editPurchase(Purchase purchase, List<PurchaseItem> items) async {
    await _repository.editPurchase(purchase, items);
    await loadPurchases();
  }

  Future<void> updatePurchaseReturn(PurchaseReturn purchaseReturn) async {
    await _repository.updatePurchaseReturn(purchaseReturn);
    await loadPurchaseReturns();
  }

  Future<void> editPurchaseReturn(
      PurchaseReturn purchaseReturn, List<PurchaseReturnItem> items) async {
    await _repository.editPurchaseReturn(purchaseReturn, items);
    await loadPurchaseReturns();
    await loadPurchases();
  }
}
