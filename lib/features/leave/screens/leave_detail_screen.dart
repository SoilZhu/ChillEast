import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/leave_models.dart';
import '../services/leave_service.dart';

/// 请假单详情（只读）
class LeaveDetailScreen extends ConsumerStatefulWidget {
  final LeaveRecord item;

  const LeaveDetailScreen({super.key, required this.item});

  @override
  ConsumerState<LeaveDetailScreen> createState() => _LeaveDetailScreenState();
}

class _LeaveDetailScreenState extends ConsumerState<LeaveDetailScreen> {
  LeaveDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail =
          await ref.read(leaveServiceProvider).fetchRecord(widget.item.id);
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (e) {
      if (!mounted) return;
      setState(() =>
          _error = e is LeaveException ? e.message : '加载失败,请检查网络后重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final base = Theme.of(context);
        return Theme(
          data: ThemeData.from(
            colorScheme: base.colorScheme,
            useMaterial3: false,
          ),
          child: AlertDialog(
            title: const Text('撤销请假?'),
            content: const Text('确定撤销这条请假申请吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('撤销',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
    );
    if (confirm != true || _deleting) return;
    setState(() => _deleting = true);
    try {
      await ref.read(leaveServiceProvider).delete(widget.item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已撤销'), behavior: SnackBarBehavior.floating),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is LeaveException ? e.message : '撤销失败,请稍后重试'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  /// 详情 JSON 形状按表单字段容错读取（对象取文本/名称，列表拼接）。
  String _str(String key) {
    final value = _detail?.raw[key];
    if (value == null) return '';
    if (value is Map) {
      for (final k in ['text', 'mc', 'name', 'label']) {
        if (value[k] != null && value[k].toString().isNotEmpty) {
          return value[k].toString();
        }
      }
      if (value['dm'] != null) return value['dm'].toString();
      return '';
    }
    if (value is List) {
      return value
          .map((e) => e is Map
              ? (e['text'] ?? e['mc'] ?? e['name'] ?? e['dm'] ?? '').toString()
              : e.toString())
          .where((e) => e.isNotEmpty)
          .join('、');
    }
    return value.toString();
  }

  String _switchLabel(String key) => _str(key) == '1' ? '是' : '否';

  String _durationText() {
    final ts = _str('ts');
    final hour = _str('hour');
    if (ts.isEmpty && hour.isEmpty) return widget.item.durationLabel;
    final parts = <String>[];
    if (ts.isNotEmpty && ts != '0') parts.add('$ts天');
    if (hour.isNotEmpty && hour != '0') parts.add('$hour小时');
    final text = parts.join('');
    return text.isEmpty ? widget.item.durationLabel : text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final item = widget.item;

    final rows = <MapEntry<String, String>>[
      MapEntry('请假类别', _str('qjlx').isEmpty ? item.typeName : _str('qjlx')),
      MapEntry('开始时间', _str('kssj').isEmpty ? item.startTime : _str('kssj')),
      MapEntry('结束时间', _str('jssj').isEmpty ? item.endTime : _str('jssj')),
      MapEntry('请假时长', _durationText()),
      MapEntry('请假事由', _str('qjsy').isEmpty ? item.reason : _str('qjsy')),
      MapEntry('紧急联系人', _str('lxr')),
      MapEntry('联系人电话', _str('lxrdh')),
      MapEntry('同行人员', _str('txry')),
      MapEntry('是否离校', _switchLabel('lxInd')),
      MapEntry('离校去向', _str('lxqx')),
      MapEntry('详细地址', _str('lxMdd')),
      MapEntry('回宿舍', _switchLabel('huisusheInd')),
      MapEntry('备注', _str('lxBz')),
      MapEntry('出市', _switchLabel('chushiInd')),
      MapEntry('出省', _switchLabel('chushengInd')),
      MapEntry('实践指导老师', _str('sjhdlsM')),
      MapEntry('附件', _str('fileList')),
      MapEntry('审核状态', item.statusLabel),
    ].where((e) => e.value.trim().isNotEmpty).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(item.typeName.isEmpty ? '请假详情' : '${item.typeName}详情'),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: theme.scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF09C489)),
            )
          : _error != null && _detail == null
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
                    ...rows.map((row) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.key,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                row.value,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF222222),
                                ),
                              ),
                            ],
                          ),
                        )),
                    if (item.canDelete)
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: _deleting ? null : _delete,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE63476),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _deleting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('撤销申请',
                                  style: TextStyle(fontSize: 15)),
                        ),
                      ),
                  ],
                ),
    );
  }
}
