import 'dart:convert';
import 'package:http/http.dart' as http;

class PubChemChemicalDetails {
  final String molecularFormula;
  final String molecularWeight;
  final String iupacName;
  final String canonicalSmiles;
  final String inchiKey;
  final String cid;
  final String imageUrl;

  const PubChemChemicalDetails({
    required this.molecularFormula,
    required this.molecularWeight,
    required this.iupacName,
    required this.canonicalSmiles,
    required this.inchiKey,
    required this.cid,
    required this.imageUrl,
  });
}

class PubChemService {
  String _normalizeCas(String cas) {
    String value = cas.trim();

    // remove surrounding quotes if present
    value = value.replaceAll('"', '').replaceAll("'", '');

    // remove trailing .0 from Excel-style numeric conversion
    if (value.endsWith('.0')) {
      value = value.substring(0, value.length - 2);
    }

    return value;
  }

  Future<PubChemChemicalDetails?> fetchByCas(String cas) async {
    final cleanCas = _normalizeCas(cas);
    if (cleanCas.isEmpty) return null;

    try {
      // Step 1: CAS -> CID
      final cidUrl = Uri.parse(
        'https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/$cleanCas/cids/JSON',
      );

      final cidResponse = await http.get(cidUrl);

      if (cidResponse.statusCode != 200) {
        return null;
      }

      final cidJson = jsonDecode(cidResponse.body) as Map<String, dynamic>;
      final idList = cidJson['IdentifierList'] as Map<String, dynamic>?;
      final cids = idList?['CID'] as List<dynamic>?;

      if (cids == null || cids.isEmpty) return null;

      final cid = cids.first.toString();

      // Step 2: CID -> properties
      final propUrl = Uri.parse(
        'https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/$cid/property/MolecularFormula,MolecularWeight,IUPACName,CanonicalSMILES,InChIKey/JSON',
      );

      final propResponse = await http.get(propUrl);

      if (propResponse.statusCode != 200) {
        return null;
      }

      final propJson = jsonDecode(propResponse.body) as Map<String, dynamic>;
      final propertyTable = propJson['PropertyTable'] as Map<String, dynamic>?;
      final properties = propertyTable?['Properties'] as List<dynamic>?;

      if (properties == null || properties.isEmpty) return null;

      final p = properties.first as Map<String, dynamic>;

      final imageUrl =
          'https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/$cid/PNG';

      return PubChemChemicalDetails(
        molecularFormula: (p['MolecularFormula'] ?? '').toString(),
        molecularWeight: (p['MolecularWeight'] ?? '').toString(),
        iupacName: (p['IUPACName'] ?? '').toString(),
        canonicalSmiles: (p['CanonicalSMILES'] ?? '').toString(),
        inchiKey: (p['InChIKey'] ?? '').toString(),
        cid: cid,
        imageUrl: imageUrl,
      );
    } catch (_) {
      return null;
    }
  }
}