import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_access_guard.dart';
import '../models/instrument_model.dart';
import '../services/instrument_service.dart';
import '../theme/labmate_theme.dart';
import '../widgets/responsive_page_container.dart';
import 'add_instrument_screen.dart';
import 'instrument_detail_screen.dart';

class InstrumentsScreen extends StatefulWidget {
  const InstrumentsScreen({super.key});

  @override
  State<InstrumentsScreen> createState() => _InstrumentsScreenState();
}

class _InstrumentsScreenState extends State<InstrumentsScreen> {
  static const List<String> _statusFilterOptions = [
    'All',
    'Working',
    'Needs service',
    'Under maintenance',
    'Out of order',
  ];

  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = _statusFilterOptions.first;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddInstrument(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddInstrumentScreen()),
    );
  }

  bool _matchesSearch(InstrumentModel instrument, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final searchableText = [
      instrument.normalizedName,
      instrument.brand,
      instrument.normalizedCategory,
      instrument.serialNo,
      instrument.instrumentIncharge,
    ].join(' ').toLowerCase();

    return searchableText.contains(normalizedQuery);
  }

  List<InstrumentModel> _applyFilters(List<InstrumentModel> instruments) {
    final query = _searchController.text.trim();

    return instruments.where((instrument) {
      final matchesSearch = _matchesSearch(instrument, query);
      final matchesStatus = _selectedStatusFilter == 'All'
          ? true
          : instrument.normalizedStatus == _selectedStatusFilter;
      return matchesSearch && matchesStatus;
    }).toList();
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

  bool get _hasActiveFilters {
    return _searchController.text.trim().isNotEmpty ||
        _selectedStatusFilter != 'All';
  }

  Widget _buildSearchBar({bool dense = false}) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return TextField(
      controller: _searchController,
      style: TextStyle(color: colorScheme.onSurface),
      onChanged: (_) {
        setState(() {});
      },
      decoration: InputDecoration(
        hintText: 'Search by name, brand, category, serial no, or in-charge',
        hintStyle: TextStyle(color: palette.subtleText),
        prefixIcon: Icon(Icons.search_rounded, color: palette.mutedText),
        suffixIcon: _searchController.text.trim().isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: Icon(Icons.close_rounded, color: palette.subtleText),
              ),
        filled: true,
        fillColor: palette.panel,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: dense ? 11 : 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.border),
        ),
      ),
    );
  }

  Widget _buildStatusFilters({bool dense = false}) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _statusFilterOptions.map((status) {
          final isSelected = status == _selectedStatusFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(status),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedStatusFilter = status;
                });
              },
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : palette.mutedText,
                fontSize: dense ? 12.0 : 12.5,
                fontWeight: FontWeight.w700,
              ),
              backgroundColor: palette.panel,
              selectedColor: colorScheme.primary,
              side: BorderSide(
                color: isSelected ? colorScheme.primary : palette.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final instrumentService = InstrumentService();

    return SafeArea(
      child: ResponsivePageContainer(
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
            final filteredInstruments = _applyFilters(instruments);
            final categoryGroups = _buildCategoryGroups(filteredInstruments);

            return LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;
                final pagePadding = isDesktop ? 12.0 : 16.0;
                final sectionGap = isDesktop ? 10.0 : 14.0;

                return Padding(
                  padding: EdgeInsets.all(pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InstrumentHeaderCard(
                        instrumentCount: instruments.length,
                        onAddInstrument: () => _openAddInstrument(context),
                        dense: isDesktop,
                      ),
                      SizedBox(height: sectionGap),
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildSearchBar(dense: true),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: _buildStatusFilters(dense: true),
                            ),
                          ],
                        )
                      else ...[
                        _buildSearchBar(),
                        const SizedBox(height: 12),
                        _buildStatusFilters(),
                      ],
                      SizedBox(height: sectionGap),
                      if (instruments.isEmpty) ...[
                        const _InstrumentEmptyState(),
                        SizedBox(height: sectionGap),
                      ] else if (filteredInstruments.isEmpty) ...[
                        const _InstrumentFilteredEmptyState(),
                        SizedBox(height: sectionGap),
                      ],
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount = constraints.maxWidth >= 1120
                                ? 6
                                : constraints.maxWidth >= 900
                                ? 5
                                : constraints.maxWidth >= 720
                                ? 4
                                : 3;
                            final childAspectRatio = constraints.maxWidth >= 900
                                ? 1.72
                                : constraints.maxWidth >= 720
                                ? 1.08
                                : 0.84;

                            return GridView.builder(
                              itemCount: categoryGroups.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    mainAxisSpacing: isDesktop ? 10 : 12,
                                    crossAxisSpacing: isDesktop ? 10 : 12,
                                    childAspectRatio: childAspectRatio,
                                  ),
                              itemBuilder: (context, index) {
                                final group = categoryGroups[index];
                                return _InstrumentCategoryTile(
                                  group: group,
                                  dense: isDesktop,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            _InstrumentCategoryScreen(
                                              category: group.category,
                                              instruments: group.instruments,
                                              hasActiveFilters:
                                                  _hasActiveFilters,
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
            );
          },
        ),
      ),
    );
  }
}

class _InstrumentAccessState extends StatelessWidget {
  final String title;

  const _InstrumentAccessState({required this.title});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.mutedText,
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
  final bool dense;

  const _InstrumentHeaderCard({
    required this.instrumentCount,
    required this.onAddInstrument,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dense ? 14 : 18),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: dense
          ? Row(
              children: [
                Expanded(child: _InstrumentHeaderCopy(instrumentCount)),
                const SizedBox(width: 16),
                _InstrumentAddButton(onAddInstrument: onAddInstrument),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InstrumentHeaderCopy(instrumentCount),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _InstrumentAddButton(onAddInstrument: onAddInstrument),
                ),
              ],
            ),
    );
  }
}

class _InstrumentHeaderCopy extends StatelessWidget {
  final int instrumentCount;

  const _InstrumentHeaderCopy(this.instrumentCount);

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final palette = context.labmate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lab Instruments',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          instrumentCount == 0
              ? 'Track balances, pumps, chillers, and other shared lab assets here.'
              : '$instrumentCount ${instrumentCount == 1 ? 'instrument' : 'instruments'} recorded for this lab.',
          style: TextStyle(
            color: palette.subtleText,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _InstrumentAddButton extends StatelessWidget {
  final VoidCallback onAddInstrument;

  const _InstrumentAddButton({required this.onAddInstrument});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onAddInstrument,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF14B8A6),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      icon: const Icon(Icons.add_rounded),
      label: const Text(
        'Add Instrument',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _InstrumentEmptyState extends StatelessWidget {
  const _InstrumentEmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No instruments added yet.',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add your first instrument to start organizing lab assets by category.',
            style: TextStyle(
              color: palette.subtleText,
              fontSize: 12.8,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstrumentFilteredEmptyState extends StatelessWidget {
  const _InstrumentFilteredEmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        'No instruments match current filters.',
        style: TextStyle(
          color: palette.mutedText,
          fontSize: 13.2,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }
}

class _InstrumentCategoryTile extends StatelessWidget {
  final _InstrumentCategoryGroup group;
  final VoidCallback onTap;
  final bool dense;

  const _InstrumentCategoryTile({
    required this.group,
    required this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Material(
      color: palette.panel,
      borderRadius: BorderRadius.circular(dense ? 16 : 20),
      child: InkWell(
        borderRadius: BorderRadius.circular(dense ? 16 : 20),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 9 : 10,
            vertical: dense ? 8 : 12,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _InstrumentPreviewBox(
                photoReference: group.previewPhoto,
                fallbackIcon: _iconForCategory(group.category),
                size: dense ? 34 : 48,
              ),
              SizedBox(height: dense ? 6 : 10),
              Text(
                group.category,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: dense ? 11.0 : 11.8,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              SizedBox(height: dense ? 5 : 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.panelAlt,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  '${group.count} ${group.count == 1 ? 'item' : 'items'}',
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
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

class _InstrumentCategoryScreen extends StatelessWidget {
  final String category;
  final List<InstrumentModel> instruments;
  final bool hasActiveFilters;

  const _InstrumentCategoryScreen({
    required this.category,
    required this.instruments,
    required this.hasActiveFilters,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;

    return Scaffold(
      appBar: AppBar(title: Text(category)),
      body: SafeArea(
        child: ResponsivePageContainer(
          maxWidth: 1120,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;

              return ListView(
                padding: EdgeInsets.all(isDesktop ? 12 : 14),
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 14 : 16,
                      vertical: isDesktop ? 12 : 16,
                    ),
                    decoration: BoxDecoration(
                      color: palette.panel,
                      borderRadius: BorderRadius.circular(isDesktop ? 16 : 18),
                      border: Border.all(color: palette.border),
                    ),
                    child: Text(
                      '${instruments.length} ${instruments.length == 1 ? 'instrument' : 'instruments'} in this category.',
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                  SizedBox(height: isDesktop ? 10 : 14),
                  if (instruments.isEmpty)
                    _CategoryEmptyState(hasActiveFilters: hasActiveFilters)
                  else
                    ...instruments.map((instrument) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: isDesktop ? 8 : 12),
                        child: _InstrumentCard(
                          instrument: instrument,
                          dense: isDesktop,
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CategoryEmptyState extends StatelessWidget {
  final bool hasActiveFilters;

  const _CategoryEmptyState({required this.hasActiveFilters});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        hasActiveFilters
            ? 'No instruments match current filters.'
            : 'No instruments added in this category yet.',
        style: TextStyle(color: palette.mutedText, fontSize: 13, height: 1.4),
      ),
    );
  }
}

class _InstrumentCard extends StatelessWidget {
  final InstrumentModel instrument;
  final bool dense;

  const _InstrumentCard({required this.instrument, this.dense = false});

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

  Widget _desktopMeta(
    BuildContext context,
    String label,
    String value, {
    int flex = 1,
  }) {
    final displayValue = value.trim().isEmpty ? 'Not set' : value.trim();
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.subtleText,
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            displayValue,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 12.2,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopCard(BuildContext context) {
    final incharge = instrument.instrumentIncharge.trim();
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final details = [
      instrument.serialNo.trim(),
      instrument.catalogNumber.trim(),
      instrument.specification.trim(),
    ].firstWhere((value) => value.isNotEmpty, orElse: () => '');

    return Material(
      color: palette.panel,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InstrumentDetailScreen(instrument: instrument),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _InstrumentPreviewBox(
                photoReference: instrument.previewPhoto,
                fallbackIcon: _iconForCategory(instrument.normalizedCategory),
                size: 56,
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Text(
                  instrument.normalizedName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14.2,
                    fontWeight: FontWeight.w800,
                    height: 1.22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _desktopMeta(
                context,
                'Category',
                instrument.normalizedCategory,
                flex: 2,
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _InstrumentStatusBadge(
                    status: instrument.normalizedStatus,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _desktopMeta(
                context,
                'In-charge',
                incharge.isEmpty ? 'Not assigned' : incharge,
                flex: 2,
              ),
              const SizedBox(width: 12),
              _desktopMeta(context, 'Details', details, flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCard(BuildContext context) {
    final brand = instrument.brand.trim();
    final incharge = instrument.instrumentIncharge.trim();
    final arrivedOn = _formatDate(instrument.arrivedOn);
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Material(
      color: palette.panel,
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
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 15.2,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _InstrumentStatusBadge(status: instrument.normalizedStatus),
                    if (brand.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Brand: $brand',
                        style: TextStyle(
                          color: palette.mutedText,
                          fontSize: 12.8,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Instrument in-charge: ${incharge.isEmpty ? 'Not assigned' : incharge}',
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: 12.8,
                        height: 1.35,
                      ),
                    ),
                    if (arrivedOn.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Arrived on: $arrivedOn',
                        style: TextStyle(
                          color: palette.subtleText,
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

  @override
  Widget build(BuildContext context) {
    return dense ? _buildDesktopCard(context) : _buildMobileCard(context);
  }
}

class _InstrumentStatusBadge extends StatelessWidget {
  final String status;

  const _InstrumentStatusBadge({required this.status});

  Color _backgroundColor() {
    switch (status) {
      case 'Needs service':
        return const Color(0xFF7C2D12);
      case 'Out of order':
        return const Color(0xFF7F1D1D);
      case 'Under maintenance':
        return const Color(0xFF1E3A8A);
      default:
        return const Color(0xFF14532D);
    }
  }

  Color _textColor() {
    switch (status) {
      case 'Needs service':
        return const Color(0xFFFBBF24);
      case 'Out of order':
        return const Color(0xFFFCA5A5);
      case 'Under maintenance':
        return const Color(0xFFBFDBFE);
      default:
        return const Color(0xFFBBF7D0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _backgroundColor().withOpacity(0.3),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _textColor().withOpacity(0.35)),
      ),
      child: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _textColor(),
          fontSize: 11.8,
          fontWeight: FontWeight.w700,
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
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
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
    final palette = context.labmate;

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
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
