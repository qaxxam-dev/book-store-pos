import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../../data/models/distributor.dart';
import '../../providers/distributor_provider.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../providers/auth_provider.dart';
import '../../../core/utils/dialog_utils.dart';

class AddEditDistributorScreen extends StatefulWidget {
  final Distributor? distributor;

  const AddEditDistributorScreen({super.key, this.distributor});

  @override
  State<AddEditDistributorScreen> createState() =>
      _AddEditDistributorScreenState();
}

class _AddEditDistributorScreenState extends State<AddEditDistributorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.distributor?.name ?? '');
    _phoneController =
        TextEditingController(text: widget.distributor?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final provider = context.read<DistributorProvider>();
      final distributor = Distributor(
        id: widget.distributor?.id,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        balance: widget.distributor?.balance ?? 0.0,
      );

      if (widget.distributor == null) {
        await provider.addDistributor(distributor, isDemo: authProvider.isDemo);
      } else {
        await provider.updateDistributor(distributor);
      }

      if (mounted) {
        Navigator.pop(context);
        AppSnackBar.showSuccess(context, 'Distributor saved successfully');
      }
    } catch (e) {
      if (mounted) {
        if (e is Map && e['type'] == 'purchase_required') {
          DialogUtils.showPurchaseDialog(e['message'], e['url'], context);
        } else {
          AppSnackBar.showError(context, 'Error saving distributor: $e');
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.distributor == null
            ? 'Add Distributor'
            : 'Edit Distributor'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Distributor Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Please enter name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter phone number'
                    : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent500,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Distributor',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
