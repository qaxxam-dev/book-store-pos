import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../database_helper.dart';
import '../../data/models/settlement_report_model.dart';
import '../../presentation/widgets/settlement_receipt_widget.dart';

class SettlementService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Fetches and computes the consolidated SettlementReport
  Future<SettlementReport> generateSettlementReport({
    required bool isSale,
    required int partyId,
    required String partyName,
    required String partyPhone,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _dbHelper.database;

    final startStr = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      0,
      0,
      0,
    ).toIso8601String();

    final endStr = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
    ).toIso8601String();

    final List<SettlementTransactionSummary> creditBills = [];
    final List<SettlementTransactionSummary> returnBills = [];

    // Helper map to aggregate items:
    // Key: "${bookId}_${unitPrice.toStringAsFixed(2)}_${discountPercent.toStringAsFixed(2)}"
    final Map<String, _MutableSettlementItem> itemMap = {};
    // Map of bookId -> total returned quantity
    final Map<int, int> returnsByBookId = {};

    if (isSale) {
      // 1. Fetch Customer Credit Sales in Date Range
      final List<Map<String, dynamic>> salesRows = await db.query(
        'sales',
        where: 'customer_id = ? AND payment_method = ? AND timestamp >= ? AND timestamp <= ?',
        whereArgs: [partyId, 'Credit', startStr, endStr],
        orderBy: 'timestamp ASC',
      );

      for (final saleMap in salesRows) {
        final saleId = saleMap['id'] as int;
        final billNumber = saleMap['bill_number'] as String? ?? 'SL-$saleId';
        final totalAmount = (saleMap['total_amount'] as num?)?.toDouble() ?? 0.0;
        final discount = (saleMap['discount'] as num?)?.toDouble() ?? 0.0;
        final rawDiscountPercent =
            (saleMap['discount_percent'] as num?)?.toDouble() ?? 0.0;
        final timestamp = saleMap['timestamp'] as String? ?? '';

        double saleDiscountPercent = rawDiscountPercent;
        if (saleDiscountPercent <= 0 && discount > 0 && (totalAmount + discount) > 0) {
          saleDiscountPercent = (discount / (totalAmount + discount)) * 100;
        }

        // Fetch items for this sale
        final List<Map<String, dynamic>> itemRows = await db.rawQuery('''
          SELECT si.book_id, si.quantity, si.price_at_sale, b.title as book_title
          FROM sale_items si
          LEFT JOIN books b ON si.book_id = b.id
          WHERE si.sale_id = ?
        ''', [saleId]);

        int totalItemsInSale = 0;
        for (final row in itemRows) {
          final bookId = row['book_id'] as int;
          final bookTitle = row['book_title'] as String? ?? 'Book #$bookId';
          final qty = row['quantity'] as int;
          final unitPrice = (row['price_at_sale'] as num?)?.toDouble() ?? 0.0;

          totalItemsInSale += qty;

          final discountAmount = unitPrice * (saleDiscountPercent / 100);
          final key = '${bookId}_${unitPrice.toStringAsFixed(2)}_${saleDiscountPercent.toStringAsFixed(2)}';

          if (itemMap.containsKey(key)) {
            itemMap[key]!.purchasedQty += qty;
          } else {
            itemMap[key] = _MutableSettlementItem(
              bookId: bookId,
              bookTitle: bookTitle,
              purchasedQty: qty,
              returnedQty: 0,
              unitPrice: unitPrice,
              discountPercent: saleDiscountPercent,
              discountAmount: discountAmount,
            );
          }
        }

        creditBills.add(SettlementTransactionSummary(
          billNumber: billNumber,
          date: timestamp,
          amount: totalAmount,
          itemCount: totalItemsInSale,
        ));
      }

      // 2. Fetch Customer Sales Returns in Date Range
      final List<Map<String, dynamic>> returnRows = await db.rawQuery('''
        SELECT sr.id, sr.bill_number, sr.total_refund, sr.timestamp
        FROM sales_returns sr
        JOIN sales s ON sr.sale_id = s.id
        WHERE s.customer_id = ? AND sr.timestamp >= ? AND sr.timestamp <= ?
        ORDER BY sr.timestamp ASC
      ''', [partyId, startStr, endStr]);

      for (final retMap in returnRows) {
        final retId = retMap['id'] as int;
        final billNumber = retMap['bill_number'] as String? ?? 'SR-$retId';
        final totalRefund = (retMap['total_refund'] as num?)?.toDouble() ?? 0.0;
        final timestamp = retMap['timestamp'] as String? ?? '';

        final List<Map<String, dynamic>> retItems = await db.query(
          'sales_return_items',
          where: 'return_id = ?',
          whereArgs: [retId],
        );

        int totalItemsInReturn = 0;
        for (final rRow in retItems) {
          final bookId = rRow['book_id'] as int;
          final qty = rRow['quantity'] as int;
          totalItemsInReturn += qty;
          returnsByBookId[bookId] = (returnsByBookId[bookId] ?? 0) + qty;
        }

        returnBills.add(SettlementTransactionSummary(
          billNumber: billNumber,
          date: timestamp,
          amount: totalRefund,
          itemCount: totalItemsInReturn,
        ));
      }
    } else {
      // 1. Fetch Distributor Credit Purchases in Date Range
      final List<Map<String, dynamic>> purchaseRows = await db.query(
        'purchases',
        where: 'distributor_id = ? AND payment_method = ? AND timestamp >= ? AND timestamp <= ?',
        whereArgs: [partyId, 'Credit', startStr, endStr],
        orderBy: 'timestamp ASC',
      );

      for (final pMap in purchaseRows) {
        final purchaseId = pMap['id'] as int;
        final billNumber = pMap['bill_number'] as String? ?? 'PR-$purchaseId';
        final totalAmount = (pMap['total_amount'] as num?)?.toDouble() ?? 0.0;
        final purchaseDiscount = (pMap['discount'] as num?)?.toDouble() ?? 0.0;
        final timestamp = pMap['timestamp'] as String? ?? '';

        final List<Map<String, dynamic>> itemRows = await db.rawQuery('''
          SELECT pi.book_id, pi.quantity, pi.cost_price, b.price as book_price, b.title as book_title
          FROM purchase_items pi
          LEFT JOIN books b ON pi.book_id = b.id
          WHERE pi.purchase_id = ?
        ''', [purchaseId]);

        // Calculate subtotal of items to detect overall discount if not explicitly set in discount column
        final subtotal = itemRows.fold<double>(
          0.0,
          (sum, r) =>
              sum +
              ((r['quantity'] as int) *
                  ((r['cost_price'] as num?)?.toDouble() ?? 0.0)),
        );

        double effectiveBillDiscountPercent = purchaseDiscount;
        if (effectiveBillDiscountPercent <= 0 &&
            subtotal > totalAmount &&
            subtotal > 0) {
          effectiveBillDiscountPercent =
              ((subtotal - totalAmount) / subtotal) * 100;
        }

        int totalItemsInPurchase = 0;
        for (final row in itemRows) {
          final bookId = row['book_id'] as int;
          final bookTitle = row['book_title'] as String? ?? 'Book #$bookId';
          final qty = row['quantity'] as int;
          final costPrice = (row['cost_price'] as num?)?.toDouble() ?? 0.0;
          final bookPrice = (row['book_price'] as num?)?.toDouble() ?? 0.0;

          totalItemsInPurchase += qty;

          double unitPrice = bookPrice > 0 ? bookPrice : costPrice;
          double discountAmount = 0.0;
          double discountPercent = 0.0;

          if (bookPrice > 0 && costPrice < bookPrice && costPrice > 0) {
            // Per-item discount was applied when adding book
            discountAmount = bookPrice - costPrice;
            discountPercent = (discountAmount / bookPrice) * 100;

            // If overall bill discount also applied on top
            if (effectiveBillDiscountPercent > 0) {
              final additionalDiscount =
                  costPrice * (effectiveBillDiscountPercent / 100);
              discountAmount += additionalDiscount;
              discountPercent = (discountAmount / unitPrice) * 100;
            }
          } else if (effectiveBillDiscountPercent > 0) {
            // Overall purchase discount % applies to unitPrice
            discountPercent = effectiveBillDiscountPercent;
            discountAmount = unitPrice * (discountPercent / 100);
          } else if (bookPrice > 0 && costPrice > 0 && bookPrice > costPrice) {
            discountAmount = bookPrice - costPrice;
            discountPercent = (discountAmount / bookPrice) * 100;
          }

          final key =
              '${bookId}_${unitPrice.toStringAsFixed(2)}_${discountPercent.toStringAsFixed(2)}';

          if (itemMap.containsKey(key)) {
            itemMap[key]!.purchasedQty += qty;
          } else {
            itemMap[key] = _MutableSettlementItem(
              bookId: bookId,
              bookTitle: bookTitle,
              purchasedQty: qty,
              returnedQty: 0,
              unitPrice: unitPrice,
              discountPercent: discountPercent,
              discountAmount: discountAmount,
            );
          }
        }

        creditBills.add(SettlementTransactionSummary(
          billNumber: billNumber,
          date: timestamp,
          amount: totalAmount,
          itemCount: totalItemsInPurchase,
        ));
      }

      // 2. Fetch Distributor Purchase Returns in Date Range
      final List<Map<String, dynamic>> returnRows = await db.rawQuery('''
        SELECT pr.id, pr.bill_number, pr.total_refund, pr.timestamp
        FROM purchase_returns pr
        JOIN purchases p ON pr.purchase_id = p.id
        WHERE p.distributor_id = ? AND pr.timestamp >= ? AND pr.timestamp <= ?
        ORDER BY pr.timestamp ASC
      ''', [partyId, startStr, endStr]);

      for (final retMap in returnRows) {
        final retId = retMap['id'] as int;
        final billNumber = retMap['bill_number'] as String? ?? 'PRR-$retId';
        final totalRefund = (retMap['total_refund'] as num?)?.toDouble() ?? 0.0;
        final timestamp = retMap['timestamp'] as String? ?? '';

        final List<Map<String, dynamic>> retItems = await db.query(
          'purchase_return_items',
          where: 'return_id = ?',
          whereArgs: [retId],
        );

        int totalItemsInReturn = 0;
        for (final rRow in retItems) {
          final bookId = rRow['book_id'] as int;
          final qty = rRow['quantity'] as int;
          totalItemsInReturn += qty;
          returnsByBookId[bookId] = (returnsByBookId[bookId] ?? 0) + qty;
        }

        returnBills.add(SettlementTransactionSummary(
          billNumber: billNumber,
          date: timestamp,
          amount: totalRefund,
          itemCount: totalItemsInReturn,
        ));
      }
    }

    // 3. Reconcile returns into item rows
    // For each book that has returns, apply returned qty to the item entries
    for (final entry in returnsByBookId.entries) {
      final bookId = entry.key;
      var remainingReturn = entry.value;

      for (final item in itemMap.values) {
        if (item.bookId == bookId && remainingReturn > 0) {
          if (remainingReturn <= item.purchasedQty) {
            item.returnedQty += remainingReturn;
            remainingReturn = 0;
          } else {
            item.returnedQty += item.purchasedQty;
            remainingReturn -= item.purchasedQty;
          }
        }
      }

      // If return exceeds purchased quantity for known keys, allocate to the first item found for that book
      if (remainingReturn > 0) {
        final firstMatch = itemMap.values.where((i) => i.bookId == bookId).firstOrNull;
        if (firstMatch != null) {
          firstMatch.returnedQty += remainingReturn;
        }
      }
    }

    // 4. Convert mutable items to final immutable list
    final List<SettlementItem> finalItems = [];
    double grandTotal = 0.0;

    for (final item in itemMap.values) {
      final netQty = (item.purchasedQty - item.returnedQty).clamp(0, 999999);
      final finalAmount = netQty * (item.unitPrice - item.discountAmount);
      grandTotal += finalAmount;

      finalItems.add(SettlementItem(
        bookId: item.bookId,
        bookTitle: item.bookTitle,
        purchasedQty: item.purchasedQty,
        returnedQty: item.returnedQty,
        netQty: netQty,
        unitPrice: item.unitPrice,
        discountPercent: item.discountPercent,
        discountAmount: item.discountAmount,
        finalAmount: finalAmount,
      ));
    }

    // Sort items alphabetically by title
    finalItems.sort((a, b) => a.bookTitle.toLowerCase().compareTo(b.bookTitle.toLowerCase()));

    return SettlementReport(
      isSale: isSale,
      partyName: partyName,
      partyPhone: partyPhone,
      startDate: startDate,
      endDate: endDate,
      creditBills: creditBills,
      returnBills: returnBills,
      items: finalItems,
      grandTotal: grandTotal,
    );
  }

  /// Renders SettlementReceiptWidget to PNG bytes
  Future<Uint8List> renderReceiptToPng(
    SettlementReport report,
    Map<String, String> settings, {
    double pixelRatio = 2.0,
    double width = 545.0,
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
          child: SettlementReceiptWidget(
            report: report,
            settings: settings,
            width: width,
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

  /// Prints the settlement report to system printer in A4 format
  Future<void> printSettlementA4(
    SettlementReport report,
    Map<String, String> settings,
  ) async {
    const double renderWidth = 545.0;
    const double pixelRatio = 2.0;

    final pngBytes = await renderReceiptToPng(
      report,
      settings,
      width: renderWidth,
      pixelRatio: pixelRatio,
    );

    final decodedImage = img.decodePng(pngBytes);
    if (decodedImage == null) return;

    final int imgWidth = decodedImage.width;
    final int imgHeight = decodedImage.height;

    final double pageWidth = PdfPageFormat.a4.width;
    final double pageHeight = PdfPageFormat.a4.height;
    const double margin = 28.0;
    final double printableWidth = pageWidth - (margin * 2);
    final double printableHeight = pageHeight - (margin * 2);

    final double scale = printableWidth / imgWidth;
    final double scaledFullHeight = imgHeight * scale;

    final pdf = pw.Document();

    if (scaledFullHeight <= printableHeight) {
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
      final int maxRowsPerPage = (printableHeight / scale).floor();
      Set<int> blankRows = {};
      for (int y = 0; y < imgHeight; y++) {
        bool isBlank = true;
        for (int x = 0; x < imgWidth; x += 4) {
          final pixel = decodedImage.getPixel(x, y);
          if (pixel.r < 240 || pixel.g < 240 || pixel.b < 240) {
            isBlank = false;
            break;
          }
        }
        if (isBlank) blankRows.add(y);
      }

      int yOffset = 0;
      while (yOffset < imgHeight) {
        int idealEnd = yOffset + maxRowsPerPage;
        if (idealEnd >= imgHeight) {
          idealEnd = imgHeight;
        } else {
          int bestSplit = -1;
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
        }

        final int chunkHeight = idealEnd - yOffset;
        if (chunkHeight <= 0) break;

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

    final safePartyName = report.partyName.replaceAll(' ', '_');
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Settlement_${report.isSale ? 'Sale' : 'Purchase'}_$safePartyName',
    );
  }

  /// Formats settlement text and shares via WhatsApp
  Future<void> shareSettlementWhatsApp({
    required BuildContext context,
    required SettlementReport report,
    required Map<String, String> settings,
  }) async {
    try {
      final shopName = settings['shop_name'] ?? 'Book Store POS';
      final shopAddress = settings['shop_address'] ?? '';
      final shopNumber = settings['shop_number'] ?? '';
      final dateFormat = DateFormat('dd/MM/yyyy');

      final buffer = StringBuffer();
      buffer.writeln('*$shopName*');
      if (shopAddress.isNotEmpty) buffer.writeln(shopAddress);
      if (shopNumber.isNotEmpty) buffer.writeln('Tel: $shopNumber');
      buffer.writeln('--------------------------------');
      buffer.writeln('*SALE OR RETURN SETTLEMENT REPORT*');
      buffer.writeln('${report.isSale ? 'Customer' : 'Distributor'}: *${report.partyName}*');
      if (report.partyPhone.isNotEmpty) buffer.writeln('Phone: ${report.partyPhone}');
      buffer.writeln('Period: ${dateFormat.format(report.startDate)} to ${dateFormat.format(report.endDate)}');
      buffer.writeln('Bills: ${report.creditBills.length}  |  Returns: ${report.returnBills.length}');
      buffer.writeln('--------------------------------');

      int totalPurchased = 0;
      int totalReturned = 0;
      int totalNet = 0;

      for (int i = 0; i < report.items.length; i++) {
        final item = report.items[i];
        totalPurchased += item.purchasedQty;
        totalReturned += item.returnedQty;
        totalNet += item.netQty;

        final discountText = item.discountPercent > 0
            ? '${item.discountPercent.toStringAsFixed(0)}%'
            : '₹${item.discountAmount.toStringAsFixed(0)}';

        buffer.writeln('${i + 1}. *${item.bookTitle}*');
        buffer.writeln(
          '   Taken: ${item.purchasedQty} | Ret: ${item.returnedQty} | *Net: ${item.netQty}*',
        );
        buffer.writeln(
          '   ₹${item.unitPrice.toStringAsFixed(2)} - Disc: $discountText = *₹${item.finalAmount.toStringAsFixed(2)}*',
        );
      }

      buffer.writeln('--------------------------------');
      buffer.writeln('Total Taken: $totalPurchased');
      buffer.writeln('Total Returned: $totalReturned');
      buffer.writeln('Total Net Qty: $totalNet');
      buffer.writeln('--------------------------------');
      buffer.writeln('*TOTAL AMOUNT YET TO PAY:*');
      buffer.writeln('*₹${report.grandTotal.toStringAsFixed(2)}*');
      buffer.writeln('--------------------------------');
      buffer.writeln('Generated on ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now())}');
      buffer.writeln('_Powered By ALQA Tech_');

      String phone = report.partyPhone.replaceAll(RegExp(r'[^\d]'), '');
      if (phone.length == 10) {
        phone = '91$phone';
      }

      final message = Uri.encodeComponent(buffer.toString());

      Uri appUrl;
      Uri webUrl;

      if (phone.isNotEmpty) {
        appUrl = Uri.parse('whatsapp://send?phone=$phone&text=$message');
        webUrl = Uri.parse('https://wa.me/$phone?text=$message');
      } else {
        appUrl = Uri.parse('whatsapp://send?text=$message');
        webUrl = Uri.parse('https://wa.me/?text=$message');
      }

      try {
        if (!await launchUrl(appUrl, mode: LaunchMode.externalApplication)) {
          throw 'Could not launch app';
        }
      } catch (e) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing on WhatsApp: $e')),
        );
      }
    }
  }
}

class _MutableSettlementItem {
  final int bookId;
  final String bookTitle;
  int purchasedQty;
  int returnedQty;
  final double unitPrice;
  final double discountPercent;
  final double discountAmount;

  _MutableSettlementItem({
    required this.bookId,
    required this.bookTitle,
    required this.purchasedQty,
    required this.returnedQty,
    required this.unitPrice,
    required this.discountPercent,
    required this.discountAmount,
  });
}
