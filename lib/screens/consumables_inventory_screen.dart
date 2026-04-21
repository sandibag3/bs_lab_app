import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';

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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sorted = [...docs];
    sorted.sort((a, b) {
      final aData = a.data();
      final bData = b.data();
      final aTimestamp = _readTimestamp(aData, 'createdAt') ??
          _readTimestamp(aData, 'deliveredAt') ??
          _readTimestamp(aData, 'updatedAt');
      final bTimestamp = _readTimestamp(bData, 'createdAt') ??
          _readTimestamp(bData, 'deliveredAt') ??
          _readTimestamp(bData, 'updatedAt');

      final aDate = aTimestamp?.toDate() ?? DateTime(2000);
      final bDate = bTimestamp?.toDate() ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });
    return sorted;
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
              return const Center(
                child: CircularProgressIndicator(),
              );
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
              separatorBuilder: (_, __) => const SizedBox(height: 12),
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

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.06),
                    ),
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
                          if (brand.isNotEmpty) _InfoChip(label: 'Brand: $brand'),
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

  const _InfoChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
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
