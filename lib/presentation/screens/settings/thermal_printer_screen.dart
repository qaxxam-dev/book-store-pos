import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/printer_provider.dart';
import '../../../core/theme.dart';

class ThermalPrinterScreen extends StatefulWidget {
  const ThermalPrinterScreen({super.key});

  @override
  State<ThermalPrinterScreen> createState() => _ThermalPrinterScreenState();
}

class _ThermalPrinterScreenState extends State<ThermalPrinterScreen> {
  @override
  void initState() {
    super.initState();
    // Start scan on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrinterProvider>().scanDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thermal Printer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<PrinterProvider>().scanDevices();
            },
          ),
        ],
      ),
      body: Consumer<PrinterProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.devices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bluetooth_disabled,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No bonded devices found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                      onPressed: () {
                        // Open system bluetooth settings?
                        // blue_thermal_printer uses 'openSettings' but it's part of the instance methods
                        // which we wrapped in service. For now just refresh or tell user to pair.
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
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
                                label: Text(
                                    isConnected ? 'Connected' : 'Selected'),
                                backgroundColor: isConnected
                                    ? AppTheme.successText
                                    : Colors.orange,
                                labelStyle:
                                    const TextStyle(color: Colors.white),
                              )
                            : null,
                        onTap: () {
                          provider.selectDevice(device);
                          // Auto connect on selection
                          provider.connect();
                        },
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              // Settings and Test Print
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
                      onPressed: provider.selectedDevice == null
                          ? null
                          : () async {
                              try {
                                await provider.printTestTicket();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Test print sent')),
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
