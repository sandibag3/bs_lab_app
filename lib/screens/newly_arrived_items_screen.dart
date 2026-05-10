import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/firestore_access_guard.dart';
import '../services/order_service.dart';
import 'add_new_chemical_screen.dart';
import 'add_new_consumable_screen.dart';

class NewlyArrivedItemsScreen extends StatelessWidget {
  const NewlyArrivedItemsScreen({super.key});

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

  String _formatDate(OrderModel order) {
    final deliveredAt = order.deliveredAt;
    if (deliveredAt == null) return 'Date unavailable';

    final date = deliveredAt.toDate();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final orderService = OrderService();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Newly Arrived',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: orderService.getOrders(),
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

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  FirestoreAccessGuard.messageFor(snapshot.error),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final recent = _pendingRecentOrders(snapshot.data!);

          if (recent.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No delivered chemicals or consumables are pending entry in the last 7 days.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: recent.length,
            itemBuilder: (context, index) {
              final order = recent[index];
              final secondary =
                  order.brand.trim().isNotEmpty ? order.brand : order.vendor;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _openEntryScreen(context, order),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  order.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
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
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Delivered on ${_formatDate(order)}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Quantity: ${order.quantity.trim().isEmpty ? '-' : order.quantity}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          if (secondary.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              order.brand.trim().isNotEmpty
                                  ? 'Brand: $secondary'
                                  : 'Vendor: $secondary',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          const Text(
                            'Tap to confirm entry',
                            style: TextStyle(
                              color: Color(0xFF14B8A6),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
