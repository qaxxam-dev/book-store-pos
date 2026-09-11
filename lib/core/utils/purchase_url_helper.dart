import 'package:url_launcher/url_launcher.dart';

class PurchaseUrlHelper {
  static String _purchaseUrl = 'https://bookstorepos.alqatech.in/';

  static String get kPurchaseUrl => _purchaseUrl;

  static void setPurchaseUrl(String url) {
    if (url.isNotEmpty) {
      _purchaseUrl = url;
    }
  }

  static Future<void> openPurchasePage() async {
    final uri = Uri.parse(_purchaseUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
