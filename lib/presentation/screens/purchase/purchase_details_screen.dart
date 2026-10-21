import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/theme.dart';
import '../../../data/models/purchase.dart';
import '../../../data/models/purchase_item.dart';
import '../../../data/models/book.dart';
import '../../../data/models/distributor.dart';
import '../../../data/repositories/purchase_repository.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/distributor_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/printer_provider.dart';
import '../../../core/services/receipt_service.dart';
import '../../../core/services/share_service.dart';
import 'purchase_entry_screen.dart';
import '../../widgets/dialogs/transaction_edit_dialog.dart';
import '../purchase_return/purchase_return_details_screen.dart';

class PurchaseDetailsScreen extends StatefulWidget {
  final Purchase purchase;

  const PurchaseDetailsScreen({super.key, required this.purchase});

  @override
  State<PurchaseDetailsScreen> createState() => _PurchaseDetailsScreenState();
}

class _PurchaseDetailsScreenState extends State<PurchaseDetailsScreen> {
  final PurchaseRepository _repository = PurchaseRepository();
  late Purchase _purchase;
  List<PurchaseItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _purchase = widget.purchase;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookProvider>().loadBooks();
      context.read<DistributorProvider>().loadDistributors();
    });
    _loadItems();
  }

  Future<void> _editPurchase() async {
    final purchaseProvider = context.read<PurchaseProvider>();
    final hasReturns = await purchaseProvider.hasReturns(_purchase.id!);
    if (!mounted) return;

    if (hasReturns) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Edit Purchase'),
          content: const Text(
              'This purchase has linked purchase returns. Please delete or adjust the returns before editing this purchase.'),
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

    final result = await Navigator.push<Purchase>(
      context,
      MaterialPageRoute(
        builder: (context) => PurchaseEntryScreen(
          editingPurchase: _purchase,
          editingItems: _items,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _purchase = result;
      });
      _loadItems();
      // Reload distributor to update balance
      context.read<DistributorProvider>().loadDistributors();
    }
  }

  Future<void> _duplicatePurchase() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PurchaseEntryScreen(
          duplicatePurchase: _purchase,
          duplicateItems: _items,
        ),
      ),
    );
  }

  Future<void> _loadItems() async {
    try {
      final items = await context
          .read<PurchaseProvider>()
          .getPurchaseItems(_purchase.id!);
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
      final distributorProvider = context.read<DistributorProvider>();
      final distributor = distributorProvider.distributors.firstWhere(
        (d) => d.id == _purchase.distributorId,
        orElse: () => Distributor(name: 'Unknown', phone: '', balance: 0),
      );

      final printerProvider = context.read<PrinterProvider>();

      await ReceiptService().printPurchaseReceipt(
        purchase: _purchase,
        items: _items,
        books: bookProvider.books,
        settings: settingsMap,
        distributor: distributor,
        thermalHandler: printerProvider.printMethod == PrintMethod.thermal
            ? (bytes) => printerProvider.printBytes(bytes)
            : null,
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Error printing: $e');
      }
    }
  }

  Future<void> _shareOnWhatsApp() async {
    try {
      final settings = context.read<SettingsProvider>().settings;
      final bookProvider = context.read<BookProvider>();
      final distributorProvider = context.read<DistributorProvider>();
      final distributor = distributorProvider.distributors.firstWhere(
        (d) => d.id == _purchase.distributorId,
        orElse: () => Distributor(name: 'Unknown', phone: '', balance: 0),
      );

      await ShareService.sharePurchaseOnWhatsApp(
        context: context,
        purchase: _purchase,
        items: _items,
        books: bookProvider.books,
        distributor: distributor,
        settings: settings.map((k, v) => MapEntry(k, v.toString())),
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Error sharing: $e');
      }
    }
  }

  Future<void> _deletePurchase() async {
    final purchaseProvider = context.read<PurchaseProvider>();
    final hasReturns = await purchaseProvider.hasReturns(_purchase.id!);

    if (!mounted) return;

    if (hasReturns) {
      final returns = await _repository.getReturnsForPurchase(_purchase.id!);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete Purchase'),
          content: const Text(
              'Purchase Delete is blocked because Purchase Returns exist for this bill. Open Purchase Return?'),
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
                      builder: (context) => PurchaseReturnDetailsScreen(
                          returnRecord: returns.first),
                    ),
                  );
                }
              },
              child: const Text('Open Purchase Return'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Purchase'),
          content: const Text(
              'Are you sure you want to delete this purchase? This will revert stock and distributor balance.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await purchaseProvider.deletePurchase(_purchase.id!);
                  if (mounted) {
                    AppSnackBar.showSuccess(
                        context, 'Purchase deleted successfully');
                    Navigator.pop(context); // Go back to list
                  }
                } catch (e) {
                  if (mounted) {
                    AppSnackBar.showError(
                        context, 'Error deleting purchase: $e');
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
    final date = DateTime.parse(_purchase.timestamp);
    final subtotal = _items.fold<double>(
        0, (sum, item) => sum + (item.quantity * item.costPrice));
    final discountAmount = subtotal - _purchase.totalAmount;

    return Scaffold(
      appBar: AppBar(
        title: Text('Purchase Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Purchase',
            onPressed: _editPurchase,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Duplicate Purchase',
            onPressed: _duplicatePurchase,
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
            onPressed: _deletePurchase,
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
                              _purchase.billNumber,
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
                              _purchase.paymentMethod,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Consumer<DistributorProvider>(
                          builder: (context, provider, child) {
                            final distributor =
                                provider.distributors.firstWhere(
                              (d) => d.id == _purchase.distributorId,
                              orElse: () => Distributor(
                                  name: 'Unknown', phone: '', balance: 0),
                            );
                            return Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Distributor:',
                                        style: TextStyle(
                                            color: AppTheme.neutral600)),
                                    Text(distributor.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                if (distributor.phone.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Phone:',
                                          style: TextStyle(
                                              color: AppTheme.neutral600)),
                                      Text(distributor.phone,
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
                                          '₹${distributor.balance.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.errorText)),
                                    ],
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
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
                              padding: EdgeInsets.all(8), child: Text('Cost')),
                          Padding(
                              padding: EdgeInsets.all(8), child: Text('Total')),
                        ],
                      ),
                      ..._items.map((item) {
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
                                    '₹${item.costPrice.toStringAsFixed(2)}')),
                            Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                    '₹${(item.quantity * item.costPrice).toStringAsFixed(2)}')),
                          ],
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Totals
                  if (widget.purchase.discount > 0) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Subtotal: ₹${subtotal.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Discount: -₹${discountAmount.toStringAsFixed(2)}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: AppTheme.successText),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Total: ₹${widget.purchase.totalAmount.toStringAsFixed(2)}',
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
