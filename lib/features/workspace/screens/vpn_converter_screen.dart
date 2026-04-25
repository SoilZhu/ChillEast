import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:typed_data';

// 使用前缀导入 PointyCastle 以彻底解决命名冲突并确保所有组件可用
import 'package:pointycastle/export.dart' as pc;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../core/utils/app_logger.dart';

/// WebVPN 链接转换器 - 原生 UI 版
class VpnConverterScreen extends StatefulWidget {
  const VpnConverterScreen({super.key});

  @override
  State<VpnConverterScreen> createState() => _VpnConverterScreenState();
}

class _VpnConverterScreenState extends State<VpnConverterScreen> {
  final TextEditingController _urlController = TextEditingController();
  final _logger = AppLogger.instance;
  String _convertedUrl = '';
  
  // 配置信息
  final String _keyAndIv = "wwwvpnisthebest!";
  final String _vpnDomain = "webvpn.hunau.edu.cn";

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  /// AES-CFB-128 加密实现
  String _encryptVpnHost(String host) {
    final keyBytes = Uint8List.fromList(utf8.encode(_keyAndIv));
    final ivBytes = Uint8List.fromList(utf8.encode(_keyAndIv));
    
    // 16 字节对齐补齐 (参考 TS 的 textRightAppend)
    String paddedHost = host;
    if (host.length % 16 != 0) {
      paddedHost += '0' * (16 - (host.length % 16));
    }
    final plainBytes = Uint8List.fromList(utf8.encode(paddedHost));

    // 使用 CFBBlockCipher (AES 引擎)
    // 根据 PointyCastle 最新实践，使用 pc.AESEngine()
    final cipher = pc.CFBBlockCipher(pc.AESEngine(), 16)
      ..init(true, pc.ParametersWithIV(pc.KeyParameter(keyBytes), ivBytes));

    final encryptedBytes = Uint8List(plainBytes.length);
    var offset = 0;
    while (offset < plainBytes.length) {
      // processBlock 返回处理的字节数
      offset += cipher.processBlock(plainBytes, offset, encryptedBytes, offset);
    }

    // 转换为 Hex
    String ivHex = _toHex(ivBytes);
    // TS 逻辑：hex(iv) + hex(encrypted).slice(0, host.length * 2)
    String encryptedHex = _toHex(encryptedBytes).substring(0, host.length * 2);

    return ivHex + encryptedHex;
  }

  String _toHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// 转换流程主逻辑
  void _convert() {
    String input = _urlController.text.trim();
    if (input.isEmpty) {
      if (mounted) {
        setState(() {
          _convertedUrl = '';
        });
      }
      return;
    }

    try {
      String url = input;
      String protocol = 'http';
      final knownProto = ['http', 'https', 'ssh', 'vnc', 'telnet', 'rdp'];

      // 提取协议
      for (var proto in knownProto) {
        if (url.toLowerCase().startsWith('$proto://')) {
          protocol = proto;
          url = url.substring(proto.length + 3);
          break;
        }
      }

      // 处理 IPv6
      String v6 = '';
      final v6Match = RegExp(r'^\[[0-9a-fA-F:]+\]').firstMatch(url);
      if (v6Match != null) {
        v6 = v6Match.group(0)!;
        url = url.substring(v6.length);
      }

      // 处理端口
      String port = '';
      final domainPlusPath = url;
      final firstSlash = domainPlusPath.indexOf('/');
      String hostPart = firstSlash == -1 ? domainPlusPath : domainPlusPath.substring(0, firstSlash);
      String pathPart = firstSlash == -1 ? '' : domainPlusPath.substring(firstSlash);

      if (hostPart.contains(':')) {
        final parts = hostPart.split(':');
        hostPart = parts[0];
        port = parts[1];
      }

      // 还原 host (IPv6 优先级)
      String finalHost = v6.isNotEmpty ? v6 : hostPart;
      
      // 加密 host
      String encryptedHost = _encryptVpnHost(finalHost);

      // 拼接路径
      String resultPath = '';
      if (port.isNotEmpty) {
        resultPath = '/$protocol-$port/$encryptedHost$pathPart';
      } else {
        resultPath = '/$protocol/$encryptedHost$pathPart';
      }

      if (mounted) {
        setState(() {
          _convertedUrl = 'https://$_vpnDomain$resultPath';
        });
      }
    } catch (e) {
      _logger.e('URL Conversion Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('转换失败: $e')),
        );
      }
    }
  }

  Future<void> _openInBrowser() async {
    if (_convertedUrl.isEmpty) return;
    
    try {
      await InAppBrowser.openWithSystemBrowser(url: WebUri(_convertedUrl));
    } catch (e) {
      _logger.e('Open Browser Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('跳转浏览器失败')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('WebVPN 转换器'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // 顶部横幅 - MD2 风格提示
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Color(0xFF5F6368), size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '将普通校内链接转换为 WebVPN 链接，以便在校外直接访问。',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF5F6368),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // MD2 风格输入框 (带悬浮标签)
              TextField(
                controller: _urlController,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  labelText: '原始地址',
                  labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                  floatingLabelStyle: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w500),
                  hintText: 'https://jwxt.hunau.edu.cn/...',
                  hintStyle: TextStyle(color: Colors.grey[350], fontSize: 14),
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Colors.grey[400]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Colors.grey[400]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste_outlined, size: 20),
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        _urlController.text = data!.text!;
                        _convert();
                      }
                    },
                  ),
                ),
                onChanged: (_) => _convert(),
              ),
              
              const SizedBox(height: 40),
              
              // 转换结果展示
              if (_convertedUrl.isNotEmpty) ...[
                const Text(
                  '转换结果',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF202124),
                    letterSpacing: 0.25,
                  ),
                ),
                const SizedBox(height: 12),
                
                // 代码块样式的链接显示
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SelectableText(
                    _convertedUrl,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Color(0xFF1967D2),
                      height: 1.4,
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // 右对齐的动作按钮栏
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _convertedUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已复制到剪贴板'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      label: const Text('复制'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF5F6368),
                        side: const BorderSide(color: Color(0xFFDADCE0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _openInBrowser,
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('访问'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // 未输入时的占位
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      Icon(Icons.link_off_outlined, size: 48, color: Colors.grey[200]),
                      const SizedBox(height: 16),
                      Text(
                        '在上方粘贴链接以开始转换',
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}
