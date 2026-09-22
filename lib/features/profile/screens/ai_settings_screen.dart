import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/ai_provider.dart';
import '../../../core/ai/ai_service.dart';
import '../../../core/utils/l10n_extension.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  late TextEditingController _apiUrlController;
  late TextEditingController _modelController;
  late TextEditingController _apiKeyController;
  bool _obscureApiKey = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final aiState = ref.read(aiAssistantProvider);
    _apiUrlController = TextEditingController(text: aiState.resolvedApiUrl);
    _modelController = TextEditingController(text: aiState.resolvedModel);
    _apiKeyController = TextEditingController(text: aiState.apiKey ?? '');
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    final apiUrl = _apiUrlController.text.trim();
    final model = _modelController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    // 留空表示跟随默认（Worker 中转），由 saveFullSettings 落盘为“清除”。
    await ref.read(aiAssistantProvider.notifier).saveFullSettings(
      apiUrl: apiUrl,
      model: model,
      apiKey: apiKey,
    );

    setState(() {
      _isSaving = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.aiSettingsSaved),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _resetDefaults() async {
    await ref.read(aiAssistantProvider.notifier).resetToDefaults();
    setState(() {
      _apiUrlController.text = AiAssistantService.defaultApiUrl;
      _modelController.text = AiAssistantService.defaultModel;
      _apiKeyController.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.aiSettingsResetDefaults),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      setState(() {
        _apiKeyController.text = data.text!.trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF09C489);
    final aiState = ref.watch(aiAssistantProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.l10n.agentSettings,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF202124),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // API 接口地址 (Base URL) - 校园卡充值同款 Outlined 样式
            TextField(
              controller: _apiUrlController,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : const Color(0xFF202124),
              ),
              decoration: InputDecoration(
                labelText: context.l10n.aiApiUrl,
                labelStyle: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[700],
                  fontSize: 14,
                ),
                hintText: context.l10n.aiApiUrlHint,
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.grey[400],
                ),
                filled: isDark,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: primaryColor, width: 1.5),
                ),
                prefixIcon: Icon(
                  Icons.link_rounded,
                  size: 20,
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 模型名称 (Model Name)
            TextField(
              controller: _modelController,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : const Color(0xFF202124),
              ),
              decoration: InputDecoration(
                labelText: context.l10n.aiModelName,
                labelStyle: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[700],
                  fontSize: 14,
                ),
                hintText: context.l10n.aiModelNameHint,
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.grey[400],
                ),
                filled: isDark,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: primaryColor, width: 1.5),
                ),
                prefixIcon: Icon(
                  Icons.memory_outlined,
                  size: 20,
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // API Key
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureApiKey,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : const Color(0xFF202124),
              ),
              decoration: InputDecoration(
                labelText: aiState.hasCustomApiKey ? context.l10n.aiApiKeyCustom : context.l10n.aiApiKeyDefault,
                labelStyle: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[700],
                  fontSize: 14,
                ),
                hintText: context.l10n.aiApiKeyHint,
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.grey[400],
                ),
                filled: isDark,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: primaryColor, width: 1.5),
                ),
                prefixIcon: Icon(
                  Icons.vpn_key_outlined,
                  size: 20,
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _obscureApiKey
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureApiKey = !_obscureApiKey;
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.paste_rounded,
                        size: 20,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                      tooltip: context.l10n.paste,
                      onPressed: _pasteFromClipboard,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 保存按钮
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        context.l10n.saveSettings,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // 恢复默认配置按钮
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _resetDefaults,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(context.l10n.resetDefaults),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : Colors.grey[700],
                  side: BorderSide(
                    color: isDark ? Colors.white24 : Colors.grey[300]!,
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
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
