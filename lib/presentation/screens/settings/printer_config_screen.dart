import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/printer_provider.dart';
import '../../../core/theme.dart';
import '../../../core/utils/snackbar_utils.dart';

class PrinterConfigScreen extends StatefulWidget {
  const PrinterConfigScreen({super.key});

  @override
  State<PrinterConfigScreen> createState() => _PrinterConfigScreenState();
}

class _PrinterConfigScreenState extends State<PrinterConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _ipController = TextEditingController();
  final _portController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final provider = context.read<PrinterProvider>();
    _ipController.text = provider.ipAddress;
    _portController.text = provider.port.toString();

    // Set initial tab based on current printer type
    if (provider.printerType == PrinterType.network) {
      _tabController.index = 1;
    }

    // Start scan on load if bluetooth
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.printerType == PrinterType.bluetooth) {
        provider.scanDevices();
      }
    });

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 0) {
          provider.setPrinterType(PrinterType.bluetooth);
          provider.scanDevices();
        } else {
          provider.setPrinterType(PrinterType.network);
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Widget _buildBluetoothTab(PrinterProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No bonded devices found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextButton(
                onPressed: () {
                  provider.scanDevices();
                },
                child: const Text('Refresh')),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Please pair your printer in Android Bluetooth Settings first.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: provider.devices.length,
            itemBuilder: (context, index) {
              final device = provider.devices[index];
              final isSelected =
                  provider.selectedDevice?.address == device.address;
              final isConnected = isSelected && provider.isConnected;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isSelected ? AppTheme.accent50 : null,
                shape: isSelected
                    ? RoundedRectangleBorder(
                        side: const BorderSide(
                            color: AppTheme.accent500, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                child: ListTile(
                  leading: Icon(
                    Icons.print,
                    color: isSelected ? AppTheme.accent500 : Colors.grey,
                  ),
                  title: Text(device.name ?? 'Unknown Device'),
                  subtitle: Text(device.address ?? 'No Address'),
                  trailing: isSelected
                      ? Chip(
                          label: Text(isConnected ? 'Connected' : 'Selected'),
                          backgroundColor: isConnected
                              ? AppTheme.successText
                              : Colors.orange,
                          labelStyle: const TextStyle(color: Colors.white),
                        )
                      : null,
                  onTap: () {
                    provider.selectDevice(device);
                    provider.connect();
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkTab(PrinterProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Network Printer Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      labelText: 'IP Address',
                      hintText: '192.168.1.100',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '9100',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final ip = _ipController.text;
                        final port = int.tryParse(_portController.text) ?? 9100;

                        await provider.setNetworkSettings(ip, port);

                        try {
                          await provider
                              .connect(); // This uses the provider which routes to wifi service
                          if (mounted) {
                            AppSnackBar.showSuccess(
                                context, 'Connected successfully');
                          }
                        } catch (e) {
                          if (mounted) {
                            AppSnackBar.showError(
                                context, 'Connection failed: $e');
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent700,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Connect & Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (provider.printerType == PrinterType.network &&
              provider.isConnected)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.successText.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.successText),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.successText),
                  SizedBox(width: 12),
                  Text('Printer Connected',
                      style: TextStyle(
                          color: AppTheme.successText,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Configuration'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Bluetooth'),
            Tab(text: 'Wi-Fi / Network'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_tabController.index == 0) {
                context.read<PrinterProvider>().scanDevices();
              }
            },
          ),
        ],
      ),
      body: Consumer<PrinterProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBluetoothTab(provider),
                    _buildNetworkTab(provider),
                  ],
                ),
              ),
              const Divider(),
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      title: const Text('Enable Auto Cut'),
                      subtitle: const Text('If supported by printer'),
                      value: provider.autoCut,
                      onChanged: (val) => provider.toggleAutoCut(val),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await provider.printTestTicket();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Test print sent')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppTheme.errorText),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('Print Test Receipt'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent700,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
