// 解析报修流转日志 `description` 中的附件标记，供详情页富文本渲染.
//
// 约定来自 Web 端实现（见 `debug/报修系统` HAR 内嵌 JS `saveToLog`）：
// - 上传：`...上传附件$$"name"$$<<rpc?method=/v2/file/download&id=xxx>>`
//   文件名引号可能是直引号 `"`，也可能是中文引号 `“”`（Web 端两种都出现过）。
// - 删除：`...删除附件“name”**rpc?method=/v2/file/download&id=xxx**`
//
// 解析结果只含两种段：纯文本段与附件段（附件段可点预览）。
// 其余 `<<..>>` / `**..**` 若包裹的是链接则直接丢弃，只留可读文字。

class RepairLogSegment {
  const RepairLogSegment.text(this.text)
      : isFile = false,
        fileId = null;

  const RepairLogSegment.file({
    required this.text,
    required this.fileId,
  }) : isFile = true;

  final bool isFile;

  /// 显示文本：附件段为归一化后的 `“文件名”`，文本段为去标记后的原文。
  final String text;

  /// 附件段的 `/v2/file/download` id，文本段为 null。
  final String? fileId;
}

final _uploadPattern = RegExp(r'\$\$[“”"]?(.+?)[“”"]?\$\$<<(.+?)>>');
final _markPattern = RegExp(r'(\*\*(.+?)\*\*|<<(.+?)>>)');
final _linkLikePattern = RegExp(r'method=|://|^rpc\?');
final _fileIdPattern = RegExp(r'[?&]id=([^&>\s]+)');
final _quotePattern = RegExp(r'[“”"]');

/// 从 `rpc?method=/v2/file/download&id=xxx` 这类链接中提取文件 id。
String? extractRepairFileId(String link) {
  final match = _fileIdPattern.firstMatch(link);
  return match?.group(1);
}

/// 去掉段内引号，得到裸文件名。
String repairLogFileName(String text) =>
    text.replaceAll(_quotePattern, '').trim();

/// 去掉 `**..**` / `<<..>>` 标记：链接型整个丢弃，普通文字保留内部。
String _cleanText(String s) {
  return s
      .replaceAllMapped(_markPattern, (m) {
        final inner = (m.group(2) ?? m.group(3) ?? '').trim();
        if (inner.isEmpty || _linkLikePattern.hasMatch(inner)) return '';
        return inner;
      })
      .replaceAll(r'$$', '');
}

List<RepairLogSegment> parseRepairLogDescription(String raw) {
  if (raw.isEmpty) return const [];
  final segments = <RepairLogSegment>[];
  var pos = 0;
  for (final m in _uploadPattern.allMatches(raw)) {
    if (m.start > pos) {
      final text = _cleanText(raw.substring(pos, m.start));
      if (text.isNotEmpty) segments.add(RepairLogSegment.text(text));
    }
    final name = m.group(1)!.trim();
    final fileId = extractRepairFileId(m.group(2)!.trim());
    if (name.isNotEmpty && fileId != null && fileId.isNotEmpty) {
      segments.add(RepairLogSegment.file(text: '“$name”', fileId: fileId));
    } else {
      final fallback = _cleanText(m.group(0)!);
      if (fallback.isNotEmpty) {
        segments.add(RepairLogSegment.text(fallback));
      }
    }
    pos = m.end;
  }
  if (pos < raw.length) {
    final text = _cleanText(raw.substring(pos));
    if (text.isNotEmpty) segments.add(RepairLogSegment.text(text));
  }
  return segments;
}
