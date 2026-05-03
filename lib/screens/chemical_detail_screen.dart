import 'package:flutter/material.dart';
import '../models/chemical_model.dart';
import '../services/inventory_service.dart';
import '../services/pubchem_service.dart';

class ChemicalDetailScreen extends StatefulWidget {
  final ChemicalModel chemical;

  const ChemicalDetailScreen({
    super.key,
    required this.chemical,
  });

  @override
  State<ChemicalDetailScreen> createState() =>
      _ChemicalDetailScreenState();
}

class _ChemicalDetailScreenState extends State<ChemicalDetailScreen>
    with SingleTickerProviderStateMixin {
  final InventoryService inventoryService = InventoryService();
  final PubChemService pubChemService = PubChemService();
  static const List<String> _allowedBottleStatuses = [
    'available',
    'low',
    'finished',
  ];

  late Future<PubChemChemicalDetails?> pubChemFuture;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    pubChemFuture = pubChemService.fetchByCas(widget.chemical.cas.trim());

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _rotateAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.linear,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color availabilityColor(String availability) {
    final v = availability.toLowerCase();
    if (v.contains('finished')) return Colors.redAccent;
    if (v.contains('low') || v.contains('about')) return Colors.orangeAccent;
    return Colors.greenAccent;
  }

  String _safeBottleStatus(String rawStatus) {
    final normalized = rawStatus.trim().toLowerCase();
    return _allowedBottleStatuses.contains(normalized)
        ? normalized
        : 'available';
  }

  String _bottleStatusLabel(String status) {
    switch (status) {
      case 'low':
        return 'Low';
      case 'finished':
        return 'Finished';
      case 'available':
      default:
        return 'Available';
    }
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget buildFunctionalGroupChips(String groups) {
  if (groups.trim().isEmpty) return const SizedBox();

  final list = groups
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Functional Groups',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: list.map((group) {
            return GestureDetector(
              onTap: () {
                Navigator.pop(context, group);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x2214B8A6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  group,
                  style: const TextStyle(
                    color: Color(0xFF14B8A6),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );
}

  Widget detailBox({
    required String label,
    required String value,
    IconData? icon,
  }) {
    final displayValue = value.trim().isEmpty ? '-' : value.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: const Color(0xFF14B8A6),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  displayValue,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.2,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget twoColumnDetailBox({
    required String leftLabel,
    required String leftValue,
    required String rightLabel,
    required String rightValue,
    IconData? leftIcon,
    IconData? rightIcon,
  }) {
    return Row(
      children: [
        Expanded(
          child: detailBox(
            label: leftLabel,
            value: leftValue,
            icon: leftIcon,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: detailBox(
            label: rightLabel,
            value: rightValue,
            icon: rightIcon,
          ),
        ),
      ],
    );
  }

  Widget chemistryLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotateAnimation.value * 6.28318,
                child: ScaleTransition(
                  scale: _pulseAnimation,
                  child: child,
                ),
              );
            },
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x2214B8A6),
                border: Border.all(
                  color: const Color(0xFF14B8A6),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.science_rounded,
                color: Color(0xFF14B8A6),
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Fetching molecular data...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Checking structure, formula, molecular weight and identifiers from PubChem',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12.8,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: Color(0x332B3A55),
              valueColor: AlwaysStoppedAnimation(Color(0xFF14B8A6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget bottleCard(ChemicalModel b, int index) {
    final safeStatus = _safeBottleStatus(b.availability);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Bottle ${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  DropdownButton<String>(
                    value: safeStatus,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    items: _allowedBottleStatuses
                        .map(
                          (status) => DropdownMenuItem<String>(
                            value: status,
                            child: Text(_bottleStatusLabel(status)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) async {
                      if (value == null) return;

                      await inventoryService.inventoryRef.doc(b.id).update({
                        'availability': _safeBottleStatus(value),
                        'updatedAt': DateTime.now(),
                      });

                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  chip('Brand: ${b.brand.isEmpty ? '-' : b.brand}'),
                  chip('Qty: ${b.quantity.isEmpty ? '-' : b.quantity}'),
                  chip('Loc: ${b.location.isEmpty ? '-' : b.location}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget pubChemDetailsCard(PubChemChemicalDetails p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF162033),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0x2214B8A6),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.biotech_rounded,
                color: Color(0xFF14B8A6),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'PubChem Molecular Data',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Image.network(
              p.imageUrl,
              height: 150,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text(
                'Structure image unavailable',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
          const SizedBox(height: 14),
          twoColumnDetailBox(
            leftLabel: 'Molecular Formula',
            leftValue: p.molecularFormula,
            rightLabel: 'Molecular Weight',
            rightValue: p.molecularWeight,
            leftIcon: Icons.functions_rounded,
            rightIcon: Icons.monitor_weight_outlined,
          ),
          const SizedBox(height: 10),
          detailBox(
            label: 'PubChem CID',
            value: p.cid,
            icon: Icons.tag_rounded,
          ),
          const SizedBox(height: 10),
          detailBox(
            label: 'InChIKey',
            value: p.inchiKey,
            icon: Icons.vpn_key_outlined,
          ),
          const SizedBox(height: 10),
          detailBox(
            label: 'IUPAC Name',
            value: p.iupacName,
            icon: Icons.menu_book_rounded,
          ),
          const SizedBox(height: 10),
          detailBox(
            label: 'Canonical SMILES',
            value: p.canonicalSmiles,
            icon: Icons.account_tree_outlined,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chemical;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chemical Details',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: StreamBuilder<List<ChemicalModel>>(
        stream: inventoryService.getChemicals(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data!;

          final bottles = all.where((e) => e.cas.trim() == c.cas.trim()).toList()
            ..sort((a, b) => a.label.compareTo(b.label));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x2214B8A6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        c.label,
                        style: const TextStyle(
                          color: Color(0xFF14B8A6),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      c.chemicalName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'CAS: ${c.cas}',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${bottles.length} bottles',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              buildFunctionalGroupChips(c.functionalGroups),

              sectionTitle('Bottles'),
              ...List.generate(
                bottles.length,
                (i) => bottleCard(bottles[i], i),
              ),

              sectionTitle('PubChem'),
              FutureBuilder<PubChemChemicalDetails?>(
                future: pubChemFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return chemistryLoadingCard();
                  }

                  if (snapshot.hasError) {
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'PubChem error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data == null) {
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        c.cas.trim().isEmpty
                            ? 'No CAS number available for PubChem lookup.'
                            : 'No PubChem data found for CAS: ${c.cas.trim()}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  final p = snapshot.data!;
                  return pubChemDetailsCard(p);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
