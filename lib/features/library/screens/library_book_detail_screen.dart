import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/l10n_extension.dart';
import '../models/library_book_models.dart';
import '../providers/library_provider.dart';

class LibraryBookDetailScreen extends ConsumerStatefulWidget {
  final LibraryBook book;

  const LibraryBookDetailScreen({
    super.key,
    required this.book,
  });

  @override
  ConsumerState<LibraryBookDetailScreen> createState() =>
      _LibraryBookDetailScreenState();
}

class _LibraryBookDetailScreenState
    extends ConsumerState<LibraryBookDetailScreen> {
  late Future<LibraryBookDetail> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _fetch();
  }

  Future<LibraryBookDetail> _fetch() {
    return ref.read(libraryBookServiceProvider).fetchBookDetail(widget.book);
  }

  void _retry() {
    setState(() {
      _detailFuture = _fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.l10n.bookDetailTitle),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
      ),
      body: FutureBuilder<LibraryBookDetail>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF09C489)),
            );
          }

          if (snapshot.hasError) {
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
                      snapshot.error
                          .toString()
                          .replaceAll('Exception:', '')
                          .trim(),
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
                      onPressed: _retry,
                      child: Text(context.l10n.retry),
                    ),
                  ],
                ),
              ),
            );
          }

          final detail = snapshot.data!;
          return _buildDetailContent(detail, isDark);
        },
      ),
    );
  }

  Widget _buildDetailContent(LibraryBookDetail detail, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. 图书主要信息（不包在框内）
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.title,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 14),
              for (final item in detail.effectiveCatalogItems)
                _buildInfoRow(
                  _iconForLabel(item.key),
                  item.key,
                  item.value,
                  isDark,
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 2. 馆藏副本标题（不显示“在馆”）
        Text(
          context.l10n.holdingsTitle,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),

        const SizedBox(height: 12),

        // 3. 馆藏副本列表
        if (detail.holdings.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFE8E8E8),
              ),
            ),
            child: Text(
              '暂无馆藏详细副本信息',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey,
                fontSize: 14,
              ),
            ),
          )
        else
          ...detail.holdings.map((h) => _buildHoldingItem(h, isDark)),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    bool isDark,
  ) {
    final cleanValue = value.replaceFirst(RegExp(r'^[:：\s]+'), '').trim();
    final cleanLabel = label.replaceAll(RegExp(r'[:：\s]+$'), '').trim();
    final isCallNumber = cleanLabel.contains('索书号');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: isCallNumber ? 2 : 0),
            child: Icon(
              icon,
              size: 16,
              color: isDark ? Colors.white38 : Colors.grey[500],
            ),
          ),
          const SizedBox(width: 8),
          if (cleanLabel.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: isCallNumber ? 1 : 0),
              child: Text(
                '$cleanLabel：',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ),
          Expanded(
            child: isCallNumber
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF09C489).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        cleanValue,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF09C489),
                        ),
                      ),
                    ),
                  )
                : Text(
                    cleanValue,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  IconData _iconForLabel(String label) {
    if (label.contains('题名') || label.contains('责任者') || label.contains('作者')) {
      return Icons.person_outline_rounded;
    }
    if (label.contains('ISBN') || label.contains('定价')) {
      return Icons.tag_rounded;
    }
    if (label.contains('出版')) {
      return Icons.business_outlined;
    }
    if (label.contains('索书号') || label.contains('主题')) {
      return Icons.bookmark_outline_rounded;
    }
    if (label.contains('形态')) {
      return Icons.menu_book_rounded;
    }
    if (label.contains('丛编') || label.contains('丛书')) {
      return Icons.collections_bookmark_outlined;
    }
    if (label.contains('文摘') ||
        label.contains('题要') ||
        label.contains('简介') ||
        label.contains('摘要')) {
      return Icons.description_outlined;
    }
    return Icons.info_outline_rounded;
  }

  Widget _buildHoldingItem(LibraryBookHolding holding, bool isDark) {
    final isAvailable = holding.isAvailable;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  holding.holdingUnit.isNotEmpty
                      ? holding.holdingUnit
                      : '湖南农业大学图书馆',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? const Color(0xFF09C489).withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  holding.status.isNotEmpty ? holding.status : '在库',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isAvailable ? const Color(0xFF09C489) : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (holding.location.isNotEmpty)
            Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 15,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${context.l10n.holdingLocation}: ${holding.location}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (holding.barcode.isNotEmpty)
                Text(
                  '${context.l10n.barcode}: ${holding.barcode}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.grey[600],
                  ),
                ),
              if (holding.accessionNo.isNotEmpty)
                Text(
                  '${context.l10n.accessionNo}: ${holding.accessionNo}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.grey[600],
                  ),
                ),
              if (holding.copyType.isNotEmpty)
                Text(
                  '${context.l10n.copyType}: ${holding.copyType}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.grey[600],
                  ),
                ),
              if (holding.notes.isNotEmpty)
                Text(
                  '备注: ${holding.notes}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.redAccent,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
