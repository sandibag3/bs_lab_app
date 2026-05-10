import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/activity_service.dart';
import '../services/consumables_inventory_service.dart';
import '../services/firestore_access_guard.dart';

class ConsumablesInventoryScreen extends StatelessWidget {
  const ConsumablesInventoryScreen({super.key});

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
      return const _ConsumableTypeParts(
        category: 'Others',
        variant: 'Unnamed',
      );
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
      return _mapTypeWithSuffix(
        originalType: cleanType,
        category: 'Gloves',
      );
    }

    if (normalized.startsWith('syringe')) {
      return _mapTypeWithSuffix(
        originalType: cleanType,
        category: 'Syringes',
      );
    }

    if (normalized.startsWith('balloon') || normalized.contains('balloon')) {
      return _mapTypeWithSuffix(
        originalType: cleanType,
        category: 'Balloons',
      );
    }

    if (normalized.startsWith('needle') || normalized.contains('needle')) {
      return _mapTypeWithSuffix(
        originalType: cleanType,
        category: 'Needles',
      );
    }

    if (normalized.contains('filter paper')) {
      return _mapTypeWithSuffix(
        originalType: cleanType,
        category: 'Filter Paper',
      );
    }

    if (normalized.startsWith('silica') || normalized.contains('silica')) {
      return _mapTypeWithSuffix(
        originalType: cleanType,
        category: 'Silica',
      );
    }

    if (normalized.startsWith('cotton') || normalized.contains('cotton')) {
      return _mapTypeWithSuffix(
        originalType: cleanType,
        category: 'Cotton',
      );
    }

    if (normalized.contains('rubber band')) {
      return _mapTypeWithSuffix(
        originalType: cleanType,
        category: 'Rubber Band',
      );
    }

    if (normalized.startsWith('tube') || normalized.contains('tube')) {
      return _mapTypeWithSuffix(
        originalType: cleanType,
        category: 'Tubes',
      );
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
      return _mapTypeWithSuffix(
        originalType: cleanType,
        category: 'Grease',
      );
    }

    if (normalized.startsWith('teflon') || normalized.contains('teflon')) {
      return _mapTypeWithSuffix(
        originalType: cleanType,
        category: 'Teflon',
      );
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

      grouped.putIfAbsent(parsedType.category, () => []).add(
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
          content: Text(
            action == 'added' ? 'Added 1 stock.' : 'Used 1 stock.',
          ),
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
          variantCardBuilder: (screenContext, variantItem) {
            return _buildVariantCard(
              context: screenContext,
              variantItem: variantItem,
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
    final totalQuantityLabel = categoryGroup.totalQuantity == null
        ? 'Mixed'
        : _formatQuantityNumber(categoryGroup.totalQuantity!);

    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () =>
            _openCategoryDetails(context: context, categoryGroup: categoryGroup),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white38,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${categoryGroup.variants.length} '
                '${categoryGroup.variants.length == 1 ? 'variant' : 'variants'}',
                style: const TextStyle(
                  color: Colors.white70,
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
  }) {
    final item = variantItem.item;
    final data = item.primaryDoc.data();
    final quantity = item.quantityText;
    final brand = item.brandLabel;
    final vendor = item.vendorLabel;
    final orderedBy = _readText(data, 'orderedBy');
    final receivedBy = _readText(data, 'receivedBy');
    final modeOfPurchase = _readText(data, 'modeOfPurchase');
    final deliveredAt = _readTimestamp(data, 'deliveredAt');
    final isLowStock = _isLowStock(quantity);
    final brandStatus = brand.isEmpty ? 'Brand not set' : brand;
    final canQuickAdjust = item.numericQuantity != null || quantity.trim().isEmpty;
    final canQuickDecrease =
        item.numericQuantity != null && item.numericQuantity! > 0;
    final quickQuantityLabel = quantity.isEmpty ? '0' : quantity;

    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showItemHistory(context: context, item: item),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (variantItem.consumableType.isNotEmpty &&
                            variantItem.consumableType != variantItem.variant) ...[
                          const SizedBox(height: 4),
                          Text(
                            variantItem.consumableType,
                            style: const TextStyle(
                              color: Colors.white54,
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
                        color: const Color(0x22FB7185),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Low Stock',
                        style: TextStyle(
                          color: Color(0xFFFB7185),
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
                      style: const TextStyle(
                        color: Colors.white70,
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
                const Text(
                  'Quick +/- needs a numeric quantity.',
                  style: TextStyle(
                    color: Colors.white38,
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
                  if (vendor.isNotEmpty) _InfoChip(label: 'Vendor: $vendor'),
                  if (modeOfPurchase.isNotEmpty)
                    _InfoChip(label: 'Mode: $modeOfPurchase'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Ordered by: ${orderedBy.isEmpty ? '-' : orderedBy}',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Received by: ${receivedBy.isEmpty ? '-' : receivedBy}',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Delivered on: ${_formatDate(deliveredAt)}',
                style: const TextStyle(
                  color: Colors.white60,
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
                    onTap: () => _showItemHistory(
                      context: context,
                      item: item,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Consumables Inventory',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: _inventoryStream(),
          builder: (context, snapshot) {
            if (!FirestoreAccessGuard.shouldQueryLabScopedData()) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    FirestoreAccessGuard.userMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, height: 1.4),
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
                    style: const TextStyle(color: Colors.white70, height: 1.4),
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
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No consumables have been added yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
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
                    childAspectRatio: constraints.maxWidth >= 720 ? 1.35 : 1.2,
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

  const _ConsumableTypeParts({
    required this.category,
    required this.variant,
  });
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

class _ConsumableCategoryDetailScreen extends StatelessWidget {
  final _ConsumableCategoryGroup categoryGroup;
  final String Function(double) formatQuantityNumber;
  final Widget Function(BuildContext, _ConsumableVariantItem) variantCardBuilder;

  const _ConsumableCategoryDetailScreen({
    required this.categoryGroup,
    required this.formatQuantityNumber,
    required this.variantCardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final totalQuantityLabel = categoryGroup.totalQuantity == null
        ? 'Mixed'
        : formatQuantityNumber(categoryGroup.totalQuantity!);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          categoryGroup.category,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    label:
                        '${categoryGroup.variants.length} ${categoryGroup.variants.length == 1 ? 'variant' : 'variants'}',
                  ),
                  _InfoChip(label: 'Total: $totalQuantityLabel'),
                  _InfoChip(label: 'Low stock: ${categoryGroup.lowStockCount}'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...categoryGroup.variants.map((variant) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: variantCardBuilder(context, variant),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                style: const TextStyle(
                  color: Colors.white,
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

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white60, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Quantity'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                minLines: 2,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Note (optional)'),
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
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
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            decoration: const BoxDecoration(
              color: Color(0xFF111827),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
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
                                return const Center(
                                  child: Text(
                                    'Unable to load item history.',
                                    style: TextStyle(color: Colors.white70),
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
                                return const Center(
                                  child: Text(
                                    'No history recorded yet.',
                                    style: TextStyle(color: Colors.white70),
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
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                formatDateTime(deliveredAt),
                style: const TextStyle(color: Colors.white54, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${formatQuantityNumber(previousQuantity)} -> '
            '${formatQuantityNumber(newQuantity)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                formatDateTime(deliveredAt),
                style: const TextStyle(color: Colors.white54, fontSize: 11.5),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                formatDateTime(createdAt),
                style: const TextStyle(color: Colors.white54, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${formatQuantityNumber(quantityChanged)} changed - '
            '${formatQuantityNumber(previousQuantity)} -> '
            '${formatQuantityNumber(newQuantity)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              note,
              style: const TextStyle(color: Colors.white60, fontSize: 12.5),
            ),
          ],
          if (actorName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'By $actorName',
              style: const TextStyle(color: Colors.white38, fontSize: 11.5),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
