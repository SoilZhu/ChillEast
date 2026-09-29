/// 图书馆图书搜索与馆藏模型
class LibraryBook {
  final String detailParam;
  final String mainKey;
  final String title;
  final String author;
  final String callNumber; // 索书号
  final String isbn;
  final String publisher;
  final String publishYear;
  final String rawInfo;

  const LibraryBook({
    required this.detailParam,
    this.mainKey = '',
    required this.title,
    this.author = '',
    this.callNumber = '',
    this.isbn = '',
    this.publisher = '',
    this.publishYear = '',
    this.rawInfo = '',
  });

  factory LibraryBook.fromHtmlMap({
    required String detailParam,
    String mainKey = '',
    required String title,
    String author = '',
    String publisher = '',
    String callNumber = '',
    String isbn = '',
    String publishYear = '',
    String rawInfo = '',
  }) {
    return LibraryBook(
      detailParam: detailParam,
      mainKey: mainKey,
      title: title,
      author: author,
      callNumber: callNumber,
      isbn: isbn,
      publisher: publisher,
      publishYear: publishYear,
      rawInfo: rawInfo,
    );
  }
}

/// 图书单册馆藏副本状态
class LibraryBookHolding {
  final String barcode; // 条码号
  final String volume; // 卷册号
  final String accessionNo; // 登录号
  final String copyType; // 单册类型 (e.g. 样本书, 农业生物, 文学艺术)
  final String status; // 状态 (在库, 借出 等)
  final String price; // 单价
  final String holdingUnit; // 馆藏单位 (湖南农业大学文渊馆, 湖南农业大学图书馆 等)
  final String location; // 典藏地 (科图法图书书库, 社会科学图书阅览二区 等)
  final String notes; // 拒借 / 备注

  const LibraryBookHolding({
    this.barcode = '',
    this.volume = '',
    this.accessionNo = '',
    this.copyType = '',
    this.status = '',
    this.price = '',
    this.holdingUnit = '',
    this.location = '',
    this.notes = '',
  });

  bool get isAvailable => status.contains('在库') || status.contains('可借');
}

/// 图书详细信息（元数据 + 馆藏副本列表）
class LibraryBookDetail {
  final String title;
  final String author; // 责任者/作者
  final String callNumber; // 索书号
  final String subject; // 主题词
  final String isbn; // ISBN
  final String price; // 定价
  final String publishInfo; // 出版项
  final String physicalDesc; // 载体形态
  final String series; // 丛编项
  final String summary; // 文摘题要
  final List<String> additionalInfo;
  final List<LibraryBookHolding> holdings;
  final List<MapEntry<String, String>> catalogItems;

  const LibraryBookDetail({
    required this.title,
    this.author = '',
    this.callNumber = '',
    this.subject = '',
    this.isbn = '',
    this.price = '',
    this.publishInfo = '',
    this.physicalDesc = '',
    this.series = '',
    this.summary = '',
    this.additionalInfo = const [],
    this.holdings = const [],
    this.catalogItems = const [],
  });

  /// 保留原始目录格式的条目列表
  List<MapEntry<String, String>> get effectiveCatalogItems {
    if (catalogItems.isNotEmpty) return catalogItems;
    final items = <MapEntry<String, String>>[];
    if (author.isNotEmpty || title.isNotEmpty) {
      items.add(MapEntry(
        '题名/责任者',
        [if (title.isNotEmpty) title, if (author.isNotEmpty) author].join(' / '),
      ));
    }
    if (isbn.isNotEmpty || price.isNotEmpty) {
      items.add(MapEntry(
        'ISBN号/定价',
        [if (isbn.isNotEmpty) isbn, if (price.isNotEmpty) price].join(' / '),
      ));
    }
    if (publishInfo.isNotEmpty) {
      items.add(MapEntry('出版项', publishInfo));
    }
    if (subject.isNotEmpty || callNumber.isNotEmpty) {
      items.add(MapEntry(
        '主题词/索书号',
        [if (subject.isNotEmpty) subject, if (callNumber.isNotEmpty) callNumber]
            .join(' / '),
      ));
    }
    if (physicalDesc.isNotEmpty) {
      items.add(MapEntry('载体形态', physicalDesc));
    }
    if (series.isNotEmpty) {
      items.add(MapEntry('丛编项', series));
    }
    if (summary.isNotEmpty) {
      items.add(MapEntry('文摘题要', summary));
    }
    return items;
  }

  // 兼容旧字段属性访问
  String get authorAndResponsibility => author;
  String get isbnAndPrice =>
      [if (isbn.isNotEmpty) isbn, if (price.isNotEmpty) price].join(' / ');
  String get subjectAndCallNumber =>
      [if (subject.isNotEmpty) subject, if (callNumber.isNotEmpty) callNumber]
          .join(' / ');

  /// 在库副本数
  int get availableCount => holdings.where((h) => h.isAvailable).length;

  /// 总副本数
  int get totalCount => holdings.length;
}

/// 图书搜索结果包装
class LibraryBookSearchResult {
  final List<LibraryBook> books;
  final int totalCount;
  final int totalPages;

  const LibraryBookSearchResult({
    required this.books,
    required this.totalCount,
    required this.totalPages,
  });

  static const empty = LibraryBookSearchResult(
    books: [],
    totalCount: 0,
    totalPages: 0,
  );
}
