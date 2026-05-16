import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/attendance_record_model.dart';
import '../services/attendance_service.dart';
import '../services/firestore_access_guard.dart';

enum _AttendanceLogbookStatusFilter { all, present, checkedOut }

class AttendanceLogbookScreen extends StatefulWidget {
  const AttendanceLogbookScreen({super.key});

  @override
  State<AttendanceLogbookScreen> createState() => _AttendanceLogbookScreenState();
}

class _AttendanceLogbookScreenState extends State<AttendanceLogbookScreen> {
  final AttendanceService _attendanceService = AttendanceService();

  DateTime? _selectedDate;
  _AttendanceLogbookStatusFilter _statusFilter =
      _AttendanceLogbookStatusFilter.all;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(data: ThemeData.dark(), child: child!);
      },
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
    });
  }

  String _formatDateLabel(DateTime value) {
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

  String _formatTime(Timestamp? value) {
    if (value == null) {
      return 'Not available';
    }

    final dateTime = value.toDate();
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final meridiem = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $meridiem';
  }

  DateTime? _dateFromKey(String dateKey) {
    try {
      return DateTime.tryParse(dateKey);
    } catch (_) {
      return null;
    }
  }

  String _sectionTitle(String dateKey) {
    final date = _dateFromKey(dateKey);
    if (date == null) {
      return dateKey;
    }

    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final difference = normalizedToday.difference(normalizedDate).inDays;

    if (difference == 0) {
      return 'Today';
    }
    if (difference == 1) {
      return 'Yesterday';
    }

    return _formatDateLabel(normalizedDate);
  }

  String _statusLabel(AttendanceRecordModel record) {
    return record.isCheckedOut ? 'Checked out' : 'Present';
  }

  Color _statusColor(AttendanceRecordModel record) {
    return record.isCheckedOut
        ? const Color(0xFF38BDF8)
        : const Color(0xFF34D399);
  }

  List<AttendanceRecordModel> _applyFilters(List<AttendanceRecordModel> input) {
    return input.where((record) {
      if (_selectedDate != null) {
        final recordDate = _dateFromKey(record.dateKey);
        if (recordDate == null) {
          return false;
        }

        final normalizedRecordDate = DateTime(
          recordDate.year,
          recordDate.month,
          recordDate.day,
        );
        final normalizedSelectedDate = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
        );
        if (normalizedRecordDate != normalizedSelectedDate) {
          return false;
        }
      }

      switch (_statusFilter) {
        case _AttendanceLogbookStatusFilter.present:
          return !record.isCheckedOut;
        case _AttendanceLogbookStatusFilter.checkedOut:
          return record.isCheckedOut;
        case _AttendanceLogbookStatusFilter.all:
          return true;
      }
    }).toList();
  }

  List<MapEntry<String, List<AttendanceRecordModel>>> _groupByDate(
    List<AttendanceRecordModel> records,
  ) {
    final grouped = <String, List<AttendanceRecordModel>>{};

    for (final record in records) {
      grouped.putIfAbsent(record.dateKey, () => []).add(record);
    }

    return grouped.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
  }

  Widget _buildStatusFilterChip({
    required String label,
    required _AttendanceLogbookStatusFilter value,
  }) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF14B8A6),
      backgroundColor: const Color(0xFF111827),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
      onSelected: (_) {
        setState(() {
          _statusFilter = value;
        });
      },
    );
  }

  Widget _buildFiltersCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _pickDate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF38BDF8)),
                ),
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: Text(
                  _selectedDate == null
                      ? 'Select date'
                      : _formatDateLabel(_selectedDate!),
                ),
              ),
              if (_selectedDate != null)
                TextButton(
                  onPressed: _clearDateFilter,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFF59E0B),
                  ),
                  child: const Text('Clear date'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusFilterChip(
                  label: 'All records',
                  value: _AttendanceLogbookStatusFilter.all,
                ),
                const SizedBox(width: 8),
                _buildStatusFilterChip(
                  label: 'Present',
                  value: _AttendanceLogbookStatusFilter.present,
                ),
                const SizedBox(width: 8),
                _buildStatusFilterChip(
                  label: 'Checked out',
                  value: _AttendanceLogbookStatusFilter.checkedOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordMetaChip({
    required IconData icon,
    required String label,
    Color color = const Color(0xFF14B8A6),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(AttendanceRecordModel record) {
    final statusColor = _statusColor(record);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.userName.trim().isEmpty
                          ? 'Unknown user'
                          : record.userName.trim(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.userEmail.trim().isEmpty
                          ? 'Email not available'
                          : record.userEmail.trim(),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(record),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildRecordMetaChip(
                icon: Icons.calendar_month_rounded,
                label: record.dateKey,
                color: const Color(0xFF94A3B8),
              ),
              _buildRecordMetaChip(
                icon: Icons.login_rounded,
                label: 'Check-in: ${_formatTime(record.checkInAt)}',
              ),
              if (record.checkOutAt != null)
                _buildRecordMetaChip(
                  icon: Icons.logout_rounded,
                  label: 'Check-out: ${_formatTime(record.checkOutAt)}',
                  color: const Color(0xFF38BDF8),
                ),
              if (record.wifiSsid.trim().isNotEmpty)
                _buildRecordMetaChip(
                  icon: Icons.wifi_rounded,
                  label: record.wifiSsid.trim(),
                ),
              if (record.checkInMethod.trim().isNotEmpty)
                _buildRecordMetaChip(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'In: ${record.checkInMethod.trim()}',
                ),
              if (record.checkOutMethod.trim().isNotEmpty)
                _buildRecordMetaChip(
                  icon: Icons.fact_check_outlined,
                  label: 'Out: ${record.checkOutMethod.trim()}',
                  color: const Color(0xFF38BDF8),
                ),
            ],
          ),
        ],
      ),
    );
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
              'Attendance Logbook',
              style: TextStyle(color: Colors.white),
            ),
          ),
          body: SafeArea(
            child: !canQueryLabData
                ? _buildInfoState(
                    title: 'Attendance logbook needs a lab',
                    message:
                        'Select, create, or join a lab before viewing attendance history.',
                    icon: Icons.apartment_rounded,
                  )
                : StreamBuilder<List<AttendanceRecordModel>>(
                    stream: _attendanceService.getLabAttendanceHistory(
                      labId: selectedLabId,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _buildInfoState(
                          title: 'Attendance logbook unavailable',
                          message: FirestoreAccessGuard.messageFor(
                            snapshot.error,
                          ),
                          icon: Icons.error_outline_rounded,
                        );
                      }

                      final records = _applyFilters(snapshot.data ?? const []);
                      final groupedRecords = _groupByDate(records);

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
                                  'Attendance Logbook',
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFiltersCard(),
                          const SizedBox(height: 16),
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              snapshot.data == null)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: CircularProgressIndicator(
                                  color: Color(0xFF14B8A6),
                                ),
                              ),
                            )
                          else if (groupedRecords.isEmpty)
                            _buildInfoState(
                              title: 'No attendance records yet.',
                              message:
                                  'Attendance check-ins for this lab will appear here once people start using attendance.',
                              icon: Icons.fact_check_outlined,
                            )
                          else
                            ...groupedRecords.expand((entry) {
                              final section = <Widget>[
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 10,
                                    top: 4,
                                  ),
                                  child: Text(
                                    _sectionTitle(entry.key),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ];

                              section.addAll(
                                entry.value.map(_buildRecordCard),
                              );
                              return section;
                            }),
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
