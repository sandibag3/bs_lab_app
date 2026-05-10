import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/order_model.dart';
import '../models/requirement_model.dart';
import '../services/activity_service.dart';
import '../services/firestore_access_guard.dart';
import '../services/order_service.dart';
import '../services/requirement_service.dart';

enum CartViewMode { compact, detailed }

enum CartSortOption { newestFirst, oldestFirst, status, type }

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final RequirementService requirementService = RequirementService();
  final OrderService orderService = OrderService();

  CartViewMode _viewMode = CartViewMode.compact;
  CartSortOption _sortOption = CartSortOption.newestFirst;

  String _requirementDisplayName(RequirementModel req) {
    final mainType = req.mainType.trim().toLowerCase();
    final chemical = req.chemicalName.trim();
    final consumable = req.consumableType.trim();

    if (mainType == 'consumable') {
      if (consumable.isNotEmpty) return consumable;
      if (chemical.isNotEmpty) return chemical;
      return 'Consumable';
    }

    if (chemical.isNotEmpty) return chemical;
    if (consumable.isNotEmpty) return consumable;
    return 'Chemical';
  }

  bool _isConsumableRequirement(RequirementModel req) {
    return req.mainType.trim().toLowerCase() == 'consumable';
  }

  String _typeLabel(RequirementModel req) {
    return _isConsumableRequirement(req) ? 'Consumable' : 'Chemical';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.greenAccent;
      case 'rejected':
        return Colors.redAccent;
      case 'ordered':
        return const Color(0xFF14B8A6);
      default:
        return Colors.orangeAccent;
    }
  }

  String _statusText(RequirementModel req) {
    switch (req.status.toLowerCase()) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'ordered':
        return 'Order placed';
      default:
        return 'Waiting for approval';
    }
  }

  int _statusSortWeight(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 0;
      case 'approved':
        return 1;
      case 'ordered':
        return 2;
      case 'rejected':
        return 3;
      default:
        return 4;
    }
  }

  String _sortLabel(CartSortOption option) {
    switch (option) {
      case CartSortOption.newestFirst:
        return 'Newest first';
      case CartSortOption.oldestFirst:
        return 'Oldest first';
      case CartSortOption.status:
        return 'Status';
      case CartSortOption.type:
        return 'Type';
    }
  }

  List<RequirementModel> _sortRequirements(List<RequirementModel> input) {
    final list = [...input];

    list.sort((a, b) {
      switch (_sortOption) {
        case CartSortOption.newestFirst:
          return b.createdAt.compareTo(a.createdAt);

        case CartSortOption.oldestFirst:
          return a.createdAt.compareTo(b.createdAt);

        case CartSortOption.status:
          final statusComparison = _statusSortWeight(
            a.status,
          ).compareTo(_statusSortWeight(b.status));
          if (statusComparison != 0) {
            return statusComparison;
          }
          return b.createdAt.compareTo(a.createdAt);

        case CartSortOption.type:
          final typeComparison = _typeLabel(
            a,
          ).toLowerCase().compareTo(_typeLabel(b).toLowerCase());
          if (typeComparison != 0) {
            return typeComparison;
          }
          return b.createdAt.compareTo(a.createdAt);
      }
    });

    return list;
  }

  Future<void> _updateStatus({
    required RequirementModel req,
    required String status,
  }) async {
    final appState = AppState.instance;
    final currentUserName = appState.authenticatedUserName;

    await requirementService.updateRequirementStatus(
      docId: req.id,
      status: status,
      approvedBy: currentUserName,
    );
    await ActivityService().addActivity(
      labId: appState.resolveWriteLabId(req.labId),
      type: status == 'approved'
          ? 'requirement_approved'
          : 'requirement_rejected',
      message:
          'Requirement ${status == 'approved' ? 'approved' : 'rejected'} for ${_requirementDisplayName(req)}',
      actorName: currentUserName,
      createdBy: appState.authenticatedUserId,
      relatedId: req.id,
    );
  }

  Future<void> _placeOrder(RequirementModel req) async {
    final appState = AppState.instance;
    final currentUserName = appState.authenticatedUserName;

    final order = OrderModel(
      id: '',
      requirementId: req.id,
      labId: appState.resolveWriteLabId(req.labId),
      mainType: req.mainType,
      chemicalName: req.chemicalName,
      consumableType: req.consumableType,
      cas: req.cas,
      brand: req.brand,
      vendor: req.vendor,
      quantity: req.quantity,
      packSize: req.packSize,
      modeOfPurchase: req.modeOfPurchase,
      orderedBy: currentUserName,
      orderedAt: Timestamp.now(),
      status: 'ordered',
      receivedBy: '',
      deliveredAt: null,
      inventoryAdded: false,
    );

    final orderId = await orderService.addOrder(order);

    await requirementService.markRequirementOrdered(
      docId: req.id,
      updatedBy: currentUserName,
    );
    await ActivityService().addActivity(
      labId: order.labId,
      type: 'order_placed',
      message: 'Order placed for ${order.displayName}',
      actorName: currentUserName,
      createdBy: appState.authenticatedUserId,
      relatedId: orderId,
    );
  }

  Widget _buildViewToggle() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Compact'),
          selected: _viewMode == CartViewMode.compact,
          selectedColor: const Color(0xFF14B8A6),
          backgroundColor: const Color(0xFF1E293B),
          labelStyle: TextStyle(
            color: _viewMode == CartViewMode.compact
                ? Colors.white
                : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) {
            setState(() {
              _viewMode = CartViewMode.compact;
            });
          },
        ),
        ChoiceChip(
          label: const Text('Detailed'),
          selected: _viewMode == CartViewMode.detailed,
          selectedColor: const Color(0xFF14B8A6),
          backgroundColor: const Color(0xFF1E293B),
          labelStyle: TextStyle(
            color: _viewMode == CartViewMode.detailed
                ? Colors.white
                : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) {
            setState(() {
              _viewMode = CartViewMode.detailed;
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
        child: DropdownButton<CartSortOption>(
          value: _sortOption,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white),
          isExpanded: true,
          items: CartSortOption.values.map((option) {
            return DropdownMenuItem<CartSortOption>(
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
            '$itemCount ${itemCount == 1 ? 'item' : 'items'} in cart',
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

  Widget _buildTypeBadge(RequirementModel req) {
    final isConsumable = _isConsumableRequirement(req);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isConsumable ? const Color(0x2238BDF8) : const Color(0x2214B8A6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _typeLabel(req),
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

  Widget _buildStatusBadge(RequirementModel req) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _statusColor(req.status).withOpacity(0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _statusText(req),
        style: TextStyle(
          color: _statusColor(req.status),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildCompactActionArea({
    required BuildContext context,
    required RequirementModel req,
    required bool isPiAdmin,
  }) {
    final status = req.status.toLowerCase();

    if (isPiAdmin && status == 'pending') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                await _updateStatus(req: req, status: 'approved');

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Requirement approved')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Approve'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                await _updateStatus(req: req, status: 'rejected');

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Requirement rejected')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Reject'),
            ),
          ),
        ],
      );
    }

    if (status == 'approved') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            await _placeOrder(req);

            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Order placed successfully')),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF14B8A6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          child: const Text('Place Order'),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDetailedCard({
    required BuildContext context,
    required RequirementModel req,
    required bool isPiAdmin,
  }) {
    final isConsumable = _isConsumableRequirement(req);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                  _requirementDisplayName(req),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _buildTypeBadge(req),
            ],
          ),
          const SizedBox(height: 10),
          if (!isConsumable && req.cas.trim().isNotEmpty) ...[
            Text(
              'CAS: ${req.cas}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 4),
          ],
          if (req.packSize.trim().isNotEmpty) ...[
            Text(
              'Pack Size: ${req.packSize}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 4),
          ],
          if (req.brand.trim().isNotEmpty) ...[
            Text(
              'Brand: ${req.brand}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 4),
          ],
          if (req.vendor.trim().isNotEmpty) ...[
            Text(
              'Vendor: ${req.vendor}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            'Qty: ${req.quantity.isEmpty ? "-" : req.quantity}',
            style: const TextStyle(color: Colors.white70),
          ),
          if (req.modeOfPurchase.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Mode: ${req.modeOfPurchase}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Requested by: ${req.userName.isEmpty ? "-" : req.userName}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          _buildStatusBadge(req),
          if (req.approvedBy.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Updated by: ${req.approvedBy}',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12.5,
              ),
            ),
          ],
          if (isPiAdmin && req.status.toLowerCase() == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _updateStatus(req: req, status: 'approved');

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Requirement approved')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _updateStatus(req: req, status: 'rejected');

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Requirement rejected')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
          if (req.status.toLowerCase() == 'approved') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await _placeOrder(req);

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Order placed successfully'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Place Order'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactCard({
    required BuildContext context,
    required RequirementModel req,
    required bool isPiAdmin,
  }) {
    final actionArea = _buildCompactActionArea(
      context: context,
      req: req,
      isPiAdmin: isPiAdmin,
    );

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
                  _requirementDisplayName(req),
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
              _buildTypeBadge(req),
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
                  'Qty: ${req.quantity.isEmpty ? "-" : req.quantity}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildStatusBadge(req),
            ],
          ),
          if (actionArea is! SizedBox) ...[
            const SizedBox(height: 12),
            actionArea,
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppState.instance;
    final bool isPiAdmin = appState.isPiAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<List<RequirementModel>>(
        stream: requirementService.getRequirements(),
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

          final sortedList = _sortRequirements(snapshot.data!);

          if (sortedList.isEmpty) {
            return const Center(
              child: Text(
                'No requirements yet',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return Column(
            children: [
              _buildControlsCard(sortedList.length),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: sortedList.length,
                  itemBuilder: (context, index) {
                    final req = sortedList[index];

                    if (_viewMode == CartViewMode.compact) {
                      return _buildCompactCard(
                        context: context,
                        req: req,
                        isPiAdmin: isPiAdmin,
                      );
                    }

                    return _buildDetailedCard(
                      context: context,
                      req: req,
                      isPiAdmin: isPiAdmin,
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
