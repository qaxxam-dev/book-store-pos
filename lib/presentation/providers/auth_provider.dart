import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_provider.dart';
import '../../core/utils/purchase_url_helper.dart';
import '../../core/globals.dart'; // Import for navigatorKey

class AuthProvider with ChangeNotifier {
  String? _token;
  bool _isAuthenticated = false;
  bool _isLoading = false;

  bool _isDemo = false;

  String? get token => _token;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get isDemo => _isDemo;

  final String _baseUrl =
      'https://bookstorepos.alqatech.in/wp-json/pos-shop/v1';

  Future<void> loginAsDemo(SettingsProvider settingsProvider) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));

      // Clear any existing persistent session to ensure no conflict on restart
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      _isDemo = true;
      _isAuthenticated = true;
      _token = 'demo_token'; // Dummy token

      // Set default demo shop details
      final demoDetails = {
        'shop_name': 'Book Store POS',
        'shop_email': 'info@alqatech.in',
        'shop_number': '70107 46690',
        'shop_address':
            'This is a demo version. Purchase a license to continue.',
        'thank_you_message': 'Thanks for shopping!',
        // 'ai_api_key': '', // Leave empty or let user fill
      };

      await settingsProvider.updateSettings(demoDetails);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password,
      SettingsProvider settingsProvider) async {
    _isLoading = true;
    notifyListeners();

    try {
      final url = Uri.parse('$_baseUrl/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        _token = data['token'];
        _isAuthenticated = true;
        _isDemo = false;

        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setBool('is_demo', false);

        if (data['shop_details'] != null) {
          final shopDetails = Map<String, dynamic>.from(data['shop_details']);
          await prefs.setString('shop_details', jsonEncode(shopDetails));

          // Update SettingsProvider
          await settingsProvider.updateSettings(
              shopDetails.map((k, v) => MapEntry(k, v.toString())));
        }

        if (data['purchase_url'] != null) {
          PurchaseUrlHelper.setPurchaseUrl(data['purchase_url']);
        }
      } else if (data['status'] == 'purchase_required') {
        if (data['purchase_url'] != null) {
          PurchaseUrlHelper.setPurchaseUrl(data['purchase_url']);
        }
        throw {
          'type': 'purchase_required',
          'message': data['message'],
          'url': PurchaseUrlHelper.kPurchaseUrl
        };
      } else {
        throw data['message'] ?? 'Login failed';
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> tryAutoLogin(SettingsProvider settingsProvider) async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('auth_token')) return;

    _token = prefs.getString('auth_token');
    _isAuthenticated = true;

    // Load cached settings immediately
    if (prefs.containsKey('shop_details')) {
      final shopDetailsString = prefs.getString('shop_details');
      if (shopDetailsString != null) {
        final shopDetails =
            jsonDecode(shopDetailsString) as Map<String, dynamic>;
        await settingsProvider.updateSettings(
            shopDetails.map((k, v) => MapEntry(k, v.toString())));
      }
    }

    notifyListeners();

    // Validate token in background
    _validateToken(settingsProvider);
  }

  Future<void> _validateToken(SettingsProvider settingsProvider) async {
    try {
      final url = Uri.parse('$_baseUrl/token/validate');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        if (data['shop_details'] != null) {
          final shopDetails = Map<String, dynamic>.from(data['shop_details']);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('shop_details', jsonEncode(shopDetails));

          // Update SettingsProvider
          await settingsProvider.updateSettings(
              shopDetails.map((k, v) => MapEntry(k, v.toString())));
        }

        if (data['purchase_url'] != null) {
          PurchaseUrlHelper.setPurchaseUrl(data['purchase_url']);
        }
      } else {
        // Invalid token or purchase required -> Logout
        if (data['purchase_url'] != null) {
          PurchaseUrlHelper.setPurchaseUrl(data['purchase_url']);
        }
        await logout();
      }
    } catch (e) {
      // Offline or error: Keep using cached data
      debugPrint('Token validation failed (likely offline): $e');
      // If it's a 401/403 error, we should logout even if offline check failed (though offline usually throws SocketException)
      // But here we are in catch block. If response was 401, it would be handled in the else block above.
      // However, if http call throws an exception that indicates auth failure (unlikely with http package unless configured), we catch it here.
    }
  }

  Future<void> logout() async {
    _token = null;
    _isAuthenticated = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('shop_details');
    notifyListeners();

    // Navigate to Login Screen
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
  }
}
