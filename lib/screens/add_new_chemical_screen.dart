import 'package:flutter/material.dart';
import '../models/chemical_model.dart';
import '../models/order_model.dart';
import '../services/inventory_service.dart';
import '../services/order_service.dart';
import '../services/pubchem_service.dart';

class AddNewChemicalScreen extends StatefulWidget {
  final OrderModel? order;

  const AddNewChemicalScreen({
    super.key,
    this.order,
  });

  @override
  State<AddNewChemicalScreen> createState() => _AddNewChemicalScreenState();
}

class _AddNewChemicalScreenState extends State<AddNewChemicalScreen> {
  final _formKey = GlobalKey<FormState>();
  final InventoryService inventoryService = InventoryService();
  final OrderService orderService = OrderService();
  final PubChemService pubChemService = PubChemService();

  late final TextEditingController chemicalNameController;
  late final TextEditingController casController;
  late final TextEditingController brandController;
  late final TextEditingController quantityController;
  late final TextEditingController formulaController;
  late final TextEditingController locationController;
  late final TextEditingController functionalGroupController;
  late final TextEditingController textureController;
  late final TextEditingController molWtController;
  late final TextEditingController catNumberController;
  late final TextEditingController arrivalDateController;
  late final TextEditingController orderedByController;
  late final TextEditingController labelController;
  late final TextEditingController sheetTabController;

  String? selectedEntryType;
  bool isLoadingMetadata = true;

  final List<String> sheetTabs = [
    'C0 - Cn',
    'Nat Pdt',
    'Salts',
    'Acids',
    'Bases',
    'Catalysts',
    'Others',
  ];

  @override
  void initState() {
    super.initState();

    final order = widget.order;
    final deliveredDate = order?.deliveredAt?.toDate();

    chemicalNameController =
        TextEditingController(text: order?.chemicalName ?? '');
    casController = TextEditingController(text: order?.cas ?? '');
    brandController = TextEditingController(text: order?.brand ?? '');
    quantityController = TextEditingController(text: order?.quantity ?? '');
    formulaController = TextEditingController();
    locationController = TextEditingController();
    functionalGroupController = TextEditingController();
    textureController = TextEditingController();
    molWtController = TextEditingController();
    catNumberController = TextEditingController();
    arrivalDateController = TextEditingController(
      text: deliveredDate == null
          ? ''
          : '${deliveredDate.day.toString().padLeft(2, '0')}/${deliveredDate.month.toString().padLeft(2, '0')}/${deliveredDate.year}',
    );
    orderedByController = TextEditingController(text: order?.orderedBy ?? '');
    labelController = TextEditingController();
    sheetTabController = TextEditingController(text: 'C0 - Cn');

    _prefillFromCas();
  }

  Future<void> _prefillFromCas() async {
    setState(() {
      isLoadingMetadata = true;
    });

    try {
      final cas = casController.text.trim();

      // 1. Fetch PubChem details first
      final pubchem = await pubChemService.fetchByCas(cas);
      if (pubchem != null) {
        formulaController.text = pubchem.molecularFormula;
        molWtController.text = pubchem.molecularWeight;
      }

      // 2. Detect whether CAS already exists in inventory
      final existing = await inventoryService.findExistingByCas(cas);

      if (existing != null) {
        selectedEntryType = 'Existing Chemical';
        labelController.text = existing.label;
        locationController.text = existing.location;
        sheetTabController.text = existing.sheetTab;
        if (functionalGroupController.text.trim().isEmpty) {
          functionalGroupController.text = existing.functionalGroups;
        }
        if (textureController.text.trim().isEmpty) {
          textureController.text = existing.texture;
        }
        if (catNumberController.text.trim().isEmpty) {
          catNumberController.text = existing.catNumber;
        }
      } else {
        selectedEntryType = 'New Chemical';

        final formula = formulaController.text.trim();
        if (formula.isNotEmpty) {
          final nextLabel =
              await inventoryService.generateNextLabelFromFormula(formula);
          labelController.text = nextLabel;
        } else {
          labelController.text = 'Could not auto-generate';
        }
      }
    } catch (_) {
      if (selectedEntryType == null) {
        selectedEntryType = 'New Chemical';
      }
      if (labelController.text.trim().isEmpty) {
        labelController.text = 'Could not auto-generate';
      }
    }

    if (!mounted) return;
    setState(() {
      isLoadingMetadata = false;
    });
  }

  @override
  void dispose() {
    chemicalNameController.dispose();
    casController.dispose();
    brandController.dispose();
    quantityController.dispose();
    formulaController.dispose();
    locationController.dispose();
    functionalGroupController.dispose();
    textureController.dispose();
    molWtController.dispose();
    catNumberController.dispose();
    arrivalDateController.dispose();
    orderedByController.dispose();
    labelController.dispose();
    sheetTabController.dispose();
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

  Future<void> submitChemicalEntry() async {
    if (!_formKey.currentState!.validate()) return;

    final chemical = ChemicalModel(
      id: '',
      label: labelController.text.trim(),
      chemicalName: chemicalNameController.text.trim(),
      cas: casController.text.trim(),
      formula: formulaController.text.trim(),
      molWt: molWtController.text.trim(),
      availability: 'Available',
      texture: textureController.text.trim(),
      location: locationController.text.trim(),
      quantity: quantityController.text.trim(),
      brand: brandController.text.trim(),
      catNumber: catNumberController.text.trim(),
      arrivalDate: arrivalDateController.text.trim(),
      orderedBy: orderedByController.text.trim(),
      functionalGroups: functionalGroupController.text.trim(),
      sheetTab: sheetTabController.text.trim(),
    );

    await inventoryService.addChemical(chemical);

    if (widget.order != null) {
      await orderService.markInventoryAdded(docId: widget.order!.id);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chemical added to inventory'),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isExisting = selectedEntryType == 'Existing Chemical';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add New Chemical',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: isLoadingMetadata
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (widget.order != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Prefilled from delivered order. CAS was checked against inventory and formula / molecular weight were fetched from PubChem.',
                          style: TextStyle(
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
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
                      controller: casController,
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('CAS No'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: formulaController,
                      readOnly: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Molecular Formula'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: molWtController,
                      readOnly: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Molecular Weight'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: brandController,
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Brand'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: quantityController,
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Quantity'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: labelController,
                      readOnly: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Generated Label'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: locationController,
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Location'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter storage location';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: functionalGroupController,
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Functional Group'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: textureController,
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Texture / Physical State'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: catNumberController,
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Catalog Number'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: arrivalDateController,
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Arrival Date'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: orderedByController,
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Ordered By'),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: sheetTabs.contains(sheetTabController.text)
                          ? sheetTabController.text
                          : null,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Sheet Tab'),
                      items: sheetTabs
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
                      onChanged: isExisting
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                sheetTabController.text = value;
                              });
                            },
                      validator: (value) {
                        final v = value ?? sheetTabController.text;
                        if (v.trim().isEmpty) {
                          return 'Select sheet tab';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        isExisting
                            ? 'CAS already exists in inventory. Entry type is Existing Chemical, label is reused, and location is autofilled from the previous record.'
                            : 'CAS is new to inventory. Entry type is New Chemical and label was generated from the carbon count in the molecular formula.',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: submitChemicalEntry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14B8A6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
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