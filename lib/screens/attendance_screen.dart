import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/attendance_record_model.dart';
import '../services/attendance_service.dart';
import '../services/firestore_access_guard.dart';
import 'attendance_admin_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  bool _isCheckingOut = false;

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime value) {
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
    return '${value.day} ${monthNames[value.month - 1]} ${value.year}';
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

  AttendanceRecordModel? _findTodayRecord(
    List<AttendanceRecordModel> records,
    String userId,
  ) {
    for (final record in records) {
      if (record.userId.trim() == userId.trim()) {
        return record;
      }
    }
    return null;
  }

  String _statusLabel(AttendanceRecordModel? record) {
    if (record == null) {
      return 'Not checked in';
    }
    if (record.isCheckedOut) {
      return 'Checked out';
    }
    return 'Present';
  }

  Color _statusColor(AttendanceRecordModel? record) {
    if (record == null) {
      return const Color(0xFF94A3B8);
    }
    if (record.isCheckedOut) {
      return const Color(0xFF38BDF8);
    }
    return const Color(0xFF34D399);
  }

  Future<void> _checkOut({
    required String labId,
    required String userId,
  }) async {
    if (_isCheckingOut) {
      return;
    }

    setState(() {
      _isCheckingOut = true;
    });

    try {
      final result = await _attendanceService.checkOut(
        labId: labId,
        userId: userId,
      );
      if (!mounted) {
        return;
      }

      _showMessage(
        result.message.isEmpty ? 'Checked out successfully.' : result.message,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(FirestoreAccessGuard.messageFor(error));
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingOut = false;
        });
      }
    }
  }

  Future<void> _openAttendanceAdmin(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AttendanceAdminScreen()),
    );
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
        final currentUserId = currentUser?.uid.trim() ?? '';
        final currentUserName = appState.authenticatedUserName;
        final isPiAdmin = appState.isPiAdmin;
        final canQueryLabData = FirestoreAccessGuard.shouldQueryLabScopedData(
          appState: appState,
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Attendance',
              style: TextStyle(color: Colors.white),
            ),
          ),
          body: SafeArea(
            child: !canQueryLabData
                ? _AttendanceInfoState(
                    title: 'Attendance needs a lab',
                    message:
                        'Select, create, or join a lab to start using attendance.',
                    icon: Icons.apartment_rounded,
                  )
                : currentUserId.isEmpty
                ? const _AttendanceInfoState(
                    title: 'Sign in required',
                    message: 'Please sign in again to use attendance.',
                    icon: Icons.lock_outline_rounded,
                  )
                : StreamBuilder<List<AttendanceRecordModel>>(
                    stream: _attendanceService.getTodayAttendanceForLab(
                      labId: selectedLabId,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _AttendanceInfoState(
                          title: 'Attendance unavailable',
                          message: FirestoreAccessGuard.messageFor(
                            snapshot.error,
                          ),
                          icon: Icons.error_outline_rounded,
                        );
                      }

                      final todayRecords = snapshot.data ?? [];
                      final todayRecord = _findTodayRecord(
                        todayRecords,
                        currentUserId,
                      );
                      final statusLabel = _statusLabel(todayRecord);
                      final statusColor = _statusColor(todayRecord);
                      final canCheckOut =
                          todayRecord != null &&
                          !todayRecord.isCheckedOut &&
                          !_isCheckingOut;

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
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0x2214B8A6),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(
                                        Icons.fact_check_outlined,
                                        color: Color(0xFF2DD4BF),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Today\'s Attendance',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            selectedLabName.isEmpty
                                                ? 'Attendance for your current lab'
                                                : selectedLabName,
                                            style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _AttendanceChip(
                                      icon: Icons.person_outline_rounded,
                                      label: currentUserName,
                                      accentColor: const Color(0xFF38BDF8),
                                    ),
                                    _AttendanceChip(
                                      icon: Icons.calendar_today_rounded,
                                      label: _formatDate(DateTime.now()),
                                      accentColor: const Color(0xFF94A3B8),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Status',
                                            style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(
                                                0.14,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              statusLabel,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (snapshot.connectionState ==
                                            ConnectionState.waiting &&
                                        snapshot.data == null)
                                      const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Color(0xFF14B8A6),
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
                                  'Today\'s Record',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _AttendanceInfoRow(
                                  label: 'Check-in time',
                                  value: todayRecord == null
                                      ? 'Not checked in yet'
                                      : _formatTimestamp(todayRecord.checkInAt),
                                ),
                                const SizedBox(height: 12),
                                _AttendanceInfoRow(
                                  label: 'Check-out time',
                                  value: todayRecord?.checkOutAt == null
                                      ? 'Not checked out yet'
                                      : _formatTimestamp(
                                          todayRecord?.checkOutAt,
                                        ),
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
                                  'Actions',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        _showMessage('QR scanner coming soon');
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF14B8A6),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.qr_code_scanner_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Scan Lab QR'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: canCheckOut
                                          ? () => _checkOut(
                                              labId: selectedLabId,
                                              userId: currentUserId,
                                            )
                                          : null,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF38BDF8,
                                        ),
                                        disabledForegroundColor:
                                            Colors.white38,
                                        side: BorderSide(
                                          color: canCheckOut
                                              ? const Color(0xFF38BDF8)
                                              : Colors.white24,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                      ),
                                      icon: _isCheckingOut
                                          ? const SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Color(0xFF38BDF8),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.logout_rounded,
                                              size: 18,
                                            ),
                                      label: Text(
                                        _isCheckingOut
                                            ? 'Checking out...'
                                            : 'Check out',
                                      ),
                                    ),
                                    if (isPiAdmin)
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _openAttendanceAdmin(context),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFFF59E0B),
                                          side: const BorderSide(
                                            color: Color(0xFFF59E0B),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.admin_panel_settings_outlined,
                                          size: 18,
                                        ),
                                        label:
                                            const Text('Attendance Admin'),
                                      ),
                                  ],
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

class _AttendanceInfoState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _AttendanceInfoState({
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

class _AttendanceInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _AttendanceInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.2,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _AttendanceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accentColor;

  const _AttendanceChip({
    required this.icon,
    required this.label,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accentColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
