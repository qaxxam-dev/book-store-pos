import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../../core/services/feedback_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/sale.dart';
import '../../../data/models/sale_item.dart';
import '../../../data/repositories/sales_repository.dart';
import '../../providers/book_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/printer_provider.dart';
import '../../widgets/cart_widget.dart';
import '../../widgets/customer_selection_widget.dart';
import '../../widgets/checkout_dialog.dart';
import '../../widgets/app_drawer.dart';
import '../scanner/scanner_screen.dart';
import '../../../core/services/receipt_service.dart';
import '../../../core/services/share_service.dart';

class PosScreen extends StatefulWidget {
  final Sale? editingSale;
  final List<SaleItem>? editingItems;
  final Sale? duplicateSale;
  final List<SaleItem>? duplicateItems;

  const PosScreen({
    super.key,
    this.editingSale,
    this.editingItems,
    this.duplicateSale,
    this.duplicateItems,
  });

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  Customer? _selectedCustomer;
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bookProvider = context.read<BookProvider>();
      await bookProvider.loadBooks();
      if (!mounted) return;
      context.read<SettingsProvider>().loadSettings();

      if (widget.editingSale != null) {
        final cartProvider = context.read<CartProvider>();
        cartProvider.clearCart();

        // Populate items in cart
        if (widget.editingItems != null) {
          for (var item in widget.editingItems!) {
            try {
              final book =
                  bookProvider.books.firstWhere((b) => b.id == item.bookId);
              cartProvider.addToCart(book);
              cartProvider.updateQuantity(book, item.quantity);
            } catch (_) {}
          }
        }

        // Preload customer or guest phone
        if (widget.editingSale!.customerId != null) {
          final customerProvider = context.read<CustomerProvider>();
          if (customerProvider.customers.isEmpty) {
            await customerProvider.loadCustomers();
          }
          try {
            final customer = customerProvider.customers.firstWhere(
              (c) => c.id == widget.editingSale!.customerId,
            );
            if (mounted) {
              setState(() {
                _selectedCustomer = customer;
                _customerController.text = customer.name;
              });
            }
          } catch (_) {}
        } else if (widget.editingSale!.guestPhone != null) {
          _customerController.text = widget.editingSale!.guestPhone!;
        }
      } else if (widget.duplicateSale != null) {
        final cartProvider = context.read<CartProvider>();
        cartProvider.clearCart();

        // Populate items in cart
        if (widget.duplicateItems != null) {
          for (var item in widget.duplicateItems!) {
            try {
              final book =
                  bookProvider.books.firstWhere((b) => b.id == item.bookId);
              cartProvider.addToCart(book);
              cartProvider.updateQuantity(book, item.quantity);
            } catch (_) {}
          }
        }
        // Customer and distributor fields left empty for manual entry
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerController.dispose();
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
    final cartProvider = context.read<CartProvider>();

    final book = await bookProvider.getBookBySku(sku);
    if (book != null) {
      cartProvider.addToCart(book);

      // Feedback
      final settings = context.read<SettingsProvider>();
      FeedbackService.trigger(settings.feedbackType);
    } else {
      // Optional: Vibrate differently for error?
      if (mounted) {
        AppSnackBar.showError(context, 'Book not found: $sku');
      }
    }
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (scrollContext, scrollController) {
          return Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Current Cart',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(child: CartWidget()),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: context.watch<CartProvider>().items.isEmpty
                        ? null
                        : () async {
                            Navigator.pop(sheetContext); // Close sheet
                            final result = await showDialog(
                              context: context, // Use PosScreen context
                              builder: (_) => CheckoutDialog(
                                customer: _selectedCustomer,
                                guestPhone: _selectedCustomer == null
                                    ? _customerController.text
                                    : null,
                                editingSale: widget.editingSale,
                                initialDiscountType:
                                    widget.duplicateSale?.discountType,
                                initialDiscountPercent:
                                    widget.duplicateSale?.discountPercent,
                                initialDiscountAmount:
                                    widget.duplicateSale?.discount,
                              ),
                            );

                            if (result is Sale && mounted) {
                              if (widget.editingSale != null) {
                                Navigator.pop(context, result);
                                return;
                              }

                              // Clear Cart & Refresh stock
                              context.read<CartProvider>().clearCart();
                              context.read<BookProvider>().loadBooks();

                              // Fetch items for receipt/share
                              final items = await SalesRepository()
                                  .getItemsForSale(result.id!);

                              // Refresh customer data to get updated balance
                              if (result.customerId != null) {
                                await context
                                    .read<CustomerProvider>()
                                    .getCustomerById(result.customerId!);
                              }

                              if (mounted) {
                                // Clear inputs
                                setState(() {
                                  _selectedCustomer = null;
                                  _customerController.clear();
                                });

                                // Show success dialog
                                _showSuccessDialog(result, items);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppTheme.accent700,
                    ),
                    child: Text(
                      widget.editingSale != null
                          ? 'PROCEED TO UPDATE'
                          : 'PROCEED TO CHECKOUT',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  void _showSuccessDialog(Sale sale, List<SaleItem> items) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Sale Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Column for vertical stacking
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
                    // Use a separate isolate or microtask to avoid UI blocking
                    await Future.microtask(() async {
                      try {
                        final settings =
                            context.read<SettingsProvider>().settings;
                        final settingsMap = settings.map(
                            (key, value) => MapEntry(key, value.toString()));
                        final bookProvider = context.read<BookProvider>();

                        Customer? customer;
                        if (sale.customerId != null) {
                          try {
                            customer = context
                                .read<CustomerProvider>()
                                .customers
                                .firstWhere((c) => c.id == sale.customerId);
                          } catch (_) {}
                        }

                        final printerProvider = context.read<PrinterProvider>();

                        await ReceiptService().printReceipt(
                          sale: sale,
                          items: items,
                          books: bookProvider.books,
                          settings: settingsMap,
                          customer: customer,
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

                if (sale.shippingAmount > 0) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.local_shipping),
                    label: const Text('Print Shipping Slip'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () async {
                      await Future.microtask(() async {
                        try {
                          final settings =
                              context.read<SettingsProvider>().settings;
                          final settingsMap = settings.map(
                              (key, value) => MapEntry(key, value.toString()));

                          final printerProvider =
                              context.read<PrinterProvider>();

                          if (printerProvider.printMethod !=
                              PrintMethod.thermal) {
                            AppSnackBar.showError(context,
                                'Shipping slip currently only supported on Thermal Printer.');
                            return;
                          }

                          await ReceiptService().printShippingSlip(
                            sale: sale,
                            settings: settingsMap,
                            thermalHandler: (bytes) =>
                                printerProvider.printBytes(bytes),
                          );
                        } catch (e) {
                          if (context.mounted) {
                            AppSnackBar.showError(
                                context, 'Error printing slip: $e');
                          }
                        }
                      });
                    },
                  ),
                ],

                const SizedBox(height: 12),

                // WhatsApp Button
                if (sale.customerId != null ||
                    (sale.guestPhone != null && sale.guestPhone!.isNotEmpty))
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
                          if (sale.customerId != null) {
                            try {
                              customer = context
                                  .read<CustomerProvider>()
                                  .customers
                                  .firstWhere((c) => c.id == sale.customerId);
                            } catch (_) {}
                          }

                          await ShareService.shareOnWhatsApp(
                            context: context,
                            sale: sale,
                            items: items,
                            books: bookProvider.books,
                            customer: customer,
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
            onPressed: () => Navigator.pop(ctx),
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
    final cartProvider = context.watch<CartProvider>();
    final bookProvider = context.watch<BookProvider>();

    final filteredBooks = bookProvider.books.where((book) {
      if (_searchQuery.isEmpty) return true;
      return book.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          book.sku.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editingSale != null
            ? 'Edit Sale: ${widget.editingSale!.billNumber}'
            : (widget.duplicateSale != null ? 'New Sale (Copied)' : 'POS')),
        leading: (widget.editingSale != null || widget.duplicateSale != null)
            ? const BackButton()
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<CartProvider>().clearCart();
              context.read<BookProvider>().loadBooks(); // Refresh stock
              setState(() {
                _selectedCustomer = null;
                _customerController.clear();
              });
            },
          ),
        ],
      ),
      drawer: (widget.editingSale != null || widget.duplicateSale != null)
          ? null
          : const AppDrawer(),
      body: Column(
        children: [
          // Top Section: Customer & Search
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                CustomerSelectionWidget(
                  controller: _customerController,
                  onCustomerSelected: (customer) {
                    setState(() {
                      _selectedCustomer = customer;
                      _customerController.text = customer.name;
                    });
                  },
                  onChanged: (value) {
                    setState(() {
                      // If user types something that doesn't match selected customer name, clear selection
                      if (_selectedCustomer != null &&
                          _selectedCustomer!.name != value) {
                        _selectedCustomer = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search Books...',
                          prefixIcon: Icon(Icons.search),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _onScanBarcode,
                      icon: const Icon(Icons.qr_code_scanner),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.accent700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Product Grid
          Expanded(
            child: bookProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.all(8), // Reduced padding
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220, // Responsive column count
                      childAspectRatio: 1.35,
                      crossAxisSpacing: 8, // Reduced spacing
                      mainAxisSpacing: 8,
                    ),
                    itemCount: filteredBooks.length,
                    itemBuilder: (context, index) {
                      final book = filteredBooks[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => cartProvider.addToCart(book),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  book.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Stock: ${book.stockQuantity}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: book.stockQuantity < 5
                                        ? AppTheme.errorText
                                        : AppTheme.neutral600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '₹${book.price}',
                                  style: const TextStyle(
                                    color: AppTheme.accent700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Cart Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cartProvider.items.length} Items',
                      style: const TextStyle(color: AppTheme.neutral600),
                    ),
                    Text(
                      '₹${cartProvider.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent700,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _showCartBottomSheet,
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text('View Cart'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent700,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
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
