import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/chemical_model.dart';
import '../services/firestore_access_guard.dart';
import '../services/inventory_service.dart';
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
    super.dispose();
  }

  List<List<ChemicalModel>> applyFilters(List<List<ChemicalModel>> grouped) {
    return grouped.where((group) {
      final main = group.first;

      final query = searchQuery.toLowerCase().trim();

      final matchesSearch = query.isEmpty ||
          main.chemicalName.toLowerCase().contains(query) ||
          main.cas.toLowerCase().contains(query) ||
          main.label.toLowerCase().contains(query) ||
          main.functionalGroups.toLowerCase().contains(query) ||
          group.any((b) =>
              b.brand.toLowerCase().contains(query) ||
              b.location.toLowerCase().contains(query));

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

      return true;
    }).toList();
  }

  List<List<ChemicalModel>> _applySort(List<List<ChemicalModel>> grouped) {
    final list = [...grouped];

    list.sort((a, b) {
      final aMain = a.first;
      final bMain = b.first;

      switch (sortOption) {
        case InventorySortOption.nameAZ:
          return aMain.chemicalName
              .toLowerCase()
              .compareTo(bMain.chemicalName.toLowerCase());

        case InventorySortOption.nameZA:
          return bMain.chemicalName
              .toLowerCase()
              .compareTo(aMain.chemicalName.toLowerCase());

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

          return aMain.chemicalName
              .toLowerCase()
              .compareTo(bMain.chemicalName.toLowerCase());
      }
    });

    return list;
  }

  List<List<ChemicalModel>> processChemicals(List<ChemicalModel> rawChemicals) {
    final groupedMap = inventoryService.groupByCas(rawChemicals);
    var groupedList = groupedMap.values.toList();

    for (final group in groupedList) {
      group.sort((a, b) {
        if (a.isAvailable != b.isAvailable) {
          return a.isAvailable ? -1 : 1;
        }
        return a.label.compareTo(b.label);
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

  void _showQuickActionMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            title,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            _buildBottleConfirmationMessage(bottle),
            style: const TextStyle(color: Colors.white70, height: 1.45),
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
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12.5,
                  ),
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
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(sheetContext).pop(bottle),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bottle.brand.trim().isEmpty
                                      ? 'Brand not set'
                                      : bottle.brand.trim(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _buildBottleSelectionSubtitle(bottle),
                                  style: const TextStyle(
                                    color: Colors.white70,
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
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            'Manual stock entry',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Use this only for old stock, external purchases, or bottles not added through Orders.',
            style: TextStyle(color: Colors.white70, height: 1.4),
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
            color: Colors.white.withOpacity(0.04),
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

 Widget buildGroupedChemicalCard(List<ChemicalModel> bottles) {
  final main = bottles.first;
  final int total = bottles.length;

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12.2,
        ),
      ),
    );
  }

  return Container(
    margin: const EdgeInsets.only(bottom: 14),
    child: Material(
      color: const Color(0xFF1B2435),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          final selectedGroup = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChemicalDetailScreen(chemical: main),
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
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
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
                              style: const TextStyle(
                                color: Color(0xFF14B8A6),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            summaryStatus,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white38,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        main.chemicalName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          chip('CAS: ${main.cas.isEmpty ? "-" : main.cas}'),
                          chip('Loc: $locationSummary'),
                          chip('Bottles: $total'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuickActionButton(
                              label: 'Finished',
                              icon: Icons.cancel_outlined,
                              color: Colors.white70,
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

  Widget buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<InventorySortOption>(
          value: sortOption,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white),
          isExpanded: true,
          items: InventorySortOption.values.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(
                'Sort: ${sortLabel(option)}',
                style: const TextStyle(color: Colors.white),
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
    );
  }

  Widget buildAvailabilityChips() {
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
                selectedColor: const Color(0xFF14B8A6),
                backgroundColor: const Color(0xFF1E293B),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                ),
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

  Widget buildLocationDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedLocationFilter,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white),
          isExpanded: true,
          hint: const Text(
            'Filter: Location',
            style: TextStyle(color: Colors.white70),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text(
                'Filter: All Locations',
                style: TextStyle(color: Colors.white),
              ),
            ),
            ...locationFilters.map((location) {
              return DropdownMenuItem<String?>(
                value: location,
                child: Text(
                  location,
                  style: const TextStyle(color: Colors.white),
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
    );
  }

  Widget buildResetButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ActionChip(
        label: const Text('Reset Filters'),
        backgroundColor: Colors.redAccent,
        labelStyle: const TextStyle(color: Colors.white),
        onPressed: () {
          setState(() {
            searchQuery = '';
            _searchController.clear();
            selectedAvailabilityFilter = 'All';
            selectedLocationFilter = null;
            sortOption = InventorySortOption.nameAZ;
          });
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
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
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
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
    return SafeArea(
      child: ResponsivePageContainer(
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
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
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText:
                      'Search name / CAS / label / functional group...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF14B8A6),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                ),
              ),
            ),
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
            buildResetButton(),
            const SizedBox(height: 14),
            Expanded(
              child: StreamBuilder<List<ChemicalModel>>(
                stream: inventoryService.getChemicals(),
                builder: (context, snapshot) {
                  if (!FirestoreAccessGuard.shouldQueryLabScopedData()) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          FirestoreAccessGuard.userMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, height: 1.4),
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
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
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ),
                    );
                  }

                  final raw = snapshot.data ?? [];
                  final groupedChemicals = processChemicals(raw);

                  if (raw.isEmpty) {
                    return _buildEmptyState(
                      title: 'No chemicals added yet',
                      message:
                          'Import inventory or add a chemical manually to start building this lab inventory.',
                    );
                  }

                  if (groupedChemicals.isEmpty) {
                    return _buildEmptyState(
                      title: 'No chemicals match current filters',
                      message:
                          'Try a different search term or reset the current filters.',
                    );
                  }

                  return ListView.builder(
                    itemCount: groupedChemicals.length,
                    itemBuilder: (context, index) {
                      return buildGroupedChemicalCard(
                        groupedChemicals[index],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
