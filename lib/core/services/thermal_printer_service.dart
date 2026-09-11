import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class ThermalPrinterService {
  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;

  Future<bool> get isConnected =>
      _bluetooth.isConnected.then((value) => value ?? false);

  /// Requests necessary permissions for scanning and connecting
  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    bool allGranted = true;
    statuses.forEach((key, value) {
      if (!value.isGranted) {
        allGranted = false;
      }
    });
    return allGranted;
  }

  /// Gets list of bonded (paired) devices
  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      return await _bluetooth.getBondedDevices();
    } on PlatformException {
      return [];
    }
  }

  /// Connect to a device
  Future<bool> connect(BluetoothDevice device) async {
    try {
      bool? isConnected = await _bluetooth.isConnected;
      if (isConnected == true) {
        return true;
      }
      await _bluetooth.connect(device);
      return true;
    } on PlatformException {
      return false;
    }
  }

  /// Disconnect
  Future<void> disconnect() async {
    await _bluetooth.disconnect();
  }

  /// Print raw bytes
  Future<void> printBytes(List<int> bytes) async {
    if ((await _bluetooth.isConnected) == true) {
      _bluetooth.writeBytes(Uint8List.fromList(bytes));
    } else {
      throw Exception("Printer not connected");
    }
  }

  /// Listen to state
  Stream<int?> get state => _bluetooth.onStateChanged();
}
