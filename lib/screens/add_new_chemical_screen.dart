import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_state.dart';
import '../models/chemical_model.dart';
import '../models/order_model.dart';
import '../services/activity_service.dart';
import '../services/inventory_service.dart';
import '../services/order_service.dart';
import '../services/pubchem_service.dart';
import '../services/chemical_label_service.dart';
import '../theme/labmate_theme.dart';

class AddNewChemicalScreen extends StatefulWidget {
  final OrderModel? order;
  final ChemicalModel? manualPrefill;
  final ChemicalModel? editChemical;

  const AddNewChemicalScreen({
    super.key,
    this.order,
    this.manualPrefill,
    this.editChemical,
  });

  @override
  State<AddNewChemicalScreen> createState() => _AddNewChemicalScreenState();
}

class _AddNewChemicalScreenState extends State<AddNewChemicalScreen> {
  static const String _customOption = 'Add custom...';

  final _formKey = GlobalKey<FormState>();
  final InventoryService inventoryService = InventoryService();
  final OrderService orderService = OrderService();
  final PubChemService pubChemService = PubChemService();
  final ChemicalLabelService chemicalLabelService = ChemicalLabelService();

  late final TextEditingController chemicalNameController;
  late final TextEditingController casController;
  late final TextEditingController brandController;
  late final TextEditingController quantityController;
  late final TextEditingController formulaController;
  late final TextEditingController molWtController;
  late final TextEditingController vendorController;
  late final TextEditingController catNumberController;
  late final TextEditingController arrivalDateController;
  late final TextEditingController orderedByController;
  late final TextEditingController labelController;
  late final TextEditingController sheetTabController;
  late final TextEditingController carbonCountController;
  late final TextEditingController catalystMetalController;
  late final TextEditingController customLocationController;
  late final TextEditingController customCategoryController;

  String? selectedEntryType;
  bool isLoadingMetadata = true;
  bool isGeneratingLabel = false;
  bool isFetchingCas = false;

  String selectedCategory = 'General';
  String? selectedSubcategory;
  String? selectedBrand;
  String? selectedVendor;

  String? selectedLocation;
  String? selectedTexture;
  List<String> selectedFunctionalGroups = [];

  int existingBottleCount = 0;

  final List<String> brandOptions = const [
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

  final List<String> vendorOptions = const [
    'Merck',
    'Sigma',
    'Globe Scientific',
    'APJ Scientific',
    'Chemical House',
    'BLD Pharm',
    'Others',
  ];

  List<String> customBrandOptions = const [];
  List<String> customVendorOptions = const [];
  List<String> customLocationOptions = const [];
  List<String> customCategoryOptions = const [];
  Set<String> hiddenChemicalBrandOptions = const {};
  Set<String> hiddenChemicalLocationOptions = const {};

  final List<String> categories = [
    'General',
    'Acid',
    'Base',
    'Salt',
    'Metal',
    'Catalyst',
    'Ligand',
  ];

  final List<String> locationOptions = const [
    'Yellow Cab',
    'Acid Cabinet',
    'Base Cabinet',
    'Solvent Rack',
    'Dry Solvent Rack',
    'Deuterated Solvent Rack',
    'Refrigerator',
    'Freezer 1A',
    'Freezer 1B',
    'Freezer 1C',
    'Freezer 1D',
    'Freezer 1E',
    'Desiccator',
    'Glovebox',
    'Drawer 1',
    'Drawer 2',
    'Drawer 3',
    'Other',
  ];

  final List<String> textureOptions = const [
    'Solid',
    'Liquid',
    'Oil',
    'Powder',
    'Crystals',
    'Solution',
    'Suspension',
    'Gas',
    'Paste',
    'Other',
  ];

  final List<String> functionalGroupOptions = const [
    'Alcohol',
    'Aldehyde',
    'Ketone',
    'Ester',
    'Amide',
    'Amine',
    'Carboxylic Acid',
    'Halide',
    'Nitrile',
    'Nitro',
    'Ether',
    'Thioether',
    'Phosphine',
    'Pyridine',
    'Imine',
    'Alkene',
    'Alkyne',
    'Arene',
    'Heteroarene',
    'Boronic Acid',
    'Sulfonamide',
    'Peroxide',
    'Carbonate',
    'Hydride',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    final order = widget.order;
    final manualPrefill = widget.editChemical ?? widget.manualPrefill;
    final deliveredDate = order?.deliveredAt?.toDate();

    chemicalNameController = TextEditingController(
      text: manualPrefill?.chemicalName ?? order?.chemicalName ?? '',
    );
    casController = TextEditingController(
      text: manualPrefill?.cas ?? order?.cas ?? '',
    );
    brandController = TextEditingController(
      text: manualPrefill?.brand ?? order?.brand ?? '',
    );
    quantityController = TextEditingController(
      text: manualPrefill?.quantity ?? order?.quantity ?? '',
    );
    formulaController = TextEditingController(
      text: manualPrefill?.formula ?? '',
    );
    molWtController = TextEditingController(text: manualPrefill?.molWt ?? '');
    vendorController = TextEditingController();
    catNumberController = TextEditingController(
      text: manualPrefill?.catNumber ?? '',
    );
    arrivalDateController = TextEditingController(
      text:
          manualPrefill?.arrivalDate ??
          (deliveredDate == null
              ? ''
              : '${deliveredDate.day.toString().padLeft(2, '0')}/${deliveredDate.month.toString().padLeft(2, '0')}/${deliveredDate.year}'),
    );
    orderedByController = TextEditingController(
      text: manualPrefill?.orderedBy ?? order?.orderedBy ?? '',
    );
    labelController = TextEditingController(text: manualPrefill?.label ?? '');
    sheetTabController = TextEditingController(
      text: manualPrefill?.sheetTab ?? '',
    );
    carbonCountController = TextEditingController();
    catalystMetalController = TextEditingController();
    customLocationController = TextEditingController();
    customCategoryController = TextEditingController();

    _setDropdownSelection(
      value: manualPrefill?.brand ?? order?.brand ?? '',
      builtInOptions: brandOptions,
      onKnownValue: (value) => selectedBrand = value,
      onCustomValue: (value) {
        selectedBrand = _customOption;
        brandController.text = value;
      },
    );

    _setDropdownSelection(
      value: manualPrefill?.vendor ?? order?.vendor ?? '',
      builtInOptions: vendorOptions,
      onKnownValue: (value) => selectedVendor = value,
      onCustomValue: (value) {
        selectedVendor = _customOption;
        vendorController.text = value;
      },
    );

    _setDropdownSelection(
      value: manualPrefill?.location ?? '',
      builtInOptions: locationOptions,
      onKnownValue: (value) => selectedLocation = value,
      onCustomValue: (value) {
        selectedLocation = _customOption;
        customLocationController.text = value;
      },
    );

    _setInitialCategoryFromPrefill(manualPrefill?.sheetTab ?? '');

    selectedTexture = textureOptions.contains(manualPrefill?.texture)
        ? manualPrefill!.texture
        : null;
    if ((manualPrefill?.functionalGroups ?? '').trim().isNotEmpty) {
      selectedFunctionalGroups = manualPrefill!.functionalGroups
          .split(',')
          .map((e) => e.trim())
          .where((e) => functionalGroupOptions.contains(e))
          .toList();
    }

    _loadHiddenDropdownOptionPreferences();
    _loadExistingDropdownOptions();
    if (widget.editChemical != null) {
      selectedEntryType = 'Edit Chemical';
      isLoadingMetadata = false;
    } else {
      _prefillFromCas();
    }
  }

  bool _matchesAnyOption(String value, Iterable<String> options) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return options.any((option) => option.trim().toLowerCase() == normalized);
  }

  String _normalizedOption(String value) {
    return value.trim().toLowerCase();
  }

  bool _optionSetsContain(Iterable<String> options, String value) {
    final normalized = _normalizedOption(value);
    if (normalized.isEmpty) return false;
    return options.any((option) => _normalizedOption(option) == normalized);
  }

  String get _optionPreferenceLabId {
    final labId = AppState.instance.resolveWriteLabId().trim();
    return labId.isEmpty ? 'no_lab_selected' : labId;
  }

  String get _hiddenBrandOptionsKey {
    return 'hiddenChemicalBrandOptions_$_optionPreferenceLabId';
  }

  String get _hiddenLocationOptionsKey {
    return 'hiddenChemicalLocationOptions_$_optionPreferenceLabId';
  }

  void _setDropdownSelection({
    required String value,
    required List<String> builtInOptions,
    required ValueChanged<String?> onKnownValue,
    required ValueChanged<String> onCustomValue,
  }) {
    final cleanValue = value.trim();
    if (cleanValue.isEmpty) {
      onKnownValue(null);
      return;
    }

    final knownOption = builtInOptions.where(
      (option) => option.trim().toLowerCase() == cleanValue.toLowerCase(),
    );
    if (knownOption.isNotEmpty) {
      onKnownValue(knownOption.first);
      return;
    }

    onCustomValue(cleanValue);
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

  List<String> _baseManageableOptions(
    List<String> builtInOptions,
    List<String> customOptions,
  ) {
    return _mergedOptions(
      builtInOptions,
      customOptions,
    ).where((option) => option != _customOption).toList();
  }

  List<String> _filterHiddenOptions({
    required List<String> options,
    required Set<String> hiddenOptions,
    String? selectedValue,
  }) {
    final selected = selectedValue?.trim() ?? '';

    return options.where((option) {
      if (option == _customOption) {
        return true;
      }
      if (selected.isNotEmpty &&
          _normalizedOption(option) == _normalizedOption(selected)) {
        return true;
      }
      return !_optionSetsContain(hiddenOptions, option);
    }).toList();
  }

  String _resolvedDropdownValue(
    String? selectedValue,
    TextEditingController customController,
  ) {
    if (selectedValue == _customOption) {
      return customController.text.trim();
    }
    return selectedValue?.trim() ?? '';
  }

  String get _resolvedBrand {
    return _resolvedDropdownValue(selectedBrand, brandController);
  }

  String get _resolvedVendor {
    return _resolvedDropdownValue(selectedVendor, vendorController);
  }

  String get _resolvedLocation {
    return _resolvedDropdownValue(selectedLocation, customLocationController);
  }

  String get _resolvedCategory {
    if (selectedCategory == _customOption) {
      return customCategoryController.text.trim();
    }
    return selectedCategory.trim();
  }

  bool get _isCustomBrandSelected => selectedBrand == _customOption;
  bool get _isCustomVendorSelected => selectedVendor == _customOption;
  bool get _isCustomLocationSelected => selectedLocation == _customOption;
  bool get _isCustomCategorySelected => selectedCategory == _customOption;

  void _setInitialCategoryFromPrefill(String sheetTab) {
    final category = _categoryFromSheetTab(sheetTab);
    if (category == null) {
      return;
    }

    if (_matchesAnyOption(category, categories)) {
      selectedCategory = categories.firstWhere(
        (option) => option.trim().toLowerCase() == category.toLowerCase(),
      );
      return;
    }

    selectedCategory = _customOption;
    customCategoryController.text = category;
  }

  String? _categoryFromSheetTab(String sheetTab) {
    final value = sheetTab.trim();
    if (value.isEmpty) {
      return null;
    }

    final normalized = value.toLowerCase();
    const builtInSheetTabs = {
      'acids': 'Acid',
      'bases': 'Base',
      'salts': 'Salt',
      'metals': 'Metal',
      'catalysts': 'Catalyst',
      'ligands': 'Ligand',
    };

    if (builtInSheetTabs.containsKey(normalized)) {
      return builtInSheetTabs[normalized];
    }

    if (RegExp(r'^c\d+$', caseSensitive: false).hasMatch(value)) {
      return 'General';
    }

    return value;
  }

  String _customTypeFromChemical(ChemicalModel chemical) {
    final sheetTab = chemical.sheetTab.trim();
    if (sheetTab.isEmpty) {
      return '';
    }

    final category = _categoryFromSheetTab(sheetTab);
    if (category == null || _matchesAnyOption(category, categories)) {
      return '';
    }

    return category;
  }

  Set<String> _cleanHiddenOptions(Iterable<String> values) {
    final unique = <String, String>{};
    for (final value in values) {
      final trimmed = value.trim();
      final normalized = _normalizedOption(trimmed);
      if (trimmed.isEmpty) {
        continue;
      }
      unique.putIfAbsent(normalized, () => trimmed);
    }
    return unique.values.toSet();
  }

  Future<void> _loadHiddenDropdownOptionPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      hiddenChemicalBrandOptions = _cleanHiddenOptions(
        prefs.getStringList(_hiddenBrandOptionsKey) ?? const <String>[],
      );
      hiddenChemicalLocationOptions = _cleanHiddenOptions(
        prefs.getStringList(_hiddenLocationOptionsKey) ?? const <String>[],
      );
    });
  }

  Future<void> _saveHiddenBrandOptions(Set<String> hiddenOptions) async {
    final cleanOptions = _cleanHiddenOptions(hiddenOptions);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenBrandOptionsKey, cleanOptions.toList());
    if (!mounted) return;

    setState(() {
      hiddenChemicalBrandOptions = cleanOptions;
    });
  }

  Future<void> _saveHiddenLocationOptions(Set<String> hiddenOptions) async {
    final cleanOptions = _cleanHiddenOptions(hiddenOptions);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenLocationOptionsKey, cleanOptions.toList());
    if (!mounted) return;

    setState(() {
      hiddenChemicalLocationOptions = cleanOptions;
    });
  }

  Future<void> _loadExistingDropdownOptions() async {
    try {
      final chemicals = await inventoryService.getChemicalsOnce();
      if (!mounted) return;

      setState(() {
        customBrandOptions = _distinctCustomValues(
          chemicals.map((chemical) => chemical.brand),
          brandOptions,
        );
        customVendorOptions = _distinctCustomValues(
          chemicals.map((chemical) => chemical.vendor),
          vendorOptions,
        );
        customLocationOptions = _distinctCustomValues(
          chemicals.map((chemical) => chemical.location),
          locationOptions,
        );
        customCategoryOptions = _distinctCustomValues(
          chemicals.map(_customTypeFromChemical),
          categories,
        );
      });
    } catch (_) {
      // Keep the built-in dropdown options usable if lab-scoped values fail.
    }
  }

  List<String> getSubcategories(String category) {
    switch (category) {
      case 'Base':
        return ['Organic', 'Inorganic'];
      case 'Ligand':
        return ['N-Donor', 'Phosphine'];
      default:
        return [];
    }
  }

  String _getSheetTabFromSelection() {
    final category = _resolvedCategory;
    switch (category) {
      case 'Acid':
        return 'Acids';
      case 'Base':
        return 'Bases';
      case 'Salt':
        return 'Salts';
      case 'Metal':
        return 'Metals';
      case 'Catalyst':
        return 'Catalysts';
      case 'Ligand':
        return 'Ligands';
      case 'General':
        final carbonCount = int.tryParse(carbonCountController.text.trim());
        if (carbonCount != null && carbonCount > 0) {
          return 'C$carbonCount';
        }
        return '';
      default:
        return category;
    }
  }

  int? _extractCarbonCount(String formula) {
    final regex = RegExp(r'C(\d*)', caseSensitive: false);
    final match = regex.firstMatch(formula);

    if (match == null) return null;

    final digits = match.group(1);
    if (digits == null || digits.isEmpty) return 1;

    return int.tryParse(digits);
  }

  Future<void> _generateLabelForNewChemical() async {
    if (selectedEntryType == 'Existing Chemical') return;

    setState(() {
      isGeneratingLabel = true;
    });

    try {
      final carbonCount = int.tryParse(carbonCountController.text.trim());

      final prefix = chemicalLabelService.getPrefix(
        category: _resolvedCategory,
        subcategory: selectedSubcategory,
        carbonCount: carbonCount,
        catalystMetal: catalystMetalController.text.trim().isEmpty
            ? null
            : catalystMetalController.text.trim(),
      );

      final labId = AppState.instance.resolveWriteLabId(
        widget.order?.labId,
      );
      final missingLabels = await chemicalLabelService.findMissingLabelsForPrefix(
        labId: labId,
        prefix: prefix,
      );
      final suggestedLabel = await chemicalLabelService.suggestNextLabelForPrefix(
        labId: labId,
        prefix: prefix,
      );
      final usedMissingLabel =
          missingLabels.isNotEmpty && suggestedLabel == missingLabels.first;

      if (!mounted) return;

      setState(() {
        labelController.text = suggestedLabel;
        sheetTabController.text = _getSheetTabFromSelection();
      });

      if (usedMissingLabel) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Missing label $suggestedLabel found. Using it to keep inventory numbering consistent.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        labelController.text = 'Could not auto-generate';
      });
    } finally {
      if (mounted) {
        setState(() {
          isGeneratingLabel = false;
        });
      }
    }
  }

  Future<void> _fetchFromCasAndCheckInventory() async {
    setState(() {
      isFetchingCas = true;
    });

    try {
      final cas = casController.text.trim();

      if (cas.isNotEmpty) {
        final pubchem = await pubChemService.fetchByCas(cas);
        if (pubchem != null) {
          formulaController.text = pubchem.molecularFormula;
          molWtController.text = pubchem.molecularWeight;

          final carbonCount = _extractCarbonCount(pubchem.molecularFormula);
          if (carbonCount != null) {
            carbonCountController.text = carbonCount.toString();
          }
        }
      }

      final existing = cas.isEmpty
          ? null
          : await inventoryService.findExistingByCas(cas);

      if (existing != null) {
        final bottleCount = await inventoryService.getBottleCountByCas(cas);

        if (!mounted) return;
        setState(() {
          selectedEntryType = 'Existing Chemical';
          existingBottleCount = bottleCount;
          labelController.text = existing.label;
          sheetTabController.text = existing.sheetTab;

          _setDropdownSelection(
            value: existing.location,
            builtInOptions: locationOptions,
            onKnownValue: (value) => selectedLocation = value,
            onCustomValue: (value) {
              selectedLocation = _customOption;
              customLocationController.text = value;
            },
          );

          if (_resolvedBrand.isEmpty) {
            _setDropdownSelection(
              value: existing.brand,
              builtInOptions: brandOptions,
              onKnownValue: (value) => selectedBrand = value,
              onCustomValue: (value) {
                selectedBrand = _customOption;
                brandController.text = value;
              },
            );
          }

          if (_resolvedVendor.isEmpty) {
            _setDropdownSelection(
              value: existing.vendor,
              builtInOptions: vendorOptions,
              onKnownValue: (value) => selectedVendor = value,
              onCustomValue: (value) {
                selectedVendor = _customOption;
                vendorController.text = value;
              },
            );
          }

          selectedTexture = textureOptions.contains(existing.texture)
              ? existing.texture
              : null;

          if (existing.functionalGroups.isNotEmpty) {
            final parsed = existing.functionalGroups
                .split(',')
                .map((e) => e.trim())
                .where((e) => functionalGroupOptions.contains(e))
                .toList();
            selectedFunctionalGroups = parsed;
          } else {
            selectedFunctionalGroups = [];
          }

          if (formulaController.text.trim().isEmpty) {
            formulaController.text = existing.formula;
          }
          if (molWtController.text.trim().isEmpty) {
            molWtController.text = existing.molWt;
          }
          if (catNumberController.text.trim().isEmpty) {
            catNumberController.text = existing.catNumber;
          }
        });
      } else {
        if (!mounted) return;
        setState(() {
          selectedEntryType = 'New Chemical';
          existingBottleCount = 0;
          selectedFunctionalGroups = [];
          sheetTabController.text = _getSheetTabFromSelection();
        });

        await _generateLabelForNewChemical();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        selectedEntryType ??= 'New Chemical';
      });
    } finally {
      if (mounted) {
        setState(() {
          isFetchingCas = false;
        });
      }
    }
  }

  Future<void> _prefillFromCas() async {
    setState(() {
      isLoadingMetadata = true;
    });

    try {
      await _fetchFromCasAndCheckInventory();
    } finally {
      if (mounted) {
        setState(() {
          isLoadingMetadata = false;
        });
      }
    }
  }

  @override
  void dispose() {
    chemicalNameController.dispose();
    casController.dispose();
    brandController.dispose();
    quantityController.dispose();
    formulaController.dispose();
    molWtController.dispose();
    vendorController.dispose();
    catNumberController.dispose();
    arrivalDateController.dispose();
    orderedByController.dispose();
    labelController.dispose();
    sheetTabController.dispose();
    carbonCountController.dispose();
    catalystMetalController.dispose();
    customLocationController.dispose();
    customCategoryController.dispose();
    super.dispose();
  }

  InputDecoration inputDecoration(String label) {
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

  Widget _buildCustomizableDropdown({
    required String label,
    required String? value,
    required List<String> builtInOptions,
    required List<String> customOptions,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
    FormFieldValidator<String>? validator,
    Set<String> hiddenOptions = const {},
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final options = _filterHiddenOptions(
      options: _mergedOptions(builtInOptions, customOptions),
      hiddenOptions: hiddenOptions,
      selectedValue: value,
    );
    final cleanValue = value?.trim() ?? '';
    final dropdownOptions = [
      ...options,
      if (cleanValue.isNotEmpty &&
          !options.any(
            (option) =>
                _normalizedOption(option) == _normalizedOption(cleanValue),
          ))
        cleanValue,
    ];
    final safeValue = cleanValue.isEmpty
        ? null
        : dropdownOptions.firstWhere(
            (option) =>
                _normalizedOption(option) == _normalizedOption(cleanValue),
            orElse: () => cleanValue,
          );

    return DropdownButtonFormField<String>(
      key: ValueKey(
        '${label}_${safeValue ?? ''}_${customOptions.join('|')}_${hiddenOptions.join('|')}',
      ),
      initialValue: safeValue,
      dropdownColor: palette.panel,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: inputDecoration(label),
      items: _dropdownItems(dropdownOptions),
      onChanged: enabled ? onChanged : null,
      validator: validator,
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required String errorText,
    ValueChanged<String>? onChanged,
  }) {
    final colorScheme = context.colorScheme;
    return TextFormField(
      controller: controller,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: inputDecoration(label),
      textCapitalization: TextCapitalization.words,
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return errorText;
        }
        return null;
      },
    );
  }

  Widget _buildManageOptionsButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    final palette = context.labmate;
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: palette.mutedText,
        ),
        icon: const Icon(Icons.tune_rounded, size: 16),
        label: Text('Manage $label'),
      ),
    );
  }

  Future<bool> _confirmHideOption(String option) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hide option?'),
          content: Text(
            'Hide "$option" from future dropdowns? Existing inventory records will not be changed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Hide'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _showManageOptionsDialog({
    required String title,
    required List<String> builtInOptions,
    required List<String> customOptions,
    required Set<String> hiddenOptions,
    required Future<void> Function(Set<String> hiddenOptions)
    onHiddenOptionsChanged,
  }) async {
    var dialogHiddenOptions = _cleanHiddenOptions(hiddenOptions);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final visibleOptions = _filterHiddenOptions(
              options: _baseManageableOptions(builtInOptions, customOptions),
              hiddenOptions: dialogHiddenOptions,
            );

            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 420,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: visibleOptions.isEmpty
                      ? Text(
                          'No visible options. Reset hidden options to restore this list.',
                          style: TextStyle(color: context.labmate.mutedText),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: visibleOptions.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: context.labmate.border),
                          itemBuilder: (context, index) {
                            final option = visibleOptions[index];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(option),
                              trailing: IconButton(
                                tooltip: 'Hide',
                                icon: const Icon(Icons.visibility_off_outlined),
                                onPressed: () async {
                                  final shouldHide = await _confirmHideOption(
                                    option,
                                  );
                                  if (!shouldHide) {
                                    return;
                                  }

                                  final nextHiddenOptions = _cleanHiddenOptions(
                                    [...dialogHiddenOptions, option],
                                  );
                                  setDialogState(() {
                                    dialogHiddenOptions = nextHiddenOptions;
                                  });
                                  await onHiddenOptionsChanged(
                                    nextHiddenOptions,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: dialogHiddenOptions.isEmpty
                      ? null
                      : () async {
                          const nextHiddenOptions = <String>{};
                          setDialogState(() {
                            dialogHiddenOptions = nextHiddenOptions;
                          });
                          await onHiddenOptionsChanged(nextHiddenOptions);
                        },
                  child: const Text('Reset hidden options'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showManageBrandOptionsDialog() async {
    await _showManageOptionsDialog(
      title: 'Manage Brand Options',
      builtInOptions: brandOptions,
      customOptions: customBrandOptions,
      hiddenOptions: hiddenChemicalBrandOptions,
      onHiddenOptionsChanged: _saveHiddenBrandOptions,
    );
  }

  Future<void> _showManageLocationOptionsDialog() async {
    await _showManageOptionsDialog(
      title: 'Manage Location Options',
      builtInOptions: locationOptions,
      customOptions: customLocationOptions,
      hiddenOptions: hiddenChemicalLocationOptions,
      onHiddenOptionsChanged: _saveHiddenLocationOptions,
    );
  }

  Widget _buildFunctionalGroupSelector() {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Functional Groups',
          style: TextStyle(
            color: palette.mutedText,
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: functionalGroupOptions.map((group) {
              final isSelected = selectedFunctionalGroups.contains(group);

              return FilterChip(
                label: Text(group),
                selected: isSelected,
                selectedColor: const Color(0xFF14B8A6),
                backgroundColor: palette.panelAlt,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF14B8A6) : palette.border,
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      if (!selectedFunctionalGroups.contains(group)) {
                        selectedFunctionalGroups.add(group);
                      }
                    } else {
                      selectedFunctionalGroups.remove(group);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Future<void> submitChemicalEntry() async {
    final editChemical = widget.editChemical;
    final isEditMode = editChemical != null;
    final isAddingExistingBottle = selectedEntryType == 'Existing Chemical';
    if (!isEditMode && !isAddingExistingBottle) {
      sheetTabController.text = _getSheetTabFromSelection();
    }

    if (!_formKey.currentState!.validate()) return;

    final labId =
        editChemical?.labId ??
        AppState.instance.resolveWriteLabId(widget.order?.labId);
    final cas = casController.text.trim();
    var label = labelController.text.trim();

    if (!isEditMode && cas.isNotEmpty) {
      final existingChemical = await inventoryService.findExistingByCas(cas);
      final existingLabel = existingChemical?.label.trim() ?? '';

      if (existingChemical != null) {
        final bottleCount = await inventoryService.getBottleCountByCas(cas);
        if (!mounted) return;
        final isReusingDifferentLabel =
            existingLabel.isNotEmpty &&
            _normalizedOption(existingLabel) != _normalizedOption(label);

        setState(() {
          selectedEntryType = 'Existing Chemical';
          existingBottleCount = bottleCount;
          if (existingLabel.isNotEmpty) {
            labelController.text = existingLabel;
            label = existingLabel;
          }
          if (existingChemical.sheetTab.trim().isNotEmpty) {
            sheetTabController.text = existingChemical.sheetTab.trim();
          }
        });

        if (isReusingDifferentLabel) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Existing CAS found. Reusing label $existingLabel.',
              ),
            ),
          );
        }
      }
    }

    final consistencyError = await inventoryService.validateCasLabelConsistency(
      labId: labId,
      cas: cas,
      label: label,
      excludeDocId: editChemical?.id,
    );

    if (consistencyError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(consistencyError)));
      return;
    }

    if (!mounted) return;

    final chemical = ChemicalModel(
      id: editChemical?.id ?? '',
      labId: labId,
      label: label,
      chemicalName: chemicalNameController.text.trim(),
      cas: cas,
      formula: formulaController.text.trim(),
      molWt: molWtController.text.trim(),
      availability: editChemical?.availability ?? 'Available',
      texture: selectedTexture ?? '',
      location: _resolvedLocation,
      quantity: quantityController.text.trim(),
      brand: _resolvedBrand,
      vendor: _resolvedVendor,
      catNumber: catNumberController.text.trim(),
      arrivalDate: arrivalDateController.text.trim(),
      orderedBy: orderedByController.text.trim(),
      functionalGroups: selectedFunctionalGroups.join(', '),
      sheetTab: sheetTabController.text.trim(),
    );

    if (isEditMode) {
      await inventoryService.updateChemical(chemical);
    } else {
      await inventoryService.addChemical(chemical);
    }

    if (!isEditMode && widget.order != null) {
      await orderService.markInventoryAdded(docId: widget.order!.id);
    }
    await ActivityService().addActivity(
      labId: chemical.labId,
      type: isEditMode
          ? 'chemical_inventory_updated'
          : 'chemical_inventory_added',
      message: isEditMode
          ? 'Chemical entry updated for ${chemical.chemicalName}'
          : 'Chemical entry confirmed for ${chemical.chemicalName}',
      actorName: AppState.instance.authenticatedUserName,
      createdBy: AppState.instance.authenticatedUserId,
      relatedId: isEditMode ? chemical.id : widget.order?.id ?? chemical.cas,
    );

    if (!mounted) return;

    final String message;
    if (isEditMode) {
      message = 'Chemical bottle updated';
    } else if (selectedEntryType == 'Existing Chemical') {
      message = 'New bottle added under existing label ${labelController.text.trim()}';
    } else {
      message = 'New chemical added to inventory';
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.editChemical != null;
    final isExisting = !isEditMode && selectedEntryType == 'Existing Chemical';
    final identityLocked = isExisting || isEditMode;
    final subcategories = getSubcategories(selectedCategory);
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final String helperText;
    final String submitLabel;
    if (isEditMode) {
      helperText =
          'Update this bottle record without creating a duplicate inventory entry.';
      submitLabel = 'Save Changes';
    } else if (isExisting) {
      helperText =
          'CAS already exists in inventory. Same label is reused, and this confirm step adds a new bottle under that chemical.';
      submitLabel = 'Add New Bottle';
    } else {
      helperText =
          'CAS is new to inventory. Category-based label generation is active. Functional category is prioritized over carbon-count category.';
      submitLabel = 'Confirm Entry';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Chemical' : 'Add New Chemical'),
      ),
      body: SafeArea(
        child: isLoadingMetadata
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (widget.order != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: palette.panel,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: palette.border),
                        ),
                        child: Text(
                          'Prefilled from delivered order. Name, CAS, brand, quantity, ordered by, and arrival date come from the order. Formula and molecular weight can be fetched from CAS.',
                          style: TextStyle(
                            color: palette.mutedText,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: chemicalNameController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: inputDecoration('Chemical Name'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter chemical name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: casController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: inputDecoration('CAS No'),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: isFetchingCas
                            ? null
                            : _fetchFromCasAndCheckInventory,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                          side: BorderSide(color: colorScheme.primary),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          isFetchingCas ? 'Fetching...' : 'Fetch from CAS',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (isExisting)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0x2214B8A6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Existing CAS found. Reusing label ${labelController.text.trim()}. This entry will be saved as bottle ${existingBottleCount + 1}.',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 13.2,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    if (isExisting) const SizedBox(height: 14),
                    _buildCustomizableDropdown(
                      label: 'Type of chemical',
                      value: selectedCategory,
                      builtInOptions: categories,
                      customOptions: customCategoryOptions,
                      enabled: !identityLocked,
                      onChanged: (value) async {
                        if (value == null) return;

                        setState(() {
                          selectedCategory = value;
                          selectedSubcategory = null;
                          labelController.clear();
                          sheetTabController.text = _getSheetTabFromSelection();
                        });

                        await _generateLabelForNewChemical();
                      },
                    ),
                    const SizedBox(height: 14),
                    if (_isCustomCategorySelected) ...[
                      _buildCustomTextField(
                        controller: customCategoryController,
                        label: 'Custom chemical type',
                        errorText: 'Enter custom chemical type',
                        onChanged: (_) {
                          sheetTabController.text = _getSheetTabFromSelection();
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (subcategories.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'subcategory_${selectedCategory}_${selectedSubcategory ?? ''}_${subcategories.join('|')}',
                        ),
                        initialValue: selectedSubcategory,
                        dropdownColor: palette.panel,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: inputDecoration('Subcategory'),
                        items: subcategories
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: identityLocked
                            ? null
                            : (value) async {
                                setState(() {
                                  selectedSubcategory = value;
                                  labelController.clear();
                                });
                                await _generateLabelForNewChemical();
                              },
                        validator: (value) {
                          if ((selectedCategory == 'Base' ||
                                  selectedCategory == 'Ligand') &&
                              !identityLocked &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Select subcategory';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (selectedCategory == 'General') ...[
                      TextFormField(
                        controller: carbonCountController,
                        readOnly: identityLocked,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: inputDecoration('Carbon Count'),
                        onChanged: (_) async {
                          if (!identityLocked) {
                            setState(() {
                              sheetTabController.text =
                                  _getSheetTabFromSelection();
                            });
                            await _generateLabelForNewChemical();
                          }
                        },
                        validator: (value) {
                          if (!identityLocked &&
                              selectedCategory == 'General') {
                            final count = int.tryParse(value?.trim() ?? '');
                            if (count == null || count <= 0) {
                              return 'Enter valid carbon count';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (selectedCategory == 'Catalyst') ...[
                      TextFormField(
                        controller: catalystMetalController,
                        readOnly: identityLocked,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: inputDecoration(
                          'Catalyst Metal (Pd, Cu, Fe...)',
                        ),
                        onChanged: (_) async {
                          if (!identityLocked) {
                            await _generateLabelForNewChemical();
                          }
                        },
                        validator: (value) {
                          if (!identityLocked &&
                              selectedCategory == 'Catalyst') {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter catalyst metal';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: formulaController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: inputDecoration('Molecular Formula'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: molWtController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: inputDecoration('Molecular Weight'),
                    ),
                    const SizedBox(height: 8),
                    _buildManageOptionsButton(
                      label: 'Brand',
                      onPressed: _showManageBrandOptionsDialog,
                    ),
                    const SizedBox(height: 6),
                    _buildCustomizableDropdown(
                      label: 'Brand',
                      value: selectedBrand,
                      builtInOptions: brandOptions,
                      customOptions: customBrandOptions,
                      hiddenOptions: hiddenChemicalBrandOptions,
                      onChanged: (value) {
                        setState(() {
                          selectedBrand = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    if (_isCustomBrandSelected) ...[
                      _buildCustomTextField(
                        controller: brandController,
                        label: 'Custom brand',
                        errorText: 'Enter custom brand',
                      ),
                      const SizedBox(height: 14),
                    ],
                    _buildCustomizableDropdown(
                      label: 'Vendor',
                      value: selectedVendor,
                      builtInOptions: vendorOptions,
                      customOptions: customVendorOptions,
                      onChanged: (value) {
                        setState(() {
                          selectedVendor = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    if (_isCustomVendorSelected) ...[
                      _buildCustomTextField(
                        controller: vendorController,
                        label: 'Custom vendor',
                        errorText: 'Enter custom vendor',
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: quantityController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: inputDecoration('Quantity'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: labelController,
                      readOnly: true,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: inputDecoration('Generated Label'),
                    ),
                    const SizedBox(height: 8),
                    _buildManageOptionsButton(
                      label: 'Location',
                      onPressed: _showManageLocationOptionsDialog,
                    ),
                    const SizedBox(height: 6),
                    _buildCustomizableDropdown(
                      label: 'Location',
                      value: selectedLocation,
                      builtInOptions: locationOptions,
                      customOptions: customLocationOptions,
                      hiddenOptions: hiddenChemicalLocationOptions,
                      onChanged: (value) {
                        setState(() {
                          selectedLocation = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Select storage location';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    if (_isCustomLocationSelected) ...[
                      _buildCustomTextField(
                        controller: customLocationController,
                        label: 'Custom location',
                        errorText: 'Enter custom location',
                      ),
                      const SizedBox(height: 14),
                    ],
                    _buildFunctionalGroupSelector(),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      key: ValueKey('texture_${selectedTexture ?? ''}'),
                      initialValue: selectedTexture,
                      dropdownColor: palette.panel,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: inputDecoration('Texture / Physical State'),
                      items: textureOptions
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(
                                item,
                                style: TextStyle(color: colorScheme.onSurface),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedTexture = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: catNumberController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: inputDecoration('Catalog Number'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: arrivalDateController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: inputDecoration('Arrival Date'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: orderedByController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: inputDecoration('Ordered By'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: sheetTabController,
                      readOnly: true,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: inputDecoration('Sheet Tab'),
                      validator: (value) {
                        if (isEditMode) {
                          return null;
                        }
                        if (value == null || value.trim().isEmpty) {
                          return 'Sheet tab could not be determined';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: palette.panel,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: palette.border),
                      ),
                      child: Text(
                        helperText,
                        style: TextStyle(
                          color: palette.mutedText,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (!identityLocked)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: isGeneratingLabel
                              ? null
                              : _generateLabelForNewChemical,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                            side: BorderSide(color: colorScheme.primary),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            isGeneratingLabel
                                ? 'Generating...'
                                : 'Regenerate Label',
                          ),
                        ),
                      ),
                    if (!identityLocked) const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: submitChemicalEntry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14B8A6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          submitLabel,
                          style: const TextStyle(fontSize: 15),
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
