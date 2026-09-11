import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/excel_service.dart';
import '../../../core/theme.dart';
import '../../../data/models/book.dart';
import '../../providers/book_provider.dart';
import '../../../core/utils/snackbar_utils.dart';

class ExcelImportScreen extends StatefulWidget {
  const ExcelImportScreen({super.key});

  @override
  State<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

class _ExcelImportScreenState extends State<ExcelImportScreen> {
  File? _selectedFile;
  List<List<dynamic>> _rows = [];
  List<String> _headers = [];
  bool _isLoading = false;

  // Mapping: Book Field -> Excel Column Index
  final Map<String, int?> _mapping = {
    'Title': null,
    'SKU/ISBN': null,
    'Price': null,
    'Stock': null,
    'Author': null,
    'Publisher': null,
  };

  final List<String> _requiredFields = ['Title', 'SKU/ISBN', 'Price'];

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _isLoading = true;
        });

        final rows = await ExcelService().readExcelFile(_selectedFile!);

        if (rows.isNotEmpty) {
          setState(() {
            _rows = rows;
            // Assume first row is header
            _headers = rows.first.map((e) => e.toString()).toList();
            _isLoading = false;

            // Auto-map if possible
            _autoMapHeaders();
          });
        } else {
          setState(() => _isLoading = false);
          if (mounted) AppSnackBar.showError(context, 'Excel file is empty');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) AppSnackBar.showError(context, 'Error reading file: $e');
    }
  }

  void _autoMapHeaders() {
    for (var i = 0; i < _headers.length; i++) {
      final header = _headers[i].toLowerCase();
      if (header.contains('title') || header.contains('name')) {
        _mapping['Title'] ??= i;
      } else if (header.contains('sku') ||
          header.contains('isbn') ||
          header.contains('barcode')) {
        _mapping['SKU/ISBN'] ??= i;
      } else if (header.contains('price') || header.contains('cost')) {
        _mapping['Price'] ??= i;
      } else if (header.contains('stock') ||
          header.contains('qty') ||
          header.contains('quantity')) {
        _mapping['Stock'] ??= i;
      } else if (header.contains('author') || header.contains('writer')) {
        _mapping['Author'] ??= i;
      } else if (header.contains('publisher')) {
        _mapping['Publisher'] ??= i;
      }
    }
  }

  Future<void> _importData() async {
    // Validate required fields
    for (final field in _requiredFields) {
      if (_mapping[field] == null) {
        AppSnackBar.showError(context, 'Please map required field: $field');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final books = <Book>[];
      // Skip header row
      for (var i = 1; i < _rows.length; i++) {
        final row = _rows[i];
        if (row.isEmpty) continue;

        try {
          final titleIdx = _mapping['Title']!;
          final skuIdx = _mapping['SKU/ISBN']!;
          final priceIdx = _mapping['Price']!;
          final stockIdx = _mapping['Stock'];
          final authorIdx = _mapping['Author'];
          final publisherIdx = _mapping['Publisher'];

          // Safe extraction
          String getValue(int idx) =>
              idx < row.length ? row[idx]?.toString() ?? '' : '';
          double getDouble(int idx) {
            if (idx >= row.length) return 0.0;
            final val = row[idx];
            if (val is num) return val.toDouble();
            return double.tryParse(val?.toString() ?? '') ?? 0.0;
          }

          int getInt(int idx) {
            if (idx >= row.length) return 0;
            final val = row[idx];
            if (val is num) return val.toInt();
            return int.tryParse(val?.toString() ?? '') ?? 0;
          }

          final title = getValue(titleIdx);
          final sku = getValue(skuIdx);
          final price = getDouble(priceIdx);

          if (title.isEmpty || sku.isEmpty) continue;

          books.add(Book(
            title: title,
            sku: sku,
            price: price,
            stockQuantity: stockIdx != null ? getInt(stockIdx) : 0,
            author: authorIdx != null ? getValue(authorIdx) : null,
            publisher: publisherIdx != null ? getValue(publisherIdx) : null,
          ));
        } catch (e) {
          print('Skipping row $i: $e');
        }
      }

      if (books.isEmpty) {
        AppSnackBar.showWarning(context, 'No valid books found to import');
        setState(() => _isLoading = false);
        return;
      }

      await context.read<BookProvider>().importBooks(books);

      if (mounted) {
        AppSnackBar.showSuccess(
            context, 'Successfully imported ${books.length} books');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, 'Import failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Books from Excel')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // File Selection
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedFile != null
                              ? 'Selected: ${_selectedFile!.path.split(Platform.pathSeparator).last}'
                              : 'No file selected',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _pickFile,
                        child: const Text('Select Excel File'),
                      ),
                    ],
                  ),
                ),
                const Divider(),

                // Mapping & Preview
                if (_rows.isNotEmpty) ...[
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Map Columns',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 16),
                          ..._mapping.keys.map((field) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      field,
                                      style: TextStyle(
                                        fontWeight:
                                            _requiredFields.contains(field)
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                        color: _requiredFields.contains(field)
                                            ? Colors.red
                                            : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: DropdownButton<int>(
                                      isExpanded: true,
                                      value: _mapping[field],
                                      hint: const Text('Select Column'),
                                      items: [
                                        const DropdownMenuItem<int>(
                                          value: null,
                                          child: Text('Ignore'),
                                        ),
                                        ...List.generate(_headers.length,
                                            (index) {
                                          return DropdownMenuItem(
                                            value: index,
                                            child: Text(_headers[index]),
                                          );
                                        }),
                                      ],
                                      onChanged: (val) {
                                        setState(() {
                                          _mapping[field] = val;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 24),
                          Text('Preview (First 5 Rows)',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: _headers
                                  .map((h) => DataColumn(label: Text(h)))
                                  .toList(),
                              rows: _rows.skip(1).take(5).map((row) {
                                return DataRow(
                                  cells:
                                      List.generate(_headers.length, (index) {
                                    final val = index < row.length
                                        ? row[index]?.toString() ?? ''
                                        : '';
                                    return DataCell(Text(val));
                                  }),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _importData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                        child: const Text('Import Books'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }
}
