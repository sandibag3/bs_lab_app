import 'package:flutter/material.dart';

import '../../models/notebook_experiment_model.dart';

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
    final tableRows = [
      _ReactionRow(label: 'Reaction Title', value: experiment.reactionTitle),
      _ReactionRow(
        label: 'Starting Material',
        value: experiment.startingMaterial,
      ),
      _ReactionRow(label: 'Reagents', value: experiment.reagents),
      _ReactionRow(label: 'Catalyst', value: experiment.catalyst),
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
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(
            icon: Icons.science_outlined,
            title: 'Reaction Workspace',
            subtitle: 'Scheme and setup',
          ),
          SizedBox(height: compact ? 10 : 12),
          _SchemePlaceholder(
            compact: compact,
            reactionTitle: experiment.reactionTitle.trim(),
          ),
          SizedBox(height: compact ? 10 : 12),
          const _SectionLabel('Reaction Setup'),
          const SizedBox(height: 8),
          _SetupTable(rows: tableRows, compact: compact),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white54,
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
    return Container(
      height: compact ? 122 : 156,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111C34),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.device_hub_rounded,
              color: Color(0xFF5EEAD4),
              size: 20,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Reaction Scheme',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add scheme / ChemDraw image later',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
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
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 11.2,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SetupTable extends StatelessWidget {
  final List<_ReactionRow> rows;
  final bool compact;

  const _SetupTable({required this.rows, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111C34),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
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
                  : Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: compact ? 102 : 118,
                  child: Text(
                    row.label,
                    style: const TextStyle(
                      color: Colors.white54,
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
                          ? Colors.white38
                          : Colors.white,
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

class _ConditionChip extends StatelessWidget {
  final _ConditionValue item;
  final bool compact;

  const _ConditionChip({required this.item, required this.compact});

  @override
  Widget build(BuildContext context) {
    final hasValue = item.value.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 11,
        vertical: compact ? 8 : 9,
      ),
      decoration: BoxDecoration(
        color: hasValue
            ? const Color(0xFF111C34)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasValue ? item.value.trim() : 'Not set',
            style: TextStyle(
              color: hasValue ? const Color(0xFFDBEAFE) : Colors.white38,
              fontSize: compact ? 11.6 : 12.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionRow {
  final String label;
  final String value;

  const _ReactionRow({required this.label, required this.value});
}

class _ConditionValue {
  final String label;
  final String value;

  const _ConditionValue({required this.label, required this.value});
}
