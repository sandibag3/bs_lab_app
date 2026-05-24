import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/experiment_edit_history_model.dart';
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
import 'add_experiment_screen.dart';

class ExperimentDetailScreen extends StatefulWidget {
  final AppState appState;
  final NotebookProjectModel project;
  final String experimentId;
  final String notebookOwnerUid;
  final String notebookOwnerLabel;
  final bool isReadOnly;

  const ExperimentDetailScreen({
    super.key,
    required this.appState,
    required this.project,
    required this.experimentId,
    required this.notebookOwnerUid,
    required this.notebookOwnerLabel,
    required this.isReadOnly,
  });

  @override
  State<ExperimentDetailScreen> createState() => _ExperimentDetailScreenState();
}

class _ExperimentDetailScreenState extends State<ExperimentDetailScreen> {
  final LabNotebookService _labNotebookService = LabNotebookService();
  final TextEditingController _noteController = TextEditingController();

  bool _isSavingNote = false;
  bool _isUpdatingStatus = false;
  bool _isDuplicating = false;
  bool _isOpeningEdit = false;
  bool _headerCollapsed = true;

  String get _labId => widget.appState.resolveWriteLabId(widget.project.labId);
  String get _currentUserUid => widget.appState.authenticatedUserId.trim();

  bool _canEditExperiment(NotebookExperimentModel? experiment) {
    if (_currentUserUid.isEmpty) {
      return false;
    }

    final routeNotebookOwnerUid = widget.notebookOwnerUid.trim();
    if (routeNotebookOwnerUid.isNotEmpty) {
      return routeNotebookOwnerUid == _currentUserUid;
    }

    final experimentOwnerUid = experiment?.ownerUid.trim() ?? '';
    if (experimentOwnerUid.isNotEmpty) {
      return experimentOwnerUid == _currentUserUid;
    }

    return !widget.isReadOnly;
  }

  bool _isEffectivelyReadOnly(NotebookExperimentModel? experiment) {
    return !_canEditExperiment(experiment);
  }

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
    if (_isUpdatingStatus || !_canEditExperiment(null)) {
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
        notebookOwnerUid: widget.notebookOwnerUid,
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
    if (_isSavingNote || !_canEditExperiment(null)) {
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
        ownerUid: widget.notebookOwnerUid,
        ownerEmail: widget.project.ownerEmail,
        createdBy: _createdByValue(),
        userEmail: widget.appState.authenticatedUserEmail,
        createdAt: Timestamp.now(),
      );

      await _labNotebookService.addExperimentNote(
        labId: _labId,
        projectId: widget.project.id,
        experimentId: widget.experimentId,
        note: note,
        notebookOwnerUid: widget.notebookOwnerUid,
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

  Future<void> _openDuplicateDraft(NotebookExperimentModel experiment) async {
    if (_isDuplicating || !_canEditExperiment(experiment)) {
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
      _isDuplicating = true;
    });

    final messenger = ScaffoldMessenger.of(context);

    try {
      final duplicateCode = await _labNotebookService
          .getNextDuplicateExperimentCode(
            labId: _labId,
            projectId: widget.project.id,
            originalCode: experiment.experimentCode,
            notebookOwnerUid: widget.notebookOwnerUid,
          );

      if (!mounted) {
        return;
      }

      final duplicatedExperimentId = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => AddExperimentScreen(
            appState: widget.appState,
            project: widget.project,
            notebookOwnerUid: widget.notebookOwnerUid,
            notebookOwnerEmail: experiment.ownerEmail.trim().isEmpty
                ? widget.project.ownerEmail
                : experiment.ownerEmail,
            initialExperiment: experiment,
            initialExperimentCode: duplicateCode,
            isDuplicateDraft: true,
          ),
        ),
      );

      if (!mounted ||
          duplicatedExperimentId == null ||
          duplicatedExperimentId.trim().isEmpty) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ExperimentDetailScreen(
            appState: widget.appState,
            project: widget.project,
            experimentId: duplicatedExperimentId.trim(),
            notebookOwnerUid: widget.notebookOwnerUid,
            notebookOwnerLabel: widget.notebookOwnerLabel,
            isReadOnly: widget.isReadOnly,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text(FirestoreAccessGuard.messageFor(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDuplicating = false;
        });
      }
    }
  }

  Future<void> _openEditDraft(NotebookExperimentModel experiment) async {
    if (_isOpeningEdit || !_canEditExperiment(experiment)) {
      return;
    }

    setState(() {
      _isOpeningEdit = true;
    });

    try {
      final updatedExperimentId = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => AddExperimentScreen(
            appState: widget.appState,
            project: widget.project,
            notebookOwnerUid: widget.notebookOwnerUid,
            notebookOwnerEmail: experiment.ownerEmail.trim().isEmpty
                ? widget.project.ownerEmail
                : experiment.ownerEmail,
            initialExperiment: experiment,
            isEditMode: true,
          ),
        ),
      );

      if (!mounted ||
          updatedExperimentId == null ||
          updatedExperimentId.trim().isEmpty) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Experiment updated.')));
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningEdit = false;
        });
      }
    }
  }

  Stream<List<ExperimentNoteModel>> _notesStream() {
    return _labNotebookService.getExperimentNotes(
      labId: _labId,
      projectId: widget.project.id,
      experimentId: widget.experimentId,
      notebookOwnerUid: widget.notebookOwnerUid,
    );
  }

  Widget _buildEditHistoryPanel(
    NotebookExperimentModel experiment, {
    required bool compact,
  }) {
    final history = experiment.editHistory;

    return Builder(
      builder: (context) {
        final palette = context.labmate;
        final colorScheme = context.colorScheme;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 12 : 13),
          decoration: BoxDecoration(
            color: palette.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit History',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: compact ? 13.2 : 13.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Latest changes to this experiment record',
                style: TextStyle(
                  color: palette.subtleText,
                  fontSize: compact ? 11.1 : 11.4,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              if (history.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: palette.panelAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text(
                    'No edit history yet.',
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: 11.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                ...history.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == history.length - 1 ? 0 : 8,
                    ),
                    child: _EditHistoryEntryTile(
                      item: item,
                      formatDateTime: _formatDateTime,
                      compact: compact,
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDesktopSheet({
    required String title,
    required Widget child,
  }) async {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sheetWidth = (screenWidth * 0.32).clamp(320.0, 420.0).toDouble();

    await showGeneralDialog<void>(
      context: context,
      barrierLabel: title,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: sheetWidth,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.panel,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: palette.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 15.2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Close',
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: palette.border),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(14),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.12, 0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  Future<void> _openExperimentInfoSheet(
    NotebookExperimentModel experiment,
  ) async {
    await _showDesktopSheet(
      title: 'Experiment Info',
      child: ExperimentInfoPanel(
        project: widget.project,
        experiment: experiment,
        formatDateTime: _formatDateTime,
        statusColor: _statusColor(experiment.status),
        compact: true,
      ),
    );
  }

  Future<void> _openRecordResultsSheet(
    NotebookExperimentModel experiment,
  ) async {
    await _showDesktopSheet(
      title: 'Record & Results',
      child: Column(
        children: [
          CharacterizationPanel(experiment: experiment, compact: true),
          const SizedBox(height: 10),
          _buildEditHistoryPanel(experiment, compact: true),
        ],
      ),
    );
  }

  Widget _buildPanelToggleButton({
    required bool expanded,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final palette = context.labmate;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Container(
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            color: palette.panelAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.border),
          ),
          child: Icon(
            expanded ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
            size: 16,
            color: palette.subtleText,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBar(
    NotebookExperimentModel experiment, {
    required bool isWide,
    double? availableWidth,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final canEditExperiment = _canEditExperiment(experiment);
    final isReadOnlyView = _isEffectivelyReadOnly(experiment);
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
    final compactHeaderWidth = availableWidth ?? double.infinity;
    final showWideActionLabels = compactHeaderWidth >= 1220;
    final collapseButton = _buildPanelToggleButton(
      expanded: !_headerCollapsed,
      tooltip: _headerCollapsed ? 'Expand header' : 'Collapse header',
      onPressed: () {
        setState(() {
          _headerCollapsed = !_headerCollapsed;
        });
      },
    );

    Widget buildHeaderActionButton({
      required IconData icon,
      required String label,
      required VoidCallback onPressed,
      required double width,
      bool iconOnly = false,
      bool enabled = true,
    }) {
      if (iconOnly) {
        return Tooltip(
          message: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: enabled ? onPressed : null,
            child: Container(
              height: 36,
              width: width,
              decoration: BoxDecoration(
                color: palette.panelAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: Icon(
                icon,
                size: 16,
                color: enabled ? colorScheme.onSurface : palette.subtleText,
              ),
            ),
          ),
        );
      }

      return SizedBox(
        width: width,
        child: OutlinedButton.icon(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            minimumSize: const Size(0, 36),
            side: BorderSide(color: palette.border),
          ),
          icon: Icon(icon, size: 16),
          label: Text(
            label,
            style: const TextStyle(fontSize: 11.2, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    final editButton = SizedBox(
      width: isWide ? 96 : double.infinity,
      child: OutlinedButton.icon(
        onPressed: !canEditExperiment || _isOpeningEdit
            ? null
            : () => _openEditDraft(experiment),
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          minimumSize: const Size(0, 36),
          side: BorderSide(color: palette.border),
        ),
        icon: _isOpeningEdit
            ? const SizedBox(
                height: 15,
                width: 15,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.edit_rounded, size: 16),
        label: Text(
          _isOpeningEdit ? 'Opening' : 'Edit',
          style: const TextStyle(fontSize: 11.2, fontWeight: FontWeight.w700),
        ),
      ),
    );
    final duplicateButton = SizedBox(
      width: isWide ? 102 : double.infinity,
      child: OutlinedButton.icon(
        onPressed: !canEditExperiment || _isDuplicating
            ? null
            : () => _openDuplicateDraft(experiment),
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          minimumSize: const Size(0, 36),
          side: BorderSide(color: palette.border),
        ),
        icon: _isDuplicating
            ? const SizedBox(
                height: 15,
                width: 15,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.copy_all_rounded, size: 16),
        label: Text(
          _isDuplicating ? 'Preparing' : 'Duplicate',
          style: const TextStyle(fontSize: 11.2, fontWeight: FontWeight.w700),
        ),
      ),
    );
    final statusDropdown = DropdownButtonFormField<String>(
      key: ValueKey('experiment_status_${experiment.status}'),
      initialValue: safeStatus,
      dropdownColor: palette.panelAlt,
      style: TextStyle(color: colorScheme.onSurface, fontSize: 11.8),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: _statusColor(experiment.status).withValues(alpha: 0.14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: notebookExperimentStatuses.map((status) {
        return DropdownMenuItem<String>(
          value: status,
          child: Text(status, style: TextStyle(color: _statusColor(status))),
        );
      }).toList(),
      onChanged: _isUpdatingStatus || !canEditExperiment
          ? null
          : (value) {
              if (value == null || value == experiment.status) {
                return;
              }
              _updateStatus(value);
            },
    );
    final statusChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _statusColor(experiment.status).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        safeStatus,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _statusColor(experiment.status),
          fontSize: 11.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final statusControl = canEditExperiment ? statusDropdown : statusChip;
    final infoButton = isWide
        ? buildHeaderActionButton(
            icon: Icons.info_outline_rounded,
            label: 'Info',
            onPressed: () => _openExperimentInfoSheet(experiment),
            width: showWideActionLabels ? 84 : 36,
            iconOnly: !showWideActionLabels,
          )
        : const SizedBox.shrink();
    final recordButton = isWide
        ? buildHeaderActionButton(
            icon: Icons.fact_check_outlined,
            label: 'Record',
            onPressed: () => _openRecordResultsSheet(experiment),
            width: showWideActionLabels ? 98 : 36,
            iconOnly: !showWideActionLabels,
          )
        : const SizedBox.shrink();

    if (isWide && _headerCollapsed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: palette.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            _HeaderBadge(
              label: code,
              icon: Icons.biotech_rounded,
              accent: const Color(0xFF5EEAD4),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 15.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: canEditExperiment
                  ? (compactHeaderWidth < 1180 ? 154 : 172)
                  : 124,
              child: statusControl,
            ),
            const SizedBox(width: 6),
            infoButton,
            const SizedBox(width: 6),
            recordButton,
            if (canEditExperiment) ...[
              const SizedBox(width: 6),
              editButton,
              const SizedBox(width: 6),
              duplicateButton,
            ],
            const SizedBox(width: 6),
            collapseButton,
          ],
        ),
      );
    }

    final leftBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
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
            _HeaderBadge(
              label: widget.notebookOwnerLabel,
              icon: isReadOnlyView
                  ? Icons.visibility_outlined
                  : Icons.person_outline_rounded,
              accent: isReadOnlyView ? const Color(0xFFFBBF24) : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: isWide ? 18.2 : 17.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (reactionSubtitle.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            reactionSubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 11.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );

    final rightBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _HeaderMetric(
                label: 'Date',
                value: _formatDate(experiment.date),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _HeaderMetric(
                label: 'Updated',
                value: _formatDate(experiment.updatedAt),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'Status',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 10.8,
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
        statusControl,
        if (canEditExperiment) ...[
          const SizedBox(height: 6),
          if (isWide)
            Row(
              children: [
                Expanded(child: editButton),
                const SizedBox(width: 6),
                Expanded(child: duplicateButton),
              ],
            )
          else
            Column(
              children: [
                editButton,
                const SizedBox(height: 8),
                duplicateButton,
              ],
            ),
        ],
        if (isWide) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [infoButton, recordButton],
          ),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerRight, child: collapseButton),
        ],
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 12 : 13,
        vertical: isWide ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: leftBlock),
                const SizedBox(width: 12),
                SizedBox(width: 332, child: rightBlock),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [leftBlock, const SizedBox(height: 10), rightBlock],
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
    final canEditExperiment = _canEditExperiment(experiment);
    final notesWidth = (width * 0.28).clamp(300.0, 340.0).toDouble();
    final reactionPanel = ReactionDetailsPanel(experiment: experiment);
    final notesPanel = ExperimentNotesPanel(
      noteController: _noteController,
      isSavingNote: _isSavingNote,
      onAddNote: _addNote,
      notesStream: _notesStream(),
      formatDateTime: _formatDateTime,
      expandList: true,
      compact: true,
      docked: true,
      canAddNote: canEditExperiment,
      readOnlyMessage:
          'Read-only view: you are viewing another member\'s notebook.',
    );

    return Column(
      children: [
        _buildHeaderBar(experiment, isWide: true, availableWidth: width),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildScrollablePanel(child: reactionPanel)),
              const SizedBox(width: 10),
              SizedBox(width: notesWidth, child: notesPanel),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileWorkspace(NotebookExperimentModel experiment) {
    final canEditExperiment = _canEditExperiment(experiment);
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
                    const SizedBox(height: 10),
                    _buildEditHistoryPanel(experiment, compact: true),
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
                  canAddNote: canEditExperiment,
                  readOnlyMessage:
                      'Read-only view: you are viewing another member\'s notebook.',
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
                  notebookOwnerUid: widget.notebookOwnerUid,
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

                  final content = LayoutBuilder(
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

                  if (!_isEffectivelyReadOnly(experiment)) {
                    return content;
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: _ReadOnlyBanner(
                          message:
                              'Read-only view: you are viewing another member\'s notebook.',
                        ),
                      ),
                      Expanded(child: content),
                    ],
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
      constraints: const BoxConstraints(maxWidth: 248),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: palette.panelAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12.5, color: accent ?? const Color(0xFF5EEAD4)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent ?? palette.mutedText,
                  fontSize: 10.9,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
              fontSize: 10.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 11.7,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditHistoryEntryTile extends StatelessWidget {
  final ExperimentEditHistoryModel item;
  final String Function(Timestamp timestamp) formatDateTime;
  final bool compact;

  const _EditHistoryEntryTile({
    required this.item,
    required this.formatDateTime,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 11),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.summary.trim().isEmpty
                      ? 'Experiment updated'
                      : item.summary,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: compact ? 12.0 : 12.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatDateTime(item.editedAt),
                style: TextStyle(
                  color: palette.subtleText,
                  fontSize: compact ? 10.6 : 10.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            item.editorLabel,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: compact ? 11.2 : 11.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyBanner extends StatelessWidget {
  final String message;

  const _ReadOnlyBanner({required this.message});

  @override
  Widget build(BuildContext context) {
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
              message,
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
}
