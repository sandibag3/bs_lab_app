import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/activity_service.dart';

class ConsumablesInventoryScreen extends StatelessWidget {
  const ConsumablesInventoryScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _inventoryStream() {
    return FirebaseFirestore.instance
        .collection('consumables_inventory')
        .snapshots();
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

  bool _matchesCurrentLab(Map<String, dynamic> data) {
    final labId = (data['labId'] ?? '').toString().trim();
    return AppState.instance.matchesSelectedLabId(labId);
  }

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

  Future<void> _openStockSheet({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required String action,
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

      previousQuantity = currentQuantity ?? 0;
      newQuantity = action == 'added'
          ? previousQuantity + quantityChanged
          : previousQuantity - quantityChanged;

      if (newQuantity < 0) {
        throw Exception('Stock cannot go below zero.');
      }

      transaction.update(doc.reference, {
        'quantity': _formatQuantityNumber(newQuantity),
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

  void _showStockHistory({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) {
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
          logsStream: _stockLogsStream(
            labId: labId,
            consumableInventoryId: doc.id,
          ),
          formatDateTime: _formatDateTime,
          formatQuantityNumber: _formatQuantityNumber,
        );
      },
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
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _inventoryStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Unable to load consumables inventory right now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = _sortDocs(
              snapshot.data!.docs
                  .where((doc) => _matchesCurrentLab(doc.data()))
                  .toList(),
            );

            if (docs.isEmpty) {
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

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final consumableType = _readText(data, 'consumableType');
                final quantity = _readText(data, 'quantity');
                final brand = _readText(data, 'brand');
                final vendor = _readText(data, 'vendor');
                final orderedBy = _readText(data, 'orderedBy');
                final receivedBy = _readText(data, 'receivedBy');
                final modeOfPurchase = _readText(data, 'modeOfPurchase');
                final deliveredAt = _readTimestamp(data, 'deliveredAt');
                final isLowStock = _isLowStock(quantity);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              consumableType.isEmpty
                                  ? 'Consumable'
                                  : consumableType,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x2238BDF8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Consumable',
                              style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isLowStock) ...[
                            const SizedBox(width: 8),
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
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        quantity.isEmpty ? 'Quantity not set' : quantity,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (brand.isNotEmpty)
                            _InfoChip(label: 'Brand: $brand'),
                          if (vendor.isNotEmpty)
                            _InfoChip(label: 'Vendor: $vendor'),
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
                              doc: docs[index],
                              action: 'used',
                            ),
                          ),
                          _StockActionButton(
                            label: 'Add Stock',
                            icon: Icons.add_circle_outline_rounded,
                            color: const Color(0xFF34D399),
                            onTap: () => _openStockSheet(
                              context: context,
                              doc: docs[index],
                              action: 'added',
                            ),
                          ),
                          _StockActionButton(
                            label: 'View History',
                            icon: Icons.history_rounded,
                            color: const Color(0xFF38BDF8),
                            onTap: () => _showStockHistory(
                              context: context,
                              doc: docs[index],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
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
  final Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> logsStream;
  final String Function(Timestamp?) formatDateTime;
  final String Function(double) formatQuantityNumber;

  const _StockHistorySheet({
    required this.title,
    required this.logsStream,
    required this.formatDateTime,
    required this.formatQuantityNumber,
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
                  child: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                    stream: logsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'Unable to load stock history.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final logs = snapshot.data!;
                      if (logs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No stock changes recorded yet.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      return ListView.separated(
                        controller: scrollController,
                        itemCount: logs.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final data = logs[index].data();
                          final action = (data['action'] ?? '')
                              .toString()
                              .trim();
                          final quantityChanged =
                              (data['quantityChanged'] as num?)?.toDouble() ??
                              0;
                          final previousQuantity =
                              (data['previousQuantity'] as num?)?.toDouble() ??
                              0;
                          final newQuantity =
                              (data['newQuantity'] as num?)?.toDouble() ?? 0;
                          final note = (data['note'] ?? '').toString().trim();
                          final actorName = (data['actorName'] ?? '')
                              .toString()
                              .trim();
                          final createdAt = data['createdAt'] is Timestamp
                              ? data['createdAt'] as Timestamp
                              : null;
                          final isAdded = action == 'added';

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                            ),
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
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${formatQuantityNumber(quantityChanged)} changed · '
                                  '${formatQuantityNumber(previousQuantity)} → '
                                  '${formatQuantityNumber(newQuantity)}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.5,
                                  ),
                                ),
                                if (note.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    note,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                                if (actorName.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'By $actorName',
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
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
