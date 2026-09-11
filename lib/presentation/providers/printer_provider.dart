import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/thermal_printer_service.dart';
import '../../core/services/wifi_printer_service.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

enum PrinterType { bluetooth, network }

class PrinterProvider extends ChangeNotifier {
  final ThermalPrinterService _service = ThermalPrinterService();
  final WifiPrinterService _wifiService = WifiPrinterService();

  List<BluetoothDevice> _devices = [];
  List<BluetoothDevice> get devices => _devices;

  BluetoothDevice? _selectedDevice;
  BluetoothDevice? get selectedDevice => _selectedDevice;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _autoCut = false;
  bool get autoCut => _autoCut;

  PrinterType _printerType = PrinterType.bluetooth;
  PrinterType get printerType => _printerType;

  String _ipAddress = '192.168.1.100';
  String get ipAddress => _ipAddress;

  int _port = 9100;
  int get port => _port;

  PrinterProvider() {
    _init();
  }

  Future<void> _init() async {
    _loadSettings();
    _checkConnection();
    _service.state.listen((state) {
      // Handle state changes if necessary
      if (state == BlueThermalPrinter.CONNECTED) {
        _isConnected = true;
      } else {
        _isConnected = false;
      }
      notifyListeners();
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoCut = prefs.getBool('printer_auto_cut') ?? false;

    final savedMethod = prefs.getString('printer_print_method');
    if (savedMethod != null) {
      _printMethod = PrintMethod.values.firstWhere(
        (e) => e.name == savedMethod,
        orElse: () => PrintMethod.pdf,
      );
    }

    final savedType = prefs.getString('printer_type');
    if (savedType != null) {
      _printerType = PrinterType.values.firstWhere(
        (e) => e.name == savedType,
        orElse: () => PrinterType.bluetooth,
      );
    }

    _ipAddress = prefs.getString('printer_ip') ?? '192.168.1.100';
    _port = prefs.getInt('printer_port') ?? 9100;

    notifyListeners();
  }

  Future<void> toggleAutoCut(bool value) async {
    _autoCut = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('printer_auto_cut', value);
    notifyListeners();
  }

  Future<void> scanDevices() async {
    _isLoading = true;
    notifyListeners();

    // Request permissions first
    if (await _service.requestPermissions()) {
      _devices = await _service.getBondedDevices();

      // Try to auto-select saved printer
      final prefs = await SharedPreferences.getInstance();
      final savedAddress = prefs.getString('default_printer_address');

      if (savedAddress != null && _selectedDevice == null) {
        try {
          final found = _devices.firstWhere((d) => d.address == savedAddress);
          _selectedDevice = found;
          // Note: We don't auto-connect here to avoid delays on start,
          // but we could if requested. For now, we just restore selection.
        } catch (e) {
          // Saved printer not found in paired devices
        }
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> selectDevice(BluetoothDevice device) async {
    _selectedDevice = device;
    final prefs = await SharedPreferences.getInstance();
    if (device.address != null) {
      await prefs.setString('default_printer_address', device.address!);
    }
    notifyListeners();
  }

  Future<void> connect() async {
    if (_selectedDevice == null) return;

    _isLoading = true;
    notifyListeners();

    notifyListeners();

    if (_printerType == PrinterType.bluetooth) {
      final success = await _service.connect(_selectedDevice!);
      _isConnected = success;
    } else {
      try {
        await _wifiService.connect(_ipAddress, _port);
        _isConnected = true;
      } catch (e) {
        _isConnected = false;
        rethrow;
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> disconnect() async {
    if (_printerType == PrinterType.bluetooth) {
      await _service.disconnect();
    } else {
      await _wifiService.disconnect();
    }
    _isConnected = false;
    notifyListeners();
  }

  Future<void> printTestTicket() async {
    if (!_isConnected && _selectedDevice != null) {
      await connect();
    }

    if (!_isConnected) return;

    final profile = await CapabilityProfile.load();
    final generator = Generator(
        PaperSize.mm58, profile); // Assuming 58mm for now, or make configurable

    List<int> bytes = [];
    bytes += generator.reset();
    bytes += generator.text('Book Store POS',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        ));
    bytes += generator.feed(1);
    bytes += generator.text('Test Ticket',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(2);

    if (_autoCut) {
      bytes += generator.cut();
    }

    await printBytes(bytes);
  }

  Future<void> _checkConnection() async {
    if (_printerType == PrinterType.bluetooth) {
      _isConnected = await _service.isConnected;
    } else {
      _isConnected = _wifiService.isConnected;
    }
    notifyListeners();
  }

  Future<void> setPrinterType(PrinterType type) async {
    _printerType = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_type', type.name);
    notifyListeners();
  }

  Future<void> setNetworkSettings(String ip, int port) async {
    _ipAddress = ip;
    _port = port;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_ip', ip);
    await prefs.setInt('printer_port', port);
    notifyListeners();
  }

  // --- Print Method ---
  PrintMethod _printMethod = PrintMethod.pdf;
  PrintMethod get printMethod => _printMethod;

  Future<void> setPrintMethod(PrintMethod method) async {
    _printMethod = method;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_print_method', method.name);
    notifyListeners();
  }

  Future<void> printBytes(List<int> bytes) async {
    if (_printerType == PrinterType.bluetooth) {
      if (!_isConnected && _selectedDevice != null) {
        // Try to auto-connect if possible
        await connect();
      }

      if (_isConnected) {
        await _service.printBytes(bytes);
      } else {
        throw Exception('Printer not connected');
      }
    } else {
      // Network
      try {
        await _wifiService.printBytes(bytes);
      } catch (e) {
        // Try to connect if failed (WifiPrinterService usually tries internally if not connected, but let's be implicit)
        try {
          await _wifiService.connect(_ipAddress, _port);
          await _wifiService.printBytes(bytes);
        } catch (e) {
          throw Exception('Failed to print to network printer: $e');
        }
      }
    }
  }
}

enum PrintMethod {
  pdf,
  thermal,
}
