import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';
import '../theme/labmate_theme.dart';

class UpdateCheckListener extends StatefulWidget {
  final Widget child;
  final UpdateService? updateService;

  const UpdateCheckListener({
    super.key,
    required this.child,
    this.updateService,
  });

  @override
  State<UpdateCheckListener> createState() => _UpdateCheckListenerState();
}

class _UpdateCheckListenerState extends State<UpdateCheckListener> {
  static bool _hasCheckedThisSession = false;
  static bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    if (_hasCheckedThisSession || _isChecking || !mounted) {
      return;
    }

    _hasCheckedThisSession = true;
    _isChecking = true;
    try {
      final result = await (widget.updateService ?? UpdateService())
          .checkForUpdate();
      if (!mounted || !result.shouldPrompt) {
        return;
      }

      final uri = Uri.tryParse(result.downloadUrl.trim());
      if (!_isValidReleaseUri(uri)) {
        return;
      }

      await _showUpdateDialog(result, uri!);
    } catch (_) {
      // Update checks should never block normal app launch.
    } finally {
      _isChecking = false;
    }
  }

  bool _isValidReleaseUri(Uri? uri) {
    if (uri == null || uri.host.trim().isEmpty) {
      return false;
    }

    return uri.scheme == 'https' || uri.scheme == 'http';
  }

  Future<void> _showUpdateDialog(UpdateCheckResult result, Uri uri) async {
    final release = result.release;
    if (release == null || !mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: !result.isRequired,
      builder: (context) {
        final palette = context.labmate;
        final colorScheme = context.colorScheme;
        final notes = release.releaseNotes.trim();
        final version = release.latestVersion.trim().isEmpty
            ? 'a newer version'
            : 'Version ${release.latestVersion.trim()}';

        return AlertDialog(
          title: Text(
            result.isRequired ? 'Update required' : 'Update available',
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$version is available.',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    notes,
                    style: TextStyle(color: palette.mutedText, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!result.isRequired)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
            FilledButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                final launched = await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
                if (!launched) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Could not open the update link.'),
                    ),
                  );
                  return;
                }

                if (!result.isRequired) {
                  navigator.pop();
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
