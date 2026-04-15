import 'package:flutter/material.dart';
import '../models/chemical_model.dart';
import '../models/order_model.dart';
import '../services/inventory_service.dart';
import '../services/order_service.dart';
import '../services/pubchem_service.dart';
import '../services/chemical_label_service.dart';

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
  final ChemicalLabelService chemicalLabelService = ChemicalLabelService();

  late final TextEditingController chemicalNameController;
  late final TextEditingController casController;
  late final TextEditingController brandController;
  late final TextEditingController quantityController;
  late final TextEditingController formulaController;
  late final TextEditingController molWtController;
  late final TextEditingController catNumberController;
  late final TextEditingController arrivalDateController;
  late final TextEditingController orderedByController;
  late final TextEditingController labelController;
  late final TextEditingController sheetTabController;
  late final TextEditingController carbonCountController;
  late final TextEditingController catalystMetalController;

  String? selectedEntryType;
  bool isLoadingMetadata = true;
  bool isGeneratingLabel = false;
  bool isFetchingCas = false;

  String selectedCategory = 'General';
  String? selectedSubcategory;

  String? selectedLocation;
  String? selectedTexture;
  String? selectedFunctionalGroup;

  final List<String> categories = [
    'General',
    'Acid',
    'Base',
    'Salt',
    'Metal',
    'Catalyst',
    'Ligand',
  ];

  final List<String> locationOptions = const [
    'Yellow Cab',
    'Acid Cabinet',
    'Base Cabinet',
    'Solvent Rack',
    'Dry Solvent Rack',
    'Deuterated Solvent Rack',
    'Refrigerator',
    'Freezer 1A',
    'Freezer 1B',
    'Freezer 1C',
    'Freezer 1D',
    'Freezer 1E',
    'Desiccator',
    'Glovebox',
    'Drawer 1',
    'Drawer 2',
    'Drawer 3',
    'Other',
  ];

  final List<String> textureOptions = const [
    'Solid',
    'Liquid',
    'Oil',
    'Powder',
    'Crystals',
    'Solution',
    'Suspension',
    'Gas',
    'Paste',
    'Other',
  ];

  final List<String> functionalGroupOptions = const [
    'Alcohol',
    'Aldehyde',
    'Ketone',
    'Ester',
    'Amide',
    'Amine',
    'Carboxylic Acid',
    'Halide',
    'Nitrile',
    'Nitro',
    'Ether',
    'Thioether',
    'Phosphine',
    'Pyridine',
    'Imine',
    'Alkene',
    'Alkyne',
    'Arene',
    'Heteroarene',
    'Boronic Acid',
    'Sulfonamide',
    'Peroxide',
    'Carbonate',
    'Hydride',
    'Other',
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
    molWtController = TextEditingController();
    catNumberController = TextEditingController();
    arrivalDateController = TextEditingController(
      text: deliveredDate == null
          ? ''
          : '${deliveredDate.day.toString().padLeft(2, '0')}/${deliveredDate.month.toString().padLeft(2, '0')}/${deliveredDate.year}',
    );
    orderedByController = TextEditingController(text: order?.orderedBy ?? '');
    labelController = TextEditingController();
    sheetTabController = TextEditingController();
    carbonCountController = TextEditingController();
    catalystMetalController = TextEditingController();

    _prefillFromCas();
  }

  List<String> getSubcategories(String category) {
    switch (category) {
      case 'Base':
        return ['Organic', 'Inorganic'];
      case 'Ligand':
        return ['N-Donor', 'Phosphine'];
      default:
        return [];
    }
  }

  String _getSheetTabFromSelection() {
    switch (selectedCategory) {
      case 'Acid':
        return 'Acids';
      case 'Base':
        return 'Bases';
      case 'Salt':
        return 'Salts';
      case 'Metal':
        return 'Metals';
      case 'Catalyst':
        return 'Catalysts';
      case 'Ligand':
        return 'Ligands';
      case 'General':
        final carbonCount = int.tryParse(carbonCountController.text.trim());
        if (carbonCount != null && carbonCount > 0) {
          return 'C$carbonCount';
        }
        return '';
      default:
        return '';
    }
  }

  int? _extractCarbonCount(String formula) {
    final regex = RegExp(r'C(\d*)', caseSensitive: false);
    final match = regex.firstMatch(formula);

    if (match == null) return null;

    final digits = match.group(1);
    if (digits == null || digits.isEmpty) return 1;

    return int.tryParse(digits);
  }

  Future<void> _generateLabelForNewChemical() async {
    if (selectedEntryType == 'Existing Chemical') return;

    setState(() {
      isGeneratingLabel = true;
    });

    try {
      final carbonCount = int.tryParse(carbonCountController.text.trim());

      final prefix = chemicalLabelService.getPrefix(
        category: selectedCategory,
        subcategory: selectedSubcategory,
        carbonCount: carbonCount,
        catalystMetal: catalystMetalController.text.trim().isEmpty
            ? null
            : catalystMetalController.text.trim(),
      );

      final labelData = await chemicalLabelService.generateLabel(prefix: prefix);

      if (!mounted) return;

      setState(() {
        labelController.text = labelData['label'];
        sheetTabController.text = _getSheetTabFromSelection();
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        labelController.text = 'Could not auto-generate';
      });
    } finally {
      if (mounted) {
        setState(() {
          isGeneratingLabel = false;
        });
      }
    }
  }

  Future<void> _fetchFromCasAndCheckInventory() async {
    setState(() {
      isFetchingCas = true;
    });

    try {
      final cas = casController.text.trim();

      if (cas.isNotEmpty) {
        final pubchem = await pubChemService.fetchByCas(cas);
        if (pubchem != null) {
          formulaController.text = pubchem.molecularFormula;
          molWtController.text = pubchem.molecularWeight;

          final carbonCount = _extractCarbonCount(pubchem.molecularFormula);
          if (carbonCount != null) {
            carbonCountController.text = carbonCount.toString();
          }
        }
      }

      final existing = cas.isEmpty
          ? null
          : await inventoryService.findExistingByCas(cas);

      if (existing != null) {
        if (!mounted) return;
        setState(() {
          selectedEntryType = 'Existing Chemical';
          labelController.text = existing.label;
          sheetTabController.text = existing.sheetTab;
          selectedLocation = existing.location.isEmpty ? null : existing.location;
          selectedTexture = existing.texture.isEmpty ? null : existing.texture;
          selectedFunctionalGroup = existing.functionalGroups.isEmpty
              ? null
              : existing.functionalGroups;

          if (catNumberController.text.trim().isEmpty) {
            catNumberController.text = existing.catNumber;
          }
        });
      } else {
        if (!mounted) return;
        setState(() {
          selectedEntryType = 'New Chemical';
          sheetTabController.text = _getSheetTabFromSelection();
        });

        await _generateLabelForNewChemical();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (selectedEntryType == null) {
          selectedEntryType = 'New Chemical';
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          isFetchingCas = false;
        });
      }
    }
  }

  Future<void> _prefillFromCas() async {
    setState(() {
      isLoadingMetadata = true;
    });

    try {
      await _fetchFromCasAndCheckInventory();
    } finally {
      if (!mounted) return;
      setState(() {
        isLoadingMetadata = false;
      });
    }
  }

  @override
  void dispose() {
    chemicalNameController.dispose();
    casController.dispose();
    brandController.dispose();
    quantityController.dispose();
    formulaController.dispose();
    molWtController.dispose();
    catNumberController.dispose();
    arrivalDateController.dispose();
    orderedByController.dispose();
    labelController.dispose();
    sheetTabController.dispose();
    carbonCountController.dispose();
    catalystMetalController.dispose();
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
      texture: selectedTexture ?? '',
      location: selectedLocation ?? '',
      quantity: quantityController.text.trim(),
      brand: brandController.text.trim(),
      catNumber: catNumberController.text.trim(),
      arrivalDate: arrivalDateController.text.trim(),
      orderedBy: orderedByController.text.trim(),
      functionalGroups: selectedFunctionalGroup ?? '',
      sheetTab: sheetTabController.text.trim(),
    );

    await inventoryService.addChemical(chemical);

    if (widget.order != null) {
      await orderService.markInventoryAdded(docId: widget.order!.id);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selectedEntryType == 'Existing Chemical'
              ? 'Existing chemical stock updated'
              : 'Chemical added to inventory',
        ),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isExisting = selectedEntryType == 'Existing Chemical';
    final subcategories = getSubcategories(selectedCategory);

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
                          'Prefilled from delivered order. Name, CAS, brand, quantity, ordered by, and arrival date come from the order. Formula and molecular weight can be fetched from CAS.',
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
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: isFetchingCas
                            ? null
                            : _fetchFromCasAndCheckInventory,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF14B8A6)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          isFetchingCas ? 'Fetching...' : 'Fetch from CAS',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Category'),
                      items: categories
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
                          : (value) async {
                              if (value == null) return;

                              setState(() {
                                selectedCategory = value;
                                selectedSubcategory = null;
                                labelController.clear();
                                sheetTabController.text = _getSheetTabFromSelection();
                              });

                              await _generateLabelForNewChemical();
                            },
                    ),
                    const SizedBox(height: 14),
                    if (subcategories.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: selectedSubcategory,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white),
                        decoration: inputDecoration('Subcategory'),
                        items: subcategories
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
                            : (value) async {
                                setState(() {
                                  selectedSubcategory = value;
                                  labelController.clear();
                                });
                                await _generateLabelForNewChemical();
                              },
                        validator: (value) {
                          if ((selectedCategory == 'Base' ||
                                  selectedCategory == 'Ligand') &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Select subcategory';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (selectedCategory == 'General') ...[
                      TextFormField(
                        controller: carbonCountController,
                        readOnly: isExisting,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: inputDecoration('Carbon Count'),
                        onChanged: (_) async {
                          if (!isExisting) {
                            setState(() {
                              sheetTabController.text = _getSheetTabFromSelection();
                            });
                            await _generateLabelForNewChemical();
                          }
                        },
                        validator: (value) {
                          if (!isExisting && selectedCategory == 'General') {
                            final count = int.tryParse(value?.trim() ?? '');
                            if (count == null || count <= 0) {
                              return 'Enter valid carbon count';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (selectedCategory == 'Catalyst') ...[
                      TextFormField(
                        controller: catalystMetalController,
                        readOnly: isExisting,
                        style: const TextStyle(color: Colors.white),
                        decoration: inputDecoration('Catalyst Metal (Pd, Cu, Fe...)'),
                        onChanged: (_) async {
                          if (!isExisting) {
                            await _generateLabelForNewChemical();
                          }
                        },
                        validator: (value) {
                          if (!isExisting && selectedCategory == 'Catalyst') {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter catalyst metal';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: formulaController,
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Molecular Formula'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: molWtController,
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
                    DropdownButtonFormField<String>(
                      value: selectedLocation,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Location'),
                      items: locationOptions
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
                          selectedLocation = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Select storage location';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedFunctionalGroup,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Functional Group'),
                      items: functionalGroupOptions
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
                          selectedFunctionalGroup = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedTexture,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Texture / Physical State'),
                      items: textureOptions
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
                          selectedTexture = value;
                        });
                      },
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
                    TextFormField(
                      controller: sheetTabController,
                      readOnly: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: inputDecoration('Sheet Tab'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Sheet tab could not be determined';
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
                            ? 'CAS already exists in inventory. Existing label is reused, and previous location / texture / functional group are loaded when available.'
                            : 'CAS is new to inventory. Category-based label generation is active. Functional category is prioritized over carbon-count category.',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (!isExisting)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: isGeneratingLabel
                              ? null
                              : _generateLabelForNewChemical,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF14B8A6)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            isGeneratingLabel
                                ? 'Generating...'
                                : 'Regenerate Label',
                          ),
                        ),
                      ),
                    if (!isExisting) const SizedBox(height: 14),
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