import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../app_state.dart';
import '../services/activity_service.dart';
import '../services/requirement_service.dart';
import '../models/requirement_model.dart';
import '../theme/labmate_theme.dart';

class AddRequirementScreen extends StatefulWidget {
  const AddRequirementScreen({super.key});

  @override
  State<AddRequirementScreen> createState() => _AddRequirementScreenState();
}

class _AddRequirementScreenState extends State<AddRequirementScreen> {
  static const String _customOption = 'Add custom...';

  final _formKey = GlobalKey<FormState>();
  final RequirementService _requirementService = RequirementService();

  // Common controllers
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController estimatedCostController = TextEditingController();

  // Chemical controllers
  final TextEditingController chemicalNameController = TextEditingController();
  final TextEditingController casController = TextEditingController();
  final TextEditingController catalogNoController = TextEditingController();
  final TextEditingController manualConsumableVariantController =
      TextEditingController();
  final TextEditingController manualConsumableNameController =
      TextEditingController();

  // Custom manual entry controllers
  final TextEditingController customBrandController = TextEditingController();
  final TextEditingController customVendorController = TextEditingController();
  final TextEditingController customModeOfPurchaseController =
      TextEditingController();
  final TextEditingController customChemicalTypeController =
      TextEditingController();
  final TextEditingController customConsumableCategoryController =
      TextEditingController();
  final TextEditingController customPackSizeController =
      TextEditingController();

  // Dropdown values
  String selectedMainType = 'chemical';
  String? selectedBrand;
  String? selectedVendor;
  String? selectedChemicalType;
  String? selectedConsumableCategory;
  String? selectedConsumableVariant;
  String? selectedConsumableType;
  String? selectedModeOfPurchase;
  String? selectedQuantity;
  String? selectedPackSize;

  bool isFetchingChemicalName = false;

  final List<String> brands = const [
    'Merck',
    'Sigma',
    'TCI',
    'Spectrochem',
    'Hyma (Avra)',
    'BLD Pharm',
    'ChemScene',
    'SRL',
    'Others',
  ];

  final List<String> vendors = const [
    'Merck',
    'Sigma',
    'Globe Scientific',
    'APJ Scientific',
    'Chemical House',
    'BLD Pharm',
    'Others',
  ];

  final List<String> quantities = const ['1', '2', '3', '4', '5', '10'];

  final List<String> packSizes = const [
    '100 mg',
    '250 mg',
    '500 mg',
    '1 g',
    '5 g',
    '25 g',
    '100 g',
    '250 g',
    '500 g',
    '1 L',
    '2.5 L',
    '5 L',
  ];

  final List<String> chemicalTypes = const [
    'Common Reagent',
    'Catalyst',
    'Ligand',
    'Gas',
    'D-Solvent',
    'Dry Solvent',
    'Solvent',
    'Bulk Solvent',
  ];

  final List<String> consumableCategories = const [
    'Gloves',
    'Syringes',
    'Balloon',
    'Needle',
    'Filter Paper',
    'Silica',
    'TLC Plates',
    'Cotton',
    'Rubber Band',
    'Tubes',
    'Joint Clips',
    'Grease',
    'Teflon',
    'Reflux Pumps',
    'Column Pumps',
    'Others',
  ];

  final Map<String, List<String>> consumableVariantsByCategory = const {
    'Gloves': ['Small', 'Medium', 'Large'],
    'Syringes': ['1 mL', '2 mL', '5 mL', '10 mL', '20 mL', '50 mL'],
    'Silica': ['100-200 mesh', '230-400 mesh'],
    'TLC Plates': ['Normal TLC Plate', 'Preparative TLC Plate'],
    'Joint Clips': ['14', '19', '24'],
  };

  final List<String> purchaseModes = const ['indent', 'direct'];

  List<String> customBrandOptions = const [];
  List<String> customVendorOptions = const [];
  List<String> customChemicalTypeOptions = const [];
  List<String> customConsumableCategoryOptions = const [];
  List<String> customModeOfPurchaseOptions = const [];
  List<String> customPackSizeOptions = const [];
  List<String> customQuantityOptions = const [];

  static const Map<String, List<String>> _categoryAliases = {
    'Gloves': ['glove', 'gloves'],
    'Syringes': ['syringe', 'syringes'],
    'Balloon': ['balloon', 'balloons'],
    'Needle': ['needle', 'needles'],
    'Filter Paper': ['filter paper'],
    'Silica': ['silica'],
    'TLC Plates': [
      'tlc',
      'tlc plate',
      'tlc plates',
      'normal tlc plate',
      'preparative tlc plate',
    ],
    'Cotton': ['cotton'],
    'Rubber Band': ['rubber band', 'rubber bands'],
    'Tubes': ['tube', 'tubes'],
    'Joint Clips': ['clip', 'clips', 'joint clip', 'joint clips'],
    'Grease': ['grease'],
    'Teflon': ['teflon'],
    'Reflux Pumps': ['reflux pump', 'reflux pumps'],
    'Column Pumps': ['column pump', 'column pumps'],
    'Others': ['other', 'others'],
  };

  @override
  void initState() {
    super.initState();
    _loadExistingDropdownOptions();
  }

  double get totalPrice {
    final estimate = double.tryParse(estimatedCostController.text.trim()) ?? 0;
    final qty = double.tryParse(_resolvedQuantity) ?? 0;
    return estimate * qty;
  }

  bool get hasFixedConsumableVariants {
    final category = _resolvedConsumableCategory;
    return consumableVariantsByCategory.containsKey(category);
  }

  bool get isOtherConsumableCategory {
    return (selectedConsumableCategory ?? '').trim() == 'Others';
  }

  bool get isCustomConsumableCategory {
    return selectedConsumableCategory == _customOption;
  }

  bool get isCustomBrandSelection => _isCustomSelection(selectedBrand);

  bool get isCustomVendorSelection => _isCustomSelection(selectedVendor);

  bool get isCustomChemicalTypeSelection {
    return selectedChemicalType == _customOption;
  }

  bool get isCustomModeOfPurchaseSelection {
    return selectedModeOfPurchase == _customOption;
  }

  bool get isCustomPackSizeSelection {
    return selectedPackSize == _customOption;
  }

  bool get isCustomQuantitySelection {
    return selectedQuantity == _customOption;
  }

  bool get shouldShowManualConsumableVariantField {
    final category = _resolvedConsumableCategory;
    return category.isNotEmpty &&
        !hasFixedConsumableVariants &&
        !isOtherConsumableCategory;
  }

  List<String> get currentConsumableVariants {
    final category = _resolvedConsumableCategory;
    return consumableVariantsByCategory[category] ?? const [];
  }

  bool _isCustomSelection(String? value) {
    return value == _customOption || value == 'Others';
  }

  String _resolvedDropdownValue(
    String? selectedValue,
    TextEditingController customController,
  ) {
    if (_isCustomSelection(selectedValue)) {
      return customController.text.trim();
    }
    return selectedValue?.trim() ?? '';
  }

  String get _resolvedBrand {
    return _resolvedDropdownValue(selectedBrand, customBrandController);
  }

  String get _resolvedVendor {
    return _resolvedDropdownValue(selectedVendor, customVendorController);
  }

  String get _resolvedChemicalType {
    return _resolvedDropdownValue(
      selectedChemicalType,
      customChemicalTypeController,
    );
  }

  String get _resolvedModeOfPurchase {
    return _resolvedDropdownValue(
      selectedModeOfPurchase,
      customModeOfPurchaseController,
    );
  }

  String get _resolvedPackSize {
    return _resolvedDropdownValue(selectedPackSize, customPackSizeController);
  }

  String get _resolvedQuantity {
    return _resolvedDropdownValue(selectedQuantity, quantityController);
  }

  String get _resolvedConsumableCategory {
    if (isCustomConsumableCategory) {
      return customConsumableCategoryController.text.trim();
    }
    return selectedConsumableCategory?.trim() ?? '';
  }

  String _buildConsumableTypeValue() {
    final category = _resolvedConsumableCategory;
    final variant = selectedConsumableVariant?.trim() ?? '';
    final manualVariant = manualConsumableVariantController.text.trim();
    final manualName = manualConsumableNameController.text.trim();

    if (category.isEmpty) {
      return '';
    }

    if (category == 'Others') {
      return manualName;
    }

    if (category == 'Gloves') {
      return variant.isEmpty ? '' : 'Gloves - $variant';
    }

    if (category == 'Syringes') {
      return variant.isEmpty ? '' : 'Syringe - $variant';
    }

    if (category == 'Silica') {
      return variant.isEmpty ? '' : 'Silica - $variant';
    }

    if (category == 'TLC Plates') {
      if (variant == 'Normal TLC Plate') {
        return 'TLC Plate';
      }
      if (variant == 'Preparative TLC Plate') {
        return 'Preparative TLC Plate';
      }
      return '';
    }

    if (category == 'Joint Clips') {
      return variant.isEmpty ? '' : 'Clips - $variant';
    }

    if (manualVariant.isNotEmpty) {
      return '$category - $manualVariant';
    }

    return category;
  }

  void _refreshConsumableTypePreview() {
    final value = _buildConsumableTypeValue();
    selectedConsumableType = value.isEmpty ? null : value;
  }

  void _resetConsumableSelection() {
    selectedConsumableCategory = null;
    selectedConsumableVariant = null;
    selectedConsumableType = null;
    customConsumableCategoryController.clear();
    manualConsumableVariantController.clear();
    manualConsumableNameController.clear();
  }

  InputDecoration inputDecoration(String label, {Widget? suffixIcon}) {
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
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return DropdownButtonFormField<String>(
      key: ValueKey('dropdown_$label|${value ?? ''}|${items.join('|')}'),
      initialValue: value,
      dropdownColor: palette.panel,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: inputDecoration(label),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: TextStyle(color: colorScheme.onSurface)),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          onChanged(value);
        });
      },
      validator:
          validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return 'Required';
            }
            return null;
          },
    );
  }

  bool _matchesAnyOption(String value, Iterable<String> options) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return options.any((option) => option.trim().toLowerCase() == normalized);
  }

  List<String> _distinctCustomValues(
    Iterable<String> values,
    Iterable<String> baseValues,
  ) {
    final baseNormalized = baseValues
        .map((value) => value.trim().toLowerCase())
        .toSet();
    final uniqueValues = <String, String>{};

    for (final value in values) {
      final trimmed = value.trim();
      final normalized = trimmed.toLowerCase();
      if (trimmed.isEmpty ||
          trimmed == _customOption ||
          baseNormalized.contains(normalized)) {
        continue;
      }
      uniqueValues.putIfAbsent(normalized, () => trimmed);
    }

    final items = uniqueValues.values.toList();
    items.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return items;
  }

  List<String> _mergedOptions(
    List<String> builtInOptions,
    List<String> customOptions,
  ) {
    final custom = _distinctCustomValues(customOptions, builtInOptions);
    return [...builtInOptions, ...custom, _customOption];
  }

  List<DropdownMenuItem<String>> _dropdownItems(List<String> options) {
    final colorScheme = context.colorScheme;
    return options
        .map(
          (item) => DropdownMenuItem<String>(
            value: item,
            child: Text(item, style: TextStyle(color: colorScheme.onSurface)),
          ),
        )
        .toList();
  }

  Widget buildCustomizableDropdown({
    required String label,
    required String? value,
    required List<String> builtInOptions,
    required List<String> customOptions,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final options = _mergedOptions(builtInOptions, customOptions);
    final safeValue = options.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      key: ValueKey('${label}_${safeValue ?? ''}_${customOptions.join('|')}'),
      initialValue: safeValue,
      dropdownColor: palette.panel,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: inputDecoration(label),
      items: _dropdownItems(options),
      onChanged: (value) {
        setState(() {
          onChanged(value);
        });
      },
      validator:
          validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return 'Required';
            }
            return null;
          },
    );
  }

  Widget buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required String errorText,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.words,
  }) {
    final colorScheme = context.colorScheme;
    return TextFormField(
      controller: controller,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: inputDecoration(label),
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return errorText;
        }
        return null;
      },
      onChanged: (_) {
        if (controller == customConsumableCategoryController) {
          setState(() {
            _refreshConsumableTypePreview();
          });
        } else if (controller == quantityController) {
          setState(() {});
        }
      },
    );
  }

  String? _matchingConsumableCategory(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    for (final entry in _categoryAliases.entries) {
      if (entry.value.any(
        (alias) => normalized == alias || normalized.startsWith('$alias '),
      )) {
        return entry.key;
      }
    }

    return null;
  }

  String _categoryFromConsumableType(String value) {
    final cleanValue = value.trim();
    if (cleanValue.isEmpty) return '';

    final parts = cleanValue.split(RegExp(r'\s*-\s*'));
    final possibleCategory = parts.first.trim();
    final knownCategory = _matchingConsumableCategory(possibleCategory);
    final category = knownCategory ?? possibleCategory;

    if (category.isEmpty ||
        category == 'Others' ||
        _matchesAnyOption(category, consumableCategories)) {
      return '';
    }

    return category;
  }

  Future<void> _loadExistingDropdownOptions() async {
    try {
      final docs = await _requirementService.getRequirementDocsOnce();
      if (!mounted) return;

      setState(() {
        customBrandOptions = _distinctCustomValues(
          docs.map((doc) => (doc.data()['brand'] ?? '').toString()),
          brands,
        );
        customVendorOptions = _distinctCustomValues(
          docs.map((doc) => (doc.data()['vendor'] ?? '').toString()),
          vendors,
        );
        customChemicalTypeOptions = _distinctCustomValues(
          docs.map((doc) => (doc.data()['chemicalType'] ?? '').toString()),
          chemicalTypes,
        );
        customConsumableCategoryOptions = _distinctCustomValues(
          docs.map((doc) {
            final data = doc.data();
            return _categoryFromConsumableType(
              (data['consumableType'] ?? '').toString(),
            );
          }),
          consumableCategories,
        );
        customModeOfPurchaseOptions = _distinctCustomValues(
          docs.map((doc) => (doc.data()['modeOfPurchase'] ?? '').toString()),
          purchaseModes,
        );
        customPackSizeOptions = _distinctCustomValues(
          docs.map((doc) => (doc.data()['packSize'] ?? '').toString()),
          packSizes,
        );
        customQuantityOptions = _distinctCustomValues(
          docs.map((doc) => (doc.data()['quantity'] ?? '').toString()),
          quantities,
        );
      });
    } catch (_) {
      // Built-in values remain available if historical requirement options fail.
    }
  }

  bool _matchesCurrentLab(Map<String, dynamic> data) {
    final labId = (data['labId'] ?? '').toString().trim();
    return AppState.instance.matchesSelectedLabId(labId);
  }

  Future<bool> fetchFromInventoryByCas() async {
    final cas = casController.text.trim();

    if (cas.isEmpty || cas.toUpperCase() == 'NA') {
      return false;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('inventory')
          .where('cas', isEqualTo: cas)
          .get();

      if (snapshot.docs.isEmpty) {
        return false;
      }

      final docs = snapshot.docs
          .where((doc) => _matchesCurrentLab(doc.data()))
          .toList();

      if (docs.isEmpty) {
        return false;
      }

      docs.sort((a, b) {
        final aTime = a.data()['createdAt'];
        final bTime = b.data()['createdAt'];

        if (aTime is Timestamp && bTime is Timestamp) {
          return bTime.compareTo(aTime);
        }
        return 0;
      });

      final data = docs.first.data();

      final fetchedChemicalName = (data['chemicalName'] ?? '')
          .toString()
          .trim();
      final fetchedCatNumber = (data['catNumber'] ?? '').toString().trim();
      final fetchedPackSize = (data['packSize'] ?? '').toString().trim();
      final fetchedBrand = (data['brand'] ?? '').toString().trim();

      setState(() {
        if (fetchedChemicalName.isNotEmpty) {
          chemicalNameController.text = fetchedChemicalName;
        }

        if (fetchedCatNumber.isNotEmpty) {
          catalogNoController.text = fetchedCatNumber;
        }

        if (fetchedPackSize.isNotEmpty) {
          final matchedPackSize = packSizes.where(
            (packSize) =>
                packSize.trim().toLowerCase() == fetchedPackSize.toLowerCase(),
          );
          if (matchedPackSize.isNotEmpty) {
            selectedPackSize = matchedPackSize.first;
            customPackSizeController.clear();
          } else {
            selectedPackSize = _customOption;
            customPackSizeController.text = fetchedPackSize;
          }
        }

        if (fetchedBrand.isNotEmpty) {
          final matchedBrand = brands.where(
            (brand) => brand.trim().toLowerCase() == fetchedBrand.toLowerCase(),
          );
          if (matchedBrand.isNotEmpty) {
            selectedBrand = matchedBrand.first;
            customBrandController.clear();
          } else {
            selectedBrand = _customOption;
            customBrandController.text = fetchedBrand;
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chemical details loaded from inventory'),
          ),
        );
      }

      return true;
    } catch (e) {
      debugPrint('Inventory lookup error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inventory lookup failed')),
        );
      }

      return false;
    }
  }

  Future<void> fetchFromPubChemByCas() async {
    final cas = casController.text.trim();

    if (cas.isEmpty || cas.toUpperCase() == 'NA') return;

    try {
      final url = Uri.parse(
        'https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/$cas/property/Title/JSON',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final properties = data['PropertyTable']?['Properties'];
        if (properties != null &&
            properties is List &&
            properties.isNotEmpty &&
            properties[0]['Title'] != null) {
          final fetchedName = properties[0]['Title'].toString().trim();

          if (fetchedName.isNotEmpty &&
              chemicalNameController.text.trim().isEmpty) {
            setState(() {
              chemicalNameController.text = fetchedName;
            });
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chemical name fetched from PubChem'),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chemical not found in PubChem. Enter manually.'),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chemical not found in PubChem. Enter manually.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('PubChem fetch error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PubChem fetch failed. Enter manually.'),
          ),
        );
      }
    }
  }

  Future<void> fetchChemicalDetailsSmart() async {
    final cas = casController.text.trim();

    if (cas.isEmpty || cas.toUpperCase() == 'NA') return;

    setState(() {
      isFetchingChemicalName = true;
    });

    try {
      final foundInInventory = await fetchFromInventoryByCas();

      if (!foundInInventory) {
        await fetchFromPubChemByCas();
      }
    } finally {
      if (mounted) {
        setState(() {
          isFetchingChemicalName = false;
        });
      }
    }
  }

  Future<void> submitRequirement() async {
    if (!_formKey.currentState!.validate()) return;

    final service = RequirementService();
    final consumableTypeValue = selectedMainType == 'consumable'
        ? _buildConsumableTypeValue()
        : '';

    if (selectedMainType == 'consumable' && consumableTypeValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a valid consumable category and variant'),
        ),
      );
      return;
    }

    final req = RequirementModel(
      id: '',
      labId: AppState.instance.resolveWriteLabId(),
      mainType: selectedMainType,
      brand: _resolvedBrand,
      vendor: _resolvedVendor,
      quantity: _resolvedQuantity,
      estimatedCost: estimatedCostController.text.trim(),
      estimatedTotal: totalPrice.toStringAsFixed(2),
      modeOfPurchase: _resolvedModeOfPurchase,
      packSize: selectedMainType == 'chemical' ? _resolvedPackSize : '',
      chemicalName: selectedMainType == 'chemical'
          ? chemicalNameController.text.trim()
          : '',
      cas: selectedMainType == 'chemical' ? casController.text.trim() : '',
      catalogNo: selectedMainType == 'chemical'
          ? catalogNoController.text.trim()
          : '',
      chemicalType: selectedMainType == 'chemical' ? _resolvedChemicalType : '',
      consumableType: selectedMainType == 'consumable'
          ? consumableTypeValue
          : '',
      status: 'pending',
      userName: AppState.instance.authenticatedUserName,
      createdAt: Timestamp.now(),
      approvedBy: '',
      approvedAt: null,
    );

    final requirementId = await service.addRequirement(req);
    await ActivityService().addActivity(
      labId: req.labId,
      type: 'requirement_created',
      message:
          'Requirement submitted for ${req.mainType == 'consumable' ? req.consumableType : req.chemicalName}',
      actorName: AppState.instance.authenticatedUserName,
      createdBy: AppState.instance.authenticatedUserId,
      relatedId: requirementId,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Requirement submitted')));

    Navigator.pop(context);
  }

  @override
  void dispose() {
    quantityController.dispose();
    estimatedCostController.dispose();
    chemicalNameController.dispose();
    casController.dispose();
    catalogNoController.dispose();
    manualConsumableVariantController.dispose();
    manualConsumableNameController.dispose();
    customBrandController.dispose();
    customVendorController.dispose();
    customModeOfPurchaseController.dispose();
    customChemicalTypeController.dispose();
    customConsumableCategoryController.dispose();
    customPackSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = totalPrice;
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Requirement')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              buildDropdown(
                label: 'Requirement Type',
                value: selectedMainType,
                items: const ['chemical', 'consumable'],
                onChanged: (value) {
                  selectedMainType = value ?? 'chemical';
                  if (selectedMainType != 'consumable') {
                    _resetConsumableSelection();
                  } else {
                    _refreshConsumableTypePreview();
                  }
                },
              ),
              const SizedBox(height: 14),

              if (selectedMainType == 'chemical') ...[
                TextFormField(
                  controller: casController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: inputDecoration(
                    'CAS No',
                    suffixIcon: IconButton(
                      onPressed: isFetchingChemicalName
                          ? null
                          : fetchChemicalDetailsSmart,
                      icon: isFetchingChemicalName
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.search, color: palette.mutedText),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter CAS No or NA';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: chemicalNameController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: inputDecoration(
                    'Chemical Name (auto from inventory/PubChem or enter manually)',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter chemical name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: catalogNoController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: inputDecoration('Catalog No'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter catalog number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                buildCustomizableDropdown(
                  label: 'Pack Size',
                  value: selectedPackSize,
                  builtInOptions: packSizes,
                  customOptions: customPackSizeOptions,
                  onChanged: (value) => selectedPackSize = value,
                  validator: (value) {
                    if (selectedMainType == 'chemical' &&
                        (value == null || value.isEmpty)) {
                      return 'Select pack size';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                if (isCustomPackSizeSelection) ...[
                  buildCustomTextField(
                    controller: customPackSizeController,
                    label: 'Custom pack size',
                    errorText: 'Enter pack size',
                    textCapitalization: TextCapitalization.none,
                  ),
                  const SizedBox(height: 14),
                ],
                buildCustomizableDropdown(
                  label: 'Type of Chemical',
                  value: selectedChemicalType,
                  builtInOptions: chemicalTypes,
                  customOptions: customChemicalTypeOptions,
                  onChanged: (value) {
                    selectedChemicalType = value;
                  },
                ),
                const SizedBox(height: 14),
                if (isCustomChemicalTypeSelection) ...[
                  buildCustomTextField(
                    controller: customChemicalTypeController,
                    label: 'Custom chemical type',
                    errorText: 'Enter custom chemical type',
                  ),
                  const SizedBox(height: 14),
                ],
              ],

              if (selectedMainType == 'consumable') ...[
                buildCustomizableDropdown(
                  label: 'Consumable Category',
                  value: selectedConsumableCategory,
                  builtInOptions: consumableCategories,
                  customOptions: customConsumableCategoryOptions,
                  onChanged: (value) {
                    selectedConsumableCategory = value;
                    selectedConsumableVariant = null;
                    manualConsumableVariantController.clear();
                    manualConsumableNameController.clear();
                    _refreshConsumableTypePreview();
                  },
                  validator: (value) {
                    if (selectedMainType == 'consumable' &&
                        (value == null || value.isEmpty)) {
                      return 'Select consumable category';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                if (isCustomConsumableCategory) ...[
                  buildCustomTextField(
                    controller: customConsumableCategoryController,
                    label: 'Custom consumable category',
                    errorText: 'Enter custom consumable category',
                  ),
                  const SizedBox(height: 14),
                ],
                if (hasFixedConsumableVariants) ...[
                  buildDropdown(
                    label: 'Consumable Subcategory / Variant',
                    value: selectedConsumableVariant,
                    items: currentConsumableVariants,
                    onChanged: (value) {
                      selectedConsumableVariant = value;
                      _refreshConsumableTypePreview();
                    },
                    validator: (value) {
                      if (selectedMainType == 'consumable' &&
                          hasFixedConsumableVariants &&
                          (value == null || value.isEmpty)) {
                        return 'Select subcategory / variant';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                if (shouldShowManualConsumableVariantField) ...[
                  TextFormField(
                    controller: manualConsumableVariantController,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: inputDecoration(
                      'Consumable Subcategory / Variant (optional)',
                    ),
                    onChanged: (_) {
                      setState(() {
                        _refreshConsumableTypePreview();
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                if (isOtherConsumableCategory) ...[
                  TextFormField(
                    controller: manualConsumableNameController,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: inputDecoration(
                      'Consumable Item Name / Variant',
                    ),
                    onChanged: (_) {
                      setState(() {
                        _refreshConsumableTypePreview();
                      });
                    },
                    validator: (value) {
                      if (selectedMainType == 'consumable' &&
                          isOtherConsumableCategory &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Enter consumable item name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                if ((selectedConsumableType ?? '').trim().isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.panel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          color: Color(0xFF14B8A6),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Will save as: ${selectedConsumableType!}',
                            style: TextStyle(
                              color: palette.mutedText,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ],

              buildCustomizableDropdown(
                label: 'Brand',
                value: selectedBrand,
                builtInOptions: brands,
                customOptions: customBrandOptions,
                onChanged: (value) => selectedBrand = value,
              ),
              if (isCustomBrandSelection) ...[
                const SizedBox(height: 14),
                buildCustomTextField(
                  controller: customBrandController,
                  label: 'Custom brand',
                  errorText: 'Enter brand name',
                ),
              ],
              const SizedBox(height: 14),
              buildCustomizableDropdown(
                label: 'Vendor Name',
                value: selectedVendor,
                builtInOptions: vendors,
                customOptions: customVendorOptions,
                onChanged: (value) => selectedVendor = value,
              ),
              if (isCustomVendorSelection) ...[
                const SizedBox(height: 14),
                buildCustomTextField(
                  controller: customVendorController,
                  label: 'Custom vendor',
                  errorText: 'Enter vendor name',
                ),
              ],
              const SizedBox(height: 14),
              buildCustomizableDropdown(
                label: 'Quantity',
                value: selectedQuantity,
                builtInOptions: quantities,
                customOptions: customQuantityOptions,
                onChanged: (value) => selectedQuantity = value,
              ),
              const SizedBox(height: 14),
              if (isCustomQuantitySelection) ...[
                buildCustomTextField(
                  controller: quantityController,
                  label: 'Custom quantity',
                  errorText: 'Enter quantity',
                  keyboardType: TextInputType.number,
                  textCapitalization: TextCapitalization.none,
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: estimatedCostController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: inputDecoration('Estimated Cost'),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter estimated cost';
                  }
                  if (double.tryParse(value.trim()) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              buildCustomizableDropdown(
                label: 'Mode of Purchase',
                value: selectedModeOfPurchase,
                builtInOptions: purchaseModes,
                customOptions: customModeOfPurchaseOptions,
                onChanged: (value) => selectedModeOfPurchase = value,
              ),
              if (isCustomModeOfPurchaseSelection) ...[
                const SizedBox(height: 14),
                buildCustomTextField(
                  controller: customModeOfPurchaseController,
                  label: 'Custom mode of purchase',
                  errorText: 'Enter mode of purchase',
                ),
              ],
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calculated Summary',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Estimated Total: ₹${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF14B8A6),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Approval and fund allocation will be handled later by PI.',
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: submitRequirement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Submit Requirement',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
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
