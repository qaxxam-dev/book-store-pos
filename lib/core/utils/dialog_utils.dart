import 'package:flutter/material.dart';

import 'purchase_url_helper.dart';

class DialogUtils {
  static void showPurchaseDialog(
      String message, String url, BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Purchase Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await PurchaseUrlHelper.openPurchasePage();
            },
            child: const Text('Buy Now'),
          ),
        ],
      ),
    );
  }
}
