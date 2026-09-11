import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:book_store_pos/core/theme.dart';
import 'package:book_store_pos/data/models/purchase_return.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:book_store_pos/data/models/distributor.dart';
import '../../screens/purchase_return/purchase_return_entry_screen.dart';
import 'package:book_store_pos/presentation/providers/purchase_provider.dart';
import 'package:book_store_pos/presentation/providers/distributor_provider.dart';
import '../../widgets/app_drawer.dart';
import 'purchase_return_details_screen.dart';

class PurchaseReturnListScreen extends StatefulWidget {
  const PurchaseReturnListScreen({super.key});

  @override
  State<PurchaseReturnListScreen> createState() =>
      _PurchaseReturnListScreenState();
}

class _PurchaseReturnListScreenState extends State<PurchaseReturnListScreen> {
  List<Map<String, dynamic>> _returnList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData({
    int? distributorId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    setState(() => _isLoading = true);
    final purchaseProvider = context.read<PurchaseProvider>();
    final distributorProvider = context.read<DistributorProvider>();

    // Load dependencies first
    await Future.wait([
      purchaseProvider.loadPurchases(),
      distributorProvider.loadDistributors(),
    ]);

    final returns = await purchaseProvider.filterPurchaseReturns(
      distributorId: distributorId,
      startDate: startDate,
      endDate: endDate,
    );

    final List<Map<String, dynamic>> tempList = [];

    for (var ret in returns) {
      // Get Distributor Name
      String distributorName = 'Unknown';
      try {
        final purchase = purchaseProvider.purchases
            .firstWhere((p) => p.id == ret.purchaseId);
        final distributor = distributorProvider.distributors
            .firstWhere((d) => d.id == purchase.distributorId);
        distributorName = distributor.name;
      } catch (_) {}

      // Get Total Return Quantity
      int totalQty = 0;
      final items = await purchaseProvider.getReturnItems(ret.id!);
      for (var item in items) {
        totalQty += item.quantity;
      }

      tempList.add({
        'return': ret,
        'distributor': distributorName,
        'totalQty': totalQty,
      });
    }

    if (mounted) {
      setState(() {
        _returnList = tempList;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Return History'),
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
          : _returnList.isEmpty
              ? const Center(child: Text('No purchase returns found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _returnList.length,
                  itemBuilder: (context, index) {
                    final data = _returnList[index];
                    final PurchaseReturn returnRecord = data['return'];
                    final String distributorName = data['distributor'];
                    final int totalQty = data['totalQty'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.warningText.withValues(alpha: 0.1),
                          child: const Icon(Icons.assignment_return,
                              color: AppTheme.warningText),
                        ),
                        title: Text(distributorName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Bill: ${returnRecord.billNumber}'),
                            Text(
                              DateFormat('MMM dd, yyyy').format(
                                  DateTime.parse(returnRecord.timestamp)),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Return Qty',
                                style: TextStyle(fontSize: 12)),
                            Text(
                              '$totalQty',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppTheme.warningText),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PurchaseReturnDetailsScreen(
                                  returnRecord: returnRecord),
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
                builder: (context) => const PurchaseReturnEntryScreen()),
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
          _loadData(
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
      title: const Text('Filter Returns'),
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
