import 'package:flutter/material.dart';
import '../../data/models/receipt_model.dart';
import 'package:google_fonts/google_fonts.dart';

class ReceiptWidget extends StatelessWidget {
  final ReceiptModel data;
  final double width;
  final bool isThermal;

  const ReceiptWidget({
    super.key,
    required this.data,
    this.width = 380,
    this.isThermal = false,
  });

  @override
  Widget build(BuildContext context) {
    // scale fonts for thermal
    // scale fonts for thermal
    // 304dpi is high density, so we need large logical font sizes.
    // logical 22 * 1.5 ratio = 33 physical dots height (~2.7mm)
    final double baseSize = isThermal ? 22 : 12;
    final double smallSize = isThermal ? 18 : 10;
    final double headerSize = isThermal ? 32 : 18; // Increased for Total Amount
    final double shopNameSize = isThermal ? 42 : 24; // Increased Shop Name
    final double thankYouSize = isThermal ? 24 : 14; // Increased Thank You
    final double poweredBySize = isThermal ? 16 : 10; // Increased Powered By

    // Determine title based on type
    String title = 'RECEIPT';
    switch (data.type) {
      case ReceiptType.sale:
        title = 'SALES RECEIPT';
        break;
      case ReceiptType.saleReturn:
        title = 'SALES RETURN RECEIPT';
        break;
      case ReceiptType.purchase:
        title = 'PURCHASE RECEIPT';
        break;
      case ReceiptType.purchaseReturn:
        title = 'PURCHASE RETURN RECEIPT';
        break;
    }

    final style = GoogleFonts.notoSansTamil(
      color: Colors.black,
      fontSize: baseSize,
      fontWeight: FontWeight.normal, // Explicitly remove bold
      height: 1.2,
    );
    final boldStyle = GoogleFonts.notoSansTamil(
      color: Colors.black,
      fontSize: baseSize,
      fontWeight: FontWeight.bold,
      height: 1.2,
    );
    final headerStyle = GoogleFonts.notoSansTamil(
      color: Colors.black,
      fontSize: headerSize,
      fontWeight: FontWeight.bold,
      height: 1.2,
    );
    final shopNameStyle = GoogleFonts.notoSansTamil(
      color: Colors.black,
      fontSize: shopNameSize,
      fontWeight: FontWeight.bold,
      height: 1.2,
    );
    final smallStyle = GoogleFonts.notoSansTamil(
      color: Colors.black,
      fontSize: smallSize,
      height: 1.2,
    );
    final thankYouStyle = GoogleFonts.notoSansTamil(
      color: Colors.black,
      fontSize: thankYouSize,
      height: 1.2,
    );

    return Container(
      width: width,
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          16, 14, 16, isThermal ? 0 : 14), // Reduced vertical spacing by ~40%
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Shop Header
          Text(data.shopName,
              style: shopNameStyle, textAlign: TextAlign.center),
          if (data.shopAddress.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(data.shopAddress,
                style: smallStyle, textAlign: TextAlign.center),
          ],
          if (data.shopPhone.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Phone: ${data.shopPhone}',
                style: smallStyle, textAlign: TextAlign.center),
          ],

          const SizedBox(height: 8),
          const Divider(color: Colors.black),
          const SizedBox(height: 8),

          Text(title, style: boldStyle, textAlign: TextAlign.center),

          const SizedBox(height: 8),

          // Meta Data
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Date: ${data.date}', style: smallStyle),
              Text(data.time, style: smallStyle),
            ],
          ),
          Text('Bill No: ${data.billNumber}', style: smallStyle),
          if (data.originalBillNumber != null)
            Text('Orig Bill: ${data.originalBillNumber}', style: smallStyle),

          const SizedBox(height: 4),
          if (data.partyName.isNotEmpty && data.partyName != 'Unknown')
            Text('Party: ${data.partyName}', style: smallStyle),
          if (data.partyPhone != null && data.partyPhone!.isNotEmpty)
            Text('Phone: ${data.partyPhone}', style: smallStyle),
          if (data.partyBalance != null)
            Text('Balance: ${data.partyBalance!.toStringAsFixed(2)}',
                style: smallStyle),

          Text('Payment: ${data.paymentMethod}', style: smallStyle),

          const SizedBox(height: 8),
          const Divider(color: Colors.black),

          // Items Header
          Row(
            children: [
              Expanded(flex: 4, child: Text('Item', style: boldStyle)),
              Expanded(
                  flex: 1,
                  child: Text('Qty',
                      style: boldStyle, textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text(data.isReturn ? 'Ref' : 'Price',
                      style: boldStyle, textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text('Total',
                      style: boldStyle, textAlign: TextAlign.right)),
            ],
          ),
          const Divider(color: Colors.black54),

          // Items List
          ...data.items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: Text(item.title, style: style)),
                  Expanded(
                      flex: 1,
                      child: Text(item.quantity.toStringAsFixed(0),
                          style: style, textAlign: TextAlign.right)),
                  Expanded(
                      flex: 2,
                      child: Text(item.price.toStringAsFixed(2),
                          style: style, textAlign: TextAlign.right)),
                  Expanded(
                      flex: 2,
                      child: Text(item.total.toStringAsFixed(2),
                          style: style, textAlign: TextAlign.right)),
                ],
              ),
            );
          }),

          const Divider(color: Colors.black),
          const SizedBox(height: 4),

          // Totals
          if (data.discount > 0 || data.shippingAmount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Subtotal:', style: style),
                Text('₹${data.subtotal.toStringAsFixed(2)}', style: style),
              ],
            ),
            if (data.discount > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      'Discount (${data.discountPercent.toStringAsFixed(1)}%):',
                      style: style),
                  Text('-₹${data.discount.toStringAsFixed(2)}', style: style),
                ],
              ),
            if (data.shippingAmount > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Shipping:', style: style),
                  Text('+₹${data.shippingAmount.toStringAsFixed(2)}',
                      style: style),
                ],
              ),
            const Divider(color: Colors.black54),
          ],

          // Total Quantity
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Quantity:', style: style),
              Text(
                  data.items
                      .fold(0.0, (sum, item) => sum + item.quantity)
                      .toStringAsFixed(0),
                  style: style),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Amount:', style: headerStyle),
              Text('₹${data.totalAmount.toStringAsFixed(2)}',
                  style: headerStyle),
            ],
          ),

          const SizedBox(height: 16),
          const SizedBox(height: 16),
          Text(data.thankYouMessage,
              style: thankYouStyle, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Powered By ALQA Tech',
              style: GoogleFonts.notoSansTamil(
                  color: Colors.grey.shade700, fontSize: poweredBySize),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
