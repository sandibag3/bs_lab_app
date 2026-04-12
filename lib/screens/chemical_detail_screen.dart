import 'package:flutter/material.dart';
import '../models/chemical_model.dart';
import '../services/pubchem_service.dart';

class ChemicalDetailScreen extends StatefulWidget {
  final ChemicalModel chemical;

  const ChemicalDetailScreen({
    super.key,
    required this.chemical,
  });

  @override
  State<ChemicalDetailScreen> createState() => _ChemicalDetailScreenState();
}

class _ChemicalDetailScreenState extends State<ChemicalDetailScreen> {
  final PubChemService pubChemService = PubChemService();
  late Future<PubChemChemicalDetails?> pubChemFuture;

  @override
  void initState() {
    super.initState();
    pubChemFuture = pubChemService.fetchByCas(widget.chemical.cas);
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
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

  Widget compactDetailTile(String label, String value) {
    final displayValue = value.isEmpty ? '-' : value;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
      ),
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
          const SizedBox(height: 4),
          Text(
            displayValue,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.2,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget twoColumnTile(String leftLabel, String leftValue, String rightLabel, String rightValue) {
    return Row(
      children: [
        Expanded(child: compactDetailTile(leftLabel, leftValue)),
        const SizedBox(width: 8),
        Expanded(child: compactDetailTile(rightLabel, rightValue)),
      ],
    );
  }

  Color availabilityColor(String availability) {
    final value = availability.toLowerCase();
    if (value.contains('finished') ||
        value.contains('empty') ||
        value.contains('not available')) {
      return Colors.redAccent;
    }
    if (value.contains('about')) {
      return Colors.orangeAccent;
    }
    return Colors.greenAccent;
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
      body: ListView(
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
                Text(
                  c.chemicalName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
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
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Text(
                      c.availability,
                      style: TextStyle(
                        color: availabilityColor(c.availability),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          sectionTitle('Inventory Info'),
          twoColumnTile('CAS No', c.cas, 'Brand', c.brand),
          twoColumnTile('Quantity', c.quantity, 'Location', c.location),
          twoColumnTile('Texture', c.texture, 'Molecular Weight', c.molWt),
          compactDetailTile('Catalog Number', c.catNumber),
          twoColumnTile('Arrival Date', c.arrivalDate, 'Ordered By', c.orderedBy),
          compactDetailTile('Functional Groups', c.functionalGroups),
          compactDetailTile('Sheet Tab', c.sheetTab),

          const SizedBox(height: 8),
          sectionTitle('PubChem Details'),
          FutureBuilder<PubChemChemicalDetails?>(
            future: pubChemFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'PubChem details could not be fetched for this CAS number.',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              final p = snapshot.data!;

              return Column(
                children: [
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
                  const SizedBox(height: 10),
                  twoColumnTile('PubChem CID', p.cid, 'Formula', p.molecularFormula),
                  twoColumnTile('Mol. Weight', p.molecularWeight, 'InChIKey', p.inchiKey),
                  compactDetailTile('IUPAC Name', p.iupacName),
                  compactDetailTile('Canonical SMILES', p.canonicalSmiles),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}