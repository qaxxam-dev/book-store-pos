import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/models/settlement_report_model.dart';

class SettlementReceiptWidget extends StatelessWidget {
  final SettlementReport report;
  final Map<String, String> settings;
  final double width;

  const SettlementReceiptWidget({
    super.key,
    required this.report,
    required this.settings,
    this.width = 545.0, // Printable A4 width in PDF points
  });

  @override
  Widget build(BuildContext context) {
    final shopName = settings['shop_name'] ?? 'Book Store POS';
    final shopAddress = settings['shop_address'] ?? '';
    final shopNumber = settings['shop_number'] ?? '';
    final dateFormat = DateFormat('dd/MM/yyyy');

    final baseStyle = GoogleFonts.notoSansTamil(
      color: Colors.black,
      fontSize: 10,
      height: 1.2,
    );

    final boldStyle = GoogleFonts.notoSansTamil(
      color: Colors.black,
      fontSize: 10,
      fontWeight: FontWeight.bold,
      height: 1.2,
    );

    final headerStyle = GoogleFonts.notoSansTamil(
      color: Colors.black,
      fontSize: 14,
      fontWeight: FontWeight.bold,
      height: 1.2,
    );

    final titleStyle = GoogleFonts.notoSansTamil(
      color: Colors.black,
      fontSize: 16,
      fontWeight: FontWeight.bold,
      height: 1.2,
    );

    final totalPurchasedQty =
        report.items.fold<int>(0, (sum, i) => sum + i.purchasedQty);
    final totalReturnedQty =
        report.items.fold<int>(0, (sum, i) => sum + i.returnedQty);
    final totalNetQty = report.items.fold<int>(0, (sum, i) => sum + i.netQty);

    return Container(
      width: width,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Shop Header
          Center(
            child: Text(
              shopName,
              style: titleStyle,
              textAlign: TextAlign.center,
            ),
          ),
          if (shopAddress.isNotEmpty) ...[
            const SizedBox(height: 2),
            Center(
              child: Text(
                shopAddress,
                style: baseStyle,
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (shopNumber.isNotEmpty) ...[
            const SizedBox(height: 2),
            Center(
              child: Text(
                'Phone: $shopNumber',
                style: baseStyle,
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Divider(thickness: 1.5, color: Colors.black87),

          // Title
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'SALE OR RETURN SETTLEMENT REPORT',
                style: headerStyle.copyWith(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Party & Exhibition Info Box
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black45, width: 0.8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${report.isSale ? 'Customer' : 'Distributor'}: ${report.partyName}',
                        style: boldStyle,
                      ),
                      if (report.partyPhone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Phone: ${report.partyPhone}', style: baseStyle),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        'Type: ${report.isSale ? 'Sales & Returns' : 'Purchases & Returns'}',
                        style: baseStyle,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Period: ${dateFormat.format(report.startDate)} to ${dateFormat.format(report.endDate)}',
                        style: boldStyle,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Credit Bills: ${report.creditBills.length}  |  Returns: ${report.returnBills.length}',
                        style: baseStyle,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Date: ${dateFormat.format(DateTime.now())}',
                        style: baseStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F0F0),
              border: Border(
                top: BorderSide(color: Colors.black, width: 1),
                bottom: BorderSide(color: Colors.black, width: 1),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                    width: 24,
                    child: Text('#',
                        style: boldStyle.copyWith(fontSize: 9),
                        textAlign: TextAlign.center)),
                Expanded(
                    flex: 5,
                    child: Text('Item',
                        style: boldStyle.copyWith(fontSize: 9))),
                SizedBox(
                    width: 44,
                    child: Text('Purchased',
                        style: boldStyle.copyWith(fontSize: 9),
                        textAlign: TextAlign.right)),
                SizedBox(
                    width: 42,
                    child: Text('Returned',
                        style: boldStyle.copyWith(fontSize: 9),
                        textAlign: TextAlign.right)),
                SizedBox(
                    width: 38,
                    child: Text('Net Qty',
                        style: boldStyle.copyWith(fontSize: 9),
                        textAlign: TextAlign.right)),
                SizedBox(
                    width: 45,
                    child: Text('Price',
                        style: boldStyle.copyWith(fontSize: 9),
                        textAlign: TextAlign.right)),
                SizedBox(
                    width: 45,
                    child: Text('Discount',
                        style: boldStyle.copyWith(fontSize: 9),
                        textAlign: TextAlign.right)),
                SizedBox(
                    width: 58,
                    child: Text('Final Amt',
                        style: boldStyle.copyWith(fontSize: 9),
                        textAlign: TextAlign.right)),
              ],
            ),
          ),

          // Table Rows
          ...report.items.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final item = entry.value;
            final discountText = item.discountPercent > 0
                ? '${item.discountPercent.toStringAsFixed(0)}%'
                : '₹${item.discountAmount.toStringAsFixed(0)}';

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade300,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '$idx',
                      style: baseStyle.copyWith(fontSize: 8.5),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      item.bookTitle,
                      style: baseStyle.copyWith(fontSize: 8.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${item.purchasedQty}',
                      style: baseStyle.copyWith(fontSize: 8.5),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 42,
                    child: Text(
                      '${item.returnedQty}',
                      style: baseStyle.copyWith(
                        fontSize: 8.5,
                        color: item.returnedQty > 0
                            ? Colors.red.shade900
                            : Colors.black,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 38,
                    child: Text(
                      '${item.netQty}',
                      style: boldStyle.copyWith(fontSize: 8.5),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 45,
                    child: Text(
                      '₹${item.unitPrice.toStringAsFixed(2)}',
                      style: baseStyle.copyWith(fontSize: 8.5),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 45,
                    child: Text(
                      discountText,
                      style: baseStyle.copyWith(fontSize: 8.5),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 58,
                    child: Text(
                      '₹${item.finalAmount.toStringAsFixed(2)}',
                      style: boldStyle.copyWith(fontSize: 8.5),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),

          // Table Total Row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              border: Border(
                top: BorderSide(color: Colors.black87, width: 1),
                bottom: BorderSide(color: Colors.black87, width: 1),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 24),
                Expanded(
                  flex: 5,
                  child: Text('Total', style: boldStyle.copyWith(fontSize: 9)),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '$totalPurchasedQty',
                    style: boldStyle.copyWith(fontSize: 9),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    '$totalReturnedQty',
                    style: boldStyle.copyWith(fontSize: 9),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 38,
                  child: Text(
                    '$totalNetQty',
                    style: boldStyle.copyWith(fontSize: 9),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 90), // Price + Discount
                SizedBox(
                  width: 58,
                  child: Text(
                    '₹${report.grandTotal.toStringAsFixed(2)}',
                    style: boldStyle.copyWith(fontSize: 9),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Total Yet to Pay Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1.5),
              borderRadius: BorderRadius.circular(4),
              color: const Color(0xFFF7F7F7),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL AMOUNT YET TO PAY:',
                  style: headerStyle.copyWith(fontSize: 12),
                ),
                Text(
                  '₹${report.grandTotal.toStringAsFixed(2)}',
                  style: headerStyle.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Signatures
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 140,
                    height: 1,
                    color: Colors.black54,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stall Keeper / Receiver',
                    style: baseStyle.copyWith(fontSize: 9),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 140,
                    height: 1,
                    color: Colors.black54,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Authorized Signature',
                    style: baseStyle.copyWith(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Generated on ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now())} • Powered By ALQA Tech',
              style: baseStyle.copyWith(fontSize: 7.5, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}
