import 'dart:io' as io;
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:ChillEast/core/services/update_service.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String path;
  MockPathProviderPlatform(this.path);

  @override
  Future<String?> getExternalStoragePath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late io.Directory tempDir;

  setUpAll(() async {
    tempDir = await io.Directory.systemTemp.createTemp('update-test-');
    PathProviderPlatform.instance = MockPathProviderPlatform(tempDir.path);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  test('cleanHistoricalApks removes old APK files and preserves other files and excluded APK', () async {
    final apk1 = io.File('${tempDir.path}/chilleast_v1.0.1.apk');
    final apk2 = io.File('${tempDir.path}/chilleast_v1.0.2.apk');
    final apkCurrent = io.File('${tempDir.path}/chilleast_v1.0.10.apk');
    final nonApk = io.File('${tempDir.path}/important_data.json');

    await apk1.writeAsString('apk1 content');
    await apk2.writeAsString('apk2 content');
    await apkCurrent.writeAsString('apkCurrent content');
    await nonApk.writeAsString('{"some": "data"}');

    expect(apk1.existsSync(), isTrue);
    expect(apk2.existsSync(), isTrue);
    expect(apkCurrent.existsSync(), isTrue);
    expect(nonApk.existsSync(), isTrue);

    // Clean historical APKs excluding the current one
    await UpdateService.cleanHistoricalApks(excludePath: apkCurrent.path);

    expect(apk1.existsSync(), isFalse);
    expect(apk2.existsSync(), isFalse);
    expect(apkCurrent.existsSync(), isTrue);
    expect(nonApk.existsSync(), isTrue);

    // Now clean all without excludePath
    await UpdateService.cleanHistoricalApks();
    expect(apkCurrent.existsSync(), isFalse);
    expect(nonApk.existsSync(), isTrue);
  });
}
