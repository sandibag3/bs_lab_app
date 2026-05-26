import 'dart:async';
import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../screens/add_new_chemical_screen.dart';
import '../screens/add_new_consumable_screen.dart';
import '../screens/newly_arrived_items_screen.dart';
import '../services/firestore_access_guard.dart';
import '../services/order_service.dart';
import '../theme/labmate_theme.dart';

class NewlyArrivedSection extends StatefulWidget {
  const NewlyArrivedSection({super.key});

  @override
  State<NewlyArrivedSection> createState() => _NewlyArrivedSectionState();
}

class _NewlyArrivedSectionState extends State<NewlyArrivedSection> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_scrollController.hasClients) {
        final max = _scrollController.position.maxScrollExtent;
        final next = _scrollController.offset + 1;

        if (next >= max) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.jumpTo(next);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  List<OrderModel> _recentArrivals(List<OrderModel> orders) {
    final now = DateTime.now();

    final recent = orders
        .where((o) => o.status.toLowerCase() == 'delivered')
        .where((o) => o.requiresInventoryIntake)
        .where((o) {
          if (o.deliveredAt == null) return false;
          return now.difference(o.deliveredAt!.toDate()).inDays <= 7;
        })
        .toList();

    recent.sort((a, b) {
      final aDate = a.deliveredAt?.toDate() ?? DateTime(2000);
      final bDate = b.deliveredAt?.toDate() ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    return recent;
  }

  Color _entryStatusColor(BuildContext context, OrderModel order) {
    final palette = context.labmate;
    return order.inventoryAdded ? palette.success : context.colorScheme.primary;
  }

  Widget _buildTypeBadge(OrderModel order) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: order.isConsumable
            ? const Color(0x2238BDF8)
            : const Color(0x2214B8A6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        order.typeLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: order.isConsumable
              ? const Color(0xFF38BDF8)
              : const Color(0xFF14B8A6),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEntryBadge(BuildContext context, OrderModel order) {
    final color = _entryStatusColor(context, order);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        order.inventoryAdded ? 'Entered' : 'Pending entry',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildArrivalCard({
    required BuildContext context,
    required OrderModel order,
    required bool isDesktopCard,
    required double cardWidth,
    required double cardPadding,
    required Color cardColor,
    required BorderRadius borderRadius,
    required List<BoxShadow> boxShadow,
    required double rightMargin,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final secondary = order.brand.trim().isNotEmpty
        ? order.brand
        : order.vendor;

    return InkWell(
      borderRadius: borderRadius,
      onTap: order.inventoryAdded
          ? null
          : () => _openEntryScreen(context, order),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          width: cardWidth,
          margin: EdgeInsets.only(right: rightMargin),
          padding: EdgeInsets.all(cardPadding),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: borderRadius,
            border: Border.all(color: palette.border),
            boxShadow: boxShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      order.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: isDesktopCard ? 14.5 : 15,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildTypeBadge(order),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                secondary.trim().isEmpty ? 'Details not set' : secondary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: 12.8,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              _buildEntryBadge(context, order),
            ],
          ),
        ),
      ),
    );
  }

  void _openEntryScreen(BuildContext context, OrderModel order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => order.isConsumable
            ? AddNewConsumableScreen(order: order)
            : AddNewChemicalScreen(order: order),
      ),
    );
  }

  void _openFullList(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewlyArrivedItemsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderService = OrderService();
    final isDesktopLayout = MediaQuery.sizeOf(context).width >= 900;
    final cardHeight = isDesktopLayout ? 110.0 : 116.0;
    final cardWidth = isDesktopLayout ? 220.0 : 240.0;
    final cardPadding = isDesktopLayout ? 11.0 : 14.0;
    final headingFontSize = isDesktopLayout ? 16.0 : 20.0;
    final headerGap = isDesktopLayout ? 8.0 : 12.0;
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final sectionContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => _openFullList(context),
              child: Text(
                'Newly Arrived',
                style: TextStyle(
                  fontSize: headingFontSize,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const Spacer(),
            StreamBuilder<List<OrderModel>>(
              stream: OrderService().getOrders(),
              builder: (context, snapshot) {
                final count = snapshot.hasData
                    ? _recentArrivals(snapshot.data!).length
                    : 0;
                if (count == 0) {
                  return const SizedBox.shrink();
                }

                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFB7185),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              },
            ),
            TextButton(
              onPressed: () => _openFullList(context),
              style: isDesktopLayout
                  ? TextButton.styleFrom(
                      foregroundColor: const Color(0xFFF59E0B),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )
                  : null,
              child: Text(
                isDesktopLayout ? 'View All' : 'View all',
                style: TextStyle(
                  color: isDesktopLayout
                      ? palette.warning
                      : colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: headerGap),
        StreamBuilder<List<OrderModel>>(
          stream: orderService.getOrders(),
          builder: (context, snapshot) {
            if (!FirestoreAccessGuard.shouldQueryLabScopedData()) {
              return Container(
                padding: isDesktopLayout
                    ? EdgeInsets.zero
                    : const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDesktopLayout ? Colors.transparent : palette.panel,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  FirestoreAccessGuard.userMessage,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Container(
                padding: isDesktopLayout
                    ? EdgeInsets.zero
                    : const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDesktopLayout ? Colors.transparent : palette.panel,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  FirestoreAccessGuard.messageFor(snapshot.error),
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return SizedBox(
                height: isDesktopLayout ? 58 : 80,
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            final recent = _recentArrivals(snapshot.data!);

            if (recent.isEmpty) {
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openFullList(context),
                child: Container(
                  padding: isDesktopLayout
                      ? EdgeInsets.zero
                      : const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDesktopLayout ? Colors.transparent : palette.panel,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    'No newly arrived items this week.',
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              );
            }

            final displayList = [...recent, ...recent];

            return SizedBox(
              height: cardHeight,
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                itemCount: displayList.length,
                itemBuilder: (context, index) {
                  final order = displayList[index];
                  return _buildArrivalCard(
                    context: context,
                    order: order,
                    isDesktopCard: true,
                    cardWidth: cardWidth,
                    cardPadding: cardPadding,
                    cardColor: palette.panelAlt,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [],
                    rightMargin: 10,
                  );
                },
              ),
            );
          },
        ),
      ],
    );

    if (isDesktopLayout) {
      return Container(
        height: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: palette.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.border),
        ),
        child: sectionContent,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => _openFullList(context),
              child: Text(
                'Newly Arrived',
                style: TextStyle(
                  fontSize: headingFontSize,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const Spacer(),
            StreamBuilder<List<OrderModel>>(
              stream: OrderService().getOrders(),
              builder: (context, snapshot) {
                final count = snapshot.hasData
                    ? _recentArrivals(snapshot.data!).length
                    : 0;
                if (count == 0) {
                  return const SizedBox.shrink();
                }

                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFB7185),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              },
            ),
            TextButton(
              onPressed: () => _openFullList(context),
              child: const Text(
                'View all',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<OrderModel>>(
          stream: orderService.getOrders(),
          builder: (context, snapshot) {
            if (!FirestoreAccessGuard.shouldQueryLabScopedData()) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  FirestoreAccessGuard.userMessage,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  FirestoreAccessGuard.messageFor(snapshot.error),
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final recent = _recentArrivals(snapshot.data!);

            if (recent.isEmpty) {
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openFullList(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.panel,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text(
                    'No newly arrived items this week.',
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }

            final displayList = [...recent, ...recent];

            return SizedBox(
              height: cardHeight,
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                itemCount: displayList.length,
                itemBuilder: (context, index) {
                  final order = displayList[index];
                  return _buildArrivalCard(
                    context: context,
                    order: order,
                    isDesktopCard: false,
                    cardWidth: cardWidth,
                    cardPadding: cardPadding,
                    cardColor: palette.panel,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: Theme.of(context).brightness == Brightness.dark
                        ? const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ]
                        : const [],
                    rightMargin: 12,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
