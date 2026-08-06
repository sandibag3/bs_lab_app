import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_state.dart';
import '../models/chemical_model.dart';
import '../models/lab_membership_model.dart';
import '../models/order_model.dart';
import '../models/user_profile.dart';
import '../services/activity_service.dart';
import '../services/lab_membership_service.dart';
import '../services/inventory_service.dart';
import '../services/order_service.dart';
import '../services/pubchem_service.dart';
import '../services/chemical_label_service.dart';
import '../services/user_profile_service.dart';
import '../theme/labmate_theme.dart';

enum _ChemicalLookupSource { none, inventory, pubChem, manual }

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
  final PubChemService pubChemService = PubChemService();
  final ChemicalLabelService chemicalLabelService = ChemicalLabelService();
  final LabMembershipService _labMembershipService = LabMembershipService();
  final UserProfileService _userProfileService = UserProfileService();

  late final TextEditingController chemicalNameController;
  late final TextEditingController casController;
  late final TextEditingController brandController;
  late final TextEditingController quantityController;
  late final TextEditingController bottleSizeController;
  late final TextEditingController formulaController;
  late final TextEditingController molWtController;
  late final TextEditingController vendorController;
  late final TextEditingController catNumberController;
  late final TextEditingController arrivalDateController;
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
  bool isSaving = false;

  String selectedCategory = 'General';
  String? selectedSubcategory;
  String? selectedBrand;
  String? selectedVendor;

  String? selectedLocation;
  String? selectedTexture;
  String selectedBottleUnit = 'g';
  String? _selectedOrderedByUid;
  String _initialOrderedByName = '';
  String _legacyOrderedByName = '';
  String _orderedByMembersLabId = '';
  List<String> selectedFunctionalGroups = [];
  List<_OrderedByMemberOption> _orderedByMembers = const [];

  int existingBottleCount = 0;
  int _casLookupRequestId = 0;
  int _orderedByMembersRequestId = 0;
  String _lastObservedCas = '';
  String? _chemicalLookupMessage;
  String? _orderedByMembersError;
  _ChemicalLookupSource _chemicalLookupSource = _ChemicalLookupSource.none;
  bool _isApplyingChemicalLookupResult = false;
  bool _isLoadingOrderedByMembers = false;

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
  List<String> manualChemicalBrandOptions = const [];
  List<String> manualChemicalLocationOptions = const [];
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
    'Solvent',
    'D-Solvent',
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

  final List<String> bottleUnitOptions = const ['mg', 'g', 'kg', 'mL', 'L'];

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
    _initialOrderedByName = (manualPrefill?.orderedBy ?? order?.orderedBy ?? '')
        .trim();
    _legacyOrderedByName = _initialOrderedByName;

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
    bottleSizeController = TextEditingController(
      text: manualPrefill?.bottleSize ?? '',
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
    labelController = TextEditingController(text: manualPrefill?.label ?? '');
    sheetTabController = TextEditingController(
      text: manualPrefill?.sheetTab ?? '',
    );
    carbonCountController = TextEditingController();
    catalystMetalController = TextEditingController();
    customLocationController = TextEditingController();
    customCategoryController = TextEditingController();
    _lastObservedCas = _normalizeCasForLookup(casController.text);
    casController.addListener(_handleCasChanged);
    chemicalNameController.addListener(_handleChemicalNameChanged);

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
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final prefillBottleUnit = manualPrefill?.bottleUnit.trim() ?? '';
    if (bottleUnitOptions.contains(prefillBottleUnit)) {
      selectedBottleUnit = prefillBottleUnit;
    }

    _loadHiddenDropdownOptionPreferences();
    _loadExistingDropdownOptions();
    AppState.instance.addListener(_handleAppStateChanged);
    _loadOrderedByMembers();
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

  bool _isGeneralChemicalType(String value) {
    final normalized = _normalizedOption(value);
    return normalized == 'general' || normalized == 'general chemical';
  }

  bool _areFunctionalGroupsEnabledForCurrentType() {
    return _isGeneralChemicalType(_resolvedCategory);
  }

  void _clearFunctionalGroupsWhenUnavailable() {
    if (!_areFunctionalGroupsEnabledForCurrentType()) {
      selectedFunctionalGroups = [];
    }
  }

  String _labelPrefixForCurrentType() {
    final carbonCount = int.tryParse(carbonCountController.text.trim());
    return chemicalLabelService.getPrefix(
      category: _resolvedCategory,
      subcategory: selectedSubcategory,
      carbonCount: carbonCount,
      catalystMetal: catalystMetalController.text.trim().isEmpty
          ? null
          : catalystMetalController.text.trim(),
    );
  }

  bool _labelMatchesPrefix(String label, String prefix) {
    return chemicalLabelService.parseLabelSerial(
          label: label,
          prefix: prefix,
        ) !=
        null;
  }

  String _normalizeCasForLookup(String value) {
    var cleanValue = value.trim();
    cleanValue = cleanValue.replaceAll('"', '').replaceAll("'", '');
    if (cleanValue.endsWith('.0')) {
      cleanValue = cleanValue.substring(0, cleanValue.length - 2);
    }
    return cleanValue;
  }

  bool _isStructurallyPlausibleCas(String value) {
    final cleanValue = _normalizeCasForLookup(value);
    return RegExp(r'^\d{1,7}-\d{2}-\d$').hasMatch(cleanValue);
  }

  void _clearCasDerivedIdentityMetadata() {
    chemicalNameController.clear();
    formulaController.clear();
    molWtController.clear();
    carbonCountController.clear();
    catalystMetalController.clear();
    selectedFunctionalGroups = [];
    selectedTexture = null;
  }

  void _handleCasChanged() {
    final currentCas = _normalizeCasForLookup(casController.text);
    if (currentCas == _lastObservedCas) {
      return;
    }

    _lastObservedCas = currentCas;
    _casLookupRequestId++;

    if (!mounted) {
      return;
    }

    setState(() {
      _chemicalLookupMessage = null;
      _chemicalLookupSource = _ChemicalLookupSource.none;
      existingBottleCount = 0;
      if (widget.editChemical == null) {
        selectedEntryType = null;
        labelController.clear();
        sheetTabController.text = _getSheetTabFromSelection();
      }
      _clearCasDerivedIdentityMetadata();
    });
  }

  void _handleChemicalNameChanged() {
    if (_isApplyingChemicalLookupResult) {
      return;
    }

    final hasManualName = chemicalNameController.text.trim().isNotEmpty;
    if (!mounted) {
      return;
    }

    if (hasManualName &&
        _chemicalLookupSource != _ChemicalLookupSource.manual) {
      setState(() {
        _chemicalLookupSource = _ChemicalLookupSource.manual;
        _chemicalLookupMessage = 'Chemical name entered manually.';
      });
    } else if (!hasManualName &&
        _chemicalLookupSource == _ChemicalLookupSource.manual) {
      setState(() {
        _chemicalLookupSource = _ChemicalLookupSource.none;
        _chemicalLookupMessage = null;
      });
    }
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

  String get _customBrandOptionsKey {
    return 'customChemicalBrandOptions_$_optionPreferenceLabId';
  }

  String get _customLocationOptionsKey {
    return 'customChemicalLocationOptions_$_optionPreferenceLabId';
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

  List<String> _cleanCustomOptions(
    Iterable<String> values, {
    Iterable<String> excludedOptions = const [],
  }) {
    final excluded = excludedOptions
        .map((option) => _normalizedOption(option))
        .where((option) => option.isNotEmpty)
        .toSet();
    final unique = <String, String>{};

    for (final value in values) {
      final trimmed = value.trim();
      final normalized = _normalizedOption(trimmed);
      if (trimmed.isEmpty ||
          trimmed == _customOption ||
          excluded.contains(normalized)) {
        continue;
      }
      unique.putIfAbsent(normalized, () => trimmed);
    }

    return unique.values.toList();
  }

  List<String> _brandDropdownCustomOptions() {
    return [...manualChemicalBrandOptions, ...customBrandOptions];
  }

  List<String> _locationDropdownCustomOptions() {
    return [...manualChemicalLocationOptions, ...customLocationOptions];
  }

  List<String> _mergedOptions(
    List<String> builtInOptions,
    List<String> customOptions,
  ) {
    final merged = <String>[];
    final seen = <String>{};

    void addOption(String value) {
      final trimmed = value.trim();
      final normalized = _normalizedOption(trimmed);
      if (trimmed.isEmpty ||
          trimmed == _customOption ||
          seen.contains(normalized)) {
        return;
      }
      seen.add(normalized);
      merged.add(trimmed);
    }

    for (final option in builtInOptions) {
      addOption(option);
    }
    for (final option in customOptions) {
      addOption(option);
    }

    return [...merged, _customOption];
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

  bool get _isCreatingChemicalEntry => widget.editChemical == null;

  bool get _isCustomBrandSelected => selectedBrand == _customOption;
  bool get _isCustomVendorSelected => selectedVendor == _customOption;
  bool get _isCustomLocationSelected => selectedLocation == _customOption;
  bool get _isCustomCategorySelected => selectedCategory == _customOption;

  void _showEntryValidationSnackBar({required bool isEditMode}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEditMode
              ? 'Please complete all required fields before saving changes.'
              : 'Please complete all required fields before confirming entry.',
        ),
      ),
    );
  }

  String? _validateRequiredText(
    String? value,
    String errorText, {
    bool creationOnly = true,
  }) {
    if (creationOnly && !_isCreatingChemicalEntry) {
      return null;
    }
    if (value == null || value.trim().isEmpty) {
      return errorText;
    }
    return null;
  }

  String? _validateRequiredDropdown(
    String? value,
    String errorText, {
    bool creationOnly = true,
  }) {
    return _validateRequiredText(value, errorText, creationOnly: creationOnly);
  }

  String _orderedByLabIdForCurrentEntry() {
    final editLabId = widget.editChemical?.labId.trim() ?? '';
    if (editLabId.isNotEmpty) {
      return editLabId;
    }

    return AppState.instance.resolveWriteLabId(widget.order?.labId).trim();
  }

  bool _isEligibleOrderedByMembership(LabMembershipModel membership) {
    final userId = membership.userId.trim();
    if (userId.isEmpty) {
      return false;
    }

    final status = membership.status.trim().toLowerCase();
    if (status.isNotEmpty && status != 'active') {
      return false;
    }

    final role = LabMembershipService.normalizeAccessRole(
      membership.role,
      isPi: userId == AppState.instance.selectedLabPiUid.trim(),
    );
    return role == LabAccessRole.pi.name ||
        role == LabAccessRole.admin.name ||
        role == LabAccessRole.member.name;
  }

  String _displayNameForOrderedByMember(
    LabMembershipModel membership,
    UserProfile? profile,
  ) {
    final profileName = profile?.name.trim() ?? '';
    if (profileName.isNotEmpty && profileName != 'Your Name') {
      return profileName;
    }

    final userName = membership.userName.trim();
    if (userName.isNotEmpty) {
      return userName;
    }

    final userEmail = membership.userEmail.trim();
    if (userEmail.isNotEmpty) {
      return userEmail;
    }

    return membership.userId.trim();
  }

  String? _matchingOrderedByUid(
    String value,
    List<_OrderedByMemberOption> members,
  ) {
    final cleanValue = value.trim();
    if (cleanValue.isEmpty) {
      return null;
    }

    for (final member in members) {
      if (member.matchesStoredValue(cleanValue)) {
        return member.uid;
      }
    }

    return null;
  }

  _OrderedByMemberOption? get _selectedOrderedByMember {
    final selectedUid = _selectedOrderedByUid?.trim() ?? '';
    if (selectedUid.isEmpty) {
      return null;
    }

    for (final member in _orderedByMembers) {
      if (member.uid == selectedUid) {
        return member;
      }
    }

    return null;
  }

  String? _validateOrderedBySelection(String? value) {
    if (_isLoadingOrderedByMembers ||
        _orderedByMembersError != null ||
        _orderedByMembers.isEmpty ||
        (value?.trim().isEmpty ?? true) ||
        _selectedOrderedByMember == null) {
      return 'Please select who ordered this item.';
    }

    return null;
  }

  void _handleAppStateChanged() {
    final labId = _orderedByLabIdForCurrentEntry();
    if (labId == _orderedByMembersLabId) {
      return;
    }

    _loadOrderedByMembers();
  }

  Future<void> _loadOrderedByMembers() async {
    final labId = _orderedByLabIdForCurrentEntry();
    final requestId = ++_orderedByMembersRequestId;
    final labChanged = labId != _orderedByMembersLabId;

    if (mounted) {
      setState(() {
        _orderedByMembersLabId = labId;
        _isLoadingOrderedByMembers = true;
        _orderedByMembersError = null;
        if (labChanged) {
          _orderedByMembers = const [];
          _selectedOrderedByUid = null;
          _legacyOrderedByName = _initialOrderedByName;
        }
      });
    }

    if (labId.isEmpty) {
      if (!mounted || requestId != _orderedByMembersRequestId) {
        return;
      }
      setState(() {
        _orderedByMembers = const [];
        _selectedOrderedByUid = null;
        _isLoadingOrderedByMembers = false;
      });
      return;
    }

    try {
      final memberships = await _labMembershipService.getMembershipsForLab(
        labId: labId,
      );
      final eligibleMemberships = <String, LabMembershipModel>{};
      for (final membership in memberships) {
        if (!_isEligibleOrderedByMembership(membership)) {
          continue;
        }

        final userId = membership.userId.trim();
        eligibleMemberships.putIfAbsent(userId, () => membership);
      }

      final profiles = await _userProfileService.getUserProfilesByIds(
        eligibleMemberships.keys,
      );
      final members = eligibleMemberships.values.map((membership) {
        final userId = membership.userId.trim();
        return _OrderedByMemberOption(
          uid: userId,
          displayName: _displayNameForOrderedByMember(
            membership,
            profiles[userId],
          ),
          userName: membership.userName.trim(),
          email: membership.userEmail.trim(),
        );
      }).toList();

      members.sort((a, b) {
        final nameComparison = a.displayName.trim().toLowerCase().compareTo(
          b.displayName.trim().toLowerCase(),
        );
        if (nameComparison != 0) {
          return nameComparison;
        }
        return a.uid.compareTo(b.uid);
      });

      if (!mounted || requestId != _orderedByMembersRequestId) {
        return;
      }

      setState(() {
        _orderedByMembers = members;
        _isLoadingOrderedByMembers = false;
        _orderedByMembersError = null;

        final currentSelection = _selectedOrderedByUid;
        final currentSelectionIsValid =
            currentSelection != null &&
            members.any((member) => member.uid == currentSelection);
        final matchedInitialUid = _matchingOrderedByUid(
          _initialOrderedByName,
          members,
        );
        _selectedOrderedByUid = currentSelectionIsValid
            ? currentSelection
            : matchedInitialUid;
        _legacyOrderedByName = _selectedOrderedByUid == null
            ? _initialOrderedByName
            : '';
      });
    } catch (_) {
      if (!mounted || requestId != _orderedByMembersRequestId) {
        return;
      }

      setState(() {
        _isLoadingOrderedByMembers = false;
        _orderedByMembersError = 'Could not load lab members.';
        if (labChanged) {
          _orderedByMembers = const [];
          _selectedOrderedByUid = null;
        }
      });
    }
  }

  String? _validateRequiredCas(String? value) {
    if (!_isCreatingChemicalEntry) {
      return null;
    }

    final cleanValue = _normalizeCasForLookup(value ?? '');
    if (cleanValue.isEmpty) {
      return 'Enter CAS number';
    }
    if (RegExp(r'[A-Za-z]').hasMatch(cleanValue) ||
        !RegExp(r'^[0-9-]+$').hasMatch(cleanValue) ||
        !cleanValue.contains('-')) {
      return 'Enter a valid CAS number';
    }
    return null;
  }

  String? _validatePositiveInteger(String? value, String errorText) {
    if (!_isCreatingChemicalEntry) {
      return null;
    }

    final cleanValue = value?.trim() ?? '';
    final parsedValue = int.tryParse(cleanValue);
    if (cleanValue.isEmpty || parsedValue == null || parsedValue <= 0) {
      return errorText;
    }
    return null;
  }

  String? _validatePositiveDecimal(String? value, String errorText) {
    if (!_isCreatingChemicalEntry) {
      return null;
    }

    final cleanValue = value?.trim() ?? '';
    final parsedValue = double.tryParse(cleanValue);
    if (cleanValue.isEmpty || parsedValue == null || parsedValue <= 0) {
      return errorText;
    }
    return null;
  }

  String? _validateGeneratedLabel(String? value) {
    if (!_isCreatingChemicalEntry) {
      return null;
    }

    final cleanValue = value?.trim() ?? '';
    if (cleanValue.isEmpty ||
        cleanValue.toLowerCase() == 'could not auto-generate') {
      return 'Generate chemical label';
    }
    return null;
  }

  String? _validateArrivalDate(String? value) {
    if (!_isCreatingChemicalEntry) {
      return null;
    }

    final cleanValue = value?.trim() ?? '';
    if (cleanValue.isEmpty) {
      return 'Select arrival date';
    }
    if (_parseArrivalDate(cleanValue) == null) {
      return 'Select a valid arrival date';
    }
    return null;
  }

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
      'solvent': 'Solvent',
      'solvents': 'Solvent',
      'd-solvent': 'D-Solvent',
      'd-solvents': 'D-Solvent',
      'd solvent': 'D-Solvent',
      'd solvents': 'D-Solvent',
      'deuterated solvent': 'D-Solvent',
      'deuterated solvents': 'D-Solvent',
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
      manualChemicalBrandOptions = _cleanCustomOptions(
        prefs.getStringList(_customBrandOptionsKey) ?? const <String>[],
        excludedOptions: brandOptions,
      );
      manualChemicalLocationOptions = _cleanCustomOptions(
        prefs.getStringList(_customLocationOptionsKey) ?? const <String>[],
        excludedOptions: locationOptions,
      );
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

  Future<void> _saveManualBrandOptions(List<String> customOptions) async {
    final cleanOptions = _cleanCustomOptions(
      customOptions,
      excludedOptions: brandOptions,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_customBrandOptionsKey, cleanOptions);
    if (!mounted) return;

    setState(() {
      manualChemicalBrandOptions = cleanOptions;
    });
  }

  Future<void> _saveManualLocationOptions(List<String> customOptions) async {
    final cleanOptions = _cleanCustomOptions(
      customOptions,
      excludedOptions: locationOptions,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_customLocationOptionsKey, cleanOptions);
    if (!mounted) return;

    setState(() {
      manualChemicalLocationOptions = cleanOptions;
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
      case 'Solvent':
        return 'Solvents';
      case 'D-Solvent':
        return 'D-Solvents';
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

  Future<void> _generateLabelForNewChemical({
    int? lookupRequestId,
    String? lookupCas,
  }) async {
    if (selectedEntryType == 'Existing Chemical') return;

    setState(() {
      isGeneratingLabel = true;
    });

    try {
      final prefix = _labelPrefixForCurrentType();

      final labId = AppState.instance.resolveWriteLabId(widget.order?.labId);
      debugPrint('AddNewChemical: label prefix used: $prefix');

      List<String> missingLabels = const [];
      try {
        missingLabels = await chemicalLabelService.findMissingLabelsForPrefix(
          labId: labId,
          prefix: prefix,
        );
      } catch (error) {
        debugPrint(
          'AddNewChemical: missing-label lookup failed for $prefix. Fallback path triggered. $error',
        );
      }

      String suggestedLabel;
      try {
        suggestedLabel = await chemicalLabelService.suggestNextLabelForPrefix(
          labId: labId,
          prefix: prefix,
        );
      } catch (suggestionError) {
        debugPrint(
          'AddNewChemical: suggestion failed for $prefix. Fallback path triggered. $suggestionError',
        );
        final fallbackLabelData = await chemicalLabelService.generateLabel(
          prefix: prefix,
        );
        suggestedLabel = (fallbackLabelData['label'] ?? '').toString().trim();
        if (suggestedLabel.isEmpty) {
          throw Exception('Generated label was empty.');
        }
      }

      debugPrint('AddNewChemical: generated label: $suggestedLabel');
      debugPrint('AddNewChemical: chosen label: $suggestedLabel');
      final usedMissingLabel =
          missingLabels.isNotEmpty && suggestedLabel == missingLabels.first;

      if (!mounted) return;
      if (lookupRequestId != null &&
          lookupCas != null &&
          !_isCurrentLookupResult(lookupRequestId, lookupCas)) {
        return;
      }

      setState(() {
        labelController.text = suggestedLabel;
        sheetTabController.text = _getSheetTabFromSelection();
      });

      if (usedMissingLabel) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Inventory numbering consistency\nMissing labels were detected in $prefix. Using $suggestedLabel to keep inventory numbering organized.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      if (lookupRequestId != null &&
          lookupCas != null &&
          !_isCurrentLookupResult(lookupRequestId, lookupCas)) {
        return;
      }

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

  bool _isCurrentLookupResult(int requestId, String cas) {
    return mounted &&
        requestId == _casLookupRequestId &&
        _normalizeCasForLookup(casController.text) == cas;
  }

  void _applyInventoryLookupResult({
    required ChemicalModel existing,
    required int bottleCount,
  }) {
    _isApplyingChemicalLookupResult = true;
    try {
      setState(() {
        selectedEntryType = 'Existing Chemical';
        existingBottleCount = bottleCount;
        chemicalNameController.text = existing.chemicalName.trim();
        labelController.text = existing.label.trim();
        sheetTabController.text = existing.sheetTab.trim();
        formulaController.text = existing.formula.trim();
        molWtController.text = existing.molWt.trim();
        final existingCategory = _categoryFromSheetTab(existing.sheetTab);
        if (existingCategory != null) {
          if (_matchesAnyOption(existingCategory, categories)) {
            selectedCategory = categories.firstWhere(
              (category) =>
                  _normalizedOption(category) ==
                  _normalizedOption(existingCategory),
            );
            customCategoryController.clear();
          } else {
            selectedCategory = _customOption;
            customCategoryController.text = existingCategory;
          }
        }
        selectedTexture = textureOptions.contains(existing.texture)
            ? existing.texture
            : null;

        if (existing.functionalGroups.trim().isNotEmpty) {
          selectedFunctionalGroups = existing.functionalGroups
              .split(',')
              .map((group) => group.trim())
              .where((group) => group.isNotEmpty)
              .toList();
        } else {
          selectedFunctionalGroups = [];
        }

        final carbonCount = _extractCarbonCount(existing.formula);
        carbonCountController.text = carbonCount?.toString() ?? '';
        _chemicalLookupSource = _ChemicalLookupSource.inventory;
        _chemicalLookupMessage = 'Chemical details loaded from inventory.';
      });
    } finally {
      _isApplyingChemicalLookupResult = false;
    }
  }

  Future<void> _applyPubChemLookupResult(
    PubChemChemicalDetails pubchem, {
    required int requestId,
    required String cas,
  }) async {
    _isApplyingChemicalLookupResult = true;
    try {
      setState(() {
        selectedEntryType = 'New Chemical';
        existingBottleCount = 0;
        chemicalNameController.text = pubchem.iupacName.trim();
        formulaController.text = pubchem.molecularFormula.trim();
        molWtController.text = pubchem.molecularWeight.trim();
        selectedFunctionalGroups = [];
        sheetTabController.text = _getSheetTabFromSelection();

        final carbonCount = _extractCarbonCount(pubchem.molecularFormula);
        carbonCountController.text = carbonCount?.toString() ?? '';
        _chemicalLookupSource = _ChemicalLookupSource.pubChem;
        _chemicalLookupMessage = 'Chemical details loaded from PubChem.';
      });
    } finally {
      _isApplyingChemicalLookupResult = false;
    }

    await _generateLabelForNewChemical(
      lookupRequestId: requestId,
      lookupCas: cas,
    );
  }

  Future<void> _applyManualLookupFallback(
    String message, {
    required int requestId,
    required String cas,
    required bool preserveManualName,
  }) async {
    _isApplyingChemicalLookupResult = true;
    try {
      setState(() {
        selectedEntryType = 'New Chemical';
        existingBottleCount = 0;
        if (!preserveManualName) {
          chemicalNameController.clear();
        }
        formulaController.clear();
        molWtController.clear();
        carbonCountController.clear();
        selectedFunctionalGroups = [];
        sheetTabController.text = _getSheetTabFromSelection();
        _chemicalLookupSource = _ChemicalLookupSource.manual;
        _chemicalLookupMessage = message;
      });
    } finally {
      _isApplyingChemicalLookupResult = false;
    }

    await _generateLabelForNewChemical(
      lookupRequestId: requestId,
      lookupCas: cas,
    );
  }

  Future<String> _resolveUniqueLabelForSave({
    required String labId,
    required String cas,
  }) async {
    final prefix = _labelPrefixForCurrentType();
    if (prefix.trim().isEmpty) {
      throw Exception('Could not determine a label prefix for this chemical.');
    }

    for (var attempt = 0; attempt < 3; attempt++) {
      final candidate = await chemicalLabelService.suggestNextLabelForPrefix(
        labId: labId,
        prefix: prefix,
      );
      final cleanCandidate = candidate.trim();

      if (!_labelMatchesPrefix(cleanCandidate, prefix)) {
        throw Exception(
          'Generated label does not match the selected chemical type.',
        );
      }

      final conflictingCas = await inventoryService.getCasForLabel(
        labId: labId,
        label: cleanCandidate,
        differentFromCas: cas,
      );

      if (conflictingCas == null) {
        return cleanCandidate;
      }
    }

    throw Exception(
      'Could not find a unique chemical label. Please try again.',
    );
  }

  String _functionalGroupsForSave({required bool isExistingCasBottle}) {
    if (isExistingCasBottle) {
      return selectedFunctionalGroups.join(', ');
    }

    if (_areFunctionalGroupsEnabledForCurrentType()) {
      return selectedFunctionalGroups.join(', ');
    }

    return '';
  }

  Future<void> _fetchFromCasAndCheckInventory() async {
    if (isFetchingCas) return;

    final cas = _normalizeCasForLookup(casController.text);
    if (cas.isEmpty) {
      setState(() {
        _chemicalLookupSource = _ChemicalLookupSource.none;
        _chemicalLookupMessage = 'Enter a CAS number to look up details.';
      });
      return;
    }

    if (!_isStructurallyPlausibleCas(cas)) {
      setState(() {
        _chemicalLookupSource = _ChemicalLookupSource.none;
        _chemicalLookupMessage = 'Enter a complete valid CAS number.';
      });
      return;
    }

    final requestId = ++_casLookupRequestId;
    final preserveManualName =
        _chemicalLookupSource == _ChemicalLookupSource.manual &&
        chemicalNameController.text.trim().isNotEmpty;
    setState(() {
      isFetchingCas = true;
      _chemicalLookupSource = _ChemicalLookupSource.none;
      _chemicalLookupMessage =
          'Checking inventory first, then PubChem if needed...';
    });

    try {
      final existing = await inventoryService.findExistingByCas(cas);
      if (!_isCurrentLookupResult(requestId, cas)) return;

      if (existing != null) {
        final bottleCount = await inventoryService.getBottleCountByCas(cas);
        if (!_isCurrentLookupResult(requestId, cas)) return;
        _applyInventoryLookupResult(
          existing: existing,
          bottleCount: bottleCount,
        );
        return;
      }

      final pubchem = await pubChemService.fetchByCas(cas);
      if (!_isCurrentLookupResult(requestId, cas)) return;

      if (pubchem != null && pubchem.iupacName.trim().isNotEmpty) {
        await _applyPubChemLookupResult(
          pubchem,
          requestId: requestId,
          cas: cas,
        );
        return;
      }

      await _applyManualLookupFallback(
        'No matching chemical was found in inventory or PubChem. Please enter the chemical name manually.',
        requestId: requestId,
        cas: cas,
        preserveManualName: preserveManualName,
      );
    } catch (error) {
      debugPrint('CAS lookup failed: $error');
      if (!mounted || !_isCurrentLookupResult(requestId, cas)) return;

      await _applyManualLookupFallback(
        'Could not complete chemical lookup. Please enter the chemical name manually.',
        requestId: requestId,
        cas: cas,
        preserveManualName: preserveManualName,
      );
    } finally {
      if (mounted) {
        setState(() {
          isFetchingCas = false;
        });
      }
    }
  }

  Future<void> _prefillFromCas() async {
    if (mounted) {
      setState(() {
        isLoadingMetadata = false;
      });
    }

    final cas = _normalizeCasForLookup(casController.text);
    if (cas.isEmpty || !_isStructurallyPlausibleCas(cas)) {
      return;
    }

    await _fetchFromCasAndCheckInventory();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_handleAppStateChanged);
    casController.removeListener(_handleCasChanged);
    chemicalNameController.removeListener(_handleChemicalNameChanged);
    chemicalNameController.dispose();
    casController.dispose();
    brandController.dispose();
    quantityController.dispose();
    bottleSizeController.dispose();
    formulaController.dispose();
    molWtController.dispose();
    vendorController.dispose();
    catNumberController.dispose();
    arrivalDateController.dispose();
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
    Alignment alignment = Alignment.centerRight,
  }) {
    final palette = context.labmate;
    return Align(
      alignment: alignment,
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

  Widget _sectionCard({required String title, required List<Widget> children}) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _sectionHeaderWithAction({
    required String title,
    required String actionLabel,
    required VoidCallback onPressed,
  }) {
    final colorScheme = context.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _buildManageOptionsButton(label: actionLabel, onPressed: onPressed),
      ],
    );
  }

  bool _optionExists(Iterable<String> options, String value, {String? except}) {
    final normalizedValue = _normalizedOption(value);
    final normalizedExcept = _normalizedOption(except ?? '');
    if (normalizedValue.isEmpty) {
      return false;
    }

    return options.any((option) {
      final normalizedOption = _normalizedOption(option);
      return normalizedOption == normalizedValue &&
          normalizedOption != normalizedExcept;
    });
  }

  Future<String?> _showOptionValueDialog({
    required String title,
    required String label,
    String initialValue = '',
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return _OptionValueDialog(
          title: title,
          label: label,
          initialValue: initialValue,
        );
      },
    );
  }

  Future<void> _showDuplicateOptionMessage(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmFutureOnlyRename({required String warning}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename dropdown option?'),
          content: Text(warning),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<bool> _confirmHideOption({required String warning}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hide option?'),
          content: Text(warning),
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
    required String optionLabel,
    required String addButtonLabel,
    required String duplicateMessage,
    required String renameWarning,
    required String hideWarning,
    required List<String> builtInOptions,
    required List<String> manualCustomOptions,
    required List<String> inventoryDerivedOptions,
    required Set<String> hiddenOptions,
    required Future<void> Function(List<String> customOptions)
    onManualOptionsChanged,
    required Future<void> Function(Set<String> hiddenOptions)
    onHiddenOptionsChanged,
    required void Function(String oldValue, String newValue)
    onSelectedValueRenamed,
  }) async {
    var dialogManualOptions = _cleanCustomOptions(
      manualCustomOptions,
      excludedOptions: builtInOptions,
    );
    var dialogHiddenOptions = _cleanHiddenOptions(hiddenOptions);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final manageableOptions = _baseManageableOptions(builtInOptions, [
              ...dialogManualOptions,
              ...inventoryDerivedOptions,
            ]);
            final visibleOptions = _filterHiddenOptions(
              options: manageableOptions,
              hiddenOptions: dialogHiddenOptions,
            );

            Future<void> addOption() async {
              final value = await _showOptionValueDialog(
                title: addButtonLabel,
                label: optionLabel,
              );
              final cleanValue = value?.trim() ?? '';
              if (cleanValue.isEmpty) {
                return;
              }

              if (_optionExists(manageableOptions, cleanValue)) {
                await _showDuplicateOptionMessage(duplicateMessage);
                return;
              }

              final nextManualOptions = _cleanCustomOptions([
                ...dialogManualOptions,
                cleanValue,
              ], excludedOptions: builtInOptions);
              setDialogState(() {
                dialogManualOptions = nextManualOptions;
              });
              await onManualOptionsChanged(nextManualOptions);
            }

            Future<void> renameOption(String option) async {
              final value = await _showOptionValueDialog(
                title: 'Edit $optionLabel',
                label: optionLabel,
                initialValue: option,
              );
              final cleanValue = value?.trim() ?? '';
              if (cleanValue.isEmpty) {
                return;
              }

              if (_normalizedOption(cleanValue) == _normalizedOption(option)) {
                return;
              }

              if (_optionExists(
                manageableOptions,
                cleanValue,
                except: option,
              )) {
                await _showDuplicateOptionMessage(duplicateMessage);
                return;
              }

              final isManualOption = _optionSetsContain(
                dialogManualOptions,
                option,
              );

              if (isManualOption) {
                final nextManualOptions = _cleanCustomOptions(
                  dialogManualOptions.map((manualOption) {
                    return _normalizedOption(manualOption) ==
                            _normalizedOption(option)
                        ? cleanValue
                        : manualOption;
                  }),
                  excludedOptions: builtInOptions,
                );
                setDialogState(() {
                  dialogManualOptions = nextManualOptions;
                });
                await onManualOptionsChanged(nextManualOptions);
                onSelectedValueRenamed(option, cleanValue);
                return;
              }

              final confirmed = await _confirmFutureOnlyRename(
                warning: renameWarning,
              );
              if (!confirmed) {
                return;
              }

              final nextManualOptions = _cleanCustomOptions([
                ...dialogManualOptions,
                cleanValue,
              ], excludedOptions: builtInOptions);
              final nextHiddenOptions = _cleanHiddenOptions([
                ...dialogHiddenOptions,
                option,
              ]);
              setDialogState(() {
                dialogManualOptions = nextManualOptions;
                dialogHiddenOptions = nextHiddenOptions;
              });
              await onManualOptionsChanged(nextManualOptions);
              await onHiddenOptionsChanged(nextHiddenOptions);
              onSelectedValueRenamed(option, cleanValue);
            }

            Future<void> hideOption(String option) async {
              final shouldHide = await _confirmHideOption(warning: hideWarning);
              if (!shouldHide) {
                return;
              }

              final nextHiddenOptions = _cleanHiddenOptions([
                ...dialogHiddenOptions,
                option,
              ]);
              setDialogState(() {
                dialogHiddenOptions = nextHiddenOptions;
              });
              await onHiddenOptionsChanged(nextHiddenOptions);
            }

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
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => renameOption(option),
                                  ),
                                  IconButton(
                                    tooltip: 'Hide',
                                    icon: const Icon(
                                      Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () => hideOption(option),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: addOption,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(addButtonLabel),
                ),
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
      optionLabel: 'brand',
      addButtonLabel: 'Add brand',
      duplicateMessage: 'This brand already exists.',
      renameWarning:
          'This will rename the dropdown option for future entries only. Existing chemical records will not be changed.',
      hideWarning:
          'Hide this brand from future dropdowns? Existing chemical records will not be changed.',
      builtInOptions: brandOptions,
      manualCustomOptions: manualChemicalBrandOptions,
      inventoryDerivedOptions: customBrandOptions,
      hiddenOptions: hiddenChemicalBrandOptions,
      onManualOptionsChanged: _saveManualBrandOptions,
      onHiddenOptionsChanged: _saveHiddenBrandOptions,
      onSelectedValueRenamed: (oldValue, newValue) {
        if (_normalizedOption(_resolvedBrand) != _normalizedOption(oldValue)) {
          return;
        }
        setState(() {
          selectedBrand = newValue;
          brandController.clear();
        });
      },
    );
  }

  Future<void> _showManageLocationOptionsDialog() async {
    await _showManageOptionsDialog(
      title: 'Manage Location Options',
      optionLabel: 'location',
      addButtonLabel: 'Add location',
      duplicateMessage: 'This location already exists.',
      renameWarning:
          'This will rename the dropdown option for future entries only. Existing chemical records will not be changed.',
      hideWarning:
          'Hide this location from future dropdowns? Existing chemical records will not be changed.',
      builtInOptions: locationOptions,
      manualCustomOptions: manualChemicalLocationOptions,
      inventoryDerivedOptions: customLocationOptions,
      hiddenOptions: hiddenChemicalLocationOptions,
      onManualOptionsChanged: _saveManualLocationOptions,
      onHiddenOptionsChanged: _saveHiddenLocationOptions,
      onSelectedValueRenamed: (oldValue, newValue) {
        if (_normalizedOption(_resolvedLocation) !=
            _normalizedOption(oldValue)) {
          return;
        }
        setState(() {
          selectedLocation = newValue;
          customLocationController.clear();
        });
      },
    );
  }

  Future<void> _pickArrivalDate() async {
    final initialDate = _parseArrivalDate(arrivalDateController.text);
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime(DateTime.now().year + 20),
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      arrivalDateController.text = _formatArrivalDate(selectedDate);
    });
  }

  DateTime? _parseArrivalDate(String value) {
    final parts = value.trim().split('/');
    if (parts.length != 3) {
      return null;
    }

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) {
      return null;
    }

    return DateTime(year, month, day);
  }

  String _formatArrivalDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _addCustomFunctionalGroup() async {
    final customGroup = await showDialog<String>(
      context: context,
      builder: (context) => const _CustomFunctionalGroupDialog(),
    );
    final cleanGroup = customGroup?.trim() ?? '';
    if (cleanGroup.isEmpty || !mounted) {
      return;
    }

    final alreadySelected = selectedFunctionalGroups.any(
      (group) => _normalizedOption(group) == _normalizedOption(cleanGroup),
    );

    if (alreadySelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$cleanGroup is already selected.')),
      );
      return;
    }

    setState(() {
      selectedFunctionalGroups.add(cleanGroup);
    });
  }

  Widget _buildFunctionalGroupSelector({bool showTitle = true}) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final functionalGroupsEnabled = _areFunctionalGroupsEnabledForCurrentType();
    final visibleFunctionalGroups = [
      ...functionalGroupOptions,
      ...selectedFunctionalGroups.where(
        (group) => !_matchesAnyOption(group, functionalGroupOptions),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            'Functional Groups',
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: functionalGroupsEnabled
              ? Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...visibleFunctionalGroups.map((group) {
                      final isSelected = selectedFunctionalGroups.any(
                        (selectedGroup) =>
                            _normalizedOption(selectedGroup) ==
                            _normalizedOption(group),
                      );

                      return FilterChip(
                        label: Text(group),
                        selected: isSelected,
                        selectedColor: const Color(0xFF14B8A6),
                        backgroundColor: palette.panelAlt,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : colorScheme.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF14B8A6)
                              : palette.border,
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              if (!isSelected) {
                                selectedFunctionalGroups.add(group);
                              }
                            } else {
                              selectedFunctionalGroups.removeWhere(
                                (selectedGroup) =>
                                    _normalizedOption(selectedGroup) ==
                                    _normalizedOption(group),
                              );
                            }
                          });
                        },
                      );
                    }),
                    ActionChip(
                      avatar: Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      label: const Text('Add functional group'),
                      backgroundColor: palette.panelAlt,
                      side: BorderSide(color: palette.border),
                      labelStyle: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      onPressed: _addCustomFunctionalGroup,
                    ),
                  ],
                )
              : Text(
                  'Functional groups are available only for General Chemicals.',
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _handleSuccessfulManualAdd() async {
    final addAnother = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Chemical added successfully'),
          content: const Text('Add another chemical?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (addAnother == true) {
      _resetForAnotherManualChemical();
      return;
    }

    Navigator.pop(context);
  }

  void _resetForAnotherManualChemical() {
    setState(() {
      chemicalNameController.clear();
      casController.clear();
      brandController.clear();
      quantityController.clear();
      bottleSizeController.clear();
      formulaController.clear();
      molWtController.clear();
      vendorController.clear();
      catNumberController.clear();
      arrivalDateController.clear();
      labelController.clear();
      sheetTabController.clear();
      carbonCountController.clear();
      catalystMetalController.clear();
      customLocationController.clear();
      customCategoryController.clear();
      _lastObservedCas = '';
      _chemicalLookupMessage = null;
      _chemicalLookupSource = _ChemicalLookupSource.none;
      _casLookupRequestId++;
      selectedEntryType = null;
      selectedCategory = 'General';
      selectedSubcategory = null;
      selectedBrand = null;
      selectedVendor = null;
      selectedLocation = null;
      selectedTexture = null;
      selectedBottleUnit = 'g';
      _selectedOrderedByUid = null;
      _legacyOrderedByName = '';
      selectedFunctionalGroups = [];
      existingBottleCount = 0;
    });
  }

  Future<void> submitChemicalEntry() async {
    if (isSaving) return;

    final editChemical = widget.editChemical;
    final isEditMode = editChemical != null;
    final isAddingExistingBottle = selectedEntryType == 'Existing Chemical';

    setState(() {
      isSaving = true;
    });

    try {
      ChemicalModel? existingChemical;
      if (!isEditMode && !isAddingExistingBottle) {
        final currentCas = _normalizeCasForLookup(casController.text);
        if (_isStructurallyPlausibleCas(currentCas)) {
          existingChemical = await inventoryService.findExistingByCas(
            currentCas,
          );
          if (existingChemical != null) {
            final selectedTypeBeforeExistingLookup = _resolvedCategory;
            final bottleCount = await inventoryService.getBottleCountByCas(
              currentCas,
            );
            if (!mounted) return;

            final existingType =
                _categoryFromSheetTab(existingChemical.sheetTab) ??
                existingChemical.sheetTab.trim();
            final isReusingDifferentType =
                existingType.trim().isNotEmpty &&
                selectedTypeBeforeExistingLookup.trim().isNotEmpty &&
                _normalizedOption(existingType) !=
                    _normalizedOption(selectedTypeBeforeExistingLookup);

            _applyInventoryLookupResult(
              existing: existingChemical,
              bottleCount: bottleCount,
            );

            if (isReusingDifferentType) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Existing CAS uses $existingType. Reusing the stored type and label for this bottle.',
                  ),
                ),
              );
            }
          }
        }
      }

      if (!isEditMode &&
          selectedEntryType != 'Existing Chemical' &&
          existingChemical == null) {
        setState(() {
          sheetTabController.text = _getSheetTabFromSelection();
          _clearFunctionalGroupsWhenUnavailable();
        });

        final prefix = _labelPrefixForCurrentType();
        if (labelController.text.trim().isEmpty ||
            !_labelMatchesPrefix(labelController.text.trim(), prefix)) {
          await _generateLabelForNewChemical();
        }
      }

      if (!mounted) return;
      FocusScope.of(context).unfocus();
      final isValid = _formKey.currentState?.validate() ?? false;
      if (!isValid) {
        _showEntryValidationSnackBar(isEditMode: isEditMode);
        return;
      }

      final labId =
          editChemical?.labId ??
          AppState.instance.resolveWriteLabId(widget.order?.labId);
      if (_isLoadingOrderedByMembers ||
          _orderedByMembersError != null ||
          _orderedByMembers.isEmpty ||
          _orderedByMembersLabId.trim() != labId.trim()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select who ordered this item.')),
        );
        return;
      }

      final orderedByMember = _selectedOrderedByMember;
      if (orderedByMember == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select who ordered this item.')),
        );
        return;
      }

      final cas = _normalizeCasForLookup(casController.text);
      var label = labelController.text.trim();
      var sheetTab = sheetTabController.text.trim();

      if (!isEditMode && cas.isNotEmpty) {
        final selectedTypeBeforeExistingLookup = _resolvedCategory;
        existingChemical ??= await inventoryService.findExistingByCas(cas);
        final existingLabel = existingChemical?.label.trim() ?? '';

        if (existingChemical != null) {
          final foundExistingChemical = existingChemical;
          final bottleCount = await inventoryService.getBottleCountByCas(cas);
          if (!mounted) return;
          final existingType =
              _categoryFromSheetTab(foundExistingChemical.sheetTab) ??
              foundExistingChemical.sheetTab.trim();
          final isReusingDifferentLabel =
              existingLabel.isNotEmpty &&
              _normalizedOption(existingLabel) != _normalizedOption(label);
          final isReusingDifferentType =
              existingType.trim().isNotEmpty &&
              selectedTypeBeforeExistingLookup.trim().isNotEmpty &&
              _normalizedOption(existingType) !=
                  _normalizedOption(selectedTypeBeforeExistingLookup);

          setState(() {
            selectedEntryType = 'Existing Chemical';
            existingBottleCount = bottleCount;
            if (existingLabel.isNotEmpty) {
              labelController.text = existingLabel;
              label = existingLabel;
            }
            if (foundExistingChemical.sheetTab.trim().isNotEmpty) {
              sheetTabController.text = foundExistingChemical.sheetTab.trim();
              sheetTab = foundExistingChemical.sheetTab.trim();
              final category = _categoryFromSheetTab(
                foundExistingChemical.sheetTab,
              );
              if (category != null) {
                if (_matchesAnyOption(category, categories)) {
                  selectedCategory = categories.firstWhere(
                    (option) =>
                        _normalizedOption(option) ==
                        _normalizedOption(category),
                  );
                  customCategoryController.clear();
                } else {
                  selectedCategory = _customOption;
                  customCategoryController.text = category;
                }
              }
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
          if (isReusingDifferentType) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Existing CAS uses $existingType. Reusing the stored type and label for this bottle.',
                ),
              ),
            );
          }
        }
      }

      final isExistingCasBottle = !isEditMode && existingChemical != null;
      if (!isEditMode && !isExistingCasBottle) {
        label = await _resolveUniqueLabelForSave(labId: labId, cas: cas);
        sheetTab = _getSheetTabFromSelection();
        if (!mounted) return;
        setState(() {
          labelController.text = label;
          sheetTabController.text = sheetTab;
          _clearFunctionalGroupsWhenUnavailable();
        });
      }

      final consistencyError = await inventoryService
          .validateCasLabelConsistency(
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
        bottleSize: bottleSizeController.text.trim(),
        bottleUnit: selectedBottleUnit,
        brand: _resolvedBrand,
        vendor: _resolvedVendor,
        catNumber: catNumberController.text.trim(),
        arrivalDate: arrivalDateController.text.trim(),
        orderedBy: orderedByMember.displayName,
        functionalGroups: _functionalGroupsForSave(
          isExistingCasBottle: isExistingCasBottle,
        ),
        sheetTab: sheetTab,
      );

      String? inventoryRecordId;
      if (isEditMode) {
        await inventoryService.updateChemical(chemical);
      } else if (widget.order != null) {
        inventoryRecordId = await inventoryService
            .addChemicalFromDeliveredOrder(
              chemical: chemical,
              orderId: widget.order!.id,
              inventoryAddedBy: AppState.instance.authenticatedUserId,
            );
      } else {
        await inventoryService.addChemical(chemical);
      }

      try {
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
          relatedId: isEditMode
              ? chemical.id
              : inventoryRecordId ?? widget.order?.id ?? chemical.cas,
        );
      } catch (error, stackTrace) {
        debugPrint('Failed to log chemical inventory activity: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      if (!mounted) return;

      final String message;
      if (isEditMode) {
        message = 'Chemical bottle updated';
      } else if (selectedEntryType == 'Existing Chemical') {
        message =
            'New bottle added under existing label ${labelController.text.trim()}';
      } else {
        message = 'New chemical added to inventory';
      }

      final isManualAdd = !isEditMode && widget.order == null;
      if (isManualAdd) {
        await _handleSuccessfulManualAdd();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        Navigator.pop(context);
      }
    } on OrderInventoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error, stackTrace) {
      debugPrint('Failed to add chemical order to inventory: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add item to inventory. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget _buildDeliveredOrderBanner() {
    final palette = context.labmate;

    return Container(
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
    );
  }

  Widget _buildExistingCasBanner() {
    final colorScheme = context.colorScheme;

    return Container(
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
    );
  }

  Widget _buildChemicalNameField() {
    final colorScheme = context.colorScheme;

    return TextFormField(
      controller: chemicalNameController,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: inputDecoration('Chemical Name'),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Enter chemical name';
        }
        return null;
      },
    );
  }

  Widget _buildChemicalLookupStatus() {
    final message = isFetchingCas
        ? 'Checking inventory first, then PubChem if needed...'
        : _chemicalLookupMessage;
    if (message == null || message.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final Color accentColor = switch (_chemicalLookupSource) {
      _ChemicalLookupSource.inventory => const Color(0xFF14B8A6),
      _ChemicalLookupSource.pubChem => colorScheme.primary,
      _ChemicalLookupSource.manual => const Color(0xFFF59E0B),
      _ChemicalLookupSource.none => palette.mutedText,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isFetchingCas)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: accentColor,
              ),
            )
          else
            Icon(Icons.info_outline_rounded, size: 17, color: accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 12.8,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCasField() {
    final colorScheme = context.colorScheme;

    return TextFormField(
      controller: casController,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: inputDecoration('CAS No'),
      textInputAction: TextInputAction.search,
      onFieldSubmitted: (_) => _fetchFromCasAndCheckInventory(),
      validator: _validateRequiredCas,
    );
  }

  Widget _buildFetchFromCasButton() {
    final colorScheme = context.colorScheme;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isFetchingCas ? null : _fetchFromCasAndCheckInventory,
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(isFetchingCas ? 'Fetching...' : 'Fetch from CAS'),
      ),
    );
  }

  Widget _buildChemicalTypeDropdown({required bool identityLocked}) {
    return _buildCustomizableDropdown(
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
          _clearFunctionalGroupsWhenUnavailable();
        });

        await _generateLabelForNewChemical();
      },
      validator: (value) =>
          _validateRequiredDropdown(value, 'Select chemical type'),
    );
  }

  Widget _buildSubcategoryDropdown({
    required bool identityLocked,
    required List<String> subcategories,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return DropdownButtonFormField<String>(
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
              child: Text(item, style: TextStyle(color: colorScheme.onSurface)),
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
        if ((selectedCategory == 'Base' || selectedCategory == 'Ligand') &&
            !identityLocked &&
            (value == null || value.trim().isEmpty)) {
          return 'Select subcategory';
        }
        return null;
      },
    );
  }

  Widget _buildCarbonCountField({required bool identityLocked}) {
    final colorScheme = context.colorScheme;

    return TextFormField(
      controller: carbonCountController,
      readOnly: identityLocked,
      keyboardType: TextInputType.number,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: inputDecoration('Carbon Count'),
      onChanged: (_) async {
        if (!identityLocked) {
          setState(() {
            sheetTabController.text = _getSheetTabFromSelection();
          });
          await _generateLabelForNewChemical();
        }
      },
      validator: (value) {
        if (!identityLocked && selectedCategory == 'General') {
          final count = int.tryParse(value?.trim() ?? '');
          if (count == null || count <= 0) {
            return 'Enter valid carbon count';
          }
        }
        return null;
      },
    );
  }

  Widget _buildCatalystMetalField({required bool identityLocked}) {
    final colorScheme = context.colorScheme;

    return TextFormField(
      controller: catalystMetalController,
      readOnly: identityLocked,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: inputDecoration('Catalyst Metal (Pd, Cu, Fe...)'),
      onChanged: (_) async {
        if (!identityLocked) {
          await _generateLabelForNewChemical();
        }
      },
      validator: (value) {
        if (!identityLocked && selectedCategory == 'Catalyst') {
          if (value == null || value.trim().isEmpty) {
            return 'Enter catalyst metal';
          }
        }
        return null;
      },
    );
  }

  Widget _buildFormulaField() {
    final colorScheme = context.colorScheme;

    return TextFormField(
      controller: formulaController,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: inputDecoration('Molecular Formula'),
    );
  }

  Widget _buildMolecularWeightField() {
    final colorScheme = context.colorScheme;

    return TextFormField(
      controller: molWtController,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: inputDecoration('Molecular Weight'),
    );
  }

  Widget _buildBrandDropdown() {
    return _buildCustomizableDropdown(
      label: 'Brand',
      value: selectedBrand,
      builtInOptions: brandOptions,
      customOptions: _brandDropdownCustomOptions(),
      hiddenOptions: hiddenChemicalBrandOptions,
      onChanged: (value) {
        setState(() {
          selectedBrand = value;
        });
      },
      validator: (value) => _validateRequiredDropdown(value, 'Select brand'),
    );
  }

  Widget _buildCatalogNumberField() {
    final colorScheme = context.colorScheme;

    return TextFormField(
      controller: catNumberController,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: inputDecoration('Catalog Number'),
    );
  }

  Widget _buildVendorDropdown() {
    return _buildCustomizableDropdown(
      label: 'Vendor',
      value: selectedVendor,
      builtInOptions: vendorOptions,
      customOptions: customVendorOptions,
      onChanged: (value) {
        setState(() {
          selectedVendor = value;
        });
      },
      validator: (value) => _validateRequiredDropdown(value, 'Select vendor'),
    );
  }

  Widget _buildQuantityField() {
    final colorScheme = context.colorScheme;

    return TextFormField(
      controller: quantityController,
      keyboardType: TextInputType.number,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: inputDecoration('Number of bottles'),
      validator: (value) =>
          _validatePositiveInteger(value, 'Enter valid bottle count'),
    );
  }

  Widget _buildBottleSizeRow() {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: bottleSizeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: colorScheme.onSurface),
            decoration: inputDecoration('Bottle size/amount'),
            validator: (value) =>
                _validatePositiveDecimal(value, 'Enter valid bottle size'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            key: ValueKey('bottle_unit_$selectedBottleUnit'),
            initialValue: selectedBottleUnit,
            dropdownColor: palette.panel,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: inputDecoration('Unit'),
            items: bottleUnitOptions
                .map(
                  (unit) => DropdownMenuItem<String>(
                    value: unit,
                    child: Text(
                      unit,
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                selectedBottleUnit = value;
              });
            },
            validator: (value) =>
                _validateRequiredDropdown(value, 'Select bottle size unit'),
          ),
        ),
      ],
    );
  }

  Widget _buildGeneratedLabelField() {
    final colorScheme = context.colorScheme;

    return TextFormField(
      controller: labelController,
      readOnly: true,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: inputDecoration('Generated Label'),
      validator: _validateGeneratedLabel,
    );
  }

  Widget _buildLocationDropdown() {
    return _buildCustomizableDropdown(
      label: 'Location',
      value: selectedLocation,
      builtInOptions: locationOptions,
      customOptions: _locationDropdownCustomOptions(),
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
    );
  }

  Widget _buildTextureDropdown() {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return DropdownButtonFormField<String>(
      key: ValueKey('texture_${selectedTexture ?? ''}'),
      initialValue: selectedTexture,
      dropdownColor: palette.panel,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: inputDecoration('Texture / Physical State'),
      items: textureOptions
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: TextStyle(color: colorScheme.onSurface)),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          selectedTexture = value;
        });
      },
      validator: (value) =>
          _validateRequiredDropdown(value, 'Select texture / physical state'),
    );
  }

  Widget _buildArrivalDateField() {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return TextFormField(
      controller: arrivalDateController,
      readOnly: true,
      onTap: _pickArrivalDate,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: inputDecoration('Arrival Date').copyWith(
        suffixIcon: Icon(
          Icons.calendar_today_rounded,
          color: palette.mutedText,
          size: 20,
        ),
      ),
      validator: _validateArrivalDate,
    );
  }

  Widget _buildOrderedByStatusRow({
    required IconData icon,
    required String message,
    required Color color,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _buildOrderedByField() {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final safeSelectedUid =
        _orderedByMembers.any((member) => member.uid == _selectedOrderedByUid)
        ? _selectedOrderedByUid
        : null;
    final isDisabled =
        _isLoadingOrderedByMembers ||
        _orderedByMembersError != null ||
        _orderedByMembers.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(
            'ordered_by_${_orderedByMembersLabId}_${safeSelectedUid ?? ''}_${_orderedByMembers.length}',
          ),
          initialValue: safeSelectedUid,
          dropdownColor: palette.panel,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: inputDecoration('Ordered By'),
          hint: Text(
            'Select lab member',
            style: TextStyle(color: palette.mutedText),
          ),
          items: _orderedByMembers
              .map(
                (member) => DropdownMenuItem<String>(
                  value: member.uid,
                  child: Text(
                    member.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                ),
              )
              .toList(),
          onChanged: isDisabled
              ? null
              : (value) {
                  setState(() {
                    _selectedOrderedByUid = value;
                    if (value != null) {
                      _legacyOrderedByName = '';
                    }
                  });
                },
          validator: _validateOrderedBySelection,
        ),
        if (_isLoadingOrderedByMembers) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const LinearProgressIndicator(minHeight: 3),
          ),
        ] else if (_orderedByMembersError != null)
          _buildOrderedByStatusRow(
            icon: Icons.error_outline,
            message: _orderedByMembersError!,
            color: colorScheme.error,
            trailing: TextButton(
              onPressed: _loadOrderedByMembers,
              child: const Text('Retry'),
            ),
          )
        else if (_orderedByMembers.isEmpty)
          _buildOrderedByStatusRow(
            icon: Icons.group_off_outlined,
            message: 'No active lab members are available.',
            color: palette.mutedText,
          ),
        if (_legacyOrderedByName.trim().isNotEmpty &&
            safeSelectedUid == null) ...[
          _buildOrderedByStatusRow(
            icon: Icons.history_outlined,
            message:
                'Previously recorded: $_legacyOrderedByName. Select an active lab member to continue.',
            color: palette.mutedText,
          ),
        ],
      ],
    );
  }

  Widget _buildSheetTabField({required bool isEditMode}) {
    final colorScheme = context.colorScheme;

    return TextFormField(
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
    );
  }

  Widget _buildHelperCard(String helperText) {
    final palette = context.labmate;

    return Container(
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
    );
  }

  Widget _buildRegenerateLabelButton() {
    final colorScheme = context.colorScheme;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isGeneratingLabel ? null : _generateLabelForNewChemical,
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(isGeneratingLabel ? 'Generating...' : 'Regenerate Label'),
      ),
    );
  }

  Widget _buildSubmitButton(String submitLabel) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isSaving ? null : submitChemicalEntry,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF14B8A6),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(submitLabel, style: const TextStyle(fontSize: 15)),
      ),
    );
  }

  List<Widget> _buildIdentityFields({
    required bool identityLocked,
    required bool isEditMode,
    required bool includeExistingBanner,
    required bool includeGeneratedLabel,
    required bool includeSheetTab,
    required bool includeRegenerateButton,
  }) {
    final subcategories = getSubcategories(selectedCategory);

    return [
      _buildCasField(),
      const SizedBox(height: 14),
      _buildFetchFromCasButton(),
      const SizedBox(height: 14),
      _buildChemicalNameField(),
      if (isFetchingCas ||
          (_chemicalLookupMessage?.trim().isNotEmpty ?? false)) ...[
        const SizedBox(height: 10),
        _buildChemicalLookupStatus(),
      ],
      if (includeExistingBanner &&
          selectedEntryType == 'Existing Chemical') ...[
        const SizedBox(height: 14),
        _buildExistingCasBanner(),
      ],
      const SizedBox(height: 14),
      _buildChemicalTypeDropdown(identityLocked: identityLocked),
      const SizedBox(height: 14),
      if (_isCustomCategorySelected) ...[
        _buildCustomTextField(
          controller: customCategoryController,
          label: 'Custom chemical type',
          errorText: 'Enter custom chemical type',
          onChanged: (_) {
            setState(() {
              sheetTabController.text = _getSheetTabFromSelection();
              _clearFunctionalGroupsWhenUnavailable();
            });
          },
        ),
        const SizedBox(height: 14),
      ],
      if (subcategories.isNotEmpty) ...[
        _buildSubcategoryDropdown(
          identityLocked: identityLocked,
          subcategories: subcategories,
        ),
        const SizedBox(height: 14),
      ],
      if (selectedCategory == 'General') ...[
        _buildCarbonCountField(identityLocked: identityLocked),
        const SizedBox(height: 14),
      ],
      if (selectedCategory == 'Catalyst') ...[
        _buildCatalystMetalField(identityLocked: identityLocked),
        const SizedBox(height: 14),
      ],
      _buildFormulaField(),
      const SizedBox(height: 14),
      _buildMolecularWeightField(),
      if (includeGeneratedLabel) ...[
        const SizedBox(height: 14),
        _buildGeneratedLabelField(),
      ],
      if (includeRegenerateButton && !identityLocked) ...[
        const SizedBox(height: 14),
        _buildRegenerateLabelButton(),
      ],
      if (includeSheetTab) ...[
        const SizedBox(height: 14),
        _buildSheetTabField(isEditMode: isEditMode),
      ],
    ];
  }

  List<Widget> _buildPurchaseStorageFields({
    required bool isEditMode,
    required bool includeGeneratedLabel,
    required bool includeFunctionalGroups,
    required bool includeSheetTab,
    bool useInlineManageHeaders = false,
  }) {
    return [
      if (useInlineManageHeaders)
        _sectionHeaderWithAction(
          title: 'Brand',
          actionLabel: 'Brand',
          onPressed: _showManageBrandOptionsDialog,
        )
      else
        _buildManageOptionsButton(
          label: 'Brand',
          onPressed: _showManageBrandOptionsDialog,
        ),
      const SizedBox(height: 6),
      _buildBrandDropdown(),
      const SizedBox(height: 14),
      if (_isCustomBrandSelected) ...[
        _buildCustomTextField(
          controller: brandController,
          label: 'Custom brand',
          errorText: 'Enter custom brand',
        ),
        const SizedBox(height: 14),
      ],
      _buildCatalogNumberField(),
      const SizedBox(height: 14),
      _buildVendorDropdown(),
      const SizedBox(height: 14),
      if (_isCustomVendorSelected) ...[
        _buildCustomTextField(
          controller: vendorController,
          label: 'Custom vendor',
          errorText: 'Enter custom vendor',
        ),
        const SizedBox(height: 14),
      ],
      _buildQuantityField(),
      const SizedBox(height: 14),
      _buildBottleSizeRow(),
      if (includeGeneratedLabel) ...[
        const SizedBox(height: 14),
        _buildGeneratedLabelField(),
      ],
      const SizedBox(height: 8),
      if (useInlineManageHeaders)
        _sectionHeaderWithAction(
          title: 'Location',
          actionLabel: 'Location',
          onPressed: _showManageLocationOptionsDialog,
        )
      else
        _buildManageOptionsButton(
          label: 'Location',
          onPressed: _showManageLocationOptionsDialog,
        ),
      const SizedBox(height: 6),
      _buildLocationDropdown(),
      const SizedBox(height: 14),
      if (_isCustomLocationSelected) ...[
        _buildCustomTextField(
          controller: customLocationController,
          label: 'Custom location',
          errorText: 'Enter custom location',
        ),
        const SizedBox(height: 14),
      ],
      if (includeFunctionalGroups) ...[
        _buildFunctionalGroupSelector(),
        const SizedBox(height: 14),
      ],
      _buildTextureDropdown(),
      const SizedBox(height: 14),
      _buildArrivalDateField(),
      const SizedBox(height: 14),
      _buildOrderedByField(),
      if (includeSheetTab) ...[
        const SizedBox(height: 14),
        _buildSheetTabField(isEditMode: isEditMode),
      ],
    ];
  }

  List<Widget> _buildBottomFields({
    required bool identityLocked,
    required String helperText,
    required String submitLabel,
    bool includeFunctionalGroups = true,
  }) {
    return [
      if (includeFunctionalGroups) ...[
        _buildFunctionalGroupSelector(),
        const SizedBox(height: 14),
      ],
      _buildHelperCard(helperText),
      const SizedBox(height: 18),
      if (!identityLocked) ...[
        _buildRegenerateLabelButton(),
        const SizedBox(height: 14),
      ],
      _buildSubmitButton(submitLabel),
    ];
  }

  Widget _buildWideFunctionalGroupsSection() {
    return _sectionCard(
      title: 'Functional Groups',
      children: [_buildFunctionalGroupSelector(showTitle: false)],
    );
  }

  List<Widget> _buildWideBottomActions({
    required String helperText,
    required String submitLabel,
  }) {
    return [
      _buildHelperCard(helperText),
      const SizedBox(height: 18),
      _buildSubmitButton(submitLabel),
    ];
  }

  Widget _buildWideIdentityColumn({
    required bool isEditMode,
    required bool identityLocked,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionCard(
          title: 'Chemical Identity',
          children: _buildIdentityFields(
            identityLocked: identityLocked,
            isEditMode: isEditMode,
            includeExistingBanner: false,
            includeGeneratedLabel: true,
            includeSheetTab: false,
            includeRegenerateButton: true,
          ),
        ),
        const SizedBox(height: 16),
        _buildWideFunctionalGroupsSection(),
      ],
    );
  }

  Widget _buildNarrowFormContent({
    required bool isEditMode,
    required bool identityLocked,
    required String helperText,
    required String submitLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.order != null) ...[
          _buildDeliveredOrderBanner(),
          const SizedBox(height: 14),
        ],
        ..._buildIdentityFields(
          identityLocked: identityLocked,
          isEditMode: isEditMode,
          includeExistingBanner: true,
          includeGeneratedLabel: false,
          includeSheetTab: false,
          includeRegenerateButton: false,
        ),
        const SizedBox(height: 8),
        ..._buildPurchaseStorageFields(
          isEditMode: isEditMode,
          includeGeneratedLabel: true,
          includeFunctionalGroups: true,
          includeSheetTab: true,
        ),
        const SizedBox(height: 14),
        ..._buildBottomFields(
          identityLocked: identityLocked,
          helperText: helperText,
          submitLabel: submitLabel,
          includeFunctionalGroups: false,
        ),
      ],
    );
  }

  Widget _buildWideFormContent({
    required bool isEditMode,
    required bool identityLocked,
    required String helperText,
    required String submitLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.order != null) ...[
          _buildDeliveredOrderBanner(),
          const SizedBox(height: 14),
        ],
        if (selectedEntryType == 'Existing Chemical') ...[
          _buildExistingCasBanner(),
          const SizedBox(height: 14),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildWideIdentityColumn(
                isEditMode: isEditMode,
                identityLocked: identityLocked,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _sectionCard(
                title: 'Purchase & Storage',
                children: _buildPurchaseStorageFields(
                  isEditMode: isEditMode,
                  includeGeneratedLabel: false,
                  includeFunctionalGroups: false,
                  includeSheetTab: true,
                  useInlineManageHeaders: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ..._buildWideBottomActions(
          helperText: helperText,
          submitLabel: submitLabel,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.editChemical != null;
    final isExisting = !isEditMode && selectedEntryType == 'Existing Chemical';
    final identityLocked = isExisting || isEditMode;
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 900;

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1120),
                            child: isWide
                                ? _buildWideFormContent(
                                    isEditMode: isEditMode,
                                    identityLocked: identityLocked,
                                    helperText: helperText,
                                    submitLabel: submitLabel,
                                  )
                                : _buildNarrowFormContent(
                                    isEditMode: isEditMode,
                                    identityLocked: identityLocked,
                                    helperText: helperText,
                                    submitLabel: submitLabel,
                                  ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _OrderedByMemberOption {
  final String uid;
  final String displayName;
  final String userName;
  final String email;

  const _OrderedByMemberOption({
    required this.uid,
    required this.displayName,
    required this.userName,
    required this.email,
  });

  bool matchesStoredValue(String value) {
    final normalizedValue = value.trim().toLowerCase();
    if (normalizedValue.isEmpty) {
      return false;
    }

    return normalizedValue == displayName.trim().toLowerCase() ||
        normalizedValue == userName.trim().toLowerCase() ||
        normalizedValue == email.trim().toLowerCase() ||
        normalizedValue == uid.trim().toLowerCase();
  }
}

class _OptionValueDialog extends StatefulWidget {
  final String title;
  final String label;
  final String initialValue;

  const _OptionValueDialog({
    required this.title,
    required this.label,
    this.initialValue = '',
  });

  @override
  State<_OptionValueDialog> createState() => _OptionValueDialogState();
}

class _OptionValueDialogState extends State<_OptionValueDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _CustomFunctionalGroupDialog extends StatefulWidget {
  const _CustomFunctionalGroupDialog();

  @override
  State<_CustomFunctionalGroupDialog> createState() =>
      _CustomFunctionalGroupDialogState();
}

class _CustomFunctionalGroupDialogState
    extends State<_CustomFunctionalGroupDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add functional group'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Functional group name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
