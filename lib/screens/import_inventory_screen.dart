import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class ImportInventoryScreen extends StatefulWidget {
  const ImportInventoryScreen({super.key});

  @override
  State<ImportInventoryScreen> createState() => _ImportInventoryScreenState();
}

class _ImportInventoryScreenState extends State<ImportInventoryScreen> {
  bool isImporting = false;
  String statusMessage = 'Pick a CSV file to import inventory.';
  int importedCount = 0;

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  String _cell(List<dynamic> row, Map<String, int> headerMap, String key) {
    final index = headerMap[key];
    if (index == null || index >= row.length) return '';
    final value = row[index];
    return value == null ? '' : value.toString().trim();
  }

  Future<void> importCsv() async {
    setState(() {
      isImporting = true;
      statusMessage = 'Selecting file...';
      importedCount = 0;
    });

    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          isImporting = false;
          statusMessage = 'Import cancelled.';
        });
        return;
      }

      final PlatformFile file = result.files.first;
      final Uint8List? bytes = file.bytes;

      if (bytes == null) {
        setState(() {
          isImporting = false;
          statusMessage = 'Could not read file bytes.';
        });
        return;
      }

      setState(() {
        statusMessage = 'Reading CSV...';
      });

      final String csvString = utf8.decode(bytes);

      // csv package v8 style
      final List<List<dynamic>> rows = csv.decode(csvString);

      if (rows.length < 2) {
        setState(() {
          isImporting = false;
          statusMessage = 'CSV is empty or has no data rows.';
        });
        return;
      }

      final headers = rows.first.map((e) => e.toString().trim()).toList();

      final Map<String, int> headerMap = {};
      for (int i = 0; i < headers.length; i++) {
        headerMap[headers[i]] = i;
      }

      final requiredHeaders = [
        'Label',
        'Chemical Name',
        'CAS',
        'Mol. Wt.',
        'Availability',
        'Texture',
        'Location',
        'Quantity',
        'Brand',
        'Cat Number',
        'Arrival Date',
        'Ordered by',
        'Functional Groups',
      ];

      final missingHeaders = requiredHeaders
          .where((header) => !headerMap.containsKey(header))
          .toList();

      if (missingHeaders.isNotEmpty) {
        setState(() {
          isImporting = false;
          statusMessage = 'Missing columns: ${missingHeaders.join(', ')}';
        });
        return;
      }

      setState(() {
        statusMessage = 'Uploading to Firestore...';
      });

      int successCount = 0;
      WriteBatch batch = firestore.batch();
      int batchCount = 0;

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        final chemicalName = _cell(row, headerMap, 'Chemical Name');

        if (chemicalName.isEmpty) continue;

        final docRef = firestore.collection('inventory').doc();

        final data = <String, dynamic>{
          'label': _cell(row, headerMap, 'Label'),
          'chemicalName': chemicalName,
          'cas': _cell(row, headerMap, 'CAS'),
          'molWt': _cell(row, headerMap, 'Mol. Wt.'),
          'availability': _cell(row, headerMap, 'Availability'),
          'texture': _cell(row, headerMap, 'Texture'),
          'location': _cell(row, headerMap, 'Location'),
          'quantity': _cell(row, headerMap, 'Quantity'),
          'brand': _cell(row, headerMap, 'Brand'),
          'catNumber': _cell(row, headerMap, 'Cat Number'),
          'arrivalDate': _cell(row, headerMap, 'Arrival Date'),
          'orderedBy': _cell(row, headerMap, 'Ordered by'),
          'functionalGroups': _cell(row, headerMap, 'Functional Groups'),
          'sheetTab': 'Sheet1',
        };

        batch.set(docRef, data);
        batchCount++;
        successCount++;

        if (batchCount >= 450) {
          await batch.commit();
          batch = firestore.batch();
          batchCount = 0;
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      setState(() {
        isImporting = false;
        importedCount = successCount;
        statusMessage = 'Import complete.';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported $successCount chemicals successfully'),
        ),
      );
    } catch (e) {
      setState(() {
        isImporting = false;
        statusMessage = 'Import failed: $e';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Import Inventory CSV',
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
                      'Imported rows: $importedCount',
                      style: const TextStyle(
                        color: Color(0xFF14B8A6),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isImporting ? null : importCsv,
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
                    isImporting ? 'Importing...' : 'Pick CSV and Import',
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