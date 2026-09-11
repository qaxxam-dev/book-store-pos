import 'dart:io';
import 'dart:typed_data';

class WifiPrinterService {
  Socket? _socket;
  String? _currentIp;
  int? _currentPort;

  bool get isConnected => _socket != null;

  Future<void> connect(String ip, int port) async {
    try {
      if (_socket != null) {
        await disconnect();
      }

      _socket =
          await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      _currentIp = ip;
      _currentPort = port;

      // Listen to close/error events to clean up
      _socket!.listen(
        (data) {},
        onError: (error) {
          disconnect();
        },
        onDone: () {
          disconnect();
        },
      );
    } catch (e) {
      _socket = null;
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (_socket != null) {
      await _socket!.close();
      _socket!.destroy();
      _socket = null;
    }
  }

  Future<void> printBytes(List<int> bytes) async {
    if (_socket == null) {
      // Try to reconnect if we have stored credentials
      if (_currentIp != null && _currentPort != null) {
        await connect(_currentIp!, _currentPort!);
      } else {
        throw Exception('Printer not connected');
      }
    }

    if (_socket != null) {
      _socket!.add(Uint8List.fromList(bytes));
      await _socket!.flush();
    }
  }
}
