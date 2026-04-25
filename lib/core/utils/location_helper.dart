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
}
