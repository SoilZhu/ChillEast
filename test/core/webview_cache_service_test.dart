// ignore_for_file: depend_on_referenced_packages
import 'dart:io' as io;
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:ChillEast/core/services/webview_cache_service.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String path;
  MockPathProviderPlatform(this.path);

  @override
  Future<String?> getTemporaryPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class FakeWebViewControllerStatic extends webview.PlatformInAppWebViewController {
  FakeWebViewControllerStatic()
      : super.implementation(
            const webview.PlatformInAppWebViewControllerCreationParams(id: 1));

  bool clearAllCacheCalled = false;
  bool? lastIncludeDiskFiles;

  @override
  Future<void> clearAllCache({bool includeDiskFiles = true}) async {
    clearAllCacheCalled = true;
    lastIncludeDiskFiles = includeDiskFiles;
  }

  @override
  void dispose({bool isKeepAlive = false}) {}
}

class FakeWebStorageManager extends webview.PlatformWebStorageManager {
  FakeWebStorageManager()
      : super.implementation(
            const webview.PlatformWebStorageManagerCreationParams());

  bool deleteAllDataCalled = false;

  @override
  Future<void> deleteAllData() async {
    deleteAllDataCalled = true;
  }
}

class FakeWebViewPlatform extends webview.InAppWebViewPlatform {
  final FakeWebViewControllerStatic controllerStatic = FakeWebViewControllerStatic();
  final FakeWebStorageManager storageManager = FakeWebStorageManager();

  @override
  webview.PlatformInAppWebViewController createPlatformInAppWebViewControllerStatic() {
    return controllerStatic;
  }

  @override
  webview.PlatformWebStorageManager createPlatformWebStorageManager(
      webview.PlatformWebStorageManagerCreationParams params) {
    return storageManager;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late io.Directory tempDir;
  late FakeWebViewPlatform fakePlatform;

  setUpAll(() async {
    tempDir = await io.Directory.systemTemp.createTemp('webview-cache-test-');
    PathProviderPlatform.instance = MockPathProviderPlatform(tempDir.path);
    fakePlatform = FakeWebViewPlatform();
    webview.InAppWebViewPlatform.instance = fakePlatform;
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  test('WebViewCacheService clears cache, storage, and cleans temp directories', () async {
    // Create some fake webview temporary files
    final webviewDir = io.Directory('${tempDir.path}/app_webview');
    await webviewDir.create();
    final cacheFile = io.File('${webviewDir.path}/cache_data.bin');
    await cacheFile.writeAsString('cache data');

    final otherFile = io.File('${tempDir.path}/user_notes.txt');
    await otherFile.writeAsString('user notes');

    final sizeBefore = await WebViewCacheService.getEstimatedCacheSize();
    expect(sizeBefore, greaterThan(0));

    // Clear with includeDiskFiles=true and clearStorage=true
    await WebViewCacheService.clearCache(includeDiskFiles: true, clearStorage: true);

    expect(fakePlatform.controllerStatic.clearAllCacheCalled, isTrue);
    expect(fakePlatform.controllerStatic.lastIncludeDiskFiles, isTrue);
    expect(fakePlatform.storageManager.deleteAllDataCalled, isTrue);

    // webview directory was deleted, other file remains
    expect(webviewDir.existsSync(), isFalse);
    expect(otherFile.existsSync(), isTrue);
  });

  test('autoPruneCacheOnStartup only cleans disk cache and does not delete storage', () async {
    fakePlatform.storageManager.deleteAllDataCalled = false;
    fakePlatform.controllerStatic.clearAllCacheCalled = false;

    await WebViewCacheService.autoPruneCacheOnStartup();

    expect(fakePlatform.controllerStatic.clearAllCacheCalled, isTrue);
    expect(fakePlatform.controllerStatic.lastIncludeDiskFiles, isTrue);
    expect(fakePlatform.storageManager.deleteAllDataCalled, isFalse);
  });
}
