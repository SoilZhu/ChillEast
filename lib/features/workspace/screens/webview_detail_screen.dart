import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/cookie_manager.dart';
import '../../../core/utils/secure_storage_helper.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'dart:collection';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'scanner_screen.dart';

/// WebView 详情页 - 终极重构版（带小程序胶囊菜单）
class WebViewDetailScreen extends StatefulWidget {
  final String title;
  final String url;
  final bool showAppBar;
  final bool showWebBack;
  final String? userAgent;
  final String? targetUrl;
  final String? autoClickText;
  final Color? appBarColor;

  const WebViewDetailScreen({
    super.key,
    required this.title,
    required this.url,
    this.showAppBar = true,
    this.showWebBack = false,
    this.userAgent,
    this.targetUrl,
    this.autoClickText,
    this.appBarColor,
  });

  @override
  State<WebViewDetailScreen> createState() => _WebViewDetailScreenState();
}

class _WebViewDetailScreenState extends State<WebViewDetailScreen> {
  final Logger _logger = Logger();
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  double _progress = 0;
  String? _errorMessage;
  Timer? _loadTimeoutTimer;

  static const int _loadTimeoutSeconds = 60; // 适当延长 SSO 超时

  @override
  void initState() {
    super.initState();
    _startLoadTimeout();
  }

  void _startLoadTimeout() {
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = Timer(Duration(seconds: _loadTimeoutSeconds), () {
      if (_isLoading && mounted) {
        setState(() {
          _errorMessage = '加载超时，可能是校内网络响应缓慢。';
          _isLoading = false;
        });
      }
    });
  }

  void _cancelLoadTimeout() {
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.appBarColor ?? Colors.white;
    // 判断亮度，决定图标颜色
    final isDarkBackground = bgColor.computeLuminance() < 0.5;
    final iconColor = isDarkBackground ? Colors.white : Colors.black87;
    final dividerColor = isDarkBackground ? Colors.white24 : Colors.black12;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.showAppBar ? AppBar(
        backgroundColor: bgColor,
        foregroundColor: iconColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false, // 禁用自动推断的返回按钮
        title: const Text(''),
        centerTitle: true,
        leadingWidth: widget.showWebBack ? 70 : 0, // 动态调节宽度
        leading: widget.showWebBack ? Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: Container(
              height: 32,
              width: 44,
              decoration: BoxDecoration(
                color: isDarkBackground ? Colors.white.withOpacity(0.15) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: dividerColor, width: 0.5),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: iconColor),
                onPressed: () async {
                  if (_webViewController != null && await _webViewController!.canGoBack()) {
                    _webViewController!.goBack();
                  } else {
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ),
          ),
        ) : null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: isDarkBackground ? Colors.white.withOpacity(0.15) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: dividerColor, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _webViewController?.reload(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.refresh_rounded, size: 18, color: iconColor),
                    ),
                  ),
                  Container(width: 0.5, height: 16, color: dividerColor),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.close_rounded, size: 18, color: iconColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ) : null,
      body: Column(
        children: [
          // 填充状态栏
          if (!widget.showAppBar)
            Container(
              height: MediaQuery.of(context).padding.top,
              color: bgColor,
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
        child: FutureBuilder<String?>(
        future: SecureStorageHelper().getToken(),
        builder: (context, snapshot) {
          final token = snapshot.data;
          
          return Stack(
            children: [
              // WebView 主体
              Padding(
                padding: EdgeInsets.zero,
                child: InAppWebView(
                  initialUserScripts: UnmodifiableListView<UserScript>([
                    if (token != null)
                      UserScript(
                        source: "try { localStorage.setItem('token', '$token'); sessionStorage.setItem('token', '$token'); } catch(e) {}",
                        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                      ),
                    // 🛠️ 终极修复：基于源码实现的超星标准安卓桥接器
                    UserScript(
                      source: """
                        (function() {
                          const url = window.location.href;
                          if (!url.includes('chaoxing.com') && !url.includes('hunau.edu.cn') && !url.includes('zhanyun.org')) {
                            return;
                          }
                          console.log("🚀 Injecting Official CX Android Bridge...");
                          
                          // 1. 定义安卓原生注入对象
                          window.androidjsbridge = {
                            postNotification: function(name, userInfo) {
                              console.log("📥 [Native-Bridge] Incoming: " + name + " -> " + userInfo);
                              // 将信息转发给 Flutter 处理器
                              window.flutter_inappwebview.callHandler('postNotification', {
                                name: name,
                                userInfo: JSON.parse(userInfo)
                              });
                            }
                          };
                          
                          // 2. 强制设置设备类型为 android (见 CXJSBridge.js 第 68 行)
                          // 循环探测直到 jsBridge 对象被创建
                          var probeCount = 0;
                          var timer = setInterval(function() {
                            if (window.jsBridge) {
                              window.jsBridge.setDevice('android');
                              console.log("✅ Device set to Android, JSBridge Ready!");
                              clearInterval(timer);
                            }
                            if (++probeCount > 50) clearInterval(timer);
                          }, 100);
                        })();
                      """,
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    ),
                    // 🛠️ 终极修复：手工注入全功能超星 JSBridge 模拟对象
                    UserScript(
                      source: """
                        (function() {
                          const url = window.location.href;
                          if (!url.includes('chaoxing.com') && !url.includes('hunau.edu.cn') && !url.includes('zhanyun.org')) {
                            return;
                          }
                          console.log("🚀 Injecting CXJSBridge Mock...");
                          window.chaoxing = true;
                          window.is_chaoxing = true;
                          
                          // 定义标准的 CXJSBridge 对象
                          var mockBridge = {
                            version: '1.2.0',
                            // 网页发送脉冲后的确认函数
                            onPushNotification: function(id) {
                              console.log("🛠️ MockBridge received pulse acknowledge: " + id);
                            },
                            // 通用的原生调用入口
                            callNative: function(method, args, callback) {
                              console.log("🛠️ MockBridge calling native: " + method);
                              window.flutter_inappwebview.callHandler(method, args).then(function(res) {
                                if (callback) callback(res);
                              });
                            },
                            // 某些页面直接使用这些速记方法
                            cx_scan: function(args) {
                              window.cx_scan(args);
                            }
                          };
                          
                          window.CXJSBridge = mockBridge;
                          
                          // 补丁：速记方法
                          window.cx_scan = function(args) {
                            window.flutter_inappwebview.callHandler('cx_scan', args).then(function(res) {
                              if(window.cx_scan_callback) window.cx_scan_callback(res.result);
                              // 也要尝试回调给可能存在的其它 JS 变量
                              if(window.onReceiveResult) window.onReceiveResult(res.result);
                            });
                          };
                          
                          window.cx_uploadImage = function(args) {
                            window.flutter_inappwebview.callHandler('cx_uploadImage', args);
                          };
                          
                          console.log("✅ CXJSBridge Mock Injected Successfully");
                        })();
                      """,
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    ),
                  ]),
                  initialSettings: InAppWebViewSettings(
                    mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                    useShouldOverrideUrlLoading: true,
                    mediaPlaybackRequiresUserGesture: false,
                    javaScriptCanOpenWindowsAutomatically: true,
                    supportZoom: true,
                    builtInZoomControls: true,
                    displayZoomControls: false,
                    userAgent: widget.userAgent ?? (widget.url.contains('17wanxiao') 
                        ? 'Mozilla/5.0 (Linux; Android 13; Build/TP1A.220624.014; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/121.0.6167.178 Mobile Safari/537.36 Wanxiao/6.0.2'
                        : (widget.url.contains('chaoxing.com')
                            ? 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36 (device:MEIZU 20) Language/zh_CN com.chaoxing.mobile.hunannongyedaxue/ChaoXingStudy_1000257_5.3_android_phone_53_234 (Kalimdor)'
                            : 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36')),
                    allowsInlineMediaPlayback: true,
                    loadWithOverviewMode: true,
                    allowFileAccessFromFileURLs: true,
                    allowUniversalAccessFromFileURLs: true,
                    minimumFontSize: 10,
                    defaultFixedFontSize: 16,
                  ),
                  onWebViewCreated: (controller) async {
                    _webViewController = controller;
                    _logger.i('🌐 Starting WebView for: ${widget.title}');

                    // 🛠️ 监听超星标准的 postNotification 调用
                    controller.addJavaScriptHandler(
                      handlerName: 'postNotification',
                      callback: (args) async {
                        final data = args[0];
                        final String name = data['name'];
                        final Map userInfo = data['userInfo'] ?? {};
                        _logger.i('💡 [JSBridge] Request: $name, data: $userInfo');
                        
                        // 1. 处理页面跳转
                        if (name == 'CLIENT_OPEN_URL') {
                          final String? webUrl = userInfo['webUrl'];
                          if (webUrl != null) {
                            final cleanUrl = webUrl.replaceAll('#INNER', '');
                            _logger.i('🔗 [JSBridge] Navigating to: $cleanUrl');
                            // 在当前 WebView 中加载新 URL
                            controller.loadUrl(urlRequest: URLRequest(url: WebUri(cleanUrl)));
                            return null;
                          }
                        }

                        // 2. 处理扫一扫指令
                        // 1. 标准超星指令名: clientScan / cx_scan
                        // 2. 本页面实际指令名 (见日志): CLIENT_BARCODE_SCANNER
                        if (name == 'clientScan' || name == 'cx_scan' || name == 'CLIENT_BARCODE_SCANNER') {
                          final result = await _openScanner();
                          if (result != null) {
                            final resultsJS = """
                              if(window.jsBridge) {
                                const dataObj = { 
                                  message: '$result', 
                                  result: '$result', 
                                  barcode: '$result' 
                                };
                                console.log("📤 [Native-Bridge] Result delivered to web");
                                jsBridge.trigger('CLIENT_BARCODE_SCANNER', dataObj);
                                jsBridge.trigger('CLIENT_BARCODE_SCANNER_RESULT', dataObj);
                              }
                              if(window.onReceiveResult) try { window.onReceiveResult('$result'); } catch(e) {}
                            """;
                            _webViewController?.evaluateJavascript(source: resultsJS);
                          }
                        } else if (name == 'CLIENT_CHOOSE_IMAGE') {
                          // 处理拍照或选择图片
                          final isCamera = userInfo['camare'] == '5';
                          final picker = ImagePicker();
                          final XFile? image = await picker.pickImage(
                            source: isCamera ? ImageSource.camera : ImageSource.gallery,
                            maxWidth: 1024,
                            maxHeight: 1024,
                            imageQuality: 80,
                          );

                          if (image != null) {
                            final bytes = await image.readAsBytes();
                            final base64Image = "data:image/jpeg;base64,${base64.encode(bytes)}";
                            
                            final resultsJS = """
                              console.log("📤 [Native-Bridge] Image captured, sending to web...");
                              if(window.jsBridge) {
                                const dataObj = { 
                                  message: '$base64Image', 
                                  result: true,
                                  filePairs: [{ id: '1', filePath: '$base64Image' }] 
                                };
                                jsBridge.trigger('CLIENT_CHOOSE_IMAGE', dataObj);
                              }
                            """;
                            _webViewController?.evaluateJavascript(source: resultsJS);
                          }
                        }
                        return null;
                      },
                    );

                    // 保留 cx_scan 速记回调 (部分页面可能不走标准 bridge)
                    controller.addJavaScriptHandler(
                      handlerName: 'cx_scan',
                      callback: (args) async {
                        final result = await _openScanner();
                        return {'result': result};
                      },
                    );

                    // 2. 相机/相册功能 (多用于上传证件照等)
                    controller.addJavaScriptHandler(
                      handlerName: 'cx_uploadImage',
                      callback: (args) async {
                        _logger.i('🖼️ JavaScript calling cx_uploadImage');
                        final result = await _pickImage();
                        return result;
                      },
                    );

                    // 3. 通用通讯 (兼容 legacy 模式)
                    controller.addJavaScriptHandler(
                      handlerName: 'CXJSBridge',
                      callback: (args) {
                        _logger.i('🔌 CXJSBridge called with: $args');
                        return null;
                      },
                    );

                    if (widget.url.isNotEmpty) {
                      // 重要：同步多域名 Cookie 才能通过 WebVPN
                      await AppCookieManager().syncMultiDomainCookiesFromWebView();
                      await controller.loadUrl(urlRequest: URLRequest(url: WebUri(widget.url)));
                    }
                  },
                  onLoadStart: (controller, url) {
                    setState(() { 
                      _isLoading = true; 
                      _errorMessage = null; 
                      _progress = 0;
                    });
                    _startLoadTimeout();
                    _logger.d('🛫 Loading: $url');
                  },
                  onLoadStop: (controller, url) async {
                    _cancelLoadTimeout();
                    
                    final urlString = url?.toString() ?? '';
                    
                    // 如果设置了目标 URL，只有到达目标后才关闭加载动画
                    if (widget.targetUrl != null) {
                      if (urlString.contains(widget.targetUrl!)) {
                        setState(() => _isLoading = false);
                      }
                    } else {
                      setState(() => _isLoading = false);
                    }
                    
                    // 针对报修系统的特殊处理：强制跳转到手机端页面
                    if (urlString.contains('bxpt.hunau.edu.cn/relax') && 
                        !urlString.contains('/mobile/') && 
                        !urlString.contains('ticket=') &&
                        !urlString.contains('cas/login')) {
                      _logger.i('🔄 Detecting repairs system PC mode, forcing mobile redirect...');
                      await controller.evaluateJavascript(source: "window.location.href = '/relax/mobile/index.html';");
                      return;
                    }

                    // ✨ 新增：自动化点击逻辑 (如：付款码)
                    if (widget.autoClickText != null && urlString.contains('homeCX/openHomePage')) {
                      _logger.i('🤖 Searching for auto-click element: ${widget.autoClickText}');
                      final js = """
                        (function() {
                          const text = '${widget.autoClickText}';
                          const links = Array.from(document.querySelectorAll('a'));
                          const target = links.find(a => a.innerText.includes(text));
                          if (target) {
                            console.log('✅ Found target link, jumping...');
                            // 优先直接修改 location 以确保快速响应
                            window.location.href = target.getAttribute('href');
                          } else {
                            console.warn('❌ Target link not found: ' + text);
                          }
                        })();
                      """;
                      await controller.evaluateJavascript(source: js);
                      // 注意：这里不要设置 _isLoading = false，因为我们要等待跳转到 targetUrl
                      return;
                    }

                    if (urlString.contains('authorize') || urlString.contains('login') || urlString.contains('ticket=')) {
                      await controller.evaluateJavascript(source: """
                        (function() {
                          const keywords = ['授权', '同意', '进入', '确认', 'Continue', 'Authorize', 'Confirm'];
                          const btns = Array.from(document.querySelectorAll('button, a, input[type="button"]'));
                          const target = btns.find(el => {
                            const t = (el.innerText || el.value || '').trim();
                            return keywords.some(k => t.includes(k));
                          });
                          if (target) target.click();
                        })();
                      """);
                    }
                  },
                  onProgressChanged: (controller, progress) {
                    setState(() => _progress = progress / 100);
                  },
                  onReceivedError: (controller, request, error) {
                    final url = request.url.toString();
                    if (url.startsWith('http')) {
                      _logger.e('❌ [WebView-Error] ${error.description}');
                    }
                  },
                  onJsPrompt: (controller, jsPromptRequest) async {
                    // 🛠️ 核心修复：拦截超星 JSBridge 的消息通讯 (通过 prompt)
                    final message = jsPromptRequest.message;
                    _logger.i('💬 JS Prompt caught: $message');
                    
                    if (message != null && (message.contains('cx_scan') || message.contains('Scanner'))) {
                      final code = await _openScanner();
                      return JsPromptResponse(
                        handledByClient: true,
                        value: code,
                      );
                    }
                    
                    // 其他通用处理 (可以根据内容进一步解析 JSON)
                    return JsPromptResponse(handledByClient: false);
                  },
                  onConsoleMessage: (controller, consoleMessage) {
                    _logger.d('📢 [Web-Console] ${consoleMessage.message}');
                  },
                  onPermissionRequest: (controller, request) async {
                    _logger.i('📸 WebView requesting permissions: ${request.resources}');
                    return PermissionResponse(
                      resources: request.resources,
                      action: PermissionResponseAction.GRANT,
                    );
                  },
                  onGeolocationPermissionsShowPrompt: (controller, origin) async {
                    _logger.i('📍 WebView requesting geolocation permission for: $origin');
                    return GeolocationPermissionShowPromptResponse(
                      origin: origin,
                      allow: true,
                      retain: true,
                    );
                  },
                  onCreateWindow: (controller, createWindowAction) async {
                    _logger.i('🪟 New window request: ${createWindowAction.request.url}');
                    if (createWindowAction.request.url != null) {
                      await controller.loadUrl(urlRequest: createWindowAction.request);
                    }
                    return true;
                  },
                  shouldOverrideUrlLoading: (controller, navigationAction) async {
                    var uri = navigationAction.request.url;
                    if (uri != null) {
                      final urlString = uri.toString();
                      final scheme = uri.scheme;

                      // 1. 处理非 HTTP/HTTPS 协议 (如 weixin://, alipays://, tel:, chaoxing://)
                      if (scheme != 'http' && scheme != 'https') {
                        // 🛠️ 特殊处理：拦截 jsbridge 协议 (超星 Legacy 模式)
                        if (scheme == 'jsbridge' || scheme == 'chaoxing') {
                          _logger.i('🔗 Intercepting JSBridge pulse: $urlString');
                          
                          // 1. 解析 Notification ID (形如 jsbridge://postnotificationwithid-1)
                          if (urlString.contains('postnotificationwithid-')) {
                            final parts = urlString.split('postnotificationwithid-');
                            if (parts.length > 1) {
                              final notificationId = parts[1];
                              // ⚠️ 关键修复：超星有些版本需要带前缀的 ID 才能触发后续的 prompt
                              final callbackIds = [
                                "postnotificationwithid-$notificationId", 
                                "id-$notificationId", 
                                notificationId
                              ];
                              for (var cbId in callbackIds) {
                                // ⚠️ 穷举所有可能的消息回传函数
                                final js = """
                                  if(window.CXJSBridge) {
                                    if(CXJSBridge.onPushNotification) CXJSBridge.onPushNotification('$cbId');
                                    if(CXJSBridge._onPushNotification) CXJSBridge._onPushNotification('$cbId');
                                    if(CXJSBridge.handleMessageFromNative) {
                                       try { CXJSBridge.handleMessageFromNative({notificationId: '$cbId', status: true}); } catch(e) {}
                                    }
                                  }
                                """;
                                controller.evaluateJavascript(source: js);
                              }
                            }
                          }
                          
                          // 2. 拦截并处理 notificationready (握手成功信号)
                          if (urlString.contains('notificationready')) {
                             _logger.i('✅ JSBridge notificationready confirmed');
                          }
                          
                          // 2. 传统扫描关键字兜底 (有些老页面直接带 scan)
                          if (urlString.contains('scan') || urlString.contains('Scanner')) {
                             _openScanner().then((code) {
                               if (code != null) {
                                 controller.evaluateJavascript(source: "if(window.cx_scan_callback) window.cx_scan_callback('$code');");
                               }
                             });
                          }
                          return NavigationActionPolicy.CANCEL;
                        }

                        _logger.i('🚀 Detecting custom scheme: $scheme, trying to launch externally...');
                        try {
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        } catch (e) {
                          _logger.w('⚠️ Failed to launch custom scheme: $urlString');
                        }
                        return NavigationActionPolicy.CANCEL;
                      }



                      // 3. 域名白名单控制 (仅限 HTTP/HTTPS)
                      final whiteList = [
                        'hunau.edu.cn',
                        'chaoxing.com',
                        'learn.chaoxing.com',
                        'busrise.cn',
                        '17wanxiao.com',   // 完美校园，用于校内充值/校园卡等业务
                        'alipay.com',      // 支付宝支付
                        'tenpay.com',      // 微信支付相关
                        'authorize',       // OAuth 授权路径片段
                        'login'            // 登录路径片段
                      ];

                      bool isAllowed = whiteList.any((domain) => urlString.contains(domain));
                      
                      if (!isAllowed) {
                        _logger.w('🛑 Blocking unauthorized navigation to: $urlString');
                        return NavigationActionPolicy.CANCEL;
                      }
                    }
                    return NavigationActionPolicy.ALLOW;
                  },
                ),
              ),

              // 进度条
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

              // 3. 全屏加载占位层 (当 _isLoading 为 true 时始终挡住 WebView)
              if (_isLoading)
                Container(
                  color: Colors.white,
                  child: const Center(child: CircularProgressIndicator()),
                ),

              if (_errorMessage != null)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() { _errorMessage = null; _isLoading = true; });
                          _webViewController?.reload();
                        },
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              
              // 🟢 浮动返回胶囊 (仅在没有 AppBar 且 showWebBack 为 true 时显示)
              if (!widget.showAppBar && widget.showWebBack)
                Positioned(
                  top: 8,
                  left: 16,
                  child: Container(
                    height: 32,
                    width: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12, width: 0.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.black87),
                      onPressed: () async {
                        if (_webViewController != null && await _webViewController!.canGoBack()) {
                          _webViewController!.goBack();
                        } else {
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ),

              // 🔴 浮动功能胶囊 (仅在没有 AppBar 时显示)
              if (!widget.showAppBar)
                Positioned(
                  top: 8,
                  right: 16,
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12, width: 0.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _webViewController?.reload(),
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
            ],
          );
        },
      ),
            ), // PopScope
          ), // Expanded
        ], // Column children
      ), // Column
    ); // Scaffold
  }

  /// 打开原生扫码界面
  Future<String?> _openScanner() async {
    return await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );
  }

  /// 原生图片选择 (返回 Base64 或特定格式)
  Future<Map<String, dynamic>?> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final file = await picker.pickImage(source: source, maxWidth: 1024, imageQuality: 80);
      if (file != null) {
        // 这里根据实际 JS 需要返回，通常是回调给 JS 文件的路径或 Base64
        return {
          'path': file.path,
          'name': file.name,
        };
      }
    }
    return null;
  }

  @override
  void dispose() {
    _cancelLoadTimeout();
    super.dispose();
  }
}
