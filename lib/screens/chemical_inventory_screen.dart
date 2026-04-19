import 'package:flutter/material.dart';
import '../models/chemical_model.dart';
import '../services/inventory_service.dart';
import 'chemical_detail_screen.dart';

enum InventorySortOption {
  nameAZ,
  nameZA,
  labelAZ,
  locationAZ,
  availabilityFirst,
}

enum InventoryFilterOption {
  all,
  availableOnly,
  finishedOnly,
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

  String searchText = '';
  InventorySortOption sortOption = InventorySortOption.nameAZ;
  InventoryFilterOption filterOption = InventoryFilterOption.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<List<ChemicalModel>> _applyFilter(List<List<ChemicalModel>> grouped) {
    switch (filterOption) {
      case InventoryFilterOption.availableOnly:
        return grouped
            .where((group) => group.any((c) => c.isAvailable))
            .toList();
      case InventoryFilterOption.finishedOnly:
        return grouped
            .where((group) => group.every((c) => c.isFinished))
            .toList();
      case InventoryFilterOption.all:
        return grouped;
    }
  }

  List<List<ChemicalModel>> _applySearch(List<List<ChemicalModel>> grouped) {
    if (searchText.trim().isEmpty) return grouped;

    final q = searchText.toLowerCase().trim();

    return grouped.where((group) {
      return group.any((c) =>
          c.label.toLowerCase().contains(q) ||
          c.chemicalName.toLowerCase().contains(q) ||
          c.cas.toLowerCase().contains(q) ||
          c.brand.toLowerCase().contains(q) ||
          c.location.toLowerCase().contains(q));
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
          return aMain.location
              .toLowerCase()
              .compareTo(bMain.location.toLowerCase());

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

    groupedList = _applyFilter(groupedList);
    groupedList = _applySearch(groupedList);
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

  String filterLabel(InventoryFilterOption option) {
    switch (option) {
      case InventoryFilterOption.all:
        return 'All';
      case InventoryFilterOption.availableOnly:
        return 'Available';
      case InventoryFilterOption.finishedOnly:
        return 'Finished';
    }
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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChemicalDetailScreen(chemical: main),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              width: 5,
              height: 130,
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

  Widget buildControls() {
    return Row(
      children: [
        Expanded(
          child: Container(
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
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<InventoryFilterOption>(
                value: filterOption,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                isExpanded: true,
                items: InventoryFilterOption.values.map((option) {
                  return DropdownMenuItem(
                    value: option,
                    child: Text(
                      'Filter: ${filterLabel(option)}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    filterOption = value;
                  });
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
                    searchText = value;
                  });
                },
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by label, name, CAS, brand, or location',
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
            buildControls(),
            const SizedBox(height: 14),
            Expanded(
              child: StreamBuilder<List<ChemicalModel>>(
                stream: inventoryService.getChemicals(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  final raw = snapshot.data ?? [];
                  final groupedChemicals = processChemicals(raw);

                  if (groupedChemicals.isEmpty) {
                    return const Center(
                      child: Text(
                        'No chemicals found.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
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
    );
  }
}