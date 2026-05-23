import 'package:flutter/material.dart';

import '../../models/notebook_experiment_model.dart';
import '../../models/reaction_component_model.dart';
import '../../theme/labmate_theme.dart';

class ReactionDetailsPanel extends StatelessWidget {
  final NotebookExperimentModel experiment;
  final bool compact;

  const ReactionDetailsPanel({
    super.key,
    required this.experiment,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final setupRows = [
      _ReactionSummaryRow(
        label: 'Reaction Title',
        value: experiment.reactionTitle,
      ),
      _ReactionSummaryRow(
        label: 'Starting Material',
        value: experiment.startingMaterial,
      ),
      _ReactionSummaryRow(label: 'Reagents', value: experiment.reagents),
      _ReactionSummaryRow(label: 'Catalyst', value: experiment.catalyst),
    ];
    final conditionChips = [
      _ConditionValue(label: 'Solvent', value: experiment.solvent),
      _ConditionValue(label: 'Temperature', value: experiment.temperature),
      _ConditionValue(label: 'Time', value: experiment.time),
      _ConditionValue(label: 'Atmosphere', value: experiment.atmosphere),
      _ConditionValue(label: 'Scale', value: experiment.scale),
    ];

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
          const _PanelHeader(
            icon: Icons.science_outlined,
            title: 'Reaction Workspace',
            subtitle: 'Scheme, setup, and structured component table',
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

  const _PanelHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        width: 1060,
        decoration: BoxDecoration(
          color: palette.panelAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.border)),
              ),
              child: const Row(
                children: [
                  _ReactionTableHeaderCell('Component', 160),
                  _ReactionTableHeaderCell('Role', 120),
                  _ReactionTableHeaderCell('Formula / Notes', 150),
                  _ReactionTableHeaderCell('mmol', 74),
                  _ReactionTableHeaderCell('Equiv', 74),
                  _ReactionTableHeaderCell('Amount', 84),
                  _ReactionTableHeaderCell('Unit', 80),
                  _ReactionTableHeaderCell('Supplier / Source', 150),
                  _ReactionTableHeaderCell('Remarks', 156),
                ],
              ),
            ),
            ...components.asMap().entries.map((entry) {
              final index = entry.key;
              final component = entry.value;
              final isLast = index == components.length - 1;

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
                    ),
                    _ReactionTableValueCell(width: 120, value: component.role),
                    _ReactionTableValueCell(
                      width: 150,
                      value: component.formulaOrNotes,
                    ),
                    _ReactionTableValueCell(width: 74, value: component.mmol),
                    _ReactionTableValueCell(width: 74, value: component.equiv),
                    _ReactionTableValueCell(width: 84, value: component.amount),
                    _ReactionTableValueCell(width: 80, value: component.unit),
                    _ReactionTableValueCell(
                      width: 150,
                      value: component.supplierOrSource,
                    ),
                    _ReactionTableValueCell(
                      width: 156,
                      value: component.remarks,
                    ),
                  ],
                ),
              );
            }),
          ],
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
                      label: 'Amount',
                      value: component.amount,
                      compact: compact,
                    ),
                    _ComponentMetaChip(
                      label: 'Unit',
                      value: component.unit,
                      compact: compact,
                    ),
                    _ComponentMetaChip(
                      label: 'mmol',
                      value: component.mmol,
                      compact: compact,
                    ),
                    _ComponentMetaChip(
                      label: 'Equiv',
                      value: component.equiv,
                      compact: compact,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _ComponentDetailLine(
                  label: 'Formula / Notes',
                  value: component.formulaOrNotes,
                ),
                _ComponentDetailLine(
                  label: 'Supplier / Source',
                  value: component.supplierOrSource,
                ),
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

  const _ReactionTableValueCell({
    required this.width,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final cleanValue = value.trim();
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    return SizedBox(
      width: width,
      child: Text(
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
