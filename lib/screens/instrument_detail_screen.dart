import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/instrument_model.dart';
import '../services/firestore_access_guard.dart';
import '../services/instrument_service.dart';
import 'add_instrument_screen.dart';

class InstrumentDetailScreen extends StatefulWidget {
  final InstrumentModel instrument;

  const InstrumentDetailScreen({
    super.key,
    required this.instrument,
  });

  @override
  State<InstrumentDetailScreen> createState() => _InstrumentDetailScreenState();
}

class _InstrumentDetailScreenState extends State<InstrumentDetailScreen> {
  final InstrumentService _instrumentService = InstrumentService();
  late InstrumentModel _instrument;

  @override
  void initState() {
    super.initState();
    _instrument = widget.instrument;
  }

  String _displayValue(String value) {
    final clean = value.trim();
    return clean.isEmpty ? 'Not set' : clean;
  }

  String _formatDate(Timestamp? value) {
    if (value == null) {
      return 'Not set';
    }

    final date = value.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String _formatTenure(Timestamp? from, Timestamp? to) {
    final fromText = from == null ? '' : _formatDate(from);
    final toText = to == null ? '' : _formatDate(to);

    if (fromText.isEmpty && toText.isEmpty) {
      return 'Not set';
    }

    if (fromText.isNotEmpty && toText.isNotEmpty) {
      return '$fromText to $toText';
    }

    if (fromText.isNotEmpty) {
      return 'From $fromText';
    }

    return 'Until $toText';
  }

  Future<DateTime?> _pickDate(DateTime? initialDate) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 15),
      builder: (context, child) {
        return Theme(data: ThemeData.dark(), child: child!);
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openEdit() async {
    final result = await Navigator.push<InstrumentModel>(
      context,
      MaterialPageRoute(
        builder: (_) => AddInstrumentScreen(existingInstrument: _instrument),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _instrument = result;
    });
  }

  Future<void> _deleteInstrument() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            'Delete this instrument?',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Delete "${_instrument.normalizedName}" from this lab?',
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Color(0xFFFB7185)),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _instrumentService.deleteInstrument(docId: _instrument.id);

      if (!mounted) {
        return;
      }

      _showMessage('Instrument deleted');
      Navigator.pop(context, true);
    } catch (error) {
      _showMessage(FirestoreAccessGuard.messageFor(error));
    }
  }

  InputDecoration _sheetInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF111827),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton.icon(
                  onPressed: onAction,
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    size: 18,
                  ),
                  label: Text(actionLabel),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDatePickerTile({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    final display = value == null
        ? 'Select date'
        : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    display,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.calendar_today_rounded, color: Color(0xFF14B8A6)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildServiceHistoryCard(InstrumentServiceHistoryRecord record) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _displayValue(record.serviceIncharge),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Service date: ${_formatDate(record.serviceDate)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12.8),
          ),
          const SizedBox(height: 6),
          Text(
            'Contact: ${_displayValue(record.serviceInchargeContactNo)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12.8),
          ),
          const SizedBox(height: 6),
          Text(
            'Details: ${_displayValue(record.serviceDetails)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.8,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Added on: ${_formatDate(record.createdAt)}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildInchargeHistoryCard(InstrumentInchargeHistoryRecord record) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _displayValue(record.instrumentIncharge),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contact: ${_displayValue(record.instrumentInchargeContactNo)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12.8),
          ),
          const SizedBox(height: 6),
          Text(
            'Tenure: ${_formatTenure(record.tenureFrom, record.tenureTo)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.8,
              height: 1.4,
            ),
          ),
          if (record.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Notes: ${record.notes.trim()}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12.8,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Added on: ${_formatDate(record.createdAt)}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _addServiceRecord() async {
    final formKey = GlobalKey<FormState>();
    final serviceInchargeController = TextEditingController(
      text: _instrument.serviceIncharge,
    );
    final contactController = TextEditingController(
      text: _instrument.serviceInchargeContactNo,
    );
    final detailsController = TextEditingController();
    DateTime? serviceDate = _instrument.serviceDate?.toDate() ?? DateTime.now();

    final record = await showModalBottomSheet<InstrumentServiceHistoryRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SafeArea(
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add service record',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildDatePickerTile(
                          label: 'Service date',
                          value: serviceDate,
                          onTap: () async {
                            final picked = await _pickDate(serviceDate);
                            if (picked == null) {
                              return;
                            }
                            setSheetState(() {
                              serviceDate = picked;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: serviceInchargeController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _sheetInputDecoration('Service incharge'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter service incharge';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: contactController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.phone,
                          decoration: _sheetInputDecoration(
                            'Service incharge contact no',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: detailsController,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 3,
                          decoration: _sheetInputDecoration('Service details'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter service details';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }
                                  Navigator.pop(
                                    context,
                                    InstrumentServiceHistoryRecord(
                                      serviceDate: serviceDate == null
                                          ? null
                                          : Timestamp.fromDate(serviceDate!),
                                      serviceDetails:
                                          detailsController.text.trim(),
                                      serviceIncharge:
                                          serviceInchargeController.text.trim(),
                                      serviceInchargeContactNo:
                                          contactController.text.trim(),
                                      createdAt: Timestamp.now(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF14B8A6),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Save'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    serviceInchargeController.dispose();
    contactController.dispose();
    detailsController.dispose();

    if (record == null) {
      return;
    }

    try {
      await _instrumentService.addServiceHistoryRecord(
        instrumentId: _instrument.id,
        record: record,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _instrument = _instrument.copyWith(
          serviceHistory: [
            ..._instrument.serviceHistory,
            record,
          ],
          updatedAt: Timestamp.now(),
        );
      });
      _showMessage('Service record added');
    } catch (error) {
      _showMessage(FirestoreAccessGuard.messageFor(error));
    }
  }

  Future<void> _addInchargeRecord() async {
    final formKey = GlobalKey<FormState>();
    final inchargeController = TextEditingController(
      text: _instrument.instrumentIncharge,
    );
    final contactController = TextEditingController(
      text: _instrument.instrumentInchargeContactNo,
    );
    final notesController = TextEditingController();
    DateTime? tenureFrom =
        _instrument.instrumentInchargeTenureFrom?.toDate() ?? DateTime.now();
    DateTime? tenureTo = _instrument.instrumentInchargeTenureTo?.toDate();

    final record = await showModalBottomSheet<InstrumentInchargeHistoryRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SafeArea(
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add in-charge record',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: inchargeController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _sheetInputDecoration(
                            'Instrument in-charge',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter instrument in-charge';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: contactController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.phone,
                          decoration: _sheetInputDecoration(
                            'Instrument in-charge contact no',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDatePickerTile(
                          label: 'Tenure from',
                          value: tenureFrom,
                          onTap: () async {
                            final picked = await _pickDate(tenureFrom);
                            if (picked == null) {
                              return;
                            }
                            setSheetState(() {
                              tenureFrom = picked;
                              if (tenureTo != null && tenureTo!.isBefore(picked)) {
                                tenureTo = picked;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildDatePickerTile(
                          label: 'Tenure to',
                          value: tenureTo,
                          onTap: () async {
                            final picked = await _pickDate(tenureTo ?? tenureFrom);
                            if (picked == null) {
                              return;
                            }
                            setSheetState(() {
                              tenureTo = picked;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: notesController,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 3,
                          decoration: _sheetInputDecoration('Notes'),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }
                                  Navigator.pop(
                                    context,
                                    InstrumentInchargeHistoryRecord(
                                      instrumentIncharge:
                                          inchargeController.text.trim(),
                                      instrumentInchargeContactNo:
                                          contactController.text.trim(),
                                      tenureFrom: tenureFrom == null
                                          ? null
                                          : Timestamp.fromDate(tenureFrom!),
                                      tenureTo: tenureTo == null
                                          ? null
                                          : Timestamp.fromDate(tenureTo!),
                                      notes: notesController.text.trim(),
                                      createdAt: Timestamp.now(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF14B8A6),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Save'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    inchargeController.dispose();
    contactController.dispose();
    notesController.dispose();

    if (record == null) {
      return;
    }

    try {
      await _instrumentService.addInchargeHistoryRecord(
        instrumentId: _instrument.id,
        record: record,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _instrument = _instrument.copyWith(
          inchargeHistory: [
            ..._instrument.inchargeHistory,
            record,
          ],
          updatedAt: Timestamp.now(),
        );
      });
      _showMessage('In-charge record added');
    } catch (error) {
      _showMessage(FirestoreAccessGuard.messageFor(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Instrument Details',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Instrument options',
            color: const Color(0xFF1E293B),
            onSelected: (value) {
              if (value == 'delete') {
                _deleteInstrument();
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFFB7185),
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Delete',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _InstrumentDetailHero(
              instrument: _instrument,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openEdit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.edit_rounded),
                label: const Text(
                  'Edit Instrument',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildSection(
              title: 'Basic Information',
              children: [
                _buildField('Instrument name', _instrument.normalizedName),
                const SizedBox(height: 10),
                _buildField('Category', _displayValue(_instrument.category)),
                const SizedBox(height: 10),
                _buildField('Arrived on', _formatDate(_instrument.arrivedOn)),
              ],
            ),
            const SizedBox(height: 14),
            _buildSection(
              title: 'Instrument Details',
              children: [
                _buildField('Brand', _displayValue(_instrument.brand)),
                const SizedBox(height: 10),
                _buildField('Serial no', _displayValue(_instrument.serialNo)),
                const SizedBox(height: 10),
                _buildField(
                  'Catalog number',
                  _displayValue(_instrument.catalogNumber),
                ),
                const SizedBox(height: 10),
                _buildField(
                  'Specification',
                  _displayValue(_instrument.specification),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildSection(
              title: 'Guides & Ownership',
              children: [
                _buildField('User guide', _displayValue(_instrument.userGuide)),
                const SizedBox(height: 10),
                _buildField(
                  'Instrument in-charge',
                  _displayValue(_instrument.instrumentIncharge),
                ),
                const SizedBox(height: 10),
                _buildField(
                  'Instrument in-charge contact no',
                  _displayValue(_instrument.instrumentInchargeContactNo),
                ),
                const SizedBox(height: 10),
                _buildField(
                  'Current tenure',
                  _formatTenure(
                    _instrument.instrumentInchargeTenureFrom,
                    _instrument.instrumentInchargeTenureTo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildSection(
              title: 'Current Servicing',
              children: [
                _buildField(
                  'Service incharge',
                  _displayValue(_instrument.serviceIncharge),
                ),
                const SizedBox(height: 10),
                _buildField(
                  'Service incharge contact no',
                  _displayValue(_instrument.serviceInchargeContactNo),
                ),
                const SizedBox(height: 10),
                _buildField('Service date', _formatDate(_instrument.serviceDate)),
                const SizedBox(height: 10),
                _buildField(
                  'Service details',
                  _displayValue(_instrument.serviceDetails),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildSection(
              title: 'Service History',
              actionLabel: 'Add service record',
              onAction: _addServiceRecord,
              children: _instrument.serviceHistory.isEmpty
                  ? [
                      _buildHistoryEmptyState('No service history yet'),
                    ]
                  : _instrument.serviceHistory.map((record) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildServiceHistoryCard(record),
                      );
                    }).toList(),
            ),
            const SizedBox(height: 14),
            _buildSection(
              title: 'In-charge History',
              actionLabel: 'Add in-charge record',
              onAction: _addInchargeRecord,
              children: _instrument.inchargeHistory.isEmpty
                  ? [
                      _buildHistoryEmptyState('No in-charge history yet'),
                    ]
                  : _instrument.inchargeHistory.map((record) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildInchargeHistoryCard(record),
                      );
                    }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstrumentDetailHero extends StatelessWidget {
  final InstrumentModel instrument;

  const _InstrumentDetailHero({required this.instrument});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InstrumentDetailPreview(
            photoReference: instrument.previewPhoto,
            fallbackIcon: _iconForCategory(instrument.normalizedCategory),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  instrument.normalizedName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    instrument.normalizedCategory,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InstrumentDetailPreview extends StatelessWidget {
  final String photoReference;
  final IconData fallbackIcon;

  const _InstrumentDetailPreview({
    required this.photoReference,
    required this.fallbackIcon,
  });

  ImageProvider<Object>? _resolveImageProvider() {
    final cleanReference = photoReference.trim();
    if (cleanReference.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(cleanReference);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return NetworkImage(cleanReference);
    }

    if (uri != null && uri.scheme == 'file') {
      final file = File.fromUri(uri);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }

    final file = File(cleanReference);
    if (file.existsSync()) {
      return FileImage(file);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = _resolveImageProvider();

    return Container(
      height: 112,
      width: 112,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: imageProvider == null
            ? Center(
                child: Icon(
                  fallbackIcon,
                  color: const Color(0xFF14B8A6),
                  size: 42,
                ),
              )
            : Image(
                image: imageProvider,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Center(
                    child: Icon(
                      fallbackIcon,
                      color: const Color(0xFF14B8A6),
                      size: 42,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

IconData _iconForCategory(String category) {
  switch (category) {
    case 'Weighing balance':
      return Icons.scale_rounded;
    case 'Magnetic stirrer':
      return Icons.rotate_right_rounded;
    case 'Vacuum pump':
      return Icons.air_rounded;
    case 'Rotary evaporator':
      return Icons.autorenew_rounded;
    case 'Chiller':
      return Icons.ac_unit_rounded;
    case 'Heating mantel':
      return Icons.local_fire_department_rounded;
    case 'Refrigerator':
      return Icons.kitchen_rounded;
    case 'Oven':
      return Icons.microwave_rounded;
    default:
      return Icons.precision_manufacturing_rounded;
  }
}
