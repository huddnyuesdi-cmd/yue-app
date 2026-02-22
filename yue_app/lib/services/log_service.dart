import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Logging service that writes all logs and errors to local files.
/// Log files are organized by date (one file per day) and stored in the
/// app's documents directory under a `logs/` subdirectory.
class LogService {
  static LogService? _instance;
  Directory? _logDir;

  LogService._();

  static Future<LogService> getInstance() async {
    if (_instance == null) {
      _instance = LogService._();
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _logDir = Directory('${appDir.path}/logs');
    if (!await _logDir!.exists()) {
      await _logDir!.create(recursive: true);
    }
    // Clean up old log files (keep last 7 days)
    await _cleanOldLogs(7);
  }

  /// Get the log file for today's date.
  File _getTodayLogFile() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return File('${_logDir!.path}/yue_$dateStr.log');
  }

  /// Write a log entry with the given level.
  Future<void> _write(String level, String tag, String message) async {
    if (_logDir == null) return;
    try {
      final file = _getTodayLogFile();
      final now = DateTime.now();
      final timestamp =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
      final line = '[$timestamp] [$level] [$tag] $message\n';
      await file.writeAsString(line, mode: FileMode.append);
    } catch (_) {
      // Silently ignore logging errors to avoid cascading failures
    }
  }

  /// Log an info-level message.
  Future<void> i(String tag, String message) => _write('INFO', tag, message);

  /// Log a warning-level message.
  Future<void> w(String tag, String message) =>
      _write('WARN', tag, message);

  /// Log an error-level message, optionally including an error object and stack trace.
  Future<void> e(String tag, String message,
      [Object? error, StackTrace? stackTrace]) {
    final sb = StringBuffer(message);
    if (error != null) {
      sb.write(' | error=$error');
    }
    if (stackTrace != null) {
      sb.write('\n$stackTrace');
    }
    return _write('ERROR', tag, sb.toString());
  }

  /// Log a debug-level message.
  Future<void> d(String tag, String message) =>
      _write('DEBUG', tag, message);

  /// Remove log files older than [keepDays] days.
  Future<void> _cleanOldLogs(int keepDays) async {
    if (_logDir == null) return;
    try {
      final cutoff = DateTime.now().subtract(Duration(days: keepDays));
      final entries = _logDir!.listSync();
      for (final entry in entries) {
        if (entry is File && entry.path.endsWith('.log')) {
          final stat = await entry.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entry.delete();
          }
        }
      }
    } catch (_) {
      // Ignore cleanup errors
    }
  }

  /// Get the path to today's log file (for display/sharing).
  String get todayLogPath => _getTodayLogFile().path;

  /// Get the log directory path.
  String get logDirPath => _logDir?.path ?? '';

  /// Read today's log file contents.
  Future<String> readTodayLog() async {
    final file = _getTodayLogFile();
    if (await file.exists()) {
      return file.readAsString();
    }
    return '暂无日志';
  }

  /// List all log files with their sizes.
  Future<List<Map<String, dynamic>>> listLogFiles() async {
    if (_logDir == null) return [];
    try {
      final entries = _logDir!.listSync()
        ..sort((a, b) => b.path.compareTo(a.path));
      final result = <Map<String, dynamic>>[];
      for (final entry in entries) {
        if (entry is File && entry.path.endsWith('.log')) {
          final stat = await entry.stat();
          result.add({
            'path': entry.path,
            'name': entry.path.split('/').last,
            'size': stat.size,
            'modified': stat.modified.toIso8601String(),
          });
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }
}
