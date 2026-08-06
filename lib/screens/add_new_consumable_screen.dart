import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/lab_membership_model.dart';
import '../models/order_model.dart';
import '../models/user_profile.dart';
import '../services/activity_service.dart';
import '../services/consumables_inventory_service.dart';
import '../services/lab_membership_service.dart';
import '../services/order_service.dart';
import '../services/user_profile_service.dart';
import '../theme/labmate_theme.dart';

class AddNewConsumableScreen extends StatefulWidget {
  final OrderModel order;

  const AddNewConsumableScreen({super.key, required this.order});

  @override
  State<AddNewConsumableScreen> createState() => _AddNewConsumableScreenState();
}

class _AddNewConsumableScreenState extends State<AddNewConsumableScreen> {
  static const String _customOption = 'Add custom...';

  final _formKey = GlobalKey<FormState>();
  final ConsumablesInventoryService _consumablesInventoryService =
      ConsumablesInventoryService();
  final LabMembershipService _labMembershipService = LabMembershipService();
  final UserProfileService _userProfileService = UserProfileService();

  late final TextEditingController consumableTypeController;
  late final TextEditingController quantityController;
  late final TextEditingController brandController;
  late final TextEditingController vendorController;
  late final TextEditingController customCategoryController;
  late final TextEditingController customLocationController;
  late final TextEditingController modeOfPurchaseController;

  String? selectedCategory;
  String? selectedBrand;
  String? selectedVendor;
  String? selectedLocation;
  String? _selectedOrderedByUid;
  String _initialOrderedByName = '';
  String _legacyOrderedByName = '';
  String _orderedByMembersLabId = '';
  bool isSaving = false;
  bool _isLoadingOrderedByMembers = false;
  String? _orderedByMembersError;
  int _orderedByMembersRequestId = 0;
  List<_OrderedByMemberOption> _orderedByMembers = const [];

  static const List<String> _categoryOptions = [
    'Gloves',
    'Syringes',
    'Balloons',
    'Needles',
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

  static const List<String> _brandOptions = [
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

  static const List<String> _vendorOptions = [
    'Merck',
    'Sigma',
    'Globe Scientific',
    'APJ Scientific',
    'Chemical House',
    'BLD Pharm',
    'Others',
  ];

  static const List<String> _locationOptions = [
    'Store Room',
    'Shelf',
    'Drawer',
    'Bench',
    'Refrigerator',
    'Freezer',
    'Desiccator',
    'Other',
  ];

  static const Map<String, List<String>> _categoryAliases = {
    'Gloves': ['glove', 'gloves'],
    'Syringes': ['syringe', 'syringes'],
    'Balloons': ['balloon', 'balloons'],
    'Needles': ['needle', 'needles'],
    'Filter Paper': ['filter paper'],
    'Silica': ['silica'],
    'TLC Plates': ['tlc', 'tlc plate', 'tlc plates'],
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

  List<String> customCategoryOptions = const [];
  List<String> customBrandOptions = const [];
  List<String> customVendorOptions = const [];
  List<String> customLocationOptions = const [];

  @override
  void initState() {
    super.initState();
    final order = widget.order;
    _initialOrderedByName = order.orderedBy.trim();
    _legacyOrderedByName = _initialOrderedByName;
    final parsedType = _parseConsumableType(
      order.consumableType.trim().isEmpty
          ? order.displayName
          : order.consumableType,
    );

    selectedCategory = parsedType.category;
    consumableTypeController = TextEditingController(text: parsedType.variant);
    quantityController = TextEditingController(text: order.quantity);
    brandController = TextEditingController();
    vendorController = TextEditingController();
    customCategoryController = TextEditingController();
    customLocationController = TextEditingController();
    modeOfPurchaseController = TextEditingController(
      text: order.modeOfPurchase,
    );

    _setDropdownSelection(
      value: order.brand,
      builtInOptions: _brandOptions,
      onKnownValue: (value) => selectedBrand = value,
      onCustomValue: (value) {
        selectedBrand = _customOption;
        brandController.text = value;
      },
    );

    _setDropdownSelection(
      value: order.vendor,
      builtInOptions: _vendorOptions,
      onKnownValue: (value) => selectedVendor = value,
      onCustomValue: (value) {
        selectedVendor = _customOption;
        vendorController.text = value;
      },
    );

    if (selectedCategory != null &&
        !_matchesAnyOption(selectedCategory!, _categoryOptions)) {
      customCategoryController.text = selectedCategory!;
      selectedCategory = _customOption;
    }

    _loadExistingDropdownOptions();
    AppState.instance.addListener(_handleAppStateChanged);
    _loadOrderedByMembers();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_handleAppStateChanged);
    consumableTypeController.dispose();
    quantityController.dispose();
    brandController.dispose();
    vendorController.dispose();
    customCategoryController.dispose();
    customLocationController.dispose();
    modeOfPurchaseController.dispose();
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

  _ConsumableTypeDraft _parseConsumableType(String value) {
    final cleanValue = value.trim();
    if (cleanValue.isEmpty) {
      return const _ConsumableTypeDraft(category: null, variant: '');
    }

    final parts = cleanValue.split(RegExp(r'\s*-\s*'));
    if (parts.length > 1) {
      final category = parts.first.trim();
      final variant = parts.sublist(1).join(' - ').trim();
      final knownCategory = _matchingCategory(category);
      return _ConsumableTypeDraft(
        category: knownCategory ?? category,
        variant: variant,
      );
    }

    final knownCategory = _matchingCategory(cleanValue);
    if (knownCategory != null) {
      final variant = _variantForCategory(cleanValue, knownCategory);
      return _ConsumableTypeDraft(category: knownCategory, variant: variant);
    }

    return _ConsumableTypeDraft(category: cleanValue, variant: '');
  }

  String? _matchingCategory(String value) {
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

  String _variantForCategory(String value, String category) {
    final aliases = _categoryAliases[category] ?? const <String>[];
    final normalized = value.trim().toLowerCase();

    for (final alias in aliases) {
      if (normalized == alias) {
        return '';
      }
      if (normalized.startsWith('$alias ')) {
        return value.trim().substring(alias.length).trim();
      }
    }

    return '';
  }

  String _categoryFromConsumableType(String value) {
    final draft = _parseConsumableType(value);
    final category = draft.category?.trim() ?? '';
    if (category.isEmpty || _matchesAnyOption(category, _categoryOptions)) {
      return '';
    }
    return category;
  }

  String get _resolvedCategory {
    if (selectedCategory == _customOption) {
      return customCategoryController.text.trim();
    }
    return selectedCategory?.trim() ?? '';
  }

  String get _resolvedConsumableType {
    final category = _resolvedCategory;
    final variant = consumableTypeController.text.trim();
    if (category.isEmpty) return variant;
    if (variant.isEmpty) return category;
    return '$category - $variant';
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

  bool get _isCustomCategorySelected => selectedCategory == _customOption;
  bool get _isCustomBrandSelected => selectedBrand == _customOption;
  bool get _isCustomVendorSelected => selectedVendor == _customOption;
  bool get _isCustomLocationSelected => selectedLocation == _customOption;

  void _showConfirmEntryValidationSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Please complete all required fields before confirming entry.',
        ),
      ),
    );
  }

  String? _validateRequiredText(String? value, String errorText) {
    if (value == null || value.trim().isEmpty) {
      return errorText;
    }
    return null;
  }

  String? _validateRequiredDropdown(String? value, String errorText) {
    return _validateRequiredText(value, errorText);
  }

  String _orderedByLabIdForCurrentEntry() {
    return AppState.instance.resolveWriteLabId(widget.order.labId).trim();
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

  String? _validatePositiveQuantity(String? value) {
    final cleanValue = value?.trim() ?? '';
    final parsedValue = _readQuantityNumber(cleanValue);
    if (cleanValue.isEmpty || parsedValue == null || parsedValue <= 0) {
      return 'Enter valid quantity';
    }
    return null;
  }

  Future<void> _loadExistingDropdownOptions() async {
    try {
      final docs = await _consumablesInventoryService
          .getConsumablesInventoryDocsOnce();
      if (!mounted) return;

      setState(() {
        customCategoryOptions = _distinctCustomValues(
          docs.map((doc) {
            final data = doc.data();
            return _categoryFromConsumableType(
              (data['consumableType'] ?? '').toString(),
            );
          }),
          _categoryOptions,
        );
        customBrandOptions = _distinctCustomValues(
          docs.expand((doc) {
            final data = doc.data();
            return [
              (data['brand'] ?? '').toString(),
              (data['latestBrand'] ?? '').toString(),
            ];
          }),
          _brandOptions,
        );
        customVendorOptions = _distinctCustomValues(
          docs.expand((doc) {
            final data = doc.data();
            return [
              (data['vendor'] ?? '').toString(),
              (data['latestVendor'] ?? '').toString(),
            ];
          }),
          _vendorOptions,
        );
        customLocationOptions = _distinctCustomValues(
          docs.map((doc) => (doc.data()['location'] ?? '').toString()),
          _locationOptions,
        );
      });
    } catch (_) {
      // Keep built-in options usable if lab-scoped custom values fail to load.
    }
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
    FormFieldValidator<String>? validator,
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
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required String errorText,
  }) {
    final colorScheme = context.colorScheme;
    return TextFormField(
      controller: controller,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: inputDecoration(label),
      textCapitalization: TextCapitalization.words,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return errorText;
        }
        return null;
      },
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

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Not available';

    final date = timestamp.toDate();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  double? _readQuantityNumber(String quantity) {
    final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(quantity.trim());
    if (match == null) {
      return null;
    }

    return double.tryParse(match.group(0) ?? '');
  }

  Future<void> submitConsumableEntry() async {
    if (isSaving) return;

    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      _showConfirmEntryValidationSnackBar();
      return;
    }

    final order = widget.order;
    final labId = AppState.instance.resolveWriteLabId(order.labId);
    final consumableType = _resolvedConsumableType;
    final quantityAddedText = quantityController.text.trim();
    final quantityAdded = _readQuantityNumber(quantityAddedText);
    final brand = _resolvedBrand;
    final vendor = _resolvedVendor;
    final location = _resolvedLocation;
    final modeOfPurchase = modeOfPurchaseController.text.trim();

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

    final orderedBy = orderedByMember.displayName;

    if (consumableType.isEmpty) {
      _showConfirmEntryValidationSnackBar();
      return;
    }

    if (quantityAdded == null || quantityAdded <= 0) {
      _showConfirmEntryValidationSnackBar();
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final confirmation = await _consumablesInventoryService
          .confirmDeliveredOrder(
            order: order,
            labId: labId,
            consumableType: consumableType,
            quantityAdded: quantityAdded,
            brand: brand,
            vendor: vendor,
            location: location,
            modeOfPurchase: modeOfPurchase,
            orderedBy: orderedBy,
            inventoryAddedBy: AppState.instance.authenticatedUserId,
          );

      try {
        await ActivityService().addActivity(
          labId: labId,
          type: 'consumable_inventory_added',
          message: 'Consumable entry confirmed for $consumableType',
          actorName: AppState.instance.authenticatedUserName,
          createdBy: AppState.instance.authenticatedUserId,
          relatedId: confirmation.inventoryId,
        );
      } catch (error, stackTrace) {
        debugPrint('Failed to log consumable inventory activity: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consumable added to inventory')),
      );

      Navigator.pop(context);
    } on OrderInventoryException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error, stackTrace) {
      debugPrint('Failed to add consumable order to inventory: $error');
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

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Add New Consumable')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.panel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  'Prefilled from the delivered consumable order. Review the basic details, edit if needed, and confirm entry to create the consumables inventory record.',
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildCustomizableDropdown(
                label: 'Category',
                value: selectedCategory,
                builtInOptions: _categoryOptions,
                customOptions: customCategoryOptions,
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Select category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              if (_isCustomCategorySelected) ...[
                _buildCustomTextField(
                  controller: customCategoryController,
                  label: 'Custom category',
                  errorText: 'Enter custom category',
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: consumableTypeController,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: inputDecoration('Specification / Size'),
                validator: (value) =>
                    _validateRequiredText(value, 'Enter specification / size'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: quantityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(color: colorScheme.onSurface),
                decoration: inputDecoration('Quantity'),
                validator: _validatePositiveQuantity,
              ),
              const SizedBox(height: 14),
              _buildCustomizableDropdown(
                label: 'Brand',
                value: selectedBrand,
                builtInOptions: _brandOptions,
                customOptions: customBrandOptions,
                onChanged: (value) {
                  setState(() {
                    selectedBrand = value;
                  });
                },
                validator: (value) =>
                    _validateRequiredDropdown(value, 'Select brand'),
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
                builtInOptions: _vendorOptions,
                customOptions: customVendorOptions,
                onChanged: (value) {
                  setState(() {
                    selectedVendor = value;
                  });
                },
                validator: (value) =>
                    _validateRequiredDropdown(value, 'Select vendor'),
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
              _buildCustomizableDropdown(
                label: 'Storage Location',
                value: selectedLocation,
                builtInOptions: _locationOptions,
                customOptions: customLocationOptions,
                onChanged: (value) {
                  setState(() {
                    selectedLocation = value;
                  });
                },
                validator: (value) =>
                    _validateRequiredDropdown(value, 'Select storage location'),
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
              TextFormField(
                controller: modeOfPurchaseController,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: inputDecoration('Mode of Purchase'),
                validator: (value) =>
                    _validateRequiredText(value, 'Enter mode of purchase'),
              ),
              const SizedBox(height: 14),
              _buildOrderedByField(),
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
                      'Delivery Details',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Received By: ${order.receivedBy.trim().isEmpty ? '-' : order.receivedBy}',
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Delivered On: ${_formatDate(order.deliveredAt)}',
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving ? null : submitConsumableEntry,
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
                      : const Text(
                          'Confirm Entry',
                          style: TextStyle(fontSize: 15),
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

class _ConsumableTypeDraft {
  final String? category;
  final String variant;

  const _ConsumableTypeDraft({required this.category, required this.variant});
}
