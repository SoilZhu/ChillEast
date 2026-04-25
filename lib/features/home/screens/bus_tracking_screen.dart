import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../../core/constants/app_constants.dart';

class BusTrackingScreen extends StatefulWidget {
  const BusTrackingScreen({super.key});

  @override
  State<BusTrackingScreen> createState() => _BusTrackingScreenState();
}

class _BusTrackingScreenState extends State<BusTrackingScreen> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  double _progress = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchLocationAndLoad();
  }

  Future<void> _fetchLocationAndLoad() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = '位置服务未开启';
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = '定位权限被拒绝';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = '定位权限被永久拒绝，请在设置中开启';
          _isLoading = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      final url = '${AppConstants.schoolBusUrl}?lat=${position.latitude}&lng=${position.longitude}';
      
      if (_webViewController != null) {
        _webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
      }
    } catch (e) {
      setState(() {
        _errorMessage = '获取位置失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 填充状态栏
          Container(
            height: MediaQuery.of(context).padding.top,
            color: const Color(0xFFF4F4F4),
          ),
          Expanded(
            child: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) async {
                if (didPop) return;
                if (_webViewController != null && await _webViewController!.canGoBack()) {
                  _webViewController!.goBack();
                } else {
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: Stack(
                children: [
                  // 1. WebView 主体
                  Padding(
                    padding: EdgeInsets.zero,
                    child: InAppWebView(
                      initialSettings: InAppWebViewSettings(
                        useShouldOverrideUrlLoading: true,
                        mediaPlaybackRequiresUserGesture: false,
                        javaScriptCanOpenWindowsAutomatically: true,
                        supportZoom: true,
                        builtInZoomControls: true,
                        displayZoomControls: false,
                        userAgent: 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36',
                        allowsInlineMediaPlayback: true,
                      ),
                      onWebViewCreated: (controller) {
                        _webViewController = controller;
                      },
                      onLoadStart: (controller, url) {
                        setState(() => _isLoading = true);
                      },
                      onLoadStop: (controller, url) {
                        setState(() => _isLoading = false);
                      },
                      onProgressChanged: (controller, progress) {
                        setState(() {
                          _progress = progress / 100;
                        });
                      },
                    ),
                  ),

                  // 2. 进度条
                  if (_isLoading)
                    Positioned(
                      top: 0,
                      left: 0, right: 0,
                      child: LinearProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                      ),
                    ),
                    
                  // 3. 加载指示器 (加载时始终挡住 WebView 以防闪烁)
                  if (_isLoading)
                    Container(
                      color: Colors.white,
                      child: const Center(child: CircularProgressIndicator()),
                    ),

                  // 5. 🔴 浮动功能胶囊
                  Positioned(
                    top: 8,
                    right: 16,
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black12, width: 0.5),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (_errorMessage != null) {
                                setState(() { _isLoading = true; _errorMessage = null; });
                                _fetchLocationAndLoad();
                              } else {
                                _webViewController?.reload();
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Icon(Icons.refresh_rounded, size: 18, color: Colors.black87),
                            ),
                          ),
                          Container(width: 0.5, height: 16, color: Colors.black12),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.pop(context),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Icon(Icons.close_rounded, size: 18, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 6. 错误提示
                  if (_errorMessage != null)
                    Container(
                      color: Colors.white,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_off_rounded, size: 60, color: Colors.grey[200]),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                            ),
                            const SizedBox(height: 24),
                            OutlinedButton(
                              onPressed: () {
                                setState(() { _isLoading = true; _errorMessage = null; });
                                _fetchLocationAndLoad();
                              },
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
