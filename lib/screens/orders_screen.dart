import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/order_model.dart';
import '../services/activity_service.dart';
import '../services/order_service.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orderService = OrderService();
    final String currentUserName = AppState.instance.authenticatedUserName;

    Color statusColor(String status) {
      switch (status.toLowerCase()) {
        case 'delivered':
          return Colors.greenAccent;
        default:
          return const Color(0xFF14B8A6);
      }
    }

    String formatOrderedNote(OrderModel order) {
      final date = order.orderedAt.toDate();
      return 'Ordered on ${date.day}/${date.month}/${date.year} by ${order.orderedBy}';
    }

    String formatDeliveredNote(OrderModel order) {
      if (order.deliveredAt == null) return '';
      final date = order.deliveredAt!.toDate();
      return 'Delivered on ${date.day}/${date.month}/${date.year} received by ${order.receivedBy}';
    }

    Future<void> markDelivered(OrderModel order) async {
      await orderService.updateOrderStatus(
        docId: order.id,
        status: 'delivered',
        receivedBy: currentUserName,
      );
      await ActivityService().addActivity(
        labId: AppState.instance.resolveWriteLabId(order.labId),
        type: 'order_delivered',
        message: 'Order delivered for ${order.displayName}',
        actorName: currentUserName,
        createdBy: AppState.instance.authenticatedUserId,
        relatedId: order.id,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: orderService.getOrders(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data!;

          if (orders.isEmpty) {
            return const Center(
              child: Text(
                'No orders yet.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final isDelivered = order.status.toLowerCase() == 'delivered';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
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
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Type: ${order.typeLabel}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    if (order.isChemical && order.cas.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'CAS: ${order.cas}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (order.packSize.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Pack Size: ${order.packSize}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (order.brand.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Brand: ${order.brand}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (order.vendor.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Vendor: ${order.vendor}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Quantity: ${order.quantity.isEmpty ? "-" : order.quantity}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    if (order.modeOfPurchase.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Mode: ${order.modeOfPurchase}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      formatOrderedNote(order),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12.5,
                      ),
                    ),
                    if (isDelivered) ...[
                      const SizedBox(height: 6),
                      Text(
                        formatDeliveredNote(order),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      isDelivered ? 'Delivered' : 'Ordered',
                      style: TextStyle(
                        color: statusColor(order.status),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!isDelivered) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await markDelivered(order);

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Order marked as delivered'),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Mark as Delivered'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
