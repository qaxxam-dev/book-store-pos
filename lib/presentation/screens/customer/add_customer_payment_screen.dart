import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/customer_payment.dart';
import '../../providers/customer_provider.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../providers/auth_provider.dart';
import '../../../core/utils/dialog_utils.dart';

class AddCustomerPaymentScreen extends StatefulWidget {
  final Customer customer;
  final CustomerPayment? payment;

  const AddCustomerPaymentScreen({
    super.key,
    required this.customer,
    this.payment,
  });

  @override
  State<AddCustomerPaymentScreen> createState() =>
      _AddCustomerPaymentScreenState();
}

class _AddCustomerPaymentScreenState extends State<AddCustomerPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  late String _paymentMode;
  late DateTime _selectedDate;
  bool _isProcessing = false;

  bool get isEditing => widget.payment != null;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.payment != null ? widget.payment!.amount.toStringAsFixed(2) : '',
    );
    _notesController = TextEditingController(
      text: widget.payment?.notes ?? '',
    );
    _paymentMode = widget.payment?.paymentMode ?? 'Cash';
    if (!['Cash', 'Card', 'UPI', 'Bank Transfer'].contains(_paymentMode)) {
      _paymentMode = 'Cash';
    }
    _selectedDate = widget.payment != null
        ? DateTime.tryParse(widget.payment!.paymentDate) ?? DateTime.now()
        : DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final amount = double.parse(_amountController.text.trim());

      if (isEditing) {
        final updatedPayment = CustomerPayment(
          id: widget.payment!.id,
          customerId: widget.payment!.customerId,
          amount: amount,
          paymentDate: _selectedDate.toIso8601String(),
          paymentMode: _paymentMode,
          notes: _notesController.text.trim(),
        );

        await context.read<CustomerProvider>().updatePayment(
              updatedPayment,
              widget.payment!.amount,
            );

        if (mounted) {
          Navigator.pop(context, true);
          AppSnackBar.showSuccess(context, 'Payment updated successfully');
        }
      } else {
        final payment = CustomerPayment(
          customerId: widget.customer.id!,
          amount: amount,
          paymentDate: _selectedDate.toIso8601String(),
          paymentMode: _paymentMode,
          notes: _notesController.text.trim(),
        );

        await context
            .read<CustomerProvider>()
            .addPayment(payment, isDemo: authProvider.isDemo);

        if (mounted) {
          Navigator.pop(context, true);
          AppSnackBar.showSuccess(context, 'Payment recorded successfully');
        }
      }
    } catch (e) {
      if (mounted) {
        if (e is Map && e['type'] == 'purchase_required') {
          DialogUtils.showPurchaseDialog(e['message'], e['url'], context);
        } else {
          AppSnackBar.showError(context, 'Error: $e');
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing
            ? 'Edit Payment - ${widget.customer.name}'
            : 'Add Payment - ${widget.customer.name}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet,
                          color: AppTheme.accent700),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Current Balance',
                              style: TextStyle(color: Colors.grey)),
                          Text(
                            '₹${widget.customer.balance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
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
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter amount';
                  }
                  final parsed = double.tryParse(value.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Please enter a valid amount greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _paymentMode,
                decoration: const InputDecoration(
                  labelText: 'Payment Mode',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payment),
                ),
                items: ['Cash', 'Card', 'UPI', 'Bank Transfer']
                    .map((mode) => DropdownMenuItem(
                          value: mode,
                          child: Text(mode),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _paymentMode = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 20, color: AppTheme.accent700),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('dd MMM yyyy, hh:mm a')
                                .format(_selectedDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _savePayment,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.accent700,
                  ),
                  child: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isEditing ? 'UPDATE PAYMENT' : 'SAVE PAYMENT',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
