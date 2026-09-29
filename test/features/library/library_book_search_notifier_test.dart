import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:ChillEast/features/library/models/library_book_models.dart';
import 'package:ChillEast/features/library/providers/library_provider.dart';
import 'package:ChillEast/features/library/services/library_book_service.dart';

class FakeLibraryBookService extends LibraryBookService {
  Completer<LibraryBookSearchResult>? completer;
  CancelToken? lastCancelToken;
  String? lastKeyword;

  @override
  Future<LibraryBookSearchResult> searchBooks({
    required String keyword,
    String searchType = 'title',
    CancelToken? cancelToken,
    void Function(int current, int total)? onProgress,
  }) async {
    lastKeyword = keyword;
    lastCancelToken = cancelToken;
    final c = Completer<LibraryBookSearchResult>();
    completer = c;

    cancelToken?.whenCancel.then((_) {
      if (!c.isCompleted) {
        c.completeError(
          DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.cancel,
          ),
        );
      }
    });

    return c.future;
  }
}

void main() {
  group('LibraryBookSearchNotifier Cancellation Tests', () {
    late FakeLibraryBookService fakeService;
    late LibraryBookSearchNotifier notifier;

    setUp(() {
      fakeService = FakeLibraryBookService();
      notifier = LibraryBookSearchNotifier(fakeService);
    });

    tearDown(() {
      notifier.dispose();
    });

    test('Searching while loading cancels old search and starts new search', () async {
      // 1. 发起第一个搜索
      final future1 = notifier.search('flutter');
      expect(notifier.state.isLoading, isTrue);
      expect(notifier.state.keyword, equals('flutter'));

      final token1 = fakeService.lastCancelToken;
      expect(token1, isNotNull);
      expect(token1!.isCancelled, isFalse);

      // 2. 在第一个搜索尚未结束时，输入新书名并点击搜索
      final future2 = notifier.search('dart');
      expect(notifier.state.isLoading, isTrue);
      expect(notifier.state.keyword, equals('dart'));

      // 老的请求应立即被取消
      expect(token1.isCancelled, isTrue);

      final token2 = fakeService.lastCancelToken;
      expect(token2, isNotNull);
      expect(token2 != token1, isTrue);
      expect(token2!.isCancelled, isFalse);

      // 3. 完成第二个搜索
      const mockResult = LibraryBookSearchResult(
        books: [
          LibraryBook(
            detailParam: 'param_1',
            title: 'Dart in Action',
            author: 'Author',
            publisher: 'Publisher',
            callNumber: 'TP312/1',
          ),
        ],
        totalCount: 1,
        totalPages: 1,
      );
      fakeService.completer?.complete(mockResult);

      await future1;
      await future2;

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.keyword, equals('dart'));
      expect(notifier.state.result?.books.length, equals(1));
      expect(notifier.state.result?.books.first.title, equals('Dart in Action'));
      expect(notifier.state.error, isNull);
    });

    test('Calling cancel() aborts in-flight search and resets loading state', () async {
      final searchFuture = notifier.search('python');
      expect(notifier.state.isLoading, isTrue);

      final token = fakeService.lastCancelToken;
      expect(token, isNotNull);
      expect(token!.isCancelled, isFalse);

      // 模拟返回退出触发 cancel()
      notifier.cancel();

      expect(token.isCancelled, isTrue);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);

      await searchFuture;
      expect(notifier.state.isLoading, isFalse);
    });
  });
}
