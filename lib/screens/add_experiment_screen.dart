import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/experiment_edit_history_model.dart';
import '../models/notebook_experiment_model.dart';
import '../models/notebook_project_model.dart';
import '../models/reaction_component_model.dart';
import '../services/firestore_access_guard.dart';
import '../services/lab_notebook_service.dart';
import '../theme/labmate_theme.dart';
import '../widgets/responsive_page_container.dart';

class AddExperimentScreen extends StatefulWidget {
  final AppState appState;
  final NotebookProjectModel project;
  final String? notebookOwnerUid;
  final String? notebookOwnerEmail;
  final NotebookExperimentModel? initialExperiment;
  final String? initialExperimentCode;
  final bool isDuplicateDraft;
  final bool isEditMode;

  const AddExperimentScreen({
    super.key,
    required this.appState,
    required this.project,
    this.notebookOwnerUid,
    this.notebookOwnerEmail,
    this.initialExperiment,
    this.initialExperimentCode,
    this.isDuplicateDraft = false,
    this.isEditMode = false,
  });

  @override
  State<AddExperimentScreen> createState() => _AddExperimentScreenState();
}

class _AddExperimentScreenState extends State<AddExperimentScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final LabNotebookService _labNotebookService = LabNotebookService();

  final TextEditingController _experimentCodeController =
      TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _aimController = TextEditingController();
  final TextEditingController _reactionTitleController =
      TextEditingController();
  final TextEditingController _startingMaterialController =
      TextEditingController();
  final TextEditingController _reagentsController = TextEditingController();
  final TextEditingController _catalystController = TextEditingController();
  final TextEditingController _solventController = TextEditingController();
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _atmosphereController = TextEditingController();
  final TextEditingController _scaleController = TextEditingController();
  final TextEditingController _procedureController = TextEditingController();
  final TextEditingController _observationsController = TextEditingController();
  final TextEditingController _workupController = TextEditingController();
  final TextEditingController _purificationController = TextEditingController();
  final TextEditingController _yieldController = TextEditingController();
  final TextEditingController _characterizationController =
      TextEditingController();
  final TextEditingController _conclusionController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedStatus = notebookExperimentStatuses.first;
  bool _isSaving = false;
  final List<_ReactionComponentDraft> _reactionComponentDrafts =
      <_ReactionComponentDraft>[];
  int _nextReactionComponentDraftId = 0;

  bool get _hasInitialExperiment => widget.initialExperiment != null;
  bool get _isEditMode => widget.isEditMode && _hasInitialExperiment;
  bool get _isDuplicateDraftMode =>
      !_isEditMode && widget.isDuplicateDraft && _hasInitialExperiment;
  String get _saveButtonLabel {
    if (_isEditMode) {
      return 'Save experiment changes';
    }

    return _isDuplicateDraftMode
        ? 'Save duplicated experiment'
        : 'Save Experiment';
  }

  String get _draftTitle {
    if (_isEditMode) {
      return 'Edit experiment';
    }

    return _isDuplicateDraftMode
        ? 'Duplicate experiment draft'
        : 'New experiment draft';
  }

  String get _duplicateSourceCode {
    final sourceCode = widget.initialExperiment?.experimentCode.trim() ?? '';
    return sourceCode.isEmpty ? 'source experiment' : sourceCode;
  }

  bool get _showLegacyTimeNotice {
    if (!_isEditMode) {
      return false;
    }

    return _startTimeController.text.trim().isEmpty &&
        _endTimeController.text.trim().isEmpty &&
        _timeController.text.trim().isNotEmpty;
  }

  bool get _preservesLegacySetupFields {
    if (!_isEditMode) {
      return false;
    }

    return _startingMaterialController.text.trim().isNotEmpty ||
        _reagentsController.text.trim().isNotEmpty ||
        _catalystController.text.trim().isNotEmpty ||
        _scaleController.text.trim().isNotEmpty;
  }

  String get _effectiveNotebookOwnerUid {
    final explicitOwnerUid = (widget.notebookOwnerUid ?? '').trim();
    if (explicitOwnerUid.isNotEmpty) {
      return explicitOwnerUid;
    }

    final initialOwnerUid = widget.initialExperiment?.ownerUid.trim() ?? '';
    if (initialOwnerUid.isNotEmpty) {
      return initialOwnerUid;
    }

    return widget.appState.authenticatedUserId.trim();
  }

  String get _effectiveNotebookOwnerEmail {
    final explicitOwnerEmail = (widget.notebookOwnerEmail ?? '').trim();
    if (explicitOwnerEmail.isNotEmpty) {
      return explicitOwnerEmail;
    }

    final initialOwnerEmail = widget.initialExperiment?.ownerEmail.trim() ?? '';
    if (initialOwnerEmail.isNotEmpty) {
      return initialOwnerEmail;
    }

    final authenticatedEmail = widget.appState.authenticatedUserEmail.trim();
    if (authenticatedEmail.isNotEmpty) {
      return authenticatedEmail;
    }

    return widget.project.ownerEmail.trim();
  }

  String get _effectiveLabId {
    final initialLabId = widget.initialExperiment?.labId.trim() ?? '';
    if (initialLabId.isNotEmpty) {
      return initialLabId;
    }

    return widget.appState.resolveWriteLabId(widget.project.labId);
  }

  String get _effectiveProjectId {
    final initialProjectId = widget.initialExperiment?.projectId.trim() ?? '';
    if (initialProjectId.isNotEmpty) {
      return initialProjectId;
    }

    return widget.project.id.trim();
  }

  @override
  void initState() {
    super.initState();
    _syncDateField();
    _applyInitialDraft();
  }

  void _syncDateField() {
    final day = _selectedDate.day.toString().padLeft(2, '0');
    final month = _selectedDate.month.toString().padLeft(2, '0');
    _dateController.text = '$day/$month/${_selectedDate.year}';
  }

  void _applyInitialDraft() {
    final initialExperiment = widget.initialExperiment;
    if ((!_isDuplicateDraftMode && !_isEditMode) || initialExperiment == null) {
      return;
    }

    if (_isEditMode) {
      _selectedDate = initialExperiment.date.toDate();
      _experimentCodeController.text = initialExperiment.experimentCode.trim();
    } else {
      _experimentCodeController.text = (widget.initialExperimentCode ?? '')
          .trim();
    }

    _syncDateField();
    _titleController.text = initialExperiment.title.trim();
    _aimController.text = initialExperiment.aim.trim();
    _reactionTitleController.text = initialExperiment.reactionTitle.trim();
    _solventController.text = initialExperiment.solvent.trim();
    _temperatureController.text = initialExperiment.temperature.trim();
    _startTimeController.text = initialExperiment.startTime.trim();
    _endTimeController.text = initialExperiment.endTime.trim();
    _atmosphereController.text = initialExperiment.atmosphere.trim();
    _procedureController.text = initialExperiment.procedure.trim();
    _workupController.text = initialExperiment.workup.trim();
    _purificationController.text = initialExperiment.purification.trim();
    _characterizationController.text = initialExperiment.characterization
        .trim();

    if (_isEditMode) {
      _startingMaterialController.text = initialExperiment.startingMaterial
          .trim();
      _reagentsController.text = initialExperiment.reagents.trim();
      _catalystController.text = initialExperiment.catalyst.trim();
      _timeController.text = initialExperiment.time.trim();
      _scaleController.text = initialExperiment.scale.trim();
    } else {
      _startingMaterialController.clear();
      _reagentsController.clear();
      _catalystController.clear();
      _timeController.clear();
      _scaleController.clear();
    }

    if (_isEditMode) {
      _observationsController.text = initialExperiment.observations.trim();
      _yieldController.text = initialExperiment.yieldText.trim();
      _conclusionController.text = initialExperiment.conclusion.trim();
      final initialStatus = initialExperiment.status.trim();
      _selectedStatus = notebookExperimentStatuses.contains(initialStatus)
          ? initialStatus
          : notebookExperimentStatuses.first;
    } else {
      _observationsController.clear();
      _yieldController.clear();
      _conclusionController.clear();
      _selectedStatus = notebookExperimentStatuses.first;
    }

    for (final component in initialExperiment.reactionComponents) {
      _reactionComponentDrafts.add(_createReactionComponentDraft(component));
    }
    _normalizeLimitingReagentSelection();
  }

  _ReactionComponentDraft _createReactionComponentDraft([
    ReactionComponentModel? initialComponent,
  ]) {
    final draft = _ReactionComponentDraft(
      id: 'component_${_nextReactionComponentDraftId++}',
      componentName: initialComponent?.componentName ?? '',
      role: initialComponent?.role ?? reactionComponentRoles.first,
      formulaOrNotes: initialComponent?.formulaOrNotes ?? '',
      mmol: initialComponent?.mmol ?? '',
      equiv: initialComponent?.equiv ?? '',
      molecularWeight: initialComponent?.molecularWeight ?? '',
      amount: initialComponent?.amount ?? '',
      unit: initialComponent?.unit ?? reactionComponentUnits.first,
      density: initialComponent?.density ?? '',
      volume: initialComponent?.volume ?? '',
      supplierOrSource: initialComponent?.supplierOrSource ?? '',
      remarks: initialComponent?.remarks ?? '',
      isLimitingReagent: initialComponent?.isLimitingReagent ?? false,
    );
    return draft;
  }

  void _setLimitingReagent(String draftId, bool isSelected) {
    setState(() {
      for (final draft in _reactionComponentDrafts) {
        draft.isLimitingReagent = false;
      }

      if (!isSelected) {
        return;
      }

      for (final draft in _reactionComponentDrafts) {
        if (draft.id == draftId) {
          draft.isLimitingReagent = true;
          break;
        }
      }
    });
  }

  void _normalizeLimitingReagentSelection() {
    var hasMarkedLimitingReagent = false;
    for (final draft in _reactionComponentDrafts) {
      if (draft.isLimitingReagent && !hasMarkedLimitingReagent) {
        hasMarkedLimitingReagent = true;
        continue;
      }

      draft.isLimitingReagent = false;
    }
  }

  void _addReactionComponentRow([ReactionComponentModel? initialComponent]) {
    setState(() {
      _reactionComponentDrafts.add(
        _createReactionComponentDraft(initialComponent),
      );
    });
  }

  void _removeReactionComponentRow(String draftId) {
    setState(() {
      final index = _reactionComponentDrafts.indexWhere(
        (draft) => draft.id == draftId,
      );
      if (index < 0) {
        return;
      }

      final draft = _reactionComponentDrafts.removeAt(index);
      draft.dispose();
    });
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

  InputDecoration _inputDecoration(BuildContext context, String label) {
    final palette = context.labmate;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: palette.mutedText, fontSize: 12.2),
      isDense: true,
      filled: true,
      fillColor: palette.panelAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      errorStyle: const TextStyle(fontSize: 11.2),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int minLines = 1,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Builder(
      builder: (context) => TextFormField(
        controller: controller,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 12.8,
        ),
        decoration: _inputDecoration(context, label),
        minLines: minLines,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        textCapitalization: maxLines > 1
            ? TextCapitalization.sentences
            : TextCapitalization.none,
        validator: validator,
      ),
    );
  }

  Widget _buildAdaptiveFields(
    List<Widget> children, {
    int maxColumns = 2,
    double minItemWidth = 220,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final rawColumns =
            ((constraints.maxWidth + spacing) / (minItemWidth + spacing))
                .floor();
        final columns = rawColumns.clamp(1, maxColumns);
        final itemWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children.map((child) {
            return SizedBox(width: itemWidth, child: child);
          }).toList(),
        );
      },
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Builder(
      builder: (context) {
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
              Text(
                title,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 14.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: palette.subtleText,
                  fontSize: 11.4,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 11),
              child,
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoBanner({
    required IconData icon,
    required Color accent,
    required String message,
  }) {
    return Builder(
      builder: (context) {
        final palette = context.labmate;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.24)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 11.8,
                    height: 1.38,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _reactionComponentInputDecoration(
    BuildContext context, {
    required String hint,
  }) {
    final palette = context.labmate;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: palette.subtleText, fontSize: 11.6),
      isDense: true,
      filled: true,
      fillColor: palette.panelAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      errorStyle: const TextStyle(fontSize: 10.8),
    );
  }

  Widget _buildReactionComponentTextField({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return Builder(
      builder: (context) => TextFormField(
        controller: controller,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 12.2,
        ),
        decoration: _reactionComponentInputDecoration(context, hint: hint),
        validator: validator,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildReactionComponentRoleField(_ReactionComponentDraft draft) {
    return Builder(
      builder: (context) => DropdownButtonFormField<String>(
        key: ValueKey('role_${draft.id}_${draft.role}'),
        initialValue: reactionComponentRoles.contains(draft.role)
            ? draft.role
            : reactionComponentRoles.first,
        dropdownColor: context.labmate.panelAlt,
        isExpanded: true,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 12.2,
        ),
        decoration: _reactionComponentInputDecoration(context, hint: 'Role'),
        items: reactionComponentRoles.map((role) {
          return DropdownMenuItem<String>(value: role, child: Text(role));
        }).toList(),
        onChanged: (value) {
          if (value == null) {
            return;
          }

          setState(() {
            draft.role = value;
          });
        },
      ),
    );
  }

  Widget _buildReactionComponentUnitField(_ReactionComponentDraft draft) {
    return Builder(
      builder: (context) => DropdownButtonFormField<String>(
        key: ValueKey('unit_${draft.id}_${draft.unit}'),
        initialValue: reactionComponentUnits.contains(draft.unit)
            ? draft.unit
            : reactionComponentUnits.first,
        dropdownColor: context.labmate.panelAlt,
        isExpanded: true,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 12.2,
        ),
        decoration: _reactionComponentInputDecoration(context, hint: 'Unit'),
        items: reactionComponentUnits.map((unit) {
          return DropdownMenuItem<String>(value: unit, child: Text(unit));
        }).toList(),
        onChanged: (value) {
          if (value == null) {
            return;
          }

          setState(() {
            draft.unit = value;
          });
        },
      ),
    );
  }

  Widget _buildLimitingReagentControl(
    _ReactionComponentDraft draft, {
    required bool compact,
  }) {
    final isSelected = draft.isLimitingReagent;

    return Builder(
      builder: (context) {
        final palette = context.labmate;
        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => _setLimitingReagent(draft.id, !isSelected),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 11,
              vertical: compact ? 8 : 9,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF14B8A6).withValues(alpha: 0.16)
                  : palette.panel,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF14B8A6).withValues(alpha: 0.32)
                    : palette.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? Icons.flag_rounded : Icons.outlined_flag_rounded,
                  size: compact ? 14 : 15,
                  color: isSelected
                      ? const Color(0xFF5EEAD4)
                      : palette.subtleText,
                ),
                const SizedBox(width: 6),
                Text(
                  isSelected ? 'Limiting' : 'Mark',
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF5EEAD4)
                        : palette.mutedText,
                    fontSize: compact ? 11.0 : 11.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double? _parseReactionNumber(String rawValue) {
    final normalized = rawValue.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }

    return double.tryParse(normalized);
  }

  double? _limitingReagentReferenceMmol() {
    for (final draft in _reactionComponentDrafts) {
      if (!draft.isLimitingReagent) {
        continue;
      }

      final limitingMmol = _parseReactionNumber(draft.mmolController.text);
      if (limitingMmol == null || limitingMmol <= 0) {
        return null;
      }

      return limitingMmol;
    }

    return null;
  }

  double? _calculatedEquivForDraft(_ReactionComponentDraft draft) {
    final limitingMmol = _limitingReagentReferenceMmol();
    final rowMmol = _parseReactionNumber(draft.mmolController.text);
    if (limitingMmol == null || rowMmol == null || limitingMmol <= 0) {
      return null;
    }

    return rowMmol / limitingMmol;
  }

  String? _calculatedEquivLabelForDraft(_ReactionComponentDraft draft) {
    final calculatedEquiv = _calculatedEquivForDraft(draft);
    if (calculatedEquiv == null) {
      return null;
    }

    return 'calc: ${calculatedEquiv.toStringAsFixed(2)} equiv';
  }

  double? _calculatedMolPercentForDraft(_ReactionComponentDraft draft) {
    if (draft.role.trim().toLowerCase() != 'catalyst') {
      return null;
    }

    final limitingMmol = _limitingReagentReferenceMmol();
    final catalystMmol = _parseReactionNumber(draft.mmolController.text);
    if (limitingMmol == null || catalystMmol == null || limitingMmol <= 0) {
      return null;
    }

    return (catalystMmol / limitingMmol) * 100;
  }

  String? _calculatedMolPercentLabelForDraft(_ReactionComponentDraft draft) {
    final calculatedMolPercent = _calculatedMolPercentForDraft(draft);
    if (calculatedMolPercent == null) {
      return null;
    }

    return 'calc: ${calculatedMolPercent.toStringAsFixed(1)} mol%';
  }

  double? _calculatedAmountMgForDraft(_ReactionComponentDraft draft) {
    final mmol = _parseReactionNumber(draft.mmolController.text);
    final molecularWeight = _parseReactionNumber(
      draft.molecularWeightController.text,
    );
    if (mmol == null || molecularWeight == null) {
      return null;
    }

    return mmol * molecularWeight;
  }

  String? _calculatedAmountLabelForDraft(_ReactionComponentDraft draft) {
    final calculatedAmount = _calculatedAmountMgForDraft(draft);
    if (calculatedAmount == null) {
      return null;
    }

    return 'calc: ${calculatedAmount.toStringAsFixed(1)} mg';
  }

  Widget _buildReactionHelperLabel(String? label) {
    if (label == null) {
      return const SizedBox.shrink();
    }

    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.only(top: 5, left: 2),
        child: Text(
          label,
          style: TextStyle(
            color: const Color(0xFF5EEAD4),
            fontSize: 10.8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildReactionTableToolbar() {
    return Builder(
      builder: (context) {
        final palette = context.labmate;
        final colorScheme = context.colorScheme;

        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Planner rows',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 12.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Capture stoichiometry and sourcing details component by component.',
                    style: TextStyle(
                      color: palette.subtleText,
                      fontSize: 11.3,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _DraftBadge(
              icon: Icons.table_rows_rounded,
              label: '${_reactionComponentDrafts.length}',
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _addReactionComponentRow(),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.onSurface,
                side: BorderSide(color: palette.border),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                'Add Row',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReactionTableEmptyState() {
    return Builder(
      builder: (context) {
        final palette = context.labmate;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.panelAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No reaction components added yet.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add rows for starting materials, reagents, solvents, products, or any other component you want to track.',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: 11.8,
                  height: 1.38,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _addReactionComponentRow(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  side: BorderSide(color: palette.border),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text(
                  'Add first row',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReactionTableSection() {
    return _buildSection(
      title: 'Reaction Table',
      subtitle: 'Structured component planner for the reaction setup',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktopTable = constraints.maxWidth >= 860;

          if (_reactionComponentDrafts.isEmpty) {
            return _buildReactionTableEmptyState();
          }

          return Column(
            children: [
              _buildReactionTableToolbar(),
              const SizedBox(height: 10),
              isDesktopTable
                  ? _buildDesktopReactionTable()
                  : _buildMobileReactionTable(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDesktopReactionTable() {
    return Builder(
      builder: (context) {
        final palette = context.labmate;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            width: 1324,
            decoration: BoxDecoration(
              color: palette.panelAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: palette.border)),
                  ),
                  child: const Row(
                    children: [
                      _DesktopReactionHeaderCell('Component', 160),
                      _DesktopReactionHeaderCell('Role', 124),
                      _DesktopReactionHeaderCell('Equiv', 76),
                      _DesktopReactionHeaderCell('mmol', 76),
                      _DesktopReactionHeaderCell('Molecular weight', 116),
                      _DesktopReactionHeaderCell('Amount', 86),
                      _DesktopReactionHeaderCell('Unit', 86),
                      _DesktopReactionHeaderCell('Density', 90),
                      _DesktopReactionHeaderCell('Volume', 90),
                      _DesktopReactionHeaderCell('Remarks', 150),
                      _DesktopReactionHeaderCell('Limit', 98),
                      _DesktopReactionHeaderCell('', 46),
                    ],
                  ),
                ),
                ..._reactionComponentDrafts.asMap().entries.map((entry) {
                  final index = entry.key;
                  final draft = entry.value;
                  final isLast = index == _reactionComponentDrafts.length - 1;
                  final calculatedEquivLabel = _calculatedEquivLabelForDraft(
                    draft,
                  );
                  final calculatedMolPercentLabel =
                      _calculatedMolPercentLabelForDraft(draft);
                  final calculatedAmountLabel = _calculatedAmountLabelForDraft(
                    draft,
                  );

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : Border(bottom: BorderSide(color: palette.border)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DesktopReactionFieldCell(
                          width: 160,
                          child: _buildReactionComponentTextField(
                            controller: draft.componentNameController,
                            hint: 'Component name',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                        _DesktopReactionFieldCell(
                          width: 124,
                          child: _buildReactionComponentRoleField(draft),
                        ),
                        _DesktopReactionFieldCell(
                          width: 76,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildReactionComponentTextField(
                                controller: draft.equivController,
                                hint: 'Equiv',
                              ),
                              _buildReactionHelperLabel(calculatedEquivLabel),
                            ],
                          ),
                        ),
                        _DesktopReactionFieldCell(
                          width: 76,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildReactionComponentTextField(
                                controller: draft.mmolController,
                                hint: 'mmol',
                                onChanged: (_) => setState(() {}),
                              ),
                              _buildReactionHelperLabel(
                                calculatedMolPercentLabel,
                              ),
                            ],
                          ),
                        ),
                        _DesktopReactionFieldCell(
                          width: 116,
                          child: _buildReactionComponentTextField(
                            controller: draft.molecularWeightController,
                            hint: 'Mol. wt.',
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        _DesktopReactionFieldCell(
                          width: 86,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildReactionComponentTextField(
                                controller: draft.amountController,
                                hint: 'Amount',
                              ),
                              _buildReactionHelperLabel(calculatedAmountLabel),
                            ],
                          ),
                        ),
                        _DesktopReactionFieldCell(
                          width: 86,
                          child: _buildReactionComponentUnitField(draft),
                        ),
                        _DesktopReactionFieldCell(
                          width: 90,
                          child: _buildReactionComponentTextField(
                            controller: draft.densityController,
                            hint: 'Density',
                          ),
                        ),
                        _DesktopReactionFieldCell(
                          width: 90,
                          child: _buildReactionComponentTextField(
                            controller: draft.volumeController,
                            hint: 'Volume',
                          ),
                        ),
                        _DesktopReactionFieldCell(
                          width: 150,
                          child: _buildReactionComponentTextField(
                            controller: draft.remarksController,
                            hint: 'Remarks',
                          ),
                        ),
                        _DesktopReactionFieldCell(
                          width: 98,
                          child: _buildLimitingReagentControl(
                            draft,
                            compact: true,
                          ),
                        ),
                        SizedBox(
                          width: 46,
                          child: IconButton(
                            onPressed: () =>
                                _removeReactionComponentRow(draft.id),
                            tooltip: 'Remove row',
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileReactionTable() {
    return Column(
      children: _reactionComponentDrafts.map((draft) {
        final calculatedEquivLabel = _calculatedEquivLabelForDraft(draft);
        final calculatedMolPercentLabel = _calculatedMolPercentLabelForDraft(
          draft,
        );
        final calculatedAmountLabel = _calculatedAmountLabelForDraft(draft);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Builder(
            builder: (context) {
              final palette = context.labmate;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.panelAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            draft.componentNameController.text.trim().isEmpty
                                ? 'Reaction component'
                                : draft.componentNameController.text.trim(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 12.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildLimitingReagentControl(draft, compact: true),
                        IconButton(
                          onPressed: () =>
                              _removeReactionComponentRow(draft.id),
                          tooltip: 'Remove row',
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    _buildAdaptiveFields(
                      [
                        _buildReactionComponentTextField(
                          controller: draft.componentNameController,
                          hint: 'Component name',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Component name is required.';
                            }
                            return null;
                          },
                        ),
                        _buildReactionComponentRoleField(draft),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildReactionComponentTextField(
                              controller: draft.equivController,
                              hint: 'Equiv',
                            ),
                            _buildReactionHelperLabel(calculatedEquivLabel),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildReactionComponentTextField(
                              controller: draft.mmolController,
                              hint: 'mmol',
                              onChanged: (_) => setState(() {}),
                            ),
                            _buildReactionHelperLabel(
                              calculatedMolPercentLabel,
                            ),
                          ],
                        ),
                        _buildReactionComponentTextField(
                          controller: draft.molecularWeightController,
                          hint: 'Molecular weight',
                          onChanged: (_) => setState(() {}),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildReactionComponentTextField(
                              controller: draft.amountController,
                              hint: 'Amount',
                            ),
                            _buildReactionHelperLabel(calculatedAmountLabel),
                          ],
                        ),
                        _buildReactionComponentUnitField(draft),
                        _buildReactionComponentTextField(
                          controller: draft.densityController,
                          hint: 'Density',
                        ),
                        _buildReactionComponentTextField(
                          controller: draft.volumeController,
                          hint: 'Volume',
                        ),
                        _buildReactionComponentTextField(
                          controller: draft.remarksController,
                          hint: 'Remarks',
                        ),
                      ],
                      maxColumns: 2,
                      minItemWidth: 180,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }).toList(),
    );
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

  String _ownerEmailValue() {
    return _effectiveNotebookOwnerEmail;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
      builder: (context, child) {
        return Theme(data: Theme.of(context), child: child!);
      },
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = picked;
      _syncDateField();
    });
  }

  Future<void> _saveExperiment() async {
    if (_isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final labId = _effectiveLabId;
    final ownerUid = _effectiveNotebookOwnerUid;
    final ownerEmail = _ownerEmailValue();
    final projectId = _effectiveProjectId;
    final initialExperiment = widget.initialExperiment;
    final experimentId = initialExperiment?.id.trim() ?? '';
    if (labId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a lab before adding experiments.'),
        ),
      );
      return;
    }

    if (projectId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project context is missing for this experiment.'),
        ),
      );
      return;
    }

    if (ownerUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notebook owner context is missing for this save.'),
        ),
      );
      return;
    }

    if (_isEditMode && experimentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Existing experiment id is missing for edit mode.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final now = Timestamp.now();

    try {
      final reactionComponents = _reactionComponentDrafts
          .map((draft) => draft.toModel())
          .toList(growable: false);

      final experiment = _isEditMode && initialExperiment != null
          ? NotebookExperimentModel(
              id: experimentId,
              experimentCode: _experimentCodeController.text.trim(),
              title: _titleController.text.trim(),
              date: Timestamp.fromDate(_selectedDate),
              aim: _aimController.text.trim(),
              reactionTitle: _reactionTitleController.text.trim(),
              startingMaterial: _startingMaterialController.text.trim(),
              reagents: _reagentsController.text.trim(),
              catalyst: _catalystController.text.trim(),
              solvent: _solventController.text.trim(),
              temperature: _temperatureController.text.trim(),
              startTime: _startTimeController.text.trim(),
              endTime: _endTimeController.text.trim(),
              time: _timeController.text.trim(),
              atmosphere: _atmosphereController.text.trim(),
              scale: _scaleController.text.trim(),
              procedure: _procedureController.text.trim(),
              observations: _observationsController.text.trim(),
              workup: _workupController.text.trim(),
              purification: _purificationController.text.trim(),
              yieldText: _yieldController.text.trim(),
              characterization: _characterizationController.text.trim(),
              conclusion: _conclusionController.text.trim(),
              reactionComponents: reactionComponents,
              editHistory: <ExperimentEditHistoryModel>[
                ...initialExperiment.editHistory,
                ExperimentEditHistoryModel(
                  editedAt: now,
                  editedByUid: ownerUid,
                  editedByEmail: ownerEmail,
                  summary: 'Experiment updated',
                ),
              ],
              status: _selectedStatus,
              ownerUid: initialExperiment.ownerUid.trim().isEmpty
                  ? ownerUid
                  : initialExperiment.ownerUid,
              ownerEmail: initialExperiment.ownerEmail.trim().isEmpty
                  ? ownerEmail
                  : initialExperiment.ownerEmail,
              createdBy: initialExperiment.createdBy,
              userEmail: initialExperiment.userEmail,
              createdAt: initialExperiment.createdAt,
              updatedAt: now,
              labId: initialExperiment.labId.trim().isEmpty
                  ? labId
                  : initialExperiment.labId,
              projectId: initialExperiment.projectId.trim().isEmpty
                  ? projectId
                  : initialExperiment.projectId,
            )
          : NotebookExperimentModel(
              id: '',
              experimentCode: _experimentCodeController.text.trim(),
              title: _titleController.text.trim(),
              date: Timestamp.fromDate(_selectedDate),
              aim: _aimController.text.trim(),
              reactionTitle: _reactionTitleController.text.trim(),
              startingMaterial: _startingMaterialController.text.trim(),
              reagents: _reagentsController.text.trim(),
              catalyst: _catalystController.text.trim(),
              solvent: _solventController.text.trim(),
              temperature: _temperatureController.text.trim(),
              startTime: _startTimeController.text.trim(),
              endTime: _endTimeController.text.trim(),
              time: _timeController.text.trim(),
              atmosphere: _atmosphereController.text.trim(),
              scale: _scaleController.text.trim(),
              procedure: _procedureController.text.trim(),
              observations: _observationsController.text.trim(),
              workup: _workupController.text.trim(),
              purification: _purificationController.text.trim(),
              yieldText: _yieldController.text.trim(),
              characterization: _characterizationController.text.trim(),
              conclusion: _conclusionController.text.trim(),
              reactionComponents: reactionComponents,
              editHistory: const <ExperimentEditHistoryModel>[],
              status: _selectedStatus,
              ownerUid: ownerUid,
              ownerEmail: ownerEmail,
              createdBy: _createdByValue(),
              userEmail: ownerEmail,
              createdAt: now,
              updatedAt: now,
              labId: labId,
              projectId: projectId,
            );

      if (_isEditMode && initialExperiment != null) {
        await _labNotebookService.updateExperiment(
          experiment: experiment,
          notebookOwnerUid: ownerUid,
        );
      } else {
        final createdExperimentId = await _labNotebookService.addExperiment(
          experiment: experiment,
          notebookOwnerUid: ownerUid,
        );

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isDuplicateDraftMode
                  ? 'Duplicated experiment saved.'
                  : 'Experiment saved successfully.',
            ),
          ),
        );
        Navigator.pop(context, createdExperimentId);
        return;
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Experiment updated.'
                : 'Experiment saved successfully.',
          ),
        ),
      );
      Navigator.pop(context, experimentId);
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
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildBlockedState() {
    return const Center(
      child: _DraftNotice(
        icon: Icons.science_outlined,
        title: 'No lab selected',
        message: 'Choose an active lab before adding notebook experiments.',
        accent: Color(0xFF38BDF8),
      ),
    );
  }

  Widget _buildAuthRequiredState() {
    return const Center(
      child: _DraftNotice(
        icon: Icons.lock_outline_rounded,
        title: 'Sign in to create a private experiment record',
        message:
            'Notebook experiments now belong to an individual member account. Sign in first, then return to add this experiment.',
        accent: Color(0xFFFBBF24),
      ),
    );
  }

  Widget _buildHeaderBar({required bool isWide}) {
    final projectTitle = widget.project.title.trim().isEmpty
        ? 'Untitled project'
        : widget.project.title.trim();
    final labLabel = widget.appState.selectedLabName.trim().isEmpty
        ? widget.project.labId
        : widget.appState.selectedLabName.trim();

    return Builder(
      builder: (context) {
        final palette = context.labmate;
        final colorScheme = context.colorScheme;
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DraftBadge(
                  icon: Icons.edit_note_rounded,
                  label: _isEditMode
                      ? 'Edit Mode'
                      : _isDuplicateDraftMode
                      ? 'Duplicate Draft'
                      : 'New Experiment Draft',
                  accent: const Color(0xFF5EEAD4),
                ),
                _DraftBadge(
                  icon: Icons.folder_open_rounded,
                  label: projectTitle,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _draftTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: isWide ? 20 : 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$projectTitle • $labLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );

        final saveButton = SizedBox(
          width: isWide ? 220 : double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveExperiment,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14B8A6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            icon: _isSaving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(
              _saveButtonLabel,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: palette.panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.border),
          ),
          child: isWide
              ? Row(
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    saveButton,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: palette.panelAlt,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _isEditMode
                            ? 'Review the current experiment details, then save to update the existing record.'
                            : _isDuplicateDraftMode
                            ? 'Review the copied setup, adjust any details, then save the new experiment.'
                            : 'Required: experiment code, title, date, and status.',
                        style: TextStyle(
                          color: palette.mutedText,
                          fontSize: 12.2,
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildDuplicateInfoBanner() {
    if (!_isDuplicateDraftMode && !_isEditMode) {
      return const SizedBox.shrink();
    }

    return Builder(
      builder: (context) {
        final palette = context.labmate;
        final sourceCode =
            widget.initialExperiment?.experimentCode.trim() ?? '';
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF14B8A6).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF14B8A6).withValues(alpha: 0.26),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _isEditMode ? Icons.history_rounded : Icons.copy_all_rounded,
                color: Color(0xFF5EEAD4),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isEditMode
                      ? 'Editing [${sourceCode.isEmpty ? 'experiment' : sourceCode}]. Saving updates this experiment and adds a history entry.'
                      : 'Copied setup from [$_duplicateSourceCode]. Notes and results are not copied.',
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 12.3,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProjectContextCard() {
    final projectTitle = widget.project.title.trim().isEmpty
        ? 'Untitled project'
        : widget.project.title.trim();
    final statusColor = _statusColor(_selectedStatus);
    final description = widget.project.description.trim();

    return Builder(
      builder: (context) {
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
              Row(
                children: [
                  Container(
                    height: 32,
                    width: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.biotech_rounded,
                      color: Color(0xFF5EEAD4),
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Draft Context',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 14.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isEditMode
                              ? 'Project and existing experiment details'
                              : _isDuplicateDraftMode
                              ? 'Project and copied setup'
                              : 'Project and required fields',
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
              const SizedBox(height: 11),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: palette.panelAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Project',
                      style: TextStyle(
                        color: palette.subtleText,
                        fontSize: 10.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      projectTitle,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 13.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.mutedText,
                          fontSize: 12.0,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DraftBadge(
                    icon: Icons.flag_rounded,
                    label: _selectedStatus,
                    accent: statusColor,
                  ),
                  const _DraftBadge(
                    icon: Icons.checklist_rounded,
                    label: 'Code required',
                  ),
                  const _DraftBadge(
                    icon: Icons.checklist_rounded,
                    label: 'Title required',
                  ),
                  const _DraftBadge(
                    icon: Icons.checklist_rounded,
                    label: 'Date required',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSchemePlaceholder() {
    return Builder(
      builder: (context) {
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
              Text(
                'Reaction Scheme Slot',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 14.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Add scheme / ChemDraw image later',
                style: TextStyle(color: palette.subtleText, fontSize: 11.4),
              ),
              const SizedBox(height: 11),
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: palette.panelAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.device_hub_rounded,
                      color: Color(0xFF5EEAD4),
                      size: 24,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Reaction Scheme',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 13.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Placeholder only for now',
                      style: TextStyle(
                        color: palette.subtleText,
                        fontSize: 11.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverviewSection() {
    return _buildSection(
      title: 'Overview',
      subtitle: 'Identity, date, status, and aim',
      child: Builder(
        builder: (context) {
          return Column(
            children: [
              _buildAdaptiveFields([
                _buildTextField(
                  controller: _experimentCodeController,
                  label: 'Experiment Code',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Experiment code is required.';
                    }
                    return null;
                  },
                ),
                _buildTextField(
                  controller: _titleController,
                  label: 'Title',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Experiment title is required.';
                    }
                    return null;
                  },
                ),
                _buildTextField(
                  controller: _dateController,
                  label: 'Date',
                  readOnly: true,
                  onTap: _pickDate,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Experiment date is required.';
                    }
                    return null;
                  },
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey(_selectedStatus),
                  initialValue: _selectedStatus,
                  dropdownColor: context.labmate.panelAlt,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12.8,
                  ),
                  decoration: _inputDecoration(context, 'Status'),
                  items: notebookExperimentStatuses.map((status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(
                        status,
                        style: TextStyle(color: _statusColor(status)),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _selectedStatus = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Experiment status is required.';
                    }
                    return null;
                  },
                ),
              ]),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _aimController,
                label: 'Aim',
                minLines: 3,
                maxLines: 4,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReactionSetupSection() {
    final setupFields = <Widget>[
      _buildTextField(
        controller: _reactionTitleController,
        label: 'Reaction Title',
      ),
      _buildTextField(controller: _solventController, label: 'Solvent'),
      _buildTextField(controller: _temperatureController, label: 'Temperature'),
      _buildTextField(controller: _startTimeController, label: 'Start Time'),
      _buildTextField(controller: _endTimeController, label: 'End Time'),
      _buildTextField(controller: _atmosphereController, label: 'Atmosphere'),
    ];

    return _buildSection(
      title: 'Reaction Setup',
      subtitle:
          'Core conditions live here. Use the reaction table for materials and stoichiometry.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_showLegacyTimeNotice) ...[
            _buildInfoBanner(
              icon: Icons.schedule_rounded,
              accent: const Color(0xFFFBBF24),
              message:
                  'Legacy time is preserved as "${_timeController.text.trim()}". Add start/end times when you want to move this experiment to the new format.',
            ),
            const SizedBox(height: 10),
          ],
          if (_preservesLegacySetupFields) ...[
            _buildInfoBanner(
              icon: Icons.archive_outlined,
              accent: const Color(0xFF38BDF8),
              message:
                  'Older setup text fields are being preserved in the background for compatibility. New material planning should go in the reaction table below.',
            ),
            const SizedBox(height: 10),
          ],
          _buildAdaptiveFields(setupFields, maxColumns: 3, minItemWidth: 180),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    return _buildSection(
      title: 'Procedure and Results',
      subtitle: 'Experimental record, observations, and outcome',
      child: Column(
        children: [
          _buildAdaptiveFields([
            _buildTextField(
              controller: _procedureController,
              label: 'Procedure',
              minLines: 4,
              maxLines: 6,
            ),
            _buildTextField(
              controller: _observationsController,
              label: 'Observations',
              minLines: 4,
              maxLines: 6,
            ),
          ], minItemWidth: 260),
          const SizedBox(height: 10),
          _buildAdaptiveFields([
            _buildTextField(
              controller: _workupController,
              label: 'Workup',
              minLines: 4,
              maxLines: 6,
            ),
            _buildTextField(
              controller: _purificationController,
              label: 'Purification',
              minLines: 4,
              maxLines: 6,
            ),
          ], minItemWidth: 260),
          const SizedBox(height: 10),
          _buildTextField(controller: _yieldController, label: 'Yield'),
          const SizedBox(height: 10),
          _buildAdaptiveFields([
            _buildTextField(
              controller: _characterizationController,
              label: 'Characterization',
              minLines: 4,
              maxLines: 6,
            ),
            _buildTextField(
              controller: _conclusionController,
              label: 'Conclusion',
              minLines: 4,
              maxLines: 6,
            ),
          ], minItemWidth: 260),
        ],
      ),
    );
  }

  Widget _buildFormWorkspace(bool isWide) {
    final mobileSaveButton = SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveExperiment,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF14B8A6),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: _isSaving
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save_rounded, size: 18),
        label: Text(
          _saveButtonLabel,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 330,
            child: Column(
              children: [
                _buildProjectContextCard(),
                const SizedBox(height: 10),
                _buildOverviewSection(),
                const SizedBox(height: 10),
                _buildSchemePlaceholder(),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                _buildReactionSetupSection(),
                const SizedBox(height: 10),
                _buildReactionTableSection(),
                const SizedBox(height: 10),
                _buildResultsSection(),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildProjectContextCard(),
        const SizedBox(height: 10),
        _buildOverviewSection(),
        const SizedBox(height: 10),
        _buildSchemePlaceholder(),
        const SizedBox(height: 10),
        _buildReactionSetupSection(),
        const SizedBox(height: 10),
        _buildReactionTableSection(),
        const SizedBox(height: 10),
        _buildResultsSection(),
        const SizedBox(height: 12),
        mobileSaveButton,
      ],
    );
  }

  @override
  void dispose() {
    _experimentCodeController.dispose();
    _titleController.dispose();
    _dateController.dispose();
    _aimController.dispose();
    _reactionTitleController.dispose();
    _startingMaterialController.dispose();
    _reagentsController.dispose();
    _catalystController.dispose();
    _solventController.dispose();
    _temperatureController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _timeController.dispose();
    _atmosphereController.dispose();
    _scaleController.dispose();
    _procedureController.dispose();
    _observationsController.dispose();
    _workupController.dispose();
    _purificationController.dispose();
    _yieldController.dispose();
    _characterizationController.dispose();
    _conclusionController.dispose();
    for (final draft in _reactionComponentDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = FirestoreAccessGuard.shouldQueryLabScopedData(
      appState: widget.appState,
    );
    final hasAuthenticatedOwner = widget.appState.authenticatedUserId
        .trim()
        .isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _isEditMode
              ? 'Edit Experiment'
              : _isDuplicateDraftMode
              ? 'Duplicate Experiment Draft'
              : 'New Experiment',
        ),
      ),
      body: ResponsivePageContainer(
        maxWidth: 1500,
        child: SafeArea(
          child: canSave
              ? hasAuthenticatedOwner
                    ? Form(
                        key: _formKey,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 1040;

                            return SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  _buildHeaderBar(isWide: isWide),
                                  if (_isDuplicateDraftMode || _isEditMode) ...[
                                    const SizedBox(height: 10),
                                    _buildDuplicateInfoBanner(),
                                  ],
                                  const SizedBox(height: 10),
                                  _buildFormWorkspace(isWide),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    : _buildAuthRequiredState()
              : _buildBlockedState(),
        ),
      ),
    );
  }
}

class _DraftNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color accent;

  const _DraftNotice({
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

class _DraftBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accent;

  const _DraftBadge({required this.icon, required this.label, this.accent});

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

class _DesktopReactionHeaderCell extends StatelessWidget {
  final String label;
  final double width;

  const _DesktopReactionHeaderCell(this.label, this.width);

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

class _DesktopReactionFieldCell extends StatelessWidget {
  final double width;
  final Widget child;

  const _DesktopReactionFieldCell({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: child);
  }
}

class _ReactionComponentDraft {
  final String id;
  final TextEditingController componentNameController;
  final TextEditingController formulaOrNotesController;
  final TextEditingController mmolController;
  final TextEditingController equivController;
  final TextEditingController molecularWeightController;
  final TextEditingController amountController;
  final TextEditingController densityController;
  final TextEditingController volumeController;
  final TextEditingController supplierOrSourceController;
  final TextEditingController remarksController;
  String role;
  String unit;
  bool isLimitingReagent;

  _ReactionComponentDraft({
    required this.id,
    required String componentName,
    required this.role,
    required String formulaOrNotes,
    required String mmol,
    required String equiv,
    required String molecularWeight,
    required String amount,
    required this.unit,
    required String density,
    required String volume,
    required String supplierOrSource,
    required String remarks,
    required this.isLimitingReagent,
  }) : componentNameController = TextEditingController(text: componentName),
       formulaOrNotesController = TextEditingController(text: formulaOrNotes),
       mmolController = TextEditingController(text: mmol),
       equivController = TextEditingController(text: equiv),
       molecularWeightController = TextEditingController(text: molecularWeight),
       amountController = TextEditingController(text: amount),
       densityController = TextEditingController(text: density),
       volumeController = TextEditingController(text: volume),
       supplierOrSourceController = TextEditingController(
         text: supplierOrSource,
       ),
       remarksController = TextEditingController(text: remarks);

  ReactionComponentModel toModel() {
    return ReactionComponentModel(
      componentName: componentNameController.text.trim(),
      role: role.trim(),
      formulaOrNotes: formulaOrNotesController.text.trim(),
      mmol: mmolController.text.trim(),
      equiv: equivController.text.trim(),
      molecularWeight: molecularWeightController.text.trim(),
      amount: amountController.text.trim(),
      unit: unit.trim(),
      density: densityController.text.trim(),
      volume: volumeController.text.trim(),
      supplierOrSource: supplierOrSourceController.text.trim(),
      remarks: remarksController.text.trim(),
      isLimitingReagent: isLimitingReagent,
    );
  }

  void dispose() {
    componentNameController.dispose();
    formulaOrNotesController.dispose();
    mmolController.dispose();
    equivController.dispose();
    molecularWeightController.dispose();
    amountController.dispose();
    densityController.dispose();
    volumeController.dispose();
    supplierOrSourceController.dispose();
    remarksController.dispose();
  }
}
