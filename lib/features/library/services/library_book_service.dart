import 'dart:async';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/app_logger.dart';
import '../models/library_book_models.dart';

class LibraryBookService {
  final _logger = AppLogger.instance;
  static const String baseUrl = 'https://superlib.hunau.edu.cn';

  Dio get _dio => DioClient().dio;

  Map<String, String> get _defaultHeaders => {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 16; MEIZU 20 Build/BQ2A.251110.001-BP2A.250605.031.A3; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/147.0.7727.55 Mobile Safari/537.36 (device:MEIZU 20) Language/zh_CN com.chaoxing.mobile.hunannongyedaxue/ChaoXingStudy_1000257_5.3_android_phone_53_234 (Kalimdor)',
        'Referer': '$baseUrl/',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      };

  /// 搜索图书，一次性把所有结果的页面请求完并合并
  /// 支持通过 [cancelToken] 随时中止请求
  /// [onProgress] 回调当前进度 (已加载页数, 总页数)
  Future<LibraryBookSearchResult> searchBooks({
    required String keyword,
    String searchType = 'title',
    CancelToken? cancelToken,
    void Function(int current, int total)? onProgress,
  }) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return LibraryBookSearchResult.empty;

    _logger.i('🔍 Searching library books: "$trimmed" (searchType: $searchType)...');

    try {
      // 1. 请求第 1 页
      final page1Response = await _dio.get(
        '$baseUrl/search/searchList',
        queryParameters: {
          'kw': trimmed,
          'xc': '3',
          'schoolid': '193',
          'searchtype': searchType,
        },
        cancelToken: cancelToken,
        options: Options(
          headers: _defaultHeaders,
          responseType: ResponseType.plain,
        ),
      );

      if (cancelToken?.isCancelled ?? false) {
        return LibraryBookSearchResult.empty;
      }

      final page1Html = page1Response.data?.toString() ?? '';
      final page1Document = html_parser.parse(page1Html);

      // 解析总数量与总页数
      final totalCount = _parseTotalCount(page1Document);
      final totalPages = _parseTotalPages(page1Document, totalCount);

      final page1Books = _parseBooks(page1Document);
      _logger.i('📚 Page 1 loaded: ${page1Books.length} books, total: $totalCount items across $totalPages pages');

      onProgress?.call(1, totalPages > 0 ? totalPages : 1);

      if (totalPages <= 1 || totalCount <= page1Books.length) {
        return LibraryBookSearchResult(
          books: page1Books,
          totalCount: totalCount > 0 ? totalCount : page1Books.length,
          totalPages: totalPages > 0 ? totalPages : 1,
        );
      }

      // 2. 一次性把所有剩余页面的结果全部请求完
      final List<LibraryBook> allBooks = List.of(page1Books);
      int completedPages = 1;

      // 分批并发控制（每批 5 个请求），防止过多并发引发服务端拒绝
      const batchSize = 5;
      final remainingPages = [for (int p = 2; p <= totalPages; p++) p];

      for (int i = 0; i < remainingPages.length; i += batchSize) {
        if (cancelToken?.isCancelled ?? false) {
          _logger.i('🛑 Book search pagination cancelled');
          return LibraryBookSearchResult.empty;
        }

        final batch = remainingPages.sublist(
          i,
          i + batchSize > remainingPages.length
              ? remainingPages.length
              : i + batchSize,
        );

        final batchResults = await Future.wait(
          batch.map((page) => _fetchPage(
                keyword: trimmed,
                searchType: searchType,
                pageIndex: page,
                cancelToken: cancelToken,
              )),
        );

        if (cancelToken?.isCancelled ?? false) {
          return LibraryBookSearchResult.empty;
        }

        for (final books in batchResults) {
          allBooks.addAll(books);
          completedPages++;
          onProgress?.call(completedPages, totalPages);
        }
      }

      _logger.i('✅ All $totalPages pages fetched, total loaded: ${allBooks.length} books');

      return LibraryBookSearchResult(
        books: allBooks,
        totalCount: totalCount > 0 ? totalCount : allBooks.length,
        totalPages: totalPages,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel || (cancelToken?.isCancelled ?? false)) {
        _logger.i('🛑 Book search request cancelled');
        return LibraryBookSearchResult.empty;
      }
      rethrow;
    }
  }

  /// 单页请求
  Future<List<LibraryBook>> _fetchPage({
    required String keyword,
    required String searchType,
    required int pageIndex,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$baseUrl/search/searchList',
        queryParameters: {
          'kw': keyword,
          'schoolid': '193',
          'pageIndex': pageIndex.toString(),
          'searchtype': searchType,
          'doctype': '',
          'xc': '3',
          'pagingParam': '{}',
        },
        cancelToken: cancelToken,
        options: Options(
          headers: _defaultHeaders,
          responseType: ResponseType.plain,
        ),
      );

      final html = response.data?.toString() ?? '';
      final doc = html_parser.parse(html);
      return _parseBooks(doc);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return [];
      }
      _logger.w('⚠️ Error fetching page $pageIndex: $e');
      return [];
    } catch (e) {
      _logger.w('⚠️ Error fetching page $pageIndex: $e');
      return [];
    }
  }

  /// 解析总搜索结果数
  int _parseTotalCount(Document doc) {
    final numElement = doc.querySelector('.num h1') ?? doc.querySelector('.num');
    if (numElement != null) {
      final text = numElement.text;
      final match = RegExp(r'共\s*(\d+)\s*条').firstMatch(text);
      if (match != null) {
        return int.tryParse(match.group(1) ?? '') ?? 0;
      }
    }

    // 正则全局匹配页面中的 "共X条搜索结果"
    final allText = doc.body?.text ?? '';
    final match = RegExp(r'共\s*(\d+)\s*条搜索结果').firstMatch(allText);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '') ?? 0;
    }

    return 0;
  }

  /// 解析总页数
  int _parseTotalPages(Document doc, int totalCount) {
    // 优先从 #pagenum 中的选项中解析
    final options = doc.querySelectorAll('#pagenum option');
    for (final opt in options) {
      final text = opt.text.trim();
      final match = RegExp(r'\d+\s*/\s*(\d+)').firstMatch(text);
      if (match != null) {
        final pages = int.tryParse(match.group(1) ?? '');
        if (pages != null && pages > 0) return pages;
      }
    }

    // 根据总条数计算，每页 20 条
    if (totalCount > 0) {
      return (totalCount / 20).ceil();
    }

    return 0;
  }

  /// 从 HTML 中解析图书列表
  bool _isIsbn(String s) {
    final cleaned = s.replaceAll(RegExp(r'[\s\-]'), '');
    return cleaned.length >= 8 &&
        RegExp(r'^\d+([0-9Xx])?$').hasMatch(cleaned);
  }

  bool _isCallNumber(String s) {
    if (_isIsbn(s)) return false;
    if (s.contains('/')) return true;
    if (RegExp(r'^[A-Za-z0-9]+[\.\-\=][A-Za-z0-9]').hasMatch(s)) return true;
    return false;
  }

  bool _isPublisher(String s) {
    if (s.contains('出版社') ||
        s.contains('书局') ||
        s.contains('书店') ||
        s.contains('公司') ||
        s.contains('编辑部') ||
        s.contains('音像') ||
        s.contains('出版')) {
      return true;
    }
    if ((s.contains(':') || s.contains('：')) && !s.startsWith('http')) {
      return true;
    }
    return false;
  }

  bool _isDocType(String s) {
    return const {'M', 'B', 'C', 'J', 'D', 'R', 'S', 'P'}
        .contains(s.trim().toUpperCase());
  }

  bool _isLanguage(String s) {
    return const {
      'chi',
      'eng',
      'chi eng',
      'eng chi',
      'fre',
      'ger',
      'jpn',
      'rus',
      'und'
    }.contains(s.trim().toLowerCase());
  }

  bool _isYear(String s) {
    if (_isIsbn(s)) return false;
    final match = RegExp(r'(19\d\d|20\d\d)(\.\d+)?').firstMatch(s);
    return match != null;
  }

  /// 从 HTML 中解析图书列表（自动校正服务端字段错位）
  List<LibraryBook> _parseBooks(Document doc) => parseBooksFromDocument(doc);

  /// 供测试与调用的图书列表解析方法
  List<LibraryBook> parseBooksFromDocument(Document doc) {
    final list = <LibraryBook>[];
    final items = doc.querySelectorAll('.list ul li');

    for (final li in items) {
      final detailParam =
          li.querySelector('input[name="detailParam"]')?.attributes['value'] ?? '';
      if (detailParam.isEmpty) continue;

      final mainKey =
          li.querySelector('input[name="mainKey"]')?.attributes['value'] ?? '';
      var title =
          li.querySelector('input[name="title"]')?.attributes['value'] ?? '';
      final titleSpan =
          li.querySelector('.title span') ?? li.querySelector('.title');
      if (titleSpan != null && titleSpan.text.trim().isNotEmpty) {
        title = titleSpan.text.trim();
      }

      final pMap = <String, String>{};
      final pValues = <String>[];
      final detailPs = li.querySelectorAll('.detail p');
      for (final p in detailPs) {
        final text = p.text.trim();
        if (text.contains('：')) {
          final parts = text.split('：');
          final k = parts[0].trim();
          final v = parts.sublist(1).join('：').trim();
          pMap[k] = v;
          if (k != '信息' && v.isNotEmpty) {
            pValues.add(v);
          }
        } else if (text.contains(':')) {
          final parts = text.split(':');
          final k = parts[0].trim();
          final v = parts.sublist(1).join(':').trim();
          pMap[k] = v;
          if (k != '信息' && v.isNotEmpty) {
            pValues.add(v);
          }
        }
      }

      String author = '';
      String callNumber = '';
      String publisher = '';
      String isbn = '';
      String publishYear = '';
      String rawInfo = '';

      // 1. 如果存在汇总的「信息：」段落（Case 1）
      if (pMap.containsKey('信息')) {
        rawInfo = pMap['信息']!;
        final tokens = rawInfo.split(RegExp(r'\s+'));
        for (final token in tokens) {
          if (_isPublisher(token) && publisher.isEmpty) {
            publisher = token;
          } else if (_isYear(token) && publishYear.isEmpty) {
            publishYear = token;
          } else if (_isCallNumber(token) && callNumber.isEmpty) {
            callNumber = token;
          } else if (_isIsbn(token) && isbn.isEmpty) {
            isbn = token;
          }
        }
        if (tokens.length >= 3) {
          author = tokens[2];
        }

        // 兜底校准
        if (callNumber.isEmpty && _isCallNumber(pMap['ISBN'] ?? '')) {
          callNumber = pMap['ISBN']!;
        }
        if (isbn.isEmpty && _isIsbn(pMap['出版时间'] ?? '')) {
          isbn = pMap['出版时间']!;
        }
      } else {
        // 2. 服务端表格列名错位情况（Case 2，如当前学校检索列表）
        final inputPublisher =
            li.querySelector('input[name="publisher"]')?.attributes['value'] ?? '';
        final inputAuthor =
            li.querySelector('input[name="author"]')?.attributes['value'] ?? '';

        if (pMap.containsKey('作者') &&
            !_isCallNumber(pMap['作者']!) &&
            !_isIsbn(pMap['作者']!) &&
            !_isPublisher(pMap['作者']!)) {
          author = pMap['作者']!;
        } else if (inputAuthor.isNotEmpty &&
            !_isCallNumber(inputAuthor) &&
            !_isIsbn(inputAuthor) &&
            !_isPublisher(inputAuthor)) {
          author = inputAuthor;
        }

        final candidates = [
          ...pValues,
          if (inputPublisher.isNotEmpty) inputPublisher,
        ];

        for (final cand in candidates) {
          if (cand.isEmpty || _isDocType(cand) || _isLanguage(cand)) {
            continue;
          }
          if (callNumber.isEmpty && _isCallNumber(cand)) {
            callNumber = cand;
          } else if (publisher.isEmpty && _isPublisher(cand)) {
            publisher = cand;
          } else if (isbn.isEmpty && _isIsbn(cand)) {
            isbn = cand;
          } else if (publishYear.isEmpty && _isYear(cand)) {
            publishYear = cand;
          }
        }
      }

      list.add(LibraryBook(
        detailParam: detailParam,
        mainKey: mainKey,
        title: title,
        author: author,
        callNumber: callNumber,
        isbn: isbn,
        publisher: publisher,
        publishYear: publishYear,
        rawInfo: rawInfo,
      ));
    }

    return list;
  }

  /// 查询图书详情与馆藏信息
  Future<LibraryBookDetail> fetchBookDetail(LibraryBook book) async {
    _logger.i('📖 Fetching book detail for "${book.title}"...');

    final response = await _dio.post(
      '$baseUrl/search/bookDetail',
      data: {
        'detailParam': book.detailParam,
        'mainKey': book.mainKey,
        'title': book.title,
        'author': book.author,
        'publisher': book.publisher,
        'language': '',
        'xc': '3',
        'schoolid': '193',
      },
      options: Options(
        headers: {
          ..._defaultHeaders,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        responseType: ResponseType.plain,
      ),
    );

    final html = response.data?.toString() ?? '';
    final doc = html_parser.parse(html);

    return parseBookDetailFromDocument(doc, defaultBook: book);
  }

  /// 解析图书详情 Document
  LibraryBookDetail parseBookDetailFromDocument(Document doc, {LibraryBook? defaultBook}) {
    String title = doc.querySelector('header .tit h1')?.text.trim() ??
        doc.querySelector('title')?.text.trim() ??
        defaultBook?.title ??
        '';

    // 剔除 title 尾部的责任者后缀
    if (title.contains(' / ')) {
      final parts = title.split(' / ');
      title = parts.first.trim();
    }

    String author = defaultBook?.author ?? '';
    String callNumber = defaultBook?.callNumber ?? '';
    String subject = '';
    String isbn = defaultBook?.isbn ?? '';
    String price = '';
    String publishInfo = defaultBook?.publisher ?? '';
    String physicalDesc = '';
    String series = '';
    String summary = '';
    final additionalInfo = <String>[];
    final catalogItems = <MapEntry<String, String>>[];

    final catalogPs = doc.querySelectorAll('.catalog p');
    for (final p in catalogPs) {
      final text = p.text.trim();
      if (text.isEmpty) continue;
      final colonIndex = text.indexOf(RegExp(r'[:：]'));
      final key = colonIndex != -1 ? text.substring(0, colonIndex).trim() : '';
      final val = colonIndex != -1 ? text.substring(colonIndex + 1).trim() : text;

      if (key.isNotEmpty && val.isNotEmpty) {
        catalogItems.add(MapEntry(key, val));
      }

      if (key.contains('题名/责任者') || key == '题名') {
        if (val.contains(' / ')) {
          final parts = val.split(' / ');
          if (title.isEmpty) title = parts[0].trim();
          author = parts[1].trim();
        } else if (val.contains('/')) {
          final parts = val.split('/');
          if (title.isEmpty) title = parts[0].trim();
          author = parts[1].trim();
        } else if (author.isEmpty) {
          author = val;
        }
      } else if (key.contains('主题词/索书号') || key.contains('索书号')) {
        if (val.contains(' / ')) {
          final parts = val.split(' / ');
          subject = parts[0].trim();
          callNumber = parts[1].trim();
        } else if (val.startsWith('/')) {
          callNumber = val.replaceFirst(RegExp(r'^\s*/\s*'), '').trim();
        } else {
          callNumber = val;
        }
      } else if (key.contains('ISBN号/定价') || key.contains('ISBN')) {
        if (val.contains(' / ')) {
          final parts = val.split(' / ');
          isbn = parts[0].trim();
          price = parts[1].trim();
        } else {
          isbn = val;
        }
        if (isbn == '7-' || isbn == '/' || isbn == '-') {
          isbn = '';
        }
        if (price == '0元' || price == '0.00元' || price == '/') {
          price = '';
        }
      } else if (key.contains('出版项')) {
        publishInfo = val;
      } else if (key.contains('载体形态') || key.contains('形态')) {
        physicalDesc = val;
      } else if (key.contains('丛编项') || key.contains('丛书')) {
        series = val;
      } else if (key.contains('文摘题要') || key.contains('简介') || key.contains('摘要')) {
        summary = val;
      } else if (text.isNotEmpty) {
        additionalInfo.add(text);
      }
    }

    // 解析馆藏副本表格
    final holdings = <LibraryBookHolding>[];
    final tables = doc.querySelectorAll('.tableLib .tableCon table');

    for (final table in tables) {
      String barcode = '';
      String volume = '';
      String accessionNo = '';
      String copyType = '';
      String status = '';
      String price = '';
      String holdingUnit = '';
      String location = '';
      String notes = '';

      final trs = table.querySelectorAll('tr');
      for (final tr in trs) {
        final th = tr.querySelector('th')?.text.trim() ?? '';
        final td = tr.querySelector('td')?.text.trim() ?? '';

        if (th == '条码号') {
          barcode = td;
        } else if (th == '卷册号') {
          volume = td;
        } else if (th == '登录号') {
          accessionNo = td;
        } else if (th == '单册类型') {
          copyType = td;
        } else if (th == '状态') {
          status = td;
        } else if (th == '单价') {
          price = td;
        } else if (th == '馆藏单位') {
          holdingUnit = td;
        } else if (th == '典藏地') {
          location = td;
        } else if (th == '拒借' || th == '备注') {
          notes = td;
        }
      }

      // 过滤页面底部的占位模板表格（其单元格值直接为字段名）
      if (barcode == '馆藏单位' || copyType == '到书时间' || location == '预约时间') {
        continue;
      }

      // 如果条码号或馆藏地有效，则是有效的单册行（跳过无效表）
      if (barcode.isNotEmpty || location.isNotEmpty || status.isNotEmpty) {
        holdings.add(LibraryBookHolding(
          barcode: barcode,
          volume: volume,
          accessionNo: accessionNo,
          copyType: copyType,
          status: status,
          price: price,
          holdingUnit: holdingUnit,
          location: location,
          notes: notes,
        ));
      }
    }

    return LibraryBookDetail(
      title: title,
      author: author,
      callNumber: callNumber,
      subject: subject,
      isbn: isbn,
      price: price,
      publishInfo: publishInfo,
      physicalDesc: physicalDesc,
      series: series,
      summary: summary,
      additionalInfo: additionalInfo,
      holdings: holdings,
      catalogItems: catalogItems,
    );
  }
}
