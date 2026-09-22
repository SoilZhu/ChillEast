import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/l10n_extension.dart';
import '../models/sunshine_models.dart';
import '../services/sunshine_service.dart';

class SunshineFormScreen extends ConsumerStatefulWidget {
  const SunshineFormScreen({super.key});
  @override
  ConsumerState<SunshineFormScreen> createState() => _SunshineFormScreenState();
}

class _SunshineFormScreenState extends ConsumerState<SunshineFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _date = TextEditingController();
  SunshineFormData? _data;
  SunshineDepartment? _department;
  String _type = '2';
  bool _loading = true;
  bool _submitting = false;
  bool _locked = false;
  bool _agreed = false;
  String? _error;
  static const _typeKeys = ['2', '3', '1', '4'];

  String _getAppealTypeLabel(BuildContext context, String type) => switch (type) {
        '2' => context.l10n.appealTypeInquiry,
        '3' => context.l10n.appealTypeSuggestion,
        '1' => context.l10n.appealTypeComplaint,
        '4' => context.l10n.appealTypePraise,
        _ => type,
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [_title, _content, _phone, _email, _date]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _getErrorMessage(dynamic e) {
    if (e is SunshineException) {
      if (e.message.contains('暂时不可用')) return context.l10n.sunshineServiceUnavailable;
      if (e.message.contains('未能读取')) return context.l10n.sunshineDataReadFailed;
      if (e.message.contains('格式异常')) return context.l10n.sunshineDataFormatError;
      if (e.message.contains('未找到诉求工单详情')) return context.l10n.sunshineTicketNotFound;
      if (e.message.contains('响应超时')) return context.l10n.sunshineFormTimeout;
      if (e.message.contains('统一认证已过期')) return context.l10n.ssoExpiredRelogin;
      if (e.message.contains('登录已失效')) return context.l10n.sunshineSessionExpired;
      if (e.message.contains('暂无可用受理单位')) return context.l10n.noDepartmentsAvailable;
      return e.message;
    }
    return context.l10n.loadSunshineFormFailed;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref.read(sunshineServiceProvider).fetchForm();
      if (!mounted) return;
      setState(() {
        _data = data;
        _phone.text = data.identity.phone;
        _email.text = data.identity.email;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = _getErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting ||
        _locked ||
        !_agreed ||
        !_formKey.currentState!.validate()) {
      return;
    }
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(context.l10n.confirmSubmitAppeal),
              content: Text(
                  context.l10n.confirmSubmitAppealMessage(
                    _data!.identity.name,
                    _department!.name,
                    _getAppealTypeLabel(context, _type),
                    _title.text.trim(),
                  )),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.l10n.continueEditing)),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(context.l10n.confirmSubmit)),
              ],
            ));
    if (confirmed != true || !mounted) return;
    setState(() => _submitting = true);
    String result;
    try {
      result = await ref.read(sunshineServiceProvider).submit(
            identity: _data!.identity,
            department: _department!,
            type: _type,
            title: _title.text,
            content: _content.text,
            phone: _phone.text,
            email: _email.text,
            finishTime: _date.text,
          );
    } catch (_) {
      result = 'unknown';
    }
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _locked = result != '2';
    });
    final message = switch (result) {
      '1' => context.l10n.appealSubmitSuccessMsg,
      '2' => context.l10n.appealSubmitPhoneCodeInvalidMsg,
      'errer' => context.l10n.appealSubmitDuplicateMsg,
      _ => context.l10n.appealSubmitUnknownMsg,
    };
    await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(result == '1' ? context.l10n.submitSuccess : context.l10n.submitResult),
              content: Text(message),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.gotIt))
              ],
            ));
    if (result == '1' && mounted) Navigator.pop(context, true);
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? context.l10n.fieldCannotBeEmpty : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white24 : const Color(0xFFDADCE0);

    return PopScope(
      canPop: !_submitting,
      child: Theme(
        data: theme.copyWith(
          inputDecorationTheme: InputDecorationTheme(
            filled: false,
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: isDark ? Colors.white12 : const Color(0xFFE8E8E8),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:
                  const BorderSide(color: Color(0xFF09C489), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:
                  const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
        ),
        child: Scaffold(
          appBar: AppBar(title: Text(context.l10n.sunshineFormTitle)),
          body: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF09C489)),
                )
              : _error != null
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!),
                              const SizedBox(height: 12),
                              TextButton(
                                  onPressed: _load, child: Text(context.l10n.retry))
                            ],
                          )))
                  : Form(
                      key: _formKey,
                      child: AbsorbPointer(
                        absorbing: _submitting || _locked,
                        child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 4, bottom: 20),
                                child: Text(
                                  context.l10n.sunshineNotice,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.6,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                              ),
                              DropdownButtonFormField<String>(
                                initialValue: _type,
                                decoration:
                                    InputDecoration(labelText: context.l10n.letterTypeRequired),
                                items: _typeKeys
                                    .map((key) => DropdownMenuItem(
                                        value: key, child: Text(_getAppealTypeLabel(context, key))))
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => _type = value!),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<SunshineDepartment>(
                                isExpanded: true,
                                initialValue: _department,
                                decoration:
                                    InputDecoration(labelText: context.l10n.handlingDepartmentRequired),
                                items: _data!.departments
                                    .map((d) => DropdownMenuItem(
                                        value: d,
                                        child: Text(d.name,
                                            overflow: TextOverflow.ellipsis)))
                                    .toList(),
                                validator: (value) =>
                                    value == null ? context.l10n.pleaseSelectHandlingDepartment : null,
                                onChanged: (value) =>
                                    setState(() => _department = value),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                  controller: _title,
                                  maxLength: 50,
                                  decoration:
                                      InputDecoration(labelText: context.l10n.subjectRequired),
                                  validator: _required),
                              const SizedBox(height: 16),
                              TextFormField(
                                  controller: _content,
                                  minLines: 5,
                                  maxLines: 10,
                                  decoration: InputDecoration(
                                      labelText: context.l10n.contentRequired,
                                      alignLabelWithHint: true,
                                      hintText: context.l10n.appealContentHint),
                                  validator: _required),
                              const SizedBox(height: 16),
                              TextFormField(
                                initialValue: _data!.identity.name,
                                readOnly: true,
                                decoration:
                                    InputDecoration(labelText: context.l10n.nameRequired),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                  controller: _phone,
                                  readOnly: _data!.identity.phone.isNotEmpty,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                      labelText: context.l10n.phoneRequired),
                                  validator: (value) => RegExp(r'^1\d{10}$')
                                          .hasMatch(value?.trim() ?? '')
                                      ? null
                                      : context.l10n.pleaseEnterValidPhone),
                              const SizedBox(height: 16),
                              TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                      labelText: context.l10n.emailOptional),
                                  validator: (value) => value == null ||
                                          value.trim().isEmpty ||
                                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                              .hasMatch(value.trim())
                                      ? null
                                      : context.l10n.pleaseEnterValidEmail),
                              const SizedBox(height: 16),
                              TextFormField(
                                  controller: _date,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                      labelText: context.l10n.expectedResolveTimeOptional,
                                      suffixIcon: IconButton(
                                          tooltip: context.l10n.clearDate,
                                          onPressed: () => _date.clear(),
                                          icon: const Icon(Icons.clear,
                                              size: 18))),
                                  onTap: () async {
                                    final now =
                                        DateUtils.dateOnly(DateTime.now());
                                    final selected = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            DateTime.tryParse(_date.text) ??
                                                now,
                                        firstDate: now,
                                        lastDate: DateTime(now.year + 5));
                                    if (selected != null && mounted) {
                                      _date.text =
                                          '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
                                    }
                                  }),
                              const SizedBox(height: 16),
                              // MD2 规范真实准确确认选项
                              InkWell(
                                onTap: () =>
                                    setState(() => _agreed = !_agreed),
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: Checkbox(
                                          value: _agreed,
                                          activeColor: const Color(0xFF09C489),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                          side: BorderSide(
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.black54,
                                            width: 1.5,
                                          ),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          onChanged: (value) => setState(
                                              () => _agreed = value ?? false),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        context.l10n.readNoticeAgreement,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // 右对齐的圆角矩形提交按钮，只保留《提交》
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton(
                                    onPressed: _agreed && !_submitting && !_locked
                                        ? _submit
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF09C489),
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: isDark
                                          ? Colors.white.withValues(alpha: 0.12)
                                          : const Color(0xFFE0E0E0),
                                      disabledForegroundColor: isDark
                                          ? Colors.white38
                                          : Colors.black26,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 10),
                                      minimumSize: const Size(88, 38),
                                    ),
                                    child: _submitting
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            context.l10n.submit,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                            ]),
                      )),
        ),
      ),
    );
  }
}
