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

  /// Parses a CSV in the same shape [buildCsv] produces (`date,weight_kg,
  /// body_fat_pct,hydration_pct`, one row per day) into entries owned by
  /// [userId]. Not a general-purpose CSV parser - no quoted-field support,
  /// same as the writer side - just enough to round-trip Suma's own export
  /// format (or a plain spreadsheet saved in that shape). Malformed rows are
  /// skipped rather than aborting the whole import.
  static ImportResult parseCsv(String content, String userId) {
    final lines = content.split(RegExp(r'\r\n|\r|\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return const ImportResult(entries: [], skipped: 0);

    final startIndex = lines.first.trim().toLowerCase().startsWith('date') ? 1 : 0;
    final entries = <WeightEntry>[];
    var skipped = 0;

    for (var i = startIndex; i < lines.length; i++) {
      final parts = lines[i].split(',');
      if (parts.length < 2) {
        skipped++;
        continue;
      }
      final date = DateTime.tryParse(parts[0].trim());
      final weight = double.tryParse(parts[1].trim().replaceAll(',', '.'));
      if (date == null || weight == null) {
        skipped++;
        continue;
      }
      final bodyFat = parts.length > 2 ? double.tryParse(parts[2].trim().replaceAll(',', '.')) : null;
      final hydration = parts.length > 3 ? double.tryParse(parts[3].trim().replaceAll(',', '.')) : null;
      entries.add(WeightEntry(
        userId: userId,
        date: date,
        weightKg: weight,
        bodyFatPct: bodyFat,
        hydrationPct: hydration,
        createdAt: DateTime.now(),
      ));
    }
    return ImportResult(entries: entries, skipped: skipped);
  }

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

/// Result of [CsvExportService.parseCsv]: the entries that parsed cleanly,
/// and how many rows were skipped for being malformed.
class ImportResult {
  final List<WeightEntry> entries;
  final int skipped;
  const ImportResult({required this.entries, required this.skipped});
}
