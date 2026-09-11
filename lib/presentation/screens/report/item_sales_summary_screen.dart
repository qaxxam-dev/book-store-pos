import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../data/repositories/sales_repository.dart';

class ItemSalesSummaryScreen extends StatefulWidget {
  const ItemSalesSummaryScreen({super.key});

  @override
  State<ItemSalesSummaryScreen> createState() => _ItemSalesSummaryScreenState();
}

enum DatePreset { today, yesterday, thisWeek, thisMonth, custom }

class _ItemSalesSummaryScreenState extends State<ItemSalesSummaryScreen> {
  final SalesRepository _salesRepository = SalesRepository();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  DatePreset _selectedPreset = DatePreset.today;

  List<SoldItemSummary> _allItems = [];
  List<SoldItemSummary> _filteredItems = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _applyPreset(DatePreset.today);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyPreset(DatePreset preset) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    switch (preset) {
      case DatePreset.today:
        start = now;
        end = now;
        break;
      case DatePreset.yesterday:
        start = now.subtract(const Duration(days: 1));
        end = start;
        break;
      case DatePreset.thisWeek:
        start = now.subtract(Duration(days: now.weekday - 1));
        end = now;
        break;
      case DatePreset.thisMonth:
        start = DateTime(now.year, now.month, 1);
        end = now;
        break;
      case DatePreset.custom:
        return;
    }

    setState(() {
      _selectedPreset = preset;
      _startDate = start;
      _endDate = end;
    });

    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final items = await _salesRepository.getConsolidatedSoldItems(
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) {
        setState(() {
          _allItems = items;
          _filterItems(_searchController.text);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackBar.showError(context, 'Error loading sold items: $e');
      }
    }
  }

  void _filterItems(String query) {
    if (query.trim().isEmpty) {
      _filteredItems = List.from(_allItems);
    } else {
      final q = query.toLowerCase();
      _filteredItems = _allItems.where((item) {
        return item.title.toLowerCase().contains(q) ||
            item.sku.toLowerCase().contains(q);
      }).toList();
    }
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.accent700,
              onPrimary: Colors.white,
              onSurface: AppTheme.neutral900,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPreset = DatePreset.custom;
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  String _generateReportText() {
    final dateFmt = DateFormat('dd MMM yyyy');
    final startFormatted = dateFmt.format(_startDate);
    final endFormatted = dateFmt.format(_endDate);
    final dateRangeStr = _startDate.year == _endDate.year &&
            _startDate.month == _endDate.month &&
            _startDate.day == _endDate.day
        ? startFormatted
        : '$startFormatted - $endFormatted';

    final totalCopies =
        _filteredItems.fold(0, (sum, item) => sum + item.totalSold);

    final buffer = StringBuffer();
    buffer.writeln('Item Sales Summary ($dateRangeStr)');
    buffer.writeln('Note: Excludes Credit & Complementary');
    buffer.writeln('Total Items: ${_filteredItems.length}');
    buffer.writeln('Total Sold Copies: $totalCopies');
    buffer.writeln('--------------------------------');
    buffer.writeln('item, total sold copies');
    for (var item in _filteredItems) {
      buffer.writeln('${item.title}, ${item.totalSold}');
    }
    return buffer.toString();
  }

  void _shareReport() {
    if (_filteredItems.isEmpty) {
      AppSnackBar.showError(context, 'No sold items to share.');
      return;
    }
    final text = _generateReportText();
    // ignore: deprecated_member_use
    Share.share(text, subject: 'Item Sales Summary');
  }

  void _copyReportToClipboard() {
    if (_filteredItems.isEmpty) {
      AppSnackBar.showError(context, 'No sold items to copy.');
      return;
    }
    final text = _generateReportText();
    Clipboard.setData(ClipboardData(text: text));
    AppSnackBar.showSuccess(context, 'Summary copied to clipboard!');
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy');
    final totalCopies =
        _filteredItems.fold(0, (sum, item) => sum + item.totalSold);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Sales Summary'),
        actions: [
          IconButton(
            tooltip: 'Copy to Clipboard',
            icon: const Icon(Icons.copy),
            onPressed: _copyReportToClipboard,
          ),
          IconButton(
            tooltip: 'Share Report',
            icon: const Icon(Icons.share),
            onPressed: _shareReport,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Preset Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPresetChip('Today', DatePreset.today),
                      const SizedBox(width: 8),
                      _buildPresetChip('Yesterday', DatePreset.yesterday),
                      const SizedBox(width: 8),
                      _buildPresetChip('This Week', DatePreset.thisWeek),
                      const SizedBox(width: 8),
                      _buildPresetChip('This Month', DatePreset.thisMonth),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.date_range,
                            size: 16, color: AppTheme.accent700),
                        label: Text(
                          _selectedPreset == DatePreset.custom
                              ? '${dateFmt.format(_startDate)} - ${dateFmt.format(_endDate)}'
                              : 'Custom',
                          style: TextStyle(
                            color: _selectedPreset == DatePreset.custom
                                ? AppTheme.accent700
                                : AppTheme.neutral900,
                            fontWeight: _selectedPreset == DatePreset.custom
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        backgroundColor: _selectedPreset == DatePreset.custom
                            ? AppTheme.accent100
                            : AppTheme.neutral100,
                        onPressed: _pickCustomDateRange,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Search bar
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _filterItems(val);
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by book title or SKU...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _filterItems('');
                              });
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.neutral300),
                    ),
                    filled: true,
                    fillColor: AppTheme.neutral50,
                  ),
                ),
              ],
            ),
          ),

          // Summary Stats Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.accent50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.menu_book,
                        size: 18, color: AppTheme.accent700),
                    const SizedBox(width: 6),
                    Text(
                      'Unique Items: ${_filteredItems.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent700,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined,
                        size: 18, color: AppTheme.successText),
                    const SizedBox(width: 6),
                    Text(
                      'Total Sold: $totalCopies copies',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Items List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 56, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'No sold items found in this date range.',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '(Credit & Complementary sales are excluded)',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _filteredItems.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: AppTheme.accent100,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accent700,
                                  ),
                                ),
                              ),
                              title: Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: item.sku.isNotEmpty
                                  ? Text(
                                      'SKU: ${item.sku}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.neutral600,
                                      ),
                                    )
                                  : null,
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent100,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '${item.totalSold} sold',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppTheme.accent700,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, DatePreset preset) {
    final isSelected = _selectedPreset == preset;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.accent700,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.neutral900,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: AppTheme.neutral100,
      onSelected: (selected) {
        if (selected) _applyPreset(preset);
      },
    );
  }
}
