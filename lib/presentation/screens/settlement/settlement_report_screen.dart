import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../data/models/settlement_report_model.dart';
import '../../../core/services/settlement_service.dart';
import '../../providers/settings_provider.dart';

class SettlementReportScreen extends StatefulWidget {
  final SettlementReport report;

  const SettlementReportScreen({
    super.key,
    required this.report,
  });

  @override
  State<SettlementReportScreen> createState() => _SettlementReportScreenState();
}

class _SettlementReportScreenState extends State<SettlementReportScreen> {
  final SettlementService _settlementService = SettlementService();
  bool _isPrinting = false;
  bool _isSharing = false;

  Future<void> _handlePrintA4() async {
    setState(() => _isPrinting = true);
    try {
      final settings = context.read<SettingsProvider>().settings;
      await _settlementService.printSettlementA4(widget.report, settings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print error: $e'),
            backgroundColor: AppTheme.errorText,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _handleShareWhatsApp() async {
    setState(() => _isSharing = true);
    try {
      final settings = context.read<SettingsProvider>().settings;
      await _settlementService.shareSettlementWhatsApp(
        context: context,
        report: widget.report,
        settings: settings,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('WhatsApp share error: $e'),
            backgroundColor: AppTheme.errorText,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final totalPurchased =
        widget.report.items.fold<int>(0, (sum, i) => sum + i.purchasedQty);
    final totalReturned =
        widget.report.items.fold<int>(0, (sum, i) => sum + i.returnedQty);
    final totalNet =
        widget.report.items.fold<int>(0, (sum, i) => sum + i.netQty);

    return Scaffold(
      backgroundColor: AppTheme.neutral50,
      appBar: AppBar(
        title: Text(
          '${widget.report.isSale ? 'Sale' : 'Purchase'} Settlement',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Share on WhatsApp',
            icon: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.share, color: Colors.white),
            onPressed: _isSharing ? null : _handleShareWhatsApp,
          ),
          IconButton(
            tooltip: 'Print A4',
            icon: _isPrinting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.print, color: Colors.white),
            onPressed: _isPrinting ? null : _handlePrintA4,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header summary cards
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: widget.report.isSale
                              ? AppTheme.accent50
                              : Colors.teal.shade50,
                          child: Icon(
                            widget.report.isSale
                                ? Icons.person
                                : Icons.local_shipping,
                            color: widget.report.isSale
                                ? AppTheme.accent500
                                : Colors.teal.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.report.partyName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.report.partyPhone.isNotEmpty)
                                Text(
                                  widget.report.partyPhone,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.report.isSale
                                ? AppTheme.accent50
                                : Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: widget.report.isSale
                                  ? AppTheme.accent500
                                  : Colors.teal.shade700,
                            ),
                          ),
                          child: Text(
                            widget.report.isSale
                                ? 'Customer Sale'
                                : 'Distributor Purchase',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: widget.report.isSale
                                  ? AppTheme.accent500
                                  : Colors.teal.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.date_range,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              '${dateFormat.format(widget.report.startDate)} - ${dateFormat.format(widget.report.endDate)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${widget.report.creditBills.length} Bills | ${widget.report.returnBills.length} Returns',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Included Bills Accordion / Expandable
          if (widget.report.creditBills.isNotEmpty ||
              widget.report.returnBills.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: Colors.white,
                collapsedBackgroundColor: Colors.white,
                dense: true,
                title: Text(
                  'Included Transactions (${widget.report.creditBills.length + widget.report.returnBills.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      children: [
                        if (widget.report.creditBills.isNotEmpty) ...[
                          const Text(
                            'Credit Bills',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.blueGrey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...widget.report.creditBills.map((b) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${b.billNumber} (${b.itemCount} items)',
                                        style: const TextStyle(fontSize: 12)),
                                    Text('₹${b.amount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 8),
                        ],
                        if (widget.report.returnBills.isNotEmpty) ...[
                          const Text(
                            'Returns',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.deepOrange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...widget.report.returnBills.map((r) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${r.billNumber} (${r.itemCount} items)',
                                        style: const TextStyle(fontSize: 12)),
                                    Text('-₹${r.amount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red)),
                                  ],
                                ),
                              )),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),

          // Consolidated Items Table
          Expanded(
            child: widget.report.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No credit transactions found in this period.',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Card(
                          elevation: 1,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DataTable(
                            headingRowHeight: 42,
                            dataRowMinHeight: 38,
                            dataRowMaxHeight: 52,
                            horizontalMargin: 12,
                            columnSpacing: 16,
                            headingRowColor: WidgetStateProperty.all(
                              Colors.grey.shade100,
                            ),
                            columns: const [
                              DataColumn(label: Text('#')),
                              DataColumn(label: Text('Item')),
                              DataColumn(label: Text('Purchased'), numeric: true),
                              DataColumn(label: Text('Returned'), numeric: true),
                              DataColumn(label: Text('Net Qty'), numeric: true),
                              DataColumn(label: Text('Price'), numeric: true),
                              DataColumn(label: Text('Discount'), numeric: true),
                              DataColumn(label: Text('Final Amount'), numeric: true),
                            ],
                            rows: [
                              ...widget.report.items.asMap().entries.map((entry) {
                                final idx = entry.key + 1;
                                final item = entry.value;
                                final discountText = item.discountPercent > 0
                                    ? '${item.discountPercent.toStringAsFixed(0)}%'
                                    : '₹${item.discountAmount.toStringAsFixed(0)}';

                                return DataRow(
                                  color: item.returnedQty > 0
                                      ? WidgetStateProperty.all(
                                          Colors.amber.shade50.withValues(alpha: 0.5))
                                      : null,
                                  cells: [
                                    DataCell(Text('$idx')),
                                    DataCell(
                                      ConstrainedBox(
                                        constraints:
                                            const BoxConstraints(maxWidth: 180),
                                        child: Text(
                                          item.bookTitle,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text('${item.purchasedQty}')),
                                    DataCell(Text(
                                      '${item.returnedQty}',
                                      style: TextStyle(
                                        color: item.returnedQty > 0
                                            ? Colors.red.shade700
                                            : null,
                                        fontWeight: item.returnedQty > 0
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    )),
                                    DataCell(Text(
                                      '${item.netQty}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    )),
                                    DataCell(Text(
                                        '₹${item.unitPrice.toStringAsFixed(2)}')),
                                    DataCell(Text(discountText)),
                                    DataCell(Text(
                                      '₹${item.finalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    )),
                                  ],
                                );
                              }),
                              // Summary footer row
                              DataRow(
                                color: WidgetStateProperty.all(
                                    Colors.grey.shade200),
                                cells: [
                                  const DataCell(Text('')),
                                  const DataCell(Text(
                                    'TOTAL',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  )),
                                  DataCell(Text(
                                    '$totalPurchased',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  )),
                                  DataCell(Text(
                                    '$totalReturned',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red),
                                  )),
                                  DataCell(Text(
                                    '$totalNet',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  )),
                                  const DataCell(Text('')),
                                  const DataCell(Text('')),
                                  DataCell(Text(
                                    '₹${widget.report.grandTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  )),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),

          // Bottom Action & Total Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount Yet to Pay:',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '₹${widget.report.grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accent500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSharing ? null : _handleShareWhatsApp,
                          icon: const Icon(Icons.share, color: Colors.green),
                          label: const Text(
                            'WhatsApp',
                            style: TextStyle(color: Colors.green),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.green),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isPrinting ? null : _handlePrintA4,
                          icon: const Icon(Icons.print, color: Colors.white),
                          label: const Text(
                            'Print A4',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent500,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
