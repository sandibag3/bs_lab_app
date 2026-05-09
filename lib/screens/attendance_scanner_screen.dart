import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app_state.dart';
import '../services/attendance_service.dart';
import '../services/firestore_access_guard.dart';

class AttendanceScannerScreen extends StatefulWidget {
  const AttendanceScannerScreen({super.key});

  @override
  State<AttendanceScannerScreen> createState() => _AttendanceScannerScreenState();
}

class _AttendanceScannerScreenState extends State<AttendanceScannerScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MobileScannerController _scannerController = MobileScannerController();

  bool _isHandlingScan = false;
  bool _isTorchEnabled = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _showFailureAndResume(String message) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            'Attendance Check-in',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'OK',
                style: TextStyle(color: Color(0xFF38BDF8)),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isHandlingScan = false;
    });
    await _scannerController.start();
  }

  Future<void> _toggleTorch() async {
    await _scannerController.toggleTorch();
    if (!mounted) {
      return;
    }

    setState(() {
      _isTorchEnabled = !_isTorchEnabled;
    });
  }

  Future<void> _handleQrRawValue(String rawValue) async {
    if (_isHandlingScan) {
      return;
    }

    setState(() {
      _isHandlingScan = true;
    });

    await _scannerController.stop();

    final appState = AppState.instance;
    final selectedLabId = appState.selectedLabId.trim();
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid.trim() ?? '';

    if (selectedLabId.isEmpty) {
      await _showFailureAndResume(
        'Select or join a lab before scanning attendance QR.',
      );
      return;
    }

    if (currentUserId.isEmpty) {
      await _showFailureAndResume('Please sign in again to continue.');
      return;
    }

    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map) {
        throw const FormatException('QR payload is not a JSON object.');
      }
      payload = Map<String, dynamic>.from(decoded);
    } catch (_) {
      await _showFailureAndResume('Invalid attendance QR');
      return;
    }

    final type = (payload['type'] ?? '').toString().trim();
    final labId = (payload['labId'] ?? '').toString().trim();
    final secret = (payload['secret'] ?? '').toString().trim();

    if (type != 'labmate_attendance') {
      await _showFailureAndResume('Invalid attendance QR');
      return;
    }

    if (labId != selectedLabId) {
      await _showFailureAndResume('QR does not belong to selected lab');
      return;
    }

    try {
      final labDoc = await _firestore.collection('labs').doc(selectedLabId).get();
      if (!labDoc.exists) {
        await _showFailureAndResume('Selected lab was not found');
        return;
      }

      final labData = labDoc.data() ?? <String, dynamic>{};
      final attendanceEnabled = labData['attendanceEnabled'] == true;
      final expectedSecret =
          (labData['attendanceQrSecret'] ?? '').toString().trim();

      if (!attendanceEnabled) {
        await _showFailureAndResume('Attendance is disabled');
        return;
      }

      if (expectedSecret.isEmpty || expectedSecret != secret) {
        await _showFailureAndResume('QR secret mismatch');
        return;
      }

      final result = await _attendanceService.checkIn(
        labId: selectedLabId,
        userId: currentUserId,
        userName: appState.authenticatedUserName,
        userEmail: appState.authenticatedUserEmail,
        wifiSsid: 'not_verified_v1',
      );

      if (!mounted) {
        return;
      }

      if (result.isSuccess) {
        Navigator.pop(
          context,
          result.message.isEmpty ? 'Checked in successfully' : result.message,
        );
        return;
      }

      await _showFailureAndResume(
        result.message.isEmpty ? 'Could not check in' : result.message,
      );
    } catch (error) {
      await _showFailureAndResume(FirestoreAccessGuard.messageFor(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppState.instance;
    final currentUser = FirebaseAuth.instance.currentUser;

    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final selectedLabId = appState.selectedLabId.trim();
        final selectedLabName = appState.selectedLabName.trim();
        final canQueryLabData = FirestoreAccessGuard.shouldQueryLabScopedData(
          appState: appState,
        );
        final hasAuthenticatedUser =
            (currentUser?.uid.trim() ?? '').isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Scan Lab QR',
              style: TextStyle(color: Colors.white),
            ),
            actions: [
              IconButton(
                onPressed: _toggleTorch,
                tooltip: _isTorchEnabled ? 'Turn torch off' : 'Turn torch on',
                icon: Icon(
                  _isTorchEnabled
                      ? Icons.flashlight_on_rounded
                      : Icons.flashlight_off_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: !canQueryLabData
                ? const _AttendanceScannerInfoState(
                    title: 'Attendance needs a lab',
                    message:
                        'Select, create, or join a lab before scanning attendance QR.',
                    icon: Icons.apartment_rounded,
                  )
                : !hasAuthenticatedUser
                ? const _AttendanceScannerInfoState(
                    title: 'Sign in required',
                    message: 'Please sign in again to use attendance scanning.',
                    icon: Icons.lock_outline_rounded,
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.06),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Attendance QR Scanner',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                selectedLabName.isEmpty
                                    ? selectedLabId
                                    : selectedLabName,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Point your camera at the permanent Labmate attendance QR.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                MobileScanner(
                                  controller: _scannerController,
                                  onDetect: (capture) {
                                    if (_isHandlingScan) {
                                      return;
                                    }

                                    for (final barcode in capture.barcodes) {
                                      final rawValue =
                                          barcode.rawValue?.trim() ?? '';
                                      if (rawValue.isNotEmpty) {
                                        _handleQrRawValue(rawValue);
                                        break;
                                      }
                                    }
                                  },
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.08),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Container(
                                    width: 220,
                                    height: 220,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: const Color(0xFF2DD4BF),
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 16,
                                  right: 16,
                                  bottom: 18,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.48),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      _isHandlingScan
                                          ? 'Validating attendance QR...'
                                          : 'Align the QR code inside the frame',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _AttendanceScannerInfoState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _AttendanceScannerInfoState({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 30, color: const Color(0xFFF59E0B)),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
