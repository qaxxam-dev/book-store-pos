import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../providers/book_provider.dart';
import 'add_edit_book_screen.dart';
import '../../widgets/app_drawer.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../scanner/scanner_screen.dart';

class BookListScreen extends StatefulWidget {
  const BookListScreen({super.key});

  @override
  State<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends State<BookListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookProvider>().loadBooks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onScanBarcode() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerScreen(
          isContinuous: false,
          onScanned: (code) async {
            // ScannerScreen automatically pops when isContinuous is false
            final bookProvider = context.read<BookProvider>();
            final book = await bookProvider.getBookBySku(code);

            if (book != null && mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditBookScreen(book: book),
                ),
              );
            } else if (mounted) {
              AppSnackBar.showError(context, 'Book not found: $code');
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditBookScreen()),
              );
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by Title or SKU...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<BookProvider>().loadBooks();
                        },
                      ),
                    ),
                    onChanged: (value) {
                      context.read<BookProvider>().searchBooks(value);
                    },
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
          ),
          Expanded(
            child: bookProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : bookProvider.books.isEmpty
                    ? const Center(child: Text('No books found'))
                    : ListView.builder(
                        itemCount: bookProvider.books.length,
                        itemBuilder: (context, index) {
                          final book = bookProvider.books[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: ListTile(
                              title: Text(
                                book.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(book.author ?? 'Unknown Author'),
                                  Text(
                                      'Stock: ${book.stockQuantity} | SKU: ${book.sku}'),
                                ],
                              ),
                              trailing: Text(
                                '₹${book.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppTheme.accent700,
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AddEditBookScreen(book: book),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
