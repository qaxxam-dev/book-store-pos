import 'package:flutter/material.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/theme.dart';
import '../../../core/utils/snackbar_utils.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _appVersion = 'Loading...';
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        AppSnackBar.showError(context, 'Could not launch $url');
      }
    }
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      final response = await http.get(Uri.parse(
          'https://bookstorepos.alqatech.in/wp-json/pos-shop/v1/app-version'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersion = data['version'] as String;
        // Simple string comparison for now, or split by dots for semantic versioning
        // Assuming version format x.y.z

        if (_isNewerVersion(latestVersion, _appVersion)) {
          _showUpdateDialog(latestVersion);
        } else {
          if (mounted) {
            AppSnackBar.showSuccess(
                context, 'You are using the latest version.');
          }
        }
      } else {
        if (mounted) {
          AppSnackBar.showError(context, 'Failed to check for updates.');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Error checking update: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  bool _isNewerVersion(String latest, String current) {
    List<String> latestParts = latest.split('.');
    List<String> currentParts = current.split('.');

    for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
      int latestPart = int.tryParse(latestParts[i]) ?? 0;
      int currentPart = int.tryParse(currentParts[i]) ?? 0;

      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }
    // If lengths define newness (e.g. 1.0.1 vs 1.0)
    return latestParts.length > currentParts.length;
  }

  void _showUpdateDialog(String latestVersion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: Text(
            'A new version $latestVersion is available. Would you like to update?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _launchUrl(
                  'https://bookstorepos.alqatech.in/?latest_version_download=1');
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/images/launcher_icon.png',
                    width: 100, height: 100),
              ),
              const SizedBox(height: 24),
              Text(
                'Book Store POS',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold, color: AppTheme.accent700),
              ),
              const SizedBox(height: 8),
              Text(
                'Developer: Alqa Tech',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.neutral600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Version: $_appVersion',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.neutral500,
                    ),
              ),
              const SizedBox(height: 48),
              _buildActionButton(
                context,
                icon: Icons.support_agent,
                label: 'Support',
                onTap: () =>
                    _launchUrl('http://bookstorepos.alqatech.in/support'),
              ),
              const SizedBox(height: 16),
              _buildActionButton(
                context,
                icon: Icons.video_library,
                label: 'Youtube Tutorials',
                onTap: () => _launchUrl(
                    'https://bookstorepos.alqatech.in/video-docs-tam'),
              ),
              const SizedBox(height: 16),
              _buildActionButton(
                context,
                icon: Icons.description,
                label: 'Documentation',
                onTap: () =>
                    _launchUrl('https://bookstorepos.alqatech.in/docs'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isCheckingUpdate ? null : _checkForUpdate,
                  icon: _isCheckingUpdate
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.system_update),
                  label: Text(
                      _isCheckingUpdate ? 'Checking...' : 'Check for update'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
