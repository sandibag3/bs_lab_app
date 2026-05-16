import 'package:flutter/material.dart';

import '../models/glass_apparatus_model.dart';
import '../services/firestore_access_guard.dart';
import '../services/glass_apparatus_service.dart';
import '../widgets/responsive_page_container.dart';
import 'add_glass_apparatus_screen.dart';

class GlassApparatusScreen extends StatefulWidget {
  const GlassApparatusScreen({super.key});

  @override
  State<GlassApparatusScreen> createState() => _GlassApparatusScreenState();
}

class _GlassApparatusScreenState extends State<GlassApparatusScreen> {
  static const List<String> _conditionFilterOptions = [
    'All',
    'Available',
    'Limited',
    'Damaged',
    'Missing',
  ];

  final TextEditingController _searchController = TextEditingController();
  String _selectedConditionFilter = _conditionFilterOptions.first;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddApparatus() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddGlassApparatusScreen()),
    );
  }

  bool _matchesSearch(GlassApparatusModel apparatus, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final searchableText = [
      apparatus.normalizedName,
      apparatus.normalizedCategory,
      apparatus.size,
      apparatus.location,
      apparatus.incharge,
      apparatus.notes,
    ].join(' ').toLowerCase();

    return searchableText.contains(normalizedQuery);
  }

  List<GlassApparatusModel> _applyFilters(List<GlassApparatusModel> apparatus) {
    final query = _searchController.text.trim();

    return apparatus.where((item) {
      final matchesSearch = _matchesSearch(item, query);
      final matchesCondition = _selectedConditionFilter == 'All'
          ? true
          : item.normalizedCondition == _selectedConditionFilter;
      return matchesSearch && matchesCondition;
    }).toList();
  }

  List<_ApparatusCategoryGroup> _buildCategoryGroups(
    List<GlassApparatusModel> apparatus,
  ) {
    return GlassApparatusModel.categories.map((category) {
      final items = apparatus
          .where((item) => item.normalizedCategory == category)
          .toList();

      items.sort((a, b) {
        return a.normalizedName.toLowerCase().compareTo(
          b.normalizedName.toLowerCase(),
        );
      });

      return _ApparatusCategoryGroup(category: category, apparatus: items);
    }).toList();
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white),
      onChanged: (_) {
        setState(() {});
      },
      decoration: InputDecoration(
        hintText: 'Search by name, category, size, location, or in-charge',
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
        suffixIcon: _searchController.text.trim().isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
              ),
        filled: true,
        fillColor: const Color(0xFF111827),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildConditionFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _conditionFilterOptions.map((condition) {
          final isSelected = condition == _selectedConditionFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(condition),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedConditionFilter = condition;
                });
              },
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              backgroundColor: const Color(0xFF111827),
              selectedColor: const Color(0xFF14B8A6),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF14B8A6)
                    : Colors.white.withValues(alpha: 0.08),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apparatusService = GlassApparatusService();

    return SafeArea(
      child: ResponsivePageContainer(
        child: StreamBuilder<List<GlassApparatusModel>>(
        stream: apparatusService.getApparatus(),
        builder: (context, snapshot) {
          if (!FirestoreAccessGuard.shouldQueryLabScopedData()) {
            return const _ApparatusAccessState(
              title: FirestoreAccessGuard.userMessage,
            );
          }

          if (snapshot.hasError) {
            return _ApparatusAccessState(
              title: FirestoreAccessGuard.messageFor(snapshot.error),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF14B8A6)),
            );
          }

          final apparatus = snapshot.data ?? [];
          final filteredApparatus = _applyFilters(apparatus);
          final categoryGroups = _buildCategoryGroups(filteredApparatus);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ApparatusHeaderCard(
                  apparatusCount: apparatus.length,
                  totalQuantity: apparatus.fold<int>(
                    0,
                    (total, item) => total + item.quantity,
                  ),
                  onAddApparatus: _openAddApparatus,
                ),
                const SizedBox(height: 14),
                _buildSearchBar(),
                const SizedBox(height: 12),
                _buildConditionFilters(),
                const SizedBox(height: 14),
                if (apparatus.isEmpty) ...[
                  const _ApparatusEmptyState(),
                  const SizedBox(height: 14),
                ] else if (filteredApparatus.isEmpty) ...[
                  const _ApparatusFilteredEmptyState(),
                  const SizedBox(height: 14),
                ],
                Expanded(
                  child: ListView.builder(
                    itemCount: categoryGroups.length,
                    itemBuilder: (context, index) {
                      final group = categoryGroups[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ApparatusCategorySection(group: group),
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

class _ApparatusAccessState extends StatelessWidget {
  final String title;

  const _ApparatusAccessState({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _ApparatusHeaderCard extends StatelessWidget {
  final int apparatusCount;
  final int totalQuantity;
  final VoidCallback onAddApparatus;

  const _ApparatusHeaderCard({
    required this.apparatusCount,
    required this.totalQuantity,
    required this.onAddApparatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Glass Apparatus',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            apparatusCount == 0
                ? 'Track shared glassware by category, count, condition, and location.'
                : '$apparatusCount records with $totalQuantity total pieces in this lab.',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: onAddApparatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14B8A6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add Apparatus',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApparatusEmptyState extends StatelessWidget {
  const _ApparatusEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: const Text(
        'No glass apparatus added yet. Add the first record to start organizing shared glassware.',
        style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
      ),
    );
  }
}

class _ApparatusFilteredEmptyState extends StatelessWidget {
  const _ApparatusFilteredEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: const Text(
        'No glass apparatus matches current filters.',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 13.2,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }
}

class _ApparatusCategorySection extends StatelessWidget {
  final _ApparatusCategoryGroup group;

  const _ApparatusCategorySection({required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: group.count > 0,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white54,
          leading: CircleAvatar(
            backgroundColor: const Color(0x22FB923C),
            child: Icon(
              _iconForCategory(group.category),
              color: const Color(0xFFFB923C),
              size: 20,
            ),
          ),
          title: Text(
            group.category,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            '${group.count} ${group.count == 1 ? 'record' : 'records'} - ${group.totalQuantity} pieces',
            style: const TextStyle(color: Colors.white60, fontSize: 12.4),
          ),
          children: group.apparatus.isEmpty
              ? const [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'No records in this category yet.',
                        style: TextStyle(color: Colors.white54, fontSize: 12.8),
                      ),
                    ),
                  ),
                ]
              : group.apparatus.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _ApparatusCard(apparatus: item),
                  );
                }).toList(),
        ),
      ),
    );
  }
}

class _ApparatusCard extends StatelessWidget {
  final GlassApparatusModel apparatus;

  const _ApparatusCard({required this.apparatus});

  @override
  Widget build(BuildContext context) {
    final location = apparatus.location.trim();
    final incharge = apparatus.incharge.trim();

    return Material(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AddGlassApparatusScreen(existingApparatus: apparatus),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _iconForCategory(apparatus.normalizedCategory),
                  color: const Color(0xFFFB923C),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apparatus.normalizedName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(label: apparatus.displaySize),
                        _InfoChip(label: 'Qty ${apparatus.quantity}'),
                        _ConditionChip(
                          condition: apparatus.normalizedCondition,
                        ),
                      ],
                    ),
                    if (location.isNotEmpty || incharge.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Text(
                        [
                          if (location.isNotEmpty) location,
                          if (incharge.isNotEmpty) 'In-charge: $incharge',
                        ].join(' - '),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.edit_outlined, color: Colors.white38, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  final String condition;

  const _ConditionChip({required this.condition});

  Color _backgroundColor() {
    switch (condition) {
      case 'Limited':
        return const Color(0xFF713F12);
      case 'Damaged':
        return const Color(0xFF7C2D12);
      case 'Missing':
        return const Color(0xFF7F1D1D);
      default:
        return const Color(0xFF14532D);
    }
  }

  Color _textColor() {
    switch (condition) {
      case 'Limited':
        return const Color(0xFFFDE68A);
      case 'Damaged':
        return const Color(0xFFFDBA74);
      case 'Missing':
        return const Color(0xFFFCA5A5);
      default:
        return const Color(0xFFBBF7D0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _backgroundColor().withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _textColor().withValues(alpha: 0.35)),
      ),
      child: Text(
        condition,
        style: TextStyle(
          color: _textColor(),
          fontSize: 11.8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ApparatusCategoryGroup {
  final String category;
  final List<GlassApparatusModel> apparatus;

  const _ApparatusCategoryGroup({
    required this.category,
    required this.apparatus,
  });

  int get count => apparatus.length;

  int get totalQuantity {
    return apparatus.fold<int>(0, (total, item) => total + item.quantity);
  }
}

IconData _iconForCategory(String category) {
  switch (category) {
    case 'Beakers':
      return Icons.local_drink_outlined;
    case 'Conical flasks':
      return Icons.science_rounded;
    case 'Round-bottom flasks':
      return Icons.bubble_chart_outlined;
    case 'Measuring cylinders':
      return Icons.straighten_rounded;
    case 'Pipettes':
      return Icons.colorize_rounded;
    case 'Burettes':
      return Icons.water_drop_outlined;
    case 'Condensers':
      return Icons.device_thermostat_rounded;
    case 'Funnels':
    case 'Separating funnels':
      return Icons.filter_alt_outlined;
    case 'Test tubes':
      return Icons.biotech_rounded;
    case 'Watch glasses':
      return Icons.radio_button_unchecked_rounded;
    case 'Desiccators':
      return Icons.inventory_2_outlined;
    case 'Adapters and joints':
      return Icons.hub_outlined;
    default:
      return Icons.science_outlined;
  }
}
