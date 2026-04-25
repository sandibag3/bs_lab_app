import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../services/lab_membership_service.dart';
import '../services/lab_service.dart';

class LabSettingsScreen extends StatefulWidget {
  final AppState appState;

  const LabSettingsScreen({
    super.key,
    required this.appState,
  });

  @override
  State<LabSettingsScreen> createState() => _LabSettingsScreenState();
}

class _LabSettingsScreenState extends State<LabSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final LabService _labService = LabService();
  final LabMembershipService _labMembershipService = LabMembershipService();
  final TextEditingController _labNameController = TextEditingController();
  final TextEditingController _instituteController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCleaningUp = false;
  bool _isEditable = false;
  bool _isRemoteLab = false;
  String _labCode = '';
  String _helperText = '';

  @override
  void initState() {
    super.initState();
    _loadLabDetails();
  }

  @override
  void dispose() {
    _labNameController.dispose();
    _instituteController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _loadLabDetails() async {
    final appState = widget.appState;
    final selectedLabId = appState.selectedLabId.trim();
    var resolvedLabName = appState.selectedLabName.trim();
    var resolvedInstitute = '';
    var resolvedLabCode = '';
    var helperText = '';
    var isEditable = false;
    var isRemoteLab = false;

    if (selectedLabId.isEmpty) {
      resolvedLabName = 'No lab selected';
      helperText = 'Select, create, or join a lab to manage its settings.';
    } else if (appState.isLocalFallbackLabSelected) {
      if (resolvedLabName.isEmpty) {
        resolvedLabName = 'Local Lab';
      }
      resolvedLabCode = selectedLabId;
      helperText =
          'This lab is stored only on this device, so shared lab settings are read-only here.';
    } else {
      isRemoteLab = true;
      var loadedRemoteDetails = false;
      try {
        final details = await _labService.getLabDetails(selectedLabId);
        if (details.isNotEmpty) {
          loadedRemoteDetails = true;
          resolvedLabName =
              (details['labName'] ?? resolvedLabName).toString().trim();
          resolvedInstitute =
              (details['institute'] ?? '').toString().trim();
          resolvedLabCode = (details['labCode'] ?? '').toString().trim();
        }
      } catch (_) {
        resolvedLabName = resolvedLabName.isEmpty ? selectedLabId : resolvedLabName;
      }

      if (resolvedLabName.isEmpty) {
        resolvedLabName = selectedLabId;
      }
      if (resolvedLabCode.isEmpty) {
        resolvedLabCode = selectedLabId;
      }

      isEditable = loadedRemoteDetails && appState.isPiAdmin;
      helperText = loadedRemoteDetails
          ? (isEditable
              ? 'Update the basic details for this lab and share the join code with collaborators.'
              : 'You can view the current lab settings here. Only PI/Admin can edit them.')
          : 'This lab could not be loaded right now. You can still view the current lab context and join code.';
    }

    if (!mounted) return;

    _labNameController.text = resolvedLabName;
    _instituteController.text = resolvedInstitute;

    setState(() {
      _labCode = resolvedLabCode;
      _helperText = helperText;
      _isEditable = isEditable;
      _isRemoteLab = isRemoteLab;
      _isLoading = false;
    });
  }

  Future<void> _copyLabCode() async {
    final code = _labCode.trim();
    if (code.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: code));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lab code copied'),
      ),
    );
  }

  Future<void> _saveLabDetails() async {
    if (!_isEditable || !_isRemoteLab) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedLabName = _labNameController.text.trim();
      final updatedInstitute = _instituteController.text.trim();

      await _labService.updateLabDetails(
        labId: widget.appState.selectedLabId,
        labName: updatedLabName,
        institute: updatedInstitute,
      );

      await widget.appState.updateSelectedLabName(updatedLabName);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lab settings updated'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update lab settings: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _runDummyLabCleanup() async {
    if (_isCleaningUp || !_isEditable || !_isRemoteLab) {
      return;
    }

    setState(() {
      _isCleaningUp = true;
    });

    try {
      final candidates = await _labService.getDummyTestLabCandidates();

      if (candidates.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No dummy/test labs found.'),
          ),
        );
        return;
      }

      final previewItems = candidates.take(6).map((candidate) {
        final labName = candidate['labName'] ?? candidate['labId'] ?? 'Lab';
        final labCode = (candidate['labCode'] ?? '').trim();
        return labCode.isEmpty ? labName : '$labName ($labCode)';
      }).toList();

      final extraCount = candidates.length - previewItems.length;

      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text(
              'Remove Dummy/Test Labs?',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will delete the matching lab documents and their related memberships.',
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                ...previewItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '- $item',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                if (extraCount > 0)
                  Text(
                    '...and $extraCount more',
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Color(0xFFFB7185)),
                ),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        return;
      }

      final labIds = candidates
          .map((candidate) => (candidate['labId'] ?? '').trim())
          .where((labId) => labId.isNotEmpty)
          .toList();

      final deletedMemberships =
          await _labMembershipService.deleteMembershipsForLabs(labIds);
      final deletedLabs = await _labService.deleteLabsByIds(labIds);

      final removedCurrentLab = labIds.contains(widget.appState.selectedLabId.trim());
      if (removedCurrentLab) {
        await widget.appState.clearSessionContext();
      }

      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      await _loadLabDetails();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Removed $deletedLabs dummy/test labs and $deletedMemberships related memberships.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not complete cleanup: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCleaningUp = false;
        });
      }
    }
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Lab Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.appState.currentRoleLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _helperText,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    final instituteText = _instituteController.text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lab Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          if (_isEditable && _isRemoteLab) ...[
            TextFormField(
              controller: _labNameController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Lab Name'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter lab name';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _instituteController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Institute'),
            ),
          ] else ...[
            _buildDetailRow(
              label: 'Lab Name',
              value: _labNameController.text.trim().isEmpty
                  ? 'Not set'
                  : _labNameController.text.trim(),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              label: 'Institute',
              value: instituteText.isEmpty ? 'Not set' : instituteText,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInviteCard() {
    final displayCode = _labCode.trim().isEmpty ? 'Not available' : _labCode.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invite',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use this code when someone joins the lab.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.68),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: SelectableText(
              displayCode,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: displayCode == 'Not available' ? null : _copyLabCode,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: Colors.white.withOpacity(0.18),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy Code'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanupCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Temporary Cleanup',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Admin-only action to remove labs explicitly marked as dummy/test, along with their memberships.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.68),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _isCleaningUp ? null : _runDummyLabCleanup,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFB7185),
              side: const BorderSide(
                color: Color(0xFFFB7185),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            icon: _isCleaningUp
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFB7185),
                    ),
                  )
                : const Icon(Icons.delete_sweep_rounded),
            label: Text(
              _isCleaningUp ? 'Cleaning Up...' : 'Remove Dummy/Test Labs',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lab Settings',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 16),
                    _buildSettingsCard(),
                    const SizedBox(height: 16),
                    _buildInviteCard(),
                    if (_isEditable && _isRemoteLab) ...[
                      const SizedBox(height: 16),
                      _buildCleanupCard(),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveLabDetails,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF14B8A6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
