import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/distributor_repository.dart';

class ShareService {
  static Future<void> shareOnWhatsApp({
    required BuildContext context,
    required Sale sale,
    required List<SaleItem> items,
    required List<Book> books,
    required Customer? customer,
    required Map<String, String> settings,
  }) async {
    try {
      // Fetch fresh customer data if available
      if (customer != null) {
        final freshCustomer =
            await CustomerRepository().getCustomerById(customer.id!);
        if (freshCustomer != null) {
          customer = freshCustomer;
        }
      }

      final receiptText = generateWhatsAppReceipt(
        sale,
        items,
        books,
        customer,
        settings['shop_name'] ?? 'Book Shop',
        settings['shop_address'],
        settings['shop_number'],
        settings['thank_you_message'] ?? 'Thank you for your purchase!',
      );

      String phone = '';
      if (customer != null) {
        phone = customer.phone;
      } else if (sale.guestPhone != null) {
        phone = sale.guestPhone!;
      }

      if (phone.isNotEmpty) {
        // 1. Sanitize (Remove all non-digits)
        phone = phone.replaceAll(RegExp(r'[^\d]'), '');

        // 2. Handle Country Code (Assumes India +91)
        if (phone.length == 10) {
          phone = '91$phone';
        }

        final message = Uri.encodeComponent(receiptText);

        // 3. Define URLs
        final appUrl = Uri.parse('whatsapp://send?phone=$phone&text=$message');
        final webUrl = Uri.parse('https://wa.me/$phone?text=$message');

        try {
          // 4. Try launching App directly first
          if (!await launchUrl(appUrl, mode: LaunchMode.externalApplication)) {
            throw 'Could not launch app';
          }
        } catch (e) {
          // 5. Fallback to Web/Browser link
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No phone number available for this sale')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
    }
  }

  static String generateWhatsAppReceipt(
    Sale sale,
    List<SaleItem> items,
    List<Book> books,
    Customer? customer,
    String? shopName,
    String? shopAddress,
    String? shopNumber,
    String? thankYouMsg,
  ) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('*$shopName*');
    if (shopAddress != null && shopAddress.isNotEmpty) {
      buffer.writeln(shopAddress);
    }
    if (shopNumber != null && shopNumber.isNotEmpty) {
      buffer.writeln('Tel: $shopNumber');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('Date: ${sale.timestamp.toString().split('.')[0]}');
    buffer.writeln('Bill No: *${sale.billNumber}*');

    // Customer Details
    if (sale.paymentMethod == 'Complementary') {
      if (sale.customerName != null && sale.customerName!.isNotEmpty) {
        buffer.writeln('Given To: ${sale.customerName}');
      }
      if (sale.customerAddress != null && sale.customerAddress!.isNotEmpty) {
        buffer.writeln('Remarks: ${sale.customerAddress}');
      }
    } else if (customer != null) {
      buffer.writeln('Customer: ${customer.name}');
      buffer.writeln('Phone: ${customer.phone}');
      buffer.writeln('Balance: ${customer.balance.toStringAsFixed(2)}');
    } else if (sale.guestPhone != null && sale.guestPhone!.isNotEmpty) {
      buffer.writeln('Guest Phone: ${sale.guestPhone}');
    }

    buffer.writeln('Payment: ${sale.paymentMethod}');
    buffer.writeln('--------------------------------');

    // Items (Vertical List)
    buffer.write(generateVerticalList(items, books));
    buffer.writeln('--------------------------------');

    // Totals
    final subtotal = sale.totalAmount + sale.discount;
    buffer.writeln('Subtotal: ${subtotal.toStringAsFixed(2)}');
    if (sale.discount > 0) {
      buffer.writeln(
        'Discount (${sale.discountPercent.toStringAsFixed(1)}%): -${sale.discount.toStringAsFixed(2)}',
      );
    }
    final totalQty = items.fold(0, (sum, item) => sum + item.quantity);
    buffer.writeln('Total Qty: $totalQty');
    buffer.writeln('*GRAND TOTAL: ${sale.totalAmount.toStringAsFixed(2)}*');
    buffer.writeln('--------------------------------');
    buffer.writeln('$thankYouMsg');
    buffer.writeln('');
    buffer.writeln('_Powered By ALQA Tech_');

    return buffer.toString();
  }

  static String generateVerticalList(List<SaleItem> items, List<Book> books) {
    final buffer = StringBuffer();
    for (var item in items) {
      final book = books.firstWhere(
        (b) => b.id == item.bookId,
        orElse: () => Book(
            title: 'Unknown',
            sku: '',
            price: 0,
            stockQuantity: 0,
            author: '',
            publisher: '',
            category: '',
            isbn: '',
            description: ''),
      );
      buffer.writeln('*${book.title}*');
      buffer.writeln(
          '${item.quantity} x ${item.priceAtSale.toStringAsFixed(2)} = ${(item.quantity * item.priceAtSale).toStringAsFixed(2)}');
      buffer.writeln(''); // Empty line for spacing
    }
    return buffer.toString();
  }

  static Future<void> sharePurchaseOnWhatsApp({
    required BuildContext context,
    required Purchase purchase,
    required List<PurchaseItem> items,
    required List<Book> books,
    required Distributor distributor,
    required Map<String, String> settings,
  }) async {
    try {
      // Fetch fresh distributor data
      final freshDistributor =
          await DistributorRepository().getDistributorById(distributor.id!);
      if (freshDistributor != null) {
        distributor = freshDistributor;
      }

      final receiptText = generateWhatsAppPurchaseReceipt(
        purchase,
        items,
        books,
        distributor,
        settings['shop_name'] ?? 'Book Shop',
        settings['shop_address'],
        settings['shop_number'],
      );

      String phone = distributor.phone;

      if (phone.isNotEmpty) {
        // 1. Sanitize (Remove all non-digits)
        phone = phone.replaceAll(RegExp(r'[^\d]'), '');

        // 2. Handle Country Code (Assumes India +91)
        if (phone.length == 10) {
          phone = '91$phone';
        }

        final message = Uri.encodeComponent(receiptText);

        // 3. Define URLs
        final appUrl = Uri.parse('whatsapp://send?phone=$phone&text=$message');
        final webUrl = Uri.parse('https://wa.me/$phone?text=$message');

        try {
          // 4. Try launching App directly first
          if (!await launchUrl(appUrl, mode: LaunchMode.externalApplication)) {
            throw 'Could not launch app';
          }
        } catch (e) {
          // 5. Fallback to Web/Browser link
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('No phone number available for this distributor')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
    }
  }

  static String generateWhatsAppPurchaseReceipt(
    Purchase purchase,
    List<PurchaseItem> items,
    List<Book> books,
    Distributor distributor,
    String? shopName,
    String? shopAddress,
    String? shopNumber,
  ) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('*$shopName*');
    if (shopAddress != null && shopAddress.isNotEmpty) {
      buffer.writeln(shopAddress);
    }
    if (shopNumber != null && shopNumber.isNotEmpty) {
      buffer.writeln('Tel: $shopNumber');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('PURCHASE RECEIPT');
    buffer.writeln('Date: ${purchase.timestamp.toString().split('.')[0]}');
    buffer.writeln('Bill No: *${purchase.billNumber}*');

    // Distributor Details
    buffer.writeln('Distributor: ${distributor.name}');
    if (distributor.phone.isNotEmpty) {
      buffer.writeln('Phone: ${distributor.phone}');
    }
    buffer.writeln('Balance: ${distributor.balance.toStringAsFixed(2)}');
    buffer.writeln('Payment: ${purchase.paymentMethod}');
    buffer.writeln('--------------------------------');

    // Items (Vertical List)
    for (var item in items) {
      final book = books.firstWhere(
        (b) => b.id == item.bookId,
        orElse: () => Book(
            title: 'Unknown',
            sku: '',
            price: 0,
            stockQuantity: 0,
            author: '',
            publisher: '',
            category: '',
            isbn: '',
            description: ''),
      );
      buffer.writeln('*${book.title}*');
      buffer.writeln(
          '${item.quantity} x ${item.costPrice.toStringAsFixed(2)} = ${(item.quantity * item.costPrice).toStringAsFixed(2)}');
      buffer.writeln(''); // Empty line for spacing
    }
    buffer.writeln('--------------------------------');

    // Totals
    final subtotal = purchase.totalAmount + purchase.discount;
    if (purchase.discount > 0) {
      buffer.writeln('Subtotal: ${subtotal.toStringAsFixed(2)}');
      buffer.writeln(
        'Discount: -${purchase.discount.toStringAsFixed(2)}',
      );
    }
    final totalQty = items.fold(0, (sum, item) => sum + item.quantity);
    buffer.writeln('Total Qty: $totalQty');
    buffer.writeln('*GRAND TOTAL: ${purchase.totalAmount.toStringAsFixed(2)}*');

    buffer.writeln('--------------------------------');
    buffer.writeln('');
    buffer.writeln('_Powered By ALQA Tech_');

    return buffer.toString();
  }

  static Future<void> sharePurchaseReturnOnWhatsApp({
    required BuildContext context,
    required PurchaseReturn returnRecord,
    required List<PurchaseReturnItem> items,
    required List<Book> books,
    required Distributor distributor,
    required Purchase purchase,
    required Map<String, String> settings,
  }) async {
    try {
      // Fetch fresh distributor data
      final freshDistributor =
          await DistributorRepository().getDistributorById(distributor.id!);
      if (freshDistributor != null) {
        distributor = freshDistributor;
      }

      final receiptText = generateWhatsAppPurchaseReturnReceipt(
        returnRecord,
        items,
        books,
        distributor,
        purchase,
        settings['shop_name'] ?? 'Book Shop',
        settings['shop_address'],
        settings['shop_number'],
      );

      String phone = distributor.phone;

      if (phone.isNotEmpty) {
        // 1. Sanitize (Remove all non-digits)
        phone = phone.replaceAll(RegExp(r'[^\d]'), '');

        // 2. Handle Country Code (Assumes India +91)
        if (phone.length == 10) {
          phone = '91$phone';
        }

        final message = Uri.encodeComponent(receiptText);

        // 3. Define URLs
        final appUrl = Uri.parse('whatsapp://send?phone=$phone&text=$message');
        final webUrl = Uri.parse('https://wa.me/$phone?text=$message');

        try {
          // 4. Try launching App directly first
          if (!await launchUrl(appUrl, mode: LaunchMode.externalApplication)) {
            throw 'Could not launch app';
          }
        } catch (e) {
          // 5. Fallback to Web/Browser link
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('No phone number available for this distributor')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
    }
  }

  static String generateWhatsAppPurchaseReturnReceipt(
    PurchaseReturn returnRecord,
    List<PurchaseReturnItem> items,
    List<Book> books,
    Distributor distributor,
    Purchase purchase,
    String? shopName,
    String? shopAddress,
    String? shopNumber,
  ) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('*$shopName*');
    if (shopAddress != null && shopAddress.isNotEmpty) {
      buffer.writeln(shopAddress);
    }
    if (shopNumber != null && shopNumber.isNotEmpty) {
      buffer.writeln('Tel: $shopNumber');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('PURCHASE RETURN RECEIPT');
    buffer.writeln('Date: ${returnRecord.timestamp.toString().split('.')[0]}');
    buffer.writeln('Return Bill No: *${returnRecord.billNumber}*');
    buffer.writeln('Original Bill No: ${purchase.billNumber}');

    // Distributor Details
    buffer.writeln('Distributor: ${distributor.name}');
    if (distributor.phone.isNotEmpty) {
      buffer.writeln('Phone: ${distributor.phone}');
    }
    buffer.writeln('Balance: ${distributor.balance.toStringAsFixed(2)}');
    buffer.writeln('Payment: ${purchase.paymentMethod}');
    buffer.writeln('--------------------------------');

    // Items (Vertical List)
    for (var item in items) {
      final book = books.firstWhere(
        (b) => b.id == item.bookId,
        orElse: () => Book(
            title: 'Unknown',
            sku: '',
            price: 0,
            stockQuantity: 0,
            author: '',
            publisher: '',
            category: '',
            isbn: '',
            description: ''),
      );
      buffer.writeln('*${book.title}*');
      buffer.writeln(
          '${item.quantity} x Refund: ${item.refundAmount.toStringAsFixed(2)}');
      buffer.writeln(''); // Empty line for spacing
    }
    buffer.writeln('--------------------------------');

    // Totals
    final totalQty = items.fold(0, (sum, item) => sum + item.quantity);
    buffer.writeln('*TOTAL RETURN QUANTITY: $totalQty*');
    buffer.writeln(
        '*TOTAL REFUND: ${returnRecord.totalRefund.toStringAsFixed(2)}*');

    buffer.writeln('--------------------------------');
    buffer.writeln('');
    buffer.writeln('_Powered By ALQA Tech_');

    return buffer.toString();
  }

  static Future<void> shareSalesReturnOnWhatsApp({
    required BuildContext context,
    required SalesReturn returnRecord,
    required List<SalesReturnItem> items,
    required List<Book> books,
    Customer? customer,
    required Sale sale,
    required Map<String, String> settings,
  }) async {
    try {
      // Fetch fresh customer data if available
      if (customer != null) {
        final freshCustomer =
            await CustomerRepository().getCustomerById(customer.id!);
        if (freshCustomer != null) {
          customer = freshCustomer;
        }
      }

      final receiptText = generateWhatsAppSalesReturnReceipt(
        returnRecord,
        items,
        books,
        customer,
        sale,
        settings['shop_name'] ?? 'Book Shop',
        settings['shop_address'],
        settings['shop_number'],
      );

      String phone = '';
      if (customer != null) {
        phone = customer.phone;
      } else if (sale.guestPhone != null) {
        phone = sale.guestPhone!;
      }

      if (phone.isNotEmpty) {
        // 1. Sanitize (Remove all non-digits)
        phone = phone.replaceAll(RegExp(r'[^\d]'), '');

        // 2. Handle Country Code (Assumes India +91)
        if (phone.length == 10) {
          phone = '91$phone';
        }

        final message = Uri.encodeComponent(receiptText);

        // 3. Define URLs
        final appUrl = Uri.parse('whatsapp://send?phone=$phone&text=$message');
        final webUrl = Uri.parse('https://wa.me/$phone?text=$message');

        try {
          // 4. Try launching App directly first
          if (!await launchUrl(appUrl, mode: LaunchMode.externalApplication)) {
            throw 'Could not launch app';
          }
        } catch (e) {
          // 5. Fallback to Web/Browser link
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No phone number available for this customer')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
    }
  }

  static String generateWhatsAppSalesReturnReceipt(
    SalesReturn returnRecord,
    List<SalesReturnItem> items,
    List<Book> books,
    Customer? customer,
    Sale sale,
    String? shopName,
    String? shopAddress,
    String? shopNumber,
  ) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('*$shopName*');
    if (shopAddress != null && shopAddress.isNotEmpty) {
      buffer.writeln(shopAddress);
    }
    if (shopNumber != null && shopNumber.isNotEmpty) {
      buffer.writeln('Tel: $shopNumber');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('SALES RETURN RECEIPT');
    buffer.writeln('Date: ${returnRecord.timestamp.toString().split('.')[0]}');
    buffer.writeln('Return Bill No: *${returnRecord.billNumber}*');
    buffer.writeln('Original Bill No: ${sale.billNumber}');

    // Customer Details
    if (customer != null) {
      buffer.writeln('Customer: ${customer.name}');
      buffer.writeln('Phone: ${customer.phone}');
      buffer.writeln('Balance: ${customer.balance.toStringAsFixed(2)}');
    } else if (sale.guestPhone != null && sale.guestPhone!.isNotEmpty) {
      buffer.writeln('Guest Phone: ${sale.guestPhone}');
    }
    buffer.writeln('Payment: ${sale.paymentMethod}');
    buffer.writeln('--------------------------------');

    // Items (Vertical List)
    for (var item in items) {
      final book = books.firstWhere(
        (b) => b.id == item.bookId,
        orElse: () => Book(
            title: 'Unknown',
            sku: '',
            price: 0,
            stockQuantity: 0,
            author: '',
            publisher: '',
            category: '',
            isbn: '',
            description: ''),
      );
      buffer.writeln('*${book.title}*');
      buffer.writeln(
          '${item.quantity} x Refund: ${item.refundAmount.toStringAsFixed(2)}');
      buffer.writeln(''); // Empty line for spacing
    }
    buffer.writeln('--------------------------------');

    // Totals
    final totalQty = items.fold(0, (sum, item) => sum + item.quantity);
    buffer.writeln('*TOTAL RETURN QUANTITY: $totalQty*');
    buffer.writeln(
        '*TOTAL REFUND: ${returnRecord.totalRefund.toStringAsFixed(2)}*');

    buffer.writeln('--------------------------------');
    buffer.writeln('');
    buffer.writeln('_Powered By ALQA Tech_');

    return buffer.toString();
  }
}
