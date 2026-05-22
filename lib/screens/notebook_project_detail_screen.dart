import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/notebook_experiment_model.dart';
import '../models/notebook_project_model.dart';
import '../services/firestore_access_guard.dart';
import '../services/lab_notebook_service.dart';
import '../theme/labmate_theme.dart';
import '../widgets/responsive_page_container.dart';
import 'add_experiment_screen.dart';
import 'experiment_detail_screen.dart';

class NotebookProjectDetailScreen extends StatelessWidget {
  final AppState appState;
  final NotebookProjectModel project;
  final LabNotebookService _labNotebookService = LabNotebookService();

  NotebookProjectDetailScreen({
    super.key,
    required this.appState,
    required this.project,
  });

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'running':
        return const Color(0xFF38BDF8);
      case 'workup pending':
      case 'purification pending':
        return const Color(0xFFFBBF24);
      case 'completed':
        return const Color(0xFF14B8A6);
      case 'failed':
        return const Color(0xFFFB7185);
      case 'repeated':
      case 'optimized':
        return const Color(0xFFA78BFA);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  Future<void> _openAddExperiment(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddExperimentScreen(appState: appState, project: project),
      ),
    );
  }

  Widget _buildProjectRail({
    required BuildContext context,
    required bool canCreate,
    required int experimentCount,
    required bool isWide,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final description = project.description.trim();
    final labLabel = appState.selectedLabName.trim().isEmpty
        ? project.labId
        : appState.selectedLabName.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.folder_special_rounded,
                  color: Color(0xFF5EEAD4),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Project Workspace',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 15.0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Experiments and reaction log',
                      style: TextStyle(
                        color: palette.subtleText,
                        fontSize: 11.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            project.title.trim().isEmpty
                ? 'Untitled project'
                : project.title.trim(),
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 16.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _ProjectBadge(
            icon: Icons.apartment_rounded,
            label: labLabel,
            accent: const Color(0xFF5EEAD4),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: palette.panelAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              description.isEmpty
                  ? 'No project description yet. Start by capturing the first experiment for this project.'
                  : description,
              style: TextStyle(
                color: description.isEmpty
                    ? palette.subtleText
                    : palette.mutedText,
                fontSize: 12.2,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (isWide)
            Row(
              children: [
                Expanded(
                  child: _ProjectMetric(
                    label: 'Experiments',
                    value: experimentCount.toString(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ProjectMetric(
                    label: 'Created',
                    value: _formatDate(project.createdAt),
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ProjectBadge(
                  icon: Icons.science_outlined,
                  label:
                      '$experimentCount experiment${experimentCount == 1 ? '' : 's'}',
                ),
                _ProjectBadge(
                  icon: Icons.schedule_rounded,
                  label: _formatDate(project.createdAt),
                ),
                _ProjectBadge(
                  icon: Icons.person_outline_rounded,
                  label: project.creatorLabel,
                ),
              ],
            ),
          if (isWide) ...[
            const SizedBox(height: 8),
            _ProjectBadge(
              icon: Icons.person_outline_rounded,
              label: project.creatorLabel,
            ),
          ],
          if (canCreate) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openAddExperiment(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Add Experiment',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExperimentCard(
    BuildContext context,
    NotebookExperimentModel experiment,
  ) {
    final statusColor = _statusColor(experiment.status);
    final reactionSummary = experiment.reactionTitle.trim().isNotEmpty
        ? experiment.reactionTitle.trim()
        : experiment.aim.trim();

    return Material(
      color: context.labmate.panelAlt,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExperimentDetailScreen(
                appState: appState,
                project: project,
                experimentId: experiment.id,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.labmate.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          experiment.experimentCode.trim().isEmpty
                              ? 'Experiment'
                              : experiment.experimentCode.trim(),
                          style: const TextStyle(
                            color: Color(0xFF5EEAD4),
                            fontSize: 11.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          experiment.title.trim().isEmpty
                              ? 'Untitled experiment'
                              : experiment.title.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colorScheme.onSurface,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      experiment.status.trim().isEmpty
                          ? 'Unknown'
                          : experiment.status.trim(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: context.labmate.panel,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  reactionSummary.isEmpty
                      ? 'No reaction summary yet. Open the experiment to capture setup and progress.'
                      : reactionSummary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: reactionSummary.isEmpty
                        ? context.labmate.subtleText
                        : context.labmate.mutedText,
                    fontSize: 12.2,
                    height: 1.38,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ProjectBadge(
                    icon: Icons.event_rounded,
                    label: _formatDate(experiment.date),
                  ),
                  if (experiment.solvent.trim().isNotEmpty)
                    _ProjectBadge(
                      icon: Icons.opacity_rounded,
                      label: experiment.solvent.trim(),
                    ),
                  if (experiment.scale.trim().isNotEmpty)
                    _ProjectBadge(
                      icon: Icons.straighten_rounded,
                      label: experiment.scale.trim(),
                    ),
                ],
              ),
              const Spacer(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      experiment.startingMaterial.trim().isEmpty
                          ? 'Open workspace'
                          : experiment.startingMaterial.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.labmate.subtleText,
                        fontSize: 11.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: context.labmate.subtleText,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExperimentsPanel(
    BuildContext context,
    List<NotebookExperimentModel> experiments,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1220
            ? 3
            : width >= 760
            ? 2
            : 1;

        Widget body;
        if (experiments.isEmpty) {
          body = const Center(
            child: _ProjectNotice(
              icon: Icons.science_outlined,
              title: 'No experiments in this project yet',
              message:
                  'Add the first experiment to start documenting reaction setup, results, and daily updates.',
              accent: Color(0xFF38BDF8),
            ),
          );
        } else if (columns == 1) {
          body = ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: experiments.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return SizedBox(
                height: 214,
                child: _buildExperimentCard(context, experiments[index]),
              );
            },
          );
        } else {
          body = GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: experiments.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: columns == 3 ? 1.34 : 1.28,
            ),
            itemBuilder: (context, index) {
              return _buildExperimentCard(context, experiments[index]);
            },
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: context.labmate.panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.labmate.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Experiments',
                          style: TextStyle(
                            color: context.colorScheme.onSurface,
                            fontSize: 15.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Reaction records inside this project',
                          style: TextStyle(
                            color: context.labmate.subtleText,
                            fontSize: 11.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ProjectBadge(
                    icon: Icons.science_outlined,
                    label: '${experiments.length}',
                    accent: const Color(0xFF5EEAD4),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWorkspace(BuildContext context) {
    final labId = appState.resolveWriteLabId(project.labId);

    return StreamBuilder<List<NotebookExperimentModel>>(
      stream: _labNotebookService.getExperiments(
        labId: labId,
        projectId: project.id,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                FirestoreAccessGuard.messageFor(snapshot.error),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.labmate.mutedText, height: 1.4),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final experiments = snapshot.data ?? [];

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            final rail = _buildProjectRail(
              context: context,
              canCreate: true,
              experimentCount: experiments.length,
              isWide: isWide,
            );
            final panel = _buildExperimentsPanel(context, experiments);

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 292, child: rail),
                  const SizedBox(width: 10),
                  Expanded(child: panel),
                ],
              );
            }

            return Column(
              children: [
                rail,
                const SizedBox(height: 10),
                Expanded(child: panel),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canQuery = FirestoreAccessGuard.shouldQueryLabScopedData(
      appState: appState,
    );
    final isMobileWidth = MediaQuery.sizeOf(context).width < 900;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Notebook Project')),
      floatingActionButton: canQuery && isMobileWidth
          ? FloatingActionButton.extended(
              onPressed: () => _openAddExperiment(context),
              backgroundColor: const Color(0xFF14B8A6),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Experiment',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: ResponsivePageContainer(
        maxWidth: 1500,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: canQuery
              ? _buildWorkspace(context)
              : const Center(
                  child: Text(
                    FirestoreAccessGuard.userMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.4),
                  ),
                ),
        ),
      ),
    );
  }
}

class _ProjectNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color accent;

  const _ProjectNotice({
    required this.icon,
    required this.title,
    required this.message,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 28),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 15.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 12.4,
              height: 1.42,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectMetric extends StatelessWidget {
  final String label;
  final String value;

  const _ProjectMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    return Container(
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
            label,
            style: TextStyle(
              color: palette.subtleText,
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 13.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accent;

  const _ProjectBadge({required this.icon, required this.label, this.accent});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: palette.panelAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: accent ?? const Color(0xFF5EEAD4)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent ?? palette.mutedText,
                  fontSize: 11.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
