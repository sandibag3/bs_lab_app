import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_state.dart';
import '../models/attendance_record_model.dart';
import '../services/attendance_service.dart';
import '../services/firestore_access_guard.dart';

class AttendanceAdminScreen extends StatefulWidget {
  const AttendanceAdminScreen({super.key});

  @override
  State<AttendanceAdminScreen> createState() => _AttendanceAdminScreenState();
}

class _AttendanceAdminScreenState extends State<AttendanceAdminScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AttendanceService _attendanceService = AttendanceService();
  final TextEditingController _ssidController = TextEditingController();

  bool _isGeneratingSecret = false;
  bool _isSavingToggle = false;
  bool _isSavingSsid = false;
  String? _removingSsid;

  @override
  void dispose() {
    _ssidController.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _labsRef =>
      _firestore.collection('labs');

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  String _generateSecret() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    final buffer = StringBuffer();

    for (var index = 0; index < 32; index++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }

    return buffer.toString();
  }

  String _formatTimestamp(Timestamp? value) {
    if (value == null) {
      return 'Not available';
    }

    final dateTime = value.toDate();
    final monthNames = const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final meridiem = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${dateTime.day} ${monthNames[dateTime.month - 1]}, $hour:$minute $meridiem';
  }

  Color _statusColor(AttendanceRecordModel record) {
    if (record.isCheckedOut) {
      return const Color(0xFF38BDF8);
    }
    return const Color(0xFF34D399);
  }

  String _statusLabel(AttendanceRecordModel record) {
    return record.isCheckedOut ? 'Checked out' : 'Present';
  }

  List<String> _readSsids(Map<String, dynamic> data) {
    final raw = data['allowedWifiSsids'];
    if (raw is! Iterable) {
      return const [];
    }

    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _generateAttendanceQr({
    required String labId,
  }) async {
    if (_isGeneratingSecret) {
      return;
    }

    setState(() {
      _isGeneratingSecret = true;
    });

    try {
      await _labsRef.doc(labId).set({
        'attendanceQrSecret': _generateSecret(),
        'attendanceEnabled': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }
      _showMessage('Attendance QR generated');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(FirestoreAccessGuard.messageFor(error));
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingSecret = false;
        });
      }
    }
  }

  Future<void> _setAttendanceEnabled({
    required String labId,
    required bool value,
  }) async {
    if (_isSavingToggle) {
      return;
    }

    setState(() {
      _isSavingToggle = true;
    });

    try {
      await _labsRef.doc(labId).set({
        'attendanceEnabled': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }
      _showMessage(value ? 'Attendance enabled' : 'Attendance disabled');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(FirestoreAccessGuard.messageFor(error));
    } finally {
      if (mounted) {
        setState(() {
          _isSavingToggle = false;
        });
      }
    }
  }

  Future<void> _addSsid({
    required String labId,
    required List<String> currentSsids,
  }) async {
    final ssid = _ssidController.text.trim();
    if (ssid.isEmpty || _isSavingSsid) {
      return;
    }

    if (currentSsids.any((item) => item.toLowerCase() == ssid.toLowerCase())) {
      _showMessage('SSID already added');
      return;
    }

    setState(() {
      _isSavingSsid = true;
    });

    try {
      await _labsRef.doc(labId).set({
        'allowedWifiSsids': FieldValue.arrayUnion([ssid]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _ssidController.clear();
      if (!mounted) {
        return;
      }
      _showMessage('Wi-Fi SSID added');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(FirestoreAccessGuard.messageFor(error));
    } finally {
      if (mounted) {
        setState(() {
          _isSavingSsid = false;
        });
      }
    }
  }

  Future<void> _removeSsid({
    required String labId,
    required String ssid,
  }) async {
    if (_removingSsid == ssid) {
      return;
    }

    setState(() {
      _removingSsid = ssid;
    });

    try {
      await _labsRef.doc(labId).set({
        'allowedWifiSsids': FieldValue.arrayRemove([ssid]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }
      _showMessage('Wi-Fi SSID removed');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(FirestoreAccessGuard.messageFor(error));
    } finally {
      if (mounted) {
        setState(() {
          _removingSsid = null;
        });
      }
    }
  }

  Widget _buildInfoState({
    required String title,
    required String message,
    required IconData icon,
  }) {
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

  @override
  Widget build(BuildContext context) {
    final appState = AppState.instance;

    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final selectedLabId = appState.selectedLabId.trim();
        final selectedLabName = appState.selectedLabName.trim();
        final canQueryLabData = FirestoreAccessGuard.shouldQueryLabScopedData(
          appState: appState,
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Attendance Admin',
              style: TextStyle(color: Colors.white),
            ),
          ),
          body: SafeArea(
            child: !canQueryLabData
                ? _buildInfoState(
                    title: 'Attendance needs a lab',
                    message:
                        'Select, create, or join a lab before managing attendance.',
                    icon: Icons.apartment_rounded,
                  )
                : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _labsRef.doc(selectedLabId).snapshots(),
                    builder: (context, labSnapshot) {
                      if (labSnapshot.hasError) {
                        return _buildInfoState(
                          title: 'Attendance settings unavailable',
                          message: FirestoreAccessGuard.messageFor(
                            labSnapshot.error,
                          ),
                          icon: Icons.error_outline_rounded,
                        );
                      }

                      final labData = labSnapshot.data?.data() ?? <String, dynamic>{};
                      final attendanceEnabled =
                          labData['attendanceEnabled'] == true;
                      final attendanceQrSecret =
                          (labData['attendanceQrSecret'] ?? '')
                              .toString()
                              .trim();
                      final allowedWifiSsids = _readSsids(labData);
                      final qrPayload = attendanceQrSecret.isEmpty
                          ? ''
                          : jsonEncode({
                              'type': 'labmate_attendance',
                              'labId': selectedLabId,
                              'secret': attendanceQrSecret,
                            });

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
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
                                  'Attendance Setup',
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
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Attendance enabled',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Turn attendance tracking on or off for this lab.',
                                            style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: 12.5,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: attendanceEnabled,
                                      onChanged: _isSavingToggle
                                          ? null
                                          : (value) => _setAttendanceEnabled(
                                              labId: selectedLabId,
                                              value: value,
                                            ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(18),
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
                                  'Attendance QR',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Use this permanent QR during check-in setup.',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12.8,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (attendanceQrSecret.isEmpty)
                                  ElevatedButton.icon(
                                    onPressed: _isGeneratingSecret
                                        ? null
                                        : () => _generateAttendanceQr(
                                            labId: selectedLabId,
                                          ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF14B8A6),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                    icon: _isGeneratingSecret
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.qr_code_rounded,
                                            size: 18,
                                          ),
                                    label: Text(
                                      _isGeneratingSecret
                                          ? 'Generating...'
                                          : 'Generate attendance QR',
                                    ),
                                  )
                                else
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(18),
                                          ),
                                          child: QrImageView(
                                            data: qrPayload,
                                            size: 180,
                                            backgroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.04),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: Text(
                                          attendanceQrSecret,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12.5,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(18),
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
                                  'Allowed Wi-Fi SSIDs',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Add lab Wi-Fi names that will later be used for attendance verification.',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12.8,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _ssidController,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Add Wi-Fi SSID',
                                          hintStyle: const TextStyle(
                                            color: Colors.white38,
                                          ),
                                          filled: true,
                                          fillColor:
                                              Colors.white.withOpacity(0.04),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton(
                                      onPressed: _isSavingSsid
                                          ? null
                                          : () => _addSsid(
                                              labId: selectedLabId,
                                              currentSsids: allowedWifiSsids,
                                            ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF38BDF8),
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(0, 50),
                                      ),
                                      child: _isSavingSsid
                                          ? const SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('Add'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                if (allowedWifiSsids.isEmpty)
                                  const Text(
                                    'No Wi-Fi SSIDs added yet.',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    ),
                                  )
                                else
                                  ...allowedWifiSsids.map((ssid) {
                                    final isRemoving = _removingSsid == ssid;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.04),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.wifi_rounded,
                                            color: Color(0xFF2DD4BF),
                                            size: 18,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              ssid,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13.2,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: isRemoving
                                                ? null
                                                : () => _removeSsid(
                                                    labId: selectedLabId,
                                                    ssid: ssid,
                                                  ),
                                            icon: isRemoving
                                                ? const SizedBox(
                                                    height: 16,
                                                    width: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white70,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.close_rounded,
                                                    color: Colors.white54,
                                                  ),
                                            tooltip: 'Remove SSID',
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(18),
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
                                  'Today\'s Attendance',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                StreamBuilder<List<AttendanceRecordModel>>(
                                  stream: _attendanceService
                                      .getTodayAttendanceForLab(
                                    labId: selectedLabId,
                                  ),
                                  builder: (context, attendanceSnapshot) {
                                    if (attendanceSnapshot.hasError) {
                                      return Text(
                                        FirestoreAccessGuard.messageFor(
                                          attendanceSnapshot.error,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      );
                                    }

                                    final records =
                                        attendanceSnapshot.data ?? const [];
                                    if (attendanceSnapshot.connectionState ==
                                            ConnectionState.waiting &&
                                        records.isEmpty) {
                                      return const Center(
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 18,
                                          ),
                                          child: CircularProgressIndicator(
                                            color: Color(0xFF14B8A6),
                                          ),
                                        ),
                                      );
                                    }

                                    if (records.isEmpty) {
                                      return const Text(
                                        'No attendance records for today yet.',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 13,
                                        ),
                                      );
                                    }

                                    return Column(
                                      children: records.map((record) {
                                        final statusColor =
                                            _statusColor(record);
                                        return Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 10),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.04,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          record.userName
                                                                  .trim()
                                                                  .isEmpty
                                                              ? 'Unknown user'
                                                              : record.userName
                                                                  .trim(),
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 13.5,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          record.userEmail
                                                              .trim(),
                                                          style:
                                                              const TextStyle(
                                                            color: Colors
                                                                .white60,
                                                            fontSize: 12.4,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: statusColor
                                                          .withOpacity(0.14),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        999,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      _statusLabel(record),
                                                      style: TextStyle(
                                                        color: statusColor,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                'Check-in: ${_formatTimestamp(record.checkInAt)}',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                              if (record.checkOutAt != null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Check-out: ${_formatTimestamp(record.checkOutAt)}',
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12.5,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}
