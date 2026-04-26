import 'dart:async';
import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../screens/add_new_chemical_screen.dart';
import '../screens/add_new_consumable_screen.dart';
import '../screens/newly_arrived_items_screen.dart';
import '../services/order_service.dart';

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

  List<OrderModel> _pendingRecentOrders(List<OrderModel> orders) {
    final now = DateTime.now();

    final recent = orders
        .where((o) => o.status.toLowerCase() == 'delivered')
        .where((o) => o.requiresInventoryIntake)
        .where((o) => o.inventoryAdded == false)
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => _openFullList(context),
              child: const Text(
                'Newly Arrived',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const Spacer(),
            StreamBuilder<List<OrderModel>>(
              stream: OrderService().getOrders(),
              builder: (context, snapshot) {
                final count = snapshot.hasData
                    ? _pendingRecentOrders(snapshot.data!).length
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
                style: TextStyle(
                  color: Color(0xFF14B8A6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<OrderModel>>(
          stream: orderService.getOrders(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final recent = _pendingRecentOrders(snapshot.data!);

            if (recent.isEmpty) {
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openFullList(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'No newly arrived items this week.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              );
            }

            final displayList = [...recent, ...recent];

            return SizedBox(
              height: 104,
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                itemCount: displayList.length,
                itemBuilder: (context, index) {
                  final order = displayList[index];
                  final secondary = order.brand.trim().isNotEmpty
                      ? order.brand
                      : order.vendor;

                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _openEntryScreen(context, order),
                    child: Container(
                      width: 240,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  order.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: order.isConsumable
                                      ? const Color(0x2238BDF8)
                                      : const Color(0x2214B8A6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  order.typeLabel,
                                  style: TextStyle(
                                    color: order.isConsumable
                                        ? const Color(0xFF38BDF8)
                                        : const Color(0xFF14B8A6),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            secondary.trim().isEmpty
                                ? 'Details not set'
                                : secondary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12.5,
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Tap to confirm entry',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF14B8A6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
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
