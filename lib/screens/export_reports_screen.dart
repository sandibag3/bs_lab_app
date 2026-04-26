import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';

class ExportReportsScreen extends StatefulWidget {
  final AppState appState;

  const ExportReportsScreen({super.key, required this.appState});

  @override
  State<ExportReportsScreen> createState() => _ExportReportsScreenState();
}

class _ExportReportsScreenState extends State<ExportReportsScreen> {
  String? exportingKey;

  String get _labId => widget.appState.selectedLabId.trim();

  List<_ReportDefinition> get _reports {
    return [
      _ReportDefinition(
        key: 'chemical_inventory',
        title: 'Chemical Inventory',
        subtitle: 'Export current lab chemical inventory rows.',
        icon: Icons.science_rounded,
        collection: 'inventory',
        headers: const [
          'id',
          'label',
          'chemicalName',
          'cas',
          'formula',
          'molWt',
          'availability',
          'texture',
          'location',
          'quantity',
          'brand',
          'catNumber',
          'arrivalDate',
          'orderedBy',
          'functionalGroups',
          'sheetTab',
        ],
      ),
      _ReportDefinition(
        key: 'consumables_inventory',
        title: 'Consumables Inventory',
        subtitle: 'Export current consumable aggregate stock.',
        icon: Icons.inventory_rounded,
        collection: 'consumables_inventory',
        headers: const [
          'id',
          'consumableType',
          'quantity',
          'brand',
          'latestBrand',
          'vendor',
          'latestVendor',
          'modeOfPurchase',
          'orderedBy',
          'receivedBy',
          'deliveredAt',
          'createdAt',
          'updatedAt',
        ],
      ),
      _ReportDefinition(
        key: 'requirements',
        title: 'Requirements',
        subtitle: 'Export submitted requirement records.',
        icon: Icons.assignment_rounded,
        collection: 'requirements',
        headers: const [
          'id',
          'mainType',
          'chemicalName',
          'consumableType',
          'cas',
          'brand',
          'vendor',
          'quantity',
          'estimatedCost',
          'estimatedTotal',
          'modeOfPurchase',
          'packSize',
          'status',
          'userName',
          'createdAt',
          'approvedBy',
          'approvedAt',
        ],
      ),
      _ReportDefinition(
        key: 'orders',
        title: 'Orders',
        subtitle: 'Export order status and delivery records.',
        icon: Icons.local_shipping_rounded,
        collection: 'orders',
        headers: const [
          'id',
          'requirementId',
          'mainType',
          'chemicalName',
          'consumableType',
          'cas',
          'brand',
          'vendor',
          'quantity',
          'packSize',
          'modeOfPurchase',
          'orderedBy',
          'orderedAt',
          'status',
          'receivedBy',
          'deliveredAt',
          'inventoryAdded',
        ],
      ),
      _ReportDefinition(
        key: 'consumable_stock_logs',
        title: 'Consumable Stock Logs',
        subtitle: 'Export stock added/used history.',
        icon: Icons.history_rounded,
        collection: 'consumable_stock_logs',
        headers: const [
          'id',
          'consumableInventoryId',
          'consumableType',
          'action',
          'quantityChanged',
          'previousQuantity',
          'newQuantity',
          'note',
          'createdAt',
          'createdBy',
          'actorName',
        ],
      ),
      _ReportDefinition(
        key: 'recent_activity',
        title: 'Recent Activity',
        subtitle: 'Export lab activity feed records.',
        icon: Icons.notifications_rounded,
        collection: 'activities',
        headers: const [
          'id',
          'type',
          'message',
          'createdAt',
          'createdBy',
          'actorName',
          'relatedId',
        ],
      ),
    ];
  }

  Future<void> _exportReport(_ReportDefinition report) async {
    if (_labId.isEmpty) {
      _showMessage('Select a lab before exporting reports.');
      return;
    }

    setState(() {
      exportingKey = report.key;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(report.collection)
          .get();
      final docs = snapshot.docs.where((doc) {
        final data = doc.data();
        return (data['labId'] ?? '').toString().trim() == _labId;
      }).toList();

      final rows = <List<dynamic>>[
        report.headers,
        ...docs.map((doc) {
          final data = doc.data();
          return report.headers.map((header) {
            if (header == 'id') {
              return doc.id;
            }
            return _csvValue(data[header]);
          }).toList();
        }),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final fileName = _fileName(report.key);
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save ${report.title}',
        fileName: fileName,
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );

      if (!mounted) return;

      _showMessage(
        savedPath == null
            ? 'Export cancelled.'
            : 'Exported ${docs.length} rows to $fileName.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not export ${report.title}: $error');
    } finally {
      if (mounted) {
        setState(() {
          exportingKey = null;
        });
      }
    }
  }

  String _csvValue(dynamic value) {
    if (value == null) return '';
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return value.toString();
  }

  String _fileName(String key) {
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final labPart = _labId.isEmpty ? 'lab' : _labId;
    return '${labPart}_${key}_$date.csv';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Export Reports',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _reports.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final report = _reports[index];
            final isExporting = exportingKey == report.key;

            return Material(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: exportingKey == null
                    ? () => _exportReport(report)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(
                          0xFF14B8A6,
                        ).withValues(alpha: 0.14),
                        child: Icon(
                          report.icon,
                          color: const Color(0xFF14B8A6),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              report.subtitle,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (isExporting)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(
                          Icons.file_download_rounded,
                          color: Colors.white54,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ReportDefinition {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final String collection;
  final List<String> headers;

  const _ReportDefinition({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.collection,
    required this.headers,
  });
}
