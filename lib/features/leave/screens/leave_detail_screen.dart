import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/l10n_extension.dart';
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

  String _getErrorMessage(dynamic e) {
    if (e is LeaveException) {
      if (e.message.contains('统一认证已过期')) return context.l10n.ssoExpiredRelogin;
      if (e.message.contains('登录已失效')) return context.l10n.studentSystemSessionExpired;
      return e.message;
    }
    return context.l10n.loadFailedCheckNetwork;
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
      setState(() => _error = _getErrorMessage(e));
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
            title: Text(context.l10n.cancelLeavePromptTitle),
            content: Text(context.l10n.cancelLeavePromptContent),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  context.l10n.revoke,
                  style: const TextStyle(color: Colors.red),
                ),
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
        SnackBar(
          content: Text(context.l10n.revokedSuccess),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is LeaveException ? e.message : context.l10n.revokeFailedRetry),
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

  String _switchLabel(String key) =>
      _str(key) == '1' ? context.l10n.yes : context.l10n.no;

  String _durationText() {
    final tsStr = _str('ts');
    final hourStr = _str('hour');
    final ts = int.tryParse(tsStr) ?? 0;
    final hour = int.tryParse(hourStr) ?? 0;
    if (ts == 0 && hour == 0) return widget.item.getLocalizedDuration(context);
    final parts = <String>[];
    if (ts > 0) parts.add(context.l10n.durationDays(ts.toString()));
    if (hour > 0) parts.add(context.l10n.durationHours(hour.toString()));
    final text = parts.join(' ');
    return text.isEmpty ? widget.item.getLocalizedDuration(context) : text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final item = widget.item;

    final rows = <MapEntry<String, String>>[
      MapEntry(context.l10n.leaveType, _str('qjlx').isEmpty ? item.typeName : _str('qjlx')),
      MapEntry(context.l10n.startTime, _str('kssj').isEmpty ? item.startTime : _str('kssj')),
      MapEntry(context.l10n.endTime, _str('jssj').isEmpty ? item.endTime : _str('jssj')),
      MapEntry(context.l10n.leaveDuration, _durationText()),
      MapEntry(context.l10n.leaveReason, _str('qjsy').isEmpty ? item.reason : _str('qjsy')),
      MapEntry(context.l10n.emergencyContact, _str('lxr')),
      MapEntry(context.l10n.contactPhone, _str('lxrdh')),
      MapEntry(context.l10n.accompanyingPersons, _str('txry')),
      MapEntry(context.l10n.isLeavingCampus, _switchLabel('lxInd')),
      MapEntry(context.l10n.leaveDestination, _str('lxqx')),
      MapEntry(context.l10n.detailedAddress, _str('lxMdd')),
      MapEntry(context.l10n.returnToDormitory, _switchLabel('huisusheInd')),
      MapEntry(context.l10n.remark, _str('lxBz')),
      MapEntry(context.l10n.leaveCity, _switchLabel('chushiInd')),
      MapEntry(context.l10n.leaveProvince, _switchLabel('chushengInd')),
      MapEntry(context.l10n.practiceInstructor, _str('sjhdlsM')),
      MapEntry(context.l10n.attachment, _str('fileList')),
      MapEntry(context.l10n.auditStatus, item.getLocalizedStatus(context)),
    ].where((e) => e.value.trim().isNotEmpty).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(item.typeName.isEmpty
            ? context.l10n.leaveDetails
            : context.l10n.leaveTypeDetails(item.typeName)),
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
                          child: Text(context.l10n.retry),
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
                              : Text(context.l10n.revokeApplication,
                                  style: const TextStyle(fontSize: 15)),
                        ),
                      ),
                  ],
                ),
    );
  }
}
