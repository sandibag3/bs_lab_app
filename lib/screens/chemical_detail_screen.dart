import 'package:flutter/material.dart';
import '../models/chemical_model.dart';
import '../services/inventory_service.dart';
import '../services/pubchem_service.dart';
import '../theme/labmate_theme.dart';
import '../utils/dropdown_option_utils.dart';
import '../widgets/responsive_page_container.dart';
import 'add_new_chemical_screen.dart';

class ChemicalDetailScreen extends StatefulWidget {
  final ChemicalModel chemical;
  final List<ChemicalModel>? navigationChemicals;
  final int? navigationIndex;

  const ChemicalDetailScreen({
    super.key,
    required this.chemical,
    this.navigationChemicals,
    this.navigationIndex,
  });

  @override
  State<ChemicalDetailScreen> createState() => _ChemicalDetailScreenState();
}

class _ChemicalDetailScreenState extends State<ChemicalDetailScreen>
    with SingleTickerProviderStateMixin {
  final InventoryService inventoryService = InventoryService();
  final PubChemService pubChemService = PubChemService();
  static const List<String> _allowedBottleStatuses = [
    'available',
    'low',
    'finished',
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
  static const List<String> _locationOptions = [
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
  static const List<String> _textureOptions = [
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

  late Future<PubChemChemicalDetails?> pubChemFuture;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  late ChemicalModel _currentChemical;
  int? _currentNavigationIndex;
  String? editingBottleId;
  List<String> customBrandOptions = const [];
  List<String> customLocationOptions = const [];
  List<String> customTextureOptions = const [];
  final TextEditingController editBrandController = TextEditingController();
  final TextEditingController editQuantityController = TextEditingController();
  final TextEditingController editLocationController = TextEditingController();
  final TextEditingController editTextureController = TextEditingController();
  final TextEditingController editCatalogController = TextEditingController();
  final TextEditingController editOrderedByController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentChemical = widget.chemical;
    _currentNavigationIndex = widget.navigationIndex;
    pubChemFuture = pubChemService.fetchByCas(_currentChemical.cas.trim());
    _loadExistingDropdownOptions();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _rotateAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    editBrandController.dispose();
    editQuantityController.dispose();
    editLocationController.dispose();
    editTextureController.dispose();
    editCatalogController.dispose();
    editOrderedByController.dispose();
    super.dispose();
  }

  Future<void> _openAddBottle() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddNewChemicalScreen(manualPrefill: _currentChemical),
      ),
    );
  }

  bool get _hasNavigationContext {
    final items = widget.navigationChemicals;
    final index = _currentNavigationIndex;
    return items != null &&
        items.isNotEmpty &&
        index != null &&
        index >= 0 &&
        index < items.length;
  }

  bool get _canGoPrevious {
    return _hasNavigationContext && _currentNavigationIndex! > 0;
  }

  bool get _canGoNext {
    return _hasNavigationContext &&
        _currentNavigationIndex! < widget.navigationChemicals!.length - 1;
  }

  void _navigateToChemical(int nextIndex) {
    final items = widget.navigationChemicals;
    if (items == null || nextIndex < 0 || nextIndex >= items.length) {
      return;
    }

    final nextChemical = items[nextIndex];
    setState(() {
      _currentNavigationIndex = nextIndex;
      _currentChemical = nextChemical;
      pubChemFuture = pubChemService.fetchByCas(nextChemical.cas.trim());
      editingBottleId = null;
      editBrandController.clear();
      editQuantityController.clear();
      editLocationController.clear();
      editTextureController.clear();
      editCatalogController.clear();
      editOrderedByController.clear();
    });
  }

  String _normalizedOption(String value) {
    return value.trim().toLowerCase();
  }

  List<String> _distinctCustomValues(
    Iterable<String> values,
    Iterable<String> baseValues,
  ) {
    final baseNormalized = baseValues
        .map((value) => value.trim().toLowerCase())
        .toSet();
    const addCustomLabel = 'add custom...';
    final uniqueValues = <String, String>{};

    for (final value in values) {
      final trimmed = value.trim();
      final normalized = trimmed.toLowerCase();
      if (trimmed.isEmpty ||
          normalized == addCustomLabel ||
          baseNormalized.contains(normalized)) {
        continue;
      }
      uniqueValues.putIfAbsent(normalized, () => trimmed);
    }

    final items = uniqueValues.values.toList();
    items.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return items;
  }

  void _addCustomOption({
    required String value,
    required List<String> builtInOptions,
    required List<String> currentOptions,
    required ValueChanged<List<String>> setOptions,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final exists = [...builtInOptions, ...currentOptions].any(
      (option) => _normalizedOption(option) == _normalizedOption(trimmed),
    );
    if (exists) {
      return;
    }

    setState(() {
      setOptions(
        _distinctCustomValues([...currentOptions, trimmed], builtInOptions),
      );
    });
  }

  Future<void> _loadExistingDropdownOptions() async {
    try {
      final chemicals = await inventoryService.getChemicalsOnce();
      if (!mounted) return;

      setState(() {
        customBrandOptions = _distinctCustomValues(
          chemicals.map((chemical) => chemical.brand),
          _brandOptions,
        );
        customLocationOptions = _distinctCustomValues(
          chemicals.map((chemical) => chemical.location),
          _locationOptions,
        );
        customTextureOptions = _distinctCustomValues(
          chemicals.map((chemical) => chemical.texture),
          _textureOptions,
        );
      });
    } catch (_) {
      // Built-in dropdown options remain available if lab-scoped options fail.
    }
  }

  void _markBottleEditing(ChemicalModel bottle) {
    setState(() {
      editingBottleId = bottle.id;
      editBrandController.text = bottle.brand;
      editQuantityController.text = bottle.quantity;
      editLocationController.text = bottle.location;
      editTextureController.text = bottle.texture;
      editCatalogController.text = bottle.catNumber;
      editOrderedByController.text = bottle.orderedBy;
    });
  }

  void _cancelBottleEditing() {
    setState(() {
      editingBottleId = null;
      editBrandController.clear();
      editQuantityController.clear();
      editLocationController.clear();
      editTextureController.clear();
      editCatalogController.clear();
      editOrderedByController.clear();
    });
  }

  Future<void> _saveBottleDetails(ChemicalModel bottle) async {
    try {
      await inventoryService.updateBottleDetails(
        bottleId: bottle.id,
        brand: editBrandController.text,
        quantity: editQuantityController.text,
        location: editLocationController.text,
        texture: editTextureController.text,
        catNumber: editCatalogController.text,
        orderedBy: editOrderedByController.text,
      );

      if (!mounted) return;
      _cancelBottleEditing();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bottle details updated.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update bottle details. Please try again.'),
        ),
      );
    }
  }

  Future<void> _setActiveBottle(ChemicalModel bottle) async {
    try {
      await inventoryService.setActiveBottle(
        labId: bottle.labId,
        cas: bottle.cas,
        bottleId: bottle.id,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Active bottle updated.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update active bottle. Please try again.'),
        ),
      );
    }
  }

  Widget _activeBottleBadge() {
    const activeColor = Color(0xFF14B8A6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: activeColor.withValues(alpha: 0.35)),
      ),
      child: const Text(
        'Active',
        style: TextStyle(
          color: activeColor,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _activeBottleControl(ChemicalModel bottle) {
    if (bottle.isActiveBottle) {
      return _activeBottleBadge();
    }

    return TextButton(
      onPressed: () => _setActiveBottle(bottle),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text(
        'Set active',
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _editingBadge() {
    final colorScheme = context.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.28)),
      ),
      child: Text(
        'Editing',
        style: TextStyle(
          color: colorScheme.primary,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _editBottleButton(ChemicalModel bottle) {
    final palette = context.labmate;

    return IconButton(
      tooltip: 'Edit bottle info',
      onPressed: () => _markBottleEditing(bottle),
      icon: Icon(Icons.edit_outlined, size: 17, color: palette.mutedText),
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  InputDecoration _inlineEditDecoration(String label) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: palette.mutedText,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
      floatingLabelStyle: TextStyle(
        color: colorScheme.primary,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
      isDense: true,
      filled: true,
      fillColor: palette.panel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: colorScheme.primary),
      ),
    );
  }

  Widget _inlineEditField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: TextStyle(
        color: context.colorScheme.onSurface,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      cursorHeight: 16,
      decoration: _inlineEditDecoration(label),
    );
  }

  Future<String?> _showInlineCustomValueDialog(String label) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add $label'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: label),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) {
                Navigator.of(context).pop(trimmed);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.isNotEmpty) {
                  Navigator.of(context).pop(trimmed);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return value?.trim();
  }

  Widget _inlineDropdownField({
    required String label,
    required TextEditingController controller,
    required List<String> builtInOptions,
    required List<String> customOptions,
    required ValueChanged<String> onCustomValueSubmitted,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final mergedOptions = mergeUniqueOptions(builtInOptions, customOptions);
    final selectedValue = controller.text.trim();
    final selectedIsPresent =
        selectedValue.isEmpty ||
        mergedOptions.any(
          (option) =>
              _normalizedOption(option) == _normalizedOption(selectedValue),
        );
    final options = [
      ...mergedOptions,
      if (selectedValue.isNotEmpty && !selectedIsPresent) selectedValue,
      addCustomDropdownOptionLabel,
    ];
    final safeValue = selectedValue.isEmpty
        ? null
        : options.firstWhere(
            (option) =>
                _normalizedOption(option) == _normalizedOption(selectedValue),
            orElse: () => selectedValue,
          );

    return DropdownButtonFormField<String>(
      key: ValueKey(
        '${label}_${editingBottleId ?? ''}_${controller.text}_${customOptions.join('|')}',
      ),
      initialValue: safeValue,
      isDense: true,
      isExpanded: true,
      iconSize: 18,
      menuMaxHeight: 260,
      dropdownColor: palette.panel,
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      decoration: _inlineEditDecoration(label),
      items: options
          .map(
            (option) => DropdownMenuItem<String>(
              value: option,
              child: Text(
                option,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (value) async {
        if (value == null) return;

        if (value == addCustomDropdownOptionLabel) {
          final customValue = await _showInlineCustomValueDialog(label);
          if (customValue == null || customValue.trim().isEmpty || !mounted) {
            return;
          }
          onCustomValueSubmitted(customValue);
          setState(() {
            controller.text = customValue.trim();
          });
          return;
        }

        setState(() {
          controller.text = value.trim();
        });
      },
    );
  }

  Widget _bottleInlineEditor({
    required ChemicalModel bottle,
    required bool isDesktop,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 32;
        final columnCount = maxWidth >= 520 ? 2 : 1;
        final fieldWidth = columnCount == 1
            ? maxWidth
            : (maxWidth - 8) / 2;

        Widget field(String label, TextEditingController controller) {
          return SizedBox(
            width: fieldWidth,
            child: _inlineEditField(label, controller),
          );
        }

        Widget dropdownField({
          required String label,
          required TextEditingController controller,
          required List<String> builtInOptions,
          required List<String> customOptions,
          required ValueChanged<String> onCustomValueSubmitted,
        }) {
          return SizedBox(
            width: fieldWidth,
            child: _inlineDropdownField(
              label: label,
              controller: controller,
              builtInOptions: builtInOptions,
              customOptions: customOptions,
              onCustomValueSubmitted: onCustomValueSubmitted,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                dropdownField(
                  label: 'Brand',
                  controller: editBrandController,
                  builtInOptions: _brandOptions,
                  customOptions: customBrandOptions,
                  onCustomValueSubmitted: (value) => _addCustomOption(
                    value: value,
                    builtInOptions: _brandOptions,
                    currentOptions: customBrandOptions,
                    setOptions: (options) => customBrandOptions = options,
                  ),
                ),
                field('Quantity / pack size', editQuantityController),
                dropdownField(
                  label: 'Location',
                  controller: editLocationController,
                  builtInOptions: _locationOptions,
                  customOptions: customLocationOptions,
                  onCustomValueSubmitted: (value) => _addCustomOption(
                    value: value,
                    builtInOptions: _locationOptions,
                    currentOptions: customLocationOptions,
                    setOptions: (options) => customLocationOptions = options,
                  ),
                ),
                dropdownField(
                  label: 'Texture',
                  controller: editTextureController,
                  builtInOptions: _textureOptions,
                  customOptions: customTextureOptions,
                  onCustomValueSubmitted: (value) => _addCustomOption(
                    value: value,
                    builtInOptions: _textureOptions,
                    currentOptions: customTextureOptions,
                    setOptions: (options) => customTextureOptions = options,
                  ),
                ),
                field('Catalog no', editCatalogController),
                field('Ordered by', editOrderedByController),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 6,
              children: [
                TextButton(
                  onPressed: _cancelBottleEditing,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text('Cancel'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _saveBottleDetails(bottle),
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label: const Text('Save'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    side: BorderSide(color: palette.border),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Color availabilityColor(String availability) {
    final v = availability.toLowerCase();
    if (v.contains('finished')) return Colors.redAccent;
    if (v.contains('low') || v.contains('about')) return Colors.orangeAccent;
    return Colors.greenAccent;
  }

  String _safeBottleStatus(String rawStatus) {
    final normalized = rawStatus.trim().toLowerCase();
    return _allowedBottleStatuses.contains(normalized)
        ? normalized
        : 'available';
  }

  String _bottleStatusLabel(String status) {
    switch (status) {
      case 'low':
        return 'Low';
      case 'finished':
        return 'Finished';
      case 'available':
      default:
        return 'Available';
    }
  }

  Widget sectionTitle(String title) {
    final colorScheme = context.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 10),
      child: Text(
        title,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 16.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget chip(String text) {
    final palette = context.labmate;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: palette.mutedText,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget buildFunctionalGroupChips(String groups) {
    final palette = context.labmate;

    if (groups.trim().isEmpty) return const SizedBox();

    final list = groups
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Functional Groups',
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: list.map((group) {
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context, group);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x2214B8A6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    group,
                    style: const TextStyle(
                      color: Color(0xFF14B8A6),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget detailBox({
    required String label,
    required String value,
    IconData? icon,
  }) {
    final displayValue = value.trim().isEmpty ? '-' : value.trim();
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: const Color(0xFF14B8A6)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  displayValue,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14.6,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget twoColumnDetailBox({
    required String leftLabel,
    required String leftValue,
    required String rightLabel,
    required String rightValue,
    IconData? leftIcon,
    IconData? rightIcon,
  }) {
    return Row(
      children: [
        Expanded(
          child: detailBox(label: leftLabel, value: leftValue, icon: leftIcon),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: detailBox(
            label: rightLabel,
            value: rightValue,
            icon: rightIcon,
          ),
        ),
      ],
    );
  }

  Widget chemistryLoadingCard() {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotateAnimation.value * 6.28318,
                child: ScaleTransition(scale: _pulseAnimation, child: child),
              );
            },
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x2214B8A6),
                border: Border.all(color: const Color(0xFF14B8A6), width: 1.5),
              ),
              child: const Icon(
                Icons.science_rounded,
                color: Color(0xFF14B8A6),
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Fetching molecular data...',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Checking structure, formula, molecular weight and identifiers from PubChem',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: Color(0x332B3A55),
              valueColor: AlwaysStoppedAnimation(Color(0xFF14B8A6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget bottleCard(
    ChemicalModel b,
    int index, {
    required bool showActiveControls,
  }) {
    final safeStatus = _safeBottleStatus(b.availability);
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final isEditing = editingBottleId == b.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isEditing ? palette.selected : palette.panel,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Bottle ${index + 1}',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isEditing) ...[
                    const SizedBox(width: 8),
                    _editingBadge(),
                  ],
                  if (showActiveControls && b.isActiveBottle) ...[
                    const SizedBox(width: 6),
                    _activeBottleBadge(),
                  ],
                  const Spacer(),
                  if (!isEditing) _editBottleButton(b),
                  const SizedBox(width: 4),
                  if (!isEditing)
                    DropdownButton<String>(
                      value: safeStatus,
                      dropdownColor: palette.panel,
                      style: TextStyle(color: colorScheme.onSurface),
                      items: _allowedBottleStatuses
                          .map(
                            (status) => DropdownMenuItem<String>(
                              value: status,
                              child: Text(
                                _bottleStatusLabel(status),
                                style: TextStyle(color: colorScheme.onSurface),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) return;

                        await inventoryService.inventoryRef.doc(b.id).update({
                          'availability': _safeBottleStatus(value),
                          'updatedAt': DateTime.now(),
                        });

                        setState(() {});
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (isEditing && showActiveControls) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: _activeBottleControl(b),
                ),
                const SizedBox(height: 8),
              ],
              if (isEditing)
                _bottleInlineEditor(bottle: b, isDesktop: false)
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    chip('Brand: ${b.brand.isEmpty ? '-' : b.brand}'),
                    chip('Qty: ${b.quantity.isEmpty ? '-' : b.quantity}'),
                    chip('Loc: ${b.location.isEmpty ? '-' : b.location}'),
                    if (showActiveControls && !b.isActiveBottle)
                      _activeBottleControl(b),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget pubChemDetailsCard(PubChemChemicalDetails p) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x2214B8A6), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.biotech_rounded,
                color: Color(0xFF14B8A6),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'PubChem Molecular Data',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.panelAlt,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Image.network(
              p.imageUrl,
              height: 150,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(
                'Structure image unavailable',
                style: TextStyle(color: palette.mutedText),
              ),
            ),
          ),
          const SizedBox(height: 14),
          twoColumnDetailBox(
            leftLabel: 'Molecular Formula',
            leftValue: p.molecularFormula,
            rightLabel: 'Molecular Weight',
            rightValue: p.molecularWeight,
            leftIcon: Icons.functions_rounded,
            rightIcon: Icons.monitor_weight_outlined,
          ),
          const SizedBox(height: 10),
          detailBox(
            label: 'PubChem CID',
            value: p.cid,
            icon: Icons.tag_rounded,
          ),
          const SizedBox(height: 10),
          detailBox(
            label: 'InChIKey',
            value: p.inchiKey,
            icon: Icons.vpn_key_outlined,
          ),
          const SizedBox(height: 10),
          detailBox(
            label: 'IUPAC Name',
            value: p.iupacName,
            icon: Icons.menu_book_rounded,
          ),
          const SizedBox(height: 10),
          detailBox(
            label: 'Canonical SMILES',
            value: p.canonicalSmiles,
            icon: Icons.account_tree_outlined,
          ),
        ],
      ),
    );
  }

  Widget _sideNavigationButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(34),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.42),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.45)),
                ),
                child: Icon(icon, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.36),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 8,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileNavigationButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final enabled = onTap != null;

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: enabled ? colorScheme.onSurface : palette.subtleText,
        disabledForegroundColor: palette.subtleText.withOpacity(0.55),
        backgroundColor: palette.panel.withOpacity(0.94),
        side: BorderSide(color: palette.border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildNavigationOverlay({
    required bool isDesktop,
    required Widget child,
  }) {
    if (!_hasNavigationContext) {
      return child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (isDesktop) {
          final top = constraints.maxHeight.isFinite
              ? constraints.maxHeight * 0.52
              : 340.0;

          return Stack(
            children: [
              Positioned.fill(child: child),
              if (_canGoPrevious)
                Positioned(
                  left: 18,
                  top: top,
                  child: _sideNavigationButton(
                    label: 'Previous',
                    icon: Icons.chevron_left_rounded,
                    onTap: () => _navigateToChemical(
                      _currentNavigationIndex! - 1,
                    ),
                  ),
                ),
              if (_canGoNext)
                Positioned(
                  right: 18,
                  top: top,
                  child: _sideNavigationButton(
                    label: 'Next',
                    icon: Icons.chevron_right_rounded,
                    onTap: () => _navigateToChemical(
                      _currentNavigationIndex! + 1,
                    ),
                  ),
                ),
            ],
          );
        }

        return Stack(
          children: [
            Positioned.fill(child: child),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _mobileNavigationButton(
                      label: 'Previous',
                      icon: Icons.chevron_left_rounded,
                      onTap: _canGoPrevious
                          ? () => _navigateToChemical(
                              _currentNavigationIndex! - 1,
                            )
                          : null,
                    ),
                    _mobileNavigationButton(
                      label: 'Next',
                      icon: Icons.chevron_right_rounded,
                      onTap: _canGoNext
                          ? () => _navigateToChemical(
                              _currentNavigationIndex! + 1,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _currentChemical;
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final showDesktopNavigation = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chemical Details'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _openAddBottle,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Bottle'),
            ),
          ),
        ],
      ),
      body: _buildNavigationOverlay(
        isDesktop: showDesktopNavigation,
        child: ResponsivePageContainer(
          maxWidth: 1120,
          child: StreamBuilder<List<ChemicalModel>>(
            stream: inventoryService.getChemicals(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final all = snapshot.data!;

              final bottles =
                  all.where((e) => e.cas.trim() == c.cas.trim()).toList()
                    ..sort((a, b) => a.label.compareTo(b.label));
              final representative = bottles.isEmpty
                  ? c
                  : _representativeBottle(bottles);

              final isDesktop = MediaQuery.sizeOf(context).width >= 900;
              if (isDesktop) {
                return _buildDesktopDetail(representative, bottles);
              }

              return ListView(
                padding: EdgeInsets.fromLTRB(
                  14,
                  14,
                  14,
                  _hasNavigationContext ? 92 : 14,
                ),
                children: [
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x2214B8A6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            representative.label,
                            style: const TextStyle(
                              color: Color(0xFF14B8A6),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          representative.chemicalName,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'CAS: ${representative.cas}',
                          style: TextStyle(
                            color: palette.mutedText,
                            fontSize: 12.8,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${bottles.length} bottles',
                          style: TextStyle(color: palette.mutedText),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  buildFunctionalGroupChips(representative.functionalGroups),

                  sectionTitle('Bottles'),
                  ...List.generate(
                    bottles.length,
                    (i) => bottleCard(
                      bottles[i],
                      i,
                      showActiveControls: bottles.length > 1,
                    ),
                  ),

                  sectionTitle('PubChem'),
                  FutureBuilder<PubChemChemicalDetails?>(
                    future: pubChemFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return chemistryLoadingCard();
                      }

                      if (snapshot.hasError) {
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: palette.panel,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: palette.border),
                          ),
                          child: Text(
                            'PubChem error: ${snapshot.error}',
                            style: TextStyle(color: palette.mutedText),
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data == null) {
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: palette.panel,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: palette.border),
                          ),
                          child: Text(
                            c.cas.trim().isEmpty
                                ? 'No CAS number available for PubChem lookup.'
                                : 'No PubChem data found for CAS: ${c.cas.trim()}',
                            style: TextStyle(color: palette.mutedText),
                          ),
                        );
                      }

                      final p = snapshot.data!;
                      return pubChemDetailsCard(p);
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _display(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '-' : trimmed;
  }

  int _representativePriority(ChemicalModel chemical) {
    if (chemical.isActiveBottle) return 0;

    final availability = chemical.availability.trim().toLowerCase();
    if (availability == 'available') return 1;
    if (availability == 'low' || availability.contains('about')) return 2;
    if (chemical.isAvailable) return 3;
    return 4;
  }

  ChemicalModel _representativeBottle(List<ChemicalModel> bottles) {
    final sorted = [...bottles];
    sorted.sort((a, b) {
      final priorityComparison = _representativePriority(
        a,
      ).compareTo(_representativePriority(b));
      if (priorityComparison != 0) {
        return priorityComparison;
      }
      return a.label.compareTo(b.label);
    });
    return sorted.first;
  }

  String _summarizeBottles(
    List<ChemicalModel> bottles,
    String Function(ChemicalModel bottle) read,
  ) {
    final values = bottles
        .map(read)
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    if (values.isEmpty) return '-';
    if (values.length == 1) return values.first;
    return '${values.first} + ${values.length - 1} more';
  }

  String _overallBottleStatus(List<ChemicalModel> bottles) {
    if (bottles.any(
      (bottle) => bottle.availability.toLowerCase().trim() == 'available',
    )) {
      return 'Available';
    }

    if (bottles.any((bottle) {
      final value = bottle.availability.toLowerCase().trim();
      return value == 'low' || value.contains('about');
    })) {
      return 'Low';
    }

    return bottles.isEmpty ? '-' : 'Finished';
  }

  Widget _compactMetric({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _display(value),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? colorScheme.onSurface,
              fontSize: 13,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactMetricGrid(List<Widget> children, {int columns = 3}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final itemWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: children.map((child) {
            return SizedBox(width: itemWidth, child: child);
          }).toList(),
        );
      },
    );
  }

  Widget _compactPanel({required String title, required Widget child}) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 13.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }

  Widget _desktopFunctionalGroups(String groups) {
    final list = groups
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (list.isEmpty) {
      return _compactMetric(label: 'Functional groups', value: '-');
    }

    return _compactPanel(
      title: 'Functional Groups',
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: list.map((group) {
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => Navigator.pop(context, group),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0x2214B8A6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                group,
                style: const TextStyle(
                  color: Color(0xFF14B8A6),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _desktopBottleRow(
    ChemicalModel bottle,
    int index, {
    required bool showActiveControls,
  }) {
    final safeStatus = _safeBottleStatus(bottle.availability);
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final isEditing = editingBottleId == bottle.id;

    if (isEditing) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: palette.selected,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Bottle ${index + 1}',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                _editingBadge(),
                if (showActiveControls) ...[
                  const SizedBox(width: 8),
                  _activeBottleControl(bottle),
                ],
              ],
            ),
            const SizedBox(height: 10),
            _bottleInlineEditor(bottle: bottle, isDesktop: true),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'Bottle ${index + 1}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _desktopTableCell(_display(bottle.brand), flex: 3),
          _desktopTableCell(_display(bottle.quantity), flex: 2),
          _desktopTableCell(_display(bottle.location), flex: 3),
          const SizedBox(width: 8),
          SizedBox(
            width: 126,
            height: 30,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: palette.panel,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: palette.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: safeStatus,
                  dropdownColor: palette.panel,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 12),
                  isDense: true,
                  isExpanded: true,
                  items: _allowedBottleStatuses
                      .map(
                        (status) => DropdownMenuItem<String>(
                          value: status,
                          child: Text(
                            _bottleStatusLabel(status),
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    if (value == null) return;

                    await inventoryService.inventoryRef.doc(bottle.id).update({
                      'availability': _safeBottleStatus(value),
                      'updatedAt': DateTime.now(),
                    });

                    setState(() {});
                  },
                ),
              ),
            ),
          ),
          if (showActiveControls) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 76,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _activeBottleControl(bottle),
              ),
            ),
          ],
          const SizedBox(width: 8),
          _editBottleButton(bottle),
        ],
      ),
    );
  }

  Widget _desktopBottleHeader({required bool showActiveControls}) {
    final palette = context.labmate;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Row(
        children: [
          _desktopTableHeader('Bottle', flex: 2),
          _desktopTableHeader('Brand', flex: 3),
          _desktopTableHeader('Qty', flex: 2),
          _desktopTableHeader('Location', flex: 3),
          const SizedBox(width: 8),
          SizedBox(
            width: 126,
            child: Text(
              'Status',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (showActiveControls) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 76,
              child: Text(
                'Active',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          const SizedBox(width: 30),
        ],
      ),
    );
  }

  Widget _desktopTableHeader(String text, {required int flex}) {
    final palette = context.labmate;

    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          color: palette.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _desktopTableCell(
    String text, {
    required int flex,
    bool isStrong = false,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Expanded(
      flex: flex,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isStrong ? colorScheme.onSurface : palette.mutedText,
          fontSize: 12.5,
          fontWeight: isStrong ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }

  Widget _desktopPubChemPanel() {
    return FutureBuilder<PubChemChemicalDetails?>(
      future: pubChemFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _compactPanel(
            title: 'PubChem',
            child: const LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: Color(0x332B3A55),
              valueColor: AlwaysStoppedAnimation(Color(0xFF14B8A6)),
            ),
          );
        }

        if (snapshot.hasError) {
          return _compactPanel(
            title: 'PubChem',
            child: Text(
              'PubChem error: ${snapshot.error}',
              style: TextStyle(
                color: context.labmate.mutedText,
                fontSize: 12.2,
              ),
            ),
          );
        }

        final p = snapshot.data;
        if (p == null) {
          return _compactPanel(
            title: 'PubChem',
            child: Text(
              'No PubChem data found.',
              style: TextStyle(
                color: context.labmate.mutedText,
                fontSize: 12.2,
              ),
            ),
          );
        }

        return _compactPanel(
          title: 'PubChem Molecular Data',
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 176,
                    height: 176,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.labmate.panelAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.labmate.border),
                    ),
                    child: Image.network(
                      p.imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.biotech_rounded,
                        color: Color(0xFF14B8A6),
                        size: 42,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        _compactMetric(
                          label: 'Formula',
                          value: p.molecularFormula,
                        ),
                        const SizedBox(height: 8),
                        _compactMetric(label: 'MW', value: p.molecularWeight),
                        const SizedBox(height: 8),
                        _compactMetric(label: 'CID', value: p.cid),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _identifierBlock(label: 'InChIKey', value: p.inchiKey),
              const SizedBox(height: 8),
              _identifierBlock(label: 'IUPAC Name', value: p.iupacName),
              const SizedBox(height: 8),
              _identifierBlock(
                label: 'Canonical SMILES',
                value: p.canonicalSmiles,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _identifierBlock({required String label, required String value}) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _display(value),
            softWrap: true,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 12.6,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopHeaderCard({
    required ChemicalModel chemical,
    required int bottleCount,
    required String availability,
    required Color statusColor,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x2214B8A6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  chemical.label,
                  style: const TextStyle(
                    color: Color(0xFF14B8A6),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withOpacity(0.34)),
                ),
                child: Text(
                  '$availability - $bottleCount ${bottleCount == 1 ? 'bottle' : 'bottles'}',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            chemical.chemicalName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          _compactMetricGrid([
            _compactMetric(label: 'CAS', value: chemical.cas),
            _compactMetric(label: 'Formula', value: chemical.formula),
            _compactMetric(label: 'MW', value: chemical.molWt),
          ], columns: 3),
        ],
      ),
    );
  }

  Widget _desktopInventoryPanel({
    required ChemicalModel chemical,
    required String brand,
    required String quantity,
    required String location,
    required String availability,
    required Color statusColor,
    required int bottleCount,
  }) {
    return _compactPanel(
      title: 'Inventory Details',
      child: Column(
        children: [
          _compactMetricGrid([
            _compactMetric(label: 'Brand', value: brand),
            _compactMetric(label: 'Pack size', value: quantity),
            _compactMetric(label: 'Location', value: location),
            _compactMetric(label: 'Texture', value: chemical.texture),
            _compactMetric(label: 'Catalog no', value: chemical.catNumber),
            _compactMetric(label: 'Ordered by', value: chemical.orderedBy),
            _compactMetric(
              label: 'Availability',
              value: availability,
              valueColor: statusColor,
            ),
            _compactMetric(label: 'Bottles', value: bottleCount.toString()),
            _compactMetric(label: 'Last updated', value: chemical.arrivalDate),
            _compactMetric(label: 'Sheet tab', value: chemical.sheetTab),
          ], columns: 3),
        ],
      ),
    );
  }

  Widget _desktopBottlePanel(List<ChemicalModel> bottles) {
    final showActiveControls = bottles.length > 1;

    return _compactPanel(
      title: 'Bottles',
      child: Column(
        children: [
          _desktopBottleHeader(showActiveControls: showActiveControls),
          const SizedBox(height: 6),
          for (int index = 0; index < bottles.length; index++) ...[
            _desktopBottleRow(
              bottles[index],
              index,
              showActiveControls: showActiveControls,
            ),
            if (index != bottles.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopDetail(ChemicalModel c, List<ChemicalModel> bottles) {
    final brand = _summarizeBottles(bottles, (bottle) => bottle.brand);
    final quantity = _summarizeBottles(bottles, (bottle) => bottle.quantity);
    final location = _summarizeBottles(bottles, (bottle) => bottle.location);
    final availability = _overallBottleStatus(bottles);
    final statusColor = availabilityColor(availability);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _desktopHeaderCard(
            chemical: c,
            bottleCount: bottles.length,
            availability: availability,
            statusColor: statusColor,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    _desktopInventoryPanel(
                      chemical: c,
                      brand: brand,
                      quantity: quantity,
                      location: location,
                      availability: availability,
                      statusColor: statusColor,
                      bottleCount: bottles.length,
                    ),
                    const SizedBox(height: 10),
                    _desktopBottlePanel(bottles),
                    const SizedBox(height: 10),
                    _desktopFunctionalGroups(c.functionalGroups),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(flex: 5, child: _desktopPubChemPanel()),
            ],
          ),
        ],
      ),
    );
  }
}
