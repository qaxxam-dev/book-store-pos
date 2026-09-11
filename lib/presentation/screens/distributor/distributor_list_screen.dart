import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../providers/distributor_provider.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../data/models/distributor.dart';
import 'add_edit_distributor_screen.dart';
import 'distributor_payment_history_screen.dart';
import 'add_distributor_payment_screen.dart';
import '../../widgets/app_drawer.dart';

class DistributorListScreen extends StatefulWidget {
  const DistributorListScreen({super.key});

  @override
  State<DistributorListScreen> createState() => _DistributorListScreenState();
}

class _DistributorListScreenState extends State<DistributorListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<DistributorProvider>().loadDistributors());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DistributorProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Distributors'),
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditDistributorScreen()),
          );
        },
        backgroundColor: AppTheme.accent500,
        foregroundColor: AppTheme.neutral50,
        child: const Icon(Icons.add),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.distributors.isEmpty
              ? const Center(child: Text('No distributors found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.distributors.length,
                  itemBuilder: (context, index) {
                    final distributor = provider.distributors[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        onTap: () => _showDistributorActionsBottomSheet(
                            context, distributor),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.accent100,
                          child: Text(
                            distributor.name[0].toUpperCase(),
                            style: const TextStyle(color: AppTheme.accent700),
                          ),
                        ),
                        title: Text(distributor.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(distributor.phone),
                            Text(
                              'Balance: ₹${distributor.balance.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: distributor.balance > 0
                                    ? AppTheme.errorText
                                    : AppTheme.successText,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () => _showDistributorActionsBottomSheet(
                              context, distributor),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showDistributorActionsBottomSheet(
      BuildContext context, Distributor distributor) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Distributor info header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppTheme.accent100,
                      child: Text(
                        distributor.name.isNotEmpty
                            ? distributor.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppTheme.accent700,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            distributor.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            distributor.phone,
                            style: const TextStyle(
                              color: AppTheme.neutral600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${distributor.balance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: distributor.balance > 0
                            ? AppTheme.errorText
                            : AppTheme.successText,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),
              // Action items
              ListTile(
                leading: const Icon(Icons.history, color: AppTheme.accent700),
                title: const Text('Payment History'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _openPaymentHistory(distributor);
                },
              ),
              ListTile(
                leading: const Icon(Icons.payment, color: AppTheme.successText),
                title: const Text('Add Payment'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _openAddPayment(distributor);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: AppTheme.neutral600),
                title: const Text('Edit Distributor'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _openEdit(distributor);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppTheme.errorText),
                title: const Text(
                  'Delete Distributor',
                  style: TextStyle(color: AppTheme.errorText),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _confirmDelete(distributor);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _openPaymentHistory(Distributor distributor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DistributorPaymentHistoryScreen(distributor: distributor),
      ),
    );
  }

  void _openAddPayment(Distributor distributor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddDistributorPaymentScreen(distributor: distributor),
      ),
    ).then((value) {
      if (value == true && mounted) {
        context.read<DistributorProvider>().loadDistributors();
      }
    });
  }

  void _openEdit(Distributor distributor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditDistributorScreen(distributor: distributor),
      ),
    ).then((value) {
      if (value == true && mounted) {
        context.read<DistributorProvider>().loadDistributors();
      }
    });
  }

  Future<void> _confirmDelete(Distributor distributor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Distributor?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppTheme.errorText))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await context
            .read<DistributorProvider>()
            .deleteDistributor(distributor.id!);
        if (mounted) {
          AppSnackBar.showSuccess(
              context, 'Distributor deleted successfully');
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.showError(
              context, 'Error deleting distributor: $e');
        }
      }
    }
  }
}
