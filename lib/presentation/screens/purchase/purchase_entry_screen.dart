import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:book_store_pos/core/theme.dart';
import 'package:book_store_pos/data/models/book.dart';
import 'package:book_store_pos/data/models/distributor.dart';
import 'package:book_store_pos/data/models/purchase.dart';
import 'package:book_store_pos/data/models/purchase_item.dart';
import 'package:book_store_pos/presentation/providers/book_provider.dart';
import 'package:book_store_pos/presentation/providers/distributor_provider.dart';
import 'package:book_store_pos/presentation/providers/purchase_provider.dart';
import 'package:book_store_pos/presentation/providers/printer_provider.dart';
import '../../widgets/app_drawer.dart';
import '../home_screen.dart';
import '../scanner/scanner_screen.dart';

import '../../../core/services/feedback_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/entry_date_picker_helper.dart';
import '../../../core/services/receipt_service.dart';
import '../../../core/services/share_service.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';

class PurchaseEntryScreen extends StatefulWidget {
  final Purchase? editingPurchase;
  final List<PurchaseItem>? editingItems;

  const PurchaseEntryScreen({
    super.key,
    this.editingPurchase,
    this.editingItems,
  });

  @override
  State<PurchaseEntryScreen> createState() => _PurchaseEntryScreenState();
}

class _PurchaseEntryScreenState extends State<PurchaseEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  Distributor? _selectedDistributor;
  final _billNumberController = TextEditingController();
  final _bookSearchController = TextEditingController();
  final _quantityController = TextEditingController();
  final _discountController = TextEditingController();
  final _totalDiscountController = TextEditingController();

  Book? _selectedBook;
  final List<PurchaseItem> _cartItems = [];
  String _paymentMethod = 'Cash';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final distributorProvider = context.read<DistributorProvider>();
      await distributorProvider.loadDistributors();
      if (!mounted) return;
      await context.read<BookProvider>().loadBooks();
      if (!mounted) return;

      if (widget.editingPurchase != null) {
        // Pre-fill distributor
        try {
          final dist = distributorProvider.distributors.firstWhere(
            (d) => d.id == widget.editingPurchase!.distributorId,
          );
          _selectedDistributor = dist;
        } catch (_) {}

        // Pre-fill payment method and discount
        _paymentMethod = widget.editingPurchase!.paymentMethod;
        if (widget.editingPurchase!.discount > 0) {
          _totalDiscountController.text =
              widget.editingPurchase!.discount.toString();
        }

        // Pre-fill items
        if (widget.editingItems != null) {
          _cartItems.addAll(widget.editingItems!);
        }

        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _billNumberController.dispose();
    _bookSearchController.dispose();
    _quantityController.dispose();
    _discountController.dispose();
    _totalDiscountController.dispose();
    super.dispose();
  }

  Future<void> _onScanBarcode() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerScreen(
          isContinuous: true,
          onScanned: (code) {
            _handleBarcode(code);
          },
        ),
      ),
    );
  }

  void _handleBarcode(String sku) async {
    final bookProvider = context.read<BookProvider>();
    final book = await bookProvider.getBookBySku(sku);

    if (book != null) {
      if (mounted) {
        setState(() {
          final existingIndex =
              _cartItems.indexWhere((item) => item.bookId == book.id);

          if (existingIndex != -1) {
            // Increment quantity
            final currentItem = _cartItems[existingIndex];
            _cartItems[existingIndex] = PurchaseItem(
              purchaseId: currentItem.purchaseId,
              bookId: currentItem.bookId,
              quantity: currentItem.quantity + 1,
              costPrice: currentItem.costPrice,
            );
          } else {
            // Add new item
            _cartItems.add(PurchaseItem(
              purchaseId: 0,
              bookId: book.id!,
              quantity: 1,
              costPrice: book.price * 1.0, // Default cost = book price
            ));
          }
        });

        final settings = context.read<SettingsProvider>();
        FeedbackService.trigger(settings.feedbackType);
      }
    } else {
      if (mounted) {
        AppSnackBar.showError(context, 'Book not found: $sku');
      }
    }
  }

  void _updateQuantity(int index, String value) {
    final quantity = int.tryParse(value);
    if (quantity != null && quantity > 0) {
      setState(() {
        final currentItem = _cartItems[index];
        _cartItems[index] = PurchaseItem(
          purchaseId: currentItem.purchaseId,
          bookId: currentItem.bookId,
          quantity: quantity,
          costPrice: currentItem.costPrice,
        );
      });
    }
  }

  void _addItem() {
    if (_selectedBook == null) {
      AppSnackBar.showWarning(context, 'Please select a book');
      return;
    }

    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final discount = double.tryParse(_discountController.text) ?? 0.0;

    if (quantity <= 0) {
      AppSnackBar.showWarning(context, 'Invalid quantity');
      return;
    }

    // Calculate Cost Price based on MRP and Discount
    // Cost = MRP * (1 - Discount / 100)
    final costPrice = _selectedBook!.price * (1 - discount / 100);

    setState(() {
      _cartItems.add(PurchaseItem(
        purchaseId: 0, // Temporary ID, will be set by repository
        bookId: _selectedBook!.id!,
        quantity: quantity,
        costPrice: costPrice,
      ));
      _selectedBook = null;
      _bookSearchController.clear();
      _quantityController.clear();
      _discountController.clear();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
  }

  double get _totalAmount {
    return _cartItems.fold(
        0.0, (sum, item) => sum + (item.quantity * item.costPrice));
  }

  double get _finalTotalAmount {
    final discount = double.tryParse(_totalDiscountController.text) ?? 0.0;
    return _totalAmount * (1 - discount / 100);
  }

  Future<void> _savePurchase() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDistributor == null) {
      AppSnackBar.showWarning(context, 'Please select a distributor');
      return;
    }
    if (_cartItems.isEmpty) {
      AppSnackBar.showWarning(context, 'Please add items to purchase');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.editingPurchase != null) {
        final newTimestamp = await EntryDatePickerHelper.promptEntryDate(
          context,
          currentTimestamp: widget.editingPurchase!.timestamp,
          helpText: 'Select Purchase Date',
        );
        if (newTimestamp == null) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        final updatedPurchase = widget.editingPurchase!.copyWith(
          distributorId: _selectedDistributor!.id!,
          totalAmount: _finalTotalAmount,
          discount: double.tryParse(_totalDiscountController.text) ?? 0.0,
          paymentMethod: _paymentMethod,
          timestamp: newTimestamp,
        );

        final purchaseProvider = context.read<PurchaseProvider>();
        final distributorProvider = context.read<DistributorProvider>();
        final bookProvider = context.read<BookProvider>();

        await purchaseProvider.editPurchase(updatedPurchase, _cartItems);

        await distributorProvider.loadDistributors();
        await bookProvider.loadBooks();

        if (mounted) {
          Navigator.pop(context, updatedPurchase);
          AppSnackBar.showSuccess(context, 'Purchase updated successfully!');
        }
        return;
      }

      final purchase = Purchase(
        distributorId: _selectedDistributor!.id!,
        billNumber: 'PUR-${DateTime.now().millisecondsSinceEpoch}',
        totalAmount: _finalTotalAmount,
        discount: double.tryParse(_totalDiscountController.text) ?? 0.0,
        paymentMethod: _paymentMethod,
        timestamp: DateTime.now().toIso8601String(),
      );

      final authProvider = context.read<AuthProvider>();

      final newPurchase = await context
          .read<PurchaseProvider>()
          .createPurchase(purchase, _cartItems, isDemo: authProvider.isDemo);

      // Refresh distributors to get updated balance
      await context.read<DistributorProvider>().loadDistributors();

      // Get the updated distributor object
      final updatedDistributor = context
          .read<DistributorProvider>()
          .distributors
          .firstWhere((d) => d.id == _selectedDistributor!.id);

      if (mounted) {
        setState(() {
          _selectedDistributor = updatedDistributor;
        });
        // Show success dialog
        _showSuccessDialog(newPurchase, _cartItems, updatedDistributor);
      }
    } catch (e) {
      if (mounted) {
        if (e is Map && e['type'] == 'purchase_required') {
          DialogUtils.showPurchaseDialog(e['message'], e['url'], context);
        } else {
          AppSnackBar.showError(context, 'Error saving purchase: $e');
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(
      Purchase purchase, List<PurchaseItem> items, Distributor distributor) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Purchase Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Print Button
                ElevatedButton.icon(
                  icon: const Icon(Icons.print),
                  label: const Text('Print'),
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

                        await ReceiptService().printPurchaseReceipt(
                          purchase: purchase,
                          items: items,
                          books: bookProvider.books,
                          settings: settingsMap,
                          distributor: distributor,
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

                        await ShareService.sharePurchaseOnWhatsApp(
                          context: context,
                          purchase: purchase,
                          items: items,
                          books: bookProvider.books,
                          distributor: distributor,
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
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()));
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
    final distributorProvider = context.watch<DistributorProvider>();
    final bookProvider = context.watch<BookProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editingPurchase != null
            ? 'Edit Purchase: ${widget.editingPurchase!.billNumber}'
            : 'Purchase Entry'),
        leading: widget.editingPurchase != null ? const BackButton() : null,
      ),
      drawer: widget.editingPurchase != null ? null : const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Distributor Selection
              DropdownButtonFormField<Distributor>(
                value: _selectedDistributor,
                decoration: const InputDecoration(
                  labelText: 'Select Distributor',
                  border: OutlineInputBorder(),
                ),
                items: distributorProvider.distributors.map((d) {
                  return DropdownMenuItem(value: d, child: Text(d.name));
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedDistributor = value),
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 24),

              // Add Item Section
              const Text('Add Items',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.neutral100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.neutral300),
                ),
                child: Column(
                  children: [
                    TypeAheadField<Book>(
                      controller: _bookSearchController,
                      builder: (context, controller, focusNode) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Search Book',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                          ),
                        );
                      },
                      suggestionsCallback: (pattern) {
                        return bookProvider.books
                            .where((book) =>
                                book.title
                                    .toLowerCase()
                                    .contains(pattern.toLowerCase()) ||
                                book.sku.contains(pattern))
                            .toList();
                      },
                      itemBuilder: (context, book) {
                        return ListTile(
                          title: Text(book.title),
                          subtitle: Text('SKU: ${book.sku}'),
                        );
                      },
                      onSelected: (book) {
                        setState(() {
                          _selectedBook = book;
                          _bookSearchController.text = book.title;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _quantityController,
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const SizedBox(width: 12),
                        const SizedBox(width: 12),
                        IconButton.filled(
                          onPressed: _onScanBarcode,
                          icon: const Icon(Icons.qr_code_scanner),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.accent700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _addItem,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Items List
              if (_cartItems.isNotEmpty) ...[
                const Text('Items List',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _cartItems.length,
                  itemBuilder: (context, index) {
                    final item = _cartItems[index];
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
                    return Card(
                      child: ListTile(
                        title: Padding(
                          padding: const EdgeInsets.only(
                              bottom: 16.0, top: 16.0), // Adjust height here
                          child: Text(book.title),
                        ),
                        subtitle: Row(
                          children: [
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                key:
                                    ValueKey('${item.bookId}-${item.quantity}'),
                                initialValue: item.quantity.toString(),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Qty',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) =>
                                    _updateQuantity(index, value),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('x ₹${item.costPrice}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                '₹${(item.quantity * item.costPrice).toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: AppTheme.errorText),
                              onPressed: () => _removeItem(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.neutral100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount:',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('₹${_finalTotalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accent700)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _totalDiscountController,
                      decoration: const InputDecoration(
                        labelText: 'Overall Discount %',
                        border: OutlineInputBorder(),
                        suffixText: '%',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Cash', 'Credit', 'Card', 'UPI'].map((method) {
                        return DropdownMenuItem(
                            value: method, child: Text(method));
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _paymentMethod = value!),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _savePurchase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent700,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : Text(
                                widget.editingPurchase != null
                                    ? 'Update Purchase'
                                    : 'Save Purchase',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
