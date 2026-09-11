import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:book_store_pos/core/theme.dart';
import 'package:book_store_pos/data/models/sales_return.dart';
import 'package:book_store_pos/presentation/providers/sales_provider.dart';
import 'package:book_store_pos/presentation/providers/customer_provider.dart';
import 'package:book_store_pos/data/models/customer.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../../widgets/app_drawer.dart';
import 'sales_return_entry_screen.dart';
import 'sales_return_details_screen.dart';
import '../../../core/utils/snackbar_utils.dart';

class SalesReturnListScreen extends StatefulWidget {
  const SalesReturnListScreen({super.key});

  @override
  State<SalesReturnListScreen> createState() => _SalesReturnListScreenState();
}

class _SalesReturnListScreenState extends State<SalesReturnListScreen> {
  List<SalesReturn> _filteredReturns = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await context.read<CustomerProvider>().loadCustomers();
    await _applyFilter();
  }

  Future<void> _applyFilter({
    int? customerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    setState(() => _isLoading = true);
    try {
      final returns = await context.read<SalesProvider>().filterSalesReturns(
            customerId: customerId,
            startDate: startDate,
            endDate: endDate,
          );
      if (mounted) {
        setState(() {
          _filteredReturns = returns;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackBar.showError(context, 'Error loading returns: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Returns'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredReturns.isEmpty
              ? const Center(child: Text('No sales returns found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredReturns.length,
                  itemBuilder: (context, index) {
                    final returnRecord = _filteredReturns[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppTheme.warningText,
                          child: Icon(Icons.assignment_return,
                              color: Colors.white),
                        ),
                        title: Text(returnRecord.billNumber,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Date: ${returnRecord.timestamp.split('T')[0]}'),
                            // We can't easily get customer name here without joining or extra queries,
                            // but we can show the total refund amount.
                            Text(
                              'Total Refund: ₹${returnRecord.totalRefund.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: AppTheme.warningText,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SalesReturnDetailsScreen(
                                returnRecord: returnRecord,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const SalesReturnEntryScreen()),
          );
          _applyFilter();
        },
        backgroundColor: AppTheme.accent500,
        foregroundColor: AppTheme.neutral50,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        onApply: (customerId, startDate, endDate) {
          _applyFilter(
            customerId: customerId,
            startDate: startDate,
            endDate: endDate,
          );
        },
      ),
    );
  }
}

class _FilterDialog extends StatefulWidget {
  final Function(int?, DateTime?, DateTime?) onApply;

  const _FilterDialog({required this.onApply});

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  int? _selectedCustomerId;
  final TextEditingController _customerController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _customerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = context.watch<CustomerProvider>();

    return AlertDialog(
      title: const Text('Filter Sales Returns'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TypeAheadField<Customer>(
              controller: _customerController,
              builder: (context, controller, focusNode) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Customer',
                    border: const OutlineInputBorder(),
                    suffixIcon: _selectedCustomerId != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _selectedCustomerId = null;
                                _customerController.clear();
                              });
                            },
                          )
                        : const Icon(Icons.search),
                  ),
                );
              },
              suggestionsCallback: (pattern) {
                return customerProvider.customers
                    .where((c) =>
                        c.name.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, customer) {
                return ListTile(
                  title: Text(customer.name),
                  subtitle: Text(customer.phone),
                );
              },
              onSelected: (customer) {
                setState(() {
                  _selectedCustomerId = customer.id;
                  _customerController.text = customer.name;
                });
              },
              emptyBuilder: (context) => const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('No customer found'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) setState(() => _startDate = date);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accent700,
                    ),
                    child: Text(_startDate == null
                        ? 'Start Date'
                        : DateFormat('MMM dd').format(_startDate!)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) setState(() => _endDate = date);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accent700,
                    ),
                    child: Text(_endDate == null
                        ? 'End Date'
                        : DateFormat('MMM dd').format(_endDate!)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onApply(null, null, null);
            Navigator.pop(context);
          },
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.accent700,
          ),
          child: const Text('Clear'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(_selectedCustomerId, _startDate, _endDate);
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
