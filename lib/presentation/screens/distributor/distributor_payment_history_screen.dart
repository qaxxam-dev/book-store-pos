import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payments - ${widget.distributor.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddDistributorPaymentScreen(
                      distributor: widget.distributor),
                ),
              );
              if (result == true) {
                _loadPayments();
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<DistributorPayment>>(
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
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final payment = payments[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.accent700.withOpacity(0.1),
                    child: const Icon(Icons.payment, color: AppTheme.accent700),
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
                          '${payment.paymentMode} • ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(payment.paymentDate))}'),
                      if (payment.notes != null && payment.notes!.isNotEmpty)
                        Text('Note: ${payment.notes}'),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
