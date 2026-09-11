import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import '../../data/models/sale.dart';
import '../../data/models/sale_item.dart';
import '../../data/models/book.dart';
import '../../data/models/customer.dart';
import '../../data/models/purchase.dart';
import '../../data/models/purchase_item.dart';
import '../../data/models/distributor.dart';
import '../../data/models/purchase_return.dart';
import '../../data/models/purchase_return_item.dart';
import '../../data/models/sales_return.dart';
import '../../data/models/sales_return_item.dart';
import '../../data/models/receipt_model.dart';

import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/distributor_repository.dart';
import '../../presentation/widgets/receipt_widget.dart';
import '../../presentation/widgets/shipping_slip_widget.dart';

class ReceiptService {
  /// Renders the [ReceiptWidget] to PNG bytes off-screen.
  ///
  /// This bypasses standard text-based PDF/ESC-POS limitations (like Tamil support).
  /// [width] should match the printer width (380 for 58mm, 580 for 80mm approx).
  Future<Uint8List> renderReceiptToPng(ReceiptModel data,
      {double pixelRatio = 3.0, double width = 380}) async {
    final RenderRepaintBoundary boundary = RenderRepaintBoundary();
    final RenderView renderView = RenderView(
      child: RenderPositionedBox(alignment: Alignment.topCenter, child: boundary),
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(Size(width, 10000)),
        devicePixelRatio: 1.0,
      ),
      view: WidgetsBinding.instance.platformDispatcher.views.first,
    );

    final PipelineOwner pipelineOwner = PipelineOwner();
    final BuildOwner buildOwner = BuildOwner(focusManager: FocusManager());

    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();

    final RenderObjectToWidgetElement<RenderBox> rootElement =
        RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: Directionality(
        textDirection: ui.TextDirection.ltr,
        child: Theme(
          data: ThemeData.light(),
          child: ReceiptWidget(data: data, width: width),
        ),
      ),
    ).attachToRenderTree(buildOwner);

    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();

    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  /// Prints the receipt using the system print dialog (PDF).
  ///
  /// Embeds the rasterized receipt image into a PDF to ensure correct rendering.
  /// If the receipt is too tall for a single page, it splits across multiple pages.
  Future<void> printReceiptToSystemPrinter(ReceiptModel data) async {
    // Render at a good width for A4 printable area (~190mm at 72 DPI ≈ 545 points)
    const double renderWidth = 545.0;
    const double pixelRatio = 2.0; // Higher ratio for crisp text

    // Render widget to PNG
    final pngBytes =
        await renderReceiptToPng(data, width: renderWidth, pixelRatio: pixelRatio);

    // Decode the PNG to get actual dimensions for slicing
    final decodedImage = img.decodePng(pngBytes);
    if (decodedImage == null) return;

    final int imgWidth = decodedImage.width;
    final int imgHeight = decodedImage.height;

    // A4 page dimensions in PDF points (1 point = 1/72 inch)
    final double pageWidth = PdfPageFormat.a4.width; // 595.28
    final double pageHeight = PdfPageFormat.a4.height; // 841.89
    const double margin = 28.0; // ~10mm margins
    final double printableWidth = pageWidth - (margin * 2);
    final double printableHeight = pageHeight - (margin * 2);

    // Calculate how the image scales onto the page
    final double scale = printableWidth / imgWidth;
    final double scaledFullHeight = imgHeight * scale;

    final pdf = pw.Document();

    if (scaledFullHeight <= printableHeight) {
      // Receipt fits on one page — no slicing needed
      final image = pw.MemoryImage(pngBytes);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(margin),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Image(
                  image,
                  width: printableWidth,
                  height: scaledFullHeight,
                  fit: pw.BoxFit.fill,
                  alignment: pw.Alignment.topCenter,
                ),
              ],
            );
          },
        ),
      );
    } else {
      // Receipt overflows — use content-aware splitting to avoid cutting rows
      // Calculate how many pixel rows fit per page
      final int maxRowsPerPage = (printableHeight / scale).floor();

      // Find all "blank" rows in the image (rows where content has ended —
      // i.e. safe places to split). A row is blank if all pixels are
      // near-white (background).
      Set<int> blankRows = {};
      for (int y = 0; y < imgHeight; y++) {
        bool isBlank = true;
        // Sample pixels across the row (every 4th pixel for speed)
        for (int x = 0; x < imgWidth; x += 4) {
          final pixel = decodedImage.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();
          // Check if pixel is near-white (threshold: 240)
          if (r < 240 || g < 240 || b < 240) {
            isBlank = false;
            break;
          }
        }
        if (isBlank) {
          blankRows.add(y);
        }
      }

      // Build page split points using blank rows
      int yOffset = 0;
      while (yOffset < imgHeight) {
        int idealEnd = yOffset + maxRowsPerPage;

        if (idealEnd >= imgHeight) {
          // Last chunk — take everything remaining
          idealEnd = imgHeight;
        } else {
          // Find the closest blank row at or before idealEnd to split cleanly.
          // Search backwards from idealEnd for a blank row.
          int bestSplit = -1;
          // Search within the last 20% of the chunk for a good split point
          final int searchStart = (idealEnd - (maxRowsPerPage * 0.2)).floor();
          for (int i = idealEnd; i >= searchStart && i > yOffset; i--) {
            if (blankRows.contains(i)) {
              bestSplit = i;
              break;
            }
          }

          if (bestSplit > yOffset) {
            idealEnd = bestSplit;
          }
          // If no blank row found, fall back to the mechanical split (idealEnd)
        }

        final int chunkHeight = idealEnd - yOffset;
        if (chunkHeight <= 0) break;

        // Crop a horizontal strip from the full image
        final img.Image chunk = img.copyCrop(
          decodedImage,
          x: 0,
          y: yOffset,
          width: imgWidth,
          height: chunkHeight,
        );
        final Uint8List chunkPng = Uint8List.fromList(img.encodePng(chunk));
        final chunkImage = pw.MemoryImage(chunkPng);

        final double chunkScaledHeight = chunkHeight * scale;
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(margin),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Image(
                    chunkImage,
                    width: printableWidth,
                    height: chunkScaledHeight,
                    fit: pw.BoxFit.fill,
                    alignment: pw.Alignment.topCenter,
                  ),
                ],
              );
            },
          ),
        );

        yOffset = idealEnd;
      }
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Receipt_${data.billNumber}',
    );
  }

  /// Generates ESC/POS commands for a thermal printer.
  ///
  /// Returns a list of bytes ready to be sent to a printer connection.
  /// Uses [CapabilityProfile] to ensure compatibility.
  Future<List<int>> generateThermalPrintBytes(ReceiptModel data,
      {PaperSize paperSize = PaperSize.mm58}) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    // 1. Render Widget to PNG
    // 58mm @ 203dpi = 384 dots.
    // 58mm @ 304dpi = 576 dots. (User's case)
    // 80mm @ 203dpi = 576 dots.

    double width;
    double pixelRatio;

    if (paperSize == PaperSize.mm58) {
      // "Zoom" strategy:
      // Layout at a narrower logical width (280) so text wraps sooner and appears larger relative to the width.
      // Target 576 physical dots (304 dpi).
      // Scale = 576 / 280 ≈ 2.05.
      width = 280.0;
      pixelRatio = 576.0 / 280.0;
    } else {
      // 80mm standard
      width = 576.0;
      pixelRatio = 1.0;
    }

    final pngBytes =
        await renderReceiptToPng(data, pixelRatio: pixelRatio, width: width);

    // 2. Decode PNG to Image object
    final img.Image? image = img.decodePng(pngBytes);

    if (image != null) {
      // 3. Resize if needed (though we generated it at target width)
      // Gray-scale and dither handled by generator.imageRaster usually
      // imageRaster is faster/better for high density
      bytes += generator.imageRaster(image);
      bytes += generator.feed(2);
      bytes += generator.cut();
    }

    return bytes;
  }

  /// Sends the receipt to a thermal printer (Placeholder).
  ///
  /// This needs an actual printer connection (USB/Bluetooth/Network).
  /// Since the transport layer depends on external packages (like flutter_blue_plus),
  /// this method serves as an integration point.
  Future<void> printReceiptToThermalPrinter(ReceiptModel data) async {
    // Example usage:
    // final bytes = await generateThermalPrintBytes(data);
    // await printerConnection.write(bytes);
    debugPrint('Thermal Print: Generated ${data.billNumber}');
  }

  // --- Adapters for backward compatibility ---

  Future<ReceiptModel> _buildReceiptModelForSale({
    required Sale sale,
    required List<SaleItem> items,
    required List<Book> books,
    required Map<String, String> settings,
    Customer? customer,
  }) async {
    // Fetch fresh customer if needed
    if (customer != null) {
      final fresh = await CustomerRepository().getCustomerById(customer.id!);
      if (fresh != null) customer = fresh;
    }

    final date = DateTime.tryParse(sale.timestamp) ?? DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy').format(date);
    final formattedTime = DateFormat('hh:mm a').format(date);

    final mappedItems = items.map((item) {
      final book = books.firstWhere((b) => b.id == item.bookId,
          orElse: () =>
              Book(title: 'Unknown', sku: '', price: 0, stockQuantity: 0));
      return ReceiptItem(
        title: book.title,
        quantity: item.quantity.toDouble(),
        price: item.priceAtSale,
        total: item.priceAtSale * item.quantity,
      );
    }).toList();

    return ReceiptModel(
      type: ReceiptType.sale,
      shopName: settings['shop_name'] ?? 'Book Shop',
      shopAddress: settings['shop_address'] ?? '',
      shopPhone: settings['shop_number'] ?? '',
      thankYouMessage:
          settings['thank_you_message'] ?? 'Thank you for your purchase!',
      billNumber: sale.billNumber,
      date: formattedDate,
      time: formattedTime,
      partyName: sale.paymentMethod == 'Complementary' &&
              (sale.customerName != null && sale.customerName!.isNotEmpty)
          ? 'Given To: ${sale.customerName}'
          : (customer?.name ?? 'Guest'),
      partyPhone: sale.paymentMethod == 'Complementary'
          ? (sale.customerMobile ?? (customer?.phone ?? sale.guestPhone))
          : (customer != null ? customer.phone : sale.guestPhone),
      partyBalance: customer?.balance,
      paymentMethod: sale.paymentMethod,
      items: mappedItems,
      subtotal: sale.totalAmount + sale.discount - sale.shippingAmount,
      discount: sale.discount,
      discountPercent: sale.discountPercent,
      shippingAmount: sale.shippingAmount,
      totalAmount: sale.totalAmount,
    );
  }

  Future<void> printReceipt({
    required Sale sale,
    required List<SaleItem> items,
    required List<Book> books,
    required Map<String, String> settings,
    Customer? customer,
    Future<void> Function(List<int>)? thermalHandler,
  }) async {
    final model = await _buildReceiptModelForSale(
      sale: sale,
      items: items,
      books: books,
      settings: settings,
      customer: customer,
    );
    if (thermalHandler != null) {
      final bytes = await generateThermalPrintBytes(model);
      await thermalHandler(bytes);
    } else {
      await printReceiptToSystemPrinter(model);
    }
  }

  // --- Purchase Adapter ---

  Future<ReceiptModel> _buildReceiptModelForPurchase({
    required Purchase purchase,
    required List<PurchaseItem> items,
    required List<Book> books,
    required Map<String, String> settings,
    required Distributor distributor,
  }) async {
    final fresh =
        await DistributorRepository().getDistributorById(distributor.id!);
    if (fresh != null) distributor = fresh;

    final date = DateTime.tryParse(purchase.timestamp) ?? DateTime.now();

    final mappedItems = items.map((item) {
      final book = books.firstWhere((b) => b.id == item.bookId,
          orElse: () =>
              Book(title: 'Unknown', sku: '', price: 0, stockQuantity: 0));
      return ReceiptItem(
        title: book.title,
        quantity: item.quantity.toDouble(),
        price: item.costPrice,
        total: item.costPrice * item.quantity,
      );
    }).toList();

    return ReceiptModel(
      type: ReceiptType.purchase,
      shopName: settings['shop_name'] ?? 'Book Shop',
      shopAddress: settings['shop_address'] ?? '',
      shopPhone: settings['shop_number'] ?? '',
      thankYouMessage: '',
      billNumber: purchase.billNumber,
      date: DateFormat('dd/MM/yyyy').format(date),
      time: DateFormat('hh:mm a').format(date),
      partyName: distributor.name,
      partyPhone: distributor.phone,
      partyBalance: distributor.balance,
      paymentMethod: purchase.paymentMethod,
      items: mappedItems,
      subtotal: purchase.totalAmount + purchase.discount,
      discount: purchase.discount,
      totalAmount: purchase.totalAmount,
    );
  }

  Future<void> printPurchaseReceipt({
    required Purchase purchase,
    required List<PurchaseItem> items,
    required List<Book> books,
    required Map<String, String> settings,
    required Distributor distributor,
    Future<void> Function(List<int>)? thermalHandler,
  }) async {
    final model = await _buildReceiptModelForPurchase(
      purchase: purchase,
      items: items,
      books: books,
      settings: settings,
      distributor: distributor,
    );
    if (thermalHandler != null) {
      final bytes = await generateThermalPrintBytes(model);
      await thermalHandler(bytes);
    } else {
      await printReceiptToSystemPrinter(model);
    }
  }

  // --- Return Adapters ---

  Future<void> printPurchaseReturnReceipt({
    required PurchaseReturn returnRecord,
    required List<PurchaseReturnItem> items,
    required List<Book> books,
    required Map<String, String> settings,
    required Distributor distributor,
    required Purchase purchase,
    Future<void> Function(List<int>)? thermalHandler,
  }) async {
    final fresh =
        await DistributorRepository().getDistributorById(distributor.id!);
    if (fresh != null) distributor = fresh;

    final date = DateTime.tryParse(returnRecord.timestamp) ?? DateTime.now();

    final mappedItems = items.map((item) {
      final book = books.firstWhere((b) => b.id == item.bookId,
          orElse: () =>
              Book(title: 'Unknown', sku: '', price: 0, stockQuantity: 0));
      return ReceiptItem(
        title: book.title,
        quantity: item.quantity.toDouble(),
        price: 0, // Not relevant for return list usually only refund matters
        total: item.refundAmount,
      );
    }).toList();

    final model = ReceiptModel(
      type: ReceiptType.purchaseReturn,
      shopName: settings['shop_name'] ?? 'Book Shop',
      shopAddress: settings['shop_address'] ?? '',
      shopPhone: settings['shop_number'] ?? '',
      thankYouMessage: '',
      billNumber: returnRecord.billNumber,
      originalBillNumber: purchase.billNumber,
      date: DateFormat('dd/MM/yyyy').format(date),
      time: DateFormat('hh:mm a').format(date),
      partyName: distributor.name,
      partyPhone: distributor.phone,
      partyBalance: distributor.balance,
      paymentMethod: purchase.paymentMethod,
      items: mappedItems,
      subtotal: returnRecord.totalRefund,
      totalAmount: returnRecord.totalRefund,
      isReturn: true,
    );
    if (thermalHandler != null) {
      final bytes = await generateThermalPrintBytes(model);
      await thermalHandler(bytes);
    } else {
      await printReceiptToSystemPrinter(model);
    }
  }

  Future<void> printSalesReturnReceipt({
    required SalesReturn returnRecord,
    required List<SalesReturnItem> items,
    required List<Book> books,
    required Map<String, String> settings,
    Customer? customer,
    required Sale sale,
    Future<void> Function(List<int>)? thermalHandler,
  }) async {
    if (customer != null) {
      final fresh = await CustomerRepository().getCustomerById(customer.id!);
      if (fresh != null) customer = fresh;
    }
    final date = DateTime.tryParse(returnRecord.timestamp) ?? DateTime.now();

    final mappedItems = items.map((item) {
      final book = books.firstWhere((b) => b.id == item.bookId,
          orElse: () =>
              Book(title: 'Unknown', sku: '', price: 0, stockQuantity: 0));
      return ReceiptItem(
        title: book.title,
        quantity: item.quantity.toDouble(),
        price: 0,
        total: item.refundAmount,
      );
    }).toList();

    final model = ReceiptModel(
      type: ReceiptType.saleReturn,
      shopName: settings['shop_name'] ?? 'Book Shop',
      shopAddress: settings['shop_address'] ?? '',
      shopPhone: settings['shop_number'] ?? '',
      thankYouMessage: settings['thank_you_message'] ?? 'Thank you!',
      billNumber: returnRecord.billNumber,
      originalBillNumber: sale.billNumber,
      date: DateFormat('dd/MM/yyyy').format(date),
      time: DateFormat('hh:mm a').format(date),
      partyName: customer?.name ?? 'Guest',
      partyPhone: customer?.phone ?? sale.guestPhone,
      partyBalance: customer?.balance,
      paymentMethod: sale.paymentMethod,
      items: mappedItems,
      subtotal: returnRecord.totalRefund,
      totalAmount: returnRecord.totalRefund,
      isReturn: true,
    );
    if (thermalHandler != null) {
      final bytes = await generateThermalPrintBytes(model);
      await thermalHandler(bytes);
    } else {
      await printReceiptToSystemPrinter(model);
    }
  }

  // --- Shipping Slip Methods ---

  Future<Uint8List> renderShippingSlipToPng({
    required String shopName,
    required String shopAddress,
    required String shopPhone,
    required String billNumber,
    required String date,
    required String time,
    required String customerName,
    required String customerMobile,
    required String customerAddress,
    double pixelRatio = 3.0,
    double width = 380,
  }) async {
    final RenderRepaintBoundary boundary = RenderRepaintBoundary();
    final RenderView renderView = RenderView(
      child: RenderPositionedBox(alignment: Alignment.topCenter, child: boundary),
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(Size(width, 10000)),
        devicePixelRatio: 1.0,
      ),
      view: WidgetsBinding.instance.platformDispatcher.views.first,
    );

    final PipelineOwner pipelineOwner = PipelineOwner();
    final BuildOwner buildOwner = BuildOwner(focusManager: FocusManager());

    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();

    final RenderObjectToWidgetElement<RenderBox> rootElement =
        RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: Directionality(
        textDirection: ui.TextDirection.ltr,
        child: Theme(
          data: ThemeData.light(),
          child: ShippingSlipWidget(
            shopName: shopName,
            shopAddress: shopAddress,
            shopPhone: shopPhone,
            billNumber: billNumber,
            date: date,
            time: time,
            customerName: customerName,
            customerMobile: customerMobile,
            customerAddress: customerAddress,
            width: width,
            isThermal: true, // Always assume thermal style for slip
          ),
        ),
      ),
    ).attachToRenderTree(buildOwner);

    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();

    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  Future<List<int>> generateShippingSlipBytes({
    required String shopName,
    required String shopAddress,
    required String shopPhone,
    required String billNumber,
    required String date,
    required String time,
    required String customerName,
    required String customerMobile,
    required String customerAddress,
    PaperSize paperSize = PaperSize.mm58,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    double width;
    double pixelRatio;

    if (paperSize == PaperSize.mm58) {
      width = 280.0;
      pixelRatio = 576.0 / 280.0;
    } else {
      width = 576.0;
      pixelRatio = 1.0;
    }

    final pngBytes = await renderShippingSlipToPng(
      shopName: shopName,
      shopAddress: shopAddress,
      shopPhone: shopPhone,
      billNumber: billNumber,
      date: date,
      time: time,
      customerName: customerName,
      customerMobile: customerMobile,
      customerAddress: customerAddress,
      pixelRatio: pixelRatio,
      width: width,
    );

    final img.Image? image = img.decodePng(pngBytes);

    if (image != null) {
      bytes += generator.imageRaster(image);
      bytes += generator.feed(2);
      bytes += generator.cut();
    }

    return bytes;
  }

  Future<void> printShippingSlip({
    required Sale sale,
    required Map<String, String> settings,
    required Future<void> Function(List<int>) thermalHandler,
  }) async {
    if (sale.shippingAmount <= 0) return;

    final date = DateTime.tryParse(sale.timestamp) ?? DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy').format(date);
    final formattedTime = DateFormat('hh:mm a').format(date);

    final shopName = settings['shop_name'] ?? 'Book Shop';
    final shopAddress = settings['shop_address'] ?? '';
    final shopPhone = settings['shop_number'] ?? '';

    final bytes = await generateShippingSlipBytes(
      shopName: shopName,
      shopAddress: shopAddress,
      shopPhone: shopPhone,
      billNumber: sale.billNumber,
      date: formattedDate,
      time: formattedTime,
      customerName: sale.customerName ?? 'Guest',
      customerMobile: sale.customerMobile ?? sale.guestPhone ?? '',
      customerAddress: sale.customerAddress ?? 'No Address',
    );

    await thermalHandler(bytes);
  }
}
