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

  List<ChemicalModel> _deduplicateByCas(List<ChemicalModel> chemicals) {
    final Map<String, List<ChemicalModel>> grouped = {};

    for (final chemical in chemicals) {
      final key = chemical.normalizedCas.isEmpty
          ? 'name:${chemical.normalizedName}'
          : 'cas:${chemical.normalizedCas}';

      grouped.putIfAbsent(key, () => []).add(chemical);
    }

    final List<ChemicalModel> result = [];

    for (final entry in grouped.entries) {
      final items = entry.value;

      items.sort((a, b) {
        if (a.isAvailable != b.isAvailable) {
          return a.isAvailable ? -1 : 1;
        }
        return a.label.compareTo(b.label);
      });

      result.add(items.first);
    }

    return result;
  }

  List<ChemicalModel> _applyFilter(List<ChemicalModel> chemicals) {
    switch (filterOption) {
      case InventoryFilterOption.availableOnly:
        return chemicals.where((c) => c.isAvailable).toList();
      case InventoryFilterOption.finishedOnly:
        return chemicals.where((c) => c.isFinished).toList();
      case InventoryFilterOption.all:
        return chemicals;
    }
  }

  List<ChemicalModel> _applySearch(List<ChemicalModel> chemicals) {
    if (searchText.trim().isEmpty) return chemicals;

    final q = searchText.toLowerCase().trim();

    return chemicals.where((c) {
      return c.label.toLowerCase().contains(q) ||
          c.chemicalName.toLowerCase().contains(q) ||
          c.cas.toLowerCase().contains(q) ||
          c.brand.toLowerCase().contains(q) ||
          c.location.toLowerCase().contains(q);
    }).toList();
  }

  List<ChemicalModel> _applySort(List<ChemicalModel> chemicals) {
    final list = [...chemicals];

    switch (sortOption) {
      case InventorySortOption.nameAZ:
        list.sort((a, b) =>
            a.chemicalName.toLowerCase().compareTo(b.chemicalName.toLowerCase()));
        break;
      case InventorySortOption.nameZA:
        list.sort((a, b) =>
            b.chemicalName.toLowerCase().compareTo(a.chemicalName.toLowerCase()));
        break;
      case InventorySortOption.labelAZ:
        list.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
        break;
      case InventorySortOption.locationAZ:
        list.sort((a, b) =>
            a.location.toLowerCase().compareTo(b.location.toLowerCase()));
        break;
      case InventorySortOption.availabilityFirst:
        list.sort((a, b) {
          if (a.isAvailable != b.isAvailable) {
            return a.isAvailable ? -1 : 1;
          }
          return a.chemicalName
              .toLowerCase()
              .compareTo(b.chemicalName.toLowerCase());
        });
        break;
    }

    return list;
  }

  List<ChemicalModel> processChemicals(List<ChemicalModel> rawChemicals) {
    var list = _deduplicateByCas(rawChemicals);
    list = _applyFilter(list);
    list = _applySearch(list);
    list = _applySort(list);
    return list;
  }

  Color getAvailabilityColor(String availability) {
    final value = availability.toLowerCase();

    if (value.contains('finished') ||
        value.contains('empty') ||
        value.contains('not available')) {
      return Colors.redAccent;
    }
    if (value.contains('about')) {
      return Colors.orangeAccent;
    }
    return Colors.greenAccent;
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

 Widget buildChemicalCard(ChemicalModel chemical) {
  Color statusColor;

  if (chemical.isFinished) {
    statusColor = Colors.redAccent;
  } else if (chemical.availability.toLowerCase().contains('about')) {
    statusColor = Colors.orangeAccent;
  } else {
    statusColor = const Color(0xFF14B8A6);
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
              builder: (_) => ChemicalDetailScreen(chemical: chemical),
            ),
          );
        },
        child: Row(
          children: [
            // 🔥 LEFT STATUS BAR
            Container(
              width: 5,
              height: 110,
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
                    // 🔹 TOP ROW
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
                            chemical.label,
                            style: const TextStyle(
                              color: Color(0xFF14B8A6),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          chemical.availability,
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

                    // 🔹 NAME
                    Text(
                      chemical.chemicalName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 🔹 CHIPS ROW
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        chip('CAS: ${chemical.cas.isEmpty ? "-" : chemical.cas}'),
                        chip(chemical.brand.isEmpty ? '-' : chemical.brand),
                        chip('Qty: ${chemical.quantity.isEmpty ? "-" : chemical.quantity}'),
                        chip(chemical.location.isEmpty ? '-' : chemical.location),
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
                  final chemicals = processChemicals(raw);

                  if (chemicals.isEmpty) {
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
                    itemCount: chemicals.length,
                    itemBuilder: (context, index) {
                      return buildChemicalCard(chemicals[index]);
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