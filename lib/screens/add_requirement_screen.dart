import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/requirement_service.dart';
import '../models/requirement_model.dart';

class AddRequirementScreen extends StatefulWidget {
  const AddRequirementScreen({super.key});

  @override
  State<AddRequirementScreen> createState() => _AddRequirementScreenState();
}

class _AddRequirementScreenState extends State<AddRequirementScreen> {
  final _formKey = GlobalKey<FormState>();

final TextEditingController casController = TextEditingController();
final TextEditingController brandController = TextEditingController();
final TextEditingController quantityController = TextEditingController();  
final TextEditingController casNoController = TextEditingController();
  final TextEditingController chemicalNameController = TextEditingController();
  final TextEditingController catalogNoController = TextEditingController();
  final TextEditingController estimatePriceController = TextEditingController();

  String? selectedBrand;
  String? selectedVendor;
  String? selectedPackSize;
  String? selectedQuantity;
  String? selectedType;

Future<void> submitRequirement() async {
  final service = RequirementService();

  final req = RequirementModel(
  id: '',
  chemicalName: chemicalNameController.text.trim(),
  cas: casController.text.trim(),
  brand: brandController.text.trim(),
  quantity: quantityController.text.trim(),
  status: 'pending',
  userName: 'Sandip',
  createdAt: Timestamp.now(),
  approvedBy: '',
  approvedAt: null,
);

  await service.addRequirement(req);

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Requirement submitted')),
  );

  Navigator.pop(context);
}

  final List<String> brands = [
    'Merck',
    'Sigma-Aldrich',
    'TCI',
    'Spectrochem',
    'SRL',
    'Loba',
    'Enter yourself',
  ];

  final List<String> vendors = [
    'Known Vendor 1',
    'Known Vendor 2',
    'Known Vendor 3',
    'Unknown',
  ];

  final List<String> packSizes = [
    '100 mg',
    '250 mg',
    '500 mg',
    '1 g',
    '5 g',
    '25 g',
    '100 g',
    '250 g',
    '500 g',
    '1 L',
    '2.5 L',
    '5 L',
  ];

  final List<String> quantities = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '10',
  ];

  final List<String> chemicalTypes = [
    'Chemical',
    'Solvent',
    'Catalyst',
    'Reagent',
    'Consumable',
    'Glass Apparatus',
    'Gas',
    'Other',
  ];

  double get totalPrice {
    final estimate = double.tryParse(estimatePriceController.text.trim()) ?? 0;
    final qty = int.tryParse(selectedQuantity ?? '0') ?? 0;
    return estimate * qty;
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

  Widget buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: const Color(0xFF1E293B),
      style: const TextStyle(color: Colors.white),
      decoration: inputDecoration(label),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          onChanged(value);
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Required';
        }
        return null;
      },
    );
  }

  

  @override
  void dispose() {
    casNoController.dispose();
    chemicalNameController.dispose();
    catalogNoController.dispose();
    estimatePriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = totalPrice;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Requirement',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: casNoController,
                style: const TextStyle(color: Colors.white),
                decoration: inputDecoration('CAS No'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter CAS No or NA';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: chemicalNameController,
                style: const TextStyle(color: Colors.white),
                decoration: inputDecoration('Chemical Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter chemical name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: catalogNoController,
                style: const TextStyle(color: Colors.white),
                decoration: inputDecoration('Catalog No'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter catalog number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              buildDropdown(
                label: 'Brand',
                value: selectedBrand,
                items: brands,
                onChanged: (value) => selectedBrand = value,
              ),
              const SizedBox(height: 14),
              buildDropdown(
                label: 'Vendor Name',
                value: selectedVendor,
                items: vendors,
                onChanged: (value) => selectedVendor = value,
              ),
              const SizedBox(height: 14),
              buildDropdown(
                label: 'Pack Size',
                value: selectedPackSize,
                items: packSizes,
                onChanged: (value) => selectedPackSize = value,
              ),
              const SizedBox(height: 14),
              buildDropdown(
                label: 'Quantity',
                value: selectedQuantity,
                items: quantities,
                onChanged: (value) => selectedQuantity = value,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: estimatePriceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: inputDecoration('Estimate Price'),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter estimate price';
                  }
                  if (double.tryParse(value.trim()) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              buildDropdown(
                label: 'Type of Chemical',
                value: selectedType,
                items: chemicalTypes,
                onChanged: (value) => selectedType = value,
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
                      'Calculated Summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Total Price: ₹${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF14B8A6),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Approval and fund allocation will be handled later by PI.',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: submitRequirement,
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF14B8A6),
      padding: const EdgeInsets.symmetric(vertical: 16),
    ),
    child: const Text(
      'Submit Requirement',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
)
            ],
          ),
        ),
      ),
    );
  }
}