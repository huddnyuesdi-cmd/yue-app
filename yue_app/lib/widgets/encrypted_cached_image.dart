import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/image_cache_service.dart';

/// Drop-in replacement for [Image.network] that loads images from an
/// encrypted local cache first, falling back to network download.
class EncryptedCachedImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final int? cacheWidth;
  final int? cacheHeight;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;

  const EncryptedCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.cacheWidth,
    this.cacheHeight,
    this.errorBuilder,
    this.loadingBuilder,
  });

  @override
  State<EncryptedCachedImage> createState() => _EncryptedCachedImageState();
}

class _EncryptedCachedImageState extends State<EncryptedCachedImage> {
  Uint8List? _bytes;
  bool _hasError = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(EncryptedCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });

    try {
      final cache = await ImageCacheService.getInstance();
      final bytes = await cache.getOrDownload(widget.imageUrl);
      if (!mounted) return;
      if (bytes != null) {
        setState(() {
          _bytes = bytes;
          _loading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, Exception('Image load failed'), null);
      }
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: Icon(Icons.broken_image_outlined, color: Color(0xFFDDDDDD)),
        ),
      );
    }

    if (_loading || _bytes == null) {
      if (widget.loadingBuilder != null) {
        return widget.loadingBuilder!(context, const SizedBox(), null);
      }
      return SizedBox(
        width: widget.width,
        height: widget.height,
      );
    }

    return Image.memory(
      _bytes!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
      errorBuilder: widget.errorBuilder,
    );
  }
}
