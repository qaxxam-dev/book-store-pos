import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';

class ShopDetailsScreen extends StatefulWidget {
  const ShopDetailsScreen({super.key});

  @override
  State<ShopDetailsScreen> createState() => _ShopDetailsScreenState();
}

class _ShopDetailsScreenState extends State<ShopDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _shopNameController;
  late TextEditingController _shopEmailController;
  late TextEditingController _shopNumberController;
  late TextEditingController _shopAddressController;
  late TextEditingController _aiApiKeyController;
  late TextEditingController _thankYouMessageController;

  @override
  void initState() {
    super.initState();
    final SettingsProvider provider = context.read<SettingsProvider>();
    _shopNameController =
        TextEditingController(text: provider.getSetting('shop_name'));
    _shopEmailController =
        TextEditingController(text: provider.getSetting('shop_email'));
    _shopNumberController =
        TextEditingController(text: provider.getSetting('shop_number'));
    _shopAddressController =
        TextEditingController(text: provider.getSetting('shop_address'));
    _aiApiKeyController =
        TextEditingController(text: provider.getSetting('ai_api_key'));
    _thankYouMessageController =
        TextEditingController(text: provider.getSetting('thank_you_message'));
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopEmailController.dispose();
    _shopNumberController.dispose();
    _shopAddressController.dispose();
    _aiApiKeyController.dispose();
    _thankYouMessageController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<SettingsProvider>();
      final authProvider = context.read<AuthProvider>();

      final newSettings = {
        ...provider.settings, // Keep existing settings
        'shop_name': _shopNameController.text,
        'shop_email': _shopEmailController.text,
        'shop_number': _shopNumberController.text,
        'shop_address': _shopAddressController.text,
        'ai_api_key': _aiApiKeyController.text,
        'thank_you_message': _thankYouMessageController.text,
      };

      try {
        if (authProvider.isDemo) {
          await provider.updateSettings(newSettings);
          if (mounted) {
            AppSnackBar.showSuccess(
                context, 'Settings updated (Demo Mode: Local only)');
            Navigator.pop(context);
          }
        } else {
          await provider.saveSettingsToApi(newSettings);
          if (mounted) {
            AppSnackBar.showSuccess(context, 'Settings saved successfully');
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.showError(context, 'Error saving settings: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDemo = context.watch<AuthProvider>().isDemo;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop Settings'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Shop Details',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextFormField(
              controller: _shopNameController,
              decoration: const InputDecoration(labelText: 'Shop Name'),
              readOnly: isDemo,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _shopEmailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              readOnly: isDemo,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _shopNumberController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
              readOnly: isDemo,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _shopAddressController,
              decoration: const InputDecoration(labelText: 'Address'),
              maxLines: 3,
              readOnly: isDemo,
            ),
            const SizedBox(height: 24),
            Text('Receipt Settings',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextFormField(
              controller: _thankYouMessageController,
              decoration: const InputDecoration(
                labelText: 'Thank You Message',
                helperText: 'Message printed at bottom of receipt',
              ),
              readOnly: isDemo,
            ),
            const SizedBox(height: 24),
            Text('AI Configuration',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextFormField(
              controller: _aiApiKeyController,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                helperText: 'Required for AI book scanning',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                const url = 'https://bookstorepos.alqatech.in/ai-api';
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (context.mounted) {
                    AppSnackBar.showError(context, 'Could not launch $url');
                  }
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Get API Key'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent500,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Save Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
