import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/lab_membership_model.dart';
import '../models/user_profile.dart';
import '../services/lab_membership_service.dart';
import '../services/user_profile_service.dart';

class LabMembersScreen extends StatefulWidget {
  final AppState appState;

  const LabMembersScreen({super.key, required this.appState});

  @override
  State<LabMembersScreen> createState() => _LabMembersScreenState();
}

class _LabMembersScreenState extends State<LabMembersScreen> {
  static const Map<String, String> _editableRoles = {
    'piAdmin': 'PI/Admin',
    'phdScholar': 'PhD Scholar',
    'undergradStudent': 'Undergrad Student',
    'projectStudent': 'Project Student',
    'postdocFellow': 'Postdoc Fellow',
    'labManager': 'Lab Manager',
  };

  final LabMembershipService _labMembershipService = LabMembershipService();
  final UserProfileService _userProfileService = UserProfileService();

  late Future<_LabMembersData> _membersFuture;
  String _updatingMemberUserId = '';

  @override
  void initState() {
    super.initState();
    _membersFuture = _loadMembers();
  }

  Future<_LabMembersData> _loadMembers() async {
    final labId = widget.appState.selectedLabId.trim();
    if (labId.isEmpty ||
        widget.appState.isDemoLabSelected ||
        widget.appState.isLocalFallbackLabSelected) {
      return const _LabMembersData(members: []);
    }

    try {
      final memberships = await _labMembershipService.getMembershipsForLab(
        labId: labId,
      );
      final profiles = await _userProfileService.getUserProfilesByIds(
        memberships.map((membership) => membership.userId),
      );

      return _LabMembersData(
        members: memberships.map((membership) {
          return _LabMemberDetails(
            membership: membership,
            profile: profiles[membership.userId.trim()],
          );
        }).toList(),
      );
    } catch (_) {
      return const _LabMembersData(members: []);
    }
  }

  Future<void> _refreshMembers() async {
    setState(() {
      _membersFuture = _loadMembers();
    });
    await _membersFuture;
  }

  String _memberName(_LabMemberDetails member) {
    final profileName = member.profile?.name.trim() ?? '';
    if (profileName.isNotEmpty && profileName != 'Your Name') {
      return profileName;
    }

    final userName = member.membership.userName.trim();
    if (userName.isNotEmpty) {
      return userName;
    }

    final userEmail = member.membership.userEmail.trim();
    if (userEmail.isNotEmpty) {
      return userEmail;
    }

    if (member.membership.userId.trim() ==
        widget.appState.authenticatedUserId) {
      return widget.appState.authenticatedUserName;
    }

    return member.membership.userId.trim().isEmpty
        ? 'Member'
        : member.membership.userId.trim();
  }

  String _memberEmail(_LabMemberDetails member) {
    final userEmail = member.membership.userEmail.trim();
    if (userEmail.isNotEmpty) {
      return userEmail;
    }

    return member.membership.userId.trim();
  }

  Future<void> _showRoleEditor(_LabMemberDetails member) async {
    if (!widget.appState.isPiAdmin || _updatingMemberUserId.isNotEmpty) {
      return;
    }

    final membership = member.membership;
    final memberUserId = membership.userId.trim();
    final labId = membership.labId.trim();
    final currentRole = membership.role.trim();
    final isCurrentUser = memberUserId == widget.appState.authenticatedUserId;
    final messenger = ScaffoldMessenger.of(context);

    var selectedRole = _editableRoles.containsKey(currentRole)
        ? currentRole
        : 'phdScholar';

    final newRole = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text(
                'Edit Member Role',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    dropdownColor: const Color(0xFF1E293B),
                    decoration: InputDecoration(
                      labelText: 'Role',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    items: _editableRoles.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedRole = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, selectedRole),
                  child: const Text(
                    'Save',
                    style: TextStyle(color: Color(0xFF14B8A6)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (newRole == null || newRole == currentRole) {
      return;
    }

    final assigningPiAdmin = newRole == 'piAdmin';
    final demotingPiAdmin = currentRole == 'piAdmin' && newRole != 'piAdmin';

    if (isCurrentUser) {
      final hasAnotherPiAdmin = await _labMembershipService.labHasActivePiAdmin(
        labId: labId,
        excludingUserId: memberUserId,
      );
      if (!hasAnotherPiAdmin) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Another PI/Admin must exist before you can change your own role.',
            ),
          ),
        );
        return;
      }
    }

    if (assigningPiAdmin) {
      final hasAnotherPiAdmin = await _labMembershipService.labHasActivePiAdmin(
        labId: labId,
        excludingUserId: memberUserId,
      );
      if (hasAnotherPiAdmin) {
        messenger.showSnackBar(
          const SnackBar(content: Text('This lab already has a PI/Admin.')),
        );
        return;
      }
    }

    if (demotingPiAdmin) {
      final hasAnotherPiAdmin = await _labMembershipService.labHasActivePiAdmin(
        labId: labId,
        excludingUserId: memberUserId,
      );
      if (!hasAnotherPiAdmin) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('A lab must always have at least one PI/Admin.'),
          ),
        );
        return;
      }
    }

    setState(() {
      _updatingMemberUserId = memberUserId;
    });

    try {
      await _labMembershipService.updateMembershipRole(
        userId: memberUserId,
        labId: labId,
        role: newRole,
      );

      if (isCurrentUser) {
        await widget.appState.refreshSelectedLabRole();
      }

      await _refreshMembers();

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Role updated to ${widget.appState.roleLabelFor(newRole)}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update role: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingMemberUserId = '';
        });
      }
    }
  }

  Widget _buildHeaderCard(String helperText) {
    final selectedLabName = widget.appState.selectedLabName.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Lab',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            selectedLabName.isEmpty ? 'No lab selected' : selectedLabName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            helperText,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalMemberCard({required String sourceLabel}) {
    return Column(
      children: [
        _buildHeaderCard(
          'This lab context is using the local role flow, so only the current user is shown here for now.',
        ),
        const SizedBox(height: 12),
        _MemberTile(
          name: widget.appState.authenticatedUserName,
          email: widget.appState.authenticatedUserEmail.isEmpty
              ? 'Current user'
              : widget.appState.authenticatedUserEmail,
          roleLabel: widget.appState.currentRoleLabel,
          profileRole: '',
          contactNumber: '',
          profileCompleted: false,
          isCurrentUser: true,
          sourceLabel: sourceLabel,
          canEditRole: false,
          isUpdating: false,
          onEditRole: null,
        ),
      ],
    );
  }

  Widget _buildEmptyMembersCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'No membership records were found for this lab yet.',
        style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabId = widget.appState.selectedLabId.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab Members', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: selectedLabId.isEmpty
              ? _buildHeaderCard(
                  'Select or create a lab first to view members.',
                )
              : widget.appState.isDemoLabSelected ||
                    widget.appState.isLocalFallbackLabSelected
              ? _buildLocalMemberCard(sourceLabel: 'Local')
              : FutureBuilder<_LabMembersData>(
                  future: _membersFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final members = snapshot.data?.members ?? [];

                    if (members.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: _refreshMembers,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            _buildHeaderCard(
                              'Roles are shown from the current lab membership records.',
                            ),
                            const SizedBox(height: 12),
                            _buildEmptyMembersCard(),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _refreshMembers,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: members.length + 1,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildHeaderCard(
                              widget.appState.isPiAdmin
                                  ? 'View member profiles and safely manage roles.'
                                  : 'You can view members. Only PI/Admin can edit roles.',
                            );
                          }

                          final member = members[index - 1];
                          final membership = member.membership;
                          final profile = member.profile;
                          final isCurrentUser =
                              membership.userId.trim() ==
                              widget.appState.authenticatedUserId;

                          return _MemberTile(
                            name: _memberName(member),
                            email: _memberEmail(member),
                            roleLabel: widget.appState.roleLabelFor(
                              membership.role.trim(),
                            ),
                            profileRole: profile?.joinAs.trim() ?? '',
                            contactNumber: profile?.contactNumber.trim() ?? '',
                            profileCompleted:
                                profile?.profileCompleted == true ||
                                profile?.isComplete == true,
                            isCurrentUser: isCurrentUser,
                            sourceLabel: 'Member',
                            canEditRole: widget.appState.isPiAdmin,
                            isUpdating:
                                _updatingMemberUserId ==
                                membership.userId.trim(),
                            onEditRole: widget.appState.isPiAdmin
                                ? () => _showRoleEditor(member)
                                : null,
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _LabMembersData {
  final List<_LabMemberDetails> members;

  const _LabMembersData({required this.members});
}

class _LabMemberDetails {
  final LabMembershipModel membership;
  final UserProfile? profile;

  const _LabMemberDetails({required this.membership, required this.profile});
}

class _MemberTile extends StatelessWidget {
  final String name;
  final String email;
  final String roleLabel;
  final String profileRole;
  final String contactNumber;
  final bool profileCompleted;
  final bool isCurrentUser;
  final String sourceLabel;
  final bool canEditRole;
  final bool isUpdating;
  final VoidCallback? onEditRole;

  const _MemberTile({
    required this.name,
    required this.email,
    required this.roleLabel,
    required this.profileRole,
    required this.contactNumber,
    required this.profileCompleted,
    required this.isCurrentUser,
    required this.sourceLabel,
    required this.canEditRole,
    required this.isUpdating,
    required this.onEditRole,
  });

  Widget _buildDetail(String label, String value) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white60, fontSize: 12.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _buildDetail('Email', email),
                _buildDetail('Profile role', profileRole),
                _buildDetail('Contact', contactNumber),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MemberBadge(label: roleLabel),
                    _MemberBadge(label: sourceLabel),
                    _MemberBadge(
                      label: profileCompleted
                          ? 'Profile Complete'
                          : 'Profile Incomplete',
                      accentColor: profileCompleted
                          ? const Color(0xFF14B8A6)
                          : Colors.white24,
                    ),
                    if (isCurrentUser)
                      const _MemberBadge(
                        label: 'You',
                        accentColor: Color(0xFF14B8A6),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (canEditRole) ...[
            const SizedBox(width: 10),
            IconButton(
              tooltip: 'Edit role',
              onPressed: isUpdating ? null : onEditRole,
              icon: isUpdating
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.manage_accounts_rounded),
              color: const Color(0xFF14B8A6),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemberBadge extends StatelessWidget {
  final String label;
  final Color accentColor;

  const _MemberBadge({required this.label, this.accentColor = Colors.white24});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
