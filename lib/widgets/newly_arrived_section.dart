import 'dart:async';
import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../screens/add_new_chemical_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final orderService = OrderService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Newly Arrived',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
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

            final now = DateTime.now();

            final delivered = snapshot.data!
                .where((o) => o.status.toLowerCase() == 'delivered')
                .where((o) => o.inventoryAdded == false)
                .toList();

            final recent = delivered.where((order) {
              if (order.deliveredAt == null) return false;
              final date = order.deliveredAt!.toDate();
              return now.difference(date).inDays <= 7;
            }).toList();

            recent.sort((a, b) {
              final aDate = a.deliveredAt?.toDate() ?? DateTime(2000);
              final bDate = b.deliveredAt?.toDate() ?? DateTime(2000);
              return bDate.compareTo(aDate);
            });

            if (recent.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'No newly arrived chemicals this week.',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            final displayList = [...recent, ...recent];

            return SizedBox(
              height: 90,
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                itemCount: displayList.length,
                itemBuilder: (context, index) {
                  final order = displayList[index];

                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddNewChemicalScreen(order: order),
                        ),
                      );
                    },
                    child: Container(
                      width: 220,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
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
                          Text(
                            order.chemicalName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            order.brand.isEmpty ? 'Brand not set' : order.brand,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12.5,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            order.receivedBy.isEmpty
                                ? 'Tap to add to inventory'
                                : 'Tap to add • ${order.receivedBy}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
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