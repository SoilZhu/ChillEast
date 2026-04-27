import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';

class LocationHelper {
  static final _logger = Logger();

  /// 仅请求/检查权限，不获取经纬度
  static Future<bool> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  /// 获取当前位置
  /// 如果无法获取或用户拒绝权限，则返回 null
  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    _logger.i('🔍 Checking location service...');
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _logger.w('❌ Location service disabled');
      return null;
    }

    _logger.i('🔍 Checking permissions...');
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      _logger.i('🔍 Requesting permissions...');
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _logger.w('❌ Permission denied');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _logger.w('❌ Permission denied forever');
      return null;
    }

    // 1. 尝试获取最后一次已知位置 (最快)
    _logger.i('🔍 Trying last known position...');
    try {
      final lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        _logger.i('✅ Got last known position: ${lastPosition.latitude}, ${lastPosition.longitude}');
        if (DateTime.now().difference(lastPosition.timestamp).inMinutes < 1) {
          return lastPosition;
        }
      }
    } catch (e) {
      _logger.e('Error getting last position: $e');
    }

    // 2. 尝试获取高精度当前位置
    _logger.i('🔍 Getting high accuracy current position...');
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 4),
      );
      return position;
    } catch (e) {
      _logger.w('⚠️ High accuracy failed: $e. trying low accuracy...');
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 3),
        );
        return position;
      } catch (e2) {
        _logger.e('❌ All location attempts failed: $e2');
        return await Geolocator.getLastKnownPosition();
      }
    }
  }

  /// WGS-84 转 GCJ-02 (火星坐标系)
  static Map<String, double> wgs84ToGcj02(double lng, double lat) {
    const double a = 6378245.0;
    const double ee = 0.00669342162296594323;
    const double pi = 3.1415926535897932384626;

    if (_outOfChina(lng, lat)) {
      return {'lat': lat, 'lng': lng};
    }
    double dlat = _transformLat(lng - 105.0, lat - 35.0);
    double dlng = _transformLng(lng - 105.0, lat - 35.0);
    double radlat = lat / 180.0 * pi;
    double magic = math.sin(radlat);
    magic = 1 - ee * magic * magic;
    double sqrtmagic = math.sqrt(magic);
    dlat = (dlat * 180.0) / ((a * (1 - ee)) / (magic * sqrtmagic) * pi);
    dlng = (dlng * 180.0) / (a / sqrtmagic * math.cos(radlat) * pi);
    return {'lat': lat + dlat, 'lng': lng + dlng};
  }

  static bool _outOfChina(double lng, double lat) {
    return !(lng > 73.66 && lng < 135.05 && lat > 3.86 && lat < 53.55);
  }

  static double _transformLat(double x, double y) {
    const double pi = 3.1415926535897932384626;
    double ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * math.sqrt(x.abs());
    ret += (20.0 * math.sin(6.0 * x * pi) + 20.0 * math.sin(2.0 * x * pi)) * 2.0 / 3.0;
    ret += (20.0 * math.sin(y * pi) + 40.0 * math.sin(y / 3.0 * pi)) * 2.0 / 3.0;
    ret += (160.0 * math.sin(y / 12.0 * pi) + 320 * math.sin(y * pi / 30.0)) * 2.0 / 3.0;
    return ret;
  }

  static double _transformLng(double x, double y) {
    const double pi = 3.1415926535897932384626;
    double ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * math.sqrt(x.abs());
    ret += (20.0 * math.sin(6.0 * x * pi) + 20.0 * math.sin(2.0 * x * pi)) * 2.0 / 3.0;
    ret += (20.0 * math.sin(x * pi) + 40.0 * math.sin(x / 3.0 * pi)) * 2.0 / 3.0;
    ret += (150.0 * math.sin(x / 12.0 * pi) + 300.0 * math.sin(x / 30.0 * pi)) * 2.0 / 3.0;
    return ret;
  }
}

