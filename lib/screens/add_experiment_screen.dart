import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/notebook_experiment_model.dart';
import '../models/notebook_project_model.dart';
import '../services/firestore_access_guard.dart';
import '../services/lab_notebook_service.dart';
import '../theme/labmate_theme.dart';
import '../widgets/responsive_page_container.dart';

class AddExperimentScreen extends StatefulWidget {
  final AppState appState;
  final NotebookProjectModel project;

  const AddExperimentScreen({
    super.key,
    required this.appState,
    required this.project,
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

  @override
  void initState() {
    super.initState();
    _syncDateField();
  }

  void _syncDateField() {
    final day = _selectedDate.day.toString().padLeft(2, '0');
    final month = _selectedDate.month.toString().padLeft(2, '0');
    _dateController.text = '$day/$month/${_selectedDate.year}';
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

    final labId = widget.appState.resolveWriteLabId(widget.project.labId);
    final ownerUid = widget.appState.authenticatedUserId.trim();
    final ownerEmail = widget.appState.authenticatedUserEmail.trim();
    if (labId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a lab before adding experiments.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final now = Timestamp.now();

    try {
      final experiment = NotebookExperimentModel(
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
        status: _selectedStatus,
        ownerUid: ownerUid,
        ownerEmail: ownerEmail,
        createdBy: _createdByValue(),
        userEmail: ownerEmail,
        createdAt: now,
        updatedAt: now,
        labId: labId,
        projectId: widget.project.id,
      );

      await _labNotebookService.addExperiment(experiment: experiment);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Experiment saved successfully.')),
      );
      Navigator.pop(context, true);
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
                const _DraftBadge(
                  icon: Icons.edit_note_rounded,
                  label: 'New Experiment Draft',
                  accent: Color(0xFF5EEAD4),
                ),
                _DraftBadge(
                  icon: Icons.folder_open_rounded,
                  label: projectTitle,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              projectTitle,
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
              labLabel,
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
            label: const Text(
              'Save Experiment',
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
                        'Required: experiment code, title, date, and status.',
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
                          'Project and required fields',
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
    return _buildSection(
      title: 'Reaction Setup',
      subtitle: 'Substrates, reagents, and reaction conditions',
      child: Column(
        children: [
          _buildAdaptiveFields([
            _buildTextField(
              controller: _reactionTitleController,
              label: 'Reaction Title',
            ),
            _buildTextField(
              controller: _startingMaterialController,
              label: 'Starting Material',
            ),
          ]),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _reagentsController,
            label: 'Reagents',
            minLines: 2,
            maxLines: 3,
          ),
          const SizedBox(height: 10),
          _buildAdaptiveFields(
            [
              _buildTextField(
                controller: _catalystController,
                label: 'Catalyst',
              ),
              _buildTextField(controller: _solventController, label: 'Solvent'),
              _buildTextField(
                controller: _temperatureController,
                label: 'Temperature',
              ),
              _buildTextField(controller: _timeController, label: 'Time'),
              _buildTextField(
                controller: _atmosphereController,
                label: 'Atmosphere',
              ),
              _buildTextField(controller: _scaleController, label: 'Scale'),
            ],
            maxColumns: 3,
            minItemWidth: 180,
          ),
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
        label: const Text(
          'Save Experiment',
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
      appBar: AppBar(title: const Text('New Experiment')),
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
