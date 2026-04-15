import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';

class InventoryImportService {
  final CollectionReference inventoryRef =
      FirebaseFirestore.instance.collection('inventory');

  Future<void> freshReplaceFromExcelBytes(Uint8List bytes) async {
    // 1. Delete existing inventory
    await _deleteAllInventory();

    // 2. Decode workbook
    final excel = Excel.decodeBytes(bytes);

    // 3. Import every sheet
    WriteBatch batch = FirebaseFirestore.instance.batch();
    int opCount = 0;

    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName];
      if (sheet == null || sheet.rows.isEmpty) continue;

      final rows = sheet.rows;
      final headers = rows.first.map((cell) {
        return _cellToString(cell).trim();
      }).toList();

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];

        final rowMap = <String, String>{};
        for (int j = 0; j < headers.length; j++) {
          final key = headers[j];
          if (key.isEmpty) continue;

          final value = j < row.length ? _cellToString(row[j]).trim() : '';
          rowMap[key] = value;
        }

        final chemicalName = rowMap['Chemical Name'] ?? '';
        if (chemicalName.trim().isEmpty) continue;

        final currentLabel = rowMap['Current Label'] ?? '';
        final suggestedLabel = rowMap['Suggested Label'] ?? '';
        final finalLabel = currentLabel.isNotEmpty
            ? currentLabel
            : suggestedLabel;

        final formula = rowMap['Molecular Formula'] ??
            rowMap['Formula'] ??
            rowMap['Molecular Formula '] ??
            '';

        final molWt = rowMap['Mol. Wt.'] ??
            rowMap['Molecular Weight'] ??
            rowMap['Mol Wt'] ??
            '';

        final availability = (rowMap['Availability'] ?? '').isNotEmpty
            ? rowMap['Availability']!
            : 'Available';

        final texture = rowMap['Texture'] ?? '';
        final location = rowMap['Location'] ?? '';
        final quantity = rowMap['Quantity'] ?? '';
        final brand = rowMap['Brand'] ?? '';
        final catNumber = rowMap['Catalogue Number'] ??
            rowMap['Catalog Number'] ??
            '';
        final arrivalDate = rowMap['Arrival Date'] ?? '';
        final orderedBy = rowMap['Ordered by'] ?? rowMap['Ordered By'] ?? '';
        final functionalGroups = rowMap['Functional Groups'] ?? '';
        final cas = rowMap['CAS'] ?? '';

        final docRef = inventoryRef.doc();

        batch.set(docRef, {
          'label': finalLabel,
          'chemicalName': chemicalName,
          'cas': cas,
          'formula': formula,
          'molWt': molWt,
          'availability': availability,
          'texture': texture,
          'location': location,
          'quantity': quantity,
          'brand': brand,
          'catNumber': catNumber,
          'arrivalDate': arrivalDate,
          'orderedBy': orderedBy,
          'functionalGroups': functionalGroups,
          'sheetTab': sheetName,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        opCount++;

        // Firestore batch limit safety
        if (opCount >= 400) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          opCount = 0;
        }
      }
    }

    if (opCount > 0) {
      await batch.commit();
    }
  }

  Future<void> _deleteAllInventory() async {
    while (true) {
      final snapshot = await inventoryRef.limit(300).get();
      if (snapshot.docs.isEmpty) break;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  String _cellToString(Data? cell) {
    if (cell == null || cell.value == null) return '';
    return cell.value.toString();
  }
}