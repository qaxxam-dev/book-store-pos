import 'package:flutter/material.dart';
import '../../data/models/customer.dart';
import '../../core/utils/purchase_url_helper.dart';
import '../../data/models/customer_payment.dart';
import '../../data/repositories/customer_repository.dart';

class CustomerProvider with ChangeNotifier {
  final CustomerRepository _customerRepository = CustomerRepository();
  List<Customer> _customers = [];
  bool _isLoading = false;

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;

  Future<void> loadCustomers() async {
    _isLoading = true;
    notifyListeners();
    try {
      _customers = await _customerRepository.getAllCustomers();
    } catch (e) {
      print('Error loading customers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCustomer(Customer customer, {bool isDemo = false}) async {
    if (isDemo && _customers.length >= 5) {
      throw {
        'type': 'purchase_required',
        'message':
            'Demo version is limited to 5 customers. Please purchase a license to continue.',
        'url': PurchaseUrlHelper.kPurchaseUrl
      };
    }
    await _customerRepository.insertCustomer(customer);
    await loadCustomers();
  }

  Future<void> updateCustomer(Customer customer) async {
    await _customerRepository.updateCustomer(customer);
    await loadCustomers();
  }

  Future<void> deleteCustomer(int id) async {
    await _customerRepository.deleteCustomer(id);
    await loadCustomers();
  }

  Future<void> searchCustomers(String query) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (query.isEmpty) {
        await loadCustomers();
      } else {
        _customers = await _customerRepository.searchCustomers(query);
      }
    } catch (e) {
      print('Error searching customers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<CustomerPayment>> getPayments(int customerId) async {
    return await _customerRepository.getPaymentsForCustomer(customerId);
  }

  Future<void> addPayment(CustomerPayment payment,
      {bool isDemo = false}) async {
    if (isDemo) {
      final payments = await getAllPayments();
      // Count total payments or just check length of loaded payments?
      // Since getAllPayments loads all, we can check its length.
      // But maybe efficient to just count? For demo (local sqlite/list), loading all is fine.
      if (payments.length >= 5) {
        throw {
          'type': 'purchase_required',
          'message':
              'Demo version is limited to 5 customer payments. Please purchase a license to continue.',
          'url': PurchaseUrlHelper.kPurchaseUrl
        };
      }
    }
    await _customerRepository.addPayment(payment);
    await loadCustomers(); // Reload to update balance
  }

  Future<void> updatePayment(CustomerPayment payment, double oldAmount) async {
    await _customerRepository.updatePayment(payment, oldAmount);
    await loadCustomers(); // Reload to update balance
  }

  Future<void> deletePayment(CustomerPayment payment) async {
    await _customerRepository.deletePayment(
      payment.id!,
      payment.customerId,
      payment.amount,
    );
    await loadCustomers(); // Reload to update balance
  }

  Future<Customer?> getCustomerById(int id) async {
    if (_customers.isEmpty) {
      await loadCustomers();
    }
    try {
      return _customers.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<List<CustomerPayment>> getAllPayments() async {
    return await _customerRepository.getAllPayments();
  }
}
