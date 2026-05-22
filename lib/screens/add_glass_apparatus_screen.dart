import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/glass_apparatus_model.dart';
import '../services/firestore_access_guard.dart';
import '../services/glass_apparatus_service.dart';
import '../theme/labmate_theme.dart';
import '../widgets/responsive_page_container.dart';

class AddGlassApparatusScreen extends StatefulWidget {
  final GlassApparatusModel? existingApparatus;

  const AddGlassApparatusScreen({super.key, this.existingApparatus});

  @override
  State<AddGlassApparatusScreen> createState() =>
      _AddGlassApparatusScreenState();
}

class _AddGlassApparatusScreenState extends State<AddGlassApparatusScreen> {
  static const String _customCategoryOption = 'Add custom category...';

  final _formKey = GlobalKey<FormState>();
  final GlassApparatusService _apparatusService = GlassApparatusService();

  late final TextEditingController _nameController;
  late final TextEditingController _sizeController;
  late final TextEditingController _quantityController;
  late final TextEditingController _locationController;
  late final TextEditingController _inchargeController;
  late final TextEditingController _notesController;
  late final TextEditingController _customCategoryController;

  String _selectedCategory = GlassApparatusModel.categories.first;
  String _selectedCondition = GlassApparatusModel.conditionOptions.first;
  bool _isSaving = false;

  bool get _isEditMode => widget.existingApparatus != null;

  bool get _isCustomCategorySelected {
    return _selectedCategory == _customCategoryOption;
  }

  String get _resolvedCategory {
    if (_isCustomCategorySelected) {
      return _customCategoryController.text.trim();
    }

    return _selectedCategory.trim();
  }

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
    _customCategoryController = TextEditingController();

    if (existing != null) {
      final existingCategory = existing.category.trim();
      if (GlassApparatusModel.categories.contains(existingCategory)) {
        _selectedCategory = existingCategory;
      } else if (existingCategory.isNotEmpty) {
        _selectedCategory = _customCategoryOption;
        _customCategoryController.text = existingCategory;
      }
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
    _customCategoryController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label) {
    final palette = context.labmate;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: palette.mutedText,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: palette.panel,
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
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dense ? 14 : 16),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(dense ? 18 : 20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          SizedBox(height: dense ? 12 : 14),
          ...children,
        ],
      ),
    );
  }

  Widget _fieldGrid({required bool isDesktop, required List<Widget> children}) {
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

  Widget _fullWidthField({required bool isDesktop, required Widget child}) {
    if (!isDesktop) {
      return child;
    }

    return SizedBox(width: double.infinity, child: child);
  }

  List<DropdownMenuItem<String>> _categoryItems() {
    return [
      ...GlassApparatusModel.categories.map((category) {
        return DropdownMenuItem<String>(value: category, child: Text(category));
      }),
      const DropdownMenuItem<String>(
        value: _customCategoryOption,
        child: Text(_customCategoryOption),
      ),
    ];
  }

  Widget _buildCategoryDropdown() {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      dropdownColor: palette.panel,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: _inputDecoration('Category'),
      items: _categoryItems(),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Select category';
        }
        return null;
      },
      onChanged: _isSaving
          ? null
          : (value) {
              if (value == null) return;
              setState(() {
                _selectedCategory = value;
              });
            },
    );
  }

  Widget _buildCustomCategoryField() {
    final colorScheme = context.colorScheme;
    return TextFormField(
      controller: _customCategoryController,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: _inputDecoration('Custom category'),
      textCapitalization: TextCapitalization.words,
      validator: (value) {
        if (!_isCustomCategorySelected) {
          return null;
        }

        if (value == null || value.trim().isEmpty) {
          return 'Enter custom category';
        }

        return null;
      },
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

    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity < 0) {
      _showMessage('Enter a valid quantity.');
      return;
    }

    final category = _resolvedCategory;
    if (category.isEmpty) {
      _showMessage('Enter a category.');
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
        category: category,
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
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Glass Apparatus' : 'Add Glass Apparatus',
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
                              style: TextStyle(color: colorScheme.onSurface),
                              decoration: _inputDecoration('Name'),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter apparatus name';
                                }
                                return null;
                              },
                            ),
                            _buildCategoryDropdown(),
                            if (_isCustomCategorySelected)
                              _buildCustomCategoryField(),
                            TextFormField(
                              controller: _sizeController,
                              style: TextStyle(color: colorScheme.onSurface),
                              decoration: _inputDecoration('Size / capacity'),
                            ),
                            TextFormField(
                              controller: _quantityController,
                              style: TextStyle(color: colorScheme.onSurface),
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('Quantity'),
                              validator: (value) {
                                final quantity = int.tryParse(
                                  (value ?? '').trim(),
                                );
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
                              dropdownColor: palette.panel,
                              style: TextStyle(color: colorScheme.onSurface),
                              decoration: _inputDecoration('Condition'),
                              items: GlassApparatusModel.conditionOptions.map((
                                status,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
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
                              style: TextStyle(color: colorScheme.onSurface),
                              decoration: _inputDecoration('Location'),
                            ),
                            TextFormField(
                              controller: _inchargeController,
                              style: TextStyle(color: colorScheme.onSurface),
                              decoration: _inputDecoration('In-charge'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _fullWidthField(
                          isDesktop: isDesktop,
                          child: TextFormField(
                            controller: _notesController,
                            style: TextStyle(color: colorScheme.onSurface),
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
