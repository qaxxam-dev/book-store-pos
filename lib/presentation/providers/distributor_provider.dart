import 'package:flutter/material.dart';
import '../../data/models/distributor.dart';
import '../../core/utils/purchase_url_helper.dart';
import '../../data/models/distributor_payment.dart';
import '../../data/repositories/distributor_repository.dart';

class DistributorProvider with ChangeNotifier {
  final DistributorRepository _repository = DistributorRepository();
  List<Distributor> _distributors = [];
  bool _isLoading = false;

  List<Distributor> get distributors => _distributors;
  bool get isLoading => _isLoading;

  Future<void> loadDistributors() async {
    _isLoading = true;
    notifyListeners();
    try {
      _distributors = await _repository.getAllDistributors();
    } catch (e) {
      debugPrint('Error loading distributors: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addDistributor(Distributor distributor,
      {bool isDemo = false}) async {
    if (isDemo && _distributors.length >= 5) {
      throw {
        'type': 'purchase_required',
        'message':
            'Demo version is limited to 5 distributors. Please purchase a license to continue.',
        'url': PurchaseUrlHelper.kPurchaseUrl
      };
    }
    await _repository.insertDistributor(distributor);
    await loadDistributors();
  }

  Future<void> updateDistributor(Distributor distributor) async {
    await _repository.updateDistributor(distributor);
    await loadDistributors();
  }

  Future<void> deleteDistributor(int id) async {
    await _repository.deleteDistributor(id);
    await loadDistributors();
  }

  Future<List<DistributorPayment>> getPayments(int distributorId) async {
    return await _repository.getPaymentsForDistributor(distributorId);
  }

  Future<void> addPayment(DistributorPayment payment,
      {bool isDemo = false}) async {
    if (isDemo) {
      final payments = await getAllPayments();
      if (payments.length >= 5) {
        throw {
          'type': 'purchase_required',
          'message':
              'Demo version is limited to 5 distributor payments. Please purchase a license to continue.',
          'url': PurchaseUrlHelper.kPurchaseUrl
        };
      }
    }
    await _repository.addPayment(payment);
    await loadDistributors(); // Reload to update balance
  }

  Future<void> updatePayment(
      DistributorPayment payment, double oldAmount) async {
    await _repository.updatePayment(payment, oldAmount);
    await loadDistributors(); // Reload to update balance
  }

  Future<void> deletePayment(DistributorPayment payment) async {
    await _repository.deletePayment(
      payment.id!,
      payment.distributorId,
      payment.amount,
    );
    await loadDistributors(); // Reload to update balance
  }

  Future<List<DistributorPayment>> getAllPayments() async {
    return await _repository.getAllPayments();
  }
}
