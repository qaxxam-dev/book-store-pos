import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:book_store_pos/core/theme.dart';
import 'package:book_store_pos/data/models/book.dart';
import 'package:book_store_pos/data/models/distributor.dart';
import 'package:book_store_pos/data/models/purchase.dart';
import 'package:book_store_pos/presentation/providers/book_provider.dart';
import 'package:book_store_pos/presentation/providers/purchase_provider.dart';
import 'package:book_store_pos/presentation/providers/distributor_provider.dart';
import '../../widgets/app_drawer.dart';
import '../scanner/scanner_screen.dart';

import '../../../core/utils/snackbar_utils.dart';
import '../../../core/services/feedback_service.dart';
import '../../providers/settings_provider.dart';
import 'purchase_return_entry_details_screen.dart';

class PurchaseReturnEntryScreen extends StatefulWidget {
  const PurchaseReturnEntryScreen({super.key});

  @override
  State<PurchaseReturnEntryScreen> createState() =>
      _PurchaseReturnEntryScreenState();
}

class _PurchaseReturnEntryScreenState extends State<PurchaseReturnEntryScreen> {
  final _bookSearchController = TextEditingController();
  Book? _selectedBook;
  List<Purchase> _relatedPurchases = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookProvider>().loadBooks();
      context.read<DistributorProvider>().loadDistributors();
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
      final purchases =
          await context.read<PurchaseProvider>().getPurchasesByBook(book.id!);
      setState(() {
        _relatedPurchases = purchases;
      });
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Error loading purchases: $e');
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
      _relatedPurchases = [];
    });
    context.read<BookProvider>().loadBooks();
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final distributorProvider = context.watch<DistributorProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Return Entry')),
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
                'Purchases containing "${_selectedBook!.title}"',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _relatedPurchases.isEmpty
                        ? const Center(
                            child: Text('No purchases found for this book.'))
                        : ListView.builder(
                            itemCount: _relatedPurchases.length,
                            itemBuilder: (context, index) {
                              final purchase = _relatedPurchases[index];
                              final distributor =
                                  distributorProvider.distributors.firstWhere(
                                      (d) => d.id == purchase.distributorId,
                                      orElse: () => Distributor(
                                          name: 'Unknown', phone: ''));

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  title: Text(purchase.billNumber,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Distributor: ${distributor.name}'),
                                      Text(
                                          'Date: ${purchase.timestamp.split('T')[0]}'),
                                      Text(
                                          'Total: ₹${purchase.totalAmount.toStringAsFixed(2)}'),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios),
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            PurchaseReturnDetailsScreen(
                                          purchase: purchase,
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
                    'Search for a book or scan a barcode to see purchase history.',
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
