import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum UpdateStatus { upToDate, optionalUpdate, requiredUpdate }

class InstalledAppVersion {
  final String version;
  final int buildNumber;

  const InstalledAppVersion({required this.version, required this.buildNumber});
}

class ReleaseMetadata {
  final String latestVersion;
  final int? latestBuildNumber;
  final String minimumSupportedVersion;
  final int? minimumSupportedBuildNumber;
  final String windowsDownloadUrl;
  final String androidDownloadUrl;
  final String webDownloadUrl;
  final String releaseNotes;
  final bool forceUpdate;
  final DateTime? publishedAt;

  const ReleaseMetadata({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.minimumSupportedVersion,
    required this.minimumSupportedBuildNumber,
    required this.windowsDownloadUrl,
    required this.androidDownloadUrl,
    required this.webDownloadUrl,
    required this.releaseNotes,
    required this.forceUpdate,
    required this.publishedAt,
  });

  factory ReleaseMetadata.fromMap(Map<String, dynamic> data) {
    return ReleaseMetadata(
      latestVersion: _stringFromValue(data['latestVersion']),
      latestBuildNumber: _intFromValue(data['latestBuildNumber']),
      minimumSupportedVersion: _stringFromValue(
        data['minimumSupportedVersion'],
      ),
      minimumSupportedBuildNumber: _intFromValue(
        data['minimumSupportedBuildNumber'],
      ),
      windowsDownloadUrl: _stringFromValue(data['windowsDownloadUrl']),
      androidDownloadUrl: _stringFromValue(data['androidDownloadUrl']),
      webDownloadUrl: _stringFromValue(data['webDownloadUrl']),
      releaseNotes: _stringFromValue(data['releaseNotes']),
      forceUpdate: data['forceUpdate'] == true,
      publishedAt: _dateTimeFromValue(data['publishedAt']),
    );
  }
}

class UpdateCheckResult {
  final UpdateStatus status;
  final InstalledAppVersion installed;
  final ReleaseMetadata? release;
  final String downloadUrl;

  const UpdateCheckResult({
    required this.status,
    required this.installed,
    this.release,
    this.downloadUrl = '',
  });

  bool get shouldPrompt => status != UpdateStatus.upToDate && release != null;

  bool get isRequired => status == UpdateStatus.requiredUpdate;
}

class UpdateService {
  final FirebaseFirestore _firestore;

  UpdateService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<InstalledAppVersion> readInstalledVersion() async {
    final info = await PackageInfo.fromPlatform();

    return InstalledAppVersion(
      version: info.version.trim(),
      buildNumber: _intFromValue(info.buildNumber) ?? 0,
    );
  }

  Future<UpdateCheckResult> checkForUpdate() async {
    final installed = await readInstalledVersion();

    try {
      final snapshot = await _firestore
          .collection('appConfig')
          .doc('releases')
          .get();
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return UpdateCheckResult(
          status: UpdateStatus.upToDate,
          installed: installed,
        );
      }

      final release = ReleaseMetadata.fromMap(data);
      final downloadUrl = _downloadUrlForCurrentPlatform(release);
      if (downloadUrl.trim().isEmpty) {
        return UpdateCheckResult(
          status: UpdateStatus.upToDate,
          installed: installed,
          release: release,
        );
      }

      final latestBuildNumber = release.latestBuildNumber;
      final hasNewerBuild =
          latestBuildNumber != null &&
          latestBuildNumber > installed.buildNumber;
      final isBelowMinimumBuild =
          release.minimumSupportedBuildNumber != null &&
          release.minimumSupportedBuildNumber! > installed.buildNumber;
      final isBelowMinimumVersion =
          release.minimumSupportedVersion.trim().isNotEmpty &&
          _compareVersionSegments(
                installed.version,
                release.minimumSupportedVersion,
              ) <
              0;

      if (!hasNewerBuild && !isBelowMinimumBuild && !isBelowMinimumVersion) {
        return UpdateCheckResult(
          status: UpdateStatus.upToDate,
          installed: installed,
          release: release,
          downloadUrl: downloadUrl,
        );
      }

      final required =
          release.forceUpdate || isBelowMinimumBuild || isBelowMinimumVersion;

      return UpdateCheckResult(
        status: required
            ? UpdateStatus.requiredUpdate
            : UpdateStatus.optionalUpdate,
        installed: installed,
        release: release,
        downloadUrl: downloadUrl,
      );
    } catch (_) {
      return UpdateCheckResult(
        status: UpdateStatus.upToDate,
        installed: installed,
      );
    }
  }

  String _downloadUrlForCurrentPlatform(ReleaseMetadata release) {
    if (kIsWeb) {
      return release.webDownloadUrl;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return release.androidDownloadUrl;
      case TargetPlatform.windows:
        return release.windowsDownloadUrl;
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return '';
    }
  }
}

int _compareVersionSegments(String left, String right) {
  final leftSegments = _versionSegments(left);
  final rightSegments = _versionSegments(right);
  final length = leftSegments.length > rightSegments.length
      ? leftSegments.length
      : rightSegments.length;

  for (var index = 0; index < length; index++) {
    final leftValue = index < leftSegments.length ? leftSegments[index] : 0;
    final rightValue = index < rightSegments.length ? rightSegments[index] : 0;
    if (leftValue != rightValue) {
      return leftValue.compareTo(rightValue);
    }
  }

  return 0;
}

List<int> _versionSegments(String value) {
  return value
      .trim()
      .split(RegExp(r'[^0-9]+'))
      .where((segment) => segment.isNotEmpty)
      .map((segment) => int.tryParse(segment) ?? 0)
      .toList();
}

String _stringFromValue(dynamic value) {
  return value?.toString().trim() ?? '';
}

int? _intFromValue(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is double) {
    return value.toInt();
  }

  return int.tryParse(value?.toString().trim() ?? '');
}

DateTime? _dateTimeFromValue(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  return null;
}
