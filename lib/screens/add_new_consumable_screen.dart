import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/order_model.dart';
import '../services/activity_service.dart';
import '../services/order_service.dart';

class AddNewConsumableScreen extends StatefulWidget {
  final OrderModel order;

  const AddNewConsumableScreen({super.key, required this.order});

  @override
  State<AddNewConsumableScreen> createState() => _AddNewConsumableScreenState();
}

class _AddNewConsumableScreenState extends State<AddNewConsumableScreen> {
  final _formKey = GlobalKey<FormState>();
  final OrderService orderService = OrderService();

  late final TextEditingController consumableTypeController;
  late final TextEditingController quantityController;
  late final TextEditingController brandController;
  late final TextEditingController vendorController;
  late final TextEditingController modeOfPurchaseController;
  late final TextEditingController orderedByController;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    final order = widget.order;

    consumableTypeController = TextEditingController(
      text: order.consumableType.trim().isEmpty
          ? order.displayName
          : order.consumableType,
    );
    quantityController = TextEditingController(text: order.quantity);
    brandController = TextEditingController(text: order.brand);
    vendorController = TextEditingController(text: order.vendor);
    modeOfPurchaseController = TextEditingController(
      text: order.modeOfPurchase,
    );
    orderedByController = TextEditingController(text: order.orderedBy);
  }

  @override
  void dispose() {
    consumableTypeController.dispose();
    quantityController.dispose();
    brandController.dispose();
    vendorController.dispose();
    modeOfPurchaseController.dispose();
    orderedByController.dispose();
    super.dispose();
  }

  InputDecoration inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Not available';

    final date = timestamp.toDate();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _inventoryKey(String consumableType) {
    return consumableType.trim().toLowerCase();
  }

  double? _readQuantityNumber(String quantity) {
    final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(quantity.trim());
    if (match == null) {
      return null;
    }

    return double.tryParse(match.group(0) ?? '');
  }

  String _formatQuantityNumber(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toStringAsFixed(0);
    }

    return quantity.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  Future<void> submitConsumableEntry() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSaving = true;
    });

    try {
      final order = widget.order;
      final labId = AppState.instance.resolveWriteLabId(order.labId);
      final consumableType = consumableTypeController.text.trim();
      final quantityAddedText = quantityController.text.trim();
      final quantityAdded = _readQuantityNumber(quantityAddedText);
      final brand = brandController.text.trim();
      final vendor = vendorController.text.trim();
      final modeOfPurchase = modeOfPurchaseController.text.trim();
      final orderedBy = orderedByController.text.trim();
      final timestamp = Timestamp.now();

      if (quantityAdded == null || quantityAdded <= 0) {
        throw Exception('Quantity must be numeric and greater than 0.');
      }

      final firestore = FirebaseFirestore.instance;
      final inventoryRef = firestore.collection('consumables_inventory');
      final purchaseLogRef = firestore
          .collection('consumable_purchase_logs')
          .doc();

      final existingSnapshot = await inventoryRef.get();
      final targetKey = _inventoryKey(consumableType);
      QueryDocumentSnapshot<Map<String, dynamic>>? existingDoc;

      for (final doc in existingSnapshot.docs) {
        final data = doc.data();
        final docLabId = (data['labId'] ?? '').toString().trim();
        if (docLabId != labId) {
          continue;
        }

        final docKey = _inventoryKey((data['consumableType'] ?? '').toString());
        if (docKey == targetKey) {
          existingDoc = doc;
          break;
        }
      }

      late final String inventoryId;
      late final double previousQuantity;
      late final double newQuantity;

      if (existingDoc == null) {
        final newInventoryRef = inventoryRef.doc();
        inventoryId = newInventoryRef.id;
        previousQuantity = 0;
        newQuantity = quantityAdded;

        await firestore.runTransaction((transaction) async {
          transaction.set(newInventoryRef, {
            'labId': labId,
            'mainType': 'consumable',
            'orderId': order.id,
            'latestOrderId': order.id,
            'requirementId': order.requirementId,
            'consumableType': consumableType,
            'quantity': _formatQuantityNumber(newQuantity),
            'isAggregate': true,
            'brand': brand,
            'latestBrand': brand,
            'vendor': vendor,
            'latestVendor': vendor,
            'modeOfPurchase': modeOfPurchase,
            'orderedBy': orderedBy,
            'receivedBy': order.receivedBy,
            'deliveredAt': order.deliveredAt ?? timestamp,
            'createdAt': timestamp,
            'updatedAt': timestamp,
          });

          transaction.set(purchaseLogRef, {
            'labId': labId,
            'consumableInventoryId': inventoryId,
            'consumableType': consumableType,
            'quantityAdded': quantityAdded,
            'previousQuantity': previousQuantity,
            'newQuantity': newQuantity,
            'brand': brand,
            'vendor': vendor,
            'modeOfPurchase': modeOfPurchase,
            'receivedBy': order.receivedBy,
            'deliveredAt': order.deliveredAt ?? timestamp,
            'sourceOrderId': order.id,
            'createdAt': timestamp,
            'createdBy': AppState.instance.authenticatedUserId,
            'actorName': AppState.instance.authenticatedUserName,
          });
        });
      } else {
        final matchedDoc = existingDoc;
        inventoryId = matchedDoc.id;

        await firestore.runTransaction((transaction) async {
          final freshSnapshot = await transaction.get(matchedDoc.reference);
          final freshData = freshSnapshot.data();
          if (freshData == null) {
            throw Exception('Existing consumable inventory item was removed.');
          }

          final currentQuantity = _readQuantityNumber(
            (freshData['quantity'] ?? '').toString(),
          );
          previousQuantity = currentQuantity ?? 0;
          newQuantity = previousQuantity + quantityAdded;

          transaction.update(matchedDoc.reference, {
            'quantity': _formatQuantityNumber(newQuantity),
            'isAggregate': true,
            'latestOrderId': order.id,
            'requirementId': order.requirementId,
            'latestBrand': brand,
            'latestVendor': vendor,
            'modeOfPurchase': modeOfPurchase,
            'orderedBy': orderedBy,
            'receivedBy': order.receivedBy,
            'deliveredAt': order.deliveredAt ?? timestamp,
            'updatedAt': timestamp,
          });

          transaction.set(purchaseLogRef, {
            'labId': labId,
            'consumableInventoryId': inventoryId,
            'consumableType': consumableType,
            'quantityAdded': quantityAdded,
            'previousQuantity': previousQuantity,
            'newQuantity': newQuantity,
            'brand': brand,
            'vendor': vendor,
            'modeOfPurchase': modeOfPurchase,
            'receivedBy': order.receivedBy,
            'deliveredAt': order.deliveredAt ?? timestamp,
            'sourceOrderId': order.id,
            'createdAt': timestamp,
            'createdBy': AppState.instance.authenticatedUserId,
            'actorName': AppState.instance.authenticatedUserName,
          });
        });
      }

      await orderService.markInventoryAdded(docId: order.id);
      await ActivityService().addActivity(
        labId: labId,
        type: 'consumable_inventory_added',
        message: 'Consumable entry confirmed for $consumableType',
        actorName: AppState.instance.authenticatedUserName,
        createdBy: AppState.instance.authenticatedUserId,
        relatedId: inventoryId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consumable added to inventory')),
      );

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add New Consumable',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Prefilled from the delivered consumable order. Review the basic details, edit if needed, and confirm entry to create the consumables inventory record.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: consumableTypeController,
                style: const TextStyle(color: Colors.white),
                decoration: inputDecoration('Consumable Type'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter consumable type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: quantityController,
                style: const TextStyle(color: Colors.white),
                decoration: inputDecoration('Quantity'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter quantity';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: brandController,
                style: const TextStyle(color: Colors.white),
                decoration: inputDecoration('Brand'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: vendorController,
                style: const TextStyle(color: Colors.white),
                decoration: inputDecoration('Vendor'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: modeOfPurchaseController,
                style: const TextStyle(color: Colors.white),
                decoration: inputDecoration('Mode of Purchase'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: orderedByController,
                style: const TextStyle(color: Colors.white),
                decoration: inputDecoration('Ordered By'),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Received By: ${order.receivedBy.trim().isEmpty ? '-' : order.receivedBy}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Delivered On: ${_formatDate(order.deliveredAt)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving ? null : submitConsumableEntry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Confirm Entry',
                          style: TextStyle(fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
