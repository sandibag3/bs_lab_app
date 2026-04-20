import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../app_state.dart';
import '../services/requirement_service.dart';
import '../models/requirement_model.dart';

class AddRequirementScreen extends StatefulWidget {
  const AddRequirementScreen({super.key});

  @override
  State<AddRequirementScreen> createState() => _AddRequirementScreenState();
}

class _AddRequirementScreenState extends State<AddRequirementScreen> {
  final _formKey = GlobalKey<FormState>();

  // Common controllers
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController estimatedCostController = TextEditingController();

  // Chemical controllers
  final TextEditingController chemicalNameController = TextEditingController();
  final TextEditingController casController = TextEditingController();
  final TextEditingController catalogNoController = TextEditingController();

  // Custom manual entry controllers
  final TextEditingController customBrandController = TextEditingController();
  final TextEditingController customVendorController = TextEditingController();

  // Dropdown values
  String selectedMainType = 'chemical';
  String? selectedBrand;
  String? selectedVendor;
  String? selectedChemicalType;
  String? selectedConsumableType;
  String? selectedModeOfPurchase;
  String? selectedQuantity;
  String? selectedPackSize;

  bool isFetchingChemicalName = false;

  final List<String> brands = [
    'Merck',
    'Sigma',
    'TCI',
    'Spectrochem',
    'Hyma (Avra)',
    'BLD Pharm',
    'ChemScene',
    'SRL',
    'Others',
  ];

  final List<String> vendors = [
    'Merck',
    'Sigma',
    'Globe Scientific',
    'APJ Scientific',
    'Chemical House',
    'BLD Pharm',
    'Others',
  ];

  final List<String> quantities = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '10',
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

  final List<String> chemicalTypes = [
    'Common Reagent',
    'Catalyst',
    'Ligand',
    'Gas',
    'D-Solvent',
    'Dry Solvent',
    'Solvent',
    'Bulk Solvent',
  ];

  final List<String> consumableTypes = [
    'Gloves - Large',
    'Gloves - Medium',
    'Gloves - Small',
    'Syringe - 1 mL',
    'Syringe - 2 mL',
    'Syringe - 5 mL',
    'Syringe - 10 mL',
    'Syringe - 20 mL',
    'Syringe - 50 mL',
    'Balloon',
    'Needle',
    'Filter Paper',
    'Silica - 230-400 mesh',
    'Silica - 100-200 mesh',
    'TLC Plate',
    'Glass Apparatus',
    'Cotton',
    'Rubber Band',
    'Clips - 14',
    'Clips - 19',
    'Clips - 24',
    'Tubes',
    'Misc',
  ];

  final List<String> purchaseModes = [
    'indent',
    'direct',
  ];

  double get totalPrice {
    final estimate = double.tryParse(estimatedCostController.text.trim()) ?? 0;
    final qty = int.tryParse(selectedQuantity ?? '0') ?? 0;
    return estimate * qty;
  }

  InputDecoration inputDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      suffixIcon: suffixIcon,
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
    String? Function(String?)? validator,
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
      validator: validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return 'Required';
            }
            return null;
          },
    );
  }

  Future<bool> fetchFromInventoryByCas() async {
  final cas = casController.text.trim();

  if (cas.isEmpty || cas.toUpperCase() == 'NA') {
    return false;
  }

  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('inventory')
        .where('cas', isEqualTo: cas)
        .get();

    if (snapshot.docs.isEmpty) {
      return false;
    }

    final docs = snapshot.docs;

    docs.sort((a, b) {
      final aTime = a.data()['createdAt'];
      final bTime = b.data()['createdAt'];

      if (aTime is Timestamp && bTime is Timestamp) {
        return bTime.compareTo(aTime);
      }
      return 0;
    });

    final data = docs.first.data();

    final fetchedChemicalName =
        (data['chemicalName'] ?? '').toString().trim();
    final fetchedCatNumber = (data['catNumber'] ?? '').toString().trim();
    final fetchedPackSize = (data['packSize'] ?? '').toString().trim();
    final fetchedBrand = (data['brand'] ?? '').toString().trim();

    setState(() {
      if (fetchedChemicalName.isNotEmpty) {
        chemicalNameController.text = fetchedChemicalName;
      }

      if (fetchedCatNumber.isNotEmpty) {
        catalogNoController.text = fetchedCatNumber;
      }

      if (fetchedPackSize.isNotEmpty && packSizes.contains(fetchedPackSize)) {
        selectedPackSize = fetchedPackSize;
      }

      if (fetchedBrand.isNotEmpty) {
        if (brands.contains(fetchedBrand)) {
          selectedBrand = fetchedBrand;
          customBrandController.clear();
        } else {
          selectedBrand = 'Others';
          customBrandController.text = fetchedBrand;
        }
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chemical details loaded from inventory'),
        ),
      );
    }

    return true;
  } catch (e) {
    debugPrint('Inventory lookup error: $e');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inventory lookup failed'),
        ),
      );
    }

    return false;
  }
}
  Future<void> fetchFromPubChemByCas() async {
    final cas = casController.text.trim();

    if (cas.isEmpty || cas.toUpperCase() == 'NA') return;

    try {
      final url = Uri.parse(
        'https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/$cas/property/Title/JSON',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final properties = data['PropertyTable']?['Properties'];
        if (properties != null &&
            properties is List &&
            properties.isNotEmpty &&
            properties[0]['Title'] != null) {
          final fetchedName = properties[0]['Title'].toString().trim();

          if (fetchedName.isNotEmpty &&
              chemicalNameController.text.trim().isEmpty) {
            setState(() {
              chemicalNameController.text = fetchedName;
            });
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chemical name fetched from PubChem'),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chemical not found in PubChem. Enter manually.'),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chemical not found in PubChem. Enter manually.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('PubChem fetch error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PubChem fetch failed. Enter manually.'),
          ),
        );
      }
    }
  }

  Future<void> fetchChemicalDetailsSmart() async {
    final cas = casController.text.trim();

    if (cas.isEmpty || cas.toUpperCase() == 'NA') return;

    setState(() {
      isFetchingChemicalName = true;
    });

    try {
      final foundInInventory = await fetchFromInventoryByCas();

      if (!foundInInventory) {
        await fetchFromPubChemByCas();
      }
    } finally {
      if (mounted) {
        setState(() {
          isFetchingChemicalName = false;
        });
      }
    }
  }

  Future<void> submitRequirement() async {
    if (!_formKey.currentState!.validate()) return;

    final service = RequirementService();

    final req = RequirementModel(
      id: '',
      mainType: selectedMainType,
      brand: selectedBrand == 'Others'
          ? customBrandController.text.trim()
          : (selectedBrand ?? ''),
      vendor: selectedVendor == 'Others'
          ? customVendorController.text.trim()
          : (selectedVendor ?? ''),
      quantity: selectedQuantity ?? quantityController.text.trim(),
      estimatedCost: estimatedCostController.text.trim(),
      estimatedTotal: totalPrice.toStringAsFixed(2),
      modeOfPurchase: selectedModeOfPurchase ?? '',
      packSize: selectedMainType == 'chemical' ? (selectedPackSize ?? '') : '',
      chemicalName:
          selectedMainType == 'chemical' ? chemicalNameController.text.trim() : '',
      cas: selectedMainType == 'chemical' ? casController.text.trim() : '',
      catalogNo:
          selectedMainType == 'chemical' ? catalogNoController.text.trim() : '',
      chemicalType:
          selectedMainType == 'chemical' ? (selectedChemicalType ?? '') : '',
      consumableType:
          selectedMainType == 'consumable' ? (selectedConsumableType ?? '') : '',
      status: 'pending',
      userName: AppState.instance.authenticatedUserName,
      createdAt: Timestamp.now(),
      approvedBy: '',
      approvedAt: null,
    );

    await service.addRequirement(req);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Requirement submitted')),
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    quantityController.dispose();
    estimatedCostController.dispose();
    chemicalNameController.dispose();
    casController.dispose();
    catalogNoController.dispose();
    customBrandController.dispose();
    customVendorController.dispose();
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
              buildDropdown(
                label: 'Requirement Type',
                value: selectedMainType,
                items: const ['chemical', 'consumable'],
                onChanged: (value) {
                  selectedMainType = value ?? 'chemical';
                },
              ),
              const SizedBox(height: 14),

              if (selectedMainType == 'chemical') ...[
                TextFormField(
                  controller: casController,
                  style: const TextStyle(color: Colors.white),
                  decoration: inputDecoration(
                    'CAS No',
                    suffixIcon: IconButton(
                      onPressed:
                          isFetchingChemicalName ? null : fetchChemicalDetailsSmart,
                      icon: isFetchingChemicalName
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search, color: Colors.white70),
                    ),
                  ),
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
                  decoration: inputDecoration(
                    'Chemical Name (auto from inventory/PubChem or enter manually)',
                  ),
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
                  label: 'Pack Size',
                  value: selectedPackSize,
                  items: packSizes,
                  onChanged: (value) => selectedPackSize = value,
                  validator: (value) {
                    if (selectedMainType == 'chemical' &&
                        (value == null || value.isEmpty)) {
                      return 'Select pack size';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                buildDropdown(
                  label: 'Type of Chemical',
                  value: selectedChemicalType,
                  items: chemicalTypes,
                  onChanged: (value) => selectedChemicalType = value,
                ),
                const SizedBox(height: 14),
              ],

              if (selectedMainType == 'consumable') ...[
                buildDropdown(
                  label: 'Consumable Type',
                  value: selectedConsumableType,
                  items: consumableTypes,
                  onChanged: (value) => selectedConsumableType = value,
                ),
                const SizedBox(height: 14),
              ],

              buildDropdown(
                label: 'Brand',
                value: selectedBrand,
                items: brands,
                onChanged: (value) => selectedBrand = value,
              ),
              if (selectedBrand == 'Others') ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: customBrandController,
                  style: const TextStyle(color: Colors.white),
                  decoration: inputDecoration('Enter Brand'),
                  validator: (value) {
                    if (selectedBrand == 'Others' &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Enter brand name';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 14),
              buildDropdown(
                label: 'Vendor Name',
                value: selectedVendor,
                items: vendors,
                onChanged: (value) => selectedVendor = value,
              ),
              if (selectedVendor == 'Others') ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: customVendorController,
                  style: const TextStyle(color: Colors.white),
                  decoration: inputDecoration('Enter Vendor'),
                  validator: (value) {
                    if (selectedVendor == 'Others' &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Enter vendor name';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 14),
              buildDropdown(
                label: 'Quantity',
                value: selectedQuantity,
                items: quantities,
                onChanged: (value) => selectedQuantity = value,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: estimatedCostController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: inputDecoration('Estimated Cost'),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter estimated cost';
                  }
                  if (double.tryParse(value.trim()) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              buildDropdown(
                label: 'Mode of Purchase',
                value: selectedModeOfPurchase,
                items: purchaseModes,
                onChanged: (value) => selectedModeOfPurchase = value,
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
                      'Estimated Total: ₹${total.toStringAsFixed(2)}',
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
