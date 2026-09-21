import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/questionnaire_models.dart';
import '../services/questionnaire_service.dart';

/// 学工问卷答题页
class QuestionnaireDetailScreen extends ConsumerStatefulWidget {
  final QuestionnaireItem item;

  const QuestionnaireDetailScreen({super.key, required this.item});

  @override
  ConsumerState<QuestionnaireDetailScreen> createState() =>
      _QuestionnaireDetailScreenState();
}

class _QuestionnaireDetailScreenState
    extends ConsumerState<QuestionnaireDetailScreen> {
  QuestionnaireDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _submitting = false;

  final Map<String, dynamic> _answers = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(questionnaireServiceProvider);
      final detail = await service.fetchDetail(widget.item);
      if (!mounted) return;
      setState(() => _detail = detail);
      // 已提交过的问卷：用服务端返回的上次答案(jg)回填，还原提交时的样子。
      for (final question in detail.questions) {
        final saved = question.answer.trim();
        if (question.isChoice) {
          if (saved.isEmpty) continue;
          String? toDm(String text) {
            for (final option in question.options) {
              if (option.dm == text || option.name == text) return option.dm;
            }
            for (final option in question.options) {
              if (option.name.contains(text) || text.contains(option.name)) {
                return option.dm;
              }
            }
            return null;
          }

          if (question.isMultiChoice) {
            final dms = saved
                .split(RegExp(r'[,，、;；]'))
                .map((e) => toDm(e.trim()))
                .whereType<String>()
                .toList();
            if (dms.isNotEmpty) _answers[question.dm] = dms;
          } else {
            final dm = toDm(saved);
            if (dm != null) _answers[question.dm] = dm;
          }
        } else if (question.isDate) {
          if (saved.isNotEmpty) _answers[question.dm] = saved;
        } else {
          final controller = _controllers.putIfAbsent(
              question.dm, () => TextEditingController());
          if (controller.text.isEmpty && saved.isNotEmpty) {
            controller.text = saved;
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error =
          e is QuestionnaireException ? e.message : '加载失败,请检查网络后重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validate() {
    final detail = _detail;
    if (detail == null) return '问卷数据异常';
    for (final question in detail.questions) {
      if (!question.required) continue;
      final value = _answers[question.dm];
      if (question.isChoice || question.isDate) {
        if (value == null ||
            (value is String && value.trim().isEmpty) ||
            (value is List && value.isEmpty)) {
          return '请填写: ${question.title}';
        }
      } else {
        final text = _controllers[question.dm]?.text.trim() ?? '';
        if (text.isEmpty) return '请填写: ${question.title}';
      }
    }
    return null;
  }

  Map<String, dynamic> _collectAnswers() {
    final result = <String, dynamic>{};
    for (final question in _detail?.questions ?? []) {
      if (question.isChoice || question.isDate) {
        result[question.dm] = _answers[question.dm];
      } else {
        result[question.dm] = _controllers[question.dm]?.text.trim() ?? '';
      }
    }
    return result;
  }

  Future<void> _submit() async {
    final detail = _detail;
    if (detail == null || _submitting) return;
    if (!detail.canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('该问卷当前不可提交'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(questionnaireServiceProvider).submit(
            detail: detail,
            answers: _collectAnswers(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('提交成功'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              e is QuestionnaireException ? e.message : '提交失败,请稍后重试'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickDate(QuestionnaireQuestion question) async {
    DateTime initial = DateTime.now();
    final current = _answers[question.dm];
    if (current is String && current.isNotEmpty) {
      try {
        initial = DateTime.parse(current);
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final text =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() => _answers[question.dm] = text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final detail = _detail;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          detail?.title.isNotEmpty == true ? detail!.title : widget.item.title,
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: theme.scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF09C489)),
            )
          : _error != null && detail == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    ...?detail?.questions
                        .map((q) => _buildQuestion(q, isDark)),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF09C489),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('提交',
                                style: TextStyle(fontSize: 15)),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildQuestion(QuestionnaireQuestion question, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF222222),
              ),
              children: [
                if (question.required)
                  const TextSpan(
                    text: '* ',
                    style: TextStyle(color: Color(0xFFE63476)),
                  ),
                TextSpan(text: question.title),
              ],
            ),
          ),
          if (question.desc.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              question.desc.trim(),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.grey[600],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (question.isChoice)
            _buildChoice(question, isDark)
          else if (question.isDate)
            _buildDateField(question, isDark)
          else
            _buildTextField(question),
        ],
      ),
    );
  }

  Widget _buildChoice(QuestionnaireQuestion question, bool isDark) {
    if (question.isMultiChoice) {
      final selected =
          (_answers[question.dm] as List?)?.map((e) => e.toString()).toSet() ??
              <String>{};
      return Column(
        children: question.options.map((option) {
          final checked = selected.contains(option.dm);
          return CheckboxListTile(
            value: checked,
            onChanged: (value) {
              setState(() {
                final next = Set<String>.from(selected);
                if (value == true) {
                  next.add(option.dm);
                } else {
                  next.remove(option.dm);
                }
                _answers[question.dm] = next.toList();
              });
            },
            title: Text(option.name, style: const TextStyle(fontSize: 14)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: const Color(0xFF09C489),
          );
        }).toList(),
      );
    }

    final groupValue = (_answers[question.dm] ?? '').toString();
    return RadioGroup<String>(
      groupValue: groupValue.isEmpty ? null : groupValue,
      onChanged: (value) =>
          setState(() => _answers[question.dm] = value ?? ''),
      child: Column(
        children: question.options.map((option) {
          return RadioListTile<String>(
            value: option.dm,
            title: Text(option.name, style: const TextStyle(fontSize: 14)),
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: const Color(0xFF09C489),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateField(QuestionnaireQuestion question, bool isDark) {
    final value = (_answers[question.dm] ?? '').toString();
    return InkWell(
      onTap: () => _pickDate(question),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        isEmpty: value.isEmpty,
        decoration: const InputDecoration(
          hintText: '请选择日期',
          filled: false,
          border: OutlineInputBorder(),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          suffixIcon: Icon(Icons.calendar_month_outlined),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(QuestionnaireQuestion question) {
    final controller = _controllers.putIfAbsent(
        question.dm, () => TextEditingController());
    final isMultiline = question.title.contains('地址') ||
        question.title.contains('原因') ||
        question.title.contains('详细');
    return TextField(
      controller: controller,
      maxLines: isMultiline ? 3 : 1,
      minLines: isMultiline ? 3 : 1,
      keyboardType:
          question.isPhone ? TextInputType.phone : TextInputType.text,
      inputFormatters: question.isPhone
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))]
          : null,
      decoration: InputDecoration(
        hintText: question.isPhone ? '请输入电话' : '请输入',
        filled: false,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
