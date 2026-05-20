import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/glass_apparatus_model.dart';
import '../services/firestore_access_guard.dart';
import '../services/glass_apparatus_service.dart';
import '../widgets/responsive_page_container.dart';

class AddGlassApparatusScreen extends StatefulWidget {
  final GlassApparatusModel? existingApparatus;

  const AddGlassApparatusScreen({super.key, this.existingApparatus});

  @override
  State<AddGlassApparatusScreen> createState() =>
      _AddGlassApparatusScreenState();
}

class _AddGlassApparatusScreenState extends State<AddGlassApparatusScreen> {
  final _formKey = GlobalKey<FormState>();
  final GlassApparatusService _apparatusService = GlassApparatusService();

  late final TextEditingController _nameController;
  late final TextEditingController _sizeController;
  late final TextEditingController _quantityController;
  late final TextEditingController _locationController;
  late final TextEditingController _inchargeController;
  late final TextEditingController _notesController;

  String _selectedCategory = GlassApparatusModel.categories.first;
  String _selectedCondition = GlassApparatusModel.conditionOptions.first;
  bool _isSaving = false;

  bool get _isEditMode => widget.existingApparatus != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingApparatus;

    _nameController = TextEditingController(text: existing?.name ?? '');
    _sizeController = TextEditingController(text: existing?.size ?? '');
    _quantityController = TextEditingController(
      text: existing == null ? '1' : existing.quantity.toString(),
    );
    _locationController = TextEditingController(text: existing?.location ?? '');
    _inchargeController = TextEditingController(text: existing?.incharge ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');

    if (existing != null) {
      _selectedCategory = existing.normalizedCategory;
      _selectedCondition = existing.normalizedCondition;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sizeController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    _inchargeController.dispose();
    _notesController.dispose();
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

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required List<Widget> children,
    bool dense = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dense ? 14 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(dense ? 18 : 20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
          SizedBox(height: dense ? 12 : 14),
          ...children,
        ],
      ),
    );
  }

  Widget _fieldGrid({
    required bool isDesktop,
    required List<Widget> children,
  }) {
    if (!isDesktop) {
      return Column(
        children: [
          for (int index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final itemWidth = (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }

  Widget _fullWidthField({
    required bool isDesktop,
    required Widget child,
  }) {
    if (!isDesktop) {
      return child;
    }

    return SizedBox(width: double.infinity, child: child);
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

    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity < 0) {
      _showMessage('Enter a valid quantity.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final existing = widget.existingApparatus;
      final now = Timestamp.now();
      final apparatusId = existing?.id.trim().isNotEmpty == true
          ? existing!.id.trim()
          : _apparatusService.createApparatusId();

      final apparatus = GlassApparatusModel(
        id: apparatusId,
        labId: labId,
        name: _nameController.text.trim(),
        category: _selectedCategory,
        size: _sizeController.text.trim(),
        quantity: quantity,
        condition: _selectedCondition,
        location: _locationController.text.trim(),
        incharge: _inchargeController.text.trim(),
        notes: _notesController.text.trim(),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      if (_isEditMode) {
        await _apparatusService.updateApparatus(apparatus);
      } else {
        await _apparatusService.addApparatus(apparatus);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Glass apparatus updated successfully'
                : 'Glass apparatus added successfully',
          ),
        ),
      );
      Navigator.pop(context, apparatus);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Glass Apparatus' : 'Add Glass Apparatus',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: ResponsivePageContainer(
          maxWidth: 980,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 700;

              return Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.all(isDesktop ? 14 : 16),
                  children: [
                    _buildSectionCard(
                      title: 'Apparatus Details',
                      subtitle: _isEditMode
                          ? 'Update this lab-scoped glassware record.'
                          : 'Create a lightweight glassware record for this lab.',
                      dense: isDesktop,
                      children: [
                        _fieldGrid(
                          isDesktop: isDesktop,
                          children: [
                            TextFormField(
                              controller: _nameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('Name'),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter apparatus name';
                                }
                                return null;
                              },
                            ),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedCategory,
                              dropdownColor: const Color(0xFF111827),
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('Category'),
                              items:
                                  GlassApparatusModel.categories.map((category) {
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
                            TextFormField(
                              controller: _sizeController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('Size / capacity'),
                            ),
                            TextFormField(
                              controller: _quantityController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('Quantity'),
                              validator: (value) {
                                final quantity =
                                    int.tryParse((value ?? '').trim());
                                if (quantity == null || quantity < 0) {
                                  return 'Enter a valid quantity';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: isDesktop ? 12 : 14),
                    _buildSectionCard(
                      title: 'Status & Ownership',
                      subtitle:
                          'Keep condition, placement, and point-of-contact details easy to scan.',
                      dense: isDesktop,
                      children: [
                        _fieldGrid(
                          isDesktop: isDesktop,
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: _selectedCondition,
                              dropdownColor: const Color(0xFF111827),
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('Condition'),
                              items: GlassApparatusModel.conditionOptions.map(
                                (status) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  );
                                },
                              ).toList(),
                              onChanged: _isSaving
                                  ? null
                                  : (value) {
                                      if (value == null) return;
                                      setState(() {
                                        _selectedCondition = value;
                                      });
                                    },
                            ),
                            TextFormField(
                              controller: _locationController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('Location'),
                            ),
                            TextFormField(
                              controller: _inchargeController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('In-charge'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _fullWidthField(
                          isDesktop: isDesktop,
                          child: TextFormField(
                            controller: _notesController,
                            style: const TextStyle(color: Colors.white),
                            maxLines: isDesktop ? 2 : 3,
                            decoration: _inputDecoration('Notes'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isDesktop ? 16 : 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14B8A6),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: isDesktop ? 14 : 16,
                          ),
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
                                  ? 'Update Apparatus'
                                  : 'Save Apparatus'),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
