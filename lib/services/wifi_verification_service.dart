import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

class WifiSsidResult {
  final String ssid;
  final String errorMessage;

  const WifiSsidResult({
    required this.ssid,
    required this.errorMessage,
  });

  bool get isSuccess => ssid.trim().isNotEmpty && errorMessage.trim().isEmpty;
}

class WifiVerificationResult {
  final bool isSuccess;
  final String ssid;
  final String message;

  const WifiVerificationResult({
    required this.isSuccess,
    required this.ssid,
    required this.message,
  });
}

class WifiVerificationService {
  static const String _ssidReadFailureMessage =
      'Could not read Wi-Fi name. Please allow location permission and turn on Wi-Fi.';
  static const String _unsupportedPlatformMessage =
      'Wi-Fi SSID verification is only supported on Android.';

  final NetworkInfo _networkInfo = NetworkInfo();

  bool get _isAndroid {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  String get _platformUnsupportedMessage {
    if (kIsWeb) {
      return 'Wi-Fi SSID verification is not supported on Web.';
    }

    if (defaultTargetPlatform == TargetPlatform.windows) {
      return 'Wi-Fi SSID verification is not supported on Windows.';
    }

    return _unsupportedPlatformMessage;
  }

  String _cleanSsid(String? rawSsid) {
    final value = (rawSsid ?? '').trim();
    if (value.isEmpty) {
      return '';
    }

    final withoutQuotes = value.replaceAll('"', '').trim();
    final normalized = withoutQuotes.toLowerCase();
    if (normalized.isEmpty ||
        normalized == '<unknown ssid>' ||
        normalized == 'unknown ssid' ||
        normalized == '0x') {
      return '';
    }

    return withoutQuotes;
  }

  Future<bool> _ensureAndroidLocationPermission() async {
    final permissionHandler = PermissionHandlerPlatform.instance;
    final currentStatus = await permissionHandler.checkPermissionStatus(
      Permission.location,
    );
    if (currentStatus.isGranted) {
      return true;
    }

    final requestedStatuses = await permissionHandler.requestPermissions([
      Permission.location,
    ]);
    return requestedStatuses[Permission.location]?.isGranted ?? false;
  }

  Future<WifiSsidResult> getCurrentWifiSsid() async {
    if (!_isAndroid) {
      debugPrint(
        'Wi-Fi verification skipped: $_platformUnsupportedMessage',
      );
      return WifiSsidResult(
        ssid: '',
        errorMessage: _platformUnsupportedMessage,
      );
    }

    try {
      final hasPermission = await _ensureAndroidLocationPermission();
      if (!hasPermission) {
        debugPrint('Wi-Fi verification failed: location permission denied.');
        return const WifiSsidResult(
          ssid: '',
          errorMessage: _ssidReadFailureMessage,
        );
      }

      final rawSsid = await _networkInfo.getWifiName();
      final ssid = _cleanSsid(rawSsid);
      if (ssid.isEmpty) {
        debugPrint('Wi-Fi verification failed: SSID unavailable.');
        return const WifiSsidResult(
          ssid: '',
          errorMessage: _ssidReadFailureMessage,
        );
      }

      return WifiSsidResult(ssid: ssid, errorMessage: '');
    } catch (error) {
      debugPrint('Wi-Fi SSID lookup failed: $error');
      return const WifiSsidResult(
        ssid: '',
        errorMessage: _ssidReadFailureMessage,
      );
    }
  }

  Future<WifiVerificationResult> isConnectedToAllowedWifi(
    List<String> allowedSsids,
  ) async {
    final normalizedAllowedSsids = allowedSsids
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    if (normalizedAllowedSsids.isEmpty) {
      return const WifiVerificationResult(
        isSuccess: false,
        ssid: '',
        message: 'No allowed Wi-Fi SSID configured for this lab.',
      );
    }

    final currentWifi = await getCurrentWifiSsid();
    if (!currentWifi.isSuccess) {
      return WifiVerificationResult(
        isSuccess: false,
        ssid: '',
        message: currentWifi.errorMessage,
      );
    }

    final currentSsid = currentWifi.ssid.trim();
    final matched = normalizedAllowedSsids.any(
      (item) => item.toLowerCase() == currentSsid.toLowerCase(),
    );

    if (!matched) {
      return WifiVerificationResult(
        isSuccess: false,
        ssid: currentSsid,
        message:
            'Connected Wi-Fi "$currentSsid" is not allowed for this lab.',
      );
    }

    return WifiVerificationResult(
      isSuccess: true,
      ssid: currentSsid,
      message: '',
    );
  }
}
