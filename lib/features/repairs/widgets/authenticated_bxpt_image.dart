import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/network/dio_client.dart';
import '../services/repair_service.dart';

// 经登录态 Dio 加载报修平台图片。
// Image.network 走 Flutter 自建 HttpClient，不带 App 的登录 Cookie，
// bxpt 文件接口此时返回登录页而非图片字节，解码必失败，故统一走这里。
class AuthenticatedBxptImage extends StatefulWidget {
  const AuthenticatedBxptImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.loadingWidget,
    this.errorWidget,
  });

  final String url;
  final BoxFit fit;
  final Widget? loadingWidget;
  final Widget? errorWidget;

  @override
  State<AuthenticatedBxptImage> createState() =>
      _AuthenticatedBxptImageState();
}

class _AuthenticatedBxptImageState extends State<AuthenticatedBxptImage> {
  Uint8List? _bytes;
  bool _failed = false;
  late String _loadedUrl;

  @override
  void initState() {
    super.initState();
    _loadedUrl = widget.url;
    _load();
  }

  @override
  void didUpdateWidget(AuthenticatedBxptImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loadedUrl = widget.url;
      _load();
    }
  }

  Future<void> _load() async {
    final url = _loadedUrl;
    setState(() {
      _bytes = null;
      _failed = false;
    });
    try {
      final res = await DioClient().dio.get<List<int>>(
            url,
            options: Options(
              responseType: ResponseType.bytes,
              headers: {
                'Referer':
                    '${RepairService.baseUrl}/relax/mobile/index.html',
              },
            ),
          );
      final data = res.data;
      if (!mounted || url != _loadedUrl) return;
      if (data == null || data.isEmpty) {
        setState(() => _failed = true);
        return;
      }
      setState(() => _bytes = Uint8List.fromList(data));
    } catch (_) {
      if (!mounted || url != _loadedUrl) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            widget.errorWidget ?? const SizedBox.shrink(),
      );
    }
    if (_failed) return widget.errorWidget ?? const SizedBox.shrink();
    return widget.loadingWidget ?? const SizedBox.shrink();
  }
}
