import 'package:flutter/material.dart';

import '../../models/notebook_experiment_model.dart';

class CharacterizationPanel extends StatelessWidget {
  final NotebookExperimentModel experiment;
  final bool compact;

  const CharacterizationPanel({
    super.key,
    required this.experiment,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final sections = [
      _RecordSection(title: 'Procedure', value: experiment.procedure),
      _RecordSection(title: 'Observations', value: experiment.observations),
      _RecordSection(title: 'Workup', value: experiment.workup),
      _RecordSection(title: 'Purification', value: experiment.purification),
      _RecordSection(title: 'Yield', value: experiment.yieldText),
      _RecordSection(
        title: 'Characterization',
        value: experiment.characterization,
      ),
      _RecordSection(title: 'Conclusion', value: experiment.conclusion),
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
            icon: Icons.fact_check_outlined,
            title: 'Record and Results',
            subtitle: 'Procedure, outcome, and analysis',
          ),
          SizedBox(height: compact ? 10 : 12),
          Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: Column(
              children: sections.map((section) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RecordTile(section: section, compact: compact),
                );
              }).toList(),
            ),
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

class _RecordTile extends StatelessWidget {
  final _RecordSection section;
  final bool compact;

  const _RecordTile({required this.section, required this.compact});

  @override
  Widget build(BuildContext context) {
    final preview = _previewText(section.value);
    final cleanValue = section.value.trim();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111C34),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: compact ? 1 : 2,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        iconColor: const Color(0xFF5EEAD4),
        collapsedIconColor: Colors.white54,
        title: Text(
          section.title,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 12.6 : 13.0,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cleanValue.isEmpty ? Colors.white38 : Colors.white60,
              fontSize: compact ? 11.4 : 11.8,
            ),
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              cleanValue.isEmpty ? 'Not recorded yet.' : cleanValue,
              style: TextStyle(
                color: cleanValue.isEmpty ? Colors.white38 : Colors.white70,
                fontSize: compact ? 12.0 : 12.4,
                height: 1.42,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _previewText(String value) {
    final compactValue = value.replaceAll('\n', ' ').trim();
    if (compactValue.isEmpty) {
      return 'Not recorded yet.';
    }
    if (compactValue.length <= 82) {
      return compactValue;
    }

    return '${compactValue.substring(0, 79)}...';
  }
}

class _RecordSection {
  final String title;
  final String value;

  const _RecordSection({required this.title, required this.value});
}
