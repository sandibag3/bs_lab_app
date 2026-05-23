import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_state.dart';
import '../models/notebook_experiment_model.dart';
import '../models/notebook_project_model.dart';
import '../services/firestore_access_guard.dart';
import '../services/lab_notebook_service.dart';
import '../theme/labmate_theme.dart';
import '../widgets/notebook/notebook_view_mode_selector.dart';
import '../widgets/responsive_page_container.dart';
import 'add_experiment_screen.dart';
import 'experiment_detail_screen.dart';

class NotebookProjectDetailScreen extends StatelessWidget {
  final AppState appState;
  final NotebookProjectModel project;
  final String notebookOwnerUid;
  final String notebookOwnerLabel;
  final bool isReadOnly;
  final LabNotebookService _labNotebookService = LabNotebookService();

  NotebookProjectDetailScreen({
    super.key,
    required this.appState,
    required this.project,
    required this.notebookOwnerUid,
    required this.notebookOwnerLabel,
    required this.isReadOnly,
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
        builder: (_) => AddExperimentScreen(
          appState: appState,
          project: project,
          notebookOwnerUid: notebookOwnerUid,
          notebookOwnerEmail: project.ownerEmail,
        ),
      ),
    );
  }

  Widget _buildReadOnlyBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBBF24).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFBBF24).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.visibility_outlined,
            color: Color(0xFFFBBF24),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Read-only view: you are viewing another member\'s notebook.',
              style: TextStyle(
                color: context.labmate.mutedText,
                fontSize: 12.4,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
                      isReadOnly ? 'Project Viewer' : 'Project Workspace',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 15.0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isReadOnly
                          ? 'Read-only experiment list'
                          : 'Experiments and reaction log',
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
            icon: Icons.person_outline_rounded,
            label: notebookOwnerLabel,
            accent: isReadOnly
                ? const Color(0xFFFBBF24)
                : const Color(0xFF5EEAD4),
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
                    label: 'Mode',
                    value: isReadOnly ? 'Read-only' : 'Owner',
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
                  label: project.ownerLabel,
                ),
              ],
            ),
          if (isWide) ...[
            const SizedBox(height: 8),
            _ProjectBadge(
              icon: Icons.schedule_rounded,
              label: _formatDate(project.createdAt),
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

  Widget _buildExperimentsPanel(
    BuildContext context,
    List<NotebookExperimentModel> experiments,
  ) {
    return _ExperimentListPanel(
      appState: appState,
      project: project,
      notebookOwnerUid: notebookOwnerUid,
      notebookOwnerLabel: notebookOwnerLabel,
      isReadOnly: isReadOnly,
      experiments: experiments,
      formatDate: _formatDate,
      statusColor: _statusColor,
    );
  }

  Widget _buildWorkspace(BuildContext context) {
    final labId = appState.resolveWriteLabId(project.labId);

    return StreamBuilder<List<NotebookExperimentModel>>(
      stream: _labNotebookService.getExperiments(
        labId: labId,
        projectId: project.id,
        notebookOwnerUid: notebookOwnerUid,
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
              canCreate:
                  !isReadOnly && appState.authenticatedUserId.trim().isNotEmpty,
              experimentCount: experiments.length,
              isWide: isWide,
            );
            final panel = _buildExperimentsPanel(context, experiments);
            final content = isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 292, child: rail),
                      const SizedBox(width: 10),
                      Expanded(child: panel),
                    ],
                  )
                : Column(
                    children: [
                      rail,
                      const SizedBox(height: 10),
                      Expanded(child: panel),
                    ],
                  );

            if (!isReadOnly) {
              return content;
            }

            return Column(
              children: [
                _buildReadOnlyBanner(context),
                const SizedBox(height: 10),
                Expanded(child: content),
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
    final canCreate =
        appState.authenticatedUserId.trim().isNotEmpty && !isReadOnly;
    final isMobileWidth = MediaQuery.sizeOf(context).width < 900;

    return Scaffold(
      appBar: AppBar(title: const Text('Notebook Project')),
      floatingActionButton: canQuery && isMobileWidth && canCreate
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

class _ExperimentListPanel extends StatefulWidget {
  final AppState appState;
  final NotebookProjectModel project;
  final String notebookOwnerUid;
  final String notebookOwnerLabel;
  final bool isReadOnly;
  final List<NotebookExperimentModel> experiments;
  final String Function(Timestamp timestamp) formatDate;
  final Color Function(String status) statusColor;

  const _ExperimentListPanel({
    required this.appState,
    required this.project,
    required this.notebookOwnerUid,
    required this.notebookOwnerLabel,
    required this.isReadOnly,
    required this.experiments,
    required this.formatDate,
    required this.statusColor,
  });

  @override
  State<_ExperimentListPanel> createState() => _ExperimentListPanelState();
}

class _ExperimentListPanelState extends State<_ExperimentListPanel> {
  static const _prefsKey = 'lab_notebook_experiment_view_mode';

  NotebookViewMode _viewMode = NotebookViewMode.list;

  @override
  void initState() {
    super.initState();
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = notebookViewModeFromStorage(
      prefs.getString(_prefsKey),
      fallback: NotebookViewMode.list,
    );

    if (!mounted || savedMode == _viewMode) {
      return;
    }

    setState(() {
      _viewMode = savedMode;
    });
  }

  Future<void> _setViewMode(NotebookViewMode mode) async {
    if (_viewMode == mode) {
      return;
    }

    setState(() {
      _viewMode = mode;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.storageValue);
  }

  int _columnsForWidth(double width) {
    switch (_viewMode) {
      case NotebookViewMode.small:
        if (width >= 1360) return 4;
        if (width >= 980) return 3;
        if (width >= 700) return 2;
        return 1;
      case NotebookViewMode.medium:
        if (width >= 1220) return 3;
        if (width >= 760) return 2;
        return 1;
      case NotebookViewMode.large:
        if (width >= 1380) return 3;
        if (width >= 920) return 2;
        return 1;
      case NotebookViewMode.list:
        return 1;
    }
  }

  double _gridItemExtent() {
    switch (_viewMode) {
      case NotebookViewMode.small:
        return 174;
      case NotebookViewMode.medium:
        return 210;
      case NotebookViewMode.large:
        return 246;
      case NotebookViewMode.list:
        return 142;
    }
  }

  void _openExperiment(
    BuildContext context,
    NotebookExperimentModel experiment,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExperimentDetailScreen(
          appState: widget.appState,
          project: widget.project,
          experimentId: experiment.id,
          notebookOwnerUid: widget.notebookOwnerUid,
          notebookOwnerLabel: widget.notebookOwnerLabel,
          isReadOnly: widget.isReadOnly,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final label = status.trim().isEmpty ? 'Unknown' : status.trim();
    final color = widget.statusColor(label);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildExperimentListRow(
    BuildContext context,
    NotebookExperimentModel experiment,
  ) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final reactionSummary = experiment.reactionTitle.trim().isNotEmpty
        ? experiment.reactionTitle.trim()
        : experiment.aim.trim();

    return Material(
      color: palette.panelAlt,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openExperiment(context, experiment),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.science_outlined,
                  color: Color(0xFF7DD3FC),
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                                  fontSize: 11.0,
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
                                  color: colorScheme.onSurface,
                                  fontSize: 14.1,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(experiment.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      reactionSummary.isEmpty
                          ? 'No reaction summary yet. Open the record to add setup details.'
                          : reactionSummary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: reactionSummary.isEmpty
                            ? palette.subtleText
                            : palette.mutedText,
                        fontSize: 12.0,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ProjectBadge(
                          icon: Icons.event_rounded,
                          label: widget.formatDate(experiment.date),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExperimentGridCard(
    BuildContext context,
    NotebookExperimentModel experiment,
  ) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final reactionSummary = experiment.reactionTitle.trim().isNotEmpty
        ? experiment.reactionTitle.trim()
        : experiment.aim.trim();
    final isSmall = _viewMode == NotebookViewMode.small;
    final isLarge = _viewMode == NotebookViewMode.large;

    return Material(
      color: palette.panelAlt,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openExperiment(context, experiment),
        child: Container(
          padding: EdgeInsets.all(isSmall ? 11 : 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
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
                            fontSize: 11.0,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          experiment.title.trim().isEmpty
                              ? 'Untitled experiment'
                              : experiment.title.trim(),
                          maxLines: isLarge ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: isLarge ? 14.6 : 14.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(experiment.status),
                ],
              ),
              SizedBox(height: isSmall ? 8 : 10),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isSmall ? 9 : 11),
                decoration: BoxDecoration(
                  color: palette.panel,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  reactionSummary.isEmpty
                      ? 'No reaction summary yet.'
                      : reactionSummary,
                  maxLines: isSmall
                      ? 2
                      : isLarge
                      ? 4
                      : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: reactionSummary.isEmpty
                        ? palette.subtleText
                        : palette.mutedText,
                    fontSize: isSmall ? 11.6 : 12.1,
                    height: 1.35,
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
                    label: widget.formatDate(experiment.date),
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
                  if (isLarge && experiment.reactionComponents.isNotEmpty)
                    _ProjectBadge(
                      icon: Icons.table_rows_rounded,
                      label: '${experiment.reactionComponents.length} rows',
                    ),
                ],
              ),
              const Spacer(),
              SizedBox(height: isSmall ? 8 : 10),
              Text(
                experiment.startingMaterial.trim().isEmpty
                    ? 'Open workspace'
                    : experiment.startingMaterial.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.subtleText,
                  fontSize: 11.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (widget.experiments.isEmpty) {
      return Center(
        child: _ProjectNotice(
          icon: Icons.science_outlined,
          title: 'No experiments in this project yet',
          message: widget.isReadOnly
              ? '${widget.notebookOwnerLabel} has not added any experiments to this project yet.'
              : 'Add the first experiment to start documenting reaction setup, results, and daily updates.',
          accent: const Color(0xFF38BDF8),
        ),
      );
    }

    if (_viewMode == NotebookViewMode.list) {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: widget.experiments.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return _buildExperimentListRow(context, widget.experiments[index]);
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsForWidth(constraints.maxWidth);

        if (columns == 1) {
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: widget.experiments.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return SizedBox(
                height: _gridItemExtent(),
                child: _buildExperimentGridCard(
                  context,
                  widget.experiments[index],
                ),
              );
            },
          );
        }

        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: widget.experiments.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: _gridItemExtent(),
          ),
          itemBuilder: (context, index) {
            return _buildExperimentGridCard(context, widget.experiments[index]);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

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
          LayoutBuilder(
            builder: (context, constraints) {
              final compactHeader = constraints.maxWidth < 760;
              const title = 'Experiments';
              final subtitle = widget.isReadOnly
                  ? 'Read-only experiment list'
                  : 'Reaction records inside this project';
              final controls = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ProjectBadge(
                    icon: Icons.science_outlined,
                    label: '${widget.experiments.length}',
                    accent: const Color(0xFF5EEAD4),
                  ),
                  const SizedBox(width: 8),
                  NotebookViewModeSelector(
                    value: _viewMode,
                    onChanged: _setViewMode,
                  ),
                ],
              );

              if (compactHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 15.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: palette.subtleText,
                        fontSize: 11.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    controls,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 15.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: palette.subtleText,
                            fontSize: 11.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(child: controls),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildBody(context)),
        ],
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
