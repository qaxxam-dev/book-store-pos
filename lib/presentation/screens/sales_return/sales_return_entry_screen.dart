import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:book_store_pos/core/theme.dart';
import 'package:book_store_pos/data/models/book.dart';
import 'package:book_store_pos/data/models/customer.dart';
import 'package:book_store_pos/data/models/sale.dart';
import 'package:book_store_pos/presentation/providers/book_provider.dart';
import 'package:book_store_pos/presentation/providers/sales_provider.dart';
import 'package:book_store_pos/presentation/providers/customer_provider.dart';
import '../../widgets/app_drawer.dart';
import '../scanner/scanner_screen.dart';

import '../../../core/utils/snackbar_utils.dart';
import '../../../core/services/feedback_service.dart';
import '../../providers/settings_provider.dart';
import 'sales_return_entry_details_screen.dart';

class SalesReturnEntryScreen extends StatefulWidget {
  const SalesReturnEntryScreen({super.key});

  @override
  State<SalesReturnEntryScreen> createState() => _SalesReturnEntryScreenState();
}

class _SalesReturnEntryScreenState extends State<SalesReturnEntryScreen> {
  final _bookSearchController = TextEditingController();
  Book? _selectedBook;
  List<Sale> _relatedSales = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookProvider>().loadBooks();
      context.read<CustomerProvider>().loadCustomers();
    });
  }

  @override
  void dispose() {
    _bookSearchController.dispose();
    super.dispose();
  }

  Future<void> _onScanBarcode() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerScreen(
          isContinuous: false,
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
      final settings = context.read<SettingsProvider>();
      FeedbackService.trigger(settings.feedbackType);
      _selectBook(book);
      if (mounted) {
        AppSnackBar.showSuccess(context, '${book.title} selected');
      }
    } else {
      if (mounted) {
        AppSnackBar.showError(context, 'Book not found: $sku');
      }
    }
  }

  void _selectBook(Book book) async {
    setState(() {
      _selectedBook = book;
      _bookSearchController.text = book.title;
      _isLoading = true;
    });

    try {
      final sales =
          await context.read<SalesProvider>().getSalesByBook(book.id!);
      setState(() {
        _relatedSales = sales;
      });
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Error loading sales: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resetSearch() {
    setState(() {
      _selectedBook = null;
      _bookSearchController.clear();
      _relatedSales = [];
    });
    context.read<BookProvider>().loadBooks();
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final customerProvider = context.watch<CustomerProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Sales Return Entry')),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.neutral100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.neutral300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TypeAheadField<Book>(
                      controller: _bookSearchController,
                      builder: (context, controller, focusNode) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Search Book (Title or SKU)',
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
                      onSelected: _selectBook,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    onPressed: _onScanBarcode,
                    icon: const Icon(Icons.qr_code_scanner),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.accent700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                    tooltip: 'Scan Barcode',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Results Section
            if (_selectedBook != null) ...[
              Text(
                'Sales containing "${_selectedBook!.title}"',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _relatedSales.isEmpty
                        ? const Center(
                            child: Text('No sales found for this book.'))
                        : ListView.builder(
                            itemCount: _relatedSales.length,
                            itemBuilder: (context, index) {
                              final sale = _relatedSales[index];
                              final customer = customerProvider.customers
                                  .firstWhere((c) => c.id == sale.customerId,
                                      orElse: () =>
                                          Customer(name: 'Unknown', phone: ''));

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  title: Text(sale.billNumber,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Customer: ${customer.name}'),
                                      Text(
                                          'Date: ${sale.timestamp.split('T')[0]}'),
                                      Text(
                                          'Total: ₹${sale.totalAmount.toStringAsFixed(2)}'),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios),
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            SalesReturnEntryDetailsScreen(
                                          sale: sale,
                                          selectedBookId: _selectedBook!.id!,
                                        ),
                                      ),
                                    );
                                    if (result == true) {
                                      _resetSearch();
                                    }
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ] else
              const Expanded(
                child: Center(
                  child: Text(
                    'Search for a book or scan a barcode to see sales history.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
