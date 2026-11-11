import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';
import '../utils/l10n_extension.dart';

class UpdateScreen extends StatelessWidget {
  final String version;
  final String releaseNotes;
  final String downloadUrl;
  final bool isForceUpdate;

  const UpdateScreen({
    super.key,
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
    this.isForceUpdate = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return PopScope(
      canPop: !isForceUpdate,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: isForceUpdate
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 纯图标，左对齐
                    Icon(
                      Icons.system_update_rounded,
                      size: 38,
                      color: primaryColor,
                    ),
                    const SizedBox(height: 16),

                    // 发现新版本标题，左对齐
                    Text(
                      context.l10n.foundNewVersion(version),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                  // 更新日志标题
                  Text(
                    context.l10n.releaseNotes,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 更新日志直接展示，不加外框，支持 Markdown 渲染
                  MarkdownBody(
                    data: releaseNotes,
                    selectable: true,
                    shrinkWrap: true,
                    onTapLink: (text, href, title) async {
                      if (href != null) {
                        final Uri uri = Uri.parse(href);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      }
                    },
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: isDark ? const Color(0xFFD0D0D0) : const Color(0xFF3C4043),
                      ),
                      h1: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF202124),
                      ),
                      h2: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF202124),
                      ),
                      h3: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF202124),
                      ),
                      listBullet: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : const Color(0xFF5F6368),
                      ),
                      a: TextStyle(
                        color: primaryColor,
                        decoration: TextDecoration.underline,
                      ),
                      code: TextStyle(
                        fontSize: 12.5,
                        backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                        color: primaryColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 底部操作栏：小圆角矩形，右对齐，去掉“以后再说”
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    final route = ModalRoute.of(context);
                    await UpdateService().startDownload(
                      context,
                      downloadUrl,
                      version,
                      isForceUpdate: isForceUpdate,
                    );
                    if (!isForceUpdate && route != null && nav.mounted) {
                      nav.removeRoute(route);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    context.l10n.updateNow,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
