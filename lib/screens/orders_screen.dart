import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/order_model.dart';
import '../services/activity_service.dart';
import '../services/firestore_access_guard.dart';
import '../services/order_service.dart';

enum OrdersViewMode { compact, detailed }

enum OrdersSortOption { newestFirst, oldestFirst, status, type }

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final OrderService orderService = OrderService();

  OrdersViewMode _viewMode = OrdersViewMode.compact;
  OrdersSortOption _sortOption = OrdersSortOption.newestFirst;

  String get _currentUserName => AppState.instance.authenticatedUserName;

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.greenAccent;
      default:
        return const Color(0xFF14B8A6);
    }
  }

  String _statusText(OrderModel order) {
    return order.status.toLowerCase() == 'delivered' ? 'Delivered' : 'Ordered';
  }

  int _statusSortWeight(String status) {
    switch (status.toLowerCase()) {
      case 'ordered':
        return 0;
      case 'delivered':
        return 1;
      default:
        return 2;
    }
  }

  String _sortLabel(OrdersSortOption option) {
    switch (option) {
      case OrdersSortOption.newestFirst:
        return 'Newest first';
      case OrdersSortOption.oldestFirst:
        return 'Oldest first';
      case OrdersSortOption.status:
        return 'Status';
      case OrdersSortOption.type:
        return 'Type';
    }
  }

  String _formatShortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String _formatOrderedNote(OrderModel order) {
    final date = order.orderedAt.toDate();
    return 'Ordered on ${_formatShortDate(date)} by ${order.orderedBy}';
  }

  String _formatDeliveredNote(OrderModel order) {
    if (order.deliveredAt == null) return '';
    final date = order.deliveredAt!.toDate();
    return 'Delivered on ${_formatShortDate(date)} received by ${order.receivedBy}';
  }

  List<OrderModel> _sortOrders(List<OrderModel> input) {
    final list = [...input];

    list.sort((a, b) {
      switch (_sortOption) {
        case OrdersSortOption.newestFirst:
          return b.orderedAt.compareTo(a.orderedAt);

        case OrdersSortOption.oldestFirst:
          return a.orderedAt.compareTo(b.orderedAt);

        case OrdersSortOption.status:
          final statusComparison = _statusSortWeight(
            a.status,
          ).compareTo(_statusSortWeight(b.status));
          if (statusComparison != 0) {
            return statusComparison;
          }
          return b.orderedAt.compareTo(a.orderedAt);

        case OrdersSortOption.type:
          final typeComparison = a.typeLabel
              .toLowerCase()
              .compareTo(b.typeLabel.toLowerCase());
          if (typeComparison != 0) {
            return typeComparison;
          }
          return b.orderedAt.compareTo(a.orderedAt);
      }
    });

    return list;
  }

  Future<void> _markDelivered(OrderModel order) async {
    await orderService.updateOrderStatus(
      docId: order.id,
      status: 'delivered',
      receivedBy: _currentUserName,
    );
    await ActivityService().addActivity(
      labId: AppState.instance.resolveWriteLabId(order.labId),
      type: 'order_delivered',
      message: 'Order delivered for ${order.displayName}',
      actorName: _currentUserName,
      createdBy: AppState.instance.authenticatedUserId,
      relatedId: order.id,
    );
  }

  Widget _buildViewToggle() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Compact'),
          selected: _viewMode == OrdersViewMode.compact,
          selectedColor: const Color(0xFF14B8A6),
          backgroundColor: const Color(0xFF1E293B),
          labelStyle: TextStyle(
            color: _viewMode == OrdersViewMode.compact
                ? Colors.white
                : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) {
            setState(() {
              _viewMode = OrdersViewMode.compact;
            });
          },
        ),
        ChoiceChip(
          label: const Text('Detailed'),
          selected: _viewMode == OrdersViewMode.detailed,
          selectedColor: const Color(0xFF14B8A6),
          backgroundColor: const Color(0xFF1E293B),
          labelStyle: TextStyle(
            color: _viewMode == OrdersViewMode.detailed
                ? Colors.white
                : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) {
            setState(() {
              _viewMode = OrdersViewMode.detailed;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<OrdersSortOption>(
          value: _sortOption,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white),
          isExpanded: true,
          items: OrdersSortOption.values.map((option) {
            return DropdownMenuItem<OrdersSortOption>(
              value: option,
              child: Text(
                'Sort: ${_sortLabel(option)}',
                style: const TextStyle(color: Colors.white),
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

  Widget _buildControlsCard(int itemCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$itemCount ${itemCount == 1 ? 'order' : 'orders'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _buildViewToggle(),
          const SizedBox(height: 12),
          _buildSortDropdown(),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(OrderModel order) {
    final isConsumable = order.isConsumable;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isConsumable ? const Color(0x2238BDF8) : const Color(0x2214B8A6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        order.typeLabel,
        style: TextStyle(
          color: isConsumable
              ? const Color(0xFF38BDF8)
              : const Color(0xFF14B8A6),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(OrderModel order) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _statusColor(order.status).withOpacity(0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _statusText(order),
        style: TextStyle(
          color: _statusColor(order.status),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildDeliveredAction({
    required BuildContext context,
    required OrderModel order,
  }) {
    final isDelivered = order.status.toLowerCase() == 'delivered';
    if (isDelivered) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          await _markDelivered(order);

          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order marked as delivered')),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        child: const Text('Mark as Delivered'),
      ),
    );
  }

  Widget _buildCompactCard({
    required BuildContext context,
    required OrderModel order,
  }) {
    final isDelivered = order.status.toLowerCase() == 'delivered';
    final actionArea = _buildDeliveredAction(context: context, order: order);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  order.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _buildTypeBadge(order),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Qty: ${order.quantity.isEmpty ? "-" : order.quantity}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildStatusBadge(order),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Ordered: ${_formatShortDate(order.orderedAt.toDate())}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (!isDelivered) ...[
            const SizedBox(height: 12),
            actionArea,
          ],
        ],
      ),
    );
  }

  Widget _buildDetailedCard({
    required BuildContext context,
    required OrderModel order,
  }) {
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(width: 10),
              _buildTypeBadge(order),
            ],
          ),
          const SizedBox(height: 8),
          if (order.isChemical && order.cas.trim().isNotEmpty) ...[
            Text(
              'CAS: ${order.cas}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (order.packSize.trim().isNotEmpty) ...[
            Text(
              'Pack Size: ${order.packSize}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (order.brand.trim().isNotEmpty) ...[
            Text(
              'Brand: ${order.brand}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (order.vendor.trim().isNotEmpty) ...[
            Text(
              'Vendor: ${order.vendor}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
          ],
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
            _formatOrderedNote(order),
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12.5,
            ),
          ),
          if (isDelivered) ...[
            const SizedBox(height: 6),
            Text(
              _formatDeliveredNote(order),
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 8),
          _buildStatusBadge(order),
          if (!isDelivered) ...[
            const SizedBox(height: 12),
            _buildDeliveredAction(context: context, order: order),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders', style: TextStyle(color: Colors.white)),
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

          final orders = _sortOrders(snapshot.data!);

          if (orders.isEmpty) {
            return const Center(
              child: Text(
                'No orders yet.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          return Column(
            children: [
              _buildControlsCard(orders.length),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];

                    if (_viewMode == OrdersViewMode.compact) {
                      return _buildCompactCard(
                        context: context,
                        order: order,
                      );
                    }

                    return _buildDetailedCard(
                      context: context,
                      order: order,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
