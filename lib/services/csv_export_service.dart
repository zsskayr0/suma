import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/entry.dart';
import '../models/profile.dart';

/// Writes one CSV file per user (date, weight, body fat, hydration) and
/// hands it off in a platform-appropriate way: on Android through the share
/// sheet (so it can be saved to Drive/Files/etc.), on desktop by revealing
/// the file in the system file explorer.
class CsvExportService {
  static const _header = 'date,weight_kg,body_fat_pct,hydration_pct';

  static String buildCsv(List<WeightEntry> entries) {
    final dateFmt = DateFormat('yyyy-MM-dd');
    final buffer = StringBuffer()..writeln(_header);
    // Entries are normally sorted newest-first for on-screen history; export
    // chronologically instead, which is what a spreadsheet/chart wants.
    final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
    for (final e in sorted) {
      buffer.writeln([
        dateFmt.format(e.date),
        _fmt(e.weightKg),
        _fmt(e.bodyFatPct),
        _fmt(e.hydrationPct),
      ].join(','));
    }
    return buffer.toString();
  }

  static String _fmt(double? value) => value == null ? '' : value.toString();

  static String _fileNameFor(Profile profile) {
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final slug = (profile.email ?? profile.name).replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'suma_${slug}_$stamp.csv';
  }

  /// Writes the CSV for [profile] to disk and returns the file. Does not
  /// share/reveal it - see [exportAndHandOff] for the full flow.
  static Future<File> writeCsvFile(Profile profile, List<WeightEntry> entries) async {
    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(p.join(dir.path, 'Suma', 'exports'));
    await exportDir.create(recursive: true);
    final file = File(p.join(exportDir.path, _fileNameFor(profile)));
    await file.writeAsString(buildCsv(entries));
    return file;
  }

  /// Full export flow for one user: write the file, then either open the
  /// share sheet (Android/iOS) or reveal it in the OS file explorer
  /// (Windows/Linux/macOS). Returns the written file so the caller can show
  /// its path in the UI regardless of platform.
  static Future<File> exportAndHandOff(Profile profile, List<WeightEntry> entries) async {
    final file = await writeCsvFile(profile, entries);

    if (Platform.isAndroid || Platform.isIOS) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Suma - dados de ${profile.name}',
        ),
      );
    } else if (Platform.isWindows) {
      await Process.run('explorer.exe', ['/select,', file.path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', file.path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [p.dirname(file.path)]);
    }

    return file;
  }
}
