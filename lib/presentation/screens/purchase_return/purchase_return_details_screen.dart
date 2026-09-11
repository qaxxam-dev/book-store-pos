import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:book_store_pos/core/theme.dart';
import 'package:book_store_pos/data/models/purchase_return.dart';
import 'package:book_store_pos/data/models/purchase_return_item.dart';
import 'package:book_store_pos/data/models/book.dart';
import 'package:book_store_pos/data/models/purchase.dart';
import 'package:book_store_pos/presentation/providers/distributor_provider.dart';
import 'package:book_store_pos/presentation/providers/purchase_provider.dart';
import 'package:book_store_pos/presentation/providers/book_provider.dart';
import '../purchase/purchase_details_screen.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/services/receipt_service.dart';
import '../../../core/services/share_service.dart';
import '../../providers/settings_provider.dart';
import '../../providers/printer_provider.dart';
import 'package:book_store_pos/data/models/distributor.dart';
import '../../widgets/dialogs/transaction_edit_dialog.dart';
import 'purchase_return_entry_details_screen.dart' as entry;

class PurchaseReturnDetailsScreen extends StatefulWidget {
  final PurchaseReturn returnRecord;

  const PurchaseReturnDetailsScreen({super.key, required this.returnRecord});

  @override
  State<PurchaseReturnDetailsScreen> createState() =>
      _PurchaseReturnDetailsScreenState();
}

class _PurchaseReturnDetailsScreenState
    extends State<PurchaseReturnDetailsScreen> {
  late PurchaseReturn _returnRecord;
  List<PurchaseReturnItem> _returnItems = [];

  bool _isLoading = true;
  Purchase? _purchase;
  Distributor? _distributor;
  String _distributorName = 'Loading...';
  double _distributorBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _returnRecord = widget.returnRecord;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DistributorProvider>().loadDistributors();
    });
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final purchaseProvider = context.read<PurchaseProvider>();

      final items = await purchaseProvider.getReturnItems(_returnRecord.id!);

      // Load Purchase
      Purchase? purchase;
      try {
        purchase = purchaseProvider.purchases.firstWhere(
          (p) => p.id == _returnRecord.purchaseId,
        );
      } catch (_) {
        // Purchase not found even after loading
      }

      final distributorProvider = context.read<DistributorProvider>();

      String distributorName = 'Unknown';
      double distributorBalance = 0.0;
      Distributor? distributor;

      if (purchase != null) {
        if (distributorProvider.distributors.isEmpty) {
          await distributorProvider.loadDistributors();
        }
        try {
          distributor = distributorProvider.distributors.firstWhere(
            (d) => d.id == purchase!.distributorId,
          );
          distributorName = distributor.name;
          distributorBalance = distributor.balance;
        } catch (_) {
          // Distributor not found
        }
      }

      if (mounted) {
        setState(() {
          _returnItems = items;
          _purchase = purchase;
          _distributor = distributor;
          _distributorName = distributorName;
          _distributorBalance = distributorBalance;
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

  Future<void> _editReturn() async {
    if (_purchase == null) {
      AppSnackBar.showError(context, 'Original purchase record not found');
      return;
    }

    final updatedReturn = await Navigator.push<PurchaseReturn>(
      context,
      MaterialPageRoute(
        builder: (context) => entry.PurchaseReturnDetailsScreen(
          purchase: _purchase!,
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
      await _loadItems();
    }
  }

  Future<void> _deleteReturn() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Purchase Return'),
        content: const Text(
            'Are you sure you want to delete this return? This will revert stock and distributor balance.'),
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
                    .read<PurchaseProvider>()
                    .deletePurchaseReturn(_returnRecord.id!);
                if (mounted) {
                  AppSnackBar.showSuccess(
                      context, 'Purchase return deleted successfully');
                  Navigator.pop(context); // Go back to list
                }
              } catch (e) {
                if (mounted) {
                  AppSnackBar.showError(
                      context, 'Error deleting purchase return: $e');
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
    final date = DateTime.parse(_returnRecord.timestamp);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Return Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Return',
            onPressed: _isLoading ? null : _editReturn,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () async {
              if (_purchase == null || _distributor == null) return;
              try {
                final settings = context.read<SettingsProvider>().settings;
                final settingsMap = settings
                    .map((key, value) => MapEntry(key, value.toString()));
                final bookProvider = context.read<BookProvider>();

                final printerProvider = context.read<PrinterProvider>();

                await ReceiptService().printPurchaseReturnReceipt(
                  returnRecord: widget.returnRecord,
                  items: _returnItems,
                  books: bookProvider.books,
                  settings: settingsMap,
                  distributor: _distributor!,
                  purchase: _purchase!,
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
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              if (_purchase == null || _distributor == null) return;
              try {
                final settings = context.read<SettingsProvider>().settings;
                final bookProvider = context.read<BookProvider>();

                await ShareService.sharePurchaseReturnOnWhatsApp(
                  context: context,
                  returnRecord: widget.returnRecord,
                  items: _returnItems,
                  books: bookProvider.books,
                  distributor: _distributor!,
                  purchase: _purchase!,
                  settings: settings.map((k, v) => MapEntry(k, v.toString())),
                );
              } catch (e) {
                if (context.mounted) {
                  AppSnackBar.showError(context, 'Error sharing: $e');
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: AppTheme.errorText),
            onPressed: _deleteReturn,
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
                              widget.returnRecord.billNumber,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_purchase != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Purchase Bill:',
                                  style: TextStyle(color: AppTheme.neutral600)),
                              Text(
                                _purchase!.billNumber,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
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
                            Text(_purchase?.paymentMethod ?? 'Unknown',
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
                            Text('${_purchase?.discount ?? 0}%',
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
                            Text('₹${_distributorBalance.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.errorText)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Purchase Details Card
                  // View Original Purchase Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        try {
                          final purchase = context
                              .read<PurchaseProvider>()
                              .purchases
                              .firstWhere((p) =>
                                  p.id == widget.returnRecord.purchaseId);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PurchaseDetailsScreen(purchase: purchase),
                            ),
                          );
                        } catch (e) {
                          AppSnackBar.showError(
                              context, 'Original purchase not found');
                        }
                      },
                      icon: const Icon(Icons.receipt),
                      label: const Text('View Original Purchase'),
                    ),
                  ),
                  const SizedBox(height: 24),

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
                              padding: EdgeInsets.all(8), child: Text('Cost')),
                        ],
                      ),
                      ..._returnItems.map((item) {
                        final bookProvider = context.watch<BookProvider>();
                        final book = bookProvider.books.firstWhere(
                          (b) => b.id == item.bookId,
                          orElse: () => Book(
                              title: 'Unknown (ID: ${item.bookId})',
                              sku: '',
                              price: 0,
                              stockQuantity: 0,
                              author: '',
                              publisher: '',
                              category: '',
                              isbn: '',
                              description: ''),
                        );
                        final cost = item.quantity > 0
                            ? item.refundAmount / item.quantity
                            : 0.0;
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
                                child: Text('₹${cost.toStringAsFixed(2)}')),
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
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
