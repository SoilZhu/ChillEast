import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../core/constants/app_constants.dart';
import 'package:logger/logger.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final Logger _logger = Logger();
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  double _progress = 0;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('工作台'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _webViewController?.reload();
            },
            tooltip: '刷新',
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(AppConstants.fusionWorkspaceUrl),
            ),
            initialSettings: InAppWebViewSettings(
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              iframeAllow: "camera; microphone",
              iframeAllowFullscreen: true,
              javaScriptEnabled: true,
              domStorageEnabled: true,
              useHybridComposition: true,
              supportZoom: true,
              builtInZoomControls: true,
              displayZoomControls: false,
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
              _logger.i('WebView created for workspace');
            },
            onLoadStart: (controller, url) {
              setState(() {
                _isLoading = true;
              });
              _logger.d('Started loading workspace: $url');
            },
            onLoadStop: (controller, url) async {
              setState(() {
                _isLoading = false;
              });
              _logger.d('Finished loading workspace: $url');
            },
            onProgressChanged: (controller, progress) {
              setState(() {
                _progress = progress / 100;
              });
            },
            onReceivedError: (controller, request, error) {
              _logger.e('WebView error: ${error.description}');
              setState(() {
                _isLoading = false;
              });
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('加载失败: ${error.description}'),
                    action: SnackBarAction(
                      label: '重试',
                      onPressed: () {
                        _webViewController?.reload();
                      },
                    ),
                  ),
                );
              }
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('加载中... ${(_progress * 100).toInt()}%'),
                  if (_progress > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: LinearProgressIndicator(value: _progress),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _webViewController?.dispose();
    super.dispose();
  }
}
