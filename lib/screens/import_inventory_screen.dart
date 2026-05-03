import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';

class ImportInventoryScreen extends StatefulWidget {
  const ImportInventoryScreen({super.key});

  @override
  State<ImportInventoryScreen> createState() => _ImportInventoryScreenState();
}

class _ImportInventoryScreenState extends State<ImportInventoryScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final CollectionReference inventoryRef =
      FirebaseFirestore.instance.collection('inventory');

  bool isImporting = false;
  String statusMessage =
      'Pick a cleaned inventory file (.xlsx or .csv) to replace Firestore inventory.';
  int importedCount = 0;
  int skippedCount = 0;
  int rowsReadCount = 0;
  String lastImportedLabId = '';

  Future<void> pickAndImportFile() async {
    final currentLabId = AppState.instance.resolveWriteLabId();

    setState(() {
      isImporting = true;
      statusMessage = 'Opening file picker...';
      importedCount = 0;
      skippedCount = 0;
      rowsReadCount = 0;
      lastImportedLabId = currentLabId;
    });

    debugPrint(
      '[Inventory Import] Starting import. '
      'labId="${currentLabId.isEmpty ? '<legacy-empty>' : currentLabId}"',
    );

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          isImporting = false;
          statusMessage = 'No file selected.';
        });
        return;
      }

      final pickedFile = result.files.first;
      final fileName = pickedFile.name.trim().toLowerCase();

      Uint8List? bytes = pickedFile.bytes;

      if ((bytes == null || bytes.isEmpty) &&
          !kIsWeb &&
          pickedFile.path != null) {
        final file = File(pickedFile.path!);
        bytes = await file.readAsBytes();
      }

      if (bytes == null || bytes.isEmpty) {
        setState(() {
          isImporting = false;
          statusMessage = 'Could not read file bytes.';
        });
        return;
      }

      if (fileName.endsWith('.xlsx')) {
        setState(() {
          statusMessage = 'Reading Excel file...';
        });
        final importResult = await _freshReplaceFromExcelBytes(
          bytes,
          currentLabId,
        );
        _applyImportResult(importResult);
      } else if (fileName.endsWith('.csv')) {
        setState(() {
          statusMessage = 'Reading CSV file...';
        });
        final importResult = await _freshReplaceFromCsvBytes(
          bytes,
          currentLabId,
        );
        _applyImportResult(importResult);
      } else {
        setState(() {
          isImporting = false;
          statusMessage = 'Please select a valid .xlsx or .csv file.';
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a valid .xlsx or .csv file'),
          ),
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        isImporting = false;
        statusMessage = _buildImportCompleteMessage(currentLabId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported $importedCount chemicals, skipped $skippedCount rows.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isImporting = false;
        statusMessage = 'Import failed: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
        ),
      );
    }
  }

  void _applyImportResult(_InventoryImportResult result) {
    importedCount = result.importedCount;
    skippedCount = result.skippedCount;
    rowsReadCount = result.rowsReadCount;
  }

  String _buildImportCompleteMessage(String labId) {
    final labLabel = labId.isEmpty ? 'legacy/unscoped inventory' : labId;
    return 'Import complete. '
        'Rows read: $rowsReadCount. '
        'Imported: $importedCount. '
        'Skipped: $skippedCount. '
        'Lab: $labLabel.';
  }

  Future<_InventoryImportResult> _freshReplaceFromExcelBytes(
    Uint8List bytes,
    String labId,
  ) async {
    await _deleteAllInventory();

    final excel = Excel.decodeBytes(bytes);

    WriteBatch batch = firestore.batch();
    int batchCount = 0;
    int successCount = 0;
    int skippedRows = 0;
    int rowsRead = 0;

    debugPrint(
      '[Inventory Import] Excel workbook loaded. '
      'sheets=${excel.tables.length}, '
      'labId="${labId.isEmpty ? '<legacy-empty>' : labId}"',
    );

    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName];
      if (sheet == null || sheet.rows.isEmpty) continue;

      final rows = sheet.rows;
      final headers = rows.first.map((cell) {
        return _excelCellToString(cell).trim();
      }).toList();

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        rowsRead++;

        final rowMap = <String, String>{};
        for (int j = 0; j < headers.length; j++) {
          final key = headers[j];
          if (key.isEmpty) continue;

          final value = j < row.length ? _excelCellToString(row[j]).trim() : '';
          rowMap[key] = value;
        }

        final chemicalName = rowMap['Chemical Name'] ?? '';
        if (chemicalName.trim().isEmpty) {
          skippedRows++;
          continue;
        }

        final currentLabel = rowMap['Current Label'] ?? rowMap['Label'] ?? '';
        final suggestedLabel = rowMap['Suggested Label'] ?? '';
        final finalLabel =
            currentLabel.isNotEmpty ? currentLabel : suggestedLabel;

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
            rowMap['Cat Number'] ??
            '';
        final arrivalDate = rowMap['Arrival Date'] ?? '';
        final orderedBy = rowMap['Ordered by'] ?? rowMap['Ordered By'] ?? '';
        final functionalGroups = rowMap['Functional Groups'] ?? '';
        final cas = rowMap['CAS'] ?? '';

        final docRef = inventoryRef.doc();

        batch.set(docRef, {
          'labId': labId,
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

        batchCount++;
        successCount++;

        if (batchCount >= 400) {
          await batch.commit();
          batch = firestore.batch();
          batchCount = 0;
        }
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    debugPrint(
      '[Inventory Import] Excel import complete. '
      'rowsRead=$rowsRead, imported=$successCount, skipped=$skippedRows, '
      'labId="${labId.isEmpty ? '<legacy-empty>' : labId}"',
    );

    return _InventoryImportResult(
      rowsReadCount: rowsRead,
      importedCount: successCount,
      skippedCount: skippedRows,
    );
  }

  Future<_InventoryImportResult> _freshReplaceFromCsvBytes(
    Uint8List bytes,
    String labId,
  ) async {
    await _deleteAllInventory();

    final csvString = utf8.decode(bytes);
    final rows = CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(csvString);

    if (rows.length < 2) {
      throw Exception('CSV is empty or has no data rows.');
    }

    final headers = rows.first.map((e) => e.toString().trim()).toList();

    final Map<String, int> headerMap = {};
    for (int i = 0; i < headers.length; i++) {
      headerMap[headers[i]] = i;
    }

    WriteBatch batch = firestore.batch();
    int batchCount = 0;
    int successCount = 0;
    int skippedRows = 0;
    int rowsRead = 0;

    debugPrint(
      '[Inventory Import] CSV loaded. '
      'rows=${rows.length - 1}, '
      'labId="${labId.isEmpty ? '<legacy-empty>' : labId}"',
    );

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      rowsRead++;
      final chemicalName = _csvCell(row, headerMap, 'Chemical Name');

      if (chemicalName.isEmpty) {
        skippedRows++;
        continue;
      }

      final docRef = inventoryRef.doc();

      batch.set(docRef, {
        'labId': labId,
        'label': _csvCell(row, headerMap, 'Current Label').isNotEmpty
            ? _csvCell(row, headerMap, 'Current Label')
            : _csvCell(row, headerMap, 'Label'),
        'chemicalName': chemicalName,
        'cas': _csvCell(row, headerMap, 'CAS'),
        'formula': _csvCell(row, headerMap, 'Molecular Formula').isNotEmpty
            ? _csvCell(row, headerMap, 'Molecular Formula')
            : _csvCell(row, headerMap, 'Formula'),
        'molWt': _csvCell(row, headerMap, 'Molecular Weight').isNotEmpty
            ? _csvCell(row, headerMap, 'Molecular Weight')
            : _csvCell(row, headerMap, 'Mol. Wt.'),
        'availability': _csvCell(row, headerMap, 'Availability').isNotEmpty
            ? _csvCell(row, headerMap, 'Availability')
            : 'Available',
        'texture': _csvCell(row, headerMap, 'Texture'),
        'location': _csvCell(row, headerMap, 'Location'),
        'quantity': _csvCell(row, headerMap, 'Quantity'),
        'brand': _csvCell(row, headerMap, 'Brand'),
        'catNumber': _csvCell(row, headerMap, 'Catalogue Number').isNotEmpty
            ? _csvCell(row, headerMap, 'Catalogue Number')
            : _csvCell(row, headerMap, 'Cat Number'),
        'arrivalDate': _csvCell(row, headerMap, 'Arrival Date'),
        'orderedBy': _csvCell(row, headerMap, 'Ordered by').isNotEmpty
            ? _csvCell(row, headerMap, 'Ordered by')
            : _csvCell(row, headerMap, 'Ordered By'),
        'functionalGroups': _csvCell(row, headerMap, 'Functional Groups'),
        'sheetTab': _csvCell(row, headerMap, 'Category').isNotEmpty
            ? _csvCell(row, headerMap, 'Category')
            : 'Sheet1',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batchCount++;
      successCount++;

      if (batchCount >= 400) {
        await batch.commit();
        batch = firestore.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    debugPrint(
      '[Inventory Import] CSV import complete. '
      'rowsRead=$rowsRead, imported=$successCount, skipped=$skippedRows, '
      'labId="${labId.isEmpty ? '<legacy-empty>' : labId}"',
    );

    return _InventoryImportResult(
      rowsReadCount: rowsRead,
      importedCount: successCount,
      skippedCount: skippedRows,
    );
  }

  Future<void> _deleteAllInventory() async {
    while (true) {
      final snapshot = await inventoryRef.limit(300).get();
      if (snapshot.docs.isEmpty) break;

      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  String _excelCellToString(Data? cell) {
    if (cell == null || cell.value == null) return '';
    return cell.value.toString();
  }

  String _csvCell(List<dynamic> row, Map<String, int> headerMap, String key) {
    final index = headerMap[key];
    if (index == null || index >= row.length) return '';
    final value = row[index];
    return value == null ? '' : value.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Import Inventory',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'One-time Inventory Import',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      statusMessage,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Imported: $importedCount | Skipped: $skippedCount',
                      style: const TextStyle(
                        color: Color(0xFF14B8A6),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (lastImportedLabId.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Current lab: $lastImportedLabId',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isImporting ? null : pickAndImportFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: isImporting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.upload_file_rounded),
                  label: Text(
                    isImporting
                        ? 'Importing...'
                        : 'Pick CSV / Excel and Import',
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

class _InventoryImportResult {
  final int rowsReadCount;
  final int importedCount;
  final int skippedCount;

  const _InventoryImportResult({
    required this.rowsReadCount,
    required this.importedCount,
    required this.skippedCount,
  });
}
