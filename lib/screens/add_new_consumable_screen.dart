import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';

class AddNewConsumableScreen extends StatefulWidget {
  final OrderModel order;

  const AddNewConsumableScreen({
    super.key,
    required this.order,
  });

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
    modeOfPurchaseController = TextEditingController(text: order.modeOfPurchase);
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

  Future<void> submitConsumableEntry() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSaving = true;
    });

    try {
      final order = widget.order;

      await FirebaseFirestore.instance.collection('consumables_inventory').add({
        'mainType': 'consumable',
        'orderId': order.id,
        'requirementId': order.requirementId,
        'consumableType': consumableTypeController.text.trim(),
        'quantity': quantityController.text.trim(),
        'brand': brandController.text.trim(),
        'vendor': vendorController.text.trim(),
        'modeOfPurchase': modeOfPurchaseController.text.trim(),
        'orderedBy': orderedByController.text.trim(),
        'receivedBy': order.receivedBy,
        'deliveredAt': order.deliveredAt ?? Timestamp.now(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await orderService.markInventoryAdded(docId: order.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Consumable added to inventory'),
        ),
      );

      Navigator.pop(context);
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
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.4,
                  ),
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
