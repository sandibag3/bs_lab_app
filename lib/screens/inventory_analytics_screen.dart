import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/chemical_model.dart';
import '../services/consumables_inventory_service.dart';
import '../services/firestore_access_guard.dart';
import '../services/inventory_service.dart';
import '../theme/labmate_theme.dart';

class InventoryAnalyticsScreen extends StatelessWidget {
  const InventoryAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showTwoColumns = constraints.maxWidth >= 980;
          final pagePadding = showTwoColumns
              ? const EdgeInsets.fromLTRB(12, 12, 12, 18)
              : const EdgeInsets.fromLTRB(16, 12, 16, 20);

          return SingleChildScrollView(
            padding: pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AnalyticsIntroCard(),
                const SizedBox(height: 16),
                if (showTwoColumns)
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _ChemicalAnalyticsSection()),
                      SizedBox(width: 14),
                      Expanded(child: _ConsumablesAnalyticsSection()),
                    ],
                  )
                else
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ChemicalAnalyticsSection(),
                      SizedBox(height: 14),
                      _ConsumablesAnalyticsSection(),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AnalyticsIntroCard extends StatelessWidget {
  const _AnalyticsIntroCard();

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.insights_rounded,
              color: colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventory Analytics',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Read-only live summary for chemical and consumables inventory. Counts are calculated locally from the existing inventory streams with no write operations.',
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: palette.selected,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Read only',
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChemicalAnalyticsSection extends StatelessWidget {
  const _ChemicalAnalyticsSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChemicalModel>>(
      stream: InventoryService().getChemicals(),
      builder: (context, snapshot) {
        final accessMessage = _accessMessage(snapshot.error);

        return _AnalyticsSectionCard(
          title: 'Chemical Inventory',
          subtitle: 'CAS-grouped summary with bottle-level availability.',
          icon: Icons.science_rounded,
          accentColor: const Color(0xFF14B8A6),
          child: _buildBody(
            context: context,
            snapshot: snapshot,
            accessMessage: accessMessage,
          ),
        );
      },
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required AsyncSnapshot<List<ChemicalModel>> snapshot,
    required String? accessMessage,
  }) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData &&
        accessMessage == null) {
      return const _SectionStateCard(
        icon: Icons.hourglass_top_rounded,
        title: 'Loading chemical inventory',
        message: 'Fetching the latest chemical inventory summary.',
        isLoading: true,
      );
    }

    if (accessMessage != null) {
      return _SectionStateCard(
        icon: Icons.lock_outline_rounded,
        title: 'Chemical inventory unavailable',
        message: accessMessage,
        accentColor: context.labmate.warning,
      );
    }

    if (snapshot.hasError) {
      return _SectionStateCard(
        icon: Icons.error_outline_rounded,
        title: 'Could not load chemical analytics',
        message: FirestoreAccessGuard.messageFor(snapshot.error),
        accentColor: context.labmate.danger,
      );
    }

    final chemicals = snapshot.data ?? const <ChemicalModel>[];
    if (chemicals.isEmpty) {
      return const _SectionStateCard(
        icon: Icons.inbox_outlined,
        title: 'No chemical inventory yet',
        message:
            'Add chemical inventory items to see CAS groups, stock health, and top locations here.',
      );
    }

    final analytics = _ChemicalInventoryAnalytics.from(chemicals);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatGrid(
          items: [
            _StatItem(
              label: 'CAS groups',
              value: '${analytics.casGroupCount}',
              helper: 'Unique CAS or fallback name groups',
              accentColor: const Color(0xFF14B8A6),
            ),
            _StatItem(
              label: 'Bottles / items',
              value: '${analytics.bottleCount}',
              helper: 'Tracked inventory entries',
              accentColor: const Color(0xFF0EA5E9),
            ),
            _StatItem(
              label: 'Available',
              value: '${analytics.availableCount}',
              helper: 'Ready for use',
              accentColor: const Color(0xFF10B981),
            ),
            _StatItem(
              label: 'Low',
              value: '${analytics.lowCount}',
              helper: 'Needs attention soon',
              accentColor: const Color(0xFFF59E0B),
            ),
            _StatItem(
              label: 'Finished',
              value: '${analytics.finishedCount}',
              helper: 'Marked empty or unavailable',
              accentColor: const Color(0xFFFB7185),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _BreakdownGrid(
          children: [
            _BreakdownListCard(
              title: 'Top Locations',
              subtitle: 'Bottle count',
              accentColor: const Color(0xFF14B8A6),
              items: analytics.topLocations,
              emptyLabel: 'No location data available.',
            ),
            _BreakdownListCard(
              title: 'Top Brands',
              subtitle: 'Bottle count',
              accentColor: const Color(0xFF0EA5E9),
              items: analytics.topBrands,
              emptyLabel: 'No brand data available.',
            ),
          ],
        ),
      ],
    );
  }
}

class _ConsumablesAnalyticsSection extends StatelessWidget {
  const _ConsumablesAnalyticsSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: ConsumablesInventoryService().getConsumablesInventoryDocs(),
      builder: (context, snapshot) {
        final accessMessage = _accessMessage(snapshot.error);

        return _AnalyticsSectionCard(
          title: 'Consumables',
          subtitle:
              'Grouped summary across item types, variants, and locations.',
          icon: Icons.inventory_2_rounded,
          accentColor: const Color(0xFF2563EB),
          child: _buildBody(
            context: context,
            snapshot: snapshot,
            accessMessage: accessMessage,
          ),
        );
      },
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required AsyncSnapshot<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    snapshot,
    required String? accessMessage,
  }) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData &&
        accessMessage == null) {
      return const _SectionStateCard(
        icon: Icons.hourglass_top_rounded,
        title: 'Loading consumables inventory',
        message: 'Fetching the latest consumables summary.',
        isLoading: true,
      );
    }

    if (accessMessage != null) {
      return _SectionStateCard(
        icon: Icons.lock_outline_rounded,
        title: 'Consumables inventory unavailable',
        message: accessMessage,
        accentColor: context.labmate.warning,
      );
    }

    if (snapshot.hasError) {
      return _SectionStateCard(
        icon: Icons.error_outline_rounded,
        title: 'Could not load consumables analytics',
        message: FirestoreAccessGuard.messageFor(snapshot.error),
        accentColor: context.labmate.danger,
      );
    }

    final docs =
        snapshot.data ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    if (docs.isEmpty) {
      return const _SectionStateCard(
        icon: Icons.inbox_outlined,
        title: 'No consumables inventory yet',
        message:
            'Add consumables inventory items to see grouped stock health, categories, and locations here.',
      );
    }

    final analytics = _ConsumablesInventoryAnalytics.from(docs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatGrid(
          items: [
            _StatItem(
              label: 'Item groups',
              value: '${analytics.itemGroupCount}',
              helper: 'Grouped by consumable type',
              accentColor: const Color(0xFF2563EB),
            ),
            _StatItem(
              label: 'Variants / items',
              value:
                  '${analytics.variantCount} / ${analytics.representedItemCount}',
              helper: 'Unique variants / tracked entries',
              accentColor: const Color(0xFF0891B2),
            ),
            _StatItem(
              label: 'Available',
              value: '${analytics.availableCount}',
              helper: 'Ready for use',
              accentColor: const Color(0xFF10B981),
            ),
            _StatItem(
              label: 'Low',
              value: '${analytics.lowCount}',
              helper: 'Numeric or manual low stock',
              accentColor: const Color(0xFFF59E0B),
            ),
            _StatItem(
              label: 'Finished',
              value: '${analytics.finishedCount}',
              helper: 'Marked finished or zero stock',
              accentColor: const Color(0xFFFB7185),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _BreakdownGrid(
          children: [
            _BreakdownListCard(
              title: 'Top Categories',
              subtitle: 'Grouped item count',
              accentColor: const Color(0xFF2563EB),
              items: analytics.topCategories,
              emptyLabel: 'No category data available.',
            ),
            _BreakdownListCard(
              title: 'Top Locations',
              subtitle: 'Tracked entry count',
              accentColor: const Color(0xFF0891B2),
              items: analytics.topLocations,
              emptyLabel: 'No location data available.',
            ),
          ],
        ),
      ],
    );
  }
}

class _AnalyticsSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Widget child;

  const _AnalyticsSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: 12.8,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SectionStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color? accentColor;
  final bool isLoading;

  const _SectionStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.accentColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final resolvedAccent = accentColor ?? colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading)
            SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: resolvedAccent,
              ),
            )
          else
            Icon(icon, color: resolvedAccent, size: 20),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 12.8,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final List<_StatItem> items;

  const _StatGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 540 ? 3 : 2;
        const spacing = 12.0;
        final itemWidth =
            (constraints.maxWidth - ((columnCount - 1) * spacing)) /
            columnCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: _CompactStatCard(item: item),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _CompactStatCard extends StatelessWidget {
  final _StatItem item;

  const _CompactStatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            width: 34,
            decoration: BoxDecoration(
              color: item.accentColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            item.label,
            style: TextStyle(
              color: palette.subtleText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.helper,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 12.2,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownGrid extends StatelessWidget {
  final List<Widget> children;

  const _BreakdownGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 560) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[0]),
              const SizedBox(width: 12),
              Expanded(child: children[1]),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [children[0], const SizedBox(height: 12), children[1]],
        );
      },
    );
  }
}

class _BreakdownListCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accentColor;
  final List<_RankedCount> items;
  final String emptyLabel;

  const _BreakdownListCard({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.items,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: palette.subtleText,
              fontSize: 12.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              emptyLabel,
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 12.6,
                height: 1.4,
              ),
            )
          else
            ...items.take(5).toList().asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == items.length - 1 ? 0 : 10,
                ),
                child: Row(
                  children: [
                    Container(
                      height: 28,
                      width: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: palette.panel,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: palette.border),
                      ),
                      child: Text(
                        '${item.count}',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final String helper;
  final Color accentColor;

  const _StatItem({
    required this.label,
    required this.value,
    required this.helper,
    required this.accentColor,
  });
}

class _RankedCount {
  final String label;
  final int count;

  const _RankedCount({required this.label, required this.count});
}

class _CountBucket {
  final String label;
  int count;

  _CountBucket({required this.label, required this.count});
}

enum _InventoryHealth { available, low, finished }

class _ChemicalInventoryAnalytics {
  final int casGroupCount;
  final int bottleCount;
  final int availableCount;
  final int lowCount;
  final int finishedCount;
  final List<_RankedCount> topLocations;
  final List<_RankedCount> topBrands;

  const _ChemicalInventoryAnalytics({
    required this.casGroupCount,
    required this.bottleCount,
    required this.availableCount,
    required this.lowCount,
    required this.finishedCount,
    required this.topLocations,
    required this.topBrands,
  });

  factory _ChemicalInventoryAnalytics.from(List<ChemicalModel> chemicals) {
    final grouped = InventoryService().groupByCas(chemicals);
    var availableCount = 0;
    var lowCount = 0;
    var finishedCount = 0;

    for (final chemical in chemicals) {
      switch (_classifyChemical(chemical)) {
        case _InventoryHealth.available:
          availableCount++;
          break;
        case _InventoryHealth.low:
          lowCount++;
          break;
        case _InventoryHealth.finished:
          finishedCount++;
          break;
      }
    }

    return _ChemicalInventoryAnalytics(
      casGroupCount: grouped.length,
      bottleCount: chemicals.length,
      availableCount: availableCount,
      lowCount: lowCount,
      finishedCount: finishedCount,
      topLocations: _rankedCounts(
        chemicals.map((chemical) => chemical.location),
      ),
      topBrands: _rankedCounts(chemicals.map((chemical) => chemical.brand)),
    );
  }
}

class _ConsumablesInventoryAnalytics {
  final int itemGroupCount;
  final int variantCount;
  final int representedItemCount;
  final int availableCount;
  final int lowCount;
  final int finishedCount;
  final List<_RankedCount> topCategories;
  final List<_RankedCount> topLocations;

  const _ConsumablesInventoryAnalytics({
    required this.itemGroupCount,
    required this.variantCount,
    required this.representedItemCount,
    required this.availableCount,
    required this.lowCount,
    required this.finishedCount,
    required this.topCategories,
    required this.topLocations,
  });

  factory _ConsumablesInventoryAnalytics.from(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final items = _groupConsumableItems(docs);
    final variantKeys = <String>{};
    var representedItemCount = 0;
    var availableCount = 0;
    var lowCount = 0;
    var finishedCount = 0;

    for (final item in items) {
      variantKeys.add(
        '${item.category.trim().toLowerCase()}|${item.variant.trim().toLowerCase()}',
      );
      representedItemCount += item.representedDocs.length;

      switch (_classifyConsumable(item)) {
        case _InventoryHealth.available:
          availableCount++;
          break;
        case _InventoryHealth.low:
          lowCount++;
          break;
        case _InventoryHealth.finished:
          finishedCount++;
          break;
      }
    }

    return _ConsumablesInventoryAnalytics(
      itemGroupCount: items.length,
      variantCount: variantKeys.length,
      representedItemCount: representedItemCount,
      availableCount: availableCount,
      lowCount: lowCount,
      finishedCount: finishedCount,
      topCategories: _rankedCounts(items.map((item) => item.category)),
      topLocations: _rankedCounts(
        items.expand(
          (item) => item.representedDocs.map(
            (doc) => _readConsumableText(doc.data(), 'location'),
          ),
        ),
      ),
    );
  }
}

class _ConsumableAnalyticsItem {
  final QueryDocumentSnapshot<Map<String, dynamic>> primaryDoc;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> sourceDocs;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> representedDocs;
  final double? numericQuantity;
  final String category;
  final String variant;

  const _ConsumableAnalyticsItem({
    required this.primaryDoc,
    required this.sourceDocs,
    required this.representedDocs,
    required this.numericQuantity,
    required this.category,
    required this.variant,
  });
}

class _ConsumableTypeParts {
  final String category;
  final String variant;

  const _ConsumableTypeParts({required this.category, required this.variant});
}

String? _accessMessage(Object? error) {
  if (!FirestoreAccessGuard.shouldQueryLabScopedData()) {
    return FirestoreAccessGuard.userMessage;
  }

  if (error is LabDataAccessException) {
    return error.message;
  }

  if (error != null && FirestoreAccessGuard.isPermissionDenied(error)) {
    return FirestoreAccessGuard.messageFor(error);
  }

  return null;
}

_InventoryHealth _classifyChemical(ChemicalModel chemical) {
  final availability = chemical.availability.trim().toLowerCase();
  if (availability == 'low' || availability.contains('about')) {
    return _InventoryHealth.low;
  }
  if (chemical.isFinished || availability.contains('unavailable')) {
    return _InventoryHealth.finished;
  }
  return _InventoryHealth.available;
}

_InventoryHealth _classifyConsumable(_ConsumableAnalyticsItem item) {
  final availability = _readConsumableAvailability(
    item.primaryDoc.data(),
  ).trim().toLowerCase();

  if (_isFinishedValue(availability)) {
    return _InventoryHealth.finished;
  }

  if (availability == 'low') {
    return _InventoryHealth.low;
  }

  final quantity = item.numericQuantity;
  if (quantity != null) {
    if (quantity <= 0) {
      return _InventoryHealth.finished;
    }
    if (quantity <= 2) {
      return _InventoryHealth.low;
    }
  }

  return _InventoryHealth.available;
}

bool _isFinishedValue(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized == 'finished' ||
      normalized.contains('finished') ||
      normalized.contains('empty') ||
      normalized.contains('not available') ||
      normalized.contains('unavailable') ||
      normalized == 'nil' ||
      normalized == '0';
}

List<_RankedCount> _rankedCounts(Iterable<String> values, {int limit = 5}) {
  final buckets = <String, _CountBucket>{};

  for (final rawValue in values) {
    final cleanValue = rawValue.trim();
    if (cleanValue.isEmpty) {
      continue;
    }

    final key = cleanValue.toLowerCase();
    final bucket = buckets.putIfAbsent(
      key,
      () => _CountBucket(label: cleanValue, count: 0),
    );
    bucket.count++;
  }

  final ranked = buckets.values.toList()
    ..sort((a, b) {
      final countCompare = b.count.compareTo(a.count);
      if (countCompare != 0) {
        return countCompare;
      }
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });

  return ranked
      .take(limit)
      .map((bucket) => _RankedCount(label: bucket.label, count: bucket.count))
      .toList();
}

String _readConsumableText(Map<String, dynamic> data, String key) {
  return (data[key] ?? '').toString().trim();
}

String _readConsumableAvailability(Map<String, dynamic> data) {
  final availability = _readConsumableText(data, 'availability');
  if (availability.isNotEmpty) {
    return availability;
  }
  return _readConsumableText(data, 'status');
}

double? _readQuantityNumber(String quantity) {
  final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(quantity.trim());
  if (match == null) {
    return null;
  }

  return double.tryParse(match.group(0) ?? '');
}

List<_ConsumableAnalyticsItem> _groupConsumableItems(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final grouped = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

  for (final doc in docs) {
    final key = _readConsumableText(
      doc.data(),
      'consumableType',
    ).trim().toLowerCase();
    grouped.putIfAbsent(key, () => []).add(doc);
  }

  return grouped.values.map((groupDocs) {
    QueryDocumentSnapshot<Map<String, dynamic>>? aggregateDoc;
    for (final doc in groupDocs) {
      if (doc.data()['isAggregate'] == true) {
        aggregateDoc = doc;
        break;
      }
    }

    final primaryDoc = aggregateDoc ?? groupDocs.first;
    final nonAggregateDocs = groupDocs
        .where((doc) => doc.data()['isAggregate'] != true)
        .toList();
    final representedDocs = nonAggregateDocs.isEmpty
        ? groupDocs
        : nonAggregateDocs;
    final primaryData = primaryDoc.data();
    final consumableType = _readConsumableText(primaryData, 'consumableType');
    final typeParts = _parseConsumableType(consumableType);

    final numericQuantity = aggregateDoc == null
        ? representedDocs.fold<double?>(0, (total, doc) {
            final quantity = _readQuantityNumber(
              _readConsumableText(doc.data(), 'quantity'),
            );
            if (quantity == null || total == null) {
              return null;
            }
            return total + quantity;
          })
        : _readQuantityNumber(_readConsumableText(primaryData, 'quantity'));

    return _ConsumableAnalyticsItem(
      primaryDoc: primaryDoc,
      sourceDocs: groupDocs,
      representedDocs: representedDocs,
      numericQuantity: numericQuantity,
      category: typeParts.category,
      variant: typeParts.variant,
    );
  }).toList();
}

_ConsumableTypeParts _parseConsumableType(String consumableType) {
  final cleanType = consumableType.trim();
  if (cleanType.isEmpty) {
    return const _ConsumableTypeParts(category: 'Others', variant: 'Unnamed');
  }

  final normalized = cleanType.toLowerCase();

  if (normalized.contains('preparative tlc')) {
    return const _ConsumableTypeParts(
      category: 'TLC Plates',
      variant: 'Preparative',
    );
  }

  if (normalized.contains('tlc')) {
    return const _ConsumableTypeParts(
      category: 'TLC Plates',
      variant: 'Normal',
    );
  }

  if (normalized.startsWith('gloves')) {
    return _mapTypeWithSuffix(originalType: cleanType, category: 'Gloves');
  }

  if (normalized.startsWith('syringe')) {
    return _mapTypeWithSuffix(originalType: cleanType, category: 'Syringes');
  }

  if (normalized.startsWith('balloon') || normalized.contains('balloon')) {
    return _mapTypeWithSuffix(originalType: cleanType, category: 'Balloons');
  }

  if (normalized.startsWith('needle') || normalized.contains('needle')) {
    return _mapTypeWithSuffix(originalType: cleanType, category: 'Needles');
  }

  if (normalized.contains('filter paper')) {
    return _mapTypeWithSuffix(
      originalType: cleanType,
      category: 'Filter Paper',
    );
  }

  if (normalized.startsWith('silica') || normalized.contains('silica')) {
    return _mapTypeWithSuffix(originalType: cleanType, category: 'Silica');
  }

  if (normalized.startsWith('cotton') || normalized.contains('cotton')) {
    return _mapTypeWithSuffix(originalType: cleanType, category: 'Cotton');
  }

  if (normalized.contains('rubber band')) {
    return _mapTypeWithSuffix(originalType: cleanType, category: 'Rubber Band');
  }

  if (normalized.startsWith('tube') || normalized.contains('tube')) {
    return _mapTypeWithSuffix(originalType: cleanType, category: 'Tubes');
  }

  if (normalized.startsWith('clips') ||
      normalized.startsWith('clip') ||
      normalized.contains('joint clip')) {
    return _mapTypeWithSuffix(originalType: cleanType, category: 'Joint Clips');
  }

  if (normalized.startsWith('grease') || normalized.contains('grease')) {
    return _mapTypeWithSuffix(originalType: cleanType, category: 'Grease');
  }

  if (normalized.startsWith('teflon') || normalized.contains('teflon')) {
    return _mapTypeWithSuffix(originalType: cleanType, category: 'Teflon');
  }

  if (normalized.startsWith('reflux pump') ||
      normalized.contains('reflux pump')) {
    return _mapTypeWithSuffix(
      originalType: cleanType,
      category: 'Reflux Pumps',
    );
  }

  if (normalized.startsWith('column pump') ||
      normalized.contains('column pump')) {
    return _mapTypeWithSuffix(
      originalType: cleanType,
      category: 'Column Pumps',
    );
  }

  return _ConsumableTypeParts(category: 'Others', variant: cleanType);
}

_ConsumableTypeParts _mapTypeWithSuffix({
  required String originalType,
  required String category,
  String defaultVariant = 'Standard',
}) {
  final suffix = _extractVariantSuffix(originalType);
  return _ConsumableTypeParts(
    category: category,
    variant: suffix.isEmpty ? defaultVariant : suffix,
  );
}

String _extractVariantSuffix(String originalType) {
  final parts = originalType.split(RegExp(r'\s*-\s*'));
  if (parts.length <= 1) {
    return '';
  }

  return parts.sublist(1).join(' - ').trim();
}
