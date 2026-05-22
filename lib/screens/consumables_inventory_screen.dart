import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/activity_service.dart';
import '../services/consumables_inventory_service.dart';
import '../services/firestore_access_guard.dart';
import '../theme/labmate_theme.dart';
import '../widgets/responsive_page_container.dart';

class ConsumablesInventoryScreen extends StatefulWidget {
  const ConsumablesInventoryScreen({super.key});

  @override
  State<ConsumablesInventoryScreen> createState() =>
      _ConsumablesInventoryScreenState();
}

class _ConsumablesInventoryScreenState
    extends State<ConsumablesInventoryScreen> {
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _inventoryStream() {
    return ConsumablesInventoryService().getConsumablesInventoryDocs();
  }

  Timestamp? _readTimestamp(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is Timestamp ? value : null;
  }

  String _readText(Map<String, dynamic> data, String key) {
    return (data[key] ?? '').toString().trim();
  }

  double? _readQuantityNumber(String quantity) {
    final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(quantity.trim());
    if (match == null) {
      return null;
    }

    return double.tryParse(match.group(0) ?? '');
  }

  bool _isLowStock(String quantity) {
    final numericQuantity = _readQuantityNumber(quantity);
    return numericQuantity != null && numericQuantity <= 2;
  }

  String _readAvailability(Map<String, dynamic> data) {
    final availability = _readText(data, 'availability');
    if (availability.isNotEmpty) return availability;
    return _readText(data, 'status');
  }

  String _availabilityLabel(String availability) {
    final normalized = availability.trim().toLowerCase();
    if (normalized == 'low') return 'Low Stock';
    if (normalized == 'finished') return 'Finished';
    return '';
  }

  Color _availabilityColor(String availability) {
    final normalized = availability.trim().toLowerCase();
    if (normalized == 'finished') return Colors.redAccent;
    return const Color(0xFFFB7185);
  }

  String _formatQuantityNumber(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toStringAsFixed(0);
    }

    return quantity.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  String _inventoryKey(String consumableType) {
    return consumableType.trim().toLowerCase();
  }

  static const List<String> _categoryOrder = [
    'Gloves',
    'Syringes',
    'Balloons',
    'Needles',
    'Filter Paper',
    'Silica',
    'TLC Plates',
    'Cotton',
    'Rubber Band',
    'Tubes',
    'Joint Clips',
    'Grease',
    'Teflon',
    'Reflux Pumps',
    'Column Pumps',
    'Others',
  ];

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Not available';

    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Not available';

    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sorted = [...docs];
    sorted.sort((a, b) {
      final aData = a.data();
      final bData = b.data();
      final aTimestamp =
          _readTimestamp(aData, 'createdAt') ??
          _readTimestamp(aData, 'deliveredAt') ??
          _readTimestamp(aData, 'updatedAt');
      final bTimestamp =
          _readTimestamp(bData, 'createdAt') ??
          _readTimestamp(bData, 'deliveredAt') ??
          _readTimestamp(bData, 'updatedAt');

      final aDate = aTimestamp?.toDate() ?? DateTime(2000);
      final bDate = bTimestamp?.toDate() ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });
    return sorted;
  }

  List<_ConsumableInventoryItem> _groupDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final grouped =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final doc in docs) {
      final data = doc.data();
      final key = _inventoryKey(_readText(data, 'consumableType'));
      grouped.putIfAbsent(key, () => []).add(doc);
    }

    return grouped.values.map((groupDocs) {
      QueryDocumentSnapshot<Map<String, dynamic>>? aggregateDoc;
      for (final doc in groupDocs) {
        if (doc.data()['isAggregate'] == true) {
          aggregateDoc = doc;
          break;
        }
      }

      final primaryDoc = aggregateDoc ?? groupDocs.first;
      final primaryData = primaryDoc.data();
      final aggregateQuantity = aggregateDoc == null
          ? groupDocs.fold<double?>(0, (total, doc) {
              final quantity = _readQuantityNumber(
                _readText(doc.data(), 'quantity'),
              );
              if (quantity == null || total == null) {
                return null;
              }
              return total + quantity;
            })
          : _readQuantityNumber(_readText(primaryData, 'quantity'));
      final quantityText = aggregateQuantity == null
          ? _readText(primaryData, 'quantity')
          : _formatQuantityNumber(aggregateQuantity);
      final brands = groupDocs
          .map((doc) => _readText(doc.data(), 'brand'))
          .where((brand) => brand.isNotEmpty)
          .toSet();
      final vendors = groupDocs
          .map((doc) => _readText(doc.data(), 'vendor'))
          .where((vendor) => vendor.isNotEmpty)
          .toSet();

      return _ConsumableInventoryItem(
        primaryDoc: primaryDoc,
        sourceDocs: groupDocs,
        quantityText: quantityText,
        numericQuantity: aggregateQuantity,
        brandLabel: brands.length > 1
            ? 'Mixed brands'
            : brands.isEmpty
            ? ''
            : brands.first,
        vendorLabel: vendors.length > 1
            ? ''
            : vendors.isEmpty
            ? ''
            : vendors.first,
      );
    }).toList();
  }

  _ConsumableTypeParts _parseConsumableType(String consumableType) {
    final cleanType = consumableType.trim();
    if (cleanType.isEmpty) {
      return const _ConsumableTypeParts(category: 'Others', variant: 'Unnamed');
    }

    final normalized = cleanType.toLowerCase();

    if (normalized.contains('preparative tlc')) {
      return const _ConsumableTypeParts(
        category: 'TLC Plates',
        variant: 'Preparative',
      );
    }

    if (normalized.contains('tlc')) {
      return const _ConsumableTypeParts(
        category: 'TLC Plates',
        variant: 'Normal',
      );
    }

    if (normalized.startsWith('gloves')) {
      return _mapTypeWithSuffix(originalType: cleanType, category: 'Gloves');
    }

    if (normalized.startsWith('syringe')) {
      return _mapTypeWithSuffix(originalType: cleanType, category: 'Syringes');
    }

    if (normalized.startsWith('balloon') || normalized.contains('balloon')) {
      return _mapTypeWithSuffix(originalType: cleanType, category: 'Balloons');
    }

    if (normalized.startsWith('needle') || normalized.contains('needle')) {
      return _mapTypeWithSuffix(originalType: cleanType, category: 'Needles');
    }

    if (normalized.contains('filter paper')) {
      return _mapTypeWithSuffix(
        originalType: cleanType,
        category: 'Filter Paper',
      );
    }

    if (normalized.startsWith('silica') || normalized.contains('silica')) {
      return _mapTypeWithSuffix(originalType: cleanType, category: 'Silica');
    }

    if (normalized.startsWith('cotton') || normalized.contains('cotton')) {
      return _mapTypeWithSuffix(originalType: cleanType, category: 'Cotton');
    }

    if (normalized.contains('rubber band')) {
      return _mapTypeWithSuffix(
        originalType: cleanType,
        category: 'Rubber Band',
      );
    }

    if (normalized.startsWith('tube') || normalized.contains('tube')) {
      return _mapTypeWithSuffix(originalType: cleanType, category: 'Tubes');
    }

    if (normalized.startsWith('clips') ||
        normalized.startsWith('clip') ||
        normalized.contains('joint clip')) {
      return _mapTypeWithSuffix(
        originalType: cleanType,
        category: 'Joint Clips',
      );
    }

    if (normalized.startsWith('grease') || normalized.contains('grease')) {
      return _mapTypeWithSuffix(originalType: cleanType, category: 'Grease');
    }

    if (normalized.startsWith('teflon') || normalized.contains('teflon')) {
      return _mapTypeWithSuffix(originalType: cleanType, category: 'Teflon');
    }

    if (normalized.startsWith('reflux pump') ||
        normalized.contains('reflux pump')) {
      return _mapTypeWithSuffix(
        originalType: cleanType,
        category: 'Reflux Pumps',
      );
    }

    if (normalized.startsWith('column pump') ||
        normalized.contains('column pump')) {
      return _mapTypeWithSuffix(
        originalType: cleanType,
        category: 'Column Pumps',
      );
    }

    return _ConsumableTypeParts(category: 'Others', variant: cleanType);
  }

  _ConsumableTypeParts _mapTypeWithSuffix({
    required String originalType,
    required String category,
    String defaultVariant = 'Standard',
  }) {
    final suffix = _extractVariantSuffix(originalType);
    return _ConsumableTypeParts(
      category: category,
      variant: suffix.isEmpty ? defaultVariant : suffix,
    );
  }

  String _extractVariantSuffix(String originalType) {
    final parts = originalType.split(RegExp(r'\s*-\s*'));
    if (parts.length <= 1) {
      return '';
    }

    return parts.sublist(1).join(' - ').trim();
  }

  int _categorySortIndex(String category) {
    final index = _categoryOrder.indexOf(category);
    return index == -1 ? _categoryOrder.length : index;
  }

  int _variantSortWeight(String variant) {
    final normalized = variant.trim().toLowerCase();
    const specialWeights = {
      'normal': 0,
      'standard': 0,
      'small': 1,
      'medium': 2,
      'large': 3,
      'preparative': 4,
    };

    final specialWeight = specialWeights[normalized];
    if (specialWeight != null) {
      return specialWeight;
    }

    final numericMatch = RegExp(r'[-+]?\d*\.?\d+').firstMatch(normalized);
    if (numericMatch != null) {
      final value = double.tryParse(numericMatch.group(0) ?? '');
      if (value != null) {
        return 100 + (value * 10).round();
      }
    }

    return 1000;
  }

  List<_ConsumableCategoryGroup> _groupItemsByCategory(
    List<_ConsumableInventoryItem> items,
  ) {
    final grouped = <String, List<_ConsumableVariantItem>>{};

    for (final item in items) {
      final data = item.primaryDoc.data();
      final consumableType = _readText(data, 'consumableType');
      final parsedType = _parseConsumableType(consumableType);

      grouped
          .putIfAbsent(parsedType.category, () => [])
          .add(
            _ConsumableVariantItem(
              item: item,
              variant: parsedType.variant,
              consumableType: consumableType,
            ),
          );
    }

    final groups = grouped.entries.map((entry) {
      final variants = [...entry.value];
      variants.sort((a, b) {
        final weightComparison = _variantSortWeight(
          a.variant,
        ).compareTo(_variantSortWeight(b.variant));
        if (weightComparison != 0) {
          return weightComparison;
        }

        return a.variant.toLowerCase().compareTo(b.variant.toLowerCase());
      });

      final totalQuantity = variants.fold<double?>(0, (total, variant) {
        if (total == null || variant.item.numericQuantity == null) {
          return null;
        }
        return total + variant.item.numericQuantity!;
      });

      final lowStockCount = variants.where((variant) {
        final quantity = variant.item.numericQuantity;
        return quantity != null && quantity <= 2;
      }).length;

      return _ConsumableCategoryGroup(
        category: entry.key,
        variants: variants,
        totalQuantity: totalQuantity,
        lowStockCount: lowStockCount,
      );
    }).toList();

    groups.sort((a, b) {
      final orderComparison = _categorySortIndex(
        a.category,
      ).compareTo(_categorySortIndex(b.category));
      if (orderComparison != 0) {
        return orderComparison;
      }

      return a.category.toLowerCase().compareTo(b.category.toLowerCase());
    });

    return groups;
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _stockLogsStream({
    required String labId,
    required String consumableInventoryId,
  }) {
    return FirebaseFirestore.instance
        .collection('consumable_stock_logs')
        .snapshots()
        .map((snapshot) {
          final logs = snapshot.docs.where((doc) {
            final data = doc.data();
            return (data['labId'] ?? '').toString().trim() == labId &&
                (data['consumableInventoryId'] ?? '').toString().trim() ==
                    consumableInventoryId;
          }).toList();

          logs.sort((a, b) {
            final aCreatedAt = _readTimestamp(a.data(), 'createdAt');
            final bCreatedAt = _readTimestamp(b.data(), 'createdAt');
            final aDate = aCreatedAt?.toDate() ?? DateTime(2000);
            final bDate = bCreatedAt?.toDate() ?? DateTime(2000);
            return bDate.compareTo(aDate);
          });

          return logs.take(30).toList();
        });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _purchaseLogsStream({
    required String labId,
    required String consumableInventoryId,
  }) {
    return FirebaseFirestore.instance
        .collection('consumable_purchase_logs')
        .snapshots()
        .map((snapshot) {
          final logs = snapshot.docs.where((doc) {
            final data = doc.data();
            return (data['labId'] ?? '').toString().trim() == labId &&
                (data['consumableInventoryId'] ?? '').toString().trim() ==
                    consumableInventoryId;
          }).toList();

          logs.sort((a, b) {
            final aCreatedAt =
                _readTimestamp(a.data(), 'deliveredAt') ??
                _readTimestamp(a.data(), 'createdAt');
            final bCreatedAt =
                _readTimestamp(b.data(), 'deliveredAt') ??
                _readTimestamp(b.data(), 'createdAt');
            final aDate = aCreatedAt?.toDate() ?? DateTime(2000);
            final bDate = bCreatedAt?.toDate() ?? DateTime(2000);
            return bDate.compareTo(aDate);
          });

          return logs.take(30).toList();
        });
  }

  Future<void> _openStockSheet({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required String action,
    double? currentQuantityOverride,
  }) async {
    final quantityController = TextEditingController();
    final noteController = TextEditingController();
    final isAdding = action == 'added';
    final data = doc.data();
    final consumableType = _readText(data, 'consumableType');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _StockActionSheet(
          title: isAdding ? 'Add Stock' : 'Use Stock',
          actionLabel: isAdding ? 'Add Stock' : 'Use Stock',
          accentColor: isAdding
              ? const Color(0xFF34D399)
              : const Color(0xFFF59E0B),
          quantityController: quantityController,
          noteController: noteController,
          onSubmit: () async {
            final messenger = ScaffoldMessenger.of(context);
            final navigator = Navigator.of(sheetContext);
            final enteredQuantity = double.tryParse(
              quantityController.text.trim(),
            );

            if (enteredQuantity == null || enteredQuantity <= 0) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Enter a quantity greater than 0.'),
                ),
              );
              return;
            }

            try {
              await _applyStockChange(
                doc: doc,
                action: action,
                quantityChanged: enteredQuantity,
                note: noteController.text.trim(),
                currentQuantityOverride: currentQuantityOverride,
              );

              navigator.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    isAdding ? 'Stock added.' : 'Stock usage recorded.',
                  ),
                ),
              );
            } catch (error) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    error.toString().replaceFirst('Exception: ', ''),
                  ),
                ),
              );
            }
          },
          subtitle: consumableType.isEmpty ? 'Consumable' : consumableType,
        );
      },
    ).whenComplete(() {
      quantityController.dispose();
      noteController.dispose();
    });
  }

  Future<void> _applyStockChange({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required String action,
    required double quantityChanged,
    required String note,
    double? currentQuantityOverride,
  }) async {
    final appState = AppState.instance;
    final labId = appState.selectedLabId.trim();
    final userId = appState.authenticatedUserId;
    final actorName = appState.authenticatedUserName;
    final firestore = FirebaseFirestore.instance;
    final logRef = firestore.collection('consumable_stock_logs').doc();
    final timestamp = Timestamp.now();
    late final String consumableType;
    late final double previousQuantity;
    late final double newQuantity;

    await firestore.runTransaction((transaction) async {
      final freshSnapshot = await transaction.get(doc.reference);
      final freshData = freshSnapshot.data();
      if (freshData == null) {
        throw Exception('This consumable no longer exists.');
      }

      final itemLabId = (freshData['labId'] ?? '').toString().trim();
      if (labId.isEmpty || itemLabId != labId) {
        throw Exception('This stock item is not in the selected lab.');
      }

      consumableType = _readText(freshData, 'consumableType');
      final currentQuantityText = _readText(freshData, 'quantity');
      final currentQuantity = _readQuantityNumber(currentQuantityText);
      if (currentQuantity == null && action == 'used') {
        throw Exception('Current quantity must be numeric before using stock.');
      }

      previousQuantity = currentQuantityOverride ?? currentQuantity ?? 0;
      newQuantity = action == 'added'
          ? previousQuantity + quantityChanged
          : previousQuantity - quantityChanged;

      if (newQuantity < 0) {
        throw Exception('Stock cannot go below zero.');
      }

      transaction.update(doc.reference, {
        'quantity': _formatQuantityNumber(newQuantity),
        'isAggregate': true,
        'updatedAt': timestamp,
      });

      transaction.set(logRef, {
        'labId': labId,
        'consumableInventoryId': doc.id,
        'consumableType': consumableType,
        'action': action,
        'quantityChanged': quantityChanged,
        'previousQuantity': previousQuantity,
        'newQuantity': newQuantity,
        'note': note,
        'createdAt': timestamp,
        'createdBy': userId,
        'actorName': actorName,
      });
    });

    final readableName = consumableType.isEmpty ? 'Consumable' : consumableType;
    await ActivityService().addActivity(
      labId: labId,
      type: action == 'added'
          ? 'consumable_stock_added'
          : 'consumable_stock_used',
      message: action == 'added'
          ? 'Added ${_formatQuantityNumber(quantityChanged)} stock to $readableName.'
          : 'Used ${_formatQuantityNumber(quantityChanged)} stock from $readableName.',
      actorName: actorName,
      createdBy: userId,
      relatedId: doc.id,
    );
  }

  Future<void> _applyQuickStockChange({
    required BuildContext context,
    required _ConsumableInventoryItem item,
    required String action,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final quantityText = item.quantityText.trim();
    final currentQuantity = item.numericQuantity;
    final canQuickAdjust = currentQuantity != null || quantityText.isEmpty;

    if (!canQuickAdjust) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Quantity must be numeric before using quick stock actions.',
          ),
        ),
      );
      return;
    }

    try {
      await _applyStockChange(
        doc: item.primaryDoc,
        action: action,
        quantityChanged: 1,
        note: action == 'added' ? 'Quick +1 adjustment' : 'Quick -1 adjustment',
        currentQuantityOverride: currentQuantity,
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text(action == 'added' ? 'Added 1 stock.' : 'Used 1 stock.'),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  void _showItemHistory({
    required BuildContext context,
    required _ConsumableInventoryItem item,
  }) {
    final doc = item.primaryDoc;
    final data = doc.data();
    final labId = _readText(data, 'labId');
    final consumableType = _readText(data, 'consumableType');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _StockHistorySheet(
          title: consumableType.isEmpty ? 'Stock History' : consumableType,
          purchaseLogsStream: _purchaseLogsStream(
            labId: labId,
            consumableInventoryId: doc.id,
          ),
          logsStream: _stockLogsStream(
            labId: labId,
            consumableInventoryId: doc.id,
          ),
          formatDateTime: _formatDateTime,
          formatQuantityNumber: _formatQuantityNumber,
          legacyArrivalDocs: item.sourceDocs,
        );
      },
    );
  }

  void _openCategoryDetails({
    required BuildContext context,
    required _ConsumableCategoryGroup categoryGroup,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ConsumableCategoryDetailScreen(
          categoryGroup: categoryGroup,
          formatQuantityNumber: _formatQuantityNumber,
          variantCardBuilder: (screenContext, variantItem, selectionControl) {
            return _buildVariantCard(
              context: screenContext,
              variantItem: variantItem,
              selectionControl: selectionControl,
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryTile({
    required BuildContext context,
    required _ConsumableCategoryGroup categoryGroup,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final totalQuantityLabel = categoryGroup.totalQuantity == null
        ? 'Mixed'
        : _formatQuantityNumber(categoryGroup.totalQuantity!);

    return Material(
      color: palette.panel,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openCategoryDetails(
          context: context,
          categoryGroup: categoryGroup,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      categoryGroup.category,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: palette.subtleText),
                ],
              ),
              const Spacer(),
              Text(
                '${categoryGroup.variants.length} '
                '${categoryGroup.variants.length == 1 ? 'variant' : 'variants'}',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(label: 'Total: $totalQuantityLabel'),
                  _InfoChip(label: 'Low stock: ${categoryGroup.lowStockCount}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVariantCard({
    required BuildContext context,
    required _ConsumableVariantItem variantItem,
    Widget? selectionControl,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final item = variantItem.item;
    final data = item.primaryDoc.data();
    final quantity = item.quantityText;
    final brand = item.brandLabel;
    final vendor = item.vendorLabel;
    final orderedBy = _readText(data, 'orderedBy');
    final receivedBy = _readText(data, 'receivedBy');
    final modeOfPurchase = _readText(data, 'modeOfPurchase');
    final deliveredAt = _readTimestamp(data, 'deliveredAt');
    final availability = _readAvailability(data);
    final availabilityLabel = _availabilityLabel(availability);
    final isLowStock = availabilityLabel.isNotEmpty || _isLowStock(quantity);
    final stockBadgeLabel = availabilityLabel.isNotEmpty
        ? availabilityLabel
        : 'Low Stock';
    final stockBadgeColor = availabilityLabel.isNotEmpty
        ? _availabilityColor(availability)
        : const Color(0xFFFB7185);
    final brandStatus = brand.isEmpty ? 'Brand not set' : brand;
    final canQuickAdjust =
        item.numericQuantity != null || quantity.trim().isEmpty;
    final canQuickDecrease =
        item.numericQuantity != null && item.numericQuantity! > 0;
    final quickQuantityLabel = quantity.isEmpty ? '0' : quantity;

    return Material(
      color: palette.panel,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showItemHistory(context: context, item: item),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectionControl != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: selectionControl,
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                variantItem.variant,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (variantItem.consumableType.isNotEmpty &&
                                  variantItem.consumableType !=
                                      variantItem.variant) ...[
                                const SizedBox(height: 4),
                                Text(
                                  variantItem.consumableType,
                                  style: TextStyle(
                                    color: palette.subtleText,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (isLowStock)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: stockBadgeColor.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              stockBadgeLabel,
                              style: TextStyle(
                                color: stockBadgeColor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            quantity.isEmpty ? 'Quantity not set' : quantity,
                            style: TextStyle(
                              color: palette.mutedText,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _QuickStockControls(
                          quantityLabel: quickQuantityLabel,
                          onDecrease: canQuickAdjust && canQuickDecrease
                              ? () => _applyQuickStockChange(
                                  context: context,
                                  item: item,
                                  action: 'used',
                                )
                              : null,
                          onIncrease: canQuickAdjust
                              ? () => _applyQuickStockChange(
                                  context: context,
                                  item: item,
                                  action: 'added',
                                )
                              : null,
                        ),
                      ],
                    ),
                    if (!canQuickAdjust) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Quick +/- needs a numeric quantity.',
                        style: TextStyle(
                          color: palette.subtleText,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(label: 'Brand: $brandStatus'),
                        if (vendor.isNotEmpty)
                          _InfoChip(label: 'Vendor: $vendor'),
                        if (modeOfPurchase.isNotEmpty)
                          _InfoChip(label: 'Mode: $modeOfPurchase'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ordered by: ${orderedBy.isEmpty ? '-' : orderedBy}',
                      style: TextStyle(
                        color: palette.subtleText,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Received by: ${receivedBy.isEmpty ? '-' : receivedBy}',
                      style: TextStyle(
                        color: palette.subtleText,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Delivered on: ${_formatDate(deliveredAt)}',
                      style: TextStyle(
                        color: palette.subtleText,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StockActionButton(
                          label: 'Use Stock',
                          icon: Icons.remove_circle_outline_rounded,
                          color: const Color(0xFFF59E0B),
                          onTap: () => _openStockSheet(
                            context: context,
                            doc: item.primaryDoc,
                            action: 'used',
                            currentQuantityOverride: item.numericQuantity,
                          ),
                        ),
                        _StockActionButton(
                          label: 'Add Stock',
                          icon: Icons.add_circle_outline_rounded,
                          color: const Color(0xFF34D399),
                          onTap: () => _openStockSheet(
                            context: context,
                            doc: item.primaryDoc,
                            action: 'added',
                            currentQuantityOverride: item.numericQuantity,
                          ),
                        ),
                        _StockActionButton(
                          label: 'View History',
                          icon: Icons.history_rounded,
                          color: const Color(0xFF38BDF8),
                          onTap: () =>
                              _showItemHistory(context: context, item: item),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;

    return Scaffold(
      appBar: AppBar(title: const Text('Consumables Inventory')),
      body: SafeArea(
        child: ResponsivePageContainer(
          child:
              StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                stream: _inventoryStream(),
                builder: (context, snapshot) {
                  if (!FirestoreAccessGuard.shouldQueryLabScopedData()) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          FirestoreAccessGuard.userMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.mutedText,
                            height: 1.4,
                          ),
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          FirestoreAccessGuard.messageFor(snapshot.error),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.mutedText,
                            height: 1.4,
                          ),
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = _sortDocs(snapshot.data!);
                  final items = _groupDocs(docs);
                  final categoryGroups = _groupItemsByCategory(items);

                  if (categoryGroups.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No consumables have been added yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: palette.mutedText),
                        ),
                      ),
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 980
                          ? 4
                          : constraints.maxWidth >= 720
                          ? 3
                          : 2;

                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: constraints.maxWidth >= 720
                              ? 1.35
                              : 1.2,
                        ),
                        itemCount: categoryGroups.length,
                        itemBuilder: (context, index) {
                          return _buildCategoryTile(
                            context: context,
                            categoryGroup: categoryGroups[index],
                          );
                        },
                      );
                    },
                  );
                },
              ),
        ),
      ),
    );
  }
}

class _ConsumableInventoryItem {
  final QueryDocumentSnapshot<Map<String, dynamic>> primaryDoc;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> sourceDocs;
  final String quantityText;
  final double? numericQuantity;
  final String brandLabel;
  final String vendorLabel;

  const _ConsumableInventoryItem({
    required this.primaryDoc,
    required this.sourceDocs,
    required this.quantityText,
    required this.numericQuantity,
    required this.brandLabel,
    required this.vendorLabel,
  });
}

class _ConsumableTypeParts {
  final String category;
  final String variant;

  const _ConsumableTypeParts({required this.category, required this.variant});
}

class _ConsumableVariantItem {
  final _ConsumableInventoryItem item;
  final String variant;
  final String consumableType;

  const _ConsumableVariantItem({
    required this.item,
    required this.variant,
    required this.consumableType,
  });
}

class _ConsumableCategoryGroup {
  final String category;
  final List<_ConsumableVariantItem> variants;
  final double? totalQuantity;
  final int lowStockCount;

  const _ConsumableCategoryGroup({
    required this.category,
    required this.variants,
    required this.totalQuantity,
    required this.lowStockCount,
  });
}

class _ConsumableCategoryDetailScreen extends StatefulWidget {
  final _ConsumableCategoryGroup categoryGroup;
  final String Function(double) formatQuantityNumber;
  final Widget Function(BuildContext, _ConsumableVariantItem, Widget?)
  variantCardBuilder;

  const _ConsumableCategoryDetailScreen({
    required this.categoryGroup,
    required this.formatQuantityNumber,
    required this.variantCardBuilder,
  });

  @override
  State<_ConsumableCategoryDetailScreen> createState() =>
      _ConsumableCategoryDetailScreenState();
}

class _ConsumableCategoryDetailScreenState
    extends State<_ConsumableCategoryDetailScreen> {
  final ValueNotifier<Set<String>> selectedConsumableIdsNotifier =
      ValueNotifier<Set<String>>(<String>{});
  final ConsumablesInventoryService _consumablesInventoryService =
      ConsumablesInventoryService();
  bool selectionMode = false;
  bool isExportingSelectedCsv = false;
  bool showSelectedOnly = false;

  static const List<String> _locationOptions = [
    'Store Room',
    'Shelf',
    'Drawer',
    'Bench',
    'Refrigerator',
    'Freezer',
    'Desiccator',
    'Other',
  ];

  Set<String> get selectedConsumableIds => selectedConsumableIdsNotifier.value;

  @override
  void dispose() {
    selectedConsumableIdsNotifier.dispose();
    super.dispose();
  }

  String _consumableId(_ConsumableVariantItem variantItem) {
    return variantItem.item.primaryDoc.id;
  }

  List<String> _visibleConsumableIds(List<_ConsumableVariantItem> variants) {
    return variants
        .map(_consumableId)
        .where((id) => id.trim().isNotEmpty)
        .toList();
  }

  void _toggleConsumableSelection(String consumableId, bool? selected) {
    if (consumableId.trim().isEmpty) return;

    final nextSelection = <String>{...selectedConsumableIdsNotifier.value};

    if (selected == true) {
      nextSelection.add(consumableId);
    } else {
      nextSelection.remove(consumableId);
    }

    selectedConsumableIdsNotifier.value = nextSelection;

    if (showSelectedOnly) {
      setState(() {
        showSelectedOnly = nextSelection.isNotEmpty;
      });
    }
  }

  void _selectAllVisibleConsumables(List<_ConsumableVariantItem> variants) {
    if (!selectionMode) return;

    final visibleIds = _visibleConsumableIds(variants);
    if (visibleIds.isEmpty) return;

    selectedConsumableIdsNotifier.value = <String>{
      ...selectedConsumableIdsNotifier.value,
      ...visibleIds,
    };

    if (showSelectedOnly) {
      setState(() {});
    }
  }

  void _enterSelectionMode() {
    if (selectionMode) return;

    setState(() {
      selectionMode = true;
    });
  }

  void _exitSelectionModeState() {
    selectionMode = false;
    selectedConsumableIdsNotifier.value = <String>{};
    showSelectedOnly = false;
  }

  void _exitSelectionMode() {
    setState(_exitSelectionModeState);
  }

  void _showBulkActionComingNext(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action bulk action is coming next.')),
    );
  }

  List<String> _selectedVisibleConsumableIds(
    List<_ConsumableVariantItem> variants,
  ) {
    final visibleIds = _visibleConsumableIds(variants).toSet();
    return selectedConsumableIds
        .where((id) => visibleIds.contains(id))
        .toSet()
        .toList();
  }

  List<_ConsumableVariantItem> _selectedVisibleConsumables(
    List<_ConsumableVariantItem> variants,
  ) {
    final selectedIds = _selectedVisibleConsumableIds(variants).toSet();
    return variants.where((variant) {
      return selectedIds.contains(_consumableId(variant));
    }).toList();
  }

  String _readExportText(Map<String, dynamic> data, String key) {
    return (data[key] ?? '').toString().trim();
  }

  Timestamp? _readExportTimestamp(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is Timestamp ? value : null;
  }

  String _availabilityForExport(_ConsumableVariantItem variant) {
    final data = variant.item.primaryDoc.data();
    final availability = _readExportText(data, 'availability');
    if (availability.isNotEmpty) return availability;

    final status = _readExportText(data, 'status');
    if (status.isNotEmpty) return status;

    final quantity = variant.item.numericQuantity;
    if (quantity != null && quantity <= 2) return 'Low';
    return 'Available';
  }

  String _unitForExport(_ConsumableVariantItem variant) {
    final data = variant.item.primaryDoc.data();
    final unit = _readExportText(data, 'unit');
    if (unit.isNotEmpty) return unit;

    final quantity = variant.item.quantityText.trim();
    final match = RegExp(r'[-+]?\d*\.?\d+\s*(.*)$').firstMatch(quantity);
    return (match?.group(1) ?? '').trim();
  }

  String _lastUpdatedForExport(_ConsumableVariantItem variant) {
    final data = variant.item.primaryDoc.data();
    final timestamp =
        _readExportTimestamp(data, 'updatedAt') ??
        _readExportTimestamp(data, 'deliveredAt') ??
        _readExportTimestamp(data, 'createdAt');

    return timestamp?.toDate().toIso8601String() ?? '';
  }

  Future<void> _exportSelectedVisibleCsv(
    List<_ConsumableVariantItem> visibleVariants,
  ) async {
    final selectedVariants = _selectedVisibleConsumables(visibleVariants);

    if (selectedVariants.isEmpty) {
      _showBulkActionComingNext('Export CSV');
      return;
    }

    setState(() {
      isExportingSelectedCsv = true;
    });

    try {
      final rows = <List<String>>[
        const [
          'Name',
          'Category',
          'Specification/Size',
          'Brand',
          'Quantity',
          'Unit',
          'Location',
          'Availability',
          'Last Updated',
        ],
        ...selectedVariants.map((variant) {
          final data = variant.item.primaryDoc.data();
          final name = variant.consumableType.trim().isEmpty
              ? variant.variant
              : variant.consumableType;

          return [
            name,
            widget.categoryGroup.category,
            variant.variant,
            variant.item.brandLabel,
            variant.item.quantityText,
            _unitForExport(variant),
            _readExportText(data, 'location'),
            _availabilityForExport(variant),
            _lastUpdatedForExport(variant),
          ];
        }),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final fileName = _selectedCsvFileName();
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save selected consumables inventory',
        fileName: fileName,
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedPath == null
                ? 'Export cancelled.'
                : 'Exported ${selectedVariants.length} selected item(s).',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not export selected consumables: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isExportingSelectedCsv = false;
        });
      }
    }
  }

  String _selectedCsvFileName() {
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

    return 'labmate_consumables_inventory_selected_${date}_$time.csv';
  }

  Future<void> _openBulkChangeLocationDialog(
    List<_ConsumableVariantItem> visibleVariants,
  ) async {
    final targetIds = _selectedVisibleConsumableIds(visibleVariants);

    if (targetIds.isEmpty) {
      _showBulkActionComingNext('Change location');
      return;
    }

    final selectedLocation = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? location;
        bool showValidationError = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final palette = dialogContext.labmate;
            final colorScheme = dialogContext.colorScheme;

            return AlertDialog(
              backgroundColor: palette.panel,
              title: Text(
                'Change location',
                style: TextStyle(color: colorScheme.onSurface),
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${targetIds.length} selected',
                      style: const TextStyle(
                        color: Color(0xFF7DD3FC),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: location,
                      dropdownColor: palette.panel,
                      decoration: InputDecoration(
                        labelText: 'Location',
                        labelStyle: TextStyle(color: palette.mutedText),
                        errorText: showValidationError
                            ? 'Select a location before applying.'
                            : null,
                        filled: true,
                        fillColor: palette.panelAlt,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: palette.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.redAccent),
                        ),
                      ),
                      iconEnabledColor: palette.mutedText,
                      style: TextStyle(color: colorScheme.onSurface),
                      items: _locationOptions.map((locationOption) {
                        return DropdownMenuItem<String>(
                          value: locationOption,
                          child: Text(
                            locationOption,
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          location = value;
                          showValidationError = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (location == null || location!.trim().isEmpty) {
                      setDialogState(() {
                        showValidationError = true;
                      });
                      return;
                    }

                    Navigator.of(dialogContext).pop(location);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF0F172A),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedLocation == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _consumablesInventoryService.updateLocationsByIds(
        docIds: targetIds,
        location: selectedLocation,
      );

      if (!mounted) return;
      setState(_exitSelectionModeState);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Location updated for ${targetIds.length} item(s).'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _confirmBulkAvailabilityUpdate({
    required List<_ConsumableVariantItem> visibleVariants,
    required String availability,
    required String title,
    required String confirmLabel,
    required String successLabel,
  }) async {
    final targetIds = _selectedVisibleConsumableIds(visibleVariants);

    if (targetIds.isEmpty) {
      _showBulkActionComingNext(confirmLabel);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final palette = dialogContext.labmate;
        final colorScheme = dialogContext.colorScheme;

        return AlertDialog(
          backgroundColor: palette.panel,
          title: Text(title, style: TextStyle(color: colorScheme.onSurface)),
          content: SizedBox(
            width: 360,
            child: Text(
              '${targetIds.length} selected',
              style: const TextStyle(
                color: Color(0xFF7DD3FC),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF0F172A),
              ),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _consumablesInventoryService.updateAvailabilityByIds(
        docIds: targetIds,
        availability: availability,
      );

      if (!mounted) return;
      setState(_exitSelectionModeState);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Marked ${targetIds.length} item(s) as $successLabel.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Widget _buildBulkSelectionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final palette = context.labmate;

    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.mutedText,
          disabledForegroundColor: palette.subtleText.withOpacity(0.55),
          side: BorderSide(color: palette.border),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedOnlyToggle() {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return SizedBox(
      height: 36,
      child: FilterChip(
        selected: showSelectedOnly,
        onSelected: (selected) {
          setState(() {
            showSelectedOnly = selected;
          });
        },
        avatar: Icon(
          showSelectedOnly
              ? Icons.filter_alt_rounded
              : Icons.filter_alt_outlined,
          size: 16,
          color: showSelectedOnly ? colorScheme.primary : palette.mutedText,
        ),
        label: const Text('Selected only'),
        selectedColor: palette.selected,
        backgroundColor: palette.panel,
        labelStyle: TextStyle(
          color: showSelectedOnly ? colorScheme.primary : palette.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        side: BorderSide(color: palette.border),
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildConsumableBulkToolbar(
    List<_ConsumableVariantItem> visibleVariants,
  ) {
    if (!selectionMode) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildBulkSelectionButton(
            label: 'Select',
            icon: Icons.check_box_outlined,
            onPressed: _enterSelectionMode,
          ),
        ),
      );
    }

    return ValueListenableBuilder<Set<String>>(
      valueListenable: selectedConsumableIdsNotifier,
      builder: (context, selectedIds, _) {
        final palette = context.labmate;
        final colorScheme = context.colorScheme;
        final selectedCount = selectedIds.length;
        final visibleIds = _visibleConsumableIds(visibleVariants).toSet();
        final selectedVisibleCount = selectedIds
            .where((id) => visibleIds.contains(id))
            .length;
        final visibleCount = visibleVariants.length;
        final selectionSummary = selectedVisibleCount == selectedCount
            ? '$selectedCount selected from $visibleCount visible'
            : '$selectedCount selected, $visibleCount visible';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: palette.panelAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selectedCount == 0
                        ? palette.panel
                        : palette.selected,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    selectedCount == 0
                        ? 'Select items to bulk edit'
                        : selectionSummary,
                    style: TextStyle(
                      color: selectedCount == 0
                          ? palette.mutedText
                          : colorScheme.primary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (selectedCount > 0) ...[
                  _buildSelectedOnlyToggle(),
                  const SizedBox(width: 8),
                ],
                _buildBulkSelectionButton(
                  label: 'Select all visible',
                  icon: Icons.select_all_rounded,
                  onPressed: () =>
                      _selectAllVisibleConsumables(visibleVariants),
                ),
                const SizedBox(width: 8),
                _buildBulkSelectionButton(
                  label: selectedCount == 0 ? 'Cancel' : 'Clear',
                  icon: Icons.close_rounded,
                  onPressed: _exitSelectionMode,
                ),
                if (selectedCount > 0) ...[
                  const SizedBox(width: 14),
                  _buildBulkSelectionButton(
                    label: 'Change location',
                    icon: Icons.place_outlined,
                    onPressed: () =>
                        _openBulkChangeLocationDialog(visibleVariants),
                  ),
                  const SizedBox(width: 8),
                  _buildBulkSelectionButton(
                    label: 'Mark low',
                    icon: Icons.warning_amber_rounded,
                    onPressed: () => _confirmBulkAvailabilityUpdate(
                      visibleVariants: visibleVariants,
                      availability: 'low',
                      title: 'Mark selected as low?',
                      confirmLabel: 'Mark Low',
                      successLabel: 'low',
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildBulkSelectionButton(
                    label: 'Mark finished',
                    icon: Icons.cancel_outlined,
                    onPressed: () => _confirmBulkAvailabilityUpdate(
                      visibleVariants: visibleVariants,
                      availability: 'finished',
                      title: 'Mark selected as finished?',
                      confirmLabel: 'Mark Finished',
                      successLabel: 'finished',
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildBulkSelectionButton(
                    label: isExportingSelectedCsv
                        ? 'Exporting...'
                        : 'Export CSV',
                    icon: Icons.file_download_outlined,
                    onPressed: isExportingSelectedCsv
                        ? null
                        : () => _exportSelectedVisibleCsv(visibleVariants),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConsumableSelectionCheckbox(String consumableId) {
    final palette = context.labmate;

    return ValueListenableBuilder<Set<String>>(
      valueListenable: selectedConsumableIdsNotifier,
      builder: (context, selectedIds, _) {
        final isSelected = selectedIds.contains(consumableId);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _toggleConsumableSelection(consumableId, !isSelected),
          child: AbsorbPointer(
            child: Checkbox(
              value: isSelected,
              onChanged: (_) {},
              activeColor: const Color(0xFF38BDF8),
              checkColor: Colors.white,
              side: BorderSide(color: palette.subtleText),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalQuantityLabel = widget.categoryGroup.totalQuantity == null
        ? 'Mixed'
        : widget.formatQuantityNumber(widget.categoryGroup.totalQuantity!);
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final palette = context.labmate;
    final visibleVariants = widget.categoryGroup.variants;
    final displayedVariants = isDesktop && selectionMode && showSelectedOnly
        ? _selectedVisibleConsumables(visibleVariants)
        : visibleVariants;

    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryGroup.category)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.panel,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.border),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    label:
                        '${widget.categoryGroup.variants.length} ${widget.categoryGroup.variants.length == 1 ? 'variant' : 'variants'}',
                  ),
                  _InfoChip(label: 'Total: $totalQuantityLabel'),
                  _InfoChip(
                    label: 'Low stock: ${widget.categoryGroup.lowStockCount}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (isDesktop) _buildConsumableBulkToolbar(visibleVariants),
            if (displayedVariants.isEmpty && showSelectedOnly)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: palette.panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  'No selected records are visible.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.mutedText),
                ),
              )
            else
              ...displayedVariants.map((variant) {
                final consumableId = _consumableId(variant);

                return Padding(
                  key: ValueKey(consumableId),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: widget.variantCardBuilder(
                    context,
                    variant,
                    isDesktop && selectionMode
                        ? _buildConsumableSelectionCheckbox(consumableId)
                        : null,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StockActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StockActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _QuickStockControls extends StatelessWidget {
  final String quantityLabel;
  final Future<void> Function()? onDecrease;
  final Future<void> Function()? onIncrease;

  const _QuickStockControls({
    required this.quantityLabel,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;

    return Container(
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QuickStockIconButton(
            icon: Icons.remove_rounded,
            color: const Color(0xFFF59E0B),
            onPressed: onDecrease,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 64, maxWidth: 116),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                quantityLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colorScheme.onSurface,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          _QuickStockIconButton(
            icon: Icons.add_rounded,
            color: const Color(0xFF34D399),
            onPressed: onIncrease,
          ),
        ],
      ),
    );
  }
}

class _QuickStockIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Future<void> Function()? onPressed;

  const _QuickStockIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    return IconButton(
      onPressed: isEnabled ? () => onPressed!() : null,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      padding: EdgeInsets.zero,
      splashRadius: 18,
      iconSize: 18,
      color: isEnabled ? color : Colors.white24,
      disabledColor: Colors.white24,
      icon: Icon(icon),
    );
  }
}

class _StockActionSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final Color accentColor;
  final TextEditingController quantityController;
  final TextEditingController noteController;
  final Future<void> Function() onSubmit;

  const _StockActionSheet({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.accentColor,
    required this.quantityController,
    required this.noteController,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: palette.subtleText, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(color: colorScheme.onSurface),
                decoration: _inputDecoration(context, 'Quantity'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                minLines: 2,
                maxLines: 3,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: _inputDecoration(context, 'Note (optional)'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(actionLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String label) {
    final palette = context.labmate;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: palette.subtleText),
      filled: true,
      fillColor: palette.panelAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.border),
      ),
    );
  }
}

class _StockHistorySheet extends StatelessWidget {
  final String title;
  final Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  purchaseLogsStream;
  final Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> logsStream;
  final String Function(Timestamp?) formatDateTime;
  final String Function(double) formatQuantityNumber;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> legacyArrivalDocs;

  const _StockHistorySheet({
    required this.title,
    required this.purchaseLogsStream,
    required this.logsStream,
    required this.formatDateTime,
    required this.formatQuantityNumber,
    required this.legacyArrivalDocs,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            decoration: BoxDecoration(
              color: palette.panel,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Stock History · $title',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: palette.mutedText),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child:
                      StreamBuilder<
                        List<QueryDocumentSnapshot<Map<String, dynamic>>>
                      >(
                        stream: purchaseLogsStream,
                        builder: (context, purchaseSnapshot) {
                          return StreamBuilder<
                            List<QueryDocumentSnapshot<Map<String, dynamic>>>
                          >(
                            stream: logsStream,
                            builder: (context, stockSnapshot) {
                              if (purchaseSnapshot.hasError ||
                                  stockSnapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Unable to load item history.',
                                    style: TextStyle(color: palette.mutedText),
                                  ),
                                );
                              }

                              if (!purchaseSnapshot.hasData ||
                                  !stockSnapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final purchaseLogs = purchaseSnapshot.data!;
                              final stockLogs = stockSnapshot.data!;
                              final legacyArrivals = purchaseLogs.isEmpty
                                  ? legacyArrivalDocs
                                  : const <
                                      QueryDocumentSnapshot<
                                        Map<String, dynamic>
                                      >
                                    >[];
                              if (purchaseLogs.isEmpty &&
                                  stockLogs.isEmpty &&
                                  legacyArrivals.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No history recorded yet.',
                                    style: TextStyle(color: palette.mutedText),
                                  ),
                                );
                              }

                              return ListView(
                                controller: scrollController,
                                children: [
                                  if (purchaseLogs.isNotEmpty ||
                                      legacyArrivals.isNotEmpty) ...[
                                    const _HistorySectionTitle(
                                      title: 'Purchase / Arrival History',
                                    ),
                                    const SizedBox(height: 8),
                                    if (purchaseLogs.isNotEmpty)
                                      ...purchaseLogs.map(
                                        (doc) => _PurchaseHistoryCard(
                                          data: doc.data(),
                                          formatDateTime: formatDateTime,
                                          formatQuantityNumber:
                                              formatQuantityNumber,
                                        ),
                                      )
                                    else
                                      ...legacyArrivals.map(
                                        (doc) => _LegacyArrivalCard(
                                          data: doc.data(),
                                          formatDateTime: formatDateTime,
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                  ],
                                  if (stockLogs.isNotEmpty) ...[
                                    const _HistorySectionTitle(
                                      title: 'Stock In / Out History',
                                    ),
                                    const SizedBox(height: 8),
                                    ...stockLogs.map(
                                      (doc) => _StockHistoryCard(
                                        data: doc.data(),
                                        formatDateTime: formatDateTime,
                                        formatQuantityNumber:
                                            formatQuantityNumber,
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          );
                        },
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HistorySectionTitle extends StatelessWidget {
  final String title;

  const _HistorySectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Text(
      title,
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _PurchaseHistoryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String Function(Timestamp?) formatDateTime;
  final String Function(double) formatQuantityNumber;

  const _PurchaseHistoryCard({
    required this.data,
    required this.formatDateTime,
    required this.formatQuantityNumber,
  });

  String _readText(String key) {
    return (data[key] ?? '').toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final quantityAdded = (data['quantityAdded'] as num?)?.toDouble() ?? 0;
    final previousQuantity =
        (data['previousQuantity'] as num?)?.toDouble() ?? 0;
    final newQuantity = (data['newQuantity'] as num?)?.toDouble() ?? 0;
    final deliveredAt = data['deliveredAt'] is Timestamp
        ? data['deliveredAt'] as Timestamp
        : null;
    final brand = _readText('brand');
    final vendor = _readText('vendor');
    final modeOfPurchase = _readText('modeOfPurchase');
    final receivedBy = _readText('receivedBy');

    return _HistoryCardFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFF38BDF8),
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Arrival +${formatQuantityNumber(quantityAdded)}',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                formatDateTime(deliveredAt),
                style: TextStyle(color: palette.subtleText, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${formatQuantityNumber(previousQuantity)} -> '
            '${formatQuantityNumber(newQuantity)}',
            style: TextStyle(color: palette.mutedText, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (brand.isNotEmpty) _InfoChip(label: 'Brand: $brand'),
              if (vendor.isNotEmpty) _InfoChip(label: 'Vendor: $vendor'),
              if (modeOfPurchase.isNotEmpty)
                _InfoChip(label: 'Mode: $modeOfPurchase'),
              if (receivedBy.isNotEmpty) _InfoChip(label: 'By: $receivedBy'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegacyArrivalCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String Function(Timestamp?) formatDateTime;

  const _LegacyArrivalCard({required this.data, required this.formatDateTime});

  String _readText(String key) {
    return (data[key] ?? '').toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final quantity = _readText('quantity');
    final brand = _readText('brand');
    final vendor = _readText('vendor');
    final modeOfPurchase = _readText('modeOfPurchase');
    final receivedBy = _readText('receivedBy');
    final deliveredAt = data['deliveredAt'] is Timestamp
        ? data['deliveredAt'] as Timestamp
        : null;

    return _HistoryCardFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFF38BDF8),
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  quantity.isEmpty ? 'Arrival' : 'Arrival +$quantity',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                formatDateTime(deliveredAt),
                style: TextStyle(color: palette.subtleText, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (brand.isNotEmpty) _InfoChip(label: 'Brand: $brand'),
              if (vendor.isNotEmpty) _InfoChip(label: 'Vendor: $vendor'),
              if (modeOfPurchase.isNotEmpty)
                _InfoChip(label: 'Mode: $modeOfPurchase'),
              if (receivedBy.isNotEmpty) _InfoChip(label: 'By: $receivedBy'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StockHistoryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String Function(Timestamp?) formatDateTime;
  final String Function(double) formatQuantityNumber;

  const _StockHistoryCard({
    required this.data,
    required this.formatDateTime,
    required this.formatQuantityNumber,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final action = (data['action'] ?? '').toString().trim();
    final quantityChanged = (data['quantityChanged'] as num?)?.toDouble() ?? 0;
    final previousQuantity =
        (data['previousQuantity'] as num?)?.toDouble() ?? 0;
    final newQuantity = (data['newQuantity'] as num?)?.toDouble() ?? 0;
    final note = (data['note'] ?? '').toString().trim();
    final actorName = (data['actorName'] ?? '').toString().trim();
    final createdAt = data['createdAt'] is Timestamp
        ? data['createdAt'] as Timestamp
        : null;
    final isAdded = action == 'added';

    return _HistoryCardFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAdded
                    ? Icons.add_circle_outline_rounded
                    : Icons.remove_circle_outline_rounded,
                color: isAdded
                    ? const Color(0xFF34D399)
                    : const Color(0xFFF59E0B),
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isAdded ? 'Stock added' : 'Stock used',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                formatDateTime(createdAt),
                style: TextStyle(color: palette.subtleText, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${formatQuantityNumber(quantityChanged)} changed - '
            '${formatQuantityNumber(previousQuantity)} -> '
            '${formatQuantityNumber(newQuantity)}',
            style: TextStyle(color: palette.mutedText, fontSize: 12.5),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              note,
              style: TextStyle(color: palette.subtleText, fontSize: 12.5),
            ),
          ],
          if (actorName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'By $actorName',
              style: TextStyle(color: palette.subtleText, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryCardFrame extends StatelessWidget {
  final Widget child;

  const _HistoryCardFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: child,
    );
  }
}
