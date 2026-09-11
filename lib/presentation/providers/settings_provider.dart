import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../core/globals.dart';
import '../../core/services/feedback_service.dart';

class SettingsProvider with ChangeNotifier {
  Map<String, String> _settings = {};
  bool _isLoading = false;

  Map<String, String> get settings => _settings;
  bool get isLoading => _isLoading;

  FeedbackType _feedbackType = FeedbackType.vibrate;
  FeedbackType get feedbackType => _feedbackType;

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('shop_details')) {
        final shopDetailsString = prefs.getString('shop_details');
        if (shopDetailsString != null) {
          final shopDetails =
              jsonDecode(shopDetailsString) as Map<String, dynamic>;
          _settings = shopDetails.map((k, v) => MapEntry(k, v.toString()));
        }
      }

      final feedback = prefs.getString('feedback_type');
      if (feedback != null) {
        _feedbackType = FeedbackType.values.firstWhere(
          (e) => e.name == feedback,
          orElse: () => FeedbackType.vibrate,
        );
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveSettingsToApi(Map<String, String> newSettings) async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw 'Not authenticated';
      }

      final url = Uri.parse(
          'https://bookstorepos.alqatech.in/wp-json/pos-shop/v1/settings/update');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(newSettings),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'updated') {
        if (data['shop_details'] != null) {
          final shopDetails = Map<String, dynamic>.from(data['shop_details']);
          _settings = shopDetails.map((k, v) => MapEntry(k, v.toString()));

          // Save to SharedPreferences
          await prefs.setString('shop_details', jsonEncode(shopDetails));
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Token revoked or invalid -> Logout immediately
        await prefs.remove('auth_token');
        await prefs.remove('shop_details');
        navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        throw 'Session expired. Please login again.';
      } else if (data['status'] == 'purchase_required') {
        throw data['message'] ?? 'Purchase required';
      } else {
        throw data['message'] ?? 'Failed to update settings';
      }
    } catch (e) {
      debugPrint('Error saving settings to API: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSettings(Map<String, String> newSettings) async {
    _settings = newSettings;
    notifyListeners();
    // Note: AuthProvider handles saving the full object to SharedPreferences from API.
    // This method is primarily for updating the in-memory state from AuthProvider.
  }

  Future<void> saveSetting(String key, String value) async {
    _settings[key] = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    // Update the specific key in the cached map
    if (prefs.containsKey('shop_details')) {
      final shopDetailsString = prefs.getString('shop_details');
      if (shopDetailsString != null) {
        final Map<String, dynamic> shopDetails = jsonDecode(shopDetailsString);
        shopDetails[key] = value;
        await prefs.setString('shop_details', jsonEncode(shopDetails));
      }
    } else {
      // Create new if doesn't exist (unlikely if logged in)
      await prefs.setString('shop_details', jsonEncode(_settings));
    }
  }

  /// Helper to safely get a setting value
  String getSetting(String key) {
    return _settings[key] ?? '';
  }

  Future<void> setFeedbackType(FeedbackType type) async {
    _feedbackType = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('feedback_type', type.name);
    notifyListeners();
  }

  // AI Model Setting
  String get aiModel => _settings['ai_model'] ?? 'gemini-2.5-flash';

  Future<void> setAiModel(String model) async {
    await saveSetting('ai_model', model);
  }
}
