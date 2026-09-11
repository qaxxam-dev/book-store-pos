import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:book_store_pos/core/theme.dart';
import 'package:book_store_pos/data/models/book.dart';
import 'package:book_store_pos/data/models/purchase.dart';
import 'package:book_store_pos/data/models/purchase_item.dart';
import 'package:book_store_pos/data/models/purchase_return.dart';
import 'package:book_store_pos/data/models/purchase_return_item.dart';
import 'package:book_store_pos/presentation/providers/book_provider.dart';
import 'package:book_store_pos/presentation/providers/distributor_provider.dart';
import 'package:book_store_pos/data/models/distributor.dart';
import 'package:book_store_pos/presentation/providers/purchase_provider.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/entry_date_picker_helper.dart';
import '../../../core/services/receipt_service.dart';
import '../../providers/auth_provider.dart';
import '../../../core/services/share_service.dart';
import '../../providers/settings_provider.dart';
import '../../providers/printer_provider.dart';

class PurchaseReturnDetailsScreen extends StatefulWidget {
  final Purchase purchase;
  final int selectedBookId;
  final PurchaseReturn? editingReturn;
  final List<PurchaseReturnItem>? editingReturnItems;

  const PurchaseReturnDetailsScreen({
    super.key,
    required this.purchase,
    required this.selectedBookId,
    this.editingReturn,
    this.editingReturnItems,
  });

  @override
  State<PurchaseReturnDetailsScreen> createState() =>
      _PurchaseReturnDetailsScreenState();
}

class _PurchaseReturnDetailsScreenState
    extends State<PurchaseReturnDetailsScreen> {
  List<PurchaseItem> _purchaseItems = [];
  Map<int, int> _returnQuantities = {};
  final Map<int, TextEditingController> _controllers = {};

  bool _isLoading = true;
  bool _isSaving = false;
  String _distributorName = 'Loading...';

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void initState() {
    super.initState();
    _loadPurchaseItems();
    _loadDistributor();
  }

  Future<void> _loadDistributor() async {
    final distributorProvider = context.read<DistributorProvider>();
    if (distributorProvider.distributors.isEmpty) {
      await distributorProvider.loadDistributors();
    }
    try {
      final distributor = distributorProvider.distributors.firstWhere(
        (d) => d.id == widget.purchase.distributorId,
      );
      if (mounted) {
        setState(() {
          _distributorName = distributor.name;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _distributorName = 'Unknown';
        });
      }
    }
  }

  Future<void> _loadPurchaseItems() async {
    try {
      final items = await context
          .read<PurchaseProvider>()
          .getPurchaseItems(widget.purchase.id!);
      setState(() {
        _purchaseItems = items;
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
          // Initialize return quantities to min(stock, purchased)
          for (var item in items) {
            final book = context.read<BookProvider>().books.firstWhere(
                (b) => b.id == item.bookId,
                orElse: () => Book(
                    title: '',
                    sku: '',
                    price: 0,
                    stockQuantity: 0,
                    author: '',
                    publisher: '',
                    category: '',
                    isbn: '',
                    description: ''));

            // Default to current stock if less than purchased, else purchased
            int defaultQty = item.quantity;
            if (book.stockQuantity < item.quantity) {
              defaultQty = book.stockQuantity;
            }

            _returnQuantities[item.bookId] = defaultQty;
            _controllers[item.bookId] =
                TextEditingController(text: defaultQty.toString());
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
    for (var item in _purchaseItems) {
      final returnQty = _returnQuantities[item.bookId] ?? 0;
      if (returnQty > 0) {
        total += returnQty * item.costPrice;
      }
    }
    // Apply discount percentage from original purchase
    if (widget.purchase.discount > 0) {
      total = total * (1 - widget.purchase.discount / 100);
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
    for (var item in _purchaseItems) {
      final returnQty = _returnQuantities[item.bookId] ?? 0;
      if (returnQty > 0) {
        hasItemsToReturn = true;

        // Check if return qty > purchased qty
        if (returnQty > item.quantity) {
          AppSnackBar.showWarning(
              context, 'Return quantity cannot exceed purchased quantity');
          return;
        }

        // Check if return qty > current stock
        final book = context
            .read<BookProvider>()
            .books
            .firstWhere((b) => b.id == item.bookId);
        if (returnQty > book.stockQuantity) {
          AppSnackBar.showWarning(context,
              'Return quantity cannot exceed current stock for ${book.title}');
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
      final returnRecord = PurchaseReturn(
        purchaseId: widget.purchase.id!,
        billNumber: '', // Will be generated by repository
        totalRefund: _totalRefundAmount,
        timestamp: DateTime.now().toIso8601String(),
      );

      final returnItems = <PurchaseReturnItem>[];
      for (var item in _purchaseItems) {
        final returnQty = _returnQuantities[item.bookId] ?? 0;
        if (returnQty > 0) {
          // Calculate refund amount for this item including proportional discount
          double itemRefund = returnQty * item.costPrice;
          if (widget.purchase.discount > 0) {
            itemRefund = itemRefund * (1 - widget.purchase.discount / 100);
          }

          returnItems.add(PurchaseReturnItem(
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
          helpText: 'Select Purchase Return Date',
        );
        if (newTimestamp == null) {
          if (mounted) setState(() => _isSaving = false);
          return;
        }

        final updatedReturn = widget.editingReturn!.copyWith(
          totalRefund: _totalRefundAmount,
          timestamp: newTimestamp,
        );

        final purchaseProvider = context.read<PurchaseProvider>();
        final distributorProvider = context.read<DistributorProvider>();
        final bookProvider = context.read<BookProvider>();

        await purchaseProvider.editPurchaseReturn(updatedReturn, returnItems);

        await distributorProvider.loadDistributors();
        await bookProvider.loadBooks();

        if (mounted) {
          Navigator.pop(context, updatedReturn);
          AppSnackBar.showSuccess(
              context, 'Purchase Return updated successfully!');
        }
        return;
      }

      final newReturn = await context.read<PurchaseProvider>().processReturn(
            returnRecord,
            returnItems,
            widget.purchase.distributorId,
            widget.purchase.paymentMethod == 'Credit',
            isDemo: authProvider.isDemo,
          );

      // Refresh distributors to get updated balance
      await context.read<DistributorProvider>().loadDistributors();

      // Get the updated distributor object
      final updatedDistributor = context
          .read<DistributorProvider>()
          .distributors
          .firstWhere((d) => d.id == widget.purchase.distributorId);

      if (mounted) {
        _showSuccessDialog(newReturn, returnItems, updatedDistributor);
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

  void _showSuccessDialog(PurchaseReturn returnRecord,
      List<PurchaseReturnItem> items, Distributor distributor) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Return Processed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Print Button
                ElevatedButton.icon(
                  icon: const Icon(Icons.print),
                  label: const Text('Print Receipt'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent700,
                  ),
                  onPressed: () async {
                    await Future.microtask(() async {
                      try {
                        final settings =
                            context.read<SettingsProvider>().settings;
                        final settingsMap = settings.map(
                            (key, value) => MapEntry(key, value.toString()));
                        final bookProvider = context.read<BookProvider>();

                        final printerProvider = context.read<PrinterProvider>();

                        await ReceiptService().printPurchaseReturnReceipt(
                          returnRecord: returnRecord,
                          items: items,
                          books: bookProvider.books,
                          settings: settingsMap,
                          distributor: distributor,
                          purchase: widget.purchase,
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
                ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('WhatsApp Share'),
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

                        await ShareService.sharePurchaseReturnOnWhatsApp(
                          context: context,
                          returnRecord: returnRecord,
                          items: items,
                          books: bookProvider.books,
                          distributor: distributor,
                          purchase: widget.purchase,
                          settings:
                              settings.map((k, v) => MapEntry(k, v.toString())),
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
              Navigator.pop(context, true); // Go back to list
            },
            child: const Text(
              'Close',
              style: TextStyle(
                color: AppTheme.accent700,
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
            : 'Return: ${widget.purchase.billNumber}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Purchase Details Card
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
                            const Text('Distributor:',
                                style: TextStyle(color: AppTheme.neutral600)),
                            Text(_distributorName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Payment:',
                                style: TextStyle(color: AppTheme.neutral600)),
                            Text(widget.purchase.paymentMethod,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Discount:',
                                style: TextStyle(color: AppTheme.neutral600)),
                            Text('${widget.purchase.discount}%',
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
                    itemCount: _purchaseItems.length,
                    itemBuilder: (context, index) {
                      final item = _purchaseItems[index];
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
                                      Text('Purchased: ${item.quantity}'),
                                      Text(
                                          'Current Stock: ${book.stockQuantity}'),
                                      Text('Cost: ₹${item.costPrice}'),
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
                        color: Colors.black.withOpacity(0.1),
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
                              widget.purchase.paymentMethod == 'Credit'
                                  ? 'Total Return Qty:'
                                  : 'Total Refund:',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(
                              widget.purchase.paymentMethod == 'Credit'
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
                            backgroundColor:
                                AppTheme.accent700, // Red for return
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
