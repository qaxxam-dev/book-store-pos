import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../data/models/book.dart';
import '../providers/sales_provider.dart';
import '../providers/book_provider.dart';

class TopSellingBooksWidget extends StatelessWidget {
  const TopSellingBooksWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: context.read<SalesProvider>().getTopSellingBooks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        final books = snapshot.data ?? [];
        if (books.isEmpty) {
          return const Center(child: Text('No sales data yet.'));
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Top Selling Books',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...books.map((book) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(book['title'] ?? 'Unknown',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500))),
                          Text('${book['total_sold']} sold',
                              style:
                                  const TextStyle(color: AppTheme.neutral600)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        );
      },
    );
  }
}

class LowStockBooksWidget extends StatelessWidget {
  const LowStockBooksWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Book>>(
      future: context.read<BookProvider>().getLowStockBooks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        final books = snapshot.data ?? [];
        if (books.isEmpty) {
          return const SizedBox.shrink(); // Hide if no low stock
        }

        return Card(
          color: AppTheme.errorBg,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppTheme.errorText),
                    SizedBox(width: 8),
                    Text('Low Stock Alert',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.errorText)),
                  ],
                ),
                const SizedBox(height: 12),
                ...books.take(5).map((book) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(book.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500))),
                          Text('${book.stockQuantity} left',
                              style: const TextStyle(
                                  color: AppTheme.errorText,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
                if (books.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('+ ${books.length - 5} more',
                        style: const TextStyle(fontStyle: FontStyle.italic)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DeadStockBooksWidget extends StatelessWidget {
  const DeadStockBooksWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: context.read<SalesProvider>().getDeadStock(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        final books = snapshot.data ?? [];
        if (books.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dead Stock (No sales > 30 days)',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...books.take(5).map((book) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(book['title'] ?? 'Unknown',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500))),
                          Text('Stock: ${book['stock_quantity']}',
                              style:
                                  const TextStyle(color: AppTheme.neutral600)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        );
      },
    );
  }
}
