import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../utils/media_url_resolver.dart';

/// Loads images from authenticated `/media/object` endpoint.
class AuthNetworkImage extends StatefulWidget {
  const AuthNetworkImage({
    super.key,
    required this.url,
    required this.headers,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.onTap,
  });

  final String url;
  final Map<String, String> headers;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  @override
  State<AuthNetworkImage> createState() => _AuthNetworkImageState();
}

class _AuthNetworkImageState extends State<AuthNetworkImage> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AuthNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _load();
  }

  Future<void> _load() async {
    setState(() {
      _bytes = null;
      _failed = false;
    });
    try {
      final res = await Dio().get<List<int>>(
        MediaUrlResolver.resolve(widget.url),
        options: Options(
          headers: widget.headers,
          responseType: ResponseType.bytes,
        ),
      );
      if (!mounted) return;
      setState(() => _bytes = Uint8List.fromList(res.data ?? []));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_bytes != null) {
      child = Image.memory(_bytes!, height: widget.height, fit: widget.fit);
    } else if (_failed) {
      child = SizedBox(
        height: widget.height ?? 120,
        child: const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.grey),
        ),
      );
    } else {
      child = SizedBox(
        height: widget.height ?? 120,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (widget.borderRadius != null) {
      child = ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }
    if (widget.onTap != null) {
      child = GestureDetector(onTap: widget.onTap, child: child);
    }
    return child;
  }
}
