import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../data/models/book.dart';
import '../../data/models/sale.dart';
import '../../data/models/customer.dart';
import '../../data/models/sales_return.dart';
import '../../data/models/purchase.dart';
import '../../data/models/purchase_return.dart';
import '../../data/models/distributor.dart';
import '../../data/models/sale_item.dart';
import '../../data/models/sales_return_item.dart';
import '../../data/models/purchase_item.dart';
import '../../data/models/purchase_return_item.dart';
import '../../data/models/customer_payment.dart';
import '../../data/models/distributor_payment.dart';

class ExcelService {
  Future<void> exportData({
    required List<Book> books,
    required List<Sale> sales,
    required List<SalesReturn> salesReturns,
    required List<Purchase> purchases,
    required List<PurchaseReturn> purchaseReturns,
    required List<Customer> customers,
    required List<Distributor> distributors,
    required Map<int, List<SaleItem>> saleItems,
    required Map<int, List<SalesReturnItem>> salesReturnItems,
    required Map<int, List<PurchaseItem>> purchaseItems,
    required Map<int, List<PurchaseReturnItem>> purchaseReturnItems,
    required List<CustomerPayment> customerPayments,
    required List<DistributorPayment> distributorPayments,
  }) async {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Books');

    // 1. Books Sheet
    final Sheet bookSheet = excel['Books'];
    bookSheet.appendRow([
      TextCellValue('Title'),
      TextCellValue('Author'),
      TextCellValue('Publisher'),
      TextCellValue('Category'),
      TextCellValue('SKU'),
      TextCellValue('Price'),
      TextCellValue('Stock'),
    ]);
    for (var book in books) {
      bookSheet.appendRow([
        TextCellValue(book.title),
        TextCellValue(book.author ?? ''),
        TextCellValue(book.publisher ?? ''),
        TextCellValue(book.category ?? ''),
        TextCellValue(book.sku),
        DoubleCellValue(book.price),
        IntCellValue(book.stockQuantity),
      ]);
    }

    // 2. Sales Sheet
    final Sheet saleSheet = excel['Sales'];
    saleSheet.appendRow([
      TextCellValue('Bill Number'),
      TextCellValue('Date'),
      TextCellValue('Customer Name'),
      TextCellValue('Total Amount'),
      TextCellValue('Payment Method'),
      TextCellValue('Items (Book: Qty)'),
    ]);

    // Helper to get book title
    String getBookTitle(int bookId) {
      return books
          .firstWhere((b) => b.id == bookId,
              orElse: () =>
                  Book(title: 'Unknown', sku: '', price: 0, stockQuantity: 0))
          .title;
    }

    // Helper to get customer name
    String getCustomerName(int? customerId, String? guestPhone) {
      if (customerId != null) {
        final customer = customers.firstWhere((c) => c.id == customerId,
            orElse: () => Customer(name: 'Unknown', phone: ''));
        return customer.name;
      }
      return 'Guest (${guestPhone ?? "N/A"})';
    }

    for (var sale in sales) {
      final items = saleItems[sale.id] ?? [];
      final itemsString = items
          .map((i) => '${getBookTitle(i.bookId)}: ${i.quantity}')
          .join(', ');

      saleSheet.appendRow([
        TextCellValue(sale.billNumber),
        TextCellValue(DateFormat('yyyy-MM-dd HH:mm')
            .format(DateTime.parse(sale.timestamp))),
        TextCellValue(getCustomerName(sale.customerId, sale.guestPhone)),
        DoubleCellValue(sale.totalAmount),
        TextCellValue(sale.paymentMethod),
        TextCellValue(itemsString),
      ]);
    }

    // 3. Sales Return Sheet
    final Sheet salesReturnSheet = excel['Sales Returns'];
    salesReturnSheet.appendRow([
      TextCellValue('Bill Number'),
      TextCellValue('Original Bill'),
      TextCellValue('Date'),
      TextCellValue('Customer Name'),
      TextCellValue('Total Refund'),
      TextCellValue('Items (Book: Qty)'),
    ]);

    for (var ret in salesReturns) {
      final sale = sales.firstWhere((s) => s.id == ret.saleId,
          orElse: () => Sale(
              totalAmount: 0,
              paymentMethod: '',
              timestamp: '',
              billNumber: 'Unknown'));
      final items = salesReturnItems[ret.id] ?? [];
      final itemsString = items
          .map((i) => '${getBookTitle(i.bookId)}: ${i.quantity}')
          .join(', ');

      salesReturnSheet.appendRow([
        TextCellValue(ret.billNumber),
        TextCellValue(sale.billNumber),
        TextCellValue(DateFormat('yyyy-MM-dd HH:mm')
            .format(DateTime.parse(ret.timestamp))),
        TextCellValue(getCustomerName(sale.customerId, sale.guestPhone)),
        DoubleCellValue(ret.totalRefund),
        TextCellValue(itemsString),
      ]);
    }

    // 4. Purchase Sheet
    final Sheet purchaseSheet = excel['Purchases'];
    purchaseSheet.appendRow([
      TextCellValue('Bill Number'),
      TextCellValue('Date'),
      TextCellValue('Distributor'),
      TextCellValue('Total Amount'),
      TextCellValue('Payment Method'),
      TextCellValue('Items (Book: Qty)'),
    ]);

    // Helper to get distributor name
    String getDistributorName(int distributorId) {
      final dist = distributors.firstWhere((d) => d.id == distributorId,
          orElse: () => Distributor(name: 'Unknown', phone: ''));
      return dist.name;
    }

    for (var purchase in purchases) {
      final items = purchaseItems[purchase.id] ?? [];
      final itemsString = items
          .map((i) => '${getBookTitle(i.bookId)}: ${i.quantity}')
          .join(', ');

      purchaseSheet.appendRow([
        TextCellValue(purchase.billNumber),
        TextCellValue(DateFormat('yyyy-MM-dd HH:mm')
            .format(DateTime.parse(purchase.timestamp))),
        TextCellValue(getDistributorName(purchase.distributorId)),
        DoubleCellValue(purchase.totalAmount),
        TextCellValue(purchase.paymentMethod),
        TextCellValue(itemsString),
      ]);
    }

    // 5. Purchase Return Sheet
    final Sheet purchaseReturnSheet = excel['Purchase Returns'];
    purchaseReturnSheet.appendRow([
      TextCellValue('Bill Number'),
      TextCellValue('Original Bill'),
      TextCellValue('Date'),
      TextCellValue('Distributor'),
      TextCellValue('Total Refund'),
      TextCellValue('Items (Book: Qty)'),
    ]);

    for (var ret in purchaseReturns) {
      final purchase = purchases.firstWhere((p) => p.id == ret.purchaseId,
          orElse: () => Purchase(
              distributorId: 0,
              billNumber: 'Unknown',
              totalAmount: 0,
              paymentMethod: '',
              timestamp: ''));
      final items = purchaseReturnItems[ret.id] ?? [];
      final itemsString = items
          .map((i) => '${getBookTitle(i.bookId)}: ${i.quantity}')
          .join(', ');

      purchaseReturnSheet.appendRow([
        TextCellValue(ret.billNumber),
        TextCellValue(purchase.billNumber),
        TextCellValue(DateFormat('yyyy-MM-dd HH:mm')
            .format(DateTime.parse(ret.timestamp))),
        TextCellValue(purchase.distributorId != 0
            ? getDistributorName(purchase.distributorId)
            : 'Unknown'),
        DoubleCellValue(ret.totalRefund),
        TextCellValue(itemsString),
      ]);
    }

    // 6. Customers Sheet
    final Sheet customerSheet = excel['Customers'];
    customerSheet.appendRow([
      TextCellValue('Name'),
      TextCellValue('Phone'),
      TextCellValue('Balance'),
      TextCellValue('Total Books Sold'),
    ]);

    for (var customer in customers) {
      // Calculate Total Books Sold
      int totalSold = 0;
      int totalReturned = 0;

      // Get all sales for this customer
      final customerSales = sales.where((s) => s.customerId == customer.id);
      for (var sale in customerSales) {
        final items = saleItems[sale.id] ?? [];
        for (var item in items) {
          totalSold += item.quantity;
        }

        // Get returns for this sale
        final returns = salesReturns.where((r) => r.saleId == sale.id);
        for (var ret in returns) {
          final retItems = salesReturnItems[ret.id] ?? [];
          for (var item in retItems) {
            totalReturned += item.quantity;
          }
        }
      }

      customerSheet.appendRow([
        TextCellValue(customer.name),
        TextCellValue(customer.phone),
        DoubleCellValue(customer.balance),
        IntCellValue(totalSold - totalReturned),
      ]);
    }

    // 7. Distributors Sheet
    final Sheet distributorSheet = excel['Distributors'];
    distributorSheet.appendRow([
      TextCellValue('Name'),
      TextCellValue('Phone'),
      TextCellValue('Balance'),
      TextCellValue('Total Books Purchased'),
    ]);

    for (var distributor in distributors) {
      // Calculate Total Books Purchased
      int totalPurchased = 0;
      int totalReturned = 0;

      // Get all purchases for this distributor
      final distPurchases =
          purchases.where((p) => p.distributorId == distributor.id);
      for (var purchase in distPurchases) {
        final items = purchaseItems[purchase.id] ?? [];
        for (var item in items) {
          totalPurchased += item.quantity;
        }

        // Get returns for this purchase
        final returns =
            purchaseReturns.where((r) => r.purchaseId == purchase.id);
        for (var ret in returns) {
          final retItems = purchaseReturnItems[ret.id] ?? [];
          for (var item in retItems) {
            totalReturned += item.quantity;
          }
        }
      }

      distributorSheet.appendRow([
        TextCellValue(distributor.name),
        TextCellValue(distributor.phone),
        DoubleCellValue(distributor.balance),
        IntCellValue(totalPurchased - totalReturned),
      ]);
    }

    // 8. Customer Payments Sheet
    final Sheet customerPaymentSheet = excel['Customer Payments'];
    customerPaymentSheet.appendRow([
      TextCellValue('Customer Name'),
      TextCellValue('Amount'),
      TextCellValue('Payment Date'),
      TextCellValue('Payment Mode'),
      TextCellValue('Notes'),
    ]);

    for (var payment in customerPayments) {
      final customer = customers.firstWhere((c) => c.id == payment.customerId,
          orElse: () => Customer(name: 'Unknown', phone: ''));

      customerPaymentSheet.appendRow([
        TextCellValue(customer.name),
        DoubleCellValue(payment.amount),
        TextCellValue(DateFormat('yyyy-MM-dd HH:mm')
            .format(DateTime.parse(payment.paymentDate))),
        TextCellValue(payment.paymentMode),
        TextCellValue(payment.notes ?? ''),
      ]);
    }

    // 9. Distributor Payments Sheet
    final Sheet distributorPaymentSheet = excel['Distributor Payments'];
    distributorPaymentSheet.appendRow([
      TextCellValue('Distributor Name'),
      TextCellValue('Amount'),
      TextCellValue('Payment Date'),
      TextCellValue('Payment Mode'),
      TextCellValue('Notes'),
    ]);

    for (var payment in distributorPayments) {
      final distributor = distributors.firstWhere(
          (d) => d.id == payment.distributorId,
          orElse: () => Distributor(name: 'Unknown', phone: ''));

      distributorPaymentSheet.appendRow([
        TextCellValue(distributor.name),
        DoubleCellValue(payment.amount),
        TextCellValue(DateFormat('yyyy-MM-dd HH:mm')
            .format(DateTime.parse(payment.paymentDate))),
        TextCellValue(payment.paymentMode),
        TextCellValue(payment.notes ?? ''),
      ]);
    }

    // Save and Share
    final fileBytes = excel.save();
    if (fileBytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'BookShop_Data_${DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now())}.xlsx';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(fileBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Book Shop Data Export',
      );
    }
  }

  Future<List<List<dynamic>>> readExcelFile(File file) async {
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    if (excel.tables.isEmpty) return [];

    // Assume first table
    final table = excel.tables.values.first;
    final rows = <List<dynamic>>[];

    for (var row in table.rows) {
      final rowData = row.map((e) => e?.value).toList();
      rows.add(rowData);
    }

    return rows;
  }
}
