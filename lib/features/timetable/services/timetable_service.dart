import 'package:logger/logger.dart';
import '../services/timetable_storage.dart';
import '../services/ydjwxt_service.dart';
import '../utils/ics_generator.dart';

class TimetableService {
  final Logger _logger = Logger();
  final YdjwxtService _ydjwxtService = YdjwxtService();
  
  /// 下载并保存课表 (全自动同步模式 - 仅限 YDJWXT)
  /// 
  /// [semester] 学期 (保留参数以兼容 API，但 YDJWXT 不需要)
  /// [firstWeekMonday] 第一周周一日期 (可选，不传则自动校准)
  /// [onProgress] 进度回调
  Future<void> downloadAndSaveTimetable({
    required String semester,
    DateTime? firstWeekMonday,
    Function(String progress)? onProgress,
  }) async {
    _logger.i('Starting downloadAndSaveTimetable (YDJWXT Only)');
    
    // 执行全自动同步 (YDJWXT)
    await _ydjwxtService.syncTimetable(
      firstWeekMonday: firstWeekMonday,
      onProgress: (p) {
        _logger.d('Sync progress: $p');
        if (onProgress != null) onProgress(p);
      },
    );
    
    _logger.i('Timetable and metadata saved successfully via YDJWXT');
  }
}
