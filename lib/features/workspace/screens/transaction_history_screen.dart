import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/l10n_extension.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';

extension TransactionTypeL10n on TransactionType {
  String getLocalizedLabel(BuildContext context) {
    switch (this) {
      case TransactionType.all:
        return context.l10n.all;
      case TransactionType.consume:
        return context.l10n.transactionConsume;
      case TransactionType.recharge:
        return context.l10n.transactionRecharge;
      case TransactionType.subsidy:
        return context.l10n.transactionSubsidy;
      case TransactionType.transfer:
        return context.l10n.transactionTransfer;
    }
  }
}

/// 校园卡账单页
///
/// 入口放在付款码页（余额卡片的「账单」按钮）。
/// 接口与加解密见 [TransactionService]，页面校验对齐
/// `querytrace.js` 的 `queryTrade()`：间隔 ≤ 31 天，截止 ≥ 起始且 ≤ 当天。
///
/// 布局：未查询时条件居中；点击查询后条件上移，下方出现灰框账单。
class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  final _logger = AppLogger.instance;

  DateTime? _beginDate;
  DateTime? _endDate;
  TransactionType _type = TransactionType.all;

  @override
  void initState() {
    super.initState();
    // 默认：上周到今天（含今天共 7 天），不自动查询
    final now = DateTime.now();
    _endDate = DateTime(now.year, now.month, now.day);
    _beginDate = _endDate!.subtract(const Duration(days: 6));
  }

  bool _isLoading = false;
  bool _hasQueried = false;
  String? _error;
  List<TransactionRecord> _records = [];

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// 对齐 querytrace.js 的三段校验，返回 null 表示通过
  String? _validate() {
    if (_beginDate == null) return context.l10n.pleaseSelectStartDate;
    if (_endDate == null) return context.l10n.pleaseSelectEndDate;
    if (_beginDate!.isAfter(_endDate!)) return context.l10n.endDateMustBeAfterStartDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_endDate!.isAfter(today)) return context.l10n.endDateCannotBeInFuture;
    if (_endDate!.difference(_beginDate!).inDays > 31) return context.l10n.dateRangeMaxOneMonth;
    return null;
  }

  Future<void> _pickDate(bool isBegin) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = isBegin
        ? (_beginDate ?? today.subtract(const Duration(days: 6)))
        : (_endDate ?? today);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
    );
    if (picked != null && mounted) {
      setState(() {
        if (isBegin) {
          _beginDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _query() async {
    final err = _validate();
    if (err != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _hasQueried = true;
      _error = null;
    });

    try {
      final records =
          await ref.read(transactionServiceProvider).queryTransactions(
                beginDate: _fmt(_beginDate!),
                endDate: _fmt(_endDate!),
                tradeType: _type.value,
              );
      if (mounted) {
        setState(() {
          _records = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.e('❌ queryTransactions failed: $e');
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  /// 每条记录的类型：记录自带优先，否则按当前筛选，全部时兜底
  String _recordTypeValue(TransactionRecord r) {
    if (r.tradeType.isNotEmpty) return r.tradeType;
    if (_type != TransactionType.all) return _type.value;
    return '';
  }

  ({IconData icon, Color color}) _typeStyle(String value) {
    switch (value) {
      case '1':
        return (icon: Icons.shopping_cart_outlined, color: Colors.orange);
      case '2':
        return (
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xFF09C489)
        );
      case '3':
        return (icon: Icons.redeem_outlined, color: Colors.purple);
      case '4':
        return (icon: Icons.swap_horiz, color: Colors.blue);
      default:
        return (icon: Icons.receipt_long_outlined, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const themeColor = Color(AppConstants.primaryColorValue);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.bill,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.12),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: _hasQueried
            ? _buildResultLayout(themeColor, isDark)
            : _buildInitialLayout(themeColor, isDark),
      ),
    );
  }

  /// 未查询：条件居中
  Widget _buildInitialLayout(Color themeColor, bool isDark) {
    return Center(
      key: const ValueKey('bill-initial'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildConditionRow(themeColor, isDark),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: _buildQueryButton(themeColor),
            ),
          ],
        ),
      ),
    );
  }

  /// 查询后：条件上移，下方灰框账单
  Widget _buildResultLayout(Color themeColor, bool isDark) {
    return Column(
      key: const ValueKey('bill-result'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            children: [
              _buildConditionRow(themeColor, isDark),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: _buildQueryButton(themeColor),
              ),
            ],
          ),
        ),
        Expanded(child: _buildBillBox(themeColor, isDark)),
      ],
    );
  }

  /// 起始日期 - 截止日期 - 类型（一行，三框固定等高）
  Widget _buildConditionRow(Color themeColor, bool isDark) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: _buildDateBox(
            label: context.l10n.startDate,
            date: _beginDate,
            isDark: isDark,
            themeColor: themeColor,
            onTap: () => _pickDate(true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: _buildDateBox(
            label: context.l10n.endDate,
            date: _endDate,
            isDark: isDark,
            themeColor: themeColor,
            onTap: () => _pickDate(false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: _buildTypeBox(isDark),
        ),
      ],
    );
  }

  Widget _buildDateBox({
    required String label,
    required DateTime? date,
    required bool isDark,
    required Color themeColor,
    required VoidCallback onTap,
  }) {
    final valueColor = date == null
        ? (isDark ? Colors.white38 : Colors.black38)
        : (isDark ? Colors.white : Colors.black87);
    return _md2Box(
      label: label,
      onTap: onTap,
      isDark: isDark,
      child: Row(
        children: [
          Expanded(
            child: Text(
              date == null ? context.l10n.pleaseSelect : _fmt(date),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: valueColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.calendar_today_outlined,
              size: 16, color: themeColor),
        ],
      ),
    );
  }

  /// MD2 风格描边框：4dp 圆角 + label 嵌在描边上 + 56dp 高
  Widget _md2Box({
    required String label,
    required Widget child,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final borderColor = isDark
        ? Colors.white.withOpacity(0.38)
        : Colors.black.withOpacity(0.38);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 56,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(fontSize: 12),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            filled: true,
            fillColor:
                isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  /// 类型选择框：MD2 框 + 底部弹窗选值
  /// （不用 DropdownButton：它的弹出菜单路由在动画首帧会以零尺寸参与
  /// hit test，debug 下刷 `Cannot hit test a render box with no size`）
  Widget _buildTypeBox(bool isDark) {
    return _md2Box(
      label: context.l10n.type,
      onTap: () => _pickType(isDark),
      isDark: isDark,
      child: Row(
        children: [
          Expanded(
            child: Text(
              _type.getLocalizedLabel(context),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.keyboard_arrow_down,
              size: 18,
              color: isDark ? Colors.white70 : Colors.black54),
        ],
      ),
    );
  }

  Future<void> _pickType(bool isDark) async {
    final selected = await showModalBottomSheet<TransactionType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(6)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ...TransactionType.values.map(
                (t) => ListTile(
                  title: Text(t.getLocalizedLabel(sheetContext),
                      style: TextStyle(
                          color:
                              isDark ? Colors.white : Colors.black87)),
                  trailing: _type == t
                      ? const Icon(Icons.check,
                          color: Color(0xFF09C489))
                      : null,
                  onTap: () => Navigator.pop(sheetContext, t),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _type = selected);
    }
  }

  /// 查询按钮：样式对齐充值页（高 42 / 无阴影 / 圆角 6 / 图文 Row），颜色保持绿色
  Widget _buildQueryButton(Color themeColor) {
    return SizedBox(
      height: 42,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _query,
        style: ElevatedButton.styleFrom(
          backgroundColor: themeColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.search, size: 18),
        label: Text(context.l10n.query,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }

  /// 灰框账单：透明背景 + 灰色边框（左/上/右），底部直通屏幕底边
  Widget _buildBillBox(Color themeColor, bool isDark) {
    final borderColor =
        isDark ? Colors.white.withOpacity(0.15) : Colors.grey.withOpacity(0.4);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          left: BorderSide(color: borderColor),
          right: BorderSide(color: borderColor),
          top: BorderSide(color: borderColor),
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildBillContent(themeColor, isDark),
        ),
      ),
    );
  }

  Widget _buildBillContent(Color themeColor, bool isDark) {
    if (_isLoading) {
      return Center(
        key: const ValueKey('bill-loading'),
        child: CircularProgressIndicator(color: themeColor),
      );
    }
    if (_error != null) {
      return Center(
        key: const ValueKey('bill-error'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _query,
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(context.l10n.retry,
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
    if (_records.isEmpty) {
      return Center(
        key: const ValueKey('bill-empty'),
        child: Text(context.l10n.noTransactions,
            style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54)),
      );
    }
    return RefreshIndicator(
      key: const ValueKey('bill-list'),
      color: themeColor,
      onRefresh: _query,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        itemCount: _records.length,
        itemBuilder: (context, index) {
          final r = _records[index];
          final style = _typeStyle(_recordTypeValue(r));
          final isNegative = r.amount.trim().startsWith('-');
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: style.color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(style.icon, size: 20, color: style.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.merchantName,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white
                                  : Colors.black87)),
                      const SizedBox(height: 2),
                      Text(r.time,
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.black54)),
                    ],
                  ),
                ),
                Text(
                  r.amount,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isNegative
                        ? (isDark ? Colors.white70 : Colors.black87)
                        : themeColor,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
