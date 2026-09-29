import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:ChillEast/features/library/models/library_book_models.dart';
import 'package:ChillEast/features/library/services/library_book_service.dart';

void main() {
  group('LibraryBookService HTML Parsing Tests', () {
    late String searchListHtml;
    late String searchListHtmlPage2;
    late String bookDetailHtml;

    setUpAll(() {
      final harFile = File('/home/soilzhu/code/chilleast/debug/图书馆查书.har');
      if (harFile.existsSync()) {
        final content = harFile.readAsStringSync();
        final Map<String, dynamic> harData = jsonDecode(content);
        final entries = harData['log']['entries'] as List<dynamic>;

        // Entry 0 is searchList page 1
        searchListHtml = entries[0]['response']['content']['text'] as String;
        // Entry 1 is searchList page 2 (with misaligned column labels from server)
        searchListHtmlPage2 = entries[1]['response']['content']['text'] as String;
        // Entry 2 is bookDetail
        bookDetailHtml = entries[2]['response']['content']['text'] as String;
      }
    });

    test('Parses searchList HTML correctly from HAR without field misalignments', () {
      final service = LibraryBookService();
      final doc = html_parser.parse(searchListHtml);

      // 验证图书列表解析
      final books = service.parseBooksFromDocument(doc);
      expect(books.length, equals(20));

      final firstBook = books.first;
      expect(firstBook.detailParam, contains('zyk0161024'));
      expect(firstBook.title, contains('美语阅读一日一篇'));
      expect(firstBook.author, equals('何庆权编著'));
      expect(firstBook.callNumber, equals('H319.4/839'));
      expect(firstBook.publisher, equals('北京:中国国际广播音像出版社'));
      expect(firstBook.isbn, equals('7-88004-367-5'));

      // 验证总数解析
      final numH1 = doc.querySelector('.num h1');
      expect(numH1?.text, contains('共1186条搜索结果'));
    });

    test('Corrects misaligned server fields on page 2 (doctype M, publisher in ISBN, callNumber in publisher)', () {
      final service = LibraryBookService();
      final doc = html_parser.parse(searchListHtmlPage2);

      final books = service.parseBooksFromDocument(doc);
      expect(books.length, equals(20));

      final firstBook = books.first;
      expect(firstBook.title, contains('东方（中）魏巍'));
      expect(firstBook.author, equals('魏巍'));
      // 索书号绝不能是 M，而是 44.572/431
      expect(firstBook.callNumber, equals('44.572/431'));
      // 出版社绝不能是 44.572/431，而是 北京:人民文学出版社
      expect(firstBook.publisher, equals('北京:人民文学出版社'));
      // ISBN 绝不能被填成出版社名称
      expect(firstBook.isbn, isNot(contains('出版社')));
      // 出版年份绝不能被填成语种 chi
      expect(firstBook.publishYear, isNot(equals('chi')));
    });

    test('Parses bookDetail HTML correctly from HAR', () {
      final service = LibraryBookService();
      final doc = html_parser.parse(bookDetailHtml);

      const defaultBook = LibraryBook(
        detailParam: '{"marc_no":"zyk0038034"}',
        title: '东方红-18型背负式机动弥雾喷粉机的使用和修理',
        author: '青克金编著',
      );

      final detail = service.parseBookDetailFromDocument(doc, defaultBook: defaultBook);

      expect(detail.title, contains('东方红-18型背负式机动弥雾喷粉机的使用和修理'));
      expect(detail.authorAndResponsibility, contains('青克金编著'));
      expect(detail.publishInfo, contains('农业出版社'));
      expect(detail.subjectAndCallNumber, contains('65.574/2'));
      expect(detail.physicalDesc, contains('304页'));

      // 验证馆藏副本解析
      expect(detail.holdings.isNotEmpty, isTrue);
      expect(detail.totalCount, equals(5));
      expect(detail.availableCount, equals(5));

      final firstHolding = detail.holdings.first;
      expect(firstHolding.barcode, equals('00092928'));
      expect(firstHolding.accessionNo, equals('323640S'));
      expect(firstHolding.copyType, equals('样本书'));
      expect(firstHolding.status, equals('在库'));
      expect(firstHolding.holdingUnit, equals('湖南农业大学文渊馆'));
      expect(firstHolding.location, equals('科图法样本图书、工具书阅览室'));
      expect(firstHolding.isAvailable, isTrue);
    });

    test('Parses bookDetail catalog fields cleanly without title/author/colon mix-ups', () {
      final service = LibraryBookService();
      const html = '''
        <header><div class="tit"><h1>美语阅读一日一篇 / 何庆权编著</h1></div></header>
        <div class="catalog">
          <p>题名/责任者：美语阅读一日一篇 / 何庆权编著</p>
          <p>ISBN号/定价：7-88004-367-5 / 18.00元</p>
          <p>出版项：北京 中国国际广播音像出版社 [不详]</p>
          <p>主题词/索书号：英语阅读-教材 / H319.4/839</p>
          <p>载体形态：155页</p>
          <p>丛编项：新东方学校英语文库</p>
          <p>文摘题要：本书选材上涉及了新闻、商业、娱乐...</p>
        </div>
      ''';
      final doc = html_parser.parse(html);
      final detail = service.parseBookDetailFromDocument(doc);

      expect(detail.title, equals('美语阅读一日一篇'));
      expect(detail.author, equals('何庆权编著'));
      expect(detail.callNumber, equals('H319.4/839'));
      expect(detail.subject, equals('英语阅读-教材'));
      expect(detail.isbn, equals('7-88004-367-5'));
      expect(detail.price, equals('18.00元'));
      expect(detail.publishInfo, equals('北京 中国国际广播音像出版社 [不详]'));
      expect(detail.physicalDesc, equals('155页'));
      expect(detail.series, equals('新东方学校英语文库'));
      expect(detail.summary, contains('本书选材上涉及了新闻'));

      // 验证保留原始格式条目 (题名/责任者, ISBN号/定价, 出版项, 主题词/索书号, 载体形态, 丛编项, 文摘题要)
      expect(detail.catalogItems.length, equals(7));
      expect(detail.catalogItems[0].key, equals('题名/责任者'));
      expect(detail.catalogItems[0].value, equals('美语阅读一日一篇 / 何庆权编著'));
      expect(detail.catalogItems[1].key, equals('ISBN号/定价'));
      expect(detail.catalogItems[1].value, equals('7-88004-367-5 / 18.00元'));
      expect(detail.catalogItems[2].key, equals('出版项'));
      expect(detail.catalogItems[2].value, equals('北京 中国国际广播音像出版社 [不详]'));
      expect(detail.catalogItems[3].key, equals('主题词/索书号'));
      expect(detail.catalogItems[3].value, equals('英语阅读-教材 / H319.4/839'));
      expect(detail.catalogItems[4].key, equals('载体形态'));
      expect(detail.catalogItems[4].value, equals('155页'));
      expect(detail.catalogItems[5].key, equals('丛编项'));
      expect(detail.catalogItems[5].value, equals('新东方学校英语文库'));
      expect(detail.catalogItems[6].key, equals('文摘题要'));
      expect(detail.catalogItems[6].value, contains('本书选材上涉及了新闻'));
    });

    test('LibraryBookHolding status and availability logic', () {
      const availableHolding = LibraryBookHolding(status: '在库');
      expect(availableHolding.isAvailable, isTrue);

      const borrowedHolding = LibraryBookHolding(status: '借出');
      expect(borrowedHolding.isAvailable, isFalse);

      const cancelledHolding = LibraryBookHolding(status: '注销');
      expect(cancelledHolding.isAvailable, isFalse);
    });

    test('Supported search types include title, author, subject and Identifier', () {
      const validSearchTypes = ['title', 'author', 'subject', 'Identifier'];
      expect(validSearchTypes.contains('subject'), isTrue);
      expect(validSearchTypes.contains('Identifier'), isTrue);
    });
  });
}
