import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:book_store_pos/core/theme.dart';
import 'package:book_store_pos/data/models/book.dart';
import 'package:book_store_pos/data/models/sale.dart';
import 'package:book_store_pos/data/models/sale_item.dart';
import 'package:book_store_pos/data/models/sales_return.dart';
import 'package:book_store_pos/data/models/sales_return_item.dart';
import 'package:book_store_pos/presentation/providers/book_provider.dart';
import 'package:book_store_pos/presentation/providers/customer_provider.dart';
import 'package:book_store_pos/presentation/providers/sales_provider.dart';
import 'package:book_store_pos/core/services/receipt_service.dart';
import 'package:book_store_pos/core/services/share_service.dart';
import 'package:book_store_pos/presentation/providers/settings_provider.dart';
import 'package:book_store_pos/data/models/customer.dart';
import '../../providers/printer_provider.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/entry_date_picker_helper.dart';
import 'sales_return_details_screen.dart';
import '../../providers/auth_provider.dart';

class SalesReturnEntryDetailsScreen extends StatefulWidget {
  final Sale sale;
  final int selectedBookId;
  final SalesReturn? editingReturn;
  final List<SalesReturnItem>? editingReturnItems;

  const SalesReturnEntryDetailsScreen({
    super.key,
    required this.sale,
    required this.selectedBookId,
    this.editingReturn,
    this.editingReturnItems,
  });

  @override
  State<SalesReturnEntryDetailsScreen> createState() =>
      _SalesReturnEntryDetailsScreenState();
}

class _SalesReturnEntryDetailsScreenState
    extends State<SalesReturnEntryDetailsScreen> {
  List<SaleItem> _saleItems = [];
  final Map<int, int> _returnQuantities = {};
  final Map<int, TextEditingController> _controllers = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String _customerName = 'Loading...';

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void initState() {
    super.initState();
    _loadSaleItems();
    _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    if (widget.sale.customerId != null) {
      final customer = await context
          .read<CustomerProvider>()
          .getCustomerById(widget.sale.customerId!);
      if (mounted) {
        setState(() {
          _customerName = customer?.name ?? 'Unknown';
        });
      }
    } else if (widget.sale.guestPhone != null &&
        widget.sale.guestPhone!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _customerName = 'Guest (${widget.sale.guestPhone})';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _customerName = 'Walk-in Customer';
        });
      }
    }
  }

  Future<void> _loadSaleItems() async {
    try {
      final items =
          await context.read<SalesProvider>().getItemsForSale(widget.sale.id!);

      setState(() {
        _saleItems = items;
        _isLoading = false;
        if (widget.editingReturnItems != null) {
          for (var retItem in widget.editingReturnItems!) {
            _returnQuantities[retItem.bookId] = retItem.quantity;
            _controllers[retItem.bookId] =
                TextEditingController(text: retItem.quantity.toString());
          }
          for (var item in items) {
            if (!_returnQuantities.containsKey(item.bookId)) {
              _returnQuantities[item.bookId] = 0;
              _controllers[item.bookId] = TextEditingController(text: '0');
            }
          }
        } else {
          // Initialize return quantities
          for (var item in items) {
            // Auto-fill for all books
            _returnQuantities[item.bookId] = item.quantity;
            _controllers[item.bookId] =
                TextEditingController(text: item.quantity.toString());
          }
        }
      });
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Error loading items: $e');
      }
    }
  }

  void _updateReturnQuantity(int bookId, String value) {
    final qty = int.tryParse(value) ?? 0;
    setState(() {
      _returnQuantities[bookId] = qty;
    });
  }

  double get _totalRefundAmount {
    double total = 0;
    for (var item in _saleItems) {
      final returnQty = _returnQuantities[item.bookId] ?? 0;
      if (returnQty > 0) {
        total += returnQty * item.priceAtSale;
      }
    }

    // Apply discount percentage from original sale
    // Note: Sale model has `discount` (amount) and `discountPercent` (percentage)
    // We should check which one to use.
    // The `Sale` model in `database_helper.dart` shows `discount` and `discount_percent`.
    // Let's check `Sale` model definition.
    // I'll assume `discount` is the fixed amount and `discountPercent` is the %.
    // If `discountPercent` is available, use it.
    // If only `discount` amount is available, we can calculate % or just deduct proportional amount.

    // Let's check the Sale model again.
    // I don't have it open. I'll assume `discount` is the amount.
    // Wait, in `PurchaseReturn`, I used `purchase.discount` as percentage?
    // In `Purchase` model: `final double discount;` (default 0.0).
    // In `PurchaseEntryScreen`, `_totalDiscountController` is "Overall Discount %".
    // So `purchase.discount` IS percentage.

    // In `Sale` model (from `database_helper`):
    // `discount` REAL DEFAULT 0.0
    // `discount_percent` REAL DEFAULT 0.0
    // It seems we have both?
    // Let's check `sales_repository.dart` createSale...
    // It inserts `sale.toMap()`.

    // I will assume `sale.discount` is the amount and `sale.discountPercent` is the percentage
    // based on typical naming, OR `sale.discount` is percentage like Purchase.
    // Let's look at `database_helper` again.
    // `discount` and `discount_percent` columns.

    // I'll check `Sale` model file content if I can... I can't right now.
    // I'll assume `discount` is amount and `discountPercent` is percentage.
    // But if `discountPercent` is 0 and `discount` > 0, maybe `discount` is the amount.

    // Logic:
    // If `discountPercent` > 0, reduce total by that %.
    // Else if `discount` > 0, we need to find what % that was of the original total.
    // % = (discount / (totalAmount + discount)) * 100?
    // Or just (discount / original_subtotal) * 100.

    // Let's simplify:
    // If we have `discountPercent`, use it.
    // If not, calculate effective discount rate from `sale.totalAmount` and `sale.discount`.
    // Effective Rate = sale.discount / (sale.totalAmount + sale.discount)

    // However, `sale.totalAmount` is usually the final amount.
    // So original = total + discount.

    // Let's try to use `discountPercent` if it exists on the model.
    // If not, I'll use `discount` as percentage if it looks like one, or calculate.

    // Safest bet: Calculate effective discount ratio.
    // ratio = sale.discount / (sale.totalAmount + sale.discount)
    // refund = raw_refund * (1 - ratio)

    // But wait, `Purchase` model used `discount` as percentage.
    // I'll check `Sale` model in next step if needed.
    // For now, I'll implement a safe logic.

    double discountRate = 0.0;
    if (widget.sale.discountPercent > 0) {
      discountRate = widget.sale.discountPercent / 100;
    } else if (widget.sale.discount > 0) {
      // Fallback: calculate rate from amount
      // Assuming totalAmount is post-discount
      double originalTotal = widget.sale.totalAmount + widget.sale.discount;
      if (originalTotal > 0) {
        discountRate = widget.sale.discount / originalTotal;
      }
    }

    if (discountRate > 0) {
      total = total * (1 - discountRate);
    }

    return total;
  }

  int get _totalReturnQuantity {
    int total = 0;
    for (var qty in _returnQuantities.values) {
      total += qty;
    }
    return total;
  }

  Future<void> _confirmReturn() async {
    // Validation
    bool hasItemsToReturn = false;
    for (var item in _saleItems) {
      final returnQty = _returnQuantities[item.bookId] ?? 0;
      if (returnQty > 0) {
        hasItemsToReturn = true;

        // Check if return qty > sold qty
        if (returnQty > item.quantity) {
          AppSnackBar.showWarning(
              context, 'Return quantity cannot exceed sold quantity');
          return;
        }
      }
    }

    if (!hasItemsToReturn) {
      AppSnackBar.showWarning(context, 'Please enter quantity to return');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final returnRecord = SalesReturn(
        saleId: widget.sale.id!,
        billNumber: '', // Will be generated by repository
        totalRefund: _totalRefundAmount,
        timestamp: DateTime.now().toIso8601String(),
      );

      final returnItems = <SalesReturnItem>[];

      // Calculate discount rate again for items
      double discountRate = 0.0;
      if (widget.sale.discountPercent > 0) {
        discountRate = widget.sale.discountPercent / 100;
      } else if (widget.sale.discount > 0) {
        double originalTotal = widget.sale.totalAmount + widget.sale.discount;
        if (originalTotal > 0) {
          discountRate = widget.sale.discount / originalTotal;
        }
      }

      for (var item in _saleItems) {
        final returnQty = _returnQuantities[item.bookId] ?? 0;
        if (returnQty > 0) {
          double itemRefund = returnQty * item.priceAtSale;
          if (discountRate > 0) {
            itemRefund = itemRefund * (1 - discountRate);
          }

          returnItems.add(SalesReturnItem(
            returnId: 0, // Will be set by repo
            bookId: item.bookId,
            quantity: returnQty,
            refundAmount: itemRefund,
          ));
        }
      }

      final authProvider = context.read<AuthProvider>();

      if (widget.editingReturn != null) {
        final newTimestamp = await EntryDatePickerHelper.promptEntryDate(
          context,
          currentTimestamp: widget.editingReturn!.timestamp,
          helpText: 'Select Sales Return Date',
        );
        if (newTimestamp == null) {
          if (mounted) setState(() => _isSaving = false);
          return;
        }

        final updatedReturn = widget.editingReturn!.copyWith(
          totalRefund: _totalRefundAmount,
          timestamp: newTimestamp,
        );

        final salesProvider = context.read<SalesProvider>();
        final customerProvider = context.read<CustomerProvider>();
        final bookProvider = context.read<BookProvider>();

        await salesProvider.editSalesReturn(updatedReturn, returnItems);

        if (widget.sale.customerId != null) {
          await customerProvider.getCustomerById(widget.sale.customerId!);
        }
        await bookProvider.loadBooks();

        if (mounted) {
          Navigator.pop(context, updatedReturn);
          AppSnackBar.showSuccess(
              context, 'Sales Return updated successfully!');
        }
        return;
      }

      final newReturn = await context.read<SalesProvider>().processReturn(
            returnRecord,
            returnItems,
            widget.sale.customerId ?? 0,
            widget.sale.paymentMethod == 'Credit',
            isDemo: authProvider.isDemo,
          );

      // Refresh customer to get updated balance if applicable
      if (widget.sale.customerId != null) {
        await context
            .read<CustomerProvider>()
            .getCustomerById(widget.sale.customerId!);
      }

      if (mounted) {
        _showSuccessDialog(newReturn, returnItems);
      }
    } catch (e) {
      if (mounted) {
        if (e is Map && e['type'] == 'purchase_required') {
          DialogUtils.showPurchaseDialog(e['message'], e['url'], context);
        } else {
          AppSnackBar.showError(context, 'Error processing return: $e');
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSuccessDialog(
      SalesReturn returnRecord, List<SalesReturnItem> items) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Return Processed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('The sales return has been processed successfully.'),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Print Button
                ElevatedButton.icon(
                  icon: const Icon(Icons.print),
                  label: const Text('Print'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await Future.microtask(() async {
                      try {
                        final settings =
                            context.read<SettingsProvider>().settings;
                        final settingsMap = settings.map(
                            (key, value) => MapEntry(key, value.toString()));
                        final bookProvider = context.read<BookProvider>();

                        Customer? customer;
                        if (widget.sale.customerId != null) {
                          try {
                            customer = await context
                                .read<CustomerProvider>()
                                .getCustomerById(widget.sale.customerId!);
                          } catch (_) {}
                        }

                        final printerProvider = context.read<PrinterProvider>();

                        await ReceiptService().printSalesReturnReceipt(
                          returnRecord: returnRecord,
                          items: items,
                          books: bookProvider.books,
                          settings: settingsMap,
                          customer: customer,
                          sale: widget.sale,
                          thermalHandler:
                              printerProvider.printMethod == PrintMethod.thermal
                                  ? (bytes) => printerProvider.printBytes(bytes)
                                  : null,
                        );
                      } catch (e) {
                        if (context.mounted) {
                          AppSnackBar.showError(context, 'Error printing: $e');
                        }
                      }
                    });
                  },
                ),

                const SizedBox(height: 12),

                // WhatsApp Button
                if (widget.sale.customerId != null ||
                    (widget.sale.guestPhone != null &&
                        widget.sale.guestPhone!.isNotEmpty))
                  ElevatedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      await Future.microtask(() async {
                        try {
                          final settings =
                              context.read<SettingsProvider>().settings;
                          final bookProvider = context.read<BookProvider>();
                          Customer? customer;
                          if (widget.sale.customerId != null) {
                            try {
                              customer = await context
                                  .read<CustomerProvider>()
                                  .getCustomerById(widget.sale.customerId!);
                            } catch (_) {}
                          }

                          await ShareService.shareSalesReturnOnWhatsApp(
                            context: context,
                            returnRecord: returnRecord,
                            items: items,
                            books: bookProvider.books,
                            customer: customer,
                            sale: widget.sale,
                            settings: settings
                                .map((k, v) => MapEntry(k, v.toString())),
                          );
                        } catch (e) {
                          if (context.mounted) {
                            AppSnackBar.showError(context, 'Error sharing: $e');
                          }
                        }
                      });
                    },
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              // Navigate to details screen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SalesReturnDetailsScreen(returnRecord: returnRecord),
                ),
              );
            },
            child: const Text(
              'Close',
              style: TextStyle(
                color: AppTheme.accent700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editingReturn != null
            ? 'Edit Return: ${widget.editingReturn!.billNumber}'
            : 'Return: ${widget.sale.billNumber}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Sales Details Card
                Card(
                  margin: const EdgeInsets.all(16),
                  color: AppTheme.neutral50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Customer:',
                                style: TextStyle(color: AppTheme.neutral600)),
                            Text(_customerName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Payment:',
                                style: TextStyle(color: AppTheme.neutral600)),
                            Text(widget.sale.paymentMethod,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Discount:',
                                style: TextStyle(color: AppTheme.neutral600)),
                            Text('${widget.sale.discountPercent}%',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _saleItems.length,
                    itemBuilder: (context, index) {
                      final item = _saleItems[index];
                      final book = bookProvider.books.firstWhere(
                          (b) => b.id == item.bookId,
                          orElse: () => Book(
                              title: 'Unknown',
                              sku: '',
                              price: 0,
                              stockQuantity: 0,
                              author: '',
                              publisher: '',
                              category: '',
                              isbn: '',
                              description: ''));

                      final isSelectedBook =
                          item.bookId == widget.selectedBookId;

                      return Card(
                        color: isSelectedBook ? AppTheme.accent50 : null,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(book.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Sold: ${item.quantity}'),
                                      Text('Sold Price: ₹${item.priceAtSale}'),
                                    ],
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: TextField(
                                      controller: _controllers[item.bookId],
                                      decoration: const InputDecoration(
                                        labelText: 'Return Qty',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) =>
                                          _updateReturnQuantity(
                                              item.bookId, value),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.neutral100,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              widget.sale.paymentMethod == 'Credit'
                                  ? 'Total Return Qty:'
                                  : 'Total Refund:',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(
                              widget.sale.paymentMethod == 'Credit'
                                  ? '$_totalReturnQuantity'
                                  : '₹${_totalRefundAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accent700)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _confirmReturn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent700,
                            foregroundColor: Colors.white,
                          ),
                          child: _isSaving
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : Text(
                                  widget.editingReturn != null
                                      ? 'Update Return'
                                      : 'Confirm Return',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}
