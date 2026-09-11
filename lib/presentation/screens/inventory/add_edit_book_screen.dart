import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import '../scanner/scanner_screen.dart';
import '../../../core/theme.dart';
import '../../../data/models/book.dart';
import '../../providers/book_provider.dart';
import '../../providers/settings_provider.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../providers/auth_provider.dart';

class AddEditBookScreen extends StatefulWidget {
  final Book? book;

  const AddEditBookScreen({super.key, this.book});

  @override
  State<AddEditBookScreen> createState() => _AddEditBookScreenState();
}

class _AddEditBookScreenState extends State<AddEditBookScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _skuController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _authorController;
  late TextEditingController _publisherController;

  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.book?.title ?? '');
    _skuController = TextEditingController(text: widget.book?.sku ?? '');
    _priceController =
        TextEditingController(text: widget.book?.price.toString() ?? '');
    _stockController = TextEditingController(
        text: widget.book?.stockQuantity.toString() ?? '');
    _authorController = TextEditingController(text: widget.book?.author ?? '');
    _publisherController =
        TextEditingController(text: widget.book?.publisher ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _authorController.dispose();
    _publisherController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerScreen(
          isContinuous: false,
          onScanned: (code) {
            setState(() {
              _skuController.text = code;
            });
          },
        ),
      ),
    );
  }

  Future<void> _scanBookCover() async {
    final settingsProvider = context.read<SettingsProvider>();
    final apiKey = settingsProvider.getSetting('ai_api_key');

    if (apiKey.isEmpty) {
      if (mounted) {
        AppSnackBar.showError(
            context, 'Please set Gemini API Key in Settings first.');
      }
      return;
    }

    setState(() => _isScanning = true);
    try {
      // Prompt user to scan book cover
      if (mounted) {
        AppSnackBar.showWarning(context, 'Please scan Book Cover');
      }

      // We only need one picture now
      List<String>? pictures = await CunningDocumentScanner.getPictures();

      if (pictures != null && pictures.isNotEmpty) {
        // Take the first image
        String imagePathToSend = pictures[0];

        final apiKey = settingsProvider.getSetting('ai_api_key');
        final aiModel = settingsProvider.aiModel;

        final aiService = AiService(apiKey, modelName: aiModel);
        final book = await aiService.extractBookDetails([imagePathToSend]);

        if (book != null) {
          setState(() {
            _titleController.text = book.title;
            // Only title is extracted now
          });
          if (mounted) {
            AppSnackBar.showSuccess(
                context, 'Book title extracted successfully!');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Error scanning: $e');
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _saveBook() async {
    if (_formKey.currentState!.validate()) {
      String sku = _skuController.text;
      if (sku.isEmpty) {
        sku = 'AUTO-${DateTime.now().millisecondsSinceEpoch}';
      }

      final book = Book(
        id: widget.book?.id,
        title: _titleController.text,
        sku: sku,
        price: double.parse(_priceController.text),
        stockQuantity: int.tryParse(_stockController.text) ?? 0,
        author: _authorController.text,
        publisher: _publisherController.text,
      );

      final provider = context.read<BookProvider>();
      final authProvider = context.read<AuthProvider>();
      try {
        if (widget.book == null) {
          await provider.addBook(book, isDemo: authProvider.isDemo);
          if (mounted) {
            AppSnackBar.showSuccess(context, 'Book added successfully');
          }
        } else {
          // Update usually doesn't need limit check, but keeping API consistent if needed
          await provider.updateBook(book);
          if (mounted) {
            AppSnackBar.showSuccess(context, 'Book updated successfully');
          }
        }
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          if (e is Map && e['type'] == 'purchase_required') {
            DialogUtils.showPurchaseDialog(e['message'], e['url'], context);
          } else if (e
              .toString()
              .contains('UNIQUE constraint failed: books.sku')) {
            AppSnackBar.showError(context, 'Error: SKU already exists');
          } else {
            AppSnackBar.showError(context, 'Error saving book: $e');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book == null ? 'Add Book' : 'Edit Book'),
        actions: [
          if (widget.book != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Book'),
                    content: const Text(
                        'Are you sure you want to delete this book?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  try {
                    await context
                        .read<BookProvider>()
                        .deleteBook(widget.book!.id!);
                    if (mounted) {
                      AppSnackBar.showSuccess(
                          context, 'Book deleted successfully');
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (mounted) {
                      AppSnackBar.showError(context, 'Error deleting book: $e');
                    }
                  }
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // AI Scan Button
            ElevatedButton.icon(
              onPressed: _isScanning ? null : _scanBookCover,
              icon: _isScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.camera_alt),
              label:
                  Text(_isScanning ? 'Processing...' : 'Scan Book Cover (AI)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent700,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),

            // Basic Info
            Text('Basic Info', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title *'),
              validator: (value) => value!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _skuController,
                    decoration:
                        const InputDecoration(labelText: 'SKU / Barcode'),
                    // Removed validator
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scanBarcode,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                        labelText: 'Price *', prefixText: '₹'),
                    keyboardType: TextInputType.number,
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    decoration: const InputDecoration(labelText: 'Stock'),
                    keyboardType: TextInputType.number,
                    // Removed required validator
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Details
            Text('Details', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextFormField(
              controller: _authorController,
              decoration: const InputDecoration(labelText: 'Author'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _publisherController,
              decoration: const InputDecoration(labelText: 'Publisher'),
            ),
            const SizedBox(height: 32),

            // Save Button
            ElevatedButton(
              onPressed: _saveBook,
              child: const Text('Save Book'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
