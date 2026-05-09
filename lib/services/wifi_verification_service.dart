import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

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

  final NetworkInfo _networkInfo = NetworkInfo();

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

  Future<bool> _ensureLocationPermission() async {
    final currentStatus = await Permission.location.status;
    if (currentStatus.isGranted) {
      return true;
    }

    final requestedStatus = await Permission.location.request();
    return requestedStatus.isGranted;
  }

  Future<WifiSsidResult> getCurrentWifiSsid() async {
    try {
      final hasPermission = await _ensureLocationPermission();
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
