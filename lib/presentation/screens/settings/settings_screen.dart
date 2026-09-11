import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/printer_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/sales_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/distributor_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/auth_provider.dart';
import '../../screens/auth/login_screen.dart';

import '../../../data/models/sale_item.dart';
import '../../../data/models/sales_return_item.dart';
import '../../../data/models/purchase_item.dart';
import '../../../data/models/purchase_return_item.dart';
import '../../../core/services/excel_service.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/theme.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/app_drawer.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'excel_import_screen.dart';
import 'shop_details_screen.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../providers/settings_provider.dart';
import '../../../core/services/feedback_service.dart';
import 'printer_config_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final SettingsProvider provider = context.read<SettingsProvider>();
    // Trigger load to ensure we have latest
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await provider.loadSettings();
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _exportData() async {
    try {
      AppSnackBar.showWarning(
          context, 'Exporting data... This may take a moment.');

      final bookProvider = context.read<BookProvider>();
      final salesProvider = context.read<SalesProvider>();
      final customerProvider = context.read<CustomerProvider>();
      final purchaseProvider = context.read<PurchaseProvider>();
      final distributorProvider = context.read<DistributorProvider>();

      // Ensure data is loaded
      if (bookProvider.books.isEmpty) await bookProvider.loadBooks();
      if (salesProvider.sales.isEmpty) await salesProvider.loadSales();
      if (customerProvider.customers.isEmpty)
        await customerProvider.loadCustomers();
      if (purchaseProvider.purchases.isEmpty)
        await purchaseProvider.loadPurchases();
      if (distributorProvider.distributors.isEmpty)
        await distributorProvider.loadDistributors();

      // Load Returns
      final salesReturns = await salesProvider.getSalesReturns();
      final purchaseReturns = await purchaseProvider.getPurchaseReturns();

      // Load Items
      final Map<int, List<SaleItem>> saleItems = {};
      for (var sale in salesProvider.sales) {
        if (sale.id != null) {
          saleItems[sale.id!] = await salesProvider.getItemsForSale(sale.id!);
        }
      }

      final Map<int, List<SalesReturnItem>> salesReturnItems = {};
      for (var ret in salesReturns) {
        if (ret.id != null) {
          salesReturnItems[ret.id!] =
              await salesProvider.getReturnItems(ret.id!);
        }
      }

      final Map<int, List<PurchaseItem>> purchaseItems = {};
      for (var purchase in purchaseProvider.purchases) {
        if (purchase.id != null) {
          purchaseItems[purchase.id!] =
              await purchaseProvider.getPurchaseItems(purchase.id!);
        }
      }

      final Map<int, List<PurchaseReturnItem>> purchaseReturnItems = {};
      for (var ret in purchaseReturns) {
        if (ret.id != null) {
          purchaseReturnItems[ret.id!] =
              await purchaseProvider.getReturnItems(ret.id!);
        }
      }

      // Load Payments
      final customerPayments = await customerProvider.getAllPayments();
      final distributorPayments = await distributorProvider.getAllPayments();

      await ExcelService().exportData(
        books: bookProvider.books,
        sales: salesProvider.sales,
        salesReturns: salesReturns,
        purchases: purchaseProvider.purchases,
        purchaseReturns: purchaseReturns,
        customers: customerProvider.customers,
        distributors: distributorProvider.distributors,
        saleItems: saleItems,
        salesReturnItems: salesReturnItems,
        purchaseItems: purchaseItems,
        purchaseReturnItems: purchaseReturnItems,
        customerPayments: customerPayments,
        distributorPayments: distributorPayments,
      );

      if (mounted) {
        AppSnackBar.showSuccess(context, 'Data exported successfully');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Export failed: $e');
      }
    }
  }

  Future<void> _backupData() async {
    try {
      AppSnackBar.showWarning(context, 'Creating backup...');

      final path = await BackupService().createBackup();

      // Share the backup file
      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(path)], text: 'Book Shop Backup');

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Backup failed: $e');
      }
    }
  }

  Future<void> _restoreData() async {
    try {
      // Ask user for confirmation
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore Backup'),
          content: const Text(
              'This will DELETE all current data and replace it with the backup. Are you sure?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.errorText),
              child: const Text('Restore'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      if (!mounted) return;

      // Show Progress Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Restoring data...'),
              ],
            ),
          ),
        ),
      );

      try {
        await BackupService().restoreBackup();

        if (mounted) {
          Navigator.of(context).pop(); // Dismiss progress dialog
          AppSnackBar.showSuccess(context, 'Restore successful! Restarting...');
          // Delay slightly to let the snackbar show
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            Phoenix.rebirth(context);
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Dismiss progress dialog
          rethrow; // Let outer catch handle it
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showWarning(context, 'Restore failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDemo = context.watch<AuthProvider>().isDemo;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      drawer: const AppDrawer(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Shop Details Navigation
            ListTile(
              leading: const Icon(Icons.store, color: AppTheme.accent500),
              title: const Text('Shop Details'),
              subtitle: const Text('Name, Address, Email, API Keys'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ShopDetailsScreen(),
                  ),
                );
              },
            ),

            Text('AI Integration',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),

            // AI Model Selector
            Consumer<SettingsProvider>(
              builder: (context, provider, _) {
                return ListTile(
                  leading:
                      const Icon(Icons.psychology, color: AppTheme.accent500),
                  title: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'AI Model',
                      border: OutlineInputBorder(),
                    ),
                    value: provider.aiModel,
                    items: const [
                      DropdownMenuItem(
                        value: 'gemini-2.5-flash',
                        child: Text('Gemini 2.5 Flash'),
                      ),
                      DropdownMenuItem(
                        value: 'gemini-2.5-flash-lite',
                        child: Text('Gemini 2.5 Flash-Lite'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        provider.setAiModel(val);
                      }
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text('Scanner Settings',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            // Feedback Settings
            Consumer<SettingsProvider>(
              builder: (context, provider, _) {
                return ListTile(
                  leading:
                      const Icon(Icons.feedback, color: AppTheme.accent500),
                  title: DropdownButtonFormField<FeedbackType>(
                    decoration: const InputDecoration(
                      labelText: 'Feedback Type',
                      border: OutlineInputBorder(),
                    ),
                    value: provider.feedbackType,
                    items: const [
                      DropdownMenuItem(
                        value: FeedbackType.vibrate,
                        child: Text('Vibrate'),
                      ),
                      DropdownMenuItem(
                        value: FeedbackType.beep,
                        child: Text('Beep'),
                      ),
                      DropdownMenuItem(
                        value: FeedbackType.none,
                        child: Text('None'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        provider.setFeedbackType(val);
                      }
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text('Printer Settings',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.print, color: AppTheme.accent500),
              title: const Text('Printer Configuration'),
              subtitle: const Text('Setup Bluetooth or Network Printer'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrinterConfigScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            // Print Method Selector
            Consumer<PrinterProvider>(
              builder: (context, provider, _) {
                return ListTile(
                  leading: const Icon(Icons.print_disabled, color: Colors.grey),
                  title: DropdownButtonFormField<PrintMethod>(
                    decoration: const InputDecoration(
                      labelText: 'Print Method',
                      border: OutlineInputBorder(),
                    ),
                    value: provider.printMethod,
                    items: const [
                      DropdownMenuItem(
                        value: PrintMethod.pdf,
                        child: Text('Save as PDF (System Default)'),
                      ),
                      DropdownMenuItem(
                        value: PrintMethod.thermal,
                        child: Text('Thermal Printer'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        provider.setPrintMethod(val);
                      }
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text('Import Data', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.restore,
                  color: isDemo ? Colors.grey : AppTheme.warningText),
              title: const Text('Restore Data'),
              subtitle: const Text('Restore from backup file'),
              onTap: isDemo
                  ? () => AppSnackBar.showError(
                      context, 'Restore is disabled in Demo Mode')
                  : _restoreData,
              enabled: !isDemo,
            ),
            ListTile(
              leading: Icon(Icons.file_upload,
                  color: isDemo ? Colors.grey : AppTheme.accent500),
              title: const Text('Import Books from Excel'),
              subtitle: const Text('Map columns and import'),
              onTap: isDemo
                  ? () => AppSnackBar.showError(
                      context, 'Import is disabled in Demo Mode')
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ExcelImportScreen(),
                        ),
                      );
                    },
              // 1. Disable the tile when in Demo Mode
              enabled: !isDemo,
            ),
            const SizedBox(height: 32),
            Text('Export Data', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ListTile(
              leading:
                  const Icon(Icons.table_chart, color: AppTheme.successText),
              title: const Text('Export Data to Excel'),
              subtitle: const Text('Books, Sales, and Customers'),
              onTap: _exportData,
            ),
            ListTile(
              leading: Icon(Icons.backup,
                  color: isDemo ? Colors.grey : AppTheme.accent500),
              title: const Text('Backup Data'),
              subtitle: const Text('Save database and images'),
              onTap: isDemo
                  ? () => AppSnackBar.showError(
                      context, 'Backup is disabled in Demo Mode')
                  : _backupData,
              enabled: !isDemo,
            ),
            const SizedBox(height: 16),
            // --- Logout Button Added Here ---
            ElevatedButton(
              onPressed: () async {
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );

                if (shouldLogout == true && context.mounted) {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                }
              },
              child: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorText,
                foregroundColor: AppTheme.neutral50,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
