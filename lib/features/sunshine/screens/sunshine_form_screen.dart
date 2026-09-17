import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  static const _types = {'2': '咨询', '3': '建议', '1': '投诉', '4': '表扬'};

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
        setState(() =>
            _error = e is SunshineException ? e.message : '加载填报信息失败，请检查网络后重试');
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
              title: const Text('确认提交诉求'),
              content: Text(
                  '将以 ${_data!.identity.name} 的身份向“${_department!.name}”提交${_types[_type]}：\n\n${_title.text.trim()}\n\n请确认内容真实准确，相同内容请勿重复提交。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('继续编辑')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('确认提交')),
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
      '1' => '您的诉求已受理，感谢您对学校工作的支持。',
      '2' => '平台提示手机号或验证码不正确。请核对手机号；如需验证码，请在阳光服务官网完成验证。',
      'errer' => '该类型问题已提交且正在处理，请勿重复提交。',
      _ => '暂时无法确认是否提交成功，请先到阳光服务官网“与我相关”核实，勿重复提交。本页已暂停再次提交。',
    };
    await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(result == '1' ? '提交成功' : '提交结果'),
              content: Text(message),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('知道了'))
              ],
            ));
    if (result == '1' && mounted) Navigator.pop(context, true);
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? '此项不能为空' : null;

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
          appBar: AppBar(title: const Text('阳光服务填报')),
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
                                  onPressed: _load, child: const Text('重试'))
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
                                  '欢迎为学校建设与发展建言献策。带 * 的栏目为必填项。\n一般问题 1–3 个工作日办复，复杂问题最长不超过 7 个工作日（以平台说明为准）。相同内容请勿重复提交或一信多投。',
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
                                    const InputDecoration(labelText: '信件类别 *'),
                                items: _types.entries
                                    .map((e) => DropdownMenuItem(
                                        value: e.key, child: Text(e.value)))
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => _type = value!),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<SunshineDepartment>(
                                isExpanded: true,
                                initialValue: _department,
                                decoration:
                                    const InputDecoration(labelText: '受理单位 *'),
                                items: _data!.departments
                                    .map((d) => DropdownMenuItem(
                                        value: d,
                                        child: Text(d.name,
                                            overflow: TextOverflow.ellipsis)))
                                    .toList(),
                                validator: (value) =>
                                    value == null ? '请选择受理单位' : null,
                                onChanged: (value) =>
                                    setState(() => _department = value),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                  controller: _title,
                                  maxLength: 50,
                                  decoration:
                                      const InputDecoration(labelText: '主题 *'),
                                  validator: _required),
                              const SizedBox(height: 16),
                              TextFormField(
                                  controller: _content,
                                  minLines: 5,
                                  maxLines: 10,
                                  decoration: const InputDecoration(
                                      labelText: '内容 *',
                                      alignLabelWithHint: true,
                                      hintText: '请描述具体情况及您的诉求'),
                                  validator: _required),
                              const SizedBox(height: 16),
                              TextFormField(
                                initialValue: _data!.identity.name,
                                readOnly: true,
                                decoration:
                                    const InputDecoration(labelText: '姓名 *'),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                  controller: _phone,
                                  readOnly: _data!.identity.phone.isNotEmpty,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                      labelText: '手机号码 *'),
                                  validator: (value) => RegExp(r'^1\d{10}$')
                                          .hasMatch(value?.trim() ?? '')
                                      ? null
                                      : '请输入有效的 11 位手机号'),
                              const SizedBox(height: 16),
                              TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                      labelText: 'Email（选填）'),
                                  validator: (value) => value == null ||
                                          value.trim().isEmpty ||
                                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                              .hasMatch(value.trim())
                                      ? null
                                      : '请输入有效的邮箱地址'),
                              const SizedBox(height: 16),
                              TextFormField(
                                  controller: _date,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                      labelText: '期望解决时间（选填）',
                                      suffixIcon: IconButton(
                                          tooltip: '清除日期',
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
                                        '已阅读填报须知，确认内容真实准确',
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
                                        : const Text(
                                            '提交',
                                            style: TextStyle(
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
