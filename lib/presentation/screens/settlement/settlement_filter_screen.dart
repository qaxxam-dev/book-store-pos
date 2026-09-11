import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/distributor.dart';
import '../../providers/customer_provider.dart';
import '../../providers/distributor_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../../core/services/settlement_service.dart';
import 'settlement_report_screen.dart';

class SettlementFilterScreen extends StatefulWidget {
  const SettlementFilterScreen({super.key});

  @override
  State<SettlementFilterScreen> createState() => _SettlementFilterScreenState();
}

class _SettlementFilterScreenState extends State<SettlementFilterScreen> {
  final SettlementService _settlementService = SettlementService();

  bool _isSale = true;
  Customer? _selectedCustomer;
  Distributor? _selectedDistributor;
  late DateTime _startDate;
  late DateTime _endDate;

  bool _isLoadingPreview = false;
  bool _isGenerating = false;
  int _previewBillsCount = 0;
  int _previewReturnsCount = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Default to last 7 days up to today
    _startDate = now.subtract(const Duration(days: 7));
    _endDate = now;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().loadCustomers();
      context.read<DistributorProvider>().loadDistributors();
    });
  }

  Future<void> _updatePreview() async {
    final partyId = _isSale ? _selectedCustomer?.id : _selectedDistributor?.id;
    if (partyId == null) {
      setState(() {
        _previewBillsCount = 0;
        _previewReturnsCount = 0;
      });
      return;
    }

    setState(() => _isLoadingPreview = true);
    try {
      final report = await _settlementService.generateSettlementReport(
        isSale: _isSale,
        partyId: partyId,
        partyName: _isSale
            ? (_selectedCustomer?.name ?? '')
            : (_selectedDistributor?.name ?? ''),
        partyPhone: _isSale
            ? (_selectedCustomer?.phone ?? '')
            : (_selectedDistributor?.phone ?? ''),
        startDate: _startDate,
        endDate: _endDate,
      );

      if (mounted) {
        setState(() {
          _previewBillsCount = report.creditBills.length;
          _previewReturnsCount = report.returnBills.length;
        });
      }
    } catch (_) {
      // Ignored for preview
    } finally {
      if (mounted) setState(() => _isLoadingPreview = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.accent500,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _updatePreview();
    }
  }

  Future<void> _handleGenerateReport() async {
    final partyId = _isSale ? _selectedCustomer?.id : _selectedDistributor?.id;
    final partyName = _isSale
        ? (_selectedCustomer?.name ?? '')
        : (_selectedDistributor?.name ?? '');
    final partyPhone = _isSale
        ? (_selectedCustomer?.phone ?? '')
        : (_selectedDistributor?.phone ?? '');

    if (partyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a ${_isSale ? 'Customer' : 'Distributor'} first',
          ),
          backgroundColor: AppTheme.warningText,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final report = await _settlementService.generateSettlementReport(
        isSale: _isSale,
        partyId: partyId,
        partyName: partyName,
        partyPhone: partyPhone,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SettlementReportScreen(report: report),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: AppTheme.errorText,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = context.watch<CustomerProvider>();
    final distributorProvider = context.watch<DistributorProvider>();
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: AppTheme.neutral50,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text(
          'Sale or Return Settlement',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info Header Banner
            Card(
              elevation: 0,
              color: AppTheme.accent50.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: AppTheme.accent500.withValues(alpha: 0.3)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(14.0),
                child: Row(
                  children: [
                    Icon(Icons.storefront, color: AppTheme.accent500, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Exhibition Settlement',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accent500,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Consolidate credit stall bills and returns into a single A4 settlement bill.',
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Toggle Sales vs Purchase
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1. Select Transaction Type',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('Sales (Customer)'),
                          icon: Icon(Icons.person),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Purchase (Distributor)'),
                          icon: Icon(Icons.local_shipping),
                        ),
                      ],
                      selected: {_isSale},
                      onSelectionChanged: (Set<bool> newSelection) {
                        setState(() {
                          _isSale = newSelection.first;
                          _selectedCustomer = null;
                          _selectedDistributor = null;
                          _previewBillsCount = 0;
                          _previewReturnsCount = 0;
                        });
                      },
                      style: ButtonStyle(
                        backgroundColor:
                            WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.selected)) {
                            return _isSale
                                ? AppTheme.accent500
                                : Colors.teal.shade700;
                          }
                          return Colors.transparent;
                        }),
                        foregroundColor:
                            WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.selected)) {
                            return Colors.white;
                          }
                          return Colors.black87;
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Select Party (Customer or Distributor)
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2. Select ${_isSale ? 'Customer / Stall Keeper' : 'Distributor'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isSale)
                      DropdownButtonFormField<Customer>(
                        value: _selectedCustomer,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: 'Choose Customer',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        items: customerProvider.customers.map((c) {
                          return DropdownMenuItem<Customer>(
                            value: c,
                            child: Text('${c.name} (${c.phone})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedCustomer = val);
                          _updatePreview();
                        },
                      )
                    else
                      DropdownButtonFormField<Distributor>(
                        value: _selectedDistributor,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: 'Choose Distributor',
                          prefixIcon: const Icon(Icons.local_shipping_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        items: distributorProvider.distributors.map((d) {
                          return DropdownMenuItem<Distributor>(
                            value: d,
                            child: Text('${d.name} (${d.phone})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedDistributor = val);
                          _updatePreview();
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Date Range Selection
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '3. Exhibition Date Range',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _selectDateRange,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.date_range,
                                    color: AppTheme.accent500),
                                const SizedBox(width: 10),
                                Text(
                                  '${dateFormat.format(_startDate)}  →  ${dateFormat.format(_endDate)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(Icons.edit_calendar,
                                size: 20, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Matching Preview Status
            if ((_isSale && _selectedCustomer != null) ||
                (!_isSale && _selectedDistributor != null))
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _isLoadingPreview
                      ? const Center(
                          child: SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  '$_previewBillsCount',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accent500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Credit Bills',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              height: 36,
                              width: 1,
                              color: Colors.grey.shade300,
                            ),
                            Column(
                              children: [
                                Text(
                                  '$_previewReturnsCount',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Returns Found',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            const SizedBox(height: 24),

            // Submit / Generate Button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _handleGenerateReport,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.assessment, color: Colors.white),
                label: Text(
                  _isGenerating
                      ? 'Generating Settlement...'
                      : 'Generate Settlement Report',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent500,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
