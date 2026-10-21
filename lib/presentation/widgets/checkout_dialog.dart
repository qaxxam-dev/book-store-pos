import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/utils/entry_date_picker_helper.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../core/utils/dialog_utils.dart';
import '../../data/models/customer.dart';
import '../../data/models/sale.dart';
import '../../data/models/sale_item.dart';
import '../providers/cart_provider.dart';
import '../providers/sales_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/book_provider.dart';
import '../providers/auth_provider.dart';
import 'package:uuid/uuid.dart';

class CheckoutDialog extends StatefulWidget {
  final Customer? customer;
  final String? guestPhone;
  final Sale? editingSale;
  final String? initialDiscountType;
  final double? initialDiscountPercent;
  final double? initialDiscountAmount;

  const CheckoutDialog({
    super.key,
    this.customer,
    this.guestPhone,
    this.editingSale,
    this.initialDiscountType,
    this.initialDiscountPercent,
    this.initialDiscountAmount,
  });

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  String _paymentMethod = 'Cash';
  bool _isProcessing = false;
  final _discountController = TextEditingController();
  double _discountPercent = 0.0;
  double _customDiscountAmount = 0.0;
  String _discountSelection = '0%';
  final FocusNode _customDiscountFocusNode = FocusNode();
  String? _customDiscountError;

  // Shipping
  bool _isShippingEnabled = false;
  final TextEditingController _shippingAmountController =
      TextEditingController(text: '0');
  final TextEditingController _shippingNameController = TextEditingController();
  final TextEditingController _shippingMobileController =
      TextEditingController();
  final TextEditingController _shippingAddressController =
      TextEditingController();
  double _shippingAmount = 0.0;

  // Complementary
  final TextEditingController _complementaryRecipientController =
      TextEditingController();
  final TextEditingController _complementaryRemarksController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.editingSale != null) {
      final sale = widget.editingSale!;
      _paymentMethod = sale.paymentMethod;
      if (sale.discountType == 'amount' ||
          (sale.discountType == null && sale.discount > 0 && sale.discountPercent == 0)) {
        _discountSelection = 'Custom ₹';
        _customDiscountAmount = sale.discount;
        _discountController.text =
            _customDiscountAmount.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
      } else if (sale.discountPercent == 0.0 && sale.discount == 0.0) {
        _discountSelection = '0%';
        _discountPercent = 0.0;
      } else if (sale.discountPercent == 10.0 &&
          (sale.discountType == 'percent' || sale.discountType == null)) {
        _discountSelection = '10%';
        _discountPercent = 10.0;
      } else {
        _discountSelection = 'Custom %';
        _discountPercent = sale.discountPercent;
        _discountController.text =
            _discountPercent.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
      }
      if (sale.shippingAmount > 0) {
        _isShippingEnabled = true;
        _shippingAmount = sale.shippingAmount;
        _shippingAmountController.text = _shippingAmount.toString();
        _shippingNameController.text =
            sale.customerName ?? '';
        _shippingMobileController.text =
            sale.customerMobile ?? '';
        _shippingAddressController.text =
            sale.customerAddress ?? '';
      }
      if (_paymentMethod == 'Complementary') {
        _complementaryRecipientController.text =
            sale.customerName ?? '';
        _complementaryRemarksController.text =
            sale.customerAddress ?? '';
      }
    } else {
      if (widget.initialDiscountType == 'amount' ||
          (widget.initialDiscountType == null &&
              (widget.initialDiscountAmount ?? 0) > 0 &&
              (widget.initialDiscountPercent ?? 0) == 0)) {
        _discountSelection = 'Custom ₹';
        _customDiscountAmount = widget.initialDiscountAmount ?? 0.0;
        _discountController.text = _customDiscountAmount > 0
            ? _customDiscountAmount.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')
            : '';
      } else if ((widget.initialDiscountPercent ?? 0.0) == 10.0 &&
          (widget.initialDiscountType == 'percent' || widget.initialDiscountType == null)) {
        _discountSelection = '10%';
        _discountPercent = 10.0;
      } else if ((widget.initialDiscountPercent ?? 0.0) > 0.0) {
        _discountSelection = 'Custom %';
        _discountPercent = widget.initialDiscountPercent!;
        _discountController.text =
            _discountPercent.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
      } else {
        _discountSelection = '0%';
        _discountPercent = 0.0;
      }

      if (widget.customer != null) {
        _shippingNameController.text = widget.customer!.name;
        _shippingMobileController.text = widget.customer!.phone;
        _complementaryRecipientController.text = widget.customer!.name;
      } else if (widget.guestPhone != null) {
        _shippingMobileController.text = widget.guestPhone!;
      }
    }
  }

  @override
  void dispose() {
    _discountController.dispose();
    _customDiscountFocusNode.dispose();
    _shippingAmountController.dispose();
    _shippingNameController.dispose();
    _shippingMobileController.dispose();
    _shippingAddressController.dispose();
    _complementaryRecipientController.dispose();
    _complementaryRemarksController.dispose();
    super.dispose();
  }

  Future<void> _processSale() async {
    final cartProvider = context.read<CartProvider>();
    final subtotal =
        cartProvider.items.fold(0.0, (sum, item) => sum + item.total);
    final isComplementary = _paymentMethod == 'Complementary';

    if (!isComplementary) {
      if (_discountSelection == 'Custom %' && _customDiscountError != null) {
        AppSnackBar.showError(
          context,
          'Please enter a valid custom discount percentage (0 - 100%).',
        );
        return;
      }
      if (_discountSelection == 'Custom ₹') {
        if (_customDiscountError != null) {
          AppSnackBar.showError(
            context,
            _customDiscountError ?? 'Please enter a valid discount amount.',
          );
          return;
        }
        if (_customDiscountAmount > subtotal) {
          AppSnackBar.showError(
            context,
            'Discount amount cannot exceed subtotal ₹${subtotal.toStringAsFixed(2)}.',
          );
          return;
        }
      }
    }

    if (_paymentMethod == 'Credit' && widget.customer == null) {
      AppSnackBar.showError(
        context,
        'Credit sales require a registered customer. Please select or create a customer.',
      );
      return;
    }

    if (isComplementary &&
        _complementaryRecipientController.text.trim().isEmpty) {
      AppSnackBar.showError(
        context,
        'Please enter who the complement is given to.',
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final salesProvider = context.read<SalesProvider>();

      final String currentDiscountType = isComplementary
          ? 'none'
          : (_discountSelection == '0%'
              ? 'none'
              : (_discountSelection == '10%'
                  ? 'percent'
                  : (_discountSelection == 'Custom %'
                      ? 'percent'
                      : 'amount')));

      double effectiveDiscountPercent = 0.0;
      double discountAmount = 0.0;
      if (isComplementary) {
        effectiveDiscountPercent = 100.0;
        discountAmount = subtotal;
      } else if (_discountSelection == '0%') {
        effectiveDiscountPercent = 0.0;
        discountAmount = 0.0;
      } else if (_discountSelection == '10%') {
        effectiveDiscountPercent = 10.0;
        discountAmount = subtotal * 0.10;
      } else if (_discountSelection == 'Custom %') {
        effectiveDiscountPercent = _discountPercent;
        discountAmount = subtotal * (_discountPercent / 100);
      } else if (_discountSelection == 'Custom ₹') {
        discountAmount = _customDiscountAmount;
        effectiveDiscountPercent =
            subtotal > 0 ? (_customDiscountAmount / subtotal) * 100 : 0.0;
      }

      final double finalTotal =
          isComplementary ? 0.0 : (subtotal - discountAmount + _shippingAmount);

      final String? finalCustomerName = isComplementary
          ? _complementaryRecipientController.text.trim()
          : (_isShippingEnabled ? _shippingNameController.text.trim() : null);

      final String? finalCustomerMobile = isComplementary
          ? (widget.customer?.phone ?? widget.guestPhone)
          : (_isShippingEnabled ? _shippingMobileController.text.trim() : null);

      final String? finalCustomerAddress = isComplementary
          ? (_complementaryRemarksController.text.trim().isNotEmpty
              ? _complementaryRemarksController.text.trim()
              : null)
          : (_isShippingEnabled ? _shippingAddressController.text.trim() : null);

      final saleItems = cartProvider.items.map((item) {
        return SaleItem(
          saleId: widget.editingSale?.id ?? 0,
          bookId: item.book.id!,
          quantity: item.quantity,
          priceAtSale: item.book.price,
        );
      }).toList();

      if (widget.editingSale != null) {
        final newTimestamp = await EntryDatePickerHelper.promptEntryDate(
          context,
          currentTimestamp: widget.editingSale!.timestamp,
          helpText: 'Select Sale Date',
        );
        if (newTimestamp == null) {
          if (mounted) setState(() => _isProcessing = false);
          return;
        }

        final updatedSale = widget.editingSale!.copyWith(
          customerId: isComplementary ? widget.customer?.id : widget.customer?.id,
          guestPhone: widget.guestPhone,
          totalAmount: finalTotal,
          discount: discountAmount,
          discountPercent: effectiveDiscountPercent,
          discountType: currentDiscountType,
          paymentMethod: _paymentMethod,
          timestamp: newTimestamp,
          shippingAmount: isComplementary ? 0.0 : _shippingAmount,
          customerName: finalCustomerName,
          customerMobile: finalCustomerMobile,
          customerAddress: finalCustomerAddress,
        );

        final customerProvider = context.read<CustomerProvider>();
        final bookProvider = context.read<BookProvider>();

        await salesProvider.editSale(updatedSale, saleItems);

        await customerProvider.loadCustomers();
        await bookProvider.loadBooks();
        cartProvider.clearCart();

        if (mounted) {
          Navigator.pop(context, updatedSale);
          AppSnackBar.showSuccess(context, 'Sale updated successfully!');
        }
        return;
      }

      final sale = Sale(
        customerId: widget.customer?.id,
        guestPhone: widget.guestPhone,
        totalAmount: finalTotal,
        discount: discountAmount,
        discountPercent: effectiveDiscountPercent,
        discountType: currentDiscountType,
        paymentMethod: _paymentMethod,
        timestamp: DateTime.now().toIso8601String(),
        billNumber:
            const Uuid().v4().substring(0, 8).toUpperCase(), // Simple Bill No
        shippingAmount: isComplementary ? 0.0 : _shippingAmount,
        customerName: finalCustomerName,
        customerMobile: finalCustomerMobile,
        customerAddress: finalCustomerAddress,
      );

      final authProvider = context.read<AuthProvider>();
      final saleId = await salesProvider.createSale(
        sale,
        saleItems,
        isDemo: authProvider.isDemo,
      );

      if (!mounted) return;

      // Update Customer Balance if Credit
      if (_paymentMethod == 'Credit' && widget.customer != null) {
        final customerProvider = context.read<CustomerProvider>();
        final updatedCustomer = Customer(
          id: widget.customer!.id,
          name: widget.customer!.name,
          phone: widget.customer!.phone,
          balance: widget.customer!.balance + finalTotal,
        );
        await customerProvider.updateCustomer(updatedCustomer);
      }

      cartProvider.clearCart();

      if (mounted) {
        // Fetch the created sale to get the correct Bill Number generated by the DB
        final createdSale = await salesProvider.getSaleById(saleId);
        if (createdSale != null) {
          Navigator.pop(context, createdSale);
          AppSnackBar.showSuccess(context, 'Sale completed successfully!');
        } else {
          // Fallback (should not happen)
          final fallbackSale = sale.copyWith(id: saleId);
          Navigator.pop(context, fallbackSale);
        }
      }
    } catch (e) {
      if (mounted) {
        if (e is Map && e['type'] == 'purchase_required') {
          // Close processing state first if needed, but dialog is sufficient
          setState(() => _isProcessing = false);
          DialogUtils.showPurchaseDialog(e['message'], e['url'], context);
        } else {
          AppSnackBar.showError(context, 'Error processing sale: $e');
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final subtotal =
        cartProvider.items.fold(0.0, (sum, item) => sum + item.total);
    final isComplementary = _paymentMethod == 'Complementary';
    double discountAmount = 0.0;
    if (isComplementary) {
      discountAmount = subtotal;
    } else if (_discountSelection == '0%') {
      discountAmount = 0.0;
    } else if (_discountSelection == '10%') {
      discountAmount = subtotal * 0.10;
    } else if (_discountSelection == 'Custom %') {
      discountAmount = subtotal * (_discountPercent / 100);
    } else if (_discountSelection == 'Custom ₹') {
      discountAmount = _customDiscountAmount;
    }

    final totalAmount =
        isComplementary ? 0.0 : (subtotal - discountAmount + _shippingAmount);

    return AlertDialog(
      title: const Text('Checkout'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.customer != null) ...[
              Text('Customer: ${widget.customer!.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
            ] else if (widget.guestPhone != null &&
                widget.guestPhone!.isNotEmpty) ...[
              Text('Guest Phone: ${widget.guestPhone}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
            ],

            if (isComplementary)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accent100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accent300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.card_giftcard, color: AppTheme.accent700),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Complementary Sale: 100% free / sample copy.',
                        style: TextStyle(
                          color: AppTheme.accent700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Fixed Discount Dropdown
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Discount',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.percent, size: 20),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _discountSelection,
                    isExpanded: true,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(
                          value: '0%', child: Text('No Discount (0%)')),
                      DropdownMenuItem(
                          value: '10%', child: Text('10% Discount')),
                      DropdownMenuItem(
                          value: 'Custom %', child: Text('Custom Discount %')),
                      DropdownMenuItem(
                          value: 'Custom ₹',
                          child: Text('Custom Discount ₹ (Discount Amount)')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _discountSelection = value;
                        _customDiscountError = null;
                        if (value == '0%') {
                          _discountPercent = 0.0;
                          _customDiscountAmount = 0.0;
                          _discountController.clear();
                        } else if (value == '10%') {
                          _discountPercent = 10.0;
                          _customDiscountAmount = subtotal * 0.10;
                          _discountController.clear();
                        } else if (value == 'Custom %') {
                          _discountController.clear();
                          _discountPercent = 0.0;
                          _customDiscountAmount = 0.0;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _customDiscountFocusNode.requestFocus();
                          });
                        } else if (value == 'Custom ₹') {
                          _discountController.clear();
                          _discountPercent = 0.0;
                          _customDiscountAmount = 0.0;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _customDiscountFocusNode.requestFocus();
                          });
                        }
                      });
                    },
                  ),
                ),
              ),
              if (_discountSelection == 'Custom %') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _discountController,
                  focusNode: _customDiscountFocusNode,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Custom Discount (%)',
                    border: const OutlineInputBorder(),
                    suffixText: '%',
                    prefixIcon: const Icon(Icons.edit, size: 20),
                    errorText: _customDiscountError,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value.trim().isEmpty) {
                        _discountPercent = 0.0;
                        _customDiscountError = null;
                        return;
                      }
                      final parsed = double.tryParse(value);
                      if (parsed == null || parsed < 0 || parsed > 100) {
                        _customDiscountError = 'Enter 0 to 100%';
                        _discountPercent = 0.0;
                      } else {
                        _customDiscountError = null;
                        _discountPercent = parsed;
                      }
                    });
                  },
                ),
              ] else if (_discountSelection == 'Custom ₹') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _discountController,
                  focusNode: _customDiscountFocusNode,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Custom Discount (₹)',
                    border: const OutlineInputBorder(),
                    prefixText: '₹ ',
                    prefixIcon: const Icon(Icons.currency_rupee, size: 20),
                    errorText: _customDiscountError,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value.trim().isEmpty) {
                        _customDiscountAmount = 0.0;
                        _customDiscountError = null;
                        return;
                      }
                      final parsed = double.tryParse(value);
                      if (parsed == null || parsed < 0) {
                        _customDiscountError = 'Enter a valid amount';
                        _customDiscountAmount = 0.0;
                      } else if (parsed > subtotal) {
                        _customDiscountError =
                            'Cannot exceed subtotal ₹${subtotal.toStringAsFixed(2)}';
                        _customDiscountAmount = parsed;
                      } else {
                        _customDiscountError = null;
                        _customDiscountAmount = parsed;
                      }
                    });
                  },
                ),
              ],
              const SizedBox(height: 16),
            ],

            const Text('Payment Method:'),
            DropdownButton<String>(
              value: _paymentMethod,
              isExpanded: true,
              items: ['Cash', 'Card', 'UPI', 'Credit', 'Complementary']
                  .map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _paymentMethod = newValue!;
                });
              },
            ),
            if (_paymentMethod == 'Credit' && widget.customer == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Please select a customer for Credit sale',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),

            if (isComplementary) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _complementaryRecipientController,
                decoration: const InputDecoration(
                  labelText: 'Given To (Recipient Name) *',
                  hintText: 'Enter recipient or institution name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _complementaryRemarksController,
                decoration: const InputDecoration(
                  labelText: 'Reason / Remarks (Optional)',
                  hintText: 'e.g. Author copy, Reviewer, Event gift',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
            ],
            const SizedBox(height: 24),

            if (!isComplementary) ...[
              // Shipping Option
              SwitchListTile(
                title: const Text('Add Shipping'),
                value: _isShippingEnabled,
                onChanged: (value) {
                  setState(() {
                    _isShippingEnabled = value;
                    if (!value) {
                      _shippingAmount = 0.0;
                      _shippingAmountController.text = '0';
                    }
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
            ],

            if (_isShippingEnabled) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _shippingNameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _shippingMobileController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _shippingAddressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Shipping Address',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _shippingAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Shipping Charge',
                  border: OutlineInputBorder(),
                  prefixText: '₹',
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() {
                    _shippingAmount = double.tryParse(value) ?? 0.0;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            // Totals Summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal:'),
                Text('₹${subtotal.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Discount:',
                    style: TextStyle(color: AppTheme.neutral700)),
                Text('-₹${discountAmount.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppTheme.neutral700)),
              ],
            ),
            if (_shippingAmount > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Shipping:',
                      style: TextStyle(color: AppTheme.neutral700)),
                  Text('+₹${_shippingAmount.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppTheme.neutral700)),
                ],
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total:',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent700,
                      ),
                ),
                Text(
                  '₹${totalAmount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent700,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context, false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppTheme.accent700),
          ),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _processSale,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent700, // Background color
            foregroundColor: AppTheme.neutral100, // Disabled state text color
          ),
          child: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(widget.editingSale != null
                  ? 'Update Sale'
                  : 'Complete Sale'),
        )
      ],
    );
  }
}
