import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/lab_context_model.dart';
import '../services/lab_service.dart';
import '../services/lab_membership_service.dart';
import 'home_screen.dart';

class CreateLabScreen extends StatefulWidget {
  final AppState appState;

  const CreateLabScreen({
    super.key,
    required this.appState,
  });

  @override
  State<CreateLabScreen> createState() => _CreateLabScreenState();
}

class _CreateLabScreenState extends State<CreateLabScreen> {
  final _formKey = GlobalKey<FormState>();
  final LabService _labService = LabService();
  final LabMembershipService _labMembershipService = LabMembershipService();
  final TextEditingController _labNameController = TextEditingController();
  final TextEditingController _instituteController = TextEditingController();

  bool isSaving = false;

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
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSaving = true;
    });

    try {
      final labName = _labNameController.text.trim();
      final currentUserId = widget.appState.authenticatedUserId;
      final piAdminRole = DemoUserRole.piAdmin.name;
      Map<String, String>? createdLab;
      String dialogMessage;

      try {
        createdLab = await _labService.createLab(
          labName: labName,
          institute: _instituteController.text.trim(),
          createdBy: widget.appState.authenticatedUserName,
        );

        final remoteContext = LabContextModel(
          selectedLabId: createdLab['labId'] ?? '',
          selectedLabName: createdLab['labName'] ?? labName,
        );

        String localRoleName = '';

        if (currentUserId.isNotEmpty) {
          try {
            await _labMembershipService.upsertMembership(
              userId: currentUserId,
              labId: remoteContext.selectedLabId,
              role: piAdminRole,
            );
          } catch (_) {
            localRoleName = piAdminRole;
          }
        } else {
          localRoleName = piAdminRole;
        }

        await widget.appState.saveSelectedLabContextWithRole(
          remoteContext,
          localRoleName: localRoleName,
        );

        if (localRoleName.isEmpty) {
          dialogMessage =
              '${createdLab['labName'] ?? labName} is ready to use on this device, and you have been added as PI/Admin.';
        } else {
          dialogMessage =
              '${createdLab['labName'] ?? labName} is ready to use on this device. PI/Admin access is stored locally for now.';
        }
      } catch (_) {
        final localContext = _labService.buildLocalLabContext(labName);
        await widget.appState.saveSelectedLabContextWithRole(
          localContext,
          localRoleName: piAdminRole,
        );
        dialogMessage =
            '$labName was saved as a local lab context on this device, and you can continue as PI/Admin right away.';
      }

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text(
              'Lab Created',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dialogMessage,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                if (createdLab != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Lab Code: ${createdLab['labCode'] ?? '-'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Continue',
                  style: TextStyle(color: Color(0xFF14B8A6)),
                ),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(appState: widget.appState),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Lab',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'Create a minimal Labmate lab workspace. The lab name is required, institute is optional, and a simple lab code will be generated for joining later.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                decoration: _inputDecoration('Institute (optional)'),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Lab'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
