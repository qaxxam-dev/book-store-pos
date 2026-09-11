import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/theme.dart';
import '../../../data/models/sale.dart';
import '../../../data/models/sale_item.dart';
import '../../../data/models/book.dart';
import '../../../data/models/customer.dart';
import '../../../data/repositories/sales_repository.dart';
import '../../providers/settings_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/customer_provider.dart';
import '../../../core/services/receipt_service.dart';
import '../../../core/services/share_service.dart';
import '../../providers/sales_provider.dart';
import '../../providers/printer_provider.dart';
import 'sales_entry_screen.dart';
import '../sales_return/sales_return_details_screen.dart';

class SaleDetailsScreen extends StatefulWidget {
  final Sale sale;

  const SaleDetailsScreen({super.key, required this.sale});

  @override
  State<SaleDetailsScreen> createState() => _SaleDetailsScreenState();
}

class _SaleDetailsScreenState extends State<SaleDetailsScreen> {
  final SalesRepository _salesRepository = SalesRepository();
  late Sale _sale;
  List<SaleItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _sale = widget.sale;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().loadSettings();
      context.read<BookProvider>().loadBooks();
    });
    _loadItems();
  }

  Future<void> _editSale() async {
    final salesProvider = context.read<SalesProvider>();
    final hasReturns = await salesProvider.hasReturns(_sale.id!);
    if (!mounted) return;

    if (hasReturns) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Edit Sale'),
          content: const Text(
              'This sale has linked sales returns. Please delete or adjust the returns before editing this sale.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final result = await Navigator.push<Sale>(
      context,
      MaterialPageRoute(
        builder: (context) => PosScreen(
          editingSale: _sale,
          editingItems: _items,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _sale = result;
      });
      _loadItems();
      // Reload customer to update balance display
      if (_sale.customerId != null) {
        context.read<CustomerProvider>().loadCustomers();
      }
    }
  }

  Future<void> _loadItems() async {
    try {
      final items = await _salesRepository.getItemsForSale(_sale.id!);
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackBar.showError(context, 'Error loading items: $e');
      }
    }
  }

  Future<void> _printReceipt() async {
    try {
      final settings = context.read<SettingsProvider>().settings;
      final settingsMap =
          settings.map((key, value) => MapEntry(key, value.toString()));

      final bookProvider = context.read<BookProvider>();
      if (bookProvider.books.isEmpty) {
        await bookProvider.loadBooks();
      }

      final customerProvider = context.read<CustomerProvider>();
      Customer? customer;
      if (_sale.customerId != null) {
        customer = await customerProvider.getCustomerById(_sale.customerId!);
      }

      final receiptService = ReceiptService();
      final printerProvider = context.read<PrinterProvider>();

      await receiptService.printReceipt(
        sale: _sale,
        items: _items,
        books: bookProvider.books,
        settings: settingsMap,
        customer: customer,
        thermalHandler: printerProvider.printMethod == PrintMethod.thermal
            ? (bytes) => printerProvider.printBytes(bytes)
            : null,
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Error printing receipt: $e');
      }
    }
  }

  Future<void> _shareOnWhatsApp() async {
    try {
      final settings = context.read<SettingsProvider>().settings;
      final bookProvider = context.read<BookProvider>();
      final customerProvider = context.read<CustomerProvider>();

      Customer? customer;
      if (_sale.customerId != null) {
        customer = await customerProvider.getCustomerById(_sale.customerId!);
      }

      await ShareService.shareOnWhatsApp(
        context: context,
        sale: _sale,
        items: _items,
        books: bookProvider.books,
        customer: customer,
        settings: settings.map((k, v) => MapEntry(k, v.toString())),
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Error sharing: $e');
      }
    }
  }

  Future<void> _deleteSale() async {
    final salesProvider = context.read<SalesProvider>();
    final hasReturns = await salesProvider.hasReturns(_sale.id!);

    if (!mounted) return;

    if (hasReturns) {
      final returns = await _salesRepository.getReturnsForSale(_sale.id!);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete Sale'),
          // ... rest of dialog content same, just keep logic structure ...
          content: const Text(
              'Sales Delete is blocked because Sales Returns exist for this bill. Open Sales Return?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (returns.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SalesReturnDetailsScreen(returnRecord: returns.first),
                    ),
                  );
                }
              },
              child: const Text('Open Sales Return'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Sale'),
          content: const Text(
              'Are you sure you want to delete this sale? This will revert stock and customer balance.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await salesProvider.deleteSale(_sale.id!);
                  if (mounted) {
                    AppSnackBar.showSuccess(
                        context, 'Sale deleted successfully');
                    Navigator.pop(context); // Go back to list
                  }
                } catch (e) {
                  if (mounted) {
                    AppSnackBar.showError(context, 'Error deleting sale: $e');
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: AppTheme.errorText),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(_sale.timestamp);

    return Scaffold(
      appBar: AppBar(
        title: Text('Sale Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editSale,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _printReceipt,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareOnWhatsApp,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: AppTheme.errorText),
            onPressed: _deleteSale,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Info
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
                            const Text('Bill:',
                                style: TextStyle(color: AppTheme.neutral600)),
                            Text(
                              _sale.billNumber,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Date:',
                                style: TextStyle(color: AppTheme.neutral600)),
                            Text(
                              DateFormat('MMM dd, yyyy hh:mm a').format(date),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Payment:',
                                style: TextStyle(color: AppTheme.neutral600)),
                            Text(
                              _sale.paymentMethod,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _sale.paymentMethod == 'Complementary'
                                    ? AppTheme.accent700
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        if (_sale.paymentMethod == 'Complementary') ...[
                          if (_sale.customerName != null &&
                              _sale.customerName!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Given To:',
                                    style:
                                        TextStyle(color: AppTheme.neutral600)),
                                Text(_sale.customerName!,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                          if (_sale.customerAddress != null &&
                              _sale.customerAddress!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Remarks:',
                                    style:
                                        TextStyle(color: AppTheme.neutral600)),
                                Flexible(
                                  child: Text(
                                    _sale.customerAddress!,
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_sale.customerMobile != null &&
                              _sale.customerMobile!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Phone:',
                                    style:
                                        TextStyle(color: AppTheme.neutral600)),
                                Text(_sale.customerMobile!,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ] else if (_sale.customerId != null) ...[
                          const SizedBox(height: 8),
                          FutureBuilder<Customer?>(
                            future: context
                                .read<CustomerProvider>()
                                .getCustomerById(_sale.customerId!),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                final customer = snapshot.data!;
                                return Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Customer:',
                                            style: TextStyle(
                                                color: AppTheme.neutral600)),
                                        Text(customer.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Phone:',
                                            style: TextStyle(
                                                color: AppTheme.neutral600)),
                                        Text(customer.phone,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Balance:',
                                            style: TextStyle(
                                                color: AppTheme.neutral600)),
                                        Text(
                                            '₹${customer.balance.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.errorText)),
                                      ],
                                    ),
                                  ],
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ] else if (_sale.guestPhone != null &&
                            _sale.guestPhone!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Guest Phone:',
                                  style: TextStyle(color: AppTheme.neutral600)),
                              Text(_sale.guestPhone!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Items Table
                  const Text(
                    'Items',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Table(
                    border: TableBorder.all(color: AppTheme.neutral300),
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(1.5),
                      3: FlexColumnWidth(1.5),
                    },
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(color: AppTheme.neutral200),
                        children: [
                          Padding(
                              padding: EdgeInsets.all(8), child: Text('Item')),
                          Padding(
                              padding: EdgeInsets.all(8), child: Text('Qty')),
                          Padding(
                              padding: EdgeInsets.all(8), child: Text('Price')),
                          Padding(
                              padding: EdgeInsets.all(8), child: Text('Total')),
                        ],
                      ),
                      ..._items.map((item) {
                        final bookProvider = context.watch<BookProvider>();
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
                              description: ''),
                        );
                        return TableRow(
                          children: [
                            Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(book.title)),
                            Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(item.quantity.toString())),
                            Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                    '₹${item.priceAtSale.toStringAsFixed(2)}')),
                            Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                    '₹${(item.quantity * item.priceAtSale).toStringAsFixed(2)}')),
                          ],
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Totals
                  if (_sale.discount > 0) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Subtotal: ₹${(_sale.totalAmount + _sale.discount).toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Discount (${_sale.discountPercent.toStringAsFixed(1)}%): -₹${_sale.discount.toStringAsFixed(2)}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: AppTheme.neutral700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Total: ₹${_sale.totalAmount.toStringAsFixed(2)}',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accent700,
                              ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
