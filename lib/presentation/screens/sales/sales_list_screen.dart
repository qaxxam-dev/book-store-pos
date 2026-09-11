import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../providers/sales_provider.dart';
import '../../providers/customer_provider.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/sale.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'sale_details_screen.dart';
import '../../widgets/app_drawer.dart';

class SalesListScreen extends StatefulWidget {
  const SalesListScreen({super.key});

  @override
  State<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  List<Sale> _filteredSales = [];
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
    List<String>? paymentMethods,
  }) async {
    setState(() => _isLoading = true);
    final sales = await context.read<SalesProvider>().filterSales(
          customerId: customerId,
          startDate: startDate,
          endDate: endDate,
          paymentMethods: paymentMethods,
        );
    if (mounted) {
      setState(() {
        _filteredSales = sales;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
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
          : _filteredSales.isEmpty
              ? const Center(child: Text('No sales recorded yet'))
              : ListView.builder(
                  itemCount: _filteredSales.length,
                  itemBuilder: (context, index) {
                    final sale = _filteredSales[index];
                    final date = DateTime.parse(sale.timestamp);
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.accent100,
                          child: const Icon(Icons.receipt,
                              color: AppTheme.accent700),
                        ),
                        title: Text(
                          'Bill #${sale.billNumber}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('MMM dd, yyyy hh:mm a').format(date),
                            ),
                            if (sale.paymentMethod == 'Complementary' &&
                                sale.customerName != null &&
                                sale.customerName!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Given to: ${sale.customerName}',
                                  style: const TextStyle(
                                    color: AppTheme.accent700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${sale.totalAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: sale.paymentMethod == 'Complementary'
                                    ? AppTheme.accent700
                                    : AppTheme.successText,
                              ),
                            ),
                            Text(
                              sale.paymentMethod,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontWeight:
                                        sale.paymentMethod == 'Complementary'
                                            ? FontWeight.bold
                                            : null,
                                    color: sale.paymentMethod == 'Complementary'
                                        ? AppTheme.accent700
                                        : null,
                                  ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SaleDetailsScreen(sale: sale),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        onApply: (customerId, startDate, endDate, paymentMethods) {
          _applyFilter(
            customerId: customerId,
            startDate: startDate,
            endDate: endDate,
            paymentMethods: paymentMethods,
          );
        },
      ),
    );
  }
}

class _FilterDialog extends StatefulWidget {
  final Function(int?, DateTime?, DateTime?, List<String>?) onApply;

  const _FilterDialog({required this.onApply});

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  int? _selectedCustomerId;
  final TextEditingController _customerController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  final List<String> _selectedPaymentMethods = [];
  final List<String> _paymentMethods = [
    'Cash',
    'Card',
    'UPI',
    'Credit',
    'Complementary'
  ];

  @override
  void dispose() {
    _customerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = context.watch<CustomerProvider>();

    return AlertDialog(
      title: const Text('Filter Sales'),
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
                    child: Text(_endDate == null
                        ? 'End Date'
                        : DateFormat('MMM dd').format(_endDate!)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Payment Method:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _paymentMethods.map((method) {
                return FilterChip(
                  label: Text(method),
                  selected: _selectedPaymentMethods.contains(method),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedPaymentMethods.add(method);
                      } else {
                        _selectedPaymentMethods.remove(method);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onApply(null, null, null, null);
            Navigator.pop(context);
          },
          child: const Text('Clear'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(_selectedCustomerId, _startDate, _endDate,
                _selectedPaymentMethods);
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
