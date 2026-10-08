/// 宿舍单项属性
class DormitoryField {
  final String code;
  final String label;
  final String value;

  const DormitoryField({
    required this.code,
    required this.label,
    required this.value,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'label': label,
        'value': value,
      };

  factory DormitoryField.fromJson(Map<String, dynamic> json) => DormitoryField(
        code: json['code'] as String? ?? '',
        label: json['label'] as String? ?? '',
        value: json['value'] as String? ?? '',
      );
}

/// 宿舍信息实体模型
class DormitoryInfo {
  final bool isAssigned;
  final String? building;
  final String? unit;
  final String? floor;
  final String? room;
  final String? bed;
  final String? academicYear;
  final String? termCode;
  final String? termName;
  final List<DormitoryField> fields;

  const DormitoryInfo({
    required this.isAssigned,
    this.building,
    this.unit,
    this.floor,
    this.room,
    this.bed,
    this.academicYear,
    this.termCode,
    this.termName,
    this.fields = const [],
  });

  /// 格式化完整宿舍名称，如 "金岸1栋 629室" 或 "金岸1栋 2单元 629室"
  String get formattedRoom {
    if (!isAssigned) return '未安排床位';
    final parts = <String>[];
    if (building != null && building!.isNotEmpty) parts.add(building!);
    if (unit != null && unit!.isNotEmpty) parts.add(unit!);
    if (room != null && room!.isNotEmpty) parts.add('$room室');
    return parts.isEmpty ? (building ?? '未知宿舍') : parts.join(' ');
  }

  /// 格式化床号，如 "4号床"
  String? get formattedBed {
    if (bed == null || bed!.isEmpty) return null;
    return bed!.endsWith('号床') || bed!.endsWith('床') ? bed : '$bed号床';
  }

  /// 完整地址描述，如 "金岸1栋 629室 4号床"
  String get fullAddress {
    if (!isAssigned) return '未安排床位';
    final roomStr = formattedRoom;
    final bedStr = formattedBed;
    if (bedStr != null && bedStr.isNotEmpty) {
      return '$roomStr $bedStr';
    }
    return roomStr;
  }

  Map<String, dynamic> toJson() => {
        'isAssigned': isAssigned,
        'building': building,
        'unit': unit,
        'floor': floor,
        'room': room,
        'bed': bed,
        'academicYear': academicYear,
        'termCode': termCode,
        'termName': termName,
        'fields': fields.map((e) => e.toJson()).toList(),
      };

  factory DormitoryInfo.fromJson(Map<String, dynamic> json) => DormitoryInfo(
        isAssigned: json['isAssigned'] as bool? ?? false,
        building: json['building'] as String?,
        unit: json['unit'] as String?,
        floor: json['floor'] as String?,
        room: json['room'] as String?,
        bed: json['bed'] as String?,
        academicYear: json['academicYear'] as String?,
        termCode: json['termCode'] as String?,
        termName: json['termName'] as String?,
        fields: (json['fields'] as List<dynamic>?)
                ?.map((e) => DormitoryField.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  /// 从 `wyDorm` 页面 HTML 解析宿舍与床位数据
  factory DormitoryInfo.fromHtml(String html) {
    // 1. 过滤单行注释与块注释，防止匹配到被注释的代码 (例如 // view.createRow("ssl", "宿舍楼", "未安排床位");)
    final withoutBlockComments = html.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
    final cleanLines = <String>[];
    for (final line in withoutBlockComments.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('//')) continue;
      cleanLines.add(line);
    }
    final cleanText = cleanLines.join('\n');

    // 2. 学年与学期
    final xnMatch =
        RegExp(r'''SFSchCalendar\.curXn\s*=\s*["']([^"']*)["']''').firstMatch(cleanText);
    final xqMatch =
        RegExp(r'''SFSchCalendar\.curXq\s*=\s*["']([^"']*)["']''').firstMatch(cleanText);
    final xqMcMatch =
        RegExp(r'''SFSchCalendar\.curXqMc\s*=\s*["']([^"']*)["']''').firstMatch(cleanText);
    final chMatch = RegExp(r'''var\s+ch\s*=\s*["']([^"']*)["']''').firstMatch(cleanText);

    final academicYear = xnMatch?.group(1)?.trim();
    final termCode = xqMatch?.group(1)?.trim();
    final termName = xqMcMatch?.group(1)?.trim();
    final bedVar = chMatch?.group(1)?.trim() ?? '';

    // 3. 提取所有 view.createRow(code, label, value)
    final rowRegex = RegExp(
        r'''view\.createRow\s*\(\s*["']([^"']*)["']\s*,\s*["']([^"']*)["']\s*,\s*["']([^"']*)["']\s*\)''');
    final rowMatches = rowRegex.allMatches(cleanText);

    final fields = <DormitoryField>[];
    String? building;
    String? unit;
    String? floor;
    String? room;
    String? bed;

    for (final m in rowMatches) {
      final code = m.group(1)?.trim() ?? '';
      final label = m.group(2)?.trim() ?? '';
      final value = m.group(3)?.trim() ?? '';

      fields.add(DormitoryField(code: code, label: label, value: value));

      switch (code) {
        case 'ssl':
          building = value.isNotEmpty ? value : null;
          break;
        case 'dy':
          unit = value.isNotEmpty ? value : null;
          break;
        case 'lc':
          floor = value.isNotEmpty ? value : null;
          break;
        case 'fj':
          room = value.isNotEmpty ? value : null;
          break;
        case 'ch':
          bed = value.isNotEmpty ? value : null;
          break;
      }
    }

    if ((bed == null || bed.isEmpty) && bedVar.isNotEmpty) {
      bed = bedVar;
    }

    final isAssigned = (bed != null &&
            bed.isNotEmpty &&
            bed != '未安排床位' &&
            building != null &&
            !building.contains('未安排')) ||
        (room != null && room.isNotEmpty && building != null);

    return DormitoryInfo(
      isAssigned: isAssigned,
      building: building,
      unit: unit,
      floor: floor,
      room: room,
      bed: bed,
      academicYear: academicYear,
      termCode: termCode,
      termName: termName,
      fields: fields,
    );
  }
}
