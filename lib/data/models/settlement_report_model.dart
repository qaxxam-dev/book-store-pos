class SettlementItem {
  final int bookId;
  final String bookTitle;
  final int purchasedQty;
  final int returnedQty;
  final int netQty;
  final double unitPrice;
  final double discountPercent;
  final double discountAmount;
  final double finalAmount;

  SettlementItem({
    required this.bookId,
    required this.bookTitle,
    required this.purchasedQty,
    required this.returnedQty,
    required this.netQty,
    required this.unitPrice,
    required this.discountPercent,
    required this.discountAmount,
    required this.finalAmount,
  });
}

class SettlementTransactionSummary {
  final String billNumber;
  final String date;
  final double amount;
  final int itemCount;

  SettlementTransactionSummary({
    required this.billNumber,
    required this.date,
    required this.amount,
    required this.itemCount,
  });
}

class SettlementReport {
  final bool isSale; // true for Sales (Customer), false for Purchase (Distributor)
  final String partyName;
  final String partyPhone;
  final DateTime startDate;
  final DateTime endDate;
  final List<SettlementTransactionSummary> creditBills;
  final List<SettlementTransactionSummary> returnBills;
  final List<SettlementItem> items;
  final double grandTotal;

  SettlementReport({
    required this.isSale,
    required this.partyName,
    required this.partyPhone,
    required this.startDate,
    required this.endDate,
    required this.creditBills,
    required this.returnBills,
    required this.items,
    required this.grandTotal,
  });
}
