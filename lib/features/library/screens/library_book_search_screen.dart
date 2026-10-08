import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import '../models/library_book_models.dart';
import '../providers/library_provider.dart';
import 'library_book_detail_screen.dart';

class LibraryBookSearchScreen extends ConsumerStatefulWidget {
  const LibraryBookSearchScreen({super.key});

  @override
  ConsumerState<LibraryBookSearchScreen> createState() =>
      _LibraryBookSearchScreenState();
}

class _LibraryBookSearchScreenState
    extends ConsumerState<LibraryBookSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    ref.read(libraryBookSearchProvider.notifier).cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearch() {
    final text = _searchController.text.trim();
    if (text.isEmpty) return;
    _focusNode.unfocus();
    ref.read(libraryBookSearchProvider.notifier).search(text);
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(libraryBookSearchProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          ref.read(libraryBookSearchProvider.notifier).cancel();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(context.l10n.bookSearch),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: isDark ? Colors.white : Colors.black87,
          elevation: 0,
        ),
        body: Column(
          children: [
            // 1. 搜索框与类型切换栏
            _buildSearchHeader(searchState, isDark),

            // 2. 加载进度提示栏
            if (searchState.isLoading)
              _buildLoadingIndicator(searchState, isDark),

            // 3. 结果或状态内容区
            Expanded(
              child: _buildBody(searchState, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(LibraryBookSearchState state, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Column(
        children: [
          // 输入框行
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : const Color(0xFFE2E4E8),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: isDark ? Colors.white38 : Colors.grey[500],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _onSearch(),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            fillColor: Colors.transparent,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          color: isDark ? Colors.white38 : Colors.grey[500],
                          splashRadius: 16,
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF09C489),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(64, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _onSearch,
                child: Text(
                  context.l10n.search,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 检索类型切换器（书名 / 作者 / 主题 / 标准编码）左对齐，样式与阳光服务一致
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTypeChip('title', context.l10n.searchTypeTitle, state.searchType, isDark),
                  const SizedBox(width: 8),
                  _buildTypeChip('author', context.l10n.searchTypeAuthor, state.searchType, isDark),
                  const SizedBox(width: 8),
                  _buildTypeChip('subject', context.l10n.searchTypeSubject, state.searchType, isDark),
                  const SizedBox(width: 8),
                  _buildTypeChip('Identifier', context.l10n.searchTypeIdentifier, state.searchType, isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(
    String type,
    String label,
    String currentType,
    bool isDark,
  ) {
    final isSelected = type == currentType;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          ref.read(libraryBookSearchProvider.notifier).setSearchType(type);
          if (_searchController.text.trim().isNotEmpty) {
            _onSearch();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF09C489)
                  : (isDark ? Colors.white24 : const Color(0xFFDADCE0)),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isSelected
                  ? const Color(0xFF09C489)
                  : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(LibraryBookSearchState state, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF09C489).withValues(alpha: 0.1),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF09C489),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.bookSearchLoading,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF09C489),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(LibraryBookSearchState state, bool isDark) {
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF09C489),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: _onSearch,
                child: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (state.result == null) {
      return const SizedBox.shrink();
    }

    final books = state.result!.books;
    if (books.isEmpty) {
      if (state.isLoading) {
        return const SizedBox.shrink();
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.bookSearchEmpty,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: books.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              context.l10n.bookSearchTotalCount(books.length),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white54 : Colors.grey[700],
              ),
            ),
          );
        }

        final book = books[index - 1];
        return _buildBookCard(book, isDark);
      },
    );
  }

  Widget _buildBookCard(LibraryBook book, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFE8E8E8),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Navigator.push(
              context,
              createSlideUpRoute(LibraryBookDetailScreen(book: book)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 题名与箭头
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: isDark ? Colors.white38 : Colors.grey[400],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // 作者与出版社
                if (book.author.isNotEmpty || book.publisher.isNotEmpty)
                  Text(
                    [
                      if (book.author.isNotEmpty) book.author,
                      if (book.publisher.isNotEmpty) book.publisher,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                    ),
                  ),

                const SizedBox(height: 8),

                // 索书号与出版年份标签
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (book.callNumber.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF09C489).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${context.l10n.callNumber}: ${book.callNumber}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF09C489),
                          ),
                        ),
                      ),
                    if (book.isbn.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFF2F3F5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ISBN: ${book.isbn}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ),
                    if (book.publishYear.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFF2F3F5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          book.publishYear,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
