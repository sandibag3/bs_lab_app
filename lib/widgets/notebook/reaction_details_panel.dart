import 'package:flutter/material.dart';

import '../../models/notebook_experiment_model.dart';
import '../../models/reaction_component_model.dart';
import '../../theme/labmate_theme.dart';

double? _parseReactionNumber(String rawValue) {
  final normalized = rawValue.trim().replaceAll(',', '.');
  if (normalized.isEmpty) {
    return null;
  }

  return double.tryParse(normalized);
}

double? _limitingReagentReferenceMmol(List<ReactionComponentModel> components) {
  for (final component in components) {
    if (!component.isLimitingReagent) {
      continue;
    }

    final limitingMmol = _parseReactionNumber(component.mmol);
    if (limitingMmol == null || limitingMmol <= 0) {
      return null;
    }

    return limitingMmol;
  }

  return null;
}

String? _calculatedEquivLabel(
  List<ReactionComponentModel> components,
  ReactionComponentModel component,
) {
  final limitingMmol = _limitingReagentReferenceMmol(components);
  final rowMmol = _parseReactionNumber(component.mmol);
  if (limitingMmol == null || rowMmol == null || limitingMmol <= 0) {
    return null;
  }

  final calculatedEquiv = rowMmol / limitingMmol;
  return 'calc: ${calculatedEquiv.toStringAsFixed(2)} equiv';
}

String? _calculatedMolPercentLabel(
  List<ReactionComponentModel> components,
  ReactionComponentModel component,
) {
  if (component.role.trim().toLowerCase() != 'catalyst') {
    return null;
  }

  final limitingMmol = _limitingReagentReferenceMmol(components);
  final catalystMmol = _parseReactionNumber(component.mmol);
  if (limitingMmol == null || catalystMmol == null || limitingMmol <= 0) {
    return null;
  }

  final molPercent = (catalystMmol / limitingMmol) * 100;
  return 'calc: ${molPercent.toStringAsFixed(1)} mol%';
}

String? _calculatedAmountLabel(ReactionComponentModel component) {
  final mmol = _parseReactionNumber(component.mmol);
  final molecularWeight = _parseReactionNumber(component.molecularWeight);
  if (mmol == null || molecularWeight == null) {
    return null;
  }

  final amountMg = mmol * molecularWeight;
  return 'calc: ${amountMg.toStringAsFixed(1)} mg';
}

class ReactionDetailsPanel extends StatelessWidget {
  final NotebookExperimentModel experiment;
  final bool compact;
  final Widget? headerTrailing;

  const ReactionDetailsPanel({
    super.key,
    required this.experiment,
    this.compact = false,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final setupRows = <_ReactionSummaryRow>[
      _ReactionSummaryRow(
        label: 'Reaction Title',
        value: experiment.reactionTitle,
      ),
      if (experiment.startingMaterial.trim().isNotEmpty)
        _ReactionSummaryRow(
          label: 'Starting Material',
          value: experiment.startingMaterial,
        ),
      if (experiment.reagents.trim().isNotEmpty)
        _ReactionSummaryRow(label: 'Reagents', value: experiment.reagents),
      if (experiment.catalyst.trim().isNotEmpty)
        _ReactionSummaryRow(label: 'Catalyst', value: experiment.catalyst),
    ];
    final conditionChips = <_ConditionValue>[
      _ConditionValue(label: 'Solvent', value: experiment.solvent),
      _ConditionValue(label: 'Temperature', value: experiment.temperature),
      if (experiment.startTime.trim().isNotEmpty)
        _ConditionValue(label: 'Start time', value: experiment.startTime),
      if (experiment.endTime.trim().isNotEmpty)
        _ConditionValue(label: 'End time', value: experiment.endTime),
      if (experiment.startTime.trim().isEmpty &&
          experiment.endTime.trim().isEmpty &&
          experiment.time.trim().isNotEmpty)
        _ConditionValue(label: 'Time', value: experiment.time),
      _ConditionValue(label: 'Atmosphere', value: experiment.atmosphere),
      _ConditionValue(label: 'Scale', value: experiment.scale),
    ];
    final hasLegacySetupFields =
        experiment.startingMaterial.trim().isNotEmpty ||
        experiment.reagents.trim().isNotEmpty ||
        experiment.catalyst.trim().isNotEmpty ||
        experiment.scale.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 13),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.science_outlined,
            title: 'Reaction Workspace',
            subtitle: 'Scheme, setup, and structured component table',
            trailing: headerTrailing,
          ),
          SizedBox(height: compact ? 10 : 12),
          _SchemePlaceholder(
            compact: compact,
            reactionTitle: experiment.reactionTitle.trim(),
          ),
          SizedBox(height: compact ? 10 : 12),
          const _SectionLabel('Reaction Setup'),
          const SizedBox(height: 8),
          _SetupTable(rows: setupRows, compact: compact),
          if (hasLegacySetupFields) ...[
            SizedBox(height: compact ? 8 : 10),
            _LegacySetupNote(compact: compact),
          ],
          SizedBox(height: compact ? 10 : 12),
          const _SectionLabel('Reaction Table'),
          const SizedBox(height: 8),
          _ReactionComponentsPanel(
            components: experiment.reactionComponents,
            compact: compact,
          ),
          SizedBox(height: compact ? 10 : 12),
          const _SectionLabel('Conditions'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: conditionChips.map((item) {
              return _ConditionChip(item: item, compact: compact);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _PanelHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final palette = context.labmate;
    return Row(
      children: [
        Container(
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            color: const Color(0xFF14B8A6).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF5EEAD4)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 13.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: palette.subtleText,
                  fontSize: 11.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class _SchemePlaceholder extends StatelessWidget {
  final bool compact;
  final String reactionTitle;

  const _SchemePlaceholder({
    required this.compact,
    required this.reactionTitle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    return Container(
      height: compact ? 122 : 156,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: palette.panel,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.device_hub_rounded,
              color: Color(0xFF5EEAD4),
              size: 20,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Reaction Scheme',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add scheme / ChemDraw image later',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.subtleText,
              fontSize: 11.8,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (reactionTitle.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              reactionTitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF5EEAD4),
                fontSize: 11.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    return Text(
      text,
      style: TextStyle(
        color: palette.subtleText,
        fontSize: 11.2,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LegacySetupNote extends StatelessWidget {
  final bool compact;

  const _LegacySetupNote({required this.compact});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 11),
      decoration: BoxDecoration(
        color: const Color(0xFF38BDF8).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.archive_outlined,
            size: 15,
            color: Color(0xFF7DD3FC),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'These legacy setup text fields are shown for older records. Use the reaction table as the primary planning surface for new experiments.',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: compact ? 11.5 : 11.8,
                height: 1.36,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupTable extends StatelessWidget {
  final List<_ReactionSummaryRow> rows;
  final bool compact;

  const _SetupTable({required this.rows, required this.compact});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          final isLast = index == rows.length - 1;

          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: compact ? 10 : 11,
            ),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(bottom: BorderSide(color: palette.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: compact ? 102 : 118,
                  child: Text(
                    row.label,
                    style: TextStyle(
                      color: palette.subtleText,
                      fontSize: 11.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _displayValue(row.value),
                    style: TextStyle(
                      color: row.value.trim().isEmpty
                          ? palette.subtleText
                          : colorScheme.onSurface,
                      fontSize: compact ? 12.0 : 12.4,
                      fontWeight: FontWeight.w600,
                      height: 1.32,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _displayValue(String value) {
    final cleanValue = value.trim();
    return cleanValue.isEmpty ? 'Not added yet.' : cleanValue;
  }
}

class _ReactionComponentsPanel extends StatelessWidget {
  final List<ReactionComponentModel> components;
  final bool compact;

  const _ReactionComponentsPanel({
    required this.components,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    if (components.isEmpty) {
      return _ReactionTableEmptyState(compact: compact);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktopTable = constraints.maxWidth >= 760;
        return useDesktopTable
            ? _ReactionComponentsDesktopTable(
                components: components,
                compact: compact,
              )
            : _ReactionComponentsMobileCards(
                components: components,
                compact: compact,
              );
      },
    );
  }
}

class _ReactionTableEmptyState extends StatelessWidget {
  final bool compact;

  const _ReactionTableEmptyState({required this.compact});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        'No structured reaction table rows added yet.',
        style: TextStyle(
          color: palette.mutedText,
          fontSize: compact ? 11.8 : 12.2,
          height: 1.4,
        ),
      ),
    );
  }
}

class _ReactionComponentsDesktopTable extends StatelessWidget {
  final List<ReactionComponentModel> components;
  final bool compact;

  const _ReactionComponentsDesktopTable({
    required this.components,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    const desktopTableMinWidth = 1120.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: desktopTableMinWidth),
        child: Container(
          width: desktopTableMinWidth,
          decoration: BoxDecoration(
            color: palette.panelAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: palette.border)),
                ),
                child: const Row(
                  children: [
                    _ReactionTableHeaderCell('Component', 160),
                    _ReactionTableHeaderCell('Role', 120),
                    _ReactionTableHeaderCell('Equiv', 74),
                    _ReactionTableHeaderCell('mmol', 74),
                    _ReactionTableHeaderCell('Molecular weight', 112),
                    _ReactionTableHeaderCell('Amount', 84),
                    _ReactionTableHeaderCell('Unit', 80),
                    _ReactionTableHeaderCell('Density', 84),
                    _ReactionTableHeaderCell('Volume', 84),
                    _ReactionTableHeaderCell('Remarks', 208),
                  ],
                ),
              ),
              ...components.asMap().entries.map((entry) {
                final index = entry.key;
                final component = entry.value;
                final isLast = index == components.length - 1;
                final calculatedEquivLabel = _calculatedEquivLabel(
                  components,
                  component,
                );
                final calculatedMolPercentLabel = _calculatedMolPercentLabel(
                  components,
                  component,
                );
                final calculatedAmountLabel = _calculatedAmountLabel(component);

                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: compact ? 10 : 11,
                  ),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : Border(bottom: BorderSide(color: palette.border)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ReactionTableValueCell(
                        width: 160,
                        value: component.componentName,
                        strong: true,
                        isLimitingReagent: component.isLimitingReagent,
                      ),
                      _ReactionTableValueCell(
                        width: 120,
                        value: component.role,
                      ),
                      _ReactionTableValueCell(
                        width: 74,
                        value: component.equiv,
                        supportingText: calculatedEquivLabel,
                      ),
                      _ReactionTableValueCell(
                        width: 74,
                        value: component.mmol,
                        supportingText: calculatedMolPercentLabel,
                      ),
                      _ReactionTableValueCell(
                        width: 112,
                        value: component.molecularWeight,
                      ),
                      _ReactionTableValueCell(
                        width: 84,
                        value: component.amount,
                        supportingText: calculatedAmountLabel,
                      ),
                      _ReactionTableValueCell(width: 80, value: component.unit),
                      _ReactionTableValueCell(
                        width: 84,
                        value: component.density,
                      ),
                      _ReactionTableValueCell(
                        width: 84,
                        value: component.volume,
                      ),
                      _ReactionTableValueCell(
                        width: 208,
                        value: component.remarks,
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactionComponentsMobileCards extends StatelessWidget {
  final List<ReactionComponentModel> components;
  final bool compact;

  const _ReactionComponentsMobileCards({
    required this.components,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Column(
      children: components.asMap().entries.map((entry) {
        final index = entry.key;
        final component = entry.value;
        final calculatedEquivLabel = _calculatedEquivLabel(
          components,
          component,
        );
        final calculatedMolPercentLabel = _calculatedMolPercentLabel(
          components,
          component,
        );
        final calculatedAmountLabel = _calculatedAmountLabel(component);

        return Padding(
          padding: EdgeInsets.only(
            bottom: index == components.length - 1 ? 0 : 8,
          ),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(compact ? 11 : 12),
            decoration: BoxDecoration(
              color: palette.panelAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  component.componentName.trim().isEmpty
                      ? 'Unnamed component'
                      : component.componentName.trim(),
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: compact ? 12.6 : 13.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (component.isLimitingReagent) ...[
                  const SizedBox(height: 6),
                  const _LimitingBadge(compact: true),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ComponentMetaChip(
                      label: 'Role',
                      value: component.role,
                      compact: compact,
                    ),
                    _ComponentMetaChip(
                      label: 'Equiv',
                      value: component.equiv,
                      compact: compact,
                    ),
                    if (calculatedEquivLabel != null)
                      _ComponentMetaChip(
                        label: 'Calc',
                        value: calculatedEquivLabel.replaceFirst('calc: ', ''),
                        compact: compact,
                      ),
                    if (calculatedMolPercentLabel != null)
                      _ComponentMetaChip(
                        label: 'Mol%',
                        value: calculatedMolPercentLabel.replaceFirst(
                          'calc: ',
                          '',
                        ),
                        compact: compact,
                      ),
                    _ComponentMetaChip(
                      label: 'mmol',
                      value: component.mmol,
                      compact: compact,
                    ),
                    _ComponentMetaChip(
                      label: 'Mol. wt.',
                      value: component.molecularWeight,
                      compact: compact,
                    ),
                    _ComponentMetaChip(
                      label: 'Amount',
                      value: component.amount,
                      compact: compact,
                    ),
                    if (calculatedAmountLabel != null)
                      _ComponentMetaChip(
                        label: 'Calc Amt',
                        value: calculatedAmountLabel.replaceFirst('calc: ', ''),
                        compact: compact,
                      ),
                    _ComponentMetaChip(
                      label: 'Unit',
                      value: component.unit,
                      compact: compact,
                    ),
                    _ComponentMetaChip(
                      label: 'Density',
                      value: component.density,
                      compact: compact,
                    ),
                    _ComponentMetaChip(
                      label: 'Volume',
                      value: component.volume,
                      compact: compact,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _ComponentDetailLine(
                  label: 'Remarks',
                  value: component.remarks,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ReactionTableHeaderCell extends StatelessWidget {
  final String label;
  final double width;

  const _ReactionTableHeaderCell(this.label, this.width);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: TextStyle(
          color: context.labmate.subtleText,
          fontSize: 10.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReactionTableValueCell extends StatelessWidget {
  final double width;
  final String value;
  final bool strong;
  final bool isLimitingReagent;
  final String? supportingText;

  const _ReactionTableValueCell({
    required this.width,
    required this.value,
    this.strong = false,
    this.isLimitingReagent = false,
    this.supportingText,
  });

  @override
  Widget build(BuildContext context) {
    final cleanValue = value.trim();
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cleanValue.isEmpty ? '-' : cleanValue,
            style: TextStyle(
              color: cleanValue.isEmpty
                  ? palette.subtleText
                  : colorScheme.onSurface,
              fontSize: 12.0,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (supportingText != null) ...[
            const SizedBox(height: 5),
            Text(
              supportingText!,
              style: const TextStyle(
                color: Color(0xFF5EEAD4),
                fontSize: 10.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (isLimitingReagent) ...[
            const SizedBox(height: 6),
            const _LimitingBadge(compact: true),
          ],
        ],
      ),
    );
  }
}

class _LimitingBadge extends StatelessWidget {
  final bool compact;

  const _LimitingBadge({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 9,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF14B8A6).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF14B8A6).withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        'Limiting',
        style: TextStyle(
          color: const Color(0xFF5EEAD4),
          fontSize: compact ? 10.4 : 10.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ComponentMetaChip extends StatelessWidget {
  final String label;
  final String value;
  final bool compact;

  const _ComponentMetaChip({
    required this.label,
    required this.value,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final cleanValue = value.trim();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 10,
        vertical: compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        '$label: ${cleanValue.isEmpty ? '-' : cleanValue}',
        style: TextStyle(
          color: cleanValue.isEmpty ? palette.subtleText : palette.mutedText,
          fontSize: compact ? 10.8 : 11.1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ComponentDetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _ComponentDetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final cleanValue = value.trim();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: palette.mutedText,
            fontSize: 11.8,
            height: 1.38,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: palette.subtleText,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: cleanValue.isEmpty ? '-' : cleanValue,
              style: TextStyle(
                color: cleanValue.isEmpty
                    ? palette.subtleText
                    : colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  final _ConditionValue item;
  final bool compact;

  const _ConditionChip({required this.item, required this.compact});

  @override
  Widget build(BuildContext context) {
    final hasValue = item.value.trim().isNotEmpty;
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 11,
        vertical: compact ? 8 : 9,
      ),
      decoration: BoxDecoration(
        color: hasValue ? palette.panelAlt : palette.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.label,
            style: TextStyle(
              color: palette.subtleText,
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasValue ? item.value.trim() : 'Not set',
            style: TextStyle(
              color: hasValue
                  ? const Color(0xFFDBEAFE)
                  : colorScheme.onSurface.withValues(alpha: 0.55),
              fontSize: compact ? 11.6 : 12.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionSummaryRow {
  final String label;
  final String value;

  const _ReactionSummaryRow({required this.label, required this.value});
}

class _ConditionValue {
  final String label;
  final String value;

  const _ConditionValue({required this.label, required this.value});
}
