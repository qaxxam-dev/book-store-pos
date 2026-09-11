import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ShippingSlipWidget extends StatelessWidget {
  final String shopName;
  final String shopAddress;
  final String shopPhone;
  final String billNumber;
  final String date;
  final String time;
  final String customerName;
  final String customerMobile;
  final String customerAddress;
  final double width;
  final bool isThermal;

  const ShippingSlipWidget({
    super.key,
    required this.shopName,
    required this.shopAddress,
    required this.shopPhone,
    required this.billNumber,
    required this.date,
    required this.time,
    required this.customerName,
    required this.customerMobile,
    required this.customerAddress,
    this.width = 380,
    this.isThermal = false,
  });

  @override
  Widget build(BuildContext context) {
    final double baseSize = isThermal ? 14 : 10;
    final double headerSize = isThermal ? 20 : 16;
    final double shopNameSize = isThermal ? 26 : 20;
    final double poweredBySize = isThermal ? 12 : 9;

    final style = GoogleFonts.notoSansTamil(
      color: Colors.black,
      fontSize: baseSize,
      fontWeight: FontWeight.normal,
      height: 1.2,
    );
    final boldStyle = GoogleFonts.notoSansTamil(
      color: Colors.black,
      fontSize: baseSize * 1.2, // Slightly larger for address
      fontWeight: FontWeight.bold,
      height: 1.3,
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
    final addressStyle = GoogleFonts.notoSansTamil(
      color: Colors.black,
      fontSize: baseSize * 1.2, // Slightly larger for address
      fontWeight: FontWeight.bold,
      height: 1.3,
    );

    return Container(
      width: width,
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16, 14, 16, isThermal ? 0 : 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Customer Details
          Text(customerName, style: boldStyle),
          Text('Mobile: $customerMobile', style: style),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(customerAddress, style: addressStyle),
          ),
        ],
      ),
    );
  }
}
