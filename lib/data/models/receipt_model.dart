enum ReceiptType { sale, saleReturn, purchase, purchaseReturn }

class ReceiptItem {
  final String title;
  final double quantity;
  final double price; // Unit price
  final double total;

  ReceiptItem({
    required this.title,
    required this.quantity,
    required this.price,
    required this.total,
  });
}

class ReceiptModel {
  final ReceiptType type;
  final String shopName;
  final String shopAddress;
  final String shopPhone;
  final String thankYouMessage;

  final String billNumber;
  final String? originalBillNumber; // For returns
  final String date;
  final String time;

  final String partyName; // Customer or Distributor Name
  final String? partyPhone;
  final double? partyBalance; // Optional

  final String paymentMethod;
  final List<ReceiptItem> items;

  final double subtotal;
  final double discount;
  final double discountPercent;
  final double totalAmount;
  final double shippingAmount;

  final bool isReturn;

  ReceiptModel({
    required this.type,
    required this.shopName,
    required this.shopAddress,
    required this.shopPhone,
    required this.thankYouMessage,
    required this.billNumber,
    this.originalBillNumber,
    required this.date,
    required this.time,
    required this.partyName,
    this.partyPhone,
    this.partyBalance,
    required this.paymentMethod,
    required this.items,
    required this.subtotal,
    this.discount = 0.0,
    this.discountPercent = 0.0,
    required this.totalAmount,
    this.shippingAmount = 0.0,
    this.isReturn = false,
  });
}
