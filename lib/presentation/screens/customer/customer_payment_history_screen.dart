import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/customer_payment.dart';
import '../../providers/customer_provider.dart';
import 'add_customer_payment_screen.dart';

class CustomerPaymentHistoryScreen extends StatefulWidget {
  final Customer customer;

  const CustomerPaymentHistoryScreen({super.key, required this.customer});

  @override
  State<CustomerPaymentHistoryScreen> createState() =>
      _CustomerPaymentHistoryScreenState();
}

class _CustomerPaymentHistoryScreenState
    extends State<CustomerPaymentHistoryScreen> {
  late Future<List<CustomerPayment>> _paymentsFuture;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  void _loadPayments() {
    setState(() {
      _paymentsFuture =
          context.read<CustomerProvider>().getPayments(widget.customer.id!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payments - ${widget.customer.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AddCustomerPaymentScreen(customer: widget.customer),
                ),
              );
              if (result == true) {
                _loadPayments();
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<CustomerPayment>>(
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
