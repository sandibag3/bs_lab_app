import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/experiment_note_model.dart';
import '../models/notebook_experiment_model.dart';
import '../models/notebook_project_model.dart';
import '../services/firestore_access_guard.dart';
import '../services/lab_notebook_service.dart';
import '../theme/labmate_theme.dart';
import '../widgets/notebook/characterization_panel.dart';
import '../widgets/notebook/experiment_info_panel.dart';
import '../widgets/notebook/experiment_notes_panel.dart';
import '../widgets/notebook/reaction_details_panel.dart';
import '../widgets/responsive_page_container.dart';

class ExperimentDetailScreen extends StatefulWidget {
  final AppState appState;
  final NotebookProjectModel project;
  final String experimentId;

  const ExperimentDetailScreen({
    super.key,
    required this.appState,
    required this.project,
    required this.experimentId,
  });

  @override
  State<ExperimentDetailScreen> createState() => _ExperimentDetailScreenState();
}

class _ExperimentDetailScreenState extends State<ExperimentDetailScreen> {
  final LabNotebookService _labNotebookService = LabNotebookService();
  final TextEditingController _noteController = TextEditingController();

  bool _isSavingNote = false;
  bool _isUpdatingStatus = false;

  String get _labId => widget.appState.resolveWriteLabId(widget.project.labId);

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _formatDateTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
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

  String _createdByValue() {
    final userId = widget.appState.authenticatedUserId.trim();
    if (userId.isNotEmpty) {
      return userId;
    }

    final userEmail = widget.appState.authenticatedUserEmail.trim();
    if (userEmail.isNotEmpty) {
      return userEmail;
    }

    return widget.appState.authenticatedUserName;
  }

  Future<void> _updateStatus(String status) async {
    if (_isUpdatingStatus) {
      return;
    }

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      await _labNotebookService.updateExperimentStatus(
        labId: _labId,
        projectId: widget.project.id,
        experimentId: widget.experimentId,
        status: status,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Status updated to $status.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FirestoreAccessGuard.messageFor(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  Future<void> _addNote() async {
    if (_isSavingNote) {
      return;
    }

    final noteText = _noteController.text.trim();
    if (noteText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a note before saving the update.')),
      );
      return;
    }

    if (_labId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active lab found for this experiment.'),
        ),
      );
      return;
    }

    setState(() {
      _isSavingNote = true;
    });

    try {
      final note = ExperimentNoteModel(
        id: '',
        note: noteText,
        createdBy: _createdByValue(),
        userEmail: widget.appState.authenticatedUserEmail,
        createdAt: Timestamp.now(),
      );

      await _labNotebookService.addExperimentNote(
        labId: _labId,
        projectId: widget.project.id,
        experimentId: widget.experimentId,
        note: note,
      );

      _noteController.clear();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Experiment note added.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FirestoreAccessGuard.messageFor(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingNote = false;
        });
      }
    }
  }

  Stream<List<ExperimentNoteModel>> _notesStream() {
    return _labNotebookService.getExperimentNotes(
      labId: _labId,
      projectId: widget.project.id,
      experimentId: widget.experimentId,
    );
  }

  Widget _buildHeaderBar(
    NotebookExperimentModel experiment, {
    required bool isWide,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final safeStatus = notebookExperimentStatuses.contains(experiment.status)
        ? experiment.status
        : notebookExperimentStatuses.first;
    final title = experiment.title.trim().isEmpty
        ? 'Untitled experiment'
        : experiment.title.trim();
    final code = experiment.experimentCode.trim().isEmpty
        ? 'Experiment'
        : experiment.experimentCode.trim();
    final projectTitle = widget.project.title.trim().isEmpty
        ? 'Untitled project'
        : widget.project.title.trim();
    final labLabel = widget.appState.selectedLabName.trim().isEmpty
        ? widget.project.labId
        : widget.appState.selectedLabName.trim();
    final reactionSubtitle = experiment.reactionTitle.trim().isEmpty
        ? experiment.aim.trim()
        : experiment.reactionTitle.trim();

    final leftBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HeaderBadge(
              label: code,
              icon: Icons.biotech_rounded,
              accent: const Color(0xFF5EEAD4),
            ),
            _HeaderBadge(label: projectTitle, icon: Icons.folder_open_rounded),
            if (labLabel.trim().isNotEmpty)
              _HeaderBadge(
                label: labLabel.trim(),
                icon: Icons.apartment_rounded,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: isWide ? 20 : 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (reactionSubtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            reactionSubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 12.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );

    final rightBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Expanded(
              child: _HeaderMetric(
                label: 'Date',
                value: _formatDate(experiment.date),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HeaderMetric(
                label: 'Updated',
                value: _formatDate(experiment.updatedAt),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Status',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 11.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (_isUpdatingStatus) ...[
              const SizedBox(
                height: 12,
                width: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 6),
              Text(
                'Saving',
                style: TextStyle(
                  color: palette.subtleText,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: ValueKey('experiment_status_${experiment.status}'),
          initialValue: safeStatus,
          dropdownColor: palette.panelAlt,
          style: TextStyle(color: colorScheme.onSurface, fontSize: 12.6),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: _statusColor(experiment.status).withValues(alpha: 0.14),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          items: notebookExperimentStatuses.map((status) {
            return DropdownMenuItem<String>(
              value: status,
              child: Text(
                status,
                style: TextStyle(color: _statusColor(status)),
              ),
            );
          }).toList(),
          onChanged: _isUpdatingStatus
              ? null
              : (value) {
                  if (value == null || value == experiment.status) {
                    return;
                  }
                  _updateStatus(value);
                },
        ),
      ],
    );

    return SizedBox(
      height: isWide ? 108 : null,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 14 : 13,
          vertical: isWide ? 10 : 13,
        ),
        decoration: BoxDecoration(
          color: palette.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.border),
        ),
        child: isWide
            ? Row(
                children: [
                  Expanded(child: leftBlock),
                  const SizedBox(width: 14),
                  SizedBox(width: 330, child: rightBlock),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [leftBlock, const SizedBox(height: 12), rightBlock],
              ),
      ),
    );
  }

  Widget _buildScrollablePanel({required Widget child}) {
    return Scrollbar(child: SingleChildScrollView(child: child));
  }

  Widget _buildDesktopWorkspace(
    NotebookExperimentModel experiment,
    double width,
  ) {
    final infoPanel = ExperimentInfoPanel(
      project: widget.project,
      experiment: experiment,
      formatDateTime: _formatDateTime,
      statusColor: _statusColor(experiment.status),
      compact: true,
    );
    final reactionPanel = ReactionDetailsPanel(experiment: experiment);
    final recordPanel = CharacterizationPanel(
      experiment: experiment,
      compact: true,
    );
    final notesPanel = ExperimentNotesPanel(
      noteController: _noteController,
      isSavingNote: _isSavingNote,
      onAddNote: _addNote,
      notesStream: _notesStream(),
      formatDateTime: _formatDateTime,
      expandList: true,
      compact: true,
      docked: true,
    );

    final leftRailWidth = width >= 1320 ? 258.0 : 232.0;
    final rightRailWidth = width >= 1320 ? 352.0 : 318.0;
    final notesHeight = width >= 1320 ? 312.0 : 280.0;

    return Column(
      children: [
        _buildHeaderBar(experiment, isWide: true),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: leftRailWidth,
                child: _buildScrollablePanel(child: infoPanel),
              ),
              const SizedBox(width: 10),
              Expanded(child: _buildScrollablePanel(child: reactionPanel)),
              const SizedBox(width: 10),
              SizedBox(
                width: rightRailWidth,
                child: Column(
                  children: [
                    Expanded(child: _buildScrollablePanel(child: recordPanel)),
                    const SizedBox(height: 10),
                    SizedBox(height: notesHeight, child: notesPanel),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileWorkspace(NotebookExperimentModel experiment) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          _buildHeaderBar(experiment, isWide: false),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: context.labmate.panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.labmate.border),
            ),
            child: TabBar(
              labelColor: context.colorScheme.onSurface,
              unselectedLabelColor: context.labmate.mutedText,
              indicatorColor: Color(0xFF14B8A6),
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Reaction'),
                Tab(text: 'Record'),
                Tab(text: 'Notes'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ExperimentInfoPanel(
                      project: widget.project,
                      experiment: experiment,
                      formatDateTime: _formatDateTime,
                      statusColor: _statusColor(experiment.status),
                      compact: true,
                    ),
                  ],
                ),
                ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ReactionDetailsPanel(experiment: experiment, compact: true),
                  ],
                ),
                ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    CharacterizationPanel(
                      experiment: experiment,
                      compact: true,
                    ),
                  ],
                ),
                ExperimentNotesPanel(
                  noteController: _noteController,
                  isSavingNote: _isSavingNote,
                  onAddNote: _addNote,
                  notesStream: _notesStream(),
                  formatDateTime: _formatDateTime,
                  expandList: true,
                  compact: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canQuery = FirestoreAccessGuard.shouldQueryLabScopedData(
      appState: widget.appState,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Experiment Details')),
      body: ResponsivePageContainer(
        maxWidth: 1540,
        child: canQuery
            ? StreamBuilder<NotebookExperimentModel?>(
                stream: _labNotebookService.getExperiment(
                  labId: _labId,
                  projectId: widget.project.id,
                  experimentId: widget.experimentId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          FirestoreAccessGuard.messageFor(snapshot.error),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.labmate.mutedText,
                            height: 1.4,
                          ),
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final experiment = snapshot.data;
                  if (experiment == null) {
                    return const Center(
                      child: Text(
                        'This experiment could not be found.',
                        textAlign: TextAlign.center,
                        style: TextStyle(height: 1.4),
                      ),
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;

                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: isWide
                            ? _buildDesktopWorkspace(
                                experiment,
                                constraints.maxWidth,
                              )
                            : _buildMobileWorkspace(experiment),
                      );
                    },
                  );
                },
              )
            : const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
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

class _HeaderBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accent;

  const _HeaderBadge({required this.icon, required this.label, this.accent});

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
                  fontSize: 11.3,
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

class _HeaderMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
              fontSize: 12.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
