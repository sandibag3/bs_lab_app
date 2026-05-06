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

    final messenger = ScaffoldMessenger.of(context);

    try {
      await _instrumentService.deleteInstrument(docId: _instrument.id);

      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('Instrument deleted')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text(FirestoreAccessGuard.messageFor(error))),
      );
    }
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
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
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
                  'Service incharge',
                  _displayValue(_instrument.serviceIncharge),
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
              ],
            ),
            const SizedBox(height: 14),
            _buildSection(
              title: 'Servicing',
              children: [
                _buildField(
                  'Service date',
                  _formatDate(_instrument.serviceDate),
                ),
                const SizedBox(height: 10),
                _buildField(
                  'Service details',
                  _displayValue(_instrument.serviceDetails),
                ),
              ],
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
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https')) {
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
