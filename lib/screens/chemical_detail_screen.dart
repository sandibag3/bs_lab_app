import 'package:flutter/material.dart';
import '../models/chemical_model.dart';
import '../services/inventory_service.dart';
import '../services/pubchem_service.dart';
import '../theme/labmate_theme.dart';
import '../widgets/responsive_page_container.dart';

class ChemicalDetailScreen extends StatefulWidget {
  final ChemicalModel chemical;

  const ChemicalDetailScreen({super.key, required this.chemical});

  @override
  State<ChemicalDetailScreen> createState() => _ChemicalDetailScreenState();
}

class _ChemicalDetailScreenState extends State<ChemicalDetailScreen>
    with SingleTickerProviderStateMixin {
  final InventoryService inventoryService = InventoryService();
  final PubChemService pubChemService = PubChemService();
  static const List<String> _allowedBottleStatuses = [
    'available',
    'low',
    'finished',
  ];

  late Future<PubChemChemicalDetails?> pubChemFuture;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    pubChemFuture = pubChemService.fetchByCas(widget.chemical.cas.trim());

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _rotateAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color availabilityColor(String availability) {
    final v = availability.toLowerCase();
    if (v.contains('finished')) return Colors.redAccent;
    if (v.contains('low') || v.contains('about')) return Colors.orangeAccent;
    return Colors.greenAccent;
  }

  String _safeBottleStatus(String rawStatus) {
    final normalized = rawStatus.trim().toLowerCase();
    return _allowedBottleStatuses.contains(normalized)
        ? normalized
        : 'available';
  }

  String _bottleStatusLabel(String status) {
    switch (status) {
      case 'low':
        return 'Low';
      case 'finished':
        return 'Finished';
      case 'available':
      default:
        return 'Available';
    }
  }

  Widget sectionTitle(String title) {
    final colorScheme = context.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 10),
      child: Text(
        title,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 16.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget chip(String text) {
    final palette = context.labmate;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: palette.mutedText,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget buildFunctionalGroupChips(String groups) {
    final palette = context.labmate;

    if (groups.trim().isEmpty) return const SizedBox();

    final list = groups
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Functional Groups',
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: list.map((group) {
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context, group);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x2214B8A6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    group,
                    style: const TextStyle(
                      color: Color(0xFF14B8A6),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget detailBox({
    required String label,
    required String value,
    IconData? icon,
  }) {
    final displayValue = value.trim().isEmpty ? '-' : value.trim();
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: const Color(0xFF14B8A6)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  displayValue,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14.6,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget twoColumnDetailBox({
    required String leftLabel,
    required String leftValue,
    required String rightLabel,
    required String rightValue,
    IconData? leftIcon,
    IconData? rightIcon,
  }) {
    return Row(
      children: [
        Expanded(
          child: detailBox(label: leftLabel, value: leftValue, icon: leftIcon),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: detailBox(
            label: rightLabel,
            value: rightValue,
            icon: rightIcon,
          ),
        ),
      ],
    );
  }

  Widget chemistryLoadingCard() {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotateAnimation.value * 6.28318,
                child: ScaleTransition(scale: _pulseAnimation, child: child),
              );
            },
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x2214B8A6),
                border: Border.all(color: const Color(0xFF14B8A6), width: 1.5),
              ),
              child: const Icon(
                Icons.science_rounded,
                color: Color(0xFF14B8A6),
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Fetching molecular data...',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Checking structure, formula, molecular weight and identifiers from PubChem',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: Color(0x332B3A55),
              valueColor: AlwaysStoppedAnimation(Color(0xFF14B8A6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget bottleCard(ChemicalModel b, int index) {
    final safeStatus = _safeBottleStatus(b.availability);
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: palette.panel,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Bottle ${index + 1}',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  DropdownButton<String>(
                    value: safeStatus,
                    dropdownColor: palette.panel,
                    style: TextStyle(color: colorScheme.onSurface),
                    items: _allowedBottleStatuses
                        .map(
                          (status) => DropdownMenuItem<String>(
                            value: status,
                            child: Text(
                              _bottleStatusLabel(status),
                              style: TextStyle(color: colorScheme.onSurface),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) async {
                      if (value == null) return;

                      await inventoryService.inventoryRef.doc(b.id).update({
                        'availability': _safeBottleStatus(value),
                        'updatedAt': DateTime.now(),
                      });

                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  chip('Brand: ${b.brand.isEmpty ? '-' : b.brand}'),
                  chip('Qty: ${b.quantity.isEmpty ? '-' : b.quantity}'),
                  chip('Loc: ${b.location.isEmpty ? '-' : b.location}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget pubChemDetailsCard(PubChemChemicalDetails p) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x2214B8A6), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.biotech_rounded,
                color: Color(0xFF14B8A6),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'PubChem Molecular Data',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.panelAlt,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Image.network(
              p.imageUrl,
              height: 150,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(
                'Structure image unavailable',
                style: TextStyle(color: palette.mutedText),
              ),
            ),
          ),
          const SizedBox(height: 14),
          twoColumnDetailBox(
            leftLabel: 'Molecular Formula',
            leftValue: p.molecularFormula,
            rightLabel: 'Molecular Weight',
            rightValue: p.molecularWeight,
            leftIcon: Icons.functions_rounded,
            rightIcon: Icons.monitor_weight_outlined,
          ),
          const SizedBox(height: 10),
          detailBox(
            label: 'PubChem CID',
            value: p.cid,
            icon: Icons.tag_rounded,
          ),
          const SizedBox(height: 10),
          detailBox(
            label: 'InChIKey',
            value: p.inchiKey,
            icon: Icons.vpn_key_outlined,
          ),
          const SizedBox(height: 10),
          detailBox(
            label: 'IUPAC Name',
            value: p.iupacName,
            icon: Icons.menu_book_rounded,
          ),
          const SizedBox(height: 10),
          detailBox(
            label: 'Canonical SMILES',
            value: p.canonicalSmiles,
            icon: Icons.account_tree_outlined,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chemical;
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Chemical Details')),
      body: ResponsivePageContainer(
        maxWidth: 1120,
        child: StreamBuilder<List<ChemicalModel>>(
          stream: inventoryService.getChemicals(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final all = snapshot.data!;

            final bottles =
                all.where((e) => e.cas.trim() == c.cas.trim()).toList()
                  ..sort((a, b) => a.label.compareTo(b.label));

            final isDesktop = MediaQuery.sizeOf(context).width >= 900;
            if (isDesktop) {
              return _buildDesktopDetail(c, bottles);
            }

            return ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.panel,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x2214B8A6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          c.label,
                          style: const TextStyle(
                            color: Color(0xFF14B8A6),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        c.chemicalName,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'CAS: ${c.cas}',
                        style: TextStyle(
                          color: palette.mutedText,
                          fontSize: 12.8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${bottles.length} bottles',
                        style: TextStyle(color: palette.mutedText),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                buildFunctionalGroupChips(c.functionalGroups),

                sectionTitle('Bottles'),
                ...List.generate(
                  bottles.length,
                  (i) => bottleCard(bottles[i], i),
                ),

                sectionTitle('PubChem'),
                FutureBuilder<PubChemChemicalDetails?>(
                  future: pubChemFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return chemistryLoadingCard();
                    }

                    if (snapshot.hasError) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: palette.panel,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: palette.border),
                        ),
                        child: Text(
                          'PubChem error: ${snapshot.error}',
                          style: TextStyle(color: palette.mutedText),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data == null) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: palette.panel,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: palette.border),
                        ),
                        child: Text(
                          c.cas.trim().isEmpty
                              ? 'No CAS number available for PubChem lookup.'
                              : 'No PubChem data found for CAS: ${c.cas.trim()}',
                          style: TextStyle(color: palette.mutedText),
                        ),
                      );
                    }

                    final p = snapshot.data!;
                    return pubChemDetailsCard(p);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _display(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '-' : trimmed;
  }

  String _summarizeBottles(
    List<ChemicalModel> bottles,
    String Function(ChemicalModel bottle) read,
  ) {
    final values = bottles
        .map(read)
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    if (values.isEmpty) return '-';
    if (values.length == 1) return values.first;
    return '${values.first} + ${values.length - 1} more';
  }

  String _overallBottleStatus(List<ChemicalModel> bottles) {
    if (bottles.any(
      (bottle) => bottle.availability.toLowerCase().trim() == 'available',
    )) {
      return 'Available';
    }

    if (bottles.any((bottle) {
      final value = bottle.availability.toLowerCase().trim();
      return value == 'low' || value.contains('about');
    })) {
      return 'Low';
    }

    return bottles.isEmpty ? '-' : 'Finished';
  }

  Widget _compactMetric({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _display(value),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? colorScheme.onSurface,
              fontSize: 13,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactMetricGrid(List<Widget> children, {int columns = 3}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final itemWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: children.map((child) {
            return SizedBox(width: itemWidth, child: child);
          }).toList(),
        );
      },
    );
  }

  Widget _compactPanel({required String title, required Widget child}) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 13.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }

  Widget _desktopFunctionalGroups(String groups) {
    final list = groups
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (list.isEmpty) {
      return _compactMetric(label: 'Functional groups', value: '-');
    }

    return _compactPanel(
      title: 'Functional Groups',
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: list.map((group) {
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => Navigator.pop(context, group),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0x2214B8A6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                group,
                style: const TextStyle(
                  color: Color(0xFF14B8A6),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _desktopBottleRow(ChemicalModel bottle, int index) {
    final safeStatus = _safeBottleStatus(bottle.availability);
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          _desktopTableCell('Bottle ${index + 1}', flex: 2, isStrong: true),
          _desktopTableCell(_display(bottle.brand), flex: 3),
          _desktopTableCell(_display(bottle.quantity), flex: 2),
          _desktopTableCell(_display(bottle.location), flex: 3),
          const SizedBox(width: 8),
          SizedBox(
            width: 126,
            height: 30,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: palette.panel,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: palette.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: safeStatus,
                  dropdownColor: palette.panel,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 12),
                  isDense: true,
                  isExpanded: true,
                  items: _allowedBottleStatuses
                      .map(
                        (status) => DropdownMenuItem<String>(
                          value: status,
                          child: Text(
                            _bottleStatusLabel(status),
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    if (value == null) return;

                    await inventoryService.inventoryRef.doc(bottle.id).update({
                      'availability': _safeBottleStatus(value),
                      'updatedAt': DateTime.now(),
                    });

                    setState(() {});
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopBottleHeader() {
    final palette = context.labmate;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Row(
        children: [
          _desktopTableHeader('Bottle', flex: 2),
          _desktopTableHeader('Brand', flex: 3),
          _desktopTableHeader('Qty', flex: 2),
          _desktopTableHeader('Location', flex: 3),
          const SizedBox(width: 8),
          SizedBox(
            width: 126,
            child: Text(
              'Status',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopTableHeader(String text, {required int flex}) {
    final palette = context.labmate;

    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          color: palette.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _desktopTableCell(
    String text, {
    required int flex,
    bool isStrong = false,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Expanded(
      flex: flex,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isStrong ? colorScheme.onSurface : palette.mutedText,
          fontSize: 12.5,
          fontWeight: isStrong ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }

  Widget _desktopPubChemPanel() {
    return FutureBuilder<PubChemChemicalDetails?>(
      future: pubChemFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _compactPanel(
            title: 'PubChem',
            child: const LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: Color(0x332B3A55),
              valueColor: AlwaysStoppedAnimation(Color(0xFF14B8A6)),
            ),
          );
        }

        if (snapshot.hasError) {
          return _compactPanel(
            title: 'PubChem',
            child: Text(
              'PubChem error: ${snapshot.error}',
              style: TextStyle(
                color: context.labmate.mutedText,
                fontSize: 12.2,
              ),
            ),
          );
        }

        final p = snapshot.data;
        if (p == null) {
          return _compactPanel(
            title: 'PubChem',
            child: Text(
              'No PubChem data found.',
              style: TextStyle(
                color: context.labmate.mutedText,
                fontSize: 12.2,
              ),
            ),
          );
        }

        return _compactPanel(
          title: 'PubChem Molecular Data',
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 176,
                    height: 176,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.labmate.panelAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.labmate.border),
                    ),
                    child: Image.network(
                      p.imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.biotech_rounded,
                        color: Color(0xFF14B8A6),
                        size: 42,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        _compactMetric(
                          label: 'Formula',
                          value: p.molecularFormula,
                        ),
                        const SizedBox(height: 8),
                        _compactMetric(label: 'MW', value: p.molecularWeight),
                        const SizedBox(height: 8),
                        _compactMetric(label: 'CID', value: p.cid),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _identifierBlock(label: 'InChIKey', value: p.inchiKey),
              const SizedBox(height: 8),
              _identifierBlock(label: 'IUPAC Name', value: p.iupacName),
              const SizedBox(height: 8),
              _identifierBlock(
                label: 'Canonical SMILES',
                value: p.canonicalSmiles,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _identifierBlock({required String label, required String value}) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _display(value),
            softWrap: true,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 12.6,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopHeaderCard({
    required ChemicalModel chemical,
    required int bottleCount,
    required String availability,
    required Color statusColor,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x2214B8A6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  chemical.label,
                  style: const TextStyle(
                    color: Color(0xFF14B8A6),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withOpacity(0.34)),
                ),
                child: Text(
                  '$availability - $bottleCount ${bottleCount == 1 ? 'bottle' : 'bottles'}',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            chemical.chemicalName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          _compactMetricGrid([
            _compactMetric(label: 'CAS', value: chemical.cas),
            _compactMetric(label: 'Formula', value: chemical.formula),
            _compactMetric(label: 'MW', value: chemical.molWt),
          ], columns: 3),
        ],
      ),
    );
  }

  Widget _desktopInventoryPanel({
    required ChemicalModel chemical,
    required String brand,
    required String quantity,
    required String location,
    required String availability,
    required Color statusColor,
    required int bottleCount,
  }) {
    return _compactPanel(
      title: 'Inventory Details',
      child: Column(
        children: [
          _compactMetricGrid([
            _compactMetric(label: 'Brand', value: brand),
            _compactMetric(label: 'Pack size', value: quantity),
            _compactMetric(label: 'Location', value: location),
            _compactMetric(label: 'Texture', value: chemical.texture),
            _compactMetric(label: 'Catalog no', value: chemical.catNumber),
            _compactMetric(label: 'Ordered by', value: chemical.orderedBy),
            _compactMetric(
              label: 'Availability',
              value: availability,
              valueColor: statusColor,
            ),
            _compactMetric(label: 'Bottles', value: bottleCount.toString()),
            _compactMetric(label: 'Last updated', value: chemical.arrivalDate),
            _compactMetric(label: 'Sheet tab', value: chemical.sheetTab),
          ], columns: 3),
        ],
      ),
    );
  }

  Widget _desktopBottlePanel(List<ChemicalModel> bottles) {
    return _compactPanel(
      title: 'Bottles',
      child: Column(
        children: [
          _desktopBottleHeader(),
          const SizedBox(height: 6),
          for (int index = 0; index < bottles.length; index++) ...[
            _desktopBottleRow(bottles[index], index),
            if (index != bottles.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopDetail(ChemicalModel c, List<ChemicalModel> bottles) {
    final brand = _summarizeBottles(bottles, (bottle) => bottle.brand);
    final quantity = _summarizeBottles(bottles, (bottle) => bottle.quantity);
    final location = _summarizeBottles(bottles, (bottle) => bottle.location);
    final availability = _overallBottleStatus(bottles);
    final statusColor = availabilityColor(availability);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _desktopHeaderCard(
            chemical: c,
            bottleCount: bottles.length,
            availability: availability,
            statusColor: statusColor,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    _desktopInventoryPanel(
                      chemical: c,
                      brand: brand,
                      quantity: quantity,
                      location: location,
                      availability: availability,
                      statusColor: statusColor,
                      bottleCount: bottles.length,
                    ),
                    const SizedBox(height: 10),
                    _desktopBottlePanel(bottles),
                    const SizedBox(height: 10),
                    _desktopFunctionalGroups(c.functionalGroups),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(flex: 5, child: _desktopPubChemPanel()),
            ],
          ),
        ],
      ),
    );
  }
}
