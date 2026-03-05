import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateDecision {
  final bool mustBlock;
  final bool forceUpdate;
  final int currentVersionCode;
  final int latestVersionCode;
  final int minVersionCode;
  final String updateMessage;
  final String updateUrl;

  const AppUpdateDecision({
    required this.mustBlock,
    required this.forceUpdate,
    required this.currentVersionCode,
    required this.latestVersionCode,
    required this.minVersionCode,
    required this.updateMessage,
    required this.updateUrl,
  });
}

class AppUpdateService {
  static const String _forceUpdateKey = 'force_update';
  static const String _forceUpdateTypoKey = 'forece_update';
  static const String _latestAndroidVersionCodeKey =
      'latest_android_version_code';
  static const String _minAndroidVersionCodeKey = 'min_android_version_code';
  static const String _updateMessageKey = 'update_message';
  static const String _updateUrlKey = 'update_url';

  static const String _defaultMessage =
      'New version of app available! Please update.';

  final FirebaseRemoteConfig _remoteConfig;

  AppUpdateService({FirebaseRemoteConfig? remoteConfig})
    : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  Future<AppUpdateDecision> checkForRequiredUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      if (!_isAndroidPlatform) {
        return _allowWithoutBlocking(currentVersionCode);
      }

      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: Duration.zero,
        ),
      );

      await _remoteConfig.fetchAndActivate();

      final hasForceUpdateKey = _remoteConfig.getAll().containsKey(
        _forceUpdateKey,
      );
      final forceUpdate = hasForceUpdateKey
          ? _remoteConfig.getBool(_forceUpdateKey)
          : _remoteConfig.getBool(_forceUpdateTypoKey);

      final latestVersionCode = _remoteConfig.getInt(
        _latestAndroidVersionCodeKey,
      );
      final minVersionCode = _remoteConfig.getInt(_minAndroidVersionCodeKey);
      final updateMessage = _remoteConfig.getString(_updateMessageKey).trim();
      final updateUrl = _remoteConfig.getString(_updateUrlKey).trim();

      final belowMin = currentVersionCode < minVersionCode;
      final belowLatest = currentVersionCode < latestVersionCode;
      final mustBlock = belowMin || (forceUpdate && belowLatest);

      return AppUpdateDecision(
        mustBlock: mustBlock,
        forceUpdate: forceUpdate,
        currentVersionCode: currentVersionCode,
        latestVersionCode: latestVersionCode,
        minVersionCode: minVersionCode,
        updateMessage: updateMessage.isEmpty ? _defaultMessage : updateMessage,
        updateUrl: updateUrl,
      );
    } catch (_) {
      // Never block app entry when update checks fail (especially on web).
      return _allowWithoutBlocking(0);
    }
  }

  AppUpdateDecision _allowWithoutBlocking(int currentVersionCode) {
    return AppUpdateDecision(
      mustBlock: false,
      forceUpdate: false,
      currentVersionCode: currentVersionCode,
      latestVersionCode: currentVersionCode,
      minVersionCode: currentVersionCode,
      updateMessage: _defaultMessage,
      updateUrl: '',
    );
  }

  bool get _isAndroidPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }
}
