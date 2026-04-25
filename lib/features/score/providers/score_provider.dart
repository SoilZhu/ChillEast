import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/score_service.dart';
import '../models/score_model.dart';
import 'package:logger/logger.dart';

class ScoreState {
  final bool isLoading;
  final List<ScoreModel> scores;
  final List<SemesterModel> semesters;
  final SemesterModel? selectedSemester;
  final String? errorMessage;

  ScoreState({
    required this.isLoading,
    required this.scores,
    required this.semesters,
    this.selectedSemester,
    this.errorMessage,
  });

  ScoreState.initial()
      : isLoading = true,
        scores = [],
        semesters = [],
        selectedSemester = null,
        errorMessage = null;

  ScoreState copyWith({
    bool? isLoading,
    List<ScoreModel>? scores,
    List<SemesterModel>? semesters,
    SemesterModel? selectedSemester,
    String? errorMessage,
  }) {
    return ScoreState(
      isLoading: isLoading ?? this.isLoading,
      scores: scores ?? this.scores,
      semesters: semesters ?? this.semesters,
      selectedSemester: selectedSemester ?? this.selectedSemester,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final scoreProvider = StateNotifierProvider.autoDispose<ScoreNotifier, ScoreState>((ref) {
  return ScoreNotifier();
});

class ScoreNotifier extends StateNotifier<ScoreState> {
  final _service = ScoreService();
  final _logger = Logger();

  ScoreNotifier() : super(ScoreState.initial()) {
    fetchInitialData();
  }

  Future<void> fetchInitialData() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      final data = await _service.fetchScores();
      
      final List<SemesterModel> semesters = data['semesters'];
      final List<ScoreModel> scores = data['scores'];
      
      // 找到当前活跃的学期
      SemesterModel? active = semesters.cast<SemesterModel?>().firstWhere(
        (s) => s?.isActive ?? false, 
        orElse: () => semesters.isNotEmpty ? semesters.first : null
      );

      state = state.copyWith(
        isLoading: false,
        scores: scores,
        semesters: semesters,
        selectedSemester: active,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> changeSemester(SemesterModel semester) async {
    if (semester == state.selectedSemester) return;
    
    try {
      state = state.copyWith(isLoading: true, selectedSemester: semester, errorMessage: null);
      final data = await _service.fetchScores(xn: semester.value, xq: semester.xq);
      
      state = state.copyWith(
        isLoading: false,
        scores: data['scores'],
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}
