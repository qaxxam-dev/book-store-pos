import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../data/models/distributor.dart';
import '../../../data/models/distributor_payment.dart';
import '../../providers/distributor_provider.dart';
import 'add_distributor_payment_screen.dart';

class DistributorPaymentHistoryScreen extends StatefulWidget {
  final Distributor distributor;

  const DistributorPaymentHistoryScreen({super.key, required this.distributor});

  @override
  State<DistributorPaymentHistoryScreen> createState() =>
      _DistributorPaymentHistoryScreenState();
}

class _DistributorPaymentHistoryScreenState
    extends State<DistributorPaymentHistoryScreen> {
  late Future<List<DistributorPayment>> _paymentsFuture;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  void _loadPayments() {
    setState(() {
      _paymentsFuture = context
          .read<DistributorProvider>()
          .getPayments(widget.distributor.id!);
    });
  }

  Future<void> _editPayment(
      Distributor currentDistributor, DistributorPayment payment) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddDistributorPaymentScreen(
          distributor: currentDistributor,
          payment: payment,
        ),
      ),
    );
    if (result == true && mounted) {
      _loadPayments();
    }
  }

  Future<void> _confirmDeletePayment(
      Distributor currentDistributor, DistributorPayment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment'),
        content: Text(
          'Are you sure you want to delete this payment of ₹${payment.amount.toStringAsFixed(2)}?\n\n'
          'This will add ₹${payment.amount.toStringAsFixed(2)} back to what you owe ${currentDistributor.name}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorText,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<DistributorProvider>().deletePayment(payment);
        if (mounted) {
          AppSnackBar.showSuccess(context, 'Payment deleted successfully');
          _loadPayments();
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.showError(context, 'Error deleting payment: $e');
        }
      }
    }
  }

  void _showActionBottomSheet(
      Distributor currentDistributor, DistributorPayment payment) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          AppTheme.accent700.withValues(alpha: 0.1),
                      child:
                          const Icon(Icons.payment, color: AppTheme.accent700),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹${payment.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${payment.paymentMode} • ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(payment.paymentDate))}',
                            style: const TextStyle(
                              color: AppTheme.neutral600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),
              ListTile(
                leading: const Icon(Icons.edit, color: AppTheme.accent700),
                title: const Text('Edit Payment'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _editPayment(currentDistributor, payment);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppTheme.errorText),
                title: const Text(
                  'Delete Payment',
                  style: TextStyle(color: AppTheme.errorText),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _confirmDeletePayment(currentDistributor, payment);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentDistributor = context.select<DistributorProvider, Distributor>(
      (provider) => provider.distributors.firstWhere(
        (d) => d.id == widget.distributor.id,
        orElse: () => widget.distributor,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Payments - ${currentDistributor.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Payment',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddDistributorPaymentScreen(
                      distributor: currentDistributor),
                ),
              );
              if (result == true) {
                _loadPayments();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet,
                      color: AppTheme.accent700, size: 28),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Outstanding Balance',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${currentDistributor.balance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accent700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<DistributorPayment>>(
              future: _paymentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final payments = snapshot.data ?? [];

                if (payments.isEmpty) {
                  return const Center(child: Text('No payment history found'));
                }

                return ListView.builder(
                  itemCount: payments.length,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemBuilder: (context, index) {
                    final payment = payments[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        onTap: () => _showActionBottomSheet(
                            currentDistributor, payment),
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.accent700.withValues(alpha: 0.1),
                          child: const Icon(Icons.payment,
                              color: AppTheme.accent700),
                        ),
                        title: Text(
                          '₹${payment.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${payment.paymentMode} • ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(payment.paymentDate))}',
                            ),
                            if (payment.notes != null &&
                                payment.notes!.isNotEmpty)
                              Text('Note: ${payment.notes}'),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editPayment(currentDistributor, payment);
                            } else if (value == 'delete') {
                              _confirmDeletePayment(
                                  currentDistributor, payment);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit,
                                      size: 20, color: AppTheme.accent700),
                                  SizedBox(width: 12),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline,
                                      size: 20, color: AppTheme.errorText),
                                  SizedBox(width: 12),
                                  Text('Delete',
                                      style: TextStyle(
                                          color: AppTheme.errorText)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
