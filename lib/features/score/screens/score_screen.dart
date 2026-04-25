import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/score_provider.dart';
import '../models/score_model.dart';
import '../../../core/constants/app_constants.dart';

class ScoreScreen extends ConsumerWidget {
  const ScoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scoreProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('成绩查询'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () => ref.read(scoreProvider.notifier).fetchInitialData(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. 学期选择栏 (扁平化设计)
          _buildSemesterPicker(context, ref, state),
          
          Divider(height: 1, thickness: 0.5, color: Theme.of(context).dividerColor),
          
          // 2. 成绩列表
          Expanded(
            child: _buildScoreList(context, ref, state),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterPicker(BuildContext context, WidgetRef ref, ScoreState state) {
    if (state.semesters.isEmpty && !state.isLoading) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            '当前学期',
            style: TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.w600, 
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey[800],
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(width: 12),
          if (state.isLoading && state.semesters.isEmpty)
             const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: DropdownButton<SemesterModel>(
                  value: state.selectedSemester,
                  underline: const SizedBox(),
                  icon: Icon(Icons.arrow_drop_down_rounded, color: Colors.grey[600]),
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  isExpanded: true,
                  items: state.semesters.map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(scoreProvider.notifier).changeSemester(val);
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreList(BuildContext context, WidgetRef ref, ScoreState state) {
    if (state.isLoading && state.scores.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.scores.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(state.errorMessage!, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => ref.read(scoreProvider.notifier).fetchInitialData(),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (state.scores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[100]),
            const SizedBox(height: 16),
            Text('本学期暂无成绩数据', style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: state.scores.length,
          separatorBuilder: (context, index) => Divider(
            height: 1, 
            thickness: 0.5, 
            indent: 72,
            color: Theme.of(context).dividerColor,
          ),
          itemBuilder: (context, index) {
            final score = state.scores[index];
            return _buildScoreItem(context, score);
          },
        ),
        if (state.isLoading)
          const Positioned(
            top: 0, left: 0, right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Widget _buildScoreItem(BuildContext context, ScoreModel score) {
    final bool isExcellent = _isExcellent(score.score);
    final bool isFailed = _isFailed(score.score);

    Color scoreColor = Theme.of(context).primaryColor;
    if (isFailed) scoreColor = Colors.red[700]!;
    if (isExcellent) scoreColor = Colors.orange[700]!;

    return InkWell(
      onTap: () {}, // 预留详情点击
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
          children: [
            // 左侧图标/标识 (MD2 风格圆框)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scoreColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFailed ? Icons.warning_amber_rounded : Icons.menu_book_rounded,
                size: 20,
                color: scoreColor,
              ),
            ),
            const SizedBox(width: 16),
            
            // 中间信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    score.courseName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF202124),
                    ),
                  ),
                  const SizedBox(height: 4),
                  DefaultTextStyle(
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    child: Row(
                      children: [
                        Text('学分: ${score.credit ?? "N/A"}'),
                        const SizedBox(width: 12),
                        const Text('•'),
                        const SizedBox(width: 12),
                        Text(score.examType ?? '正常考试'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 右侧分数
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  score.score,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                    fontFamily: 'monospace',
                  ),
                ),
                if (isExcellent || isFailed)
                  Text(
                    isExcellent ? '优秀' : '不及格',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: scoreColor.withOpacity(0.8),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isExcellent(String score) {
    final val = double.tryParse(score);
    if (val != null) return val >= 90;
    return score == '优秀';
  }

  bool _isFailed(String score) {
    final val = double.tryParse(score);
    if (val != null) return val < 60;
    return score == '不及格';
  }
}
