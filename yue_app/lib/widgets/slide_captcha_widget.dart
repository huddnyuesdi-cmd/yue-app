import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// A slide captcha dialog that displays the captcha image and lets the user
/// drag the slider to the correct position, then verifies it.
/// Returns the verified captcha ID on success, or null on cancel.
class SlideCaptchaDialog extends StatefulWidget {
  const SlideCaptchaDialog({super.key});

  /// Show the captcha dialog and return the verified captcha ID, or null.
  static Future<String?> show(BuildContext context) {
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SlideCaptchaDialog(),
    );
  }

  @override
  State<SlideCaptchaDialog> createState() => _SlideCaptchaDialogState();
}

class _SlideCaptchaDialogState extends State<SlideCaptchaDialog> {
  // Default thumb dimensions (matches the server-generated 60x60 puzzle piece)
  static const double _thumbSize = 60;

  CaptchaData? _captchaData;
  bool _isLoading = true;
  bool _isVerifying = false;
  String? _error;
  double _sliderValue = 0;

  // Cached decoded image bytes to avoid re-decoding on every rebuild
  Uint8List? _bgImageBytes;
  Uint8List? _thumbImageBytes;

  @override
  void initState() {
    super.initState();
    _loadCaptcha();
  }

  String _parseErrorMessage(Object e) {
    return e.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _loadCaptcha() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _sliderValue = 0;
      _bgImageBytes = null;
      _thumbImageBytes = null;
    });

    try {
      final authService = await AuthService.getInstance();
      final captchaData = await authService.generateCaptcha();
      if (!mounted) return;

      // Decode base64 images once and cache the bytes
      Uint8List? bgBytes;
      Uint8List? thumbBytes;
      if (captchaData.image != null) {
        bgBytes = base64Decode(captchaData.image!.split(',').last);
      }
      if (captchaData.thumbImage != null) {
        thumbBytes = base64Decode(captchaData.thumbImage!.split(',').last);
      }

      setState(() {
        _captchaData = captchaData;
        _bgImageBytes = bgBytes;
        _thumbImageBytes = thumbBytes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _parseErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyCaptcha() async {
    if (_captchaData == null) return;

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      final authService = await AuthService.getInstance();
      final position = _sliderValue.round();
      final success = await authService.verifyCaptcha(
        _captchaData!.id,
        position,
        mode: _captchaData!.mode ?? 'slide',
      );

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(_captchaData!.id);
      } else {
        setState(() {
          _error = '验证失败，请重试';
          _isVerifying = false;
        });
        // Reload captcha after failure
        await _loadCaptcha();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _parseErrorMessage(e);
        _isVerifying = false;
      });
      await _loadCaptcha();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '安全验证',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF999999)),
                  onPressed: () => Navigator.of(context).pop(null),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF2442),
                  ),
                ),
              )
            else if (_captchaData != null)
              _buildCaptchaContent()
            else if (_error != null)
              _buildErrorContent(),

            if (_error != null && _captchaData != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptchaContent() {
    final captcha = _captchaData!;
    final imgWidth = (captcha.imageWidth ?? 300).toDouble();
    final imgHeight = (captcha.imageHeight ?? 220).toDouble(); // API returns 220

    // Scale to fit dialog width (max ~280px padding considered)
    final maxWidth = MediaQuery.of(context).size.width - 120;
    final scale = maxWidth < imgWidth ? maxWidth / imgWidth : 1.0;
    final displayWidth = imgWidth * scale;
    final displayHeight = imgHeight * scale;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Captcha image with thumb overlay
        SizedBox(
          width: displayWidth,
          height: displayHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Background image (uses cached bytes)
              if (_bgImageBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _bgImageBytes!,
                    width: displayWidth,
                    height: displayHeight,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  ),
                ),
              // Thumb image (puzzle piece) at natural size, scaled with background
              if (_thumbImageBytes != null)
                Positioned(
                  left: _sliderValue * scale,
                  top: (captcha.thumbY ?? 0) * scale,
                  child: Image.memory(
                    _thumbImageBytes!,
                    width: _thumbSize * scale,
                    height: _thumbSize * scale,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Slider track
        SizedBox(
          width: displayWidth,
          child: Column(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: const Color(0xFFFF2442),
                  inactiveTrackColor: const Color(0xFFE0E0E0),
                  thumbColor: const Color(0xFFFF2442),
                  overlayColor: const Color(0xFFFF2442).withAlpha(51),
                  trackHeight: 8,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 14,
                  ),
                ),
                child: Slider(
                  value: _sliderValue,
                  min: 0,
                  max: imgWidth - _thumbSize,
                  onChanged: _isVerifying
                      ? null
                      : (value) {
                          setState(() => _sliderValue = value);
                        },
                  onChangeEnd: _isVerifying ? null : (_) => _verifyCaptcha(),
                ),
              ),
              const Text(
                '← 拖动滑块完成验证 →',
                style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Refresh button
        TextButton.icon(
          onPressed: _isVerifying ? null : _loadCaptcha,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('换一张'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF666666),
          ),
        ),

        if (_isVerifying)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFFF2442),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorContent() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadCaptcha,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF2442),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
