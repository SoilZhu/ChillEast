import 'package:flutter/material.dart';

/// 公交线路定义
class CampusBusLine {
  final String id;
  final String name;
  final String englishName;
  final Color color;
  final List<String> stationIds;
  final String description;
  final bool isLoop;

  const CampusBusLine({
    required this.id,
    required this.name,
    required this.englishName,
    required this.color,
    required this.stationIds,
    required this.description,
    this.isLoop = false,
  });
}

/// 站点标签对齐方式
enum StationLabelAnchor {
  start, // 靠左对齐，置于站点右侧
  end, // 靠右对齐，置于站点左侧
  middle, // 居中对齐，置于站点上方或下方
}

/// 站点定义
class CampusBusStation {
  final String id;
  final String name;
  final String englishName;
  final String? primaryTitle;
  final String? subtitle;
  final double normX; // 归一化 X (0.0 ~ 1.0)
  final double normY; // 归一化 Y (0.0 ~ 1.0)
  final StationLabelAnchor labelAnchor;
  final double labelDx;
  final double labelDy;
  final List<String> lineIds;
  final String? transferInfo;
  final String? nearbyHint;

  const CampusBusStation({
    required this.id,
    required this.name,
    required this.englishName,
    this.primaryTitle,
    this.subtitle,
    required this.normX,
    required this.normY,
    required this.labelAnchor,
    required this.labelDx,
    required this.labelDy,
    required this.lineIds,
    this.transferInfo,
    this.nearbyHint,
  });
}

/// 静态数据源
class CampusBusRepository {
  static const double canvasWidth = 827.452;
  static const double canvasHeight = 513.126;
  static const double canvasMinX = -220.381;
  static const double canvasMinY = 92.048;

  // 线路定义
  static const List<CampusBusLine> lines = [
    CampusBusLine(
      id: 'red_loop',
      name: '红色环线',
      englishName: 'Red Loop Line',
      color: Color(0xFFE3002B),
      description: '贯通丰泽、修业、生科楼、丹桂、实训工厂与体育馆的校园主干环线',
      isLoop: true,
      stationIds: [
        'fengze',
        'xiuye',
        'library',
        'canteen',
        'square',
        'wenyuan',
        'building7',
        'factory',
        'gym',
        'hongqi',
      ],
    ),
    CampusBusLine(
      id: 'green_line',
      name: '绿色线路',
      englishName: 'Green Line',
      color: Color(0xFF00AD54),
      description: '自兴湘楼、北门经图书馆、芷兰公寓北直达新体育馆与岳麓山实验室',
      isLoop: false,
      stationIds: [
        'xingxiang',
        'north_gate',
        'library',
        'zhilan_north',
        'gym',
        'yuelushan_lab',
      ],
    ),
    CampusBusLine(
      id: 'purple_line',
      name: '紫色支线',
      englishName: 'Purple Branch Line',
      color: Color(0xFF950BA8),
      description: '自碧荷轩、行政楼横贯生科楼、丹桂公寓至体育馆与岳麓山实验室',
      isLoop: false,
      stationIds: [
        'bihexuan',
        'admin_building',
        'wenyuan',
        'building7',
        'gym',
        'yuelushan_lab',
      ],
    ),
    CampusBusLine(
      id: 'metro_feeder',
      name: '地铁接驳线',
      englishName: 'Metro Feeder Line',
      color: Color(0xFFA3C10B),
      description: '无缝接驳长沙地铁6号线「农科院农大站」与学校「北门」',
      isLoop: false,
      stationIds: [
        'metro_stn',
        'north_gate',
      ],
    ),
    CampusBusLine(
      id: 'metro_line6',
      name: '长沙地铁6号线',
      englishName: 'Changsha Metro Line 6',
      color: Color(0xFF2559A8),
      description: '城市轨道交通，农科院农大站为校外核心接驳站点',
      isLoop: false,
      stationIds: [
        'metro_stn',
      ],
    ),
  ];

  // 站点列表（含精确归一化坐标与原生文字布局参数）
  static const List<CampusBusStation> stations = [
    CampusBusStation(
      id: 'metro_stn',
      name: '农科院农大站',
      englishName: 'Academy of Agri-Sciences & Agri-University',
      normX: 0.4053,
      normY: 0.1617,
      labelAnchor: StationLabelAnchor.start,
      labelDx: 14.0,
      labelDy: -24.0,
      lineIds: ['metro_line6', 'metro_feeder'],
      transferInfo: '换乘长沙地铁6号线 / 地铁接驳线',
      nearbyHint: '地铁6号线出口，可快速进出校园',
    ),
    CampusBusStation(
      id: 'north_gate',
      name: '北门',
      englishName: 'North Gate',
      normX: 0.6906,
      normY: 0.3995,
      labelAnchor: StationLabelAnchor.start,
      labelDx: 14.0,
      labelDy: -16.0,
      lineIds: ['green_line', 'metro_feeder'],
      transferInfo: '换乘地铁接驳线至地铁6号线',
      nearbyHint: '学校北校门、靠近修业广场',
    ),
    CampusBusStation(
      id: 'xingxiang',
      name: '兴湘楼',
      englishName: 'Xing-Xiang Building',
      normX: 0.8102,
      normY: 0.3176,
      labelAnchor: StationLabelAnchor.start,
      labelDx: 14.0,
      labelDy: -8.0,
      lineIds: ['green_line'],
      nearbyHint: '兴湘教学楼、东北生活区',
    ),
    CampusBusStation(
      id: 'fengze',
      name: '丰泽公寓',
      englishName: 'FengZe Apartment',
      normX: 0.5866,
      normY: 0.4832,
      labelAnchor: StationLabelAnchor.end,
      labelDx: -14.0,
      labelDy: -18.0,
      lineIds: ['red_loop'],
      nearbyHint: '丰泽学生公寓宿舍区',
    ),
    CampusBusStation(
      id: 'xiuye',
      name: '修业广场',
      englishName: 'XiuYe Square',
      normX: 0.6812,
      normY: 0.4832,
      labelAnchor: StationLabelAnchor.end,
      labelDx: -14.0,
      labelDy: -18.0,
      lineIds: ['red_loop'],
      nearbyHint: '修业大楼、修业广场学生活动中心',
    ),
    CampusBusStation(
      id: 'library',
      name: '图书馆',
      englishName: 'Library',
      normX: 0.7651,
      normY: 0.5401,
      labelAnchor: StationLabelAnchor.start,
      labelDx: 16.0,
      labelDy: -8.0,
      lineIds: ['red_loop', 'green_line'],
      transferInfo: '红绿双线换乘枢纽',
      nearbyHint: '主校区图书馆、学习研讨中心',
    ),
    CampusBusStation(
      id: 'canteen',
      name: '教工食堂',
      englishName: 'Faculty canteen',
      normX: 0.7651,
      normY: 0.6545,
      labelAnchor: StationLabelAnchor.start,
      labelDx: 16.0,
      labelDy: -8.0,
      lineIds: ['red_loop'],
      nearbyHint: '教工餐厅、教职工活动中心',
    ),
    CampusBusStation(
      id: 'square',
      name: '中心广场',
      englishName: 'Central Square',
      normX: 0.7651,
      normY: 0.7583,
      labelAnchor: StationLabelAnchor.start,
      labelDx: 16.0,
      labelDy: -8.0,
      lineIds: ['red_loop'],
      nearbyHint: '校区中心广场、主大道交汇处',
    ),
    CampusBusStation(
      id: 'bihexuan',
      name: '碧荷轩',
      englishName: 'BiHe Xuan',
      normX: 0.8614,
      normY: 0.8129,
      labelAnchor: StationLabelAnchor.start,
      labelDx: 14.0,
      labelDy: -8.0,
      lineIds: ['purple_line'],
      nearbyHint: '碧荷轩园区、东苑生活区',
    ),
    CampusBusStation(
      id: 'admin_building',
      name: '行政楼（一教）',
      primaryTitle: '行政楼（一教）',
      englishName: 'Administration Building\n(No.1 Teaching Building)',
      normX: 0.7861,
      normY: 0.8129,
      labelAnchor: StationLabelAnchor.middle,
      labelDx: 0.0,
      labelDy: 16.0,
      lineIds: ['purple_line'],
      nearbyHint: '学校办公大楼、第一教学楼',
    ),
    CampusBusStation(
      id: 'wenyuan',
      name: '文渊馆（生科楼）',
      primaryTitle: '文渊馆',
      subtitle: '（生科楼）',
      englishName: 'WenYuan Hall\n(Life-Sci Building)',
      normX: 0.6812,
      normY: 0.8129,
      labelAnchor: StationLabelAnchor.middle,
      labelDx: 0.0,
      labelDy: 16.0,
      lineIds: ['red_loop', 'purple_line'],
      transferInfo: '红紫双线换乘站',
      nearbyHint: '生物科学楼、文渊馆教学区',
    ),
    CampusBusStation(
      id: 'building7',
      name: '第七教学楼（丹桂公寓）',
      primaryTitle: '第七教学楼',
      subtitle: '（丹桂公寓）',
      englishName: 'No.7 Teaching Build\n(DanGui Apartment)',
      normX: 0.6155,
      normY: 0.8129,
      labelAnchor: StationLabelAnchor.middle,
      labelDx: 0.0,
      labelDy: -44.0,
      lineIds: ['red_loop', 'purple_line'],
      transferInfo: '红紫双线换乘站',
      nearbyHint: '第七教学楼、丹桂学生公寓区',
    ),
    CampusBusStation(
      id: 'factory',
      name: '实训工厂',
      englishName: 'Training Factory',
      normX: 0.5469,
      normY: 0.8763,
      labelAnchor: StationLabelAnchor.middle,
      labelDx: 0.0,
      labelDy: 14.0,
      lineIds: ['red_loop'],
      nearbyHint: '工程工程训练中心、实践基地',
    ),
    CampusBusStation(
      id: 'gym',
      name: '新体育馆',
      englishName: 'New stadium',
      normX: 0.5004,
      normY: 0.6421,
      labelAnchor: StationLabelAnchor.end,
      labelDx: -16.0,
      labelDy: -8.0,
      lineIds: ['red_loop', 'green_line', 'purple_line'],
      transferInfo: '三线交汇超级枢纽',
      nearbyHint: '综合体育馆、田径场、风雨操场',
    ),
    CampusBusStation(
      id: 'hongqi',
      name: '红旗市场',
      englishName: 'HongQi Market',
      normX: 0.5004,
      normY: 0.5524,
      labelAnchor: StationLabelAnchor.end,
      labelDx: -16.0,
      labelDy: -18.0,
      lineIds: ['red_loop'],
      nearbyHint: '红旗商业街、西区生活圈',
    ),
    CampusBusStation(
      id: 'zhilan_north',
      name: '芷兰公寓北',
      englishName: 'ZhiLan Apartment North',
      normX: 0.6313,
      normY: 0.6421,
      labelAnchor: StationLabelAnchor.start,
      labelDx: 14.0,
      labelDy: -18.0,
      lineIds: ['green_line'],
      nearbyHint: '芷兰公寓区北门、学子聚集区',
    ),
    CampusBusStation(
      id: 'yuelushan_lab',
      name: '岳麓山实验室',
      englishName: 'YueLuShan Laboratory',
      normX: 0.4009,
      normY: 0.5765,
      labelAnchor: StationLabelAnchor.end,
      labelDx: -16.0,
      labelDy: -8.0,
      lineIds: ['green_line', 'purple_line'],
      transferInfo: '绿紫双线终点站',
      nearbyHint: '岳麓山国家实验室科研重镇',
    ),
  ];

  static CampusBusStation? getStationById(String id) {
    for (final s in stations) {
      if (s.id == id) return s;
    }
    return null;
  }

  static CampusBusLine? getLineById(String id) {
    for (final l in lines) {
      if (l.id == id) return l;
    }
    return null;
  }

  static List<CampusBusStation> getStationsForLine(String lineId) {
    final line = getLineById(lineId);
    if (line == null) return [];
    return line.stationIds
        .map((id) => getStationById(id))
        .whereType<CampusBusStation>()
        .toList();
  }
}
