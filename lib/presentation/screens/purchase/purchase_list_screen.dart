import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:book_store_pos/core/theme.dart';
import 'package:book_store_pos/data/models/distributor.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:book_store_pos/data/models/purchase.dart';
import 'package:book_store_pos/presentation/providers/purchase_provider.dart';
import 'package:book_store_pos/presentation/providers/distributor_provider.dart';
import 'package:book_store_pos/presentation/screens/purchase/purchase_details_screen.dart';
import '../../widgets/app_drawer.dart';
import '../purchase/purchase_entry_screen.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  List<Purchase> _filteredPurchases = [];
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
    await context.read<DistributorProvider>().loadDistributors();
    await _applyFilter();
  }

  Future<void> _applyFilter({
    int? distributorId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    setState(() => _isLoading = true);
    final purchases = await context.read<PurchaseProvider>().filterPurchases(
          distributorId: distributorId,
          startDate: startDate,
          endDate: endDate,
        );
    if (mounted) {
      setState(() {
        _filteredPurchases = purchases;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final distributorProvider = context.watch<DistributorProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase History'),
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
          : _filteredPurchases.isEmpty
              ? const Center(child: Text('No purchase history found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredPurchases.length,
                  itemBuilder: (context, index) {
                    final purchase = _filteredPurchases[index];
                    final distributor =
                        distributorProvider.distributors.firstWhere(
                      (d) => d.id == purchase.distributorId,
                      orElse: () =>
                          Distributor(name: 'Unknown', phone: '', balance: 0),
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.accent100,
                          child: const Icon(Icons.receipt,
                              color: AppTheme.accent700),
                        ),
                        title: Text(distributor.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${DateFormat('MMM dd, yyyy').format(DateTime.parse(purchase.timestamp))} • ${purchase.paymentMethod}',
                        ),
                        trailing: Text(
                          '₹${purchase.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PurchaseDetailsScreen(purchase: purchase),
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
                builder: (context) => const PurchaseEntryScreen()),
          );
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
        onApply: (distributorId, startDate, endDate) {
          _applyFilter(
            distributorId: distributorId,
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
  int? _selectedDistributorId;
  final TextEditingController _distributorController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _distributorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final distributorProvider = context.watch<DistributorProvider>();

    return AlertDialog(
      title: const Text('Filter Purchases'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TypeAheadField<Distributor>(
              controller: _distributorController,
              builder: (context, controller, focusNode) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Distributor',
                    border: const OutlineInputBorder(),
                    suffixIcon: _selectedDistributorId != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _selectedDistributorId = null;
                                _distributorController.clear();
                              });
                            },
                          )
                        : const Icon(Icons.search),
                  ),
                );
              },
              suggestionsCallback: (pattern) {
                return distributorProvider.distributors
                    .where((d) =>
                        d.name.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, distributor) {
                return ListTile(
                  title: Text(distributor.name),
                  subtitle: distributor.phone.isNotEmpty
                      ? Text(distributor.phone)
                      : null,
                );
              },
              onSelected: (distributor) {
                setState(() {
                  _selectedDistributorId = distributor.id;
                  _distributorController.text = distributor.name;
                });
              },
              emptyBuilder: (context) => const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('No distributor found'),
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onApply(null, null, null);
            Navigator.pop(context);
          },
          child: const Text('Clear'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(_selectedDistributorId, _startDate, _endDate);
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
