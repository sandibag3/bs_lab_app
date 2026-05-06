import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_access_guard.dart';
import '../models/instrument_model.dart';
import '../services/instrument_service.dart';
import 'add_instrument_screen.dart';
import 'instrument_detail_screen.dart';

class InstrumentsScreen extends StatelessWidget {
  const InstrumentsScreen({super.key});

  void _openAddInstrument(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddInstrumentScreen()),
    );
  }

  List<_InstrumentCategoryGroup> _buildCategoryGroups(
    List<InstrumentModel> instruments,
  ) {
    return InstrumentModel.categories.map((category) {
      final items = instruments
          .where((instrument) => instrument.normalizedCategory == category)
          .toList();

      items.sort((a, b) {
        return a.normalizedName.toLowerCase().compareTo(
          b.normalizedName.toLowerCase(),
        );
      });

      return _InstrumentCategoryGroup(category: category, instruments: items);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final instrumentService = InstrumentService();

    return SafeArea(
      child: StreamBuilder<List<InstrumentModel>>(
        stream: instrumentService.getInstruments(),
        builder: (context, snapshot) {
          if (!FirestoreAccessGuard.shouldQueryLabScopedData()) {
            return _InstrumentAccessState(
              title: FirestoreAccessGuard.userMessage,
            );
          }

          if (snapshot.hasError) {
            return _InstrumentAccessState(
              title: FirestoreAccessGuard.messageFor(snapshot.error),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF14B8A6)),
            );
          }

          final instruments = snapshot.data ?? [];
          final categoryGroups = _buildCategoryGroups(instruments);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InstrumentHeaderCard(
                  instrumentCount: instruments.length,
                  onAddInstrument: () => _openAddInstrument(context),
                ),
                const SizedBox(height: 14),
                if (instruments.isEmpty) ...[
                  const _InstrumentEmptyState(),
                  const SizedBox(height: 14),
                ],
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 980
                          ? 3
                          : constraints.maxWidth >= 640
                          ? 2
                          : 1;

                      return GridView.builder(
                        itemCount: categoryGroups.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: constraints.maxWidth >= 640
                              ? 1.45
                              : 1.65,
                        ),
                        itemBuilder: (context, index) {
                          final group = categoryGroups[index];
                          return _InstrumentCategoryTile(
                            group: group,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _InstrumentCategoryScreen(
                                    category: group.category,
                                  ),
                                ),
                              );
                            },
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

class _InstrumentAccessState extends StatelessWidget {
  final String title;

  const _InstrumentAccessState({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _InstrumentHeaderCard extends StatelessWidget {
  final int instrumentCount;
  final VoidCallback onAddInstrument;

  const _InstrumentHeaderCard({
    required this.instrumentCount,
    required this.onAddInstrument,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lab Instruments',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            instrumentCount == 0
                ? 'Track balances, pumps, chillers, and other shared lab assets here.'
                : '$instrumentCount ${instrumentCount == 1 ? 'instrument' : 'instruments'} recorded for this lab.',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: onAddInstrument,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14B8A6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add Instrument',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstrumentEmptyState extends StatelessWidget {
  const _InstrumentEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No instruments added yet.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add your first instrument to start organizing lab assets by category.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12.8,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstrumentCategoryTile extends StatelessWidget {
  final _InstrumentCategoryGroup group;
  final VoidCallback onTap;

  const _InstrumentCategoryTile({
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _InstrumentPreviewBox(
                photoReference: group.previewPhoto,
                fallbackIcon: _iconForCategory(group.category),
                size: 74,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      group.category,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${group.count} ${group.count == 1 ? 'instrument' : 'instruments'}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white38,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstrumentCategoryScreen extends StatelessWidget {
  final String category;

  const _InstrumentCategoryScreen({required this.category});

  @override
  Widget build(BuildContext context) {
    final instrumentService = InstrumentService();

    return Scaffold(
      appBar: AppBar(
        title: Text(category, style: const TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: StreamBuilder<List<InstrumentModel>>(
          stream: instrumentService.getInstruments(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _InstrumentAccessState(
                title: FirestoreAccessGuard.messageFor(snapshot.error),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF14B8A6)),
              );
            }

            final instruments = snapshot.data!
                .where((instrument) => instrument.normalizedCategory == category)
                .toList();

            instruments.sort((a, b) {
              return a.normalizedName.toLowerCase().compareTo(
                b.normalizedName.toLowerCase(),
              );
            });

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Text(
                    '${instruments.length} ${instruments.length == 1 ? 'instrument' : 'instruments'} in this category.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (instruments.isEmpty)
                  const _CategoryEmptyState()
                else
                  ...instruments.map((instrument) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _InstrumentCard(instrument: instrument),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryEmptyState extends StatelessWidget {
  const _CategoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: const Text(
        'No instruments added in this category yet.',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }
}

class _InstrumentCard extends StatelessWidget {
  final InstrumentModel instrument;

  const _InstrumentCard({required this.instrument});

  String _formatDate(Timestamp? value) {
    if (value == null) {
      return '';
    }

    final date = value.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    final brand = instrument.brand.trim();
    final incharge = instrument.instrumentIncharge.trim();
    final arrivedOn = _formatDate(instrument.arrivedOn);

    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InstrumentDetailScreen(instrument: instrument),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InstrumentPreviewBox(
                photoReference: instrument.previewPhoto,
                fallbackIcon: _iconForCategory(instrument.normalizedCategory),
                size: 72,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      instrument.normalizedName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.2,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    if (brand.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Brand: $brand',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.8,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Instrument in-charge: ${incharge.isEmpty ? 'Not assigned' : incharge}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.8,
                        height: 1.35,
                      ),
                    ),
                    if (arrivedOn.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Arrived on: $arrivedOn',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstrumentPreviewBox extends StatelessWidget {
  final String photoReference;
  final IconData fallbackIcon;
  final double size;

  const _InstrumentPreviewBox({
    required this.photoReference,
    required this.fallbackIcon,
    required this.size,
  });

  ImageProvider<Object>? _resolveImageProvider() {
    final cleanReference = photoReference.trim();
    if (cleanReference.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(cleanReference);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https')) {
      return NetworkImage(cleanReference);
    }

    if (uri != null && uri.scheme == 'file') {
      final file = File.fromUri(uri);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }

    final file = File(cleanReference);
    if (file.existsSync()) {
      return FileImage(file);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = _resolveImageProvider();

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: imageProvider == null
            ? Center(
                child: Icon(
                  fallbackIcon,
                  color: const Color(0xFF14B8A6),
                  size: size * 0.38,
                ),
              )
            : Image(
                image: imageProvider,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Center(
                    child: Icon(
                      fallbackIcon,
                      color: const Color(0xFF14B8A6),
                      size: size * 0.38,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _InstrumentCategoryGroup {
  final String category;
  final List<InstrumentModel> instruments;

  const _InstrumentCategoryGroup({
    required this.category,
    required this.instruments,
  });

  int get count => instruments.length;

  String get previewPhoto {
    for (final instrument in instruments) {
      final preview = instrument.previewPhoto.trim();
      if (preview.isNotEmpty) {
        return preview;
      }
    }

    return '';
  }
}

IconData _iconForCategory(String category) {
  switch (category) {
    case 'Weighing balance':
      return Icons.scale_rounded;
    case 'Magnetic stirrer':
      return Icons.rotate_right_rounded;
    case 'Vacuum pump':
      return Icons.air_rounded;
    case 'Rotary evaporator':
      return Icons.autorenew_rounded;
    case 'Chiller':
      return Icons.ac_unit_rounded;
    case 'Heating mantel':
      return Icons.local_fire_department_rounded;
    case 'Refrigerator':
      return Icons.kitchen_rounded;
    case 'Oven':
      return Icons.microwave_rounded;
    default:
      return Icons.precision_manufacturing_rounded;
  }
}
