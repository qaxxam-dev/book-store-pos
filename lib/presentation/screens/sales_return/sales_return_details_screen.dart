import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:book_store_pos/core/theme.dart';
import 'package:book_store_pos/data/models/book.dart';
import 'package:book_store_pos/data/models/sales_return.dart';
import 'package:book_store_pos/data/models/sales_return_item.dart';
import 'package:book_store_pos/presentation/providers/book_provider.dart';
import 'package:book_store_pos/presentation/providers/sales_provider.dart';
import 'package:book_store_pos/data/models/sale.dart';
import 'package:book_store_pos/data/models/customer.dart';
import 'package:book_store_pos/presentation/providers/customer_provider.dart';
import 'package:intl/intl.dart';
import '../sales/sale_details_screen.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/services/receipt_service.dart';
import '../../../core/services/share_service.dart';
import '../../providers/settings_provider.dart';
import '../../providers/printer_provider.dart';

import '../../widgets/dialogs/transaction_edit_dialog.dart';
import 'sales_return_entry_details_screen.dart';

class SalesReturnDetailsScreen extends StatefulWidget {
  final SalesReturn returnRecord;

  const SalesReturnDetailsScreen({
    super.key,
    required this.returnRecord,
  });

  @override
  State<SalesReturnDetailsScreen> createState() =>
      _SalesReturnDetailsScreenState();
}

class _SalesReturnDetailsScreenState extends State<SalesReturnDetailsScreen> {
  late SalesReturn _returnRecord;
  List<SalesReturnItem> _returnItems = [];
  bool _isLoading = true;
  Sale? _originalSale;
  Customer? _customer;

  @override
  void initState() {
    super.initState();
    _returnRecord = widget.returnRecord;
    _loadData();
  }

  Future<void> _editReturn() async {
    if (_originalSale == null) {
      AppSnackBar.showError(context, 'Original sale record not found');
      return;
    }

    final updatedReturn = await Navigator.push<SalesReturn>(
      context,
      MaterialPageRoute(
        builder: (context) => SalesReturnEntryDetailsScreen(
          sale: _originalSale!,
          selectedBookId: 0,
          editingReturn: _returnRecord,
          editingReturnItems: _returnItems,
        ),
      ),
    );

    if (updatedReturn != null && mounted) {
      setState(() {
        _returnRecord = updatedReturn;
        _isLoading = true;
      });
      await _loadData();
    }
  }

  Future<void> _loadData() async {
    try {
      final salesProvider = context.read<SalesProvider>();
      final customerProvider = context.read<CustomerProvider>();

      // Load items
      final items = await salesProvider.getReturnItems(_returnRecord.id!);

      // Load original sale
      final sale = await salesProvider.getSaleById(_returnRecord.saleId);

      Customer? customer;
      if (sale != null && sale.customerId != null) {
        customer = await customerProvider.getCustomerById(sale.customerId!);
      }

      if (mounted) {
        setState(() {
          _returnItems = items;
          _originalSale = sale;
          _customer = customer;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackBar.showError(context, 'Error loading details: $e');
      }
    }
  }

  Future<void> _deleteReturn() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sales Return'),
        content: const Text(
            'Are you sure you want to delete this return? This will revert stock and customer balance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context
                    .read<SalesProvider>()
                    .deleteSalesReturn(_returnRecord.id!);
                if (mounted) {
                  AppSnackBar.showSuccess(
                      context, 'Sales return deleted successfully');
                  Navigator.pop(context); // Go back to list
                }
              } catch (e) {
                if (mounted) {
                  AppSnackBar.showError(
                      context, 'Error deleting sales return: $e');
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

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final date = DateTime.parse(_returnRecord.timestamp);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sale Return Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Return',
            onPressed: _isLoading ? null : _editReturn,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print Receipt',
            onPressed: _isLoading
                ? null
                : () async {
                    await Future.microtask(() async {
                      try {
                        final settings =
                            context.read<SettingsProvider>().settings;
                        final settingsMap = settings.map(
                            (key, value) => MapEntry(key, value.toString()));
                        final bookProvider = context.read<BookProvider>();

                        final printerProvider = context.read<PrinterProvider>();

                        await ReceiptService().printSalesReturnReceipt(
                          returnRecord: _returnRecord,
                          items: _returnItems,
                          books: bookProvider.books,
                          settings: settingsMap,
                          customer: _customer,
                          sale: _originalSale!,
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
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share on WhatsApp',
            onPressed: _isLoading
                ? null
                : () async {
                    await Future.microtask(() async {
                      try {
                        final settings =
                            context.read<SettingsProvider>().settings;
                        final bookProvider = context.read<BookProvider>();

                        await ShareService.shareSalesReturnOnWhatsApp(
                          context: context,
                          returnRecord: widget.returnRecord,
                          items: _returnItems,
                          books: bookProvider.books,
                          customer: _customer,
                          sale: _originalSale!,
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
          IconButton(
            icon: const Icon(Icons.delete, color: AppTheme.errorText),
            tooltip: 'Delete Return',
            onPressed: _isLoading ? null : _deleteReturn,
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
                              _returnRecord.billNumber,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Sale Bill:',
                                style: TextStyle(color: AppTheme.neutral600)),
                            Text(
                              _originalSale!.billNumber,
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
                            const Text('Customer:',
                                style: TextStyle(color: AppTheme.neutral600)),
                            Text(
                              _customer?.name ??
                                  (_originalSale!.guestPhone != null &&
                                          _originalSale!.guestPhone!.isNotEmpty
                                      ? 'Guest (${_originalSale!.guestPhone})'
                                      : 'Walk-in Customer'),
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
                            Text(_originalSale!.paymentMethod,
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
                            Text('${_originalSale!.discountPercent}%',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Balance:',
                                style: TextStyle(color: AppTheme.neutral600)),
                            Text(
                                '₹${(_customer?.balance ?? 0.0).toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.errorText)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // View Original Sales Button
                  if (_originalSale != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  SaleDetailsScreen(sale: _originalSale!),
                            ),
                          );
                        },
                        icon: const Icon(Icons.receipt),
                        label: const Text('View Original Sales'),
                      ),
                    ),
                  if (_originalSale != null) const SizedBox(height: 24),

                  // Items Table
                  const Text(
                    'Returned Items',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Table(
                    border: TableBorder.all(color: AppTheme.neutral300),
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(1.5),
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
                              padding: EdgeInsets.all(8),
                              child: Text('Refund')),
                        ],
                      ),
                      ..._returnItems.map((item) {
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
                                    '₹${item.refundAmount.toStringAsFixed(2)}')),
                          ],
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Totals
                  Align(
                      alignment: Alignment.centerRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Total Return Qty: ${_returnItems.fold(0, (sum, item) => sum + item.quantity)}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.warningText,
                                ),
                          ),
                          SizedBox(
                              height:
                                  4), // Optional spacing between the two lines
                          Text(
                            'Total Refund: ₹${_returnRecord.totalRefund.toStringAsFixed(2)}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.warningText,
                                ),
                          ),
                        ],
                      )),
                ],
              ),
            ),
    );
  }
}
