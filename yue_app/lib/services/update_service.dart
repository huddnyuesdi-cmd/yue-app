import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/api_config.dart';

class AppUpdateInfo {
  final bool hasUpdate;
  final int? versionCode;
  final String? versionName;
  final String? downloadUrl;
  final String? updateLog;
  final bool? forceUpdate;

  AppUpdateInfo({
    required this.hasUpdate,
    this.versionCode,
    this.versionName,
    this.downloadUrl,
    this.updateLog,
    this.forceUpdate,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      hasUpdate: json['has_update'] as bool? ?? false,
      versionCode: json['version_code'] as int?,
      versionName: json['version_name'] as String?,
      downloadUrl: json['download_url'] as String?,
      updateLog: json['update_log'] as String?,
      forceUpdate: json['force_update'] as bool?,
    );
  }
}

class UpdateService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.communityBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  /// Check for app updates from the server.
  static Future<AppUpdateInfo?> checkUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final versionName = packageInfo.version;
      final versionCode = packageInfo.buildNumber;
      final platform = Platform.isAndroid ? 'android' : 'ios';

      final response = await _dio.get(
        '/api/app/check-update',
        queryParameters: {
          'platform': platform,
          'version_name': versionName,
          'version_code': versionCode,
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data['code'] == 200 && data['data'] != null) {
        return AppUpdateInfo.fromJson(data['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Report an app event to the server.
  static Future<void> reportEvent({
    required String deviceId,
    required String eventType,
    int? versionCode,
    int? duration,
  }) async {
    try {
      final platform = Platform.isAndroid ? 'android' : 'ios';
      await _dio.post(
        '/api/app/report-event',
        data: {
          'device_id': deviceId,
          'event_type': eventType,
          'platform': platform,
          if (versionCode != null) 'version_code': versionCode,
          if (duration != null) 'duration': duration,
        },
      );
    } catch (_) {
      // Silently ignore report failures
    }
  }

  /// Download APK file and return the local path.
  static Future<String?> downloadApk(
    String url, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/app_update.apk';

      await _dio.download(
        url,
        filePath,
        onReceiveProgress: onProgress,
      );

      return filePath;
    } catch (_) {
      return null;
    }
  }
}
