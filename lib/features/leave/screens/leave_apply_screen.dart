import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/utils/l10n_extension.dart';
import '../models/leave_models.dart';
import '../services/leave_service.dart';

/// 请假申请填单页
/// 字段与校验对照请假 HAR 填单页脚本（sfvalidation + beforeSubmit）。
class LeaveApplyScreen extends ConsumerStatefulWidget {
  const LeaveApplyScreen({super.key});

  @override
  ConsumerState<LeaveApplyScreen> createState() => _LeaveApplyScreenState();
}

class _LeaveApplyScreenState extends ConsumerState<LeaveApplyScreen> {
  bool _loading = true;
  String? _error;
  bool _submitting = false;
  bool _calculating = false;

  List<LeaveDictItem> _types = [];
  String? _typeId;
  List<RegionNode> _regions = [];

  String? _startTime;
  String? _endTime;

  final _daysController = TextEditingController();
  final _hoursController = TextEditingController();
  final _reasonController = TextEditingController();
  final _contactController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companionsController = TextEditingController();
  final _addressController = TextEditingController();
  final _remarkController = TextEditingController();

  bool _leaveSchool = false;
  bool _backDorm = false;
  bool _outCity = false;
  bool _outProvince = false;

  String? _provinceId;
  String? _cityId;
  String? _countyId;

  String? _attachmentPath;
  String? _attachmentName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _daysController.dispose();
    _hoursController.dispose();
    _reasonController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _companionsController.dispose();
    _addressController.dispose();
    _remarkController.dispose();
    super.dispose();
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
      final service = ref.read(leaveServiceProvider);
      final results = await Future.wait([
        service.fetchTypes(),
        service.fetchRegions(),
      ]);
      if (!mounted) return;
      final types = results[0] as List<LeaveDictItem>;
      setState(() {
        _types = types;
        _typeId = types.isNotEmpty ? types.first.id : null;
        _regions = results[1] as List<RegionNode>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  DateTime? _parse(String? value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.replaceFirst(' ', 'T'));
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickDateTime(bool isStart) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = now.add(const Duration(days: 365));
    final startDt = _parse(_startTime);
    // 结束不得早于开始；选择器记住已选值，不再每次都停在今天
    final first = isStart ? today : (startDt ?? today);
    var initial =
        (isStart ? _parse(_startTime) : _parse(_endTime)) ?? (isStart ? now : (startDt ?? now));
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(lastDay)) initial = lastDay;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: lastDay,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      // 24 小时制 + MD2 表盘样式，避免 12 小时制 AM/PM 存错小时
      builder: (context, child) {
        final base = Theme.of(context);
        return MediaQuery(
          data:
              MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            data: ThemeData.from(
              colorScheme: base.colorScheme,
              useMaterial3: false,
            ),
            child: child!,
          ),
        );
      },
    );
    if (time == null) return;
    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startTime = _formatDateTime(picked);
        // 开始挪到结束之后时，清空结束与时长，避免残留非法组合
        final s = _parse(_startTime);
        final e = _parse(_endTime);
        if (s != null && e != null && !e.isAfter(s)) {
          _endTime = null;
          _daysController.clear();
          _hoursController.clear();
        }
      } else {
        _endTime = _formatDateTime(picked);
      }
    });
    _autoCalculate();
  }

  /// 起止齐了就调 calculate 自动回填时长（对齐网页 dateTimeChange）
  Future<void> _autoCalculate() async {
    if (_startTime == null || _endTime == null || _calculating) return;
    setState(() => _calculating = true);
    try {
      final duration = await ref
          .read(leaveServiceProvider)
          .calculate(_startTime!, _endTime!);
      if (!mounted) return;
      _daysController.text = duration.days.toString();
      _hoursController.text = duration.hours.toString();
    } catch (_) {
      // 试算失败不打断填写，提交时再校验
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  List<RegionNode> get _cities {
    if (_provinceId == null) return const [];
    for (final p in _regions) {
      if (p.id == _provinceId) return p.children;
    }
    return const [];
  }

  List<RegionNode> get _counties {
    if (_cityId == null) return const [];
    for (final c in _cities) {
      if (c.id == _cityId) return c.children;
    }
    return const [];
  }

  String _durationText() {
    final days = _daysController.text.trim();
    final hours = _hoursController.text.trim();
    if (days.isEmpty && hours.isEmpty) {
      return context.l10n.selectTimeAutoCalculateDuration;
    }
    final d = days.isEmpty ? '0' : days;
    final h = hours.isEmpty ? '0' : hours;
    return '${context.l10n.durationDays(d)} ${context.l10n.durationHours(h)}';
  }

  String? _validate() {
    if (_typeId == null || _typeId!.isEmpty) return context.l10n.pleaseSelectLeaveType;
    if (_startTime == null) return context.l10n.pleaseSelectStartTime;
    if (_endTime == null) return context.l10n.pleaseSelectEndTime;
    final start = _parse(_startTime);
    final end = _parse(_endTime);
    if (start == null || end == null) return context.l10n.timeFormatErrorReselect;
    if (!end.isAfter(start)) return context.l10n.endTimeMustBeAfterStartTime;
    final days = _daysController.text.trim();
    final hours = _hoursController.text.trim();
    if (days.isEmpty && hours.isEmpty) return context.l10n.durationCalculateFailedReselect;
    final dayInt = int.tryParse(days.isEmpty ? '0' : days);
    final hourInt = int.tryParse(hours.isEmpty ? '0' : hours);
    if (dayInt == null || hourInt == null) return context.l10n.durationMustBeInteger;
    if (dayInt < 0 || hourInt < 0 || hourInt > 23) return context.l10n.pleaseEnterValidDuration;
    if (_reasonController.text.trim().isEmpty) return context.l10n.pleaseFillLeaveReason;
    if (_contactController.text.trim().isEmpty) return context.l10n.pleaseFillEmergencyContact;
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return context.l10n.pleaseFillEmergencyContactPhone;
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) return context.l10n.invalidEmergencyContactPhone;
    if (_leaveSchool) {
      if (_provinceId == null) return context.l10n.pleaseSelectLeaveDestination;
      if (_addressController.text.trim().isEmpty) return context.l10n.pleaseFillDetailedAddress;
      if (_remarkController.text.trim().isEmpty) return context.l10n.pleaseFillRemark;
    }
    return null;
  }

  Future<void> _pickAttachment() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() {
      _attachmentPath = file.path;
      _attachmentName = file.name;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      // 请假时长由起止时间自动计算：若试算结果为空，提交前补算一次
      if (_startTime != null &&
          _endTime != null &&
          _daysController.text.trim().isEmpty &&
          _hoursController.text.trim().isEmpty) {
        try {
          final duration = await ref
              .read(leaveServiceProvider)
              .calculate(_startTime!, _endTime!);
          _daysController.text = duration.days.toString();
          _hoursController.text = duration.hours.toString();
        } catch (_) {}
      }
      if (!mounted) return;
      final error = _validate();
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
        );
        return;
      }
    final typeName = _types
        .firstWhere((t) => t.id == _typeId,
            orElse: () => LeaveDictItem(id: _typeId!, name: ''))
        .name;

    // 最深一级去向 id（县>市>省），显示文本取最深一级名称
    String regionId = '';
    String regionName = '';
    if (_leaveSchool) {
      final province = _regions.where((e) => e.id == _provinceId);
      final city = _cities.where((e) => e.id == _cityId);
      final county = _counties.where((e) => e.id == _countyId);
      if (county.isNotEmpty) {
        regionId = county.first.id;
        regionName = county.first.name;
      } else if (city.isNotEmpty) {
        regionId = city.first.id;
        regionName = city.first.name;
      } else if (province.isNotEmpty) {
        regionId = province.first.id;
        regionName = province.first.name;
      }
    }

    final fields = <String, String>{
      'qjlxM.dm': _typeId!,
      'qjlx': typeName,
      'kssj': _startTime!,
      'jssj': _endTime!,
      'ts': _daysController.text.trim().isEmpty
          ? '0'
          : _daysController.text.trim(),
      'jsTs': _daysController.text.trim().isEmpty
          ? '0'
          : _daysController.text.trim(),
      'hour': _hoursController.text.trim().isEmpty
          ? '0'
          : _hoursController.text.trim(),
      'jsHour': _hoursController.text.trim().isEmpty
          ? '0'
          : _hoursController.text.trim(),
      'qjsy': _reasonController.text.trim(),
      'lxr': _contactController.text.trim(),
      'lxrdh': _phoneController.text.trim(),
      'txry': _companionsController.text.trim(),
      'lxInd': _leaveSchool ? '1' : '0',
      'lxqx.dm': regionId,
      'lxqx1': regionName,
      'lxMdd': _addressController.text.trim(),
      'huisusheInd': _backDorm ? '1' : '0',
      'lxBz': _remarkController.text.trim(),
      'chushiInd': _outCity ? '1' : '0',
      'chushengInd': _outProvince ? '1' : '0',
      'pathFile': '',
      'qjLocation': '',
      'qjLocationZb': '',
      'operationType': 'Create',
      'id': '',
    };

    await ref.read(leaveServiceProvider).submit(
          fields: fields,
          attachmentPath: _attachmentPath,
        );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.submitSuccess), behavior: SnackBarBehavior.floating),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is LeaveException ? e.message : context.l10n.submitFailedRetry),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.l10n.leaveApplication),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: theme.scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF09C489)),
            )
          : _error != null && _types.isEmpty
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
                    _label(context.l10n.leaveType, required: true),
                    DropdownButtonFormField<String>(
                      initialValue: _typeId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        filled: false,
                        border: OutlineInputBorder(),
                      ),
                      items: _types
                          .map((t) => DropdownMenuItem(
                              value: t.id, child: Text(t.name)))
                          .toList(),
                      onChanged: (v) => setState(() => _typeId = v),
                    ),
                    const SizedBox(height: 20),
                    _label(context.l10n.startTime, required: true),
                    _dateField(_startTime, () => _pickDateTime(true)),
                    const SizedBox(height: 20),
                    _label(context.l10n.endTime, required: true),
                    _dateField(_endTime, () => _pickDateTime(false)),
                    const SizedBox(height: 20),
                    _label(context.l10n.leaveDuration,
                        required: true,
                        suffix: _calculating ? context.l10n.calculatingDuration : ''),
                    Text(
                      _durationText(),
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : const Color(0xFF222222),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _label(context.l10n.leaveReason, required: true),
                    TextField(
                      controller: _reasonController,
                      maxLines: 3,
                      minLines: 3,
                      decoration: InputDecoration(
                        hintText: context.l10n.pleaseEnter,
                        filled: false,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _label(context.l10n.emergencyContact, required: true),
                    TextField(
                      controller: _contactController,
                      decoration: InputDecoration(
                        hintText: context.l10n.pleaseEnter,
                        filled: false,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _label(context.l10n.emergencyContactPhone, required: true),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))
                      ],
                      decoration: InputDecoration(
                        hintText: context.l10n.pleaseEnter11DigitPhone,
                        filled: false,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _label(context.l10n.accompanyingPersons),
                    TextField(
                      controller: _companionsController,
                      decoration: InputDecoration(
                        hintText: context.l10n.optional,
                        filled: false,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: _leaveSchool,
                      onChanged: (v) =>
                          setState(() => _leaveSchool = v),
                      title: Text(context.l10n.leaveCampus, style: const TextStyle(fontSize: 15)),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: const Color(0xFF09C489),
                    ),
                    if (_leaveSchool) ...[
                      _label(context.l10n.leaveDestination, required: true),
                      DropdownButtonFormField<String>(
                        initialValue: _provinceId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: context.l10n.province,
                          filled: false,
                          border: const OutlineInputBorder(),
                        ),
                        items: _regions
                            .map((r) => DropdownMenuItem(
                                value: r.id, child: Text(r.name)))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _provinceId = v;
                          _cityId = null;
                          _countyId = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _cityId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                hintText: context.l10n.city,
                                filled: false,
                                border: const OutlineInputBorder(),
                              ),
                              items: _cities
                                  .map((r) => DropdownMenuItem(
                                      value: r.id, child: Text(r.name)))
                                  .toList(),
                              onChanged: (v) => setState(() {
                                _cityId = v;
                                _countyId = null;
                              }),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _countyId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                hintText: context.l10n.districtCounty,
                                filled: false,
                                border: const OutlineInputBorder(),
                              ),
                              items: _counties
                                  .map((r) => DropdownMenuItem(
                                      value: r.id, child: Text(r.name)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _countyId = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _label(context.l10n.detailedAddress, required: true),
                      TextField(
                        controller: _addressController,
                        maxLines: 2,
                        minLines: 2,
                        decoration: InputDecoration(
                          hintText: context.l10n.pleaseEnter,
                          filled: false,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      SwitchListTile(
                        value: _backDorm,
                        onChanged: (v) =>
                            setState(() => _backDorm = v),
                        title:
                            Text(context.l10n.returnToDormitory, style: const TextStyle(fontSize: 15)),
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: const Color(0xFF09C489),
                      ),
                      _label(context.l10n.remark, required: true),
                      TextField(
                        controller: _remarkController,
                        maxLines: 2,
                        minLines: 2,
                        decoration: InputDecoration(
                          hintText: context.l10n.pleaseEnter,
                          filled: false,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                    SwitchListTile(
                      value: _outCity,
                      onChanged: (v) => setState(() => _outCity = v),
                      title: Text(context.l10n.leaveCity, style: const TextStyle(fontSize: 15)),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: const Color(0xFF09C489),
                    ),
                    SwitchListTile(
                      value: _outProvince,
                      onChanged: (v) =>
                          setState(() => _outProvince = v),
                      title: Text(context.l10n.leaveProvince, style: const TextStyle(fontSize: 15)),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: const Color(0xFF09C489),
                    ),
                    _label(context.l10n.leaveMaterials),
                    InkWell(
                      onTap: _pickAttachment,
                      borderRadius: BorderRadius.circular(4),
                      child: InputDecorator(
                        isEmpty: _attachmentPath == null,
                        decoration: InputDecoration(
                          hintText: context.l10n.leaveMaterialsHint,
                          filled: false,
                          border: const OutlineInputBorder(),
                          suffixIcon: const Icon(Icons.image_outlined),
                        ),
                        child: Text(
                          _attachmentName ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    if (_attachmentPath != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(() {
                            _attachmentPath = null;
                            _attachmentName = null;
                          }),
                          child: Text(context.l10n.removeAttachment),
                        ),
                      ),
                    const SizedBox(height: 16),
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
                            : Text(context.l10n.submit,
                                style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _label(String text, {bool required = false, String suffix = ''}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF222222),
          ),
          children: [
            if (required)
              const TextSpan(
                text: '* ',
                style: TextStyle(color: Color(0xFFE63476)),
              ),
            TextSpan(text: text),
            if (suffix.isNotEmpty)
              TextSpan(
                text: ' $suffix',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dateField(String? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        isEmpty: value == null,
        decoration: InputDecoration(
          hintText: context.l10n.pleaseSelect,
          filled: false,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_month_outlined),
        ),
        child: Text(
          value ?? '',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
