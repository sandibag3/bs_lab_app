import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../models/instrument_model.dart';
import '../services/firestore_access_guard.dart';
import '../services/instrument_service.dart';

class AddInstrumentScreen extends StatefulWidget {
  final InstrumentModel? existingInstrument;

  const AddInstrumentScreen({
    super.key,
    this.existingInstrument,
  });

  @override
  State<AddInstrumentScreen> createState() => _AddInstrumentScreenState();
}

class _AddInstrumentScreenState extends State<AddInstrumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final InstrumentService _instrumentService = InstrumentService();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _serialNoController;
  late final TextEditingController _catalogNumberController;
  late final TextEditingController _serviceInchargeController;
  late final TextEditingController _serviceInchargeContactNoController;
  late final TextEditingController _specificationController;
  late final TextEditingController _userGuideController;
  late final TextEditingController _instrumentInchargeController;
  late final TextEditingController _instrumentInchargeContactNoController;
  late final TextEditingController _serviceDetailsController;

  final List<String> _existingPhotoUrls = [];
  final List<XFile> _pendingPhotoFiles = [];

  String _selectedCategory = InstrumentModel.categories.first;
  DateTime? _arrivedOn;
  DateTime? _serviceDate;
  DateTime? _instrumentInchargeTenureFrom;
  DateTime? _instrumentInchargeTenureTo;
  bool _isSaving = false;

  bool get _isEditMode => widget.existingInstrument != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingInstrument;
    _nameController = TextEditingController();
    _brandController = TextEditingController();
    _serialNoController = TextEditingController();
    _catalogNumberController = TextEditingController();
    _serviceInchargeController = TextEditingController();
    _serviceInchargeContactNoController = TextEditingController();
    _specificationController = TextEditingController();
    _userGuideController = TextEditingController();
    _instrumentInchargeController = TextEditingController();
    _instrumentInchargeContactNoController = TextEditingController();
    _serviceDetailsController = TextEditingController();

    if (existing != null) {
      _selectedCategory = existing.normalizedCategory;
      _arrivedOn = existing.arrivedOn?.toDate();
      _serviceDate = existing.serviceDate?.toDate();
      _instrumentInchargeTenureFrom =
          existing.instrumentInchargeTenureFrom?.toDate();
      _instrumentInchargeTenureTo =
          existing.instrumentInchargeTenureTo?.toDate();
      _nameController.text = existing.name;
      _brandController.text = existing.brand;
      _serialNoController.text = existing.serialNo;
      _catalogNumberController.text = existing.catalogNumber;
      _serviceInchargeController.text = existing.serviceIncharge;
      _serviceInchargeContactNoController.text =
          existing.serviceInchargeContactNo;
      _specificationController.text = existing.specification;
      _userGuideController.text = existing.userGuide;
      _instrumentInchargeController.text = existing.instrumentIncharge;
      _instrumentInchargeContactNoController.text =
          existing.instrumentInchargeContactNo;
      _serviceDetailsController.text = existing.serviceDetails;
      _existingPhotoUrls.addAll(
        existing.photoUrls
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _serialNoController.dispose();
    _catalogNumberController.dispose();
    _serviceInchargeController.dispose();
    _serviceInchargeContactNoController.dispose();
    _specificationController.dispose();
    _userGuideController.dispose();
    _instrumentInchargeController.dispose();
    _instrumentInchargeContactNoController.dispose();
    _serviceDetailsController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label) {
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

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Select date';
    }

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }

  Future<DateTime?> _pickDate(DateTime? initialDate) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
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

  Future<void> _selectArrivedOn() async {
    final picked = await _pickDate(_arrivedOn);
    if (picked == null) return;
    setState(() {
      _arrivedOn = picked;
    });
  }

  Future<void> _selectServiceDate() async {
    final picked = await _pickDate(_serviceDate ?? _arrivedOn);
    if (picked == null) return;
    setState(() {
      _serviceDate = picked;
    });
  }

  Future<void> _selectInstrumentInchargeTenureFrom() async {
    final picked = await _pickDate(_instrumentInchargeTenureFrom ?? _arrivedOn);
    if (picked == null) return;
    setState(() {
      _instrumentInchargeTenureFrom = picked;
      if (_instrumentInchargeTenureTo != null &&
          _instrumentInchargeTenureTo!.isBefore(picked)) {
        _instrumentInchargeTenureTo = picked;
      }
    });
  }

  Future<void> _selectInstrumentInchargeTenureTo() async {
    final picked = await _pickDate(
      _instrumentInchargeTenureTo ??
          _instrumentInchargeTenureFrom ??
          _arrivedOn,
    );
    if (picked == null) return;
    setState(() {
      _instrumentInchargeTenureTo = picked;
    });
  }

  Future<void> _pickInstrumentPhoto() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (pickedFile == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingPhotoFiles.add(pickedFile);
      });
    } catch (_) {
      _showMessage('Unable to pick image right now');
    }
  }

  void _removeExistingPhoto(int index) {
    setState(() {
      _existingPhotoUrls.removeAt(index);
    });
  }

  void _removePendingPhoto(int index) {
    setState(() {
      _pendingPhotoFiles.removeAt(index);
    });
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
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
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
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
                    _formatDate(value),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!FirestoreAccessGuard.shouldQueryLabScopedData()) {
      _showMessage(FirestoreAccessGuard.userMessage);
      return;
    }

    final labId = AppState.instance.resolveWriteLabId().trim();
    if (labId.isEmpty) {
      _showMessage(FirestoreAccessGuard.userMessage);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final existing = widget.existingInstrument;
      final now = Timestamp.now();
      final instrumentId =
          existing?.id.trim().isNotEmpty == true
              ? existing!.id.trim()
              : _instrumentService.createInstrumentId();

      final photoUrls = [
        ..._existingPhotoUrls,
        ..._pendingPhotoFiles
            .map((file) => file.path.trim())
            .where((path) => path.isNotEmpty),
      ];

      final instrument = InstrumentModel(
        id: instrumentId,
        labId: labId,
        name: _nameController.text.trim(),
        category: _selectedCategory,
        arrivedOn: _arrivedOn == null ? null : Timestamp.fromDate(_arrivedOn!),
        brand: _brandController.text.trim(),
        serialNo: _serialNoController.text.trim(),
        catalogNumber: _catalogNumberController.text.trim(),
        serviceIncharge: _serviceInchargeController.text.trim(),
        serviceInchargeContactNo: _serviceInchargeContactNoController.text.trim(),
        specification: _specificationController.text.trim(),
        userGuide: _userGuideController.text.trim(),
        instrumentIncharge: _instrumentInchargeController.text.trim(),
        instrumentInchargeContactNo:
            _instrumentInchargeContactNoController.text.trim(),
        instrumentInchargeTenureFrom: _instrumentInchargeTenureFrom == null
            ? null
            : Timestamp.fromDate(_instrumentInchargeTenureFrom!),
        instrumentInchargeTenureTo: _instrumentInchargeTenureTo == null
            ? null
            : Timestamp.fromDate(_instrumentInchargeTenureTo!),
        serviceDate: _serviceDate == null
            ? null
            : Timestamp.fromDate(_serviceDate!),
        serviceDetails: _serviceDetailsController.text.trim(),
        serviceHistory:
            existing?.serviceHistory ?? const <InstrumentServiceHistoryRecord>[],
        inchargeHistory:
            existing?.inchargeHistory ?? const <InstrumentInchargeHistoryRecord>[],
        photoUrls: photoUrls,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      if (_isEditMode) {
        await _instrumentService.updateInstrument(instrument);
      } else {
        await _instrumentService.addInstrument(instrument);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Instrument updated successfully'
                : 'Instrument added successfully',
          ),
        ),
      );
      Navigator.pop(context, instrument);
    } catch (error) {
      _showMessage(FirestoreAccessGuard.messageFor(error));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPhotos = _existingPhotoUrls.length + _pendingPhotoFiles.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Instrument' : 'Add Instrument',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionCard(
                title: 'Basic Information',
                subtitle: _isEditMode
                    ? 'Update the current lab-scoped instrument record.'
                    : 'Create a lab-scoped instrument record.',
                children: [
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Instrument name'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter instrument name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    dropdownColor: const Color(0xFF111827),
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Category'),
                    items: InstrumentModel.categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedCategory = value;
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  _buildDateField(
                    label: 'Arrived on',
                    value: _arrivedOn,
                    onTap: _selectArrivedOn,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildSectionCard(
                title: 'Instrument Details',
                subtitle: 'Track vendor and reference details for the instrument.',
                children: [
                  TextFormField(
                    controller: _brandController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Brand'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _serialNoController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Serial no'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _catalogNumberController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Catalog number'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _serviceInchargeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Service incharge'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _serviceInchargeContactNoController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration('Service incharge contact no'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _specificationController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: _inputDecoration('Specification'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildSectionCard(
                title: 'Guides & Ownership',
                subtitle: 'Keep quick access info and point-of-contact details together.',
                children: [
                  TextFormField(
                    controller: _userGuideController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: _inputDecoration('User guide (text or link)'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _instrumentInchargeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Instrument in-charge'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _instrumentInchargeContactNoController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration(
                      'Instrument in-charge contact no',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDateField(
                    label: 'Tenure from',
                    value: _instrumentInchargeTenureFrom,
                    onTap: _selectInstrumentInchargeTenureFrom,
                  ),
                  const SizedBox(height: 12),
                  _buildDateField(
                    label: 'Tenure to',
                    value: _instrumentInchargeTenureTo,
                    onTap: _selectInstrumentInchargeTenureTo,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildSectionCard(
                title: 'Servicing',
                subtitle: 'Record the most recent service checkpoint if available.',
                children: [
                  _buildDateField(
                    label: 'Service date',
                    value: _serviceDate,
                    onTap: _selectServiceDate,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _serviceDetailsController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: _inputDecoration('Service details'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildSectionCard(
                title: 'Instrument Photos',
                subtitle:
                    'Pick instrument photos from the device. For now, selected local photo paths are saved directly with the instrument record.',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          totalPhotos == 0
                              ? 'No photos selected yet'
                              : '$totalPhotos photo${totalPhotos == 1 ? '' : 's'} selected',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.8,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isSaving ? null : _pickInstrumentPhoto,
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text('Add photo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (totalPhotos == 0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Selected photos will appear here before save.',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12.8,
                          height: 1.4,
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ...List.generate(_existingPhotoUrls.length, (index) {
                          return _InstrumentPhotoPreviewTile(
                            previewSource: _existingPhotoUrls[index],
                            label: 'Saved',
                            onRemove: _isSaving
                                ? null
                                : () => _removeExistingPhoto(index),
                          );
                        }),
                        ...List.generate(_pendingPhotoFiles.length, (index) {
                          return _InstrumentPhotoPreviewTile(
                            previewSource: _pendingPhotoFiles[index].path,
                            label: 'New',
                            onRemove: _isSaving
                                ? null
                                : () => _removePendingPhoto(index),
                          );
                        }),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    _isSaving
                        ? (_isEditMode ? 'Updating...' : 'Saving...')
                        : (_isEditMode
                              ? 'Update Instrument'
                              : 'Save Instrument'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstrumentPhotoPreviewTile extends StatelessWidget {
  final String previewSource;
  final String label;
  final VoidCallback? onRemove;

  const _InstrumentPhotoPreviewTile({
    required this.previewSource,
    required this.label,
    required this.onRemove,
  });

  ImageProvider<Object>? _resolveImageProvider() {
    final cleanReference = previewSource.trim();
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
      width: 104,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 86,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageProvider == null
                      ? const Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.white38,
                          ),
                        )
                      : Image(
                          image: imageProvider,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return const Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.white38,
                              ),
                            );
                          },
                        ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
