import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import '../../workspace/screens/webview_detail_screen.dart';
import '../models/exam_schedule_model.dart';
import '../providers/exam_provider.dart';

class ExamScreen extends ConsumerStatefulWidget {
  const ExamScreen({super.key});

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen> {
  Object? _dismissedError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(examProvider.notifier).pruneExpiredManualExams();
    });
  }

  @override
  Widget build(BuildContext context) {
    final examsAsync = ref.watch(currentSemesterExamsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final error = examsAsync.hasError ? examsAsync.error : null;
    final exams = examsAsync.valueOrNull ?? [];
    final bool showErrorCard = error != null && _dismissedError != error;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.l10n.examSchedule),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: context.l10n.addExam,
            onPressed: () => _showAddExamSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: context.l10n.refreshTimetable,
            onPressed: () {
              setState(() {
                _dismissedError = null;
              });
              ref.read(examProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _dismissedError = null;
          });
          await ref.read(examProvider.notifier).refresh();
        },
        child: (examsAsync.isLoading && !examsAsync.hasValue)
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  if (showErrorCard) ...[
                    _buildErrorCard(context, error, isDark),
                    const SizedBox(height: 12),
                  ],
                  if (exams.isEmpty)
                    _buildEmptyState(context, isDark)
                  else
                    for (final exam in exams)
                      _buildExamCard(context, exam, isDark),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, Object error, bool isDark) {
    var errorMsg = error.toString().replaceFirst('Exception: ', '');
    if (errorMsg.contains('超星') &&
        (errorMsg.contains('验证') ||
            errorMsg.contains('反爬') ||
            errorMsg.contains('202'))) {
      errorMsg = '触发了超星安全验证';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF382326) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFE53935).withValues(alpha: isDark ? 0.3 : 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: Color(0xFFE53935),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorMsg,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFFFFCDD2) : const Color(0xFFC62828),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: isDark ? Colors.white60 : Colors.black54,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: Size.zero,
              padding: const EdgeInsets.all(4),
            ),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () {
              setState(() {
                _dismissedError = error;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_turned_in_outlined,
              size: 64,
              color: isDark ? Colors.white38 : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.noCurrentSemesterExams,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showAddExamSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(context.l10n.addExam),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF09C489),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamCard(BuildContext context, ExamScheduleModel exam, bool isDark) {
    final now = DateTime.now();
    final isPast = exam.time != null && exam.time!.isBefore(now);
    final cardColor = isDark
        ? Theme.of(context).cardTheme.color ?? const Color(0xFF1E1E1E)
        : Colors.white;

    final primaryTitle =
        exam.courseName.isNotEmpty ? exam.courseName : exam.title;
    final secondaryTitle =
        (exam.courseName.isNotEmpty &&
                exam.title.trim().isNotEmpty &&
                exam.title.trim() != exam.courseName.trim())
            ? exam.title.trim()
            : '';
    final statusChip = _buildStatusChip(context, exam, isPast);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE0E0E0),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: exam.detailUrl.isNotEmpty
              ? () {
                  Navigator.push(
                    context,
                    createSlideUpRoute(
                      WebViewDetailScreen(
                        title: exam.title,
                        url: exam.detailUrl,
                        userAgent: AppConstants.campusCardUA,
                      ),
                    ),
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部：课程/考试名称 + 删除按钮 (若为手动)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        primaryTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF202124),
                        ),
                      ),
                    ),
                    if (statusChip != null) ...[
                      const SizedBox(width: 8),
                      statusChip,
                    ],
                    if (exam.isManual) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        color: Colors.red[400],
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.all(4),
                        ),
                        tooltip: context.l10n.delete,
                        onPressed: () => _confirmDeleteExam(context, exam),
                      ),
                    ],
                  ],
                ),
                if (secondaryTitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    secondaryTitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.grey[600],
                    ),
                  ),
                ],
                // 时间行（若未提取到时间，则不显示时间）
                if (exam.time != null) ...[
                  const SizedBox(height: 10),
                  Builder(
                    builder: (context) {
                      final String timeDisplay;
                      if (exam.endTime != null) {
                        if (exam.time!.year == exam.endTime!.year &&
                            exam.time!.month == exam.endTime!.month &&
                            exam.time!.day == exam.endTime!.day) {
                          timeDisplay =
                              '${DateFormat('yyyy-MM-dd HH:mm').format(exam.time!)} ~ ${DateFormat('HH:mm').format(exam.endTime!)}';
                        } else {
                          timeDisplay =
                              '${DateFormat('yyyy-MM-dd HH:mm').format(exam.time!)} ~ ${DateFormat('yyyy-MM-dd HH:mm').format(exam.endTime!)}';
                        }
                      } else {
                        timeDisplay = DateFormat('yyyy-MM-dd HH:mm').format(exam.time!);
                      }

                      return Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: isDark ? Colors.white60 : Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              timeDisplay,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.87)
                                    : const Color(0xFF3C4043),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                // 地点行 (若有)
                if (exam.location != null && exam.location!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          exam.location!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                // 备注行 (若有)
                if (exam.remarks != null && exam.remarks!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.notes_rounded,
                          size: 16,
                          color: isDark ? Colors.white60 : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          exam.remarks!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                // 学习通考试点击跳转提示 (若有跳转链接)
                if (exam.detailUrl.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        context.l10n.openInChaoXing,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E88E5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: Color(0xFF1E88E5),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildStatusChip(BuildContext context, ExamScheduleModel exam, bool isPast) {
    String label;
    Color color;

    if (exam.status.isNotEmpty) {
      if (exam.status == '待考' || exam.status == context.l10n.examStatusPending) {
        return null;
      }
      label = exam.status;
      if (exam.status == '已完成') {
        color = Colors.green;
      } else if (exam.status == '未交') {
        color = Colors.orange;
      } else if (exam.status == '进行中') {
        color = Colors.blue;
      } else {
        color = isPast ? Colors.grey : const Color(0xFF09C489);
      }
    } else {
      if (!isPast) {
        return null;
      }
      label = context.l10n.examStatusEnded;
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  void _confirmDeleteExam(BuildContext context, ExamScheduleModel exam) {
    final messenger = ScaffoldMessenger.of(context);
    final deletedMessage = context.l10n.examDeleted;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(context.l10n.delete),
        content: Text(context.l10n.deleteExamConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref.read(examProvider.notifier).deleteExam(exam.id);
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(content: Text(deletedMessage)),
              );
            },
            child: Text(context.l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddExamSheet(BuildContext context) {
    String title = '';
    String course = '';
    DateTime? selectedTime;
    String location = '';
    String remarks = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final timeStr = selectedTime != null
              ? DateFormat('yyyy-MM-dd HH:mm').format(selectedTime!)
              : null;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF242424) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.addExam,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 所属课程（必填）
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: context.l10n.examCourse,
                      hintText: context.l10n.inputExamCourseHint,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.school_outlined),
                    ),
                    onChanged: (v) => course = v,
                  ),
                  const SizedBox(height: 12),
                  // 考试名称（选填）
                  TextField(
                    decoration: InputDecoration(
                      labelText: context.l10n.examTitle,
                      hintText: context.l10n.inputExamTitleHint,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.quiz_outlined),
                    ),
                    onChanged: (v) => title = v,
                  ),
                  const SizedBox(height: 12),
                  // 考试时间（必填）
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () async {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedTime != null && !selectedTime!.isBefore(today)
                            ? selectedTime!
                            : today,
                        firstDate: today,
                        lastDate: now.add(const Duration(days: 365)),
                      );
                      if (date != null && context.mounted) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: selectedTime != null
                              ? TimeOfDay(
                                  hour: selectedTime!.hour,
                                  minute: selectedTime!.minute,
                                )
                              : TimeOfDay.now(),
                        );
                        if (time != null) {
                          setSheetState(() {
                            selectedTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: context.l10n.examTime,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.access_time_rounded),
                        suffixIcon: selectedTime != null
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 20),
                                onPressed: () {
                                  setSheetState(() => selectedTime = null);
                                },
                              )
                            : null,
                      ),
                      child: Text(
                        timeStr ?? context.l10n.selectExamTimeHint,
                        style: TextStyle(
                          color: timeStr != null
                              ? (isDark ? Colors.white : Colors.black87)
                              : Colors.grey[500],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 考场地点（可选）
                  TextField(
                    decoration: InputDecoration(
                      labelText: context.l10n.examLocation,
                      hintText: context.l10n.inputExamLocationHint,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                    onChanged: (v) => location = v,
                  ),
                  const SizedBox(height: 12),
                  // 备注（可选）
                  TextField(
                    decoration: InputDecoration(
                      labelText: context.l10n.examRemarks,
                      hintText: context.l10n.inputExamRemarksHint,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.notes_rounded),
                    ),
                    onChanged: (v) => remarks = v,
                  ),
                  const SizedBox(height: 20),
                  // 保存按钮
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF09C489),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        final effCourse = course.trim();
                        final effTitle = title.trim();
                        if (effCourse.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.l10n.inputExamCourseHint)),
                          );
                          return;
                        }
                        if (selectedTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.l10n.selectExamTimeHint)),
                          );
                          return;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        final addedMessage = context.l10n.examAdded;

                        await ref.read(examProvider.notifier).addManualExam(
                              title: effTitle,
                              courseName: effCourse,
                              time: selectedTime!,
                              location: location,
                              remarks: remarks,
                            );

                        if (!mounted) return;
                        navigator.pop();
                        messenger.showSnackBar(
                          SnackBar(content: Text(addedMessage)),
                        );
                      },
                      child: Text(
                        context.l10n.save,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
