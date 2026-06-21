import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/order_model.dart';
import '../services/activity_service.dart';
import '../services/consumables_inventory_service.dart';
import '../services/order_service.dart';
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
  final OrderService orderService = OrderService();
  final ConsumablesInventoryService _consumablesInventoryService =
      ConsumablesInventoryService();

  late final TextEditingController consumableTypeController;
  late final TextEditingController quantityController;
  late final TextEditingController brandController;
  late final TextEditingController vendorController;
  late final TextEditingController customCategoryController;
  late final TextEditingController customLocationController;
  late final TextEditingController modeOfPurchaseController;
  late final TextEditingController orderedByController;

  String? selectedCategory;
  String? selectedBrand;
  String? selectedVendor;
  String? selectedLocation;
  bool isSaving = false;

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
    orderedByController = TextEditingController(text: order.orderedBy);

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
  }

  @override
  void dispose() {
    consumableTypeController.dispose();
    quantityController.dispose();
    brandController.dispose();
    vendorController.dispose();
    customCategoryController.dispose();
    customLocationController.dispose();
    modeOfPurchaseController.dispose();
    orderedByController.dispose();
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

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Not available';

    final date = timestamp.toDate();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _inventoryKey(String consumableType) {
    return consumableType.trim().toLowerCase();
  }

  double? _readQuantityNumber(String quantity) {
    final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(quantity.trim());
    if (match == null) {
      return null;
    }

    return double.tryParse(match.group(0) ?? '');
  }

  String _formatQuantityNumber(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toStringAsFixed(0);
    }

    return quantity.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  Future<void> submitConsumableEntry() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSaving = true;
    });

    try {
      final order = widget.order;
      final labId = AppState.instance.resolveWriteLabId(order.labId);
      final consumableType = _resolvedConsumableType;
      final quantityAddedText = quantityController.text.trim();
      final quantityAdded = _readQuantityNumber(quantityAddedText);
      final brand = _resolvedBrand;
      final vendor = _resolvedVendor;
      final location = _resolvedLocation;
      final modeOfPurchase = modeOfPurchaseController.text.trim();
      final orderedBy = orderedByController.text.trim();
      final timestamp = Timestamp.now();

      if (consumableType.isEmpty) {
        throw Exception('Consumable type is required.');
      }

      if (quantityAdded == null || quantityAdded <= 0) {
        throw Exception('Quantity must be numeric and greater than 0.');
      }

      final firestore = FirebaseFirestore.instance;
      final inventoryRef = firestore.collection('consumables_inventory');
      final purchaseLogRef = firestore
          .collection('consumable_purchase_logs')
          .doc();

      final existingSnapshot = await inventoryRef.get();
      final targetKey = _inventoryKey(consumableType);
      QueryDocumentSnapshot<Map<String, dynamic>>? existingDoc;

      for (final doc in existingSnapshot.docs) {
        final data = doc.data();
        final docLabId = (data['labId'] ?? '').toString().trim();
        if (docLabId != labId) {
          continue;
        }

        final docKey = _inventoryKey((data['consumableType'] ?? '').toString());
        if (docKey == targetKey) {
          existingDoc = doc;
          break;
        }
      }

      late final String inventoryId;
      late final double previousQuantity;
      late final double newQuantity;

      if (existingDoc == null) {
        final newInventoryRef = inventoryRef.doc();
        inventoryId = newInventoryRef.id;
        previousQuantity = 0;
        newQuantity = quantityAdded;

        await firestore.runTransaction((transaction) async {
          transaction.set(newInventoryRef, {
            'labId': labId,
            'mainType': 'consumable',
            'orderId': order.id,
            'latestOrderId': order.id,
            'requirementId': order.requirementId,
            'consumableType': consumableType,
            'quantity': _formatQuantityNumber(newQuantity),
            'isAggregate': true,
            'brand': brand,
            'latestBrand': brand,
            'vendor': vendor,
            'latestVendor': vendor,
            'location': location,
            'modeOfPurchase': modeOfPurchase,
            'orderedBy': orderedBy,
            'receivedBy': order.receivedBy,
            'deliveredAt': order.deliveredAt ?? timestamp,
            'createdAt': timestamp,
            'updatedAt': timestamp,
          });

          transaction.set(purchaseLogRef, {
            'labId': labId,
            'consumableInventoryId': inventoryId,
            'consumableType': consumableType,
            'quantityAdded': quantityAdded,
            'previousQuantity': previousQuantity,
            'newQuantity': newQuantity,
            'brand': brand,
            'vendor': vendor,
            'location': location,
            'modeOfPurchase': modeOfPurchase,
            'receivedBy': order.receivedBy,
            'deliveredAt': order.deliveredAt ?? timestamp,
            'sourceOrderId': order.id,
            'createdAt': timestamp,
            'createdBy': AppState.instance.authenticatedUserId,
            'actorName': AppState.instance.authenticatedUserName,
          });
        });
      } else {
        final matchedDoc = existingDoc;
        inventoryId = matchedDoc.id;

        await firestore.runTransaction((transaction) async {
          final freshSnapshot = await transaction.get(matchedDoc.reference);
          final freshData = freshSnapshot.data();
          if (freshData == null) {
            throw Exception('Existing consumable inventory item was removed.');
          }

          final currentQuantity = _readQuantityNumber(
            (freshData['quantity'] ?? '').toString(),
          );
          previousQuantity = currentQuantity ?? 0;
          newQuantity = previousQuantity + quantityAdded;

          transaction.update(matchedDoc.reference, {
            'quantity': _formatQuantityNumber(newQuantity),
            'isAggregate': true,
            'latestOrderId': order.id,
            'requirementId': order.requirementId,
            if (brand.isNotEmpty) 'brand': brand,
            'latestBrand': brand,
            if (vendor.isNotEmpty) 'vendor': vendor,
            'latestVendor': vendor,
            if (location.isNotEmpty) 'location': location,
            'modeOfPurchase': modeOfPurchase,
            'orderedBy': orderedBy,
            'receivedBy': order.receivedBy,
            'deliveredAt': order.deliveredAt ?? timestamp,
            'updatedAt': timestamp,
          });

          transaction.set(purchaseLogRef, {
            'labId': labId,
            'consumableInventoryId': inventoryId,
            'consumableType': consumableType,
            'quantityAdded': quantityAdded,
            'previousQuantity': previousQuantity,
            'newQuantity': newQuantity,
            'brand': brand,
            'vendor': vendor,
            'location': location,
            'modeOfPurchase': modeOfPurchase,
            'receivedBy': order.receivedBy,
            'deliveredAt': order.deliveredAt ?? timestamp,
            'sourceOrderId': order.id,
            'createdAt': timestamp,
            'createdBy': AppState.instance.authenticatedUserId,
            'actorName': AppState.instance.authenticatedUserName,
          });
        });
      }

      await orderService.markInventoryAdded(docId: order.id);
      await ActivityService().addActivity(
        labId: labId,
        type: 'consumable_inventory_added',
        message: 'Consumable entry confirmed for $consumableType',
        actorName: AppState.instance.authenticatedUserName,
        createdBy: AppState.instance.authenticatedUserId,
        relatedId: inventoryId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consumable added to inventory')),
      );

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
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
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: quantityController,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: inputDecoration('Quantity'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter quantity';
                  }
                  return null;
                },
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
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: orderedByController,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: inputDecoration('Ordered By'),
              ),
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

class _ConsumableTypeDraft {
  final String? category;
  final String variant;

  const _ConsumableTypeDraft({required this.category, required this.variant});
}
