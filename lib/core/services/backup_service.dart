import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';

class BackupService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<String> createBackup() async {
    try {
      // Get the correct database path (same as DatabaseHelper)
      final appDocDir = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(appDocDir.path, 'book_shop_pos.db'));

      if (!await dbFile.exists()) {
        throw Exception('Database file not found at ${dbFile.path}');
      }

      // Create a temporary directory for the backup
      final tempDir = await getTemporaryDirectory();
      final backupDir = Directory(p.join(tempDir.path, 'backup_temp'));
      if (await backupDir.exists()) {
        await backupDir.delete(recursive: true);
      }
      await backupDir.create();

      // Copy database to backup dir
      await dbFile.copy(p.join(backupDir.path, 'book_shop_pos.db'));

      // Create ZIP
      final encoder = ZipFileEncoder();
      final timestamp =
          DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final zipPath = p.join(tempDir.path, 'backup_$timestamp.zip');
      encoder.zipDirectory(backupDir, filename: zipPath);

      // Cleanup temp dir
      await backupDir.delete(recursive: true);

      return zipPath;
    } catch (e) {
      throw Exception('Failed to create backup: $e');
    }
  }

  Future<void> restoreBackup() async {
    try {
      // Pick Backup File
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.single.path == null) return;

      final zipFile = File(result.files.single.path!);
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final appDocDir = await getApplicationDocumentsDirectory();
      final dbPath = appDocDir.path;
      final dbFile = File(p.join(dbPath, 'book_shop_pos.db'));

      // Close Database
      await _dbHelper.close();

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          if (filename == 'book_shop_pos.db') {
            // Restore Database
            dbFile
              ..createSync(recursive: true)
              ..writeAsBytesSync(data);
          }
        }
      }

      // Re-open Database
      await _dbHelper.database;
    } catch (e) {
      throw Exception('Failed to restore backup: $e');
    }
  }
}
