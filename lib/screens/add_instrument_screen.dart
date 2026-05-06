import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _serialNoController;
  late final TextEditingController _catalogNumberController;
  late final TextEditingController _serviceInchargeController;
  late final TextEditingController _specificationController;
  late final TextEditingController _userGuideController;
  late final TextEditingController _instrumentInchargeController;
  late final TextEditingController _serviceDetailsController;

  final List<TextEditingController> _photoUrlControllers = [];

  String _selectedCategory = InstrumentModel.categories.first;
  DateTime? _arrivedOn;
  DateTime? _serviceDate;
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
    _specificationController = TextEditingController();
    _userGuideController = TextEditingController();
    _instrumentInchargeController = TextEditingController();
    _serviceDetailsController = TextEditingController();

    if (existing != null) {
      _selectedCategory = existing.normalizedCategory;
      _arrivedOn = existing.arrivedOn?.toDate();
      _serviceDate = existing.serviceDate?.toDate();
      _nameController.text = existing.name;
      _brandController.text = existing.brand;
      _serialNoController.text = existing.serialNo;
      _catalogNumberController.text = existing.catalogNumber;
      _serviceInchargeController.text = existing.serviceIncharge;
      _specificationController.text = existing.specification;
      _userGuideController.text = existing.userGuide;
      _instrumentInchargeController.text = existing.instrumentIncharge;
      _serviceDetailsController.text = existing.serviceDetails;

      final photoUrls = existing.photoUrls
          .where((value) => value.trim().isNotEmpty)
          .toList();

      if (photoUrls.isEmpty) {
        _photoUrlControllers.add(TextEditingController());
      } else {
        for (final photoUrl in photoUrls) {
          _photoUrlControllers.add(TextEditingController(text: photoUrl));
        }
      }
    } else {
      _photoUrlControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _serialNoController.dispose();
    _catalogNumberController.dispose();
    _serviceInchargeController.dispose();
    _specificationController.dispose();
    _userGuideController.dispose();
    _instrumentInchargeController.dispose();
    _serviceDetailsController.dispose();
    for (final controller in _photoUrlControllers) {
      controller.dispose();
    }
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

  void _addPhotoField() {
    setState(() {
      _photoUrlControllers.add(TextEditingController());
    });
  }

  void _removePhotoField(int index) {
    if (_photoUrlControllers.length == 1) {
      _photoUrlControllers.first.clear();
      return;
    }

    final controller = _photoUrlControllers.removeAt(index);
    controller.dispose();
    setState(() {});
  }

  List<String> _collectPhotoUrls() {
    return _photoUrlControllers
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(FirestoreAccessGuard.userMessage)),
      );
      return;
    }

    final labId = AppState.instance.resolveWriteLabId().trim();
    if (labId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(FirestoreAccessGuard.userMessage)),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final existing = widget.existingInstrument;
      final now = Timestamp.now();
      final instrument = InstrumentModel(
        id: existing?.id ?? '',
        labId: labId,
        name: _nameController.text.trim(),
        category: _selectedCategory,
        arrivedOn: _arrivedOn == null ? null : Timestamp.fromDate(_arrivedOn!),
        brand: _brandController.text.trim(),
        serialNo: _serialNoController.text.trim(),
        catalogNumber: _catalogNumberController.text.trim(),
        serviceIncharge: _serviceInchargeController.text.trim(),
        specification: _specificationController.text.trim(),
        userGuide: _userGuideController.text.trim(),
        instrumentIncharge: _instrumentInchargeController.text.trim(),
        serviceDate: _serviceDate == null
            ? null
            : Timestamp.fromDate(_serviceDate!),
        serviceDetails: _serviceDetailsController.text.trim(),
        photoUrls: _collectPhotoUrls(),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      InstrumentModel savedInstrument = instrument;

      if (_isEditMode) {
        await _instrumentService.updateInstrument(instrument);
      } else {
        final docId = await _instrumentService.addInstrument(instrument);
        savedInstrument = instrument.copyWith(id: docId);
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
      Navigator.pop(context, savedInstrument);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FirestoreAccessGuard.messageFor(error))),
      );
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
                subtitle:
                    _isEditMode
                        ? 'Update the current lab-scoped instrument record. Photo upload is kept as URL or path text for now.'
                        : 'Create a lab-scoped instrument record. Photo upload is kept as URL or path text for now.',
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
                    'Add one or more image URLs or local file paths for preview cards. File upload can come later.',
                children: [
                  ...List.generate(_photoUrlControllers.length, (index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == _photoUrlControllers.length - 1 ? 0 : 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _photoUrlControllers[index],
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                'Photo URL or local path ${index + 1}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: _isSaving
                                ? null
                                : () => _removePhotoField(index),
                            icon: const Icon(
                              Icons.remove_circle_outline_rounded,
                              color: Color(0xFFFB7185),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _addPhotoField,
                    icon: const Icon(Icons.add_link_rounded),
                    label: const Text('Add another photo reference'),
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
