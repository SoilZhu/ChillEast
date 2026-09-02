import 'dart:convert';

/// 图书馆预约记录状态
enum ReserveStatus {
  reserved, // 0: 待签到 / 预约中
  inUse,    // 1: 使用中 / 已签到
  temporarilyAway, // 3: 暂离
  flexibleSign, // 5: 弹性签到
  completed, // 7: 已完成 / 结束
  cancelled, // 已取消
  unknown;

  static ReserveStatus fromInt(int? val) {
    switch (val) {
      case 0:
        return ReserveStatus.reserved;
      case 1:
        return ReserveStatus.inUse;
      case 3:
        return ReserveStatus.temporarilyAway;
      case 5:
        return ReserveStatus.flexibleSign;
      case 7:
        return ReserveStatus.completed;
      default:
        return ReserveStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case ReserveStatus.reserved:
        return '待签到';
      case ReserveStatus.inUse:
        return '使用中';
      case ReserveStatus.temporarilyAway:
        return '暂离中';
      case ReserveStatus.flexibleSign:
        return '可签到';
      case ReserveStatus.completed:
        return '已结束';
      case ReserveStatus.cancelled:
        return '已取消';
      case ReserveStatus.unknown:
        return '未知';
    }
  }

  /// 当前状态是否允许执行退座操作。
  ///
  /// 超星座位系统在“使用中”、“暂离中”和“被监督中”状态下都提供退座入口。
  bool get canSignBack {
    switch (this) {
      case ReserveStatus.inUse:
      case ReserveStatus.temporarilyAway:
      case ReserveStatus.flexibleSign:
        return true;
      case ReserveStatus.reserved:
      case ReserveStatus.completed:
      case ReserveStatus.cancelled:
      case ReserveStatus.unknown:
        return false;
    }
  }
}

/// 预约记录模型
class LibraryReserveModel {
  final int id;
  final int roomId;
  final int deptId;
  final String seatNum;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime? expireTime;
  final DateTime? insertTime;
  final int status;
  final String firstLevelName;
  final String secondLevelName;
  final String thirdLevelName;
  final String today;
  final String? duration;
  final String? uname;
  final int? uid;

  LibraryReserveModel({
    required this.id,
    required this.roomId,
    required this.deptId,
    required this.seatNum,
    required this.startTime,
    required this.endTime,
    this.expireTime,
    this.insertTime,
    required this.status,
    required this.firstLevelName,
    required this.secondLevelName,
    required this.thirdLevelName,
    required this.today,
    this.duration,
    this.uname,
    this.uid,
  });

  ReserveStatus get reserveStatus => ReserveStatus.fromInt(status);

  String get fullRoomName {
    final parts = [firstLevelName, secondLevelName, thirdLevelName]
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join(' · ');
  }

  factory LibraryReserveModel.fromJson(Map<String, dynamic> json) {
    return LibraryReserveModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      roomId: json['roomId'] is int ? json['roomId'] : int.tryParse(json['roomId']?.toString() ?? '0') ?? 0,
      deptId: json['deptId'] is int ? json['deptId'] : int.tryParse(json['deptId']?.toString() ?? '0') ?? 0,
      seatNum: json['seatNum']?.toString() ?? '',
      startTime: json['startTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['startTime'] is int
              ? json['startTime']
              : int.tryParse(json['startTime'].toString()) ?? 0)
          : DateTime.now(),
      endTime: json['endTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['endTime'] is int
              ? json['endTime']
              : int.tryParse(json['endTime'].toString()) ?? 0)
          : DateTime.now(),
      expireTime: json['expireTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['expireTime'] is int
              ? json['expireTime']
              : int.tryParse(json['expireTime'].toString()) ?? 0)
          : null,
      insertTime: json['inserttime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['inserttime'] is int
              ? json['inserttime']
              : int.tryParse(json['inserttime'].toString()) ?? 0)
          : null,
      status: json['status'] is int ? json['status'] : int.tryParse(json['status']?.toString() ?? '0') ?? 0,
      firstLevelName: json['firstLevelName']?.toString() ?? '',
      secondLevelName: json['secondLevelName']?.toString() ?? '',
      thirdLevelName: json['thirdLevelName']?.toString() ?? '',
      today: json['today']?.toString() ?? '',
      duration: json['duration']?.toString(),
      uname: json['uname']?.toString(),
      uid: json['uid'] is int ? json['uid'] : int.tryParse(json['uid']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'deptId': deptId,
      'seatNum': seatNum,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'expireTime': expireTime?.millisecondsSinceEpoch,
      'inserttime': insertTime?.millisecondsSinceEpoch,
      'status': status,
      'firstLevelName': firstLevelName,
      'secondLevelName': secondLevelName,
      'thirdLevelName': thirdLevelName,
      'today': today,
      'duration': duration,
      'uname': uname,
      'uid': uid,
    };
  }
}

/// 阅览室/教室模型
class LibraryRoomModel {
  final int id;
  final String firstLevelName;
  final String secondLevelName;
  final String thirdLevelName;
  final int capacity;
  final int reserveBeforeDay;
  final String reserveBeforeTime;
  final int reserveAfterDay;
  final String reserveAfterTime;
  final int deptId;
  final int gridStyle;

  LibraryRoomModel({
    required this.id,
    required this.firstLevelName,
    required this.secondLevelName,
    required this.thirdLevelName,
    required this.capacity,
    required this.reserveBeforeDay,
    required this.reserveBeforeTime,
    required this.reserveAfterDay,
    required this.reserveAfterTime,
    required this.deptId,
    required this.gridStyle,
  });

  String get displayName => thirdLevelName.isNotEmpty ? thirdLevelName : secondLevelName;
  String get floorName => secondLevelName;

  factory LibraryRoomModel.fromJson(Map<String, dynamic> json) {
    return LibraryRoomModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      firstLevelName: json['firstLevelName']?.toString() ?? '',
      secondLevelName: json['secondLevelName']?.toString() ?? '',
      thirdLevelName: json['thirdLevelName']?.toString() ?? '',
      capacity: json['capacity'] is int ? json['capacity'] : int.tryParse(json['capacity']?.toString() ?? '0') ?? 0,
      reserveBeforeDay: json['reserveBeforeDay'] is int ? json['reserveBeforeDay'] : int.tryParse(json['reserveBeforeDay']?.toString() ?? '1') ?? 1,
      reserveBeforeTime: json['reserveBeforeTime']?.toString() ?? '18:00',
      reserveAfterDay: json['reserveAfterDay'] is int ? json['reserveAfterDay'] : int.tryParse(json['reserveAfterDay']?.toString() ?? '-1') ?? -1,
      reserveAfterTime: json['reserveAfterTime']?.toString() ?? '12:00',
      deptId: json['deptId'] is int ? json['deptId'] : int.tryParse(json['deptId']?.toString() ?? '0') ?? 0,
      gridStyle: json['gridStyle'] is int ? json['gridStyle'] : int.tryParse(json['gridStyle']?.toString() ?? '1') ?? 1,
    );
  }
}

/// 座位信息模型
class LibrarySeatItem {
  final int id;
  final int roomId;
  final String seatNum;
  final int x;
  final int y;
  final int reserveStatus;

  LibrarySeatItem({
    required this.id,
    required this.roomId,
    required this.seatNum,
    required this.x,
    required this.y,
    required this.reserveStatus,
  });

  factory LibrarySeatItem.fromJson(Map<String, dynamic> json) {
    return LibrarySeatItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      roomId: json['roomId'] is int ? json['roomId'] : int.tryParse(json['roomId']?.toString() ?? '0') ?? 0,
      seatNum: json['seatNum']?.toString() ?? '',
      x: json['x'] is int ? json['x'] : int.tryParse(json['x']?.toString() ?? '0') ?? 0,
      y: json['y'] is int ? json['y'] : int.tryParse(json['y']?.toString() ?? '0') ?? 0,
      reserveStatus: json['reserveStatus'] is int ? json['reserveStatus'] : int.tryParse(json['reserveStatus']?.toString() ?? '0') ?? 0,
    );
  }
}

/// 网格障碍物/桌子/标识模型
class LibraryGridConfigItem {
  final int x;
  final int y;
  final int type;
  final String label;

  LibraryGridConfigItem({
    required this.x,
    required this.y,
    required this.type,
    required this.label,
  });

  factory LibraryGridConfigItem.fromJson(Map<String, dynamic> json) {
    return LibraryGridConfigItem(
      x: json['x'] is int ? json['x'] : int.tryParse(json['x']?.toString() ?? '0') ?? 0,
      y: json['y'] is int ? json['y'] : int.tryParse(json['y']?.toString() ?? '0') ?? 0,
      type: json['type'] is int ? json['type'] : int.tryParse(json['type']?.toString() ?? '0') ?? 0,
      label: json['label']?.toString() ?? '',
    );
  }
}

/// 座位图全量数据模型
class LibrarySeatGridData {
  final int roomId;
  final int cols; // x
  final int rows; // y
  final List<LibrarySeatItem> seats;
  final List<LibraryGridConfigItem> obstacles;
  final Map<String, LibrarySeatItem> seatMapByNum; // seatNum -> seat
  final Map<String, LibrarySeatItem> seatMapByCoord; // "x,y" -> seat
  final Map<String, LibraryGridConfigItem> obstacleMapByCoord; // "x,y" -> obstacle

  LibrarySeatGridData({
    required this.roomId,
    required this.cols,
    required this.rows,
    required this.seats,
    required this.obstacles,
    required this.seatMapByNum,
    required this.seatMapByCoord,
    required this.obstacleMapByCoord,
  });

  factory LibrarySeatGridData.fromJson(Map<String, dynamic> json) {
    final otherDatas = json['otherDatas'] as Map<String, dynamic>? ?? {};
    final seatDatas = json['seatDatas'] as List<dynamic>? ?? [];

    final roomId = otherDatas['roomId'] is int
        ? otherDatas['roomId']
        : int.tryParse(otherDatas['roomId']?.toString() ?? '0') ?? 0;
    final cols = otherDatas['x'] is int
        ? otherDatas['x']
        : int.tryParse(otherDatas['x']?.toString() ?? '0') ?? 0;
    final rows = otherDatas['y'] is int
        ? otherDatas['y']
        : int.tryParse(otherDatas['y']?.toString() ?? '0') ?? 0;

    final seatList = seatDatas.map((e) => LibrarySeatItem.fromJson(e as Map<String, dynamic>)).toList();
    
    List<LibraryGridConfigItem> obstacleList = [];
    final configRaw = otherDatas['config'];
    if (configRaw != null && configRaw is String && configRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(configRaw) as List<dynamic>;
        obstacleList = decoded.map((e) => LibraryGridConfigItem.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    final byNum = <String, LibrarySeatItem>{};
    final byCoord = <String, LibrarySeatItem>{};
    for (final s in seatList) {
      byNum[s.seatNum] = s;
      byCoord['${s.x},${s.y}'] = s;
    }

    final obsByCoord = <String, LibraryGridConfigItem>{};
    for (final o in obstacleList) {
      obsByCoord['${o.x},${o.y}'] = o;
    }

    return LibrarySeatGridData(
      roomId: roomId,
      cols: cols,
      rows: rows,
      seats: seatList,
      obstacles: obstacleList,
      seatMapByNum: byNum,
      seatMapByCoord: byCoord,
      obstacleMapByCoord: obsByCoord,
    );
  }
}

/// 系统配置信息
class LibrarySeatConfig {
  final int deptId;
  final int preSignDuration;
  final int signDuration;
  final int reserveBeforeDay;
  final String reserveBeforeTime;
  final String monStartTime;
  final String monEndTime;
  final double minReserveDuration;
  final double maxReserveDuration;

  LibrarySeatConfig({
    required this.deptId,
    required this.preSignDuration,
    required this.signDuration,
    required this.reserveBeforeDay,
    required this.reserveBeforeTime,
    required this.monStartTime,
    required this.monEndTime,
    required this.minReserveDuration,
    required this.maxReserveDuration,
  });

  factory LibrarySeatConfig.fromJson(Map<String, dynamic> json) {
    final timeCfg = json['commonTimeConfig'] as Map<String, dynamic>? ?? {};
    return LibrarySeatConfig(
      deptId: json['deptId'] is int ? json['deptId'] : int.tryParse(json['deptId']?.toString() ?? '33430') ?? 33430,
      preSignDuration: json['preSignDuration'] is int ? json['preSignDuration'] : int.tryParse(json['preSignDuration']?.toString() ?? '15') ?? 15,
      signDuration: json['signDuration'] is int ? json['signDuration'] : int.tryParse(json['signDuration']?.toString() ?? '15') ?? 15,
      reserveBeforeDay: json['reserveBeforeDay'] is int ? json['reserveBeforeDay'] : int.tryParse(json['reserveBeforeDay']?.toString() ?? '1') ?? 1,
      reserveBeforeTime: json['reserveBeforeTime']?.toString() ?? '19:00',
      monStartTime: timeCfg['monStartTime']?.toString() ?? '07:00',
      monEndTime: timeCfg['monEndTime']?.toString() ?? '22:00',
      minReserveDuration: (json['minReserveDuration'] as num?)?.toDouble() ?? 0.5,
      maxReserveDuration: (json['reserveDuration'] as num?)?.toDouble() ?? 5.0,
    );
  }
}

/// 首页聚合数据
class LibraryIndexData {
  final LibrarySeatConfig? config;
  final List<LibraryReserveModel> curReserves;
  final List<LibraryReserveModel> nearReserves;

  LibraryIndexData({
    this.config,
    required this.curReserves,
    required this.nearReserves,
  });

  LibraryReserveModel? get activeReservation {
    if (curReserves.isEmpty) return null;
    return curReserves.first;
  }
}
