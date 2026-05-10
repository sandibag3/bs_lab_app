import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/lab_context_model.dart';
import '../services/firestore_access_guard.dart';
import '../services/lab_service.dart';
import '../services/lab_membership_service.dart';
import 'home_screen.dart';

class JoinLabScreen extends StatefulWidget {
  final AppState appState;

  const JoinLabScreen({super.key, required this.appState});

  @override
  State<JoinLabScreen> createState() => _JoinLabScreenState();
}

class _JoinLabScreenState extends State<JoinLabScreen> {
  final _formKey = GlobalKey<FormState>();
  final LabService _labService = LabService();
  final LabMembershipService _labMembershipService = LabMembershipService();
  final TextEditingController _identifierController = TextEditingController();
  String _selectedRoleName = DemoUserRole.researcher.name;

  bool isJoining = false;

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  String _roleLabel(String roleName) {
    return widget.appState.roleLabelFor(roleName);
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
      isJoining = true;
    });

    try {
      final identifier = _identifierController.text.trim();
      final currentUserId = widget.appState.authenticatedUserId;
      final selectedRoleName = _selectedRoleName;
      LabContextModel? foundLab;

      try {
        foundLab = await _labService.findLabByIdentifier(identifier);
      } on LabDataAccessException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
        return;
      } catch (_) {
        foundLab = null;
      }

      final LabContextModel selectedContext;
      final String statusMessage;

      if (foundLab != null) {
        selectedContext = foundLab;

        if (selectedRoleName == DemoUserRole.piAdmin.name) {
          final hasPiAdmin = await _labMembershipService.labHasActivePiAdmin(
            labId: foundLab.selectedLabId,
            excludingUserId: currentUserId,
          );

          if (hasPiAdmin) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'This lab already has a PI/Admin. Join with a non-PI role.',
                ),
              ),
            );
            return;
          }
        }

        String localRoleName = '';
        if (currentUserId.isNotEmpty) {
          try {
            await _labMembershipService.upsertMembership(
              userId: currentUserId,
              labId: foundLab.selectedLabId,
              role: selectedRoleName,
              userName: widget.appState.authenticatedUserName,
              userEmail: widget.appState.authenticatedUserEmail,
              labName: foundLab.selectedLabName,
            );
          } catch (_) {
            localRoleName = selectedRoleName;
          }
        } else {
          localRoleName = selectedRoleName;
        }

        await widget.appState.saveSelectedLabContextWithRole(
          selectedContext,
          localRoleName: localRoleName,
        );

        if (localRoleName.isEmpty) {
          statusMessage =
              'Joined ${foundLab.selectedLabName} as ${_roleLabel(selectedRoleName)}';
        } else {
          statusMessage =
              'Joined ${foundLab.selectedLabName}. ${_roleLabel(selectedRoleName)} access is stored locally for now.';
        }
      } else {
        selectedContext = _labService.buildLocalLabContext(identifier);
        await widget.appState.saveSelectedLabContextWithRole(
          selectedContext,
          localRoleName: selectedRoleName,
        );
        statusMessage =
            'No shared lab found. Using a local lab context for "$identifier".';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(statusMessage)));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(appState: widget.appState),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(FirestoreAccessGuard.messageFor(e))),
      );
    } finally {
      if (mounted) {
        setState(() {
          isJoining = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Lab', style: TextStyle(color: Colors.white)),
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
                  'Enter a shared lab code from Create Lab, an existing lab document id, or a mock identifier for a temporary local lab context on this device.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _identifierController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Lab Code or Identifier'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a lab code or identifier';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _selectedRoleName,
                dropdownColor: const Color(0xFF1E293B),
                decoration: _inputDecoration('Join as'),
                style: const TextStyle(color: Colors.white),
                items: DemoUserRole.values.map((role) {
                  return DropdownMenuItem<String>(
                    value: role.name,
                    child: Text(role.label),
                  );
                }).toList(),
                onChanged: isJoining
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedRoleName = value;
                        });
                      },
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isJoining ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isJoining
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Join Lab'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
