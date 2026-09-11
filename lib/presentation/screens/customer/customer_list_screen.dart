import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/customer_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../../core/theme.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../data/models/customer.dart';
import 'add_customer_screen.dart';
import 'customer_payment_history_screen.dart';
import 'add_customer_payment_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().loadCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
      ),
      drawer: const AppDrawer(),
      body: Consumer<CustomerProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.customers.isEmpty) {
            return const Center(child: Text('No customers found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: provider.customers.length,
            itemBuilder: (context, index) {
              final customer = provider.customers[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  onTap: () =>
                      _showCustomerActionsBottomSheet(context, customer),
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.accent100,
                    child: Text(
                      customer.name.isNotEmpty
                          ? customer.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: AppTheme.accent700),
                    ),
                  ),
                  title: Text(
                    customer.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer.phone),
                      Text(
                        'Balance: ₹${customer.balance.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: customer.balance > 0
                              ? AppTheme.successText
                              : AppTheme.neutral600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () =>
                        _showCustomerActionsBottomSheet(context, customer),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
          ).then((value) {
            if (value == true) {
              context.read<CustomerProvider>().loadCustomers();
            }
          });
        },
        backgroundColor: AppTheme.accent500,
        foregroundColor: AppTheme.neutral50,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCustomerActionsBottomSheet(
      BuildContext context, Customer customer) {
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
              // Customer info header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppTheme.accent100,
                      child: Text(
                        customer.name.isNotEmpty
                            ? customer.name[0].toUpperCase()
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
                            customer.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            customer.phone,
                            style: const TextStyle(
                              color: AppTheme.neutral600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${customer.balance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: customer.balance > 0
                            ? AppTheme.successText
                            : AppTheme.neutral600,
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
                  _openPaymentHistory(customer);
                },
              ),
              ListTile(
                leading: const Icon(Icons.payment, color: AppTheme.successText),
                title: const Text('Add Payment'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _openAddPayment(customer);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: AppTheme.neutral600),
                title: const Text('Edit Customer'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _openEdit(customer);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppTheme.errorText),
                title: const Text(
                  'Delete Customer',
                  style: TextStyle(color: AppTheme.errorText),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _confirmDelete(customer);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _openPaymentHistory(Customer customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerPaymentHistoryScreen(customer: customer),
      ),
    );
  }

  void _openAddPayment(Customer customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddCustomerPaymentScreen(customer: customer),
      ),
    ).then((value) {
      if (value == true && mounted) {
        context.read<CustomerProvider>().loadCustomers();
      }
    });
  }

  void _openEdit(Customer customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddCustomerScreen(customer: customer),
      ),
    ).then((value) {
      if (value == true && mounted) {
        context.read<CustomerProvider>().loadCustomers();
      }
    });
  }

  Future<void> _confirmDelete(Customer customer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete ${customer.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.errorText)),
          ),
        ],
      ),
    );

    if (confirm == true && customer.id != null && mounted) {
      try {
        await context.read<CustomerProvider>().deleteCustomer(customer.id!);
        if (mounted) {
          AppSnackBar.showSuccess(context, 'Customer deleted successfully');
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.showError(context, 'Error deleting customer: $e');
        }
      }
    }
  }
}
