import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  /// Show the update dialog. Returns true if user started the update.
  static Future<bool> show(BuildContext context, AppUpdateInfo updateInfo) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: updateInfo.forceUpdate != true,
      builder: (_) => UpdateDialog(updateInfo: updateInfo),
    );
    return result ?? false;
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _startUpdate() async {
    final downloadUrl = widget.updateInfo.downloadUrl;
    if (downloadUrl == null || downloadUrl.isEmpty) return;

    if (!Platform.isAndroid) {
      // On iOS or other platforms, open the URL in browser
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    // Android: download and install APK
    // Request storage permission for older Android versions
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted && !status.isLimited) {
        if (mounted) {
          setState(() {
            _error = '需要存储权限才能下载更新';
          });
        }
        return;
      }
    }

    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });

    final filePath = await UpdateService.downloadApk(
      downloadUrl,
      onProgress: (received, total) {
        if (total > 0 && mounted) {
          setState(() => _progress = received / total);
        }
      },
    );

    if (!mounted) return;

    if (filePath != null) {
      // Open the APK file to trigger system install
      final result = await OpenFilex.open(filePath, type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done && mounted) {
        setState(() {
          _downloading = false;
          _error = '安装失败: ${result.message}';
        });
      } else if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _downloading = false;
        _error = '下载失败，请重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.updateInfo;

    return PopScope(
      canPop: info.forceUpdate != true,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Color(0xFFFF2442), size: 28),
            const SizedBox(width: 8),
            const Text(
              '发现新版本',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF222222)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info.versionName != null)
              Text(
                '版本 ${info.versionName}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
              ),
            if (info.updateLog != null && info.updateLog!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                '更新内容：',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(
                    info.updateLog!,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF666666), height: 1.5),
                  ),
                ),
              ),
            ],
            if (_downloading) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFEEEEEE),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF2442)),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '下载中 ${(_progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(fontSize: 13, color: Colors.red),
              ),
            ],
          ],
        ),
        actions: [
          if (info.forceUpdate != true && !_downloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('稍后再说', style: TextStyle(color: Color(0xFF999999))),
            ),
          if (!_downloading)
            ElevatedButton(
              onPressed: _startUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2442),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              child: const Text('立即更新', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
