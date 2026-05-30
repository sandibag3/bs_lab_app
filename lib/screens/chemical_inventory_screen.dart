import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/chemical_model.dart';
import '../services/firestore_access_guard.dart';
import '../services/inventory_service.dart';
import '../theme/labmate_theme.dart';
import '../widgets/responsive_page_container.dart';
import 'add_new_chemical_screen.dart';
import 'chemical_detail_screen.dart';

enum InventorySortOption {
  nameAZ,
  nameZA,
  labelAZ,
  locationAZ,
  availabilityFirst,
}

class ChemicalInventoryScreen extends StatefulWidget {
  const ChemicalInventoryScreen({super.key});

  @override
  State<ChemicalInventoryScreen> createState() =>
      _ChemicalInventoryScreenState();
}

class _ChemicalInventoryScreenState extends State<ChemicalInventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final InventoryService inventoryService = InventoryService();

  String searchQuery = '';
  InventorySortOption sortOption = InventorySortOption.nameAZ;

  String selectedAvailabilityFilter = 'All';
  String? selectedLocationFilter;
  String selectedChemicalGroupFilter = 'All';
  List<String> chemicalGroupFilters = const [];
  final ValueNotifier<Set<String>> selectedInventoryIdsNotifier =
      ValueNotifier<Set<String>>(<String>{});
  bool selectionMode = false;
  bool isExportingSelectedCsv = false;
  bool showSelectedOnly = false;

  Set<String> get selectedInventoryIds => selectedInventoryIdsNotifier.value;

  final List<String> availabilityFilters = [
    'All',
    'Available',
    'Low',
    'Finished',
  ];

  final List<String> locationFilters = const [
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

  @override
  void dispose() {
    _searchController.dispose();
    selectedInventoryIdsNotifier.dispose();
    super.dispose();
  }

  List<List<ChemicalModel>> applyFilters(List<List<ChemicalModel>> grouped) {
    return grouped.where((group) {
      final main = group.first;

      final query = searchQuery.toLowerCase().trim();

      final matchesSearch =
          query.isEmpty ||
          main.chemicalName.toLowerCase().contains(query) ||
          main.cas.toLowerCase().contains(query) ||
          main.label.toLowerCase().contains(query) ||
          main.functionalGroups.toLowerCase().contains(query) ||
          group.any(
            (b) =>
                b.brand.toLowerCase().contains(query) ||
                b.location.toLowerCase().contains(query),
          );

      if (!matchesSearch) return false;

      if (selectedAvailabilityFilter != 'All') {
        final hasAvailable = group.any(
          (b) => b.availability.toLowerCase().trim() == 'available',
        );

        final hasLow = group.any((b) {
          final v = b.availability.toLowerCase().trim();
          return v == 'low' || v.contains('about');
        });

        if (selectedAvailabilityFilter == 'Available' && !hasAvailable) {
          return false;
        }

        if (selectedAvailabilityFilter == 'Low' && !hasLow) {
          return false;
        }

        if (selectedAvailabilityFilter == 'Finished' &&
            (hasAvailable || hasLow)) {
          return false;
        }
      }

      if (selectedLocationFilter != null) {
        final match = group.any((b) => b.location == selectedLocationFilter);
        if (!match) return false;
      }

      if (selectedChemicalGroupFilter != 'All') {
        final match = group.any(
          (b) => _chemicalMatchesGroup(b, selectedChemicalGroupFilter),
        );
        if (!match) return false;
      }

      return true;
    }).toList();
  }

  List<List<ChemicalModel>> _applySort(List<List<ChemicalModel>> grouped) {
    final list = [...grouped];

    list.sort((a, b) {
      final aMain = _representativeBottleForCurrentFilters(a);
      final bMain = _representativeBottleForCurrentFilters(b);

      if (selectedChemicalGroupFilter != 'All') {
        final labelComparison = compareChemicalLabelsNatural(
          aMain.label,
          bMain.label,
        );
        if (labelComparison != 0) {
          return labelComparison;
        }

        return aMain.chemicalName.toLowerCase().compareTo(
          bMain.chemicalName.toLowerCase(),
        );
      }

      switch (sortOption) {
        case InventorySortOption.nameAZ:
          return aMain.chemicalName.toLowerCase().compareTo(
            bMain.chemicalName.toLowerCase(),
          );

        case InventorySortOption.nameZA:
          return bMain.chemicalName.toLowerCase().compareTo(
            aMain.chemicalName.toLowerCase(),
          );

        case InventorySortOption.labelAZ:
          return aMain.label.toLowerCase().compareTo(bMain.label.toLowerCase());

        case InventorySortOption.locationAZ:
          final aLocation = a
              .map((e) => e.location.trim())
              .where((e) => e.isNotEmpty)
              .join(', ');
          final bLocation = b
              .map((e) => e.location.trim())
              .where((e) => e.isNotEmpty)
              .join(', ');

          return aLocation.toLowerCase().compareTo(bLocation.toLowerCase());

        case InventorySortOption.availabilityFirst:
          final aAvailable = a.any((c) => c.isAvailable);
          final bAvailable = b.any((c) => c.isAvailable);

          if (aAvailable != bAvailable) {
            return aAvailable ? -1 : 1;
          }

          return aMain.chemicalName.toLowerCase().compareTo(
            bMain.chemicalName.toLowerCase(),
          );
      }
    });

    return list;
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
      return compareChemicalLabelsNatural(a.label, b.label);
    });
    return sorted.first;
  }

  List<ChemicalModel> _bottlesForSelectedChemicalGroup(
    List<ChemicalModel> bottles,
  ) {
    if (selectedChemicalGroupFilter == 'All') {
      return bottles;
    }

    final matchingBottles = bottles
        .where(
          (bottle) => _chemicalMatchesGroup(
            bottle,
            selectedChemicalGroupFilter,
          ),
        )
        .toList();

    return matchingBottles.isEmpty ? bottles : matchingBottles;
  }

  ChemicalModel _representativeBottleForCurrentFilters(
    List<ChemicalModel> bottles,
  ) {
    return _representativeBottle(_bottlesForSelectedChemicalGroup(bottles));
  }

  String _optionKey(String value) => value.trim().toLowerCase();

  static const Map<String, String> _chemicalGroupAliases = {
    'a': 'Acids',
    'acid': 'Acids',
    'acids': 'Acids',
    'b': 'Bases',
    'base': 'Bases',
    'bases': 'Bases',
    'm': 'Metals',
    'metal': 'Metals',
    'metals': 'Metals',
    's': 'Salts',
    'salt': 'Salts',
    'salts': 'Salts',
    'catalyst': 'Catalysts',
    'catalysts': 'Catalysts',
    'ligand': 'Ligands',
    'ligands': 'Ligands',
  };

  static const Set<String> _catalystGroupAliases = {
    'cu',
    'copper',
    'ni',
    'nickel',
    'fe',
    'iron',
    'pd',
    'palladium',
    'rh',
    'rhodium',
    'ru',
    'ruthenium',
    'ir',
    'iridium',
    'co',
    'cobalt',
    'mn',
    'manganese',
    'zn',
    'zinc',
    'pt',
    'platinum',
    'ag',
    'silver',
    'au',
    'gold',
    'mo',
    'molybdenum',
    'cr',
    'chromium',
    'v',
    'vanadium',
    'w',
    'tungsten',
    'ti',
    'titanium',
    'zr',
    'zirconium',
  };

  static const Set<String> _ligandGroupAliases = {
    'phos',
    'phosphine',
    'phosphines',
    'phen',
    'phenanthroline',
    'tpy',
    'terpy',
    'terpyridine',
    'bipy',
    'bipyridine',
    'bpy',
    'dppf',
    'dppe',
    'dppp',
    'dppb',
    'binap',
    'xphos',
    'sphos',
    'pph3',
    'pcy3',
  };

  String _normalizedChemicalGroupDisplay(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    final key = _optionKey(trimmed);
    final alias = _chemicalGroupAliases[key];
    if (alias != null) return alias;
    if (_catalystGroupAliases.contains(key)) return 'Catalysts';
    if (_ligandGroupAliases.contains(key)) return 'Ligands';
    return trimmed;
  }

  String _chemicalGroupFilterKey(String value) {
    return _optionKey(_normalizedChemicalGroupDisplay(value));
  }

  String _labelDerivedChemicalGroup(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty || !trimmed.contains('-')) return '';
    return trimmed.split('-').first.trim();
  }

  String _explicitChemicalGroup(ChemicalModel chemical) {
    return chemical.sheetTab.trim();
  }

  bool _chemicalMatchesGroup(ChemicalModel chemical, String group) {
    final selected = _chemicalGroupFilterKey(group);
    if (selected.isEmpty || selected == 'all') return true;

    final explicit = _explicitChemicalGroup(chemical);
    if (_chemicalGroupFilterKey(explicit) == selected) return true;

    final derived = _labelDerivedChemicalGroup(chemical.label);
    return _chemicalGroupFilterKey(derived) == selected;
  }

  List<String> _chemicalGroupOptionsFrom(List<ChemicalModel> chemicals) {
    final seen = <String>{};
    final options = <String>[];

    void addOption(String value) {
      final trimmed = _normalizedChemicalGroupDisplay(value);
      if (trimmed.isEmpty) return;

      final key = _chemicalGroupFilterKey(trimmed);
      if (key == 'all') return;
      if (seen.add(key)) {
        options.add(trimmed);
      }
    }

    for (final chemical in chemicals) {
      addOption(_explicitChemicalGroup(chemical));
      addOption(_labelDerivedChemicalGroup(chemical.label));
    }

    options.sort(compareChemicalLabelsNatural);
    return options;
  }

  void _syncChemicalGroupFilters(List<ChemicalModel> chemicals) {
    final nextFilters = _chemicalGroupOptionsFrom(chemicals);
    if (nextFilters.length == chemicalGroupFilters.length) {
      var unchanged = true;
      for (var i = 0; i < nextFilters.length; i++) {
        if (nextFilters[i] != chemicalGroupFilters[i]) {
          unchanged = false;
          break;
        }
      }
      if (unchanged) return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        chemicalGroupFilters = nextFilters;
      });
    });
  }

  int compareChemicalLabelsNatural(String a, String b) {
    final aTokens = _naturalSortTokens(a);
    final bTokens = _naturalSortTokens(b);
    final maxLength = aTokens.length > bTokens.length
        ? aTokens.length
        : bTokens.length;

    for (var i = 0; i < maxLength; i++) {
      if (i >= aTokens.length) return -1;
      if (i >= bTokens.length) return 1;

      final aToken = aTokens[i];
      final bToken = bTokens[i];
      final aNumber = int.tryParse(aToken);
      final bNumber = int.tryParse(bToken);

      if (aNumber != null && bNumber != null) {
        final comparison = aNumber.compareTo(bNumber);
        if (comparison != 0) return comparison;
        continue;
      }

      final comparison = aToken.toLowerCase().compareTo(bToken.toLowerCase());
      if (comparison != 0) return comparison;
    }

    return a.compareTo(b);
  }

  List<String> _naturalSortTokens(String value) {
    final matches = RegExp(r'\d+|\D+').allMatches(value.trim());
    return matches.map((match) => match.group(0) ?? '').toList();
  }

  List<List<ChemicalModel>> processChemicals(List<ChemicalModel> rawChemicals) {
    final groupedMap = inventoryService.groupByCas(rawChemicals);
    var groupedList = groupedMap.values.toList();

    for (final group in groupedList) {
      group.sort((a, b) {
        final priorityComparison = _representativePriority(
          a,
        ).compareTo(_representativePriority(b));
        if (priorityComparison != 0) {
          return priorityComparison;
        }
        return compareChemicalLabelsNatural(a.label, b.label);
      });
    }

    groupedList = applyFilters(groupedList);
    groupedList = _applySort(groupedList);

    return groupedList;
  }

  String sortLabel(InventorySortOption option) {
    switch (option) {
      case InventorySortOption.nameAZ:
        return 'Name A-Z';
      case InventorySortOption.nameZA:
        return 'Name Z-A';
      case InventorySortOption.labelAZ:
        return 'Label';
      case InventorySortOption.locationAZ:
        return 'Location';
      case InventorySortOption.availabilityFirst:
        return 'Availability';
    }
  }

  void _clearSelectionState() {
    selectedInventoryIdsNotifier.value = <String>{};
    showSelectedOnly = false;
  }

  void _enterSelectionMode() {
    if (selectionMode) return;

    setState(() {
      selectionMode = true;
    });
  }

  void _exitSelectionModeState() {
    selectionMode = false;
    _clearSelectionState();
  }

  void _exitSelectionMode() {
    setState(_exitSelectionModeState);
  }

  void _toggleInventorySelection(String inventoryId, bool? selected) {
    if (inventoryId.trim().isEmpty) return;

    final nextSelection = <String>{...selectedInventoryIdsNotifier.value};

    if (selected == true) {
      nextSelection.add(inventoryId);
    } else {
      nextSelection.remove(inventoryId);
    }

    selectedInventoryIdsNotifier.value = nextSelection;

    if (showSelectedOnly) {
      setState(() {
        showSelectedOnly = nextSelection.isNotEmpty;
      });
    }
  }

  String _representativeInventoryId(List<ChemicalModel> bottles) {
    // TODO: Expand desktop bulk actions to all bottle IDs in grouped CAS rows.
    return _representativeBottleForCurrentFilters(bottles).id;
  }

  List<String> _visibleRepresentativeInventoryIds(
    List<List<ChemicalModel>> groupedChemicals,
  ) {
    return groupedChemicals
        .map(_representativeInventoryId)
        .where((id) => id.trim().isNotEmpty)
        .toList();
  }

  List<String> _selectedVisibleInventoryIds(
    List<List<ChemicalModel>> groupedChemicals,
  ) {
    final visibleIds = _visibleRepresentativeInventoryIds(
      groupedChemicals,
    ).toSet();

    return selectedInventoryIds
        .where((id) => visibleIds.contains(id))
        .toSet()
        .toList();
  }

  List<ChemicalModel> _selectedVisibleChemicals(
    List<List<ChemicalModel>> groupedChemicals,
  ) {
    final selectedIds = _selectedVisibleInventoryIds(groupedChemicals).toSet();

    return groupedChemicals
        .map(_representativeBottleForCurrentFilters)
        .where((chemical) => selectedIds.contains(chemical.id))
        .toList();
  }

  List<List<ChemicalModel>> _selectedVisibleGroups(
    List<List<ChemicalModel>> groupedChemicals,
  ) {
    final selectedIds = _selectedVisibleInventoryIds(groupedChemicals).toSet();

    return groupedChemicals.where((bottles) {
      return selectedIds.contains(_representativeInventoryId(bottles));
    }).toList();
  }

  void _selectAllVisible(List<List<ChemicalModel>> groupedChemicals) {
    if (!selectionMode) return;

    final visibleIds = _visibleRepresentativeInventoryIds(groupedChemicals);
    if (visibleIds.isEmpty) return;

    selectedInventoryIdsNotifier.value = <String>{
      ...selectedInventoryIdsNotifier.value,
      ...visibleIds,
    };

    if (showSelectedOnly) {
      setState(() {});
    }
  }

  Future<void> _openBulkChangeLocationDialog(
    List<List<ChemicalModel>> groupedChemicals,
  ) async {
    final targetIds = _selectedVisibleInventoryIds(groupedChemicals);

    if (targetIds.isEmpty) {
      _showQuickActionMessage(
        'No selected inventory items are visible with current filters.',
      );
      return;
    }

    // TODO: Future improvement: offer an option to update all bottles under
    // selected CAS groups instead of only the visible representative document.
    final selectedLocation = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? location;
        bool showValidationError = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final palette = dialogContext.labmate;
            final colorScheme = dialogContext.colorScheme;

            return AlertDialog(
              backgroundColor: palette.panel,
              title: Text(
                'Change location',
                style: TextStyle(color: colorScheme.onSurface),
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${targetIds.length} selected',
                      style: const TextStyle(
                        color: Color(0xFF5EEAD4),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: location,
                      dropdownColor: palette.panel,
                      decoration: InputDecoration(
                        labelText: 'Location',
                        labelStyle: TextStyle(color: palette.mutedText),
                        errorText: showValidationError
                            ? 'Select a location before applying.'
                            : null,
                        filled: true,
                        fillColor: palette.panelAlt,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: palette.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF14B8A6),
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.redAccent),
                        ),
                      ),
                      iconEnabledColor: palette.mutedText,
                      style: TextStyle(color: colorScheme.onSurface),
                      items: locationFilters.map((locationOption) {
                        return DropdownMenuItem<String>(
                          value: locationOption,
                          child: Text(
                            locationOption,
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          location = value;
                          showValidationError = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (location == null || location!.trim().isEmpty) {
                      setDialogState(() {
                        showValidationError = true;
                      });
                      return;
                    }

                    Navigator.of(dialogContext).pop(location);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedLocation == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await inventoryService.updateLocationsByIds(
        docIds: targetIds,
        location: selectedLocation,
      );

      if (!mounted) return;
      setState(_exitSelectionModeState);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Location updated for ${targetIds.length} item(s).'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _confirmBulkAvailabilityUpdate({
    required List<List<ChemicalModel>> groupedChemicals,
    required String availability,
    required String title,
    required String confirmLabel,
    required String successLabel,
  }) async {
    final targetIds = _selectedVisibleInventoryIds(groupedChemicals);

    if (targetIds.isEmpty) {
      _showQuickActionMessage(
        'No selected inventory items are visible with current filters.',
      );
      return;
    }

    // TODO: Future improvement: offer an option to update all bottles under
    // selected CAS groups instead of only the visible representative document.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final palette = dialogContext.labmate;
        final colorScheme = dialogContext.colorScheme;

        return AlertDialog(
          backgroundColor: palette.panel,
          title: Text(title, style: TextStyle(color: colorScheme.onSurface)),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${targetIds.length} selected',
                  style: const TextStyle(
                    color: Color(0xFF5EEAD4),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Only selected visible inventory records will be updated.',
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14B8A6),
                foregroundColor: Colors.white,
              ),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await inventoryService.updateAvailabilityByIds(
        docIds: targetIds,
        availability: availability,
      );

      if (!mounted) return;
      setState(_exitSelectionModeState);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Marked ${targetIds.length} item(s) as $successLabel.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _exportSelectedVisibleCsv(
    List<List<ChemicalModel>> groupedChemicals,
  ) async {
    final selectedChemicals = _selectedVisibleChemicals(groupedChemicals);

    if (selectedChemicals.isEmpty) {
      _showQuickActionMessage(
        'No selected inventory items are visible with current filters.',
      );
      return;
    }

    setState(() {
      isExportingSelectedCsv = true;
    });

    try {
      final rows = <List<String>>[
        const [
          'Label',
          'Chemical name',
          'CAS',
          'Molecular formula',
          'Molecular weight',
          'Brand',
          'Location',
          'Quantity',
          'Availability',
          'Category/type',
        ],
        ...selectedChemicals.map((chemical) {
          return [
            chemical.label,
            chemical.chemicalName,
            chemical.cas,
            chemical.formula,
            chemical.molWt,
            chemical.brand,
            chemical.location,
            chemical.quantity,
            chemical.availability,
            _categoryOrType(chemical),
          ];
        }),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final fileName = _selectedCsvFileName();
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save selected chemical inventory',
        fileName: fileName,
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );

      if (!mounted) return;

      _showQuickActionMessage(
        savedPath == null
            ? 'Export cancelled.'
            : 'Exported ${selectedChemicals.length} selected item(s).',
      );
    } catch (error) {
      if (!mounted) return;
      _showQuickActionMessage('Could not export selected inventory: $error');
    } finally {
      if (mounted) {
        setState(() {
          isExportingSelectedCsv = false;
        });
      }
    }
  }

  String _categoryOrType(ChemicalModel chemical) {
    final category = chemical.sheetTab.trim();
    if (category.isNotEmpty) return category;

    final type = chemical.texture.trim();
    return type.isEmpty ? '-' : type;
  }

  String _selectedCsvFileName() {
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

    return 'labmate_chemical_inventory_selected_${date}_$time.csv';
  }

  void _showQuickActionMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _displayOrDash(String value) {
    final clean = value.trim();
    return clean.isEmpty ? '-' : clean;
  }

  String _statusLabel(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'low') return 'Low';
    if (normalized == 'finished') return 'Finished';
    return 'Available';
  }

  String _buildBottleSelectionSubtitle(ChemicalModel bottle) {
    final parts = <String>[
      'Label: ${_displayOrDash(bottle.label)}',
      'Location: ${_displayOrDash(bottle.location)}',
      'Qty: ${_displayOrDash(bottle.quantity)}',
      'Status: ${_statusLabel(bottle.availability)}',
    ];

    if (bottle.catNumber.trim().isNotEmpty) {
      parts.add('Cat: ${bottle.catNumber.trim()}');
    }

    return parts.join('  |  ');
  }

  String _buildBottleConfirmationMessage(ChemicalModel bottle) {
    final lines = <String>[
      'Brand: ${_displayOrDash(bottle.brand)}',
      'Label: ${_displayOrDash(bottle.label)}',
      'Location: ${_displayOrDash(bottle.location)}',
      'Quantity: ${_displayOrDash(bottle.quantity)}',
    ];

    if (bottle.catNumber.trim().isNotEmpty) {
      lines.add('Catalog No: ${bottle.catNumber.trim()}');
    }

    return lines.join('\n');
  }

  Future<bool> _confirmBottleStatusAction({
    required ChemicalModel bottle,
    required String title,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final palette = dialogContext.labmate;
        final colorScheme = dialogContext.colorScheme;

        return AlertDialog(
          backgroundColor: palette.panel,
          title: Text(title, style: TextStyle(color: colorScheme.onSurface)),
          content: Text(
            _buildBottleConfirmationMessage(bottle),
            style: TextStyle(color: palette.mutedText, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14B8A6),
                foregroundColor: Colors.white,
              ),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<ChemicalModel?> _pickBottleForStatusAction({
    required String title,
    required String subtitle,
    required List<ChemicalModel> bottles,
  }) async {
    return showModalBottomSheet<ChemicalModel>(
      context: context,
      backgroundColor: context.labmate.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        final palette = sheetContext.labmate;
        final colorScheme = sheetContext.colorScheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(color: palette.subtleText, fontSize: 12.5),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetContext).size.height * 0.52,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: bottles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (sheetContext, index) {
                      final bottle = bottles[index];
                      return Material(
                        color: palette.panel,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(sheetContext).pop(bottle),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: palette.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bottle.brand.trim().isEmpty
                                      ? 'Brand not set'
                                      : bottle.brand.trim(),
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _buildBottleSelectionSubtitle(bottle),
                                  style: TextStyle(
                                    color: palette.mutedText,
                                    fontSize: 12.4,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _markSpecificBottleFinished(ChemicalModel bottle) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final confirmed = await _confirmBottleStatusAction(
        bottle: bottle,
        title: 'Mark bottle finished?',
        confirmLabel: 'Mark Finished',
      );
      if (!confirmed || !mounted) return;

      await inventoryService.markBottleFinishedById(docId: bottle.id);

      if (!mounted) return;
      setState(() {});
      messenger.showSnackBar(
        const SnackBar(content: Text('Marked bottle as finished')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _markSpecificBottleLow(ChemicalModel bottle) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final confirmed = await _confirmBottleStatusAction(
        bottle: bottle,
        title: 'Mark bottle as low?',
        confirmLabel: 'Mark Low',
      );
      if (!confirmed || !mounted) return;

      await inventoryService.markBottleLowById(docId: bottle.id);

      if (!mounted) return;
      setState(() {});
      messenger.showSnackBar(
        const SnackBar(content: Text('Marked bottle as low')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _markOneBottleLow(ChemicalModel chemical) async {
    final messenger = ScaffoldMessenger.of(context);
    final labId = AppState.instance.selectedLabId.trim();

    try {
      final activeBottles = await inventoryService.getActiveBottlesForCas(
        cas: chemical.cas,
        labId: labId,
      );

      if (!mounted) return;

      if (activeBottles.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No active bottle found')),
        );
        return;
      }

      if (activeBottles.length == 1) {
        await _markSpecificBottleLow(activeBottles.first);
        return;
      }

      final selectedBottle = await _pickBottleForStatusAction(
        title: 'Which bottle is low?',
        subtitle: 'Select the exact active bottle to mark as low.',
        bottles: activeBottles,
      );

      if (selectedBottle == null || !mounted) return;
      await _markSpecificBottleLow(selectedBottle);
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _markOneBottleFinished(ChemicalModel chemical) async {
    final messenger = ScaffoldMessenger.of(context);
    final labId = AppState.instance.selectedLabId.trim();

    try {
      final activeBottles = await inventoryService.getActiveBottlesForCas(
        cas: chemical.cas,
        labId: labId,
      );

      if (!mounted) return;

      if (activeBottles.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No active bottle found')),
        );
        return;
      }

      if (activeBottles.length == 1) {
        await _markSpecificBottleFinished(activeBottles.first);
        return;
      }

      final selectedBottle = await _pickBottleForStatusAction(
        title: 'Which bottle is finished?',
        subtitle: 'Select the exact active bottle to mark as finished.',
        bottles: activeBottles,
      );

      if (selectedBottle == null || !mounted) return;
      await _markSpecificBottleFinished(selectedBottle);
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _startManualEntry(ChemicalModel chemical) async {
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final palette = dialogContext.labmate;
        final colorScheme = dialogContext.colorScheme;

        return AlertDialog(
          backgroundColor: palette.panel,
          title: Text(
            'Manual stock entry',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          content: Text(
            'Use this only for old stock, external purchases, or bottles not added through Orders.',
            style: TextStyle(color: palette.mutedText, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14B8A6),
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (shouldContinue != true || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddNewChemicalScreen(manualPrefill: chemical),
      ),
    );
  }

  Widget _buildQuickActionButton({
    String? label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: label == null ? 8 : 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: context.labmate.panelAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              if (label != null) ...[
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget buildGroupedChemicalCard(
    List<ChemicalModel> bottles, {
    bool showSelection = false,
    List<ChemicalModel>? navigationChemicals,
    int? navigationIndex,
  }) {
    final main = _representativeBottleForCurrentFilters(bottles);
    final representativeInventoryId = _representativeInventoryId(bottles);
    final int total = bottles.length;
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final cardRadius = isDesktop ? 14.0 : 18.0;
    final cardPadding = isDesktop ? 10.0 : 14.0;

    final locations = bottles
        .map((b) => b.location.trim())
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList();

    String locationSummary;
    if (locations.isEmpty) {
      locationSummary = '-';
    } else if (locations.length == 1) {
      locationSummary = locations.first;
    } else {
      locationSummary = '${locations.first} + ${locations.length - 1} more';
    }

    final bool hasAvailable = bottles.any(
      (b) => b.availability.toLowerCase().trim() == 'available',
    );

    final bool hasLow = bottles.any((b) {
      final v = b.availability.toLowerCase().trim();
      return v == 'low' || v.contains('about');
    });

    String summaryStatus;
    Color statusColor;

    if (hasAvailable) {
      summaryStatus = 'Available';
      statusColor = const Color(0xFF14B8A6);
    } else if (hasLow) {
      summaryStatus = 'Low';
      statusColor = Colors.orangeAccent;
    } else {
      summaryStatus = 'Finished';
      statusColor = Colors.redAccent;
    }

    Widget chip(String text) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 8 : 10,
          vertical: isDesktop ? 4 : 5,
        ),
        decoration: BoxDecoration(
          color: palette.panelAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: palette.mutedText,
            fontSize: isDesktop ? 12.3 : 12.8,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      key: ValueKey(representativeInventoryId),
      margin: EdgeInsets.only(bottom: isDesktop ? 8 : 14),
      child: Material(
        color: palette.panel,
        borderRadius: BorderRadius.circular(cardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(cardRadius),
          onTap: () async {
            final selectedGroup = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChemicalDetailScreen(
                  chemical: main,
                  navigationChemicals: navigationChemicals,
                  navigationIndex: navigationIndex,
                ),
              ),
            );

            if (selectedGroup != null && selectedGroup is String) {
              setState(() {
                searchQuery = selectedGroup;
                _searchController.text = selectedGroup;
              });
            }
          },
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
                if (showSelection)
                  SizedBox(
                    width: 42,
                    child: Center(
                      child: ValueListenableBuilder<Set<String>>(
                        valueListenable: selectedInventoryIdsNotifier,
                        builder: (context, selectedIds, _) {
                          final isSelected = selectedIds.contains(
                            representativeInventoryId,
                          );

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _toggleInventorySelection(
                              representativeInventoryId,
                              !isSelected,
                            ),
                            child: AbsorbPointer(
                              child: Checkbox(
                                value: isSelected,
                                onChanged: (_) {},
                                activeColor: const Color(0xFF14B8A6),
                                checkColor: Colors.white,
                                side: BorderSide(color: palette.subtleText),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x2214B8A6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                main.label,
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            SizedBox(width: isDesktop ? 12 : 8),
                            Expanded(
                              child: Text(
                                main.chemicalName,
                                maxLines: isDesktop ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: isDesktop ? 14.8 : 15.8,
                                  fontWeight: FontWeight.w800,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            SizedBox(width: isDesktop ? 12 : 6),
                            Text(
                              summaryStatus,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: palette.subtleText,
                              size: 18,
                            ),
                          ],
                        ),
                        SizedBox(height: isDesktop ? 8 : 10),
                        Wrap(
                          spacing: isDesktop ? 6 : 8,
                          runSpacing: isDesktop ? 6 : 8,
                          children: [
                            chip('CAS: ${main.cas.isEmpty ? "-" : main.cas}'),
                            chip('Loc: $locationSummary'),
                            chip('Bottles: $total'),
                          ],
                        ),
                        SizedBox(height: isDesktop ? 8 : 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildQuickActionButton(
                                label: 'Finished',
                                icon: Icons.cancel_outlined,
                                color: palette.mutedText,
                                onTap: () => _markOneBottleFinished(main),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildQuickActionButton(
                                label: 'Low',
                                icon: Icons.warning_amber_rounded,
                                color: const Color(0xFFFB7185),
                                onTap: () => _markOneBottleLow(main),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildQuickActionButton(
                              icon: Icons.add_circle_outline,
                              color: const Color(0xFF14B8A6),
                              onTap: () => _startManualEntry(main),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildSortDropdown({bool dense = false}) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return SizedBox(
      height: dense ? 42 : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: palette.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<InventorySortOption>(
            value: sortOption,
            dropdownColor: palette.panel,
            style: TextStyle(color: colorScheme.onSurface),
            isExpanded: true,
            items: InventorySortOption.values.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(
                  'Sort: ${sortLabel(option)}',
                  style: TextStyle(color: colorScheme.onSurface),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                sortOption = value;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget buildAvailabilityChips({bool dense = false}) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...availabilityFilters.map((filter) {
            final isSelected = selectedAvailabilityFilter == filter;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filter),
                selected: isSelected,
                selectedColor: palette.selected,
                backgroundColor: palette.panel,
                labelStyle: TextStyle(
                  color: isSelected ? colorScheme.primary : palette.mutedText,
                  fontSize: dense ? 12 : null,
                  fontWeight: FontWeight.w700,
                ),
                visualDensity: dense
                    ? const VisualDensity(horizontal: -2, vertical: -2)
                    : null,
                materialTapTargetSize: dense
                    ? MaterialTapTargetSize.shrinkWrap
                    : null,
                onSelected: (_) {
                  setState(() {
                    selectedAvailabilityFilter = filter;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget buildLocationDropdown({bool dense = false}) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return SizedBox(
      height: dense ? 42 : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: palette.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: selectedLocationFilter,
            dropdownColor: palette.panel,
            style: TextStyle(color: colorScheme.onSurface),
            isExpanded: true,
            hint: const Text('Filter: Location'),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  'Filter: All Locations',
                  style: TextStyle(color: colorScheme.onSurface),
                ),
              ),
              ...locationFilters.map((location) {
                return DropdownMenuItem<String?>(
                  value: location,
                  child: Text(
                    location,
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                );
              }),
            ],
            onChanged: (value) {
              setState(() {
                selectedLocationFilter = value;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget buildChemicalGroupDropdown({bool dense = false}) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final selectedValue = selectedChemicalGroupFilter == 'All'
        ? 'All'
        : _normalizedChemicalGroupDisplay(selectedChemicalGroupFilter);
    final options = [
      ...chemicalGroupFilters,
      if (selectedValue != 'All' &&
          !chemicalGroupFilters.any(
            (group) =>
                _chemicalGroupFilterKey(group) ==
                _chemicalGroupFilterKey(selectedValue),
          ))
        selectedValue,
    ];

    return SizedBox(
      height: dense ? 42 : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: palette.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedValue,
            dropdownColor: palette.panel,
            style: TextStyle(color: colorScheme.onSurface),
            isExpanded: true,
            hint: const Text('Chemical Group'),
            items: [
              DropdownMenuItem<String>(
                value: 'All',
                child: Text(
                  'Chemical Group: All',
                  style: TextStyle(color: colorScheme.onSurface),
                ),
              ),
              ...options.map((group) {
                return DropdownMenuItem<String>(
                  value: group,
                  child: Text(
                    group,
                    style: TextStyle(color: colorScheme.onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                selectedChemicalGroupFilter = value == 'All'
                    ? 'All'
                    : _normalizedChemicalGroupDisplay(value);
              });
            },
          ),
        ),
      ),
    );
  }

  Widget buildResetButton({bool dense = false}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: dense ? 42 : null,
        child: ActionChip(
          avatar: dense
              ? const Icon(
                  Icons.restart_alt_rounded,
                  size: 17,
                  color: Colors.white,
                )
              : null,
          label: Text(dense ? 'Reset' : 'Reset Filters'),
          backgroundColor: Colors.redAccent,
          labelStyle: const TextStyle(color: Colors.white),
          visualDensity: dense
              ? const VisualDensity(horizontal: -2, vertical: -2)
              : null,
          materialTapTargetSize: dense
              ? MaterialTapTargetSize.shrinkWrap
              : null,
          onPressed: () {
            setState(() {
              searchQuery = '';
              _searchController.clear();
              selectedAvailabilityFilter = 'All';
              selectedLocationFilter = null;
              selectedChemicalGroupFilter = 'All';
              sortOption = InventorySortOption.nameAZ;
            });
          },
        ),
      ),
    );
  }

  Widget _buildDesktopToolbar(Widget searchField) {
    final palette = context.labmate;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchField,
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 260,
                        maxWidth: 420,
                      ),
                      child: buildAvailabilityChips(dense: true),
                    ),
                    SizedBox(width: 150, child: buildSortDropdown(dense: true)),
                    SizedBox(
                      width: 170,
                      child: buildChemicalGroupDropdown(dense: true),
                    ),
                    SizedBox(
                      width: 180,
                      child: buildLocationDropdown(dense: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (!selectionMode) ...[
                _buildSelectionButton(
                  label: 'Select',
                  icon: Icons.check_box_outlined,
                  onPressed: _enterSelectionMode,
                ),
                const SizedBox(width: 8),
              ],
              buildResetButton(dense: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final palette = context.labmate;

    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.mutedText,
          disabledForegroundColor: palette.subtleText.withOpacity(0.55),
          side: BorderSide(color: palette.border),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedOnlyToggle() {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return SizedBox(
      height: 36,
      child: FilterChip(
        selected: showSelectedOnly,
        onSelected: (selected) {
          setState(() {
            showSelectedOnly = selected;
          });
        },
        avatar: Icon(
          showSelectedOnly
              ? Icons.filter_alt_rounded
              : Icons.filter_alt_outlined,
          size: 16,
          color: showSelectedOnly ? colorScheme.primary : palette.mutedText,
        ),
        label: const Text('Selected only'),
        selectedColor: palette.selected,
        backgroundColor: palette.panel,
        labelStyle: TextStyle(
          color: showSelectedOnly ? colorScheme.primary : palette.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        side: BorderSide(color: palette.border),
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildDesktopSelectionControls(
    List<List<ChemicalModel>> groupedChemicals,
  ) {
    if (!selectionMode) {
      return Align(
        alignment: Alignment.centerRight,
        child: _buildSelectionButton(
          label: 'Select',
          icon: Icons.check_box_outlined,
          onPressed: _enterSelectionMode,
        ),
      );
    }

    return ValueListenableBuilder<Set<String>>(
      valueListenable: selectedInventoryIdsNotifier,
      builder: (context, selectedIds, _) {
        final palette = context.labmate;
        final selectedCount = selectedIds.length;
        final visibleCount = groupedChemicals.length;
        final visibleIds = _visibleRepresentativeInventoryIds(
          groupedChemicals,
        ).toSet();
        final selectedVisibleCount = selectedIds
            .where((id) => visibleIds.contains(id))
            .length;
        final selectionSummary = selectedVisibleCount == selectedCount
            ? '$selectedCount selected from $visibleCount visible'
            : '$selectedCount selected, $visibleCount visible';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: palette.panelAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selectedCount == 0
                        ? palette.panel
                        : palette.selected,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    selectedCount == 0
                        ? 'Select items to bulk edit'
                        : selectionSummary,
                    style: TextStyle(
                      color: selectedCount == 0
                          ? palette.mutedText
                          : context.colorScheme.primary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (selectedCount > 0) ...[
                  _buildSelectedOnlyToggle(),
                  const SizedBox(width: 8),
                ],
                _buildSelectionButton(
                  label: 'Select all visible',
                  icon: Icons.select_all_rounded,
                  onPressed: () => _selectAllVisible(groupedChemicals),
                ),
                const SizedBox(width: 8),
                _buildSelectionButton(
                  label: selectedCount == 0 ? 'Cancel' : 'Clear',
                  icon: Icons.close_rounded,
                  onPressed: _exitSelectionMode,
                ),
                if (selectedCount > 0) ...[
                  const SizedBox(width: 14),
                  _buildSelectionButton(
                    label: isExportingSelectedCsv
                        ? 'Exporting...'
                        : 'Export CSV',
                    icon: Icons.file_download_outlined,
                    onPressed: isExportingSelectedCsv
                        ? null
                        : () => _exportSelectedVisibleCsv(groupedChemicals),
                  ),
                  const SizedBox(width: 8),
                  _buildSelectionButton(
                    label: 'Change location',
                    icon: Icons.place_outlined,
                    onPressed: () =>
                        _openBulkChangeLocationDialog(groupedChemicals),
                  ),
                  const SizedBox(width: 8),
                  _buildSelectionButton(
                    label: 'Mark low',
                    icon: Icons.warning_amber_rounded,
                    onPressed: () => _confirmBulkAvailabilityUpdate(
                      groupedChemicals: groupedChemicals,
                      availability: 'low',
                      title: 'Mark selected as low?',
                      confirmLabel: 'Mark Low',
                      successLabel: 'low',
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildSelectionButton(
                    label: 'Mark finished',
                    icon: Icons.cancel_outlined,
                    onPressed: () => _confirmBulkAvailabilityUpdate(
                      groupedChemicals: groupedChemicals,
                      availability: 'finished',
                      title: 'Mark selected as finished?',
                      confirmLabel: 'Mark Finished',
                      successLabel: 'finished',
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required String title, required String message}) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: palette.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.science_outlined,
                color: Color(0xFF14B8A6),
                size: 30,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: palette.mutedText,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return SafeArea(
      child: ResponsivePageContainer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            final pagePadding = isDesktop ? 12.0 : 16.0;
            final searchField = Container(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? double.infinity : double.infinity,
              ),
              decoration: BoxDecoration(
                color: palette.panel,
                borderRadius: BorderRadius.circular(isDesktop ? 14 : 18),
                boxShadow: isDesktop
                    ? null
                    : const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search name / CAS / label / functional group...',
                  hintStyle: TextStyle(color: palette.subtleText),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF14B8A6),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: palette.panel,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: isDesktop ? 10 : 14,
                  ),
                ),
              ),
            );

            return Padding(
              padding: EdgeInsets.all(pagePadding),
              child: Column(
                children: [
                  if (isDesktop)
                    _buildDesktopToolbar(searchField)
                  else ...[
                    searchField,
                    const SizedBox(height: 12),
                    buildAvailabilityChips(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: buildSortDropdown()),
                        const SizedBox(width: 10),
                        Expanded(child: buildLocationDropdown()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    buildChemicalGroupDropdown(),
                    const SizedBox(height: 12),
                    buildResetButton(),
                  ],
                  SizedBox(height: isDesktop ? 12 : 14),
                  Expanded(
                    child: StreamBuilder<List<ChemicalModel>>(
                      stream: inventoryService.getChemicals(),
                      builder: (context, snapshot) {
                        if (!FirestoreAccessGuard.shouldQueryLabScopedData()) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                FirestoreAccessGuard.userMessage,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: palette.mutedText,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          );
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                FirestoreAccessGuard.messageFor(snapshot.error),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: palette.mutedText,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          );
                        }

                        final raw = snapshot.data ?? [];
                        _syncChemicalGroupFilters(raw);
                        final groupedChemicals = processChemicals(raw);

                        if (raw.isEmpty && !selectionMode) {
                          return _buildEmptyState(
                            title: 'No chemicals added yet',
                            message:
                                'Import inventory or add a chemical manually to start building this lab inventory.',
                          );
                        }

                        if (groupedChemicals.isEmpty && !selectionMode) {
                          return _buildEmptyState(
                            title: 'No chemicals match current filters',
                            message:
                                'Try a different search term or reset the current filters.',
                          );
                        }

                        final displayedChemicals =
                            isDesktop && selectionMode && showSelectedOnly
                            ? _selectedVisibleGroups(groupedChemicals)
                            : groupedChemicals;
                        final navigationChemicals = displayedChemicals
                            .map(_representativeBottleForCurrentFilters)
                            .toList();

                        return Column(
                          children: [
                            if (isDesktop && selectionMode) ...[
                              _buildDesktopSelectionControls(groupedChemicals),
                              const SizedBox(height: 8),
                            ],
                            Expanded(
                              child: displayedChemicals.isEmpty
                                  ? _buildEmptyState(
                                      title: showSelectedOnly
                                          ? 'No selected records visible'
                                          : 'No chemicals match current filters',
                                      message: showSelectedOnly
                                          ? 'Selected items are still kept. Adjust filters or turn off Selected only to return to the full list.'
                                          : 'Try a different search term or reset the current filters.',
                                    )
                                  : ListView.builder(
                                      itemCount: displayedChemicals.length,
                                      itemBuilder: (context, index) {
                                        return buildGroupedChemicalCard(
                                          displayedChemicals[index],
                                          showSelection:
                                              isDesktop && selectionMode,
                                          navigationChemicals:
                                              navigationChemicals,
                                          navigationIndex: index,
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
