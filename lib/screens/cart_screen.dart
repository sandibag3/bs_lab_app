import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/order_model.dart';
import '../models/requirement_model.dart';
import '../services/activity_service.dart';
import '../services/order_service.dart';
import '../services/requirement_service.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final requirementService = RequirementService();
    final orderService = OrderService();
    final appState = AppState.instance;
    final bool isPiAdmin = appState.isPiAdmin;
    final String currentUserName = appState.authenticatedUserName;

    Color statusColor(String status) {
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

    String statusText(RequirementModel req) {
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

    Future<void> updateStatus({
      required RequirementModel req,
      required String status,
    }) async {
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

    Future<void> placeOrder(RequirementModel req) async {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<List<RequirementModel>>(
        stream: requirementService.getRequirements(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snapshot.data!;

          if (list.isEmpty) {
            return const Center(
              child: Text(
                'No requirements yet',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final req = list[index];
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
                    Text(
                      _requirementDisplayName(req),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Type: ${_typeLabel(req)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (!isConsumable && req.cas.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'CAS: ${req.cas}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                    if (req.packSize.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Pack Size: ${req.packSize}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                    if (req.brand.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Brand: ${req.brand}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                    if (req.vendor.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Vendor: ${req.vendor}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                    const SizedBox(height: 4),
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
                    Text(
                      statusText(req),
                      style: TextStyle(
                        color: statusColor(req.status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                                await updateStatus(
                                  req: req,
                                  status: 'approved',
                                );

                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Requirement approved'),
                                  ),
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
                                await updateStatus(
                                  req: req,
                                  status: 'rejected',
                                );

                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Requirement rejected'),
                                  ),
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
                            await placeOrder(req);

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
            },
          );
        },
      ),
    );
  }
}
