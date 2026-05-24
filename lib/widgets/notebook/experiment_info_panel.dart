import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/notebook_experiment_model.dart';
import '../../models/notebook_project_model.dart';
import '../../theme/labmate_theme.dart';

class ExperimentInfoPanel extends StatelessWidget {
  final NotebookProjectModel project;
  final NotebookExperimentModel experiment;
  final String Function(Timestamp timestamp) formatDateTime;
  final Color statusColor;
  final bool compact;
  final Widget? headerTrailing;

  const ExperimentInfoPanel({
    super.key,
    required this.project,
    required this.experiment,
    required this.formatDateTime,
    required this.statusColor,
    this.compact = false,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final projectTitle = project.title.trim().isEmpty
        ? 'Untitled project'
        : project.title.trim();
    final aim = experiment.aim.trim();
    final projectDescription = project.description.trim();

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
          _RailHeader(
            icon: Icons.space_dashboard_rounded,
            title: 'Experiment Rail',
            subtitle: 'Metadata and context',
            trailing: headerTrailing,
          ),
          SizedBox(height: compact ? 10 : 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                label: experiment.status.trim().isEmpty
                    ? 'Unknown'
                    : experiment.status.trim(),
                color: statusColor,
              ),
              _MetaPill(
                icon: Icons.schedule_rounded,
                label: 'Updated ${formatDateTime(experiment.updatedAt)}',
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 12),
          _MiniCard(
            title: 'Project',
            value: projectTitle,
            accent: const Color(0xFF5EEAD4),
          ),
          SizedBox(height: compact ? 8 : 10),
          _MiniCard(
            title: 'Experiment',
            value: experiment.experimentCode.trim().isEmpty
                ? 'Experiment'
                : experiment.experimentCode.trim(),
          ),
          SizedBox(height: compact ? 10 : 12),
          _InfoStack(
            rows: [
              _InfoValue(label: 'Created by', value: experiment.creatorLabel),
              _InfoValue(
                label: 'Created',
                value: formatDateTime(experiment.createdAt),
              ),
              _InfoValue(
                label: 'Updated',
                value: formatDateTime(experiment.updatedAt),
              ),
              _InfoValue(label: 'Date', value: formatDateTime(experiment.date)),
            ],
          ),
          SizedBox(height: compact ? 10 : 12),
          _SectionBlock(
            title: 'Aim',
            value: aim,
            emptyMessage: 'Aim not added yet.',
            compact: compact,
          ),
          if (projectDescription.isNotEmpty) ...[
            SizedBox(height: compact ? 10 : 12),
            _SectionBlock(
              title: 'Project Notes',
              value: projectDescription,
              emptyMessage: 'Project notes not added yet.',
              compact: compact,
            ),
          ],
        ],
      ),
    );
  }
}

class _RailHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _RailHeader({
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
                  fontSize: 13.6,
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

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.6,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.8, color: const Color(0xFF5EEAD4)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 11.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String title;
  final String value;
  final Color? accent;

  const _MiniCard({required this.title, required this.value, this.accent});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: palette.subtleText,
              fontSize: 11.0,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: accent ?? colorScheme.onSurface,
              fontSize: 12.8,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoStack extends StatelessWidget {
  final List<_InfoValue> rows;

  const _InfoStack({required this.rows});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          final isLast = index == rows.length - 1;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(bottom: BorderSide(color: palette.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 74,
                  child: Text(
                    row.label,
                    style: TextStyle(
                      color: palette.subtleText,
                      fontSize: 11.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    row.value,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 12.1,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
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
}

class _InfoValue {
  final String label;
  final String value;

  const _InfoValue({required this.label, required this.value});
}

class _SectionBlock extends StatelessWidget {
  final String title;
  final String value;
  final String emptyMessage;
  final bool compact;

  const _SectionBlock({
    required this.title,
    required this.value,
    required this.emptyMessage,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final cleanValue = value.trim();
    final palette = context.labmate;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 11 : 12),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: palette.subtleText,
              fontSize: 11.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            cleanValue.isEmpty ? emptyMessage : cleanValue,
            style: TextStyle(
              color: cleanValue.isEmpty
                  ? palette.subtleText
                  : palette.mutedText,
              fontSize: compact ? 12.0 : 12.4,
              height: 1.38,
            ),
          ),
        ],
      ),
    );
  }
}
