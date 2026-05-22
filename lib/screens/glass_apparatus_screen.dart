import 'package:flutter/material.dart';

import '../models/glass_apparatus_model.dart';
import '../services/firestore_access_guard.dart';
import '../services/glass_apparatus_service.dart';
import '../theme/labmate_theme.dart';
import '../widgets/responsive_page_container.dart';
import 'add_glass_apparatus_screen.dart';

enum GlassApparatusSortOption {
  nameAsc,
  nameDesc,
  categoryAsc,
  quantityAsc,
  quantityDesc,
  recentlyAdded,
  lastUpdated,
}

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
  GlassApparatusSortOption _sortOption = GlassApparatusSortOption.nameAsc;

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

  String _sortLabel(GlassApparatusSortOption option) {
    switch (option) {
      case GlassApparatusSortOption.nameAsc:
        return 'Name A-Z';
      case GlassApparatusSortOption.nameDesc:
        return 'Name Z-A';
      case GlassApparatusSortOption.categoryAsc:
        return 'Category A-Z';
      case GlassApparatusSortOption.quantityAsc:
        return 'Quantity Low to High';
      case GlassApparatusSortOption.quantityDesc:
        return 'Quantity High to Low';
      case GlassApparatusSortOption.recentlyAdded:
        return 'Recently Added';
      case GlassApparatusSortOption.lastUpdated:
        return 'Last Updated';
    }
  }

  int _compareName(GlassApparatusModel a, GlassApparatusModel b) {
    return a.normalizedName.toLowerCase().compareTo(
      b.normalizedName.toLowerCase(),
    );
  }

  List<GlassApparatusModel> _sortApparatus(
    List<GlassApparatusModel> apparatus,
  ) {
    final sorted = [...apparatus];

    sorted.sort((a, b) {
      switch (_sortOption) {
        case GlassApparatusSortOption.nameAsc:
          return _compareName(a, b);
        case GlassApparatusSortOption.nameDesc:
          return _compareName(b, a);
        case GlassApparatusSortOption.categoryAsc:
          final categoryComparison = a.normalizedCategory
              .toLowerCase()
              .compareTo(b.normalizedCategory.toLowerCase());
          if (categoryComparison != 0) {
            return categoryComparison;
          }
          return _compareName(a, b);
        case GlassApparatusSortOption.quantityAsc:
          final quantityComparison = a.quantity.compareTo(b.quantity);
          if (quantityComparison != 0) {
            return quantityComparison;
          }
          return _compareName(a, b);
        case GlassApparatusSortOption.quantityDesc:
          final quantityComparison = b.quantity.compareTo(a.quantity);
          if (quantityComparison != 0) {
            return quantityComparison;
          }
          return _compareName(a, b);
        case GlassApparatusSortOption.recentlyAdded:
          final dateComparison = b.createdAt.compareTo(a.createdAt);
          if (dateComparison != 0) {
            return dateComparison;
          }
          return _compareName(a, b);
        case GlassApparatusSortOption.lastUpdated:
          final dateComparison = b.updatedAt.compareTo(a.updatedAt);
          if (dateComparison != 0) {
            return dateComparison;
          }
          return _compareName(a, b);
      }
    });

    return sorted;
  }

  List<_ApparatusCategoryGroup> _buildCategoryGroups(
    List<GlassApparatusModel> apparatus,
  ) {
    final customCategories =
        apparatus
            .map((item) => item.normalizedCategory)
            .where(
              (category) => !GlassApparatusModel.categories.contains(category),
            )
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final categories = [...GlassApparatusModel.categories, ...customCategories];

    if (_sortOption == GlassApparatusSortOption.categoryAsc) {
      categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }

    return categories.map((category) {
      final items = apparatus
          .where((item) => item.normalizedCategory == category)
          .toList();

      return _ApparatusCategoryGroup(category: category, apparatus: items);
    }).toList();
  }

  Widget _buildSearchBar({bool dense = false}) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return TextField(
      controller: _searchController,
      style: TextStyle(color: colorScheme.onSurface),
      onChanged: (_) {
        setState(() {});
      },
      decoration: InputDecoration(
        hintText: 'Search by name, category, size, location, or in-charge',
        hintStyle: TextStyle(color: palette.subtleText),
        prefixIcon: Icon(Icons.search_rounded, color: palette.mutedText),
        suffixIcon: _searchController.text.trim().isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: Icon(Icons.close_rounded, color: palette.subtleText),
              ),
        filled: true,
        fillColor: palette.panel,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: dense ? 11 : 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildConditionFilters({bool dense = false}) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

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
                color: isSelected ? colorScheme.primary : palette.mutedText,
                fontSize: dense ? 12.0 : 12.5,
                fontWeight: FontWeight.w700,
              ),
              backgroundColor: palette.panel,
              selectedColor: palette.selected,
              side: BorderSide(
                color: isSelected ? colorScheme.primary : palette.border,
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

  Widget _buildSortDropdown({bool dense = false}) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      height: dense ? 46 : null,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<GlassApparatusSortOption>(
          value: _sortOption,
          isExpanded: true,
          dropdownColor: palette.panel,
          style: TextStyle(color: colorScheme.onSurface),
          items: GlassApparatusSortOption.values.map((option) {
            return DropdownMenuItem<GlassApparatusSortOption>(
              value: option,
              child: Text(
                'Sort: ${_sortLabel(option)}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: dense ? 12.5 : 13,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _sortOption = value;
            });
          },
        ),
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
            final sortedApparatus = _sortApparatus(filteredApparatus);
            final categoryGroups = _buildCategoryGroups(sortedApparatus);

            return LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;
                final pagePadding = isDesktop ? 12.0 : 16.0;
                final sectionGap = isDesktop ? 10.0 : 14.0;

                return Padding(
                  padding: EdgeInsets.all(pagePadding),
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
                        dense: isDesktop,
                      ),
                      SizedBox(height: sectionGap),
                      if (isDesktop)
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildSearchBar(dense: true),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: _buildConditionFilters(dense: true),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 220,
                              child: _buildSortDropdown(dense: true),
                            ),
                          ],
                        )
                      else ...[
                        _buildSearchBar(),
                        const SizedBox(height: 12),
                        _buildConditionFilters(),
                        const SizedBox(height: 12),
                        _buildSortDropdown(),
                      ],
                      SizedBox(height: sectionGap),
                      if (apparatus.isEmpty) ...[
                        const _ApparatusEmptyState(),
                        SizedBox(height: sectionGap),
                      ] else if (filteredApparatus.isEmpty) ...[
                        const _ApparatusFilteredEmptyState(),
                        SizedBox(height: sectionGap),
                      ],
                      Expanded(
                        child: ListView.builder(
                          itemCount: categoryGroups.length,
                          itemBuilder: (context, index) {
                            final group = categoryGroups[index];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: isDesktop ? 8 : 12,
                              ),
                              child: _ApparatusCategorySection(
                                group: group,
                                dense: isDesktop,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
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
    final palette = context.labmate;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.mutedText,
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
  final bool dense;

  const _ApparatusHeaderCard({
    required this.apparatusCount,
    required this.totalQuantity,
    required this.onAddApparatus,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dense ? 14 : 18),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: dense
          ? Row(
              children: [
                Expanded(
                  child: _ApparatusHeaderCopy(
                    apparatusCount: apparatusCount,
                    totalQuantity: totalQuantity,
                  ),
                ),
                const SizedBox(width: 16),
                _ApparatusAddButton(onAddApparatus: onAddApparatus),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ApparatusHeaderCopy(
                  apparatusCount: apparatusCount,
                  totalQuantity: totalQuantity,
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _ApparatusAddButton(onAddApparatus: onAddApparatus),
                ),
              ],
            ),
    );
  }
}

class _ApparatusHeaderCopy extends StatelessWidget {
  final int apparatusCount;
  final int totalQuantity;

  const _ApparatusHeaderCopy({
    required this.apparatusCount,
    required this.totalQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Glass Apparatus',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          apparatusCount == 0
              ? 'Track shared glassware by category, count, condition, and location.'
              : '$apparatusCount records with $totalQuantity total pieces in this lab.',
          style: TextStyle(
            color: palette.subtleText,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _ApparatusAddButton extends StatelessWidget {
  final VoidCallback onAddApparatus;

  const _ApparatusAddButton({required this.onAddApparatus});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onAddApparatus,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF14B8A6),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      icon: const Icon(Icons.add_rounded),
      label: const Text(
        'Add Apparatus',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ApparatusEmptyState extends StatelessWidget {
  const _ApparatusEmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        'No glass apparatus added yet. Add the first record to start organizing shared glassware.',
        style: TextStyle(color: palette.mutedText, fontSize: 13, height: 1.4),
      ),
    );
  }
}

class _ApparatusFilteredEmptyState extends StatelessWidget {
  const _ApparatusFilteredEmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        'No glass apparatus matches current filters.',
        style: TextStyle(
          color: palette.mutedText,
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
  final bool dense;

  const _ApparatusCategorySection({required this.group, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: group.count > 0,
          tilePadding: EdgeInsets.symmetric(horizontal: dense ? 10 : 14),
          childrenPadding: EdgeInsets.fromLTRB(
            dense ? 10 : 12,
            0,
            dense ? 10 : 12,
            dense ? 8 : 12,
          ),
          iconColor: palette.mutedText,
          collapsedIconColor: palette.subtleText,
          leading: SizedBox(
            height: dense ? 32 : 40,
            width: dense ? 32 : 40,
            child: CircleAvatar(
              backgroundColor: const Color(0x22FB923C),
              child: Icon(
                _iconForCategory(group.category),
                color: const Color(0xFFFB923C),
                size: dense ? 17 : 20,
              ),
            ),
          ),
          title: Text(
            group.category,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            '${group.count} ${group.count == 1 ? 'record' : 'records'} - ${group.totalQuantity} pieces',
            style: TextStyle(color: palette.subtleText, fontSize: 12.4),
          ),
          children: group.apparatus.isEmpty
              ? [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'No records in this category yet.',
                        style: TextStyle(
                          color: palette.subtleText,
                          fontSize: 12.8,
                        ),
                      ),
                    ),
                  ),
                ]
              : [
                  if (dense) const _ApparatusDesktopHeader(),
                  ...group.apparatus.map((item) {
                    return Padding(
                      padding: EdgeInsets.only(top: dense ? 6 : 10),
                      child: _ApparatusCard(apparatus: item, dense: dense),
                    );
                  }),
                ],
        ),
      ),
    );
  }
}

class _ApparatusDesktopHeader extends StatelessWidget {
  const _ApparatusDesktopHeader();

  Widget _header(BuildContext context, String label, {int flex = 1}) {
    final palette = context.labmate;
    return Expanded(
      flex: flex,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: palette.subtleText,
          fontSize: 10.8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(58, 2, 34, 0),
      child: Row(
        children: [
          _header(context, 'Name', flex: 3),
          const SizedBox(width: 10),
          _header(context, 'Category', flex: 2),
          const SizedBox(width: 10),
          _header(context, 'Size'),
          const SizedBox(width: 10),
          _header(context, 'Qty'),
          const SizedBox(width: 10),
          _header(context, 'Condition', flex: 2),
          const SizedBox(width: 10),
          _header(context, 'Location', flex: 2),
          const SizedBox(width: 10),
          _header(context, 'In-charge', flex: 2),
        ],
      ),
    );
  }
}

class _ApparatusCard extends StatelessWidget {
  final GlassApparatusModel apparatus;
  final bool dense;

  const _ApparatusCard({required this.apparatus, this.dense = false});

  Widget _desktopText(
    BuildContext context,
    String value, {
    int flex = 1,
    bool strong = false,
  }) {
    final displayValue = value.trim().isEmpty ? 'Not set' : value.trim();
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Expanded(
      flex: flex,
      child: Text(
        displayValue,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: strong ? colorScheme.onSurface : palette.mutedText,
          fontSize: strong ? 14.0 : 12.8,
          height: 1.25,
          fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildDesktopCard(BuildContext context) {
    final palette = context.labmate;
    return Material(
      color: palette.panelAlt,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: palette.panel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border),
                ),
                child: Icon(
                  _iconForCategory(apparatus.normalizedCategory),
                  color: const Color(0xFFFB923C),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              _desktopText(
                context,
                apparatus.normalizedName,
                flex: 3,
                strong: true,
              ),
              const SizedBox(width: 10),
              _desktopText(context, apparatus.normalizedCategory, flex: 2),
              const SizedBox(width: 10),
              _desktopText(context, apparatus.displaySize),
              const SizedBox(width: 10),
              _desktopText(context, apparatus.quantity.toString()),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _ConditionChip(
                    condition: apparatus.normalizedCondition,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _desktopText(context, apparatus.location, flex: 2),
              const SizedBox(width: 10),
              _desktopText(context, apparatus.incharge, flex: 2),
              const SizedBox(width: 8),
              Icon(Icons.edit_outlined, color: palette.subtleText, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCard(BuildContext context) {
    final location = apparatus.location.trim();
    final incharge = apparatus.incharge.trim();
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Material(
      color: palette.panel,
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
                  color: palette.panelAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
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
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 15,
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
                        style: TextStyle(
                          color: palette.mutedText,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.edit_outlined, color: palette.subtleText, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return dense ? _buildDesktopCard(context) : _buildMobileCard(context);
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.mutedText,
          fontSize: 12.3,
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
          fontSize: 12.2,
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
