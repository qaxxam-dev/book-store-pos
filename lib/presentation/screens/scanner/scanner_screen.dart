import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:book_store_pos/core/theme.dart';

class ScannerScreen extends StatefulWidget {
  final Function(String) onScanned;
  final bool isContinuous;

  const ScannerScreen({
    super.key,
    required this.onScanned,
    this.isContinuous = true,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  String? _lastScannedCode;
  DateTime? _lastScannedTime;
  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null) return;

    final now = DateTime.now();

    // Debounce logic:
    // If same code scanned within 2 seconds, ignore.
    if (_lastScannedCode == code &&
        _lastScannedTime != null &&
        now.difference(_lastScannedTime!) < const Duration(seconds: 2)) {
      return;
    }

    // Update state
    _lastScannedCode = code;
    _lastScannedTime = now;

    // Trigger callback
    widget.onScanned(code);

    if (!widget.isContinuous) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        actions: [
          if (widget.isContinuous)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Done',
                style: TextStyle(
                  color: AppTheme.accent700,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
          ),
          // Overlay guide
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.accent700, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              widget.isContinuous
                  ? 'Continuous Mode: Keep scanning items'
                  : 'Scan a barcode',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.accent50,
                fontSize: 16,
                backgroundColor: AppTheme.neutral900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
