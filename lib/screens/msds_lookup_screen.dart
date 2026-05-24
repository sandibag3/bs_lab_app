import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/msds_model.dart';
import '../services/msds_service.dart';
import '../theme/labmate_theme.dart';
import '../widgets/responsive_page_container.dart';

class MsdsLookupScreen extends StatefulWidget {
  const MsdsLookupScreen({super.key});

  @override
  State<MsdsLookupScreen> createState() => _MsdsLookupScreenState();
}

class _MsdsLookupScreenState extends State<MsdsLookupScreen> {
  final TextEditingController _casController = TextEditingController();
  final MsdsService _msdsService = MsdsService();

  MsdsModel? _result;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _casController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();

    final cas = _casController.text.trim();
    if (cas.isEmpty) {
      setState(() {
        _errorMessage = 'Enter a CAS number to search.';
        _result = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final result = await _msdsService.fetchByCas(cas);
      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
        _isLoading = false;
      });
    } on MsdsLookupException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Something went wrong while fetching safety data.';
        _isLoading = false;
      });
    }
  }

  void _clearOutcome() {
    FocusScope.of(context).unfocus();
    setState(() {
      _result = null;
      _errorMessage = null;
      _isLoading = false;
    });
  }

  Future<void> _openPubChem(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the PubChem page')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasOutcome = _result != null || _errorMessage != null;

    return Scaffold(
      appBar: AppBar(title: const Text('MSDS / Safety')),
      body: SafeArea(
        child: ResponsivePageContainer(
          maxWidth: 1230,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
            children: [
              _SearchBarSection(
                controller: _casController,
                hasOutcome: hasOutcome,
                isLoading: _isLoading,
                onSearch: _search,
                onClear: hasOutcome ? _clearOutcome : null,
              ),
              if (_isLoading) ...[
                const SizedBox(height: 10),
                const _LoadingCard(),
              ] else if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                _CompactBanner(
                  icon: Icons.error_outline_rounded,
                  accentColor: context.labmate.danger,
                  message: _errorMessage!,
                ),
              ] else if (_result != null) ...[
                const SizedBox(height: 10),
                _MsdsResultBody(result: _result!, onOpenPubChem: _openPubChem),
                const SizedBox(height: 10),
                _CompactBanner(
                  icon: Icons.info_outline_rounded,
                  accentColor: context.labmate.warning,
                  message:
                      'Safety data shown here is a PubChem-based summary and may not replace the official supplier SDS/MSDS. Always verify with the manufacturer\'s SDS before handling chemicals.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBarSection extends StatelessWidget {
  final TextEditingController controller;
  final bool hasOutcome;
  final bool isLoading;
  final VoidCallback onSearch;
  final VoidCallback? onClear;

  const _SearchBarSection({
    required this.controller,
    required this.hasOutcome,
    required this.isLoading,
    required this.onSearch,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(12, hasOutcome ? 10 : 12, 12, 12),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useWideRow = constraints.maxWidth >= 760;
          final showClear = onClear != null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hasOutcome) ...[
                Row(
                  children: [
                    Container(
                      height: 28,
                      width: 28,
                      decoration: BoxDecoration(
                        color: palette.warning.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.science_outlined,
                        color: palette.warning,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Search by CAS number',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 14.6,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              if (useWideRow)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => onSearch(),
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'CAS number',
                          hintText: 'Example: 75-77-4',
                          prefixIcon: Icon(Icons.science_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 118,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : onSearch,
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: Text(isLoading ? '...' : 'Search'),
                      ),
                    ),
                    if (showClear) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: TextButton.icon(
                          onPressed: isLoading ? null : onClear,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Clear'),
                        ),
                      ),
                    ],
                  ],
                )
              else ...[
                TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSearch(),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'CAS number',
                    hintText: 'Example: 75-77-4',
                    prefixIcon: Icon(Icons.science_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : onSearch,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: Text(isLoading ? 'Searching...' : 'Search'),
                      ),
                    ),
                    if (showClear) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: isLoading ? null : onClear,
                        child: const Text('Clear'),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Fetching PubChem identity and safety details...',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 12.8,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactBanner extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String message;

  const _CompactBanner({
    required this.icon,
    required this.accentColor,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, color: accentColor, size: 17),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 12.2,
                height: 1.32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MsdsResultBody extends StatelessWidget {
  final MsdsModel result;
  final ValueChanged<String> onOpenPubChem;

  const _MsdsResultBody({required this.result, required this.onOpenPubChem});

  @override
  Widget build(BuildContext context) {
    final notes = _buildAdditionalNotes(result);

    final cardSpecs = <_SafetyCardSpec>[
      _SafetyCardSpec(
        title: 'GHS Pictograms',
        icon: Icons.shield_outlined,
        accentColor: const Color(0xFFDC2626),
        child: _PictogramSection(result: result),
      ),
      _SafetyCardSpec(
        title: 'Hazard Statements',
        icon: Icons.warning_amber_rounded,
        accentColor: const Color(0xFFEF4444),
        child: _StatementSection(
          items: result.hazardStatements,
          emptyMessage:
              'No hazard statements were listed in the PubChem summary.',
        ),
      ),
      _SafetyCardSpec(
        title: 'Precautionary Statements',
        icon: Icons.fact_check_outlined,
        accentColor: const Color(0xFFF59E0B),
        child: _StatementSection(
          items: result.precautionaryStatements,
          emptyMessage:
              'No precautionary statements were listed in the PubChem summary.',
        ),
      ),
      _SafetyCardSpec(
        title: 'First Aid Measures',
        icon: Icons.local_hospital_outlined,
        accentColor: const Color(0xFF2563EB),
        child: _ActionLinesSection(
          text: result.firstAid,
          fallback: 'No first-aid guidance was available from PubChem.',
        ),
      ),
      _SafetyCardSpec(
        title: 'Handling & Storage',
        icon: Icons.inventory_2_outlined,
        accentColor: const Color(0xFF16A34A),
        child: _ActionLinesSection(
          text: result.handlingAndStorage,
          fallback:
              'No handling or storage guidance was available from PubChem.',
        ),
      ),
      if (notes.isNotEmpty)
        _SafetyCardSpec(
          title: 'Additional Info',
          icon: Icons.notes_rounded,
          accentColor: const Color(0xFF7C3AED),
          child: _NotesSection(lines: notes),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChemicalSummaryCard(result: result, onOpenPubChem: onOpenPubChem),
        const SizedBox(height: 10),
        _SafetyCardGrid(cards: cardSpecs),
      ],
    );
  }

  static List<String> _buildAdditionalNotes(MsdsModel result) {
    final lines = <String>[];

    if (!result.hasDetailedSafetyData) {
      lines.add(
        'Detailed safety data was not available from PubChem for this CAS.',
      );
    }
    if (result.signalWord.trim().isEmpty) {
      lines.add('Signal word was not listed in the PubChem summary.');
    }
    if (result.hazardStatements.isEmpty) {
      lines.add('Hazard statements were not included in the PubChem summary.');
    }
    if (result.precautionaryStatements.isEmpty) {
      lines.add(
        'Precautionary statements were not included in the PubChem summary.',
      );
    }

    return lines;
  }
}

class _ChemicalSummaryCard extends StatelessWidget {
  final MsdsModel result;
  final ValueChanged<String> onOpenPubChem;

  const _ChemicalSummaryCard({
    required this.result,
    required this.onOpenPubChem,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final displayName = result.name.trim().isEmpty
        ? 'Chemical information unavailable'
        : result.name.trim();
    final subtitle =
        result.iupacName.trim().isNotEmpty &&
            result.iupacName.trim().toLowerCase() != displayName.toLowerCase()
        ? result.iupacName.trim()
        : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useWideLayout = constraints.maxWidth >= 780;

          final leading = Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.science_rounded,
              color: colorScheme.primary,
              size: 30,
            ),
          );

          final middle = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: useWideLayout ? 24 : 21,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: useWideLayout ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: 12.8,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _MetaGrid(
                  items: [
                    _MetaGridItem(label: 'CAS', value: result.cas),
                    _MetaGridItem(label: 'CID', value: result.cid),
                    _MetaGridItem(
                      label: 'Formula',
                      value: _displayValue(result.molecularFormula),
                    ),
                    _MetaGridItem(
                      label: 'MW',
                      value: _displayValue(result.molecularWeight),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => onOpenPubChem(result.pubChemUrl),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: const Text('Open PubChem page'),
                ),
              ],
            ),
          );

          final signalPanel = _SignalPanel(result: result);

          if (useWideLayout) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading,
                const SizedBox(width: 14),
                middle,
                const SizedBox(width: 14),
                SizedBox(width: 170, child: signalPanel),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  leading,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.mutedText,
                              fontSize: 12.7,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              signalPanel,
              const SizedBox(height: 12),
              _MetaGrid(
                items: [
                  _MetaGridItem(label: 'CAS', value: result.cas),
                  _MetaGridItem(label: 'CID', value: result.cid),
                  _MetaGridItem(
                    label: 'Formula',
                    value: _displayValue(result.molecularFormula),
                  ),
                  _MetaGridItem(
                    label: 'MW',
                    value: _displayValue(result.molecularWeight),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => onOpenPubChem(result.pubChemUrl),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: const Text('Open PubChem page'),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _displayValue(String value) {
    return value.trim().isEmpty ? 'Not available' : value.trim();
  }
}

class _MetaGridItem {
  final String label;
  final String value;

  const _MetaGridItem({required this.label, required this.value});
}

class _MetaGrid extends StatelessWidget {
  final List<_MetaGridItem> items;

  const _MetaGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 460 ? 4 : 2;
        const spacing = 8.0;
        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((item) {
            return SizedBox(
              width: itemWidth,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: palette.panelAlt,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        color: palette.subtleText,
                        fontSize: 10.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 13.2,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SignalPanel extends StatelessWidget {
  final MsdsModel result;

  const _SignalPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final signalWord = result.signalWord.trim();
    final representativePictogram = result.ghsPictograms.isNotEmpty
        ? result.ghsPictograms.first
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Signal word',
                  style: TextStyle(
                    color: palette.subtleText,
                    fontSize: 11.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                _SignalBadge(signalWord: signalWord),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _RepresentativePictogram(code: representativePictogram),
        ],
      ),
    );
  }
}

class _RepresentativePictogram extends StatelessWidget {
  final String? code;

  const _RepresentativePictogram({required this.code});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      alignment: Alignment.center,
      child: code == null
          ? Icon(Icons.shield_outlined, color: palette.subtleText, size: 26)
          : ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                'https://pubchem.ncbi.nlm.nih.gov/images/ghs/$code.gif',
                height: 36,
                width: 36,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.warning_amber_rounded,
                    color: context.labmate.warning,
                    size: 28,
                  );
                },
              ),
            ),
    );
  }
}

class _SignalBadge extends StatelessWidget {
  final String signalWord;

  const _SignalBadge({required this.signalWord});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final normalized = signalWord.trim().toLowerCase();

    Color backgroundColor = palette.panel;
    Color foregroundColor = context.colorScheme.onSurface;
    String label = signalWord.trim().isEmpty ? 'Not available' : signalWord;

    if (normalized == 'danger') {
      backgroundColor = palette.danger.withValues(alpha: 0.14);
      foregroundColor = palette.danger;
      label = 'DANGER';
    } else if (normalized == 'warning') {
      backgroundColor = palette.warning.withValues(alpha: 0.14);
      foregroundColor = palette.warning;
      label = 'WARNING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _SafetyCardSpec {
  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget child;

  const _SafetyCardSpec({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.child,
  });
}

class _SafetyCardGrid extends StatelessWidget {
  final List<_SafetyCardSpec> cards;

  const _SafetyCardGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 860;
        const spacing = 10.0;
        final cardWidth = useTwoColumns
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards.map((card) {
            return SizedBox(
              width: cardWidth,
              child: _SafetyGridCard(
                title: card.title,
                icon: card.icon,
                accentColor: card.accentColor,
                child: card.child,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SafetyGridCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget child;

  const _SafetyGridCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = Color.alphaBlend(
      accentColor.withValues(alpha: isDark ? 0.10 : 0.06),
      palette.panel,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _PictogramSection extends StatelessWidget {
  final MsdsModel result;

  const _PictogramSection({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.ghsPictograms.isEmpty) {
      return const _MutedInfoText(
        'No GHS pictograms were available from PubChem for this compound.',
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: result.ghsPictograms
          .map((code) => _PictogramChip(code: code))
          .toList(),
    );
  }
}

class _StatementSection extends StatelessWidget {
  final List<String> items;
  final String emptyMessage;

  const _StatementSection({required this.items, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _MutedInfoText(emptyMessage);
    }

    return _ExpandableBulletList(items: items, previewCount: 5);
  }
}

class _ActionLinesSection extends StatelessWidget {
  final String text;
  final String fallback;

  const _ActionLinesSection({required this.text, required this.fallback});

  @override
  Widget build(BuildContext context) {
    final lines = _SafetyTextCleaner.cleanActionLines(text);
    if (lines.isEmpty) {
      return _MutedInfoText(fallback);
    }

    return _ExpandableTextLines(lines: lines, previewCount: 5);
  }
}

class _NotesSection extends StatelessWidget {
  final List<String> lines;

  const _NotesSection({required this.lines});

  @override
  Widget build(BuildContext context) {
    return _ExpandableTextLines(lines: lines, previewCount: 4);
  }
}

class _MutedInfoText extends StatelessWidget {
  final String text;

  const _MutedInfoText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.labmate.mutedText,
        fontSize: 12.6,
        height: 1.35,
      ),
    );
  }
}

class _ExpandableBulletList extends StatefulWidget {
  final List<String> items;
  final int previewCount;

  const _ExpandableBulletList({
    required this.items,
    required this.previewCount,
  });

  @override
  State<_ExpandableBulletList> createState() => _ExpandableBulletListState();
}

class _ExpandableBulletListState extends State<_ExpandableBulletList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final visibleItems = _expanded
        ? widget.items
        : widget.items.take(widget.previewCount).toList();
    final hasMore = widget.items.length > widget.previewCount;
    final palette = context.labmate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visibleItems.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    height: 5,
                    width: 5,
                    decoration: BoxDecoration(
                      color: context.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: 12.7,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        if (hasMore)
          TextButton(
            onPressed: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(_expanded ? 'Show less' : 'Show more'),
          ),
      ],
    );
  }
}

class _ExpandableTextLines extends StatefulWidget {
  final List<String> lines;
  final int previewCount;

  const _ExpandableTextLines({required this.lines, required this.previewCount});

  @override
  State<_ExpandableTextLines> createState() => _ExpandableTextLinesState();
}

class _ExpandableTextLinesState extends State<_ExpandableTextLines> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final visibleLines = _expanded
        ? widget.lines
        : widget.lines.take(widget.previewCount).toList();
    final hasMore = widget.lines.length > widget.previewCount;
    final palette = context.labmate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visibleLines.map((line) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              line,
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 12.7,
                height: 1.36,
              ),
            ),
          );
        }),
        if (hasMore)
          TextButton(
            onPressed: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(_expanded ? 'Show less' : 'Show more'),
          ),
      ],
    );
  }
}

class _PictogramChip extends StatelessWidget {
  final String code;

  const _PictogramChip({required this.code});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;

    return Container(
      width: 62,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              'https://pubchem.ncbi.nlm.nih.gov/images/ghs/$code.gif',
              height: 34,
              width: 34,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.warning_amber_rounded,
                  color: context.labmate.warning,
                  size: 28,
                );
              },
            ),
          ),
          const SizedBox(height: 5),
          Text(
            code,
            style: TextStyle(
              color: context.colorScheme.onSurface,
              fontSize: 10.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyTextCleaner {
  static final RegExp _genericIntroPattern = RegExp(
    r'^(this section|the purpose of this section|this page|this summary|the information in this section|recommendations for first aid|handling and storage guidance)',
    caseSensitive: false,
  );

  static List<String> cleanActionLines(String raw) {
    if (raw.trim().isEmpty) {
      return const [];
    }

    final normalized = raw
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\n{2,}'), '\n');
    final fragments = normalized
        .split('\n')
        .expand((line) => line.split(RegExp(r'(?<=[.!?])\s+')))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final lines = <String>[];
    final seen = <String>{};

    for (final fragment in fragments) {
      final cleaned = fragment.replaceAll(RegExp(r'\s+'), ' ').trim();
      final lower = cleaned.toLowerCase();
      if (cleaned.isEmpty ||
          _genericIntroPattern.hasMatch(cleaned) ||
          lower.contains('relevant routes of exposure') ||
          lower.contains('recommendations for immediate medical care') ||
          lower.contains('this section provides recommendations') ||
          lower.contains('this section includes information')) {
        continue;
      }

      if (seen.add(cleaned)) {
        lines.add(cleaned);
      }
    }

    return lines;
  }
}
