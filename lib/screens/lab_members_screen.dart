import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/lab_membership_model.dart';
import '../models/user_profile.dart';
import '../services/lab_membership_service.dart';
import '../services/user_profile_service.dart';
import '../theme/labmate_theme.dart';

class LabMembersScreen extends StatefulWidget {
  final AppState appState;

  const LabMembersScreen({super.key, required this.appState});

  @override
  State<LabMembersScreen> createState() => _LabMembersScreenState();
}

class _LabMembersScreenState extends State<LabMembersScreen> {
  static const Map<String, String> _editableRoles = {
    'pi': 'PI',
    'admin': 'Admin',
    'member': 'Member',
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
    if (!widget.appState.isPiOrAdmin || _updatingMemberUserId.isNotEmpty) {
      return;
    }

    final membership = member.membership;
    final memberUserId = membership.userId.trim();
    final labId = membership.labId.trim();
    final currentRole = _accessRoleName(membership);
    final currentUserId = widget.appState.authenticatedUserId;
    final isCurrentUser = memberUserId == currentUserId;
    final messenger = ScaffoldMessenger.of(context);

    var selectedRole = _editableRoles.containsKey(currentRole)
        ? currentRole
        : LabAccessRole.member.name;

    final newRole = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final palette = context.labmate;
            final colorScheme = context.colorScheme;
            return AlertDialog(
              backgroundColor: palette.panel,
              title: Text(
                'Edit Lab Access',
                style: TextStyle(color: colorScheme.onSurface),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    dropdownColor: palette.panel,
                    decoration: InputDecoration(
                      labelText: 'Lab Access',
                      labelStyle: TextStyle(
                        color: palette.mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      filled: true,
                      fillColor: palette.panelAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: colorScheme.onSurface),
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
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: palette.mutedText),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, selectedRole),
                  child: Text(
                    'Save',
                    style: TextStyle(color: colorScheme.primary),
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

    final transferringPi = newRole == LabAccessRole.pi.name;
    final demotingCurrentPi =
        currentRole == LabAccessRole.pi.name &&
        newRole != LabAccessRole.pi.name;

    if (transferringPi && !widget.appState.isPi) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Only the current PI can transfer PI ownership.'),
        ),
      );
      return;
    }

    if (demotingCurrentPi) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Transfer PI ownership to another member before changing the current PI role.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _updatingMemberUserId = memberUserId;
    });

    try {
      await _labMembershipService.updateMembershipRole(
        userId: memberUserId,
        labId: labId,
        role: newRole,
        currentUserId: currentUserId,
      );

      if (isCurrentUser || transferringPi) {
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

  String _accessRoleName(LabMembershipModel membership) {
    final isMembershipPi =
        membership.userId.trim() == widget.appState.selectedLabPiUid.trim();
    return LabMembershipService.normalizeAccessRole(
      membership.role,
      isPi: isMembershipPi,
    );
  }

  String _accessRoleLabel(LabMembershipModel membership) {
    return widget.appState.roleLabelFor(
      membership.role.trim(),
      isPi: membership.userId.trim() == widget.appState.selectedLabPiUid.trim(),
    );
  }

  bool _canCurrentUserClaimPi(List<_LabMemberDetails> members) {
    if (!widget.appState.selectedLabNeedsPrincipalInvestigatorAssignment) {
      return false;
    }

    final currentUserId = widget.appState.authenticatedUserId.trim();
    if (currentUserId.isEmpty) {
      return false;
    }

    return members.any((member) {
      final membership = member.membership;
      final profileRole = member.profile?.joinAs.trim().toLowerCase() ?? '';
      return membership.userId.trim() == currentUserId &&
          LabMembershipService.isLegacyPiAdminRole(membership.role) &&
          profileRole == 'pi';
    });
  }

  Future<void> _confirmCurrentUserAsPi() async {
    if (_updatingMemberUserId.isNotEmpty) {
      return;
    }

    final labId = widget.appState.selectedLabId.trim();
    final currentUserId = widget.appState.authenticatedUserId.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (labId.isEmpty || currentUserId.isEmpty) {
      return;
    }

    setState(() {
      _updatingMemberUserId = currentUserId;
    });

    try {
      await _labMembershipService.claimPrincipalInvestigatorFromLegacyProfile(
        labId: labId,
        currentUserId: currentUserId,
      );
      await widget.appState.refreshSelectedLabRole();
      await _refreshMembers();

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Principal Investigator assigned.')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not assign PI: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingMemberUserId = '';
        });
      }
    }
  }

  Widget _buildPiAssignmentCard() {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final isUpdating =
        _updatingMemberUserId == widget.appState.authenticatedUserId.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Principal Investigator assignment needed',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This legacy lab has no PI owner field yet. Because your Profile Role is PI and your legacy access record marks you as a lab administrator, you can confirm yourself as the lab PI.',
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: isUpdating ? null : _confirmCurrentUserAsPi,
              icon: isUpdating
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user_outlined, size: 18),
              label: Text(isUpdating ? 'Assigning...' : 'Confirm me as PI'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(String helperText) {
    final selectedLabName = widget.appState.selectedLabName.trim();
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Lab',
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            selectedLabName.isEmpty ? 'No lab selected' : selectedLabName,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            helperText,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 13.2,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalMemberCard() {
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
          designation: '',
          researchArea: '',
          contactNumber: '',
          profileCompleted: false,
          isCurrentUser: true,
          canEditRole: false,
          isUpdating: false,
          onEditRole: null,
        ),
      ],
    );
  }

  Widget _buildEmptyMembersCard() {
    final palette = context.labmate;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        'No membership records were found for this lab yet.',
        style: TextStyle(
          color: palette.mutedText,
          fontSize: 13.2,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabId = widget.appState.selectedLabId.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Lab Members')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: selectedLabId.isEmpty
              ? _buildHeaderCard(
                  'Select or create a lab first to view members.',
                )
              : widget.appState.isDemoLabSelected ||
                    widget.appState.isLocalFallbackLabSelected
              ? _buildLocalMemberCard()
              : FutureBuilder<_LabMembersData>(
                  future: _membersFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final members = snapshot.data?.members ?? [];
                    final canCurrentUserClaimPi = _canCurrentUserClaimPi(
                      members,
                    );

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
                            return Column(
                              children: [
                                _buildHeaderCard(
                                  widget.appState.isPiOrAdmin
                                      ? 'View member profiles and safely manage roles.'
                                      : 'You can view members. Only PI or Admin can edit access roles.',
                                ),
                                if (canCurrentUserClaimPi) ...[
                                  const SizedBox(height: 12),
                                  _buildPiAssignmentCard(),
                                ],
                              ],
                            );
                          }

                          final member = members[index - 1];
                          final membership = member.membership;
                          final profile = member.profile;
                          final showEmail =
                              profile?.showEmailToLabMembers ?? true;
                          final showMobile =
                              profile?.showMobileToLabMembers ?? false;
                          final isCurrentUser =
                              membership.userId.trim() ==
                              widget.appState.authenticatedUserId;

                          return _MemberTile(
                            name: _memberName(member),
                            email: showEmail ? _memberEmail(member) : 'Hidden',
                            roleLabel: _accessRoleLabel(membership),
                            profileRole: profile?.joinAs.trim() ?? '',
                            designation: profile?.designation?.trim() ?? '',
                            researchArea: profile?.researchArea?.trim() ?? '',
                            contactNumber: showMobile
                                ? profile?.contactNumber.trim() ?? ''
                                : 'Hidden',
                            profileCompleted:
                                profile?.profileCompleted == true ||
                                profile?.isComplete == true,
                            isCurrentUser: isCurrentUser,
                            canEditRole: widget.appState.isPiOrAdmin,
                            isUpdating:
                                _updatingMemberUserId ==
                                membership.userId.trim(),
                            onEditRole: widget.appState.isPiOrAdmin
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
  final String designation;
  final String researchArea;
  final String contactNumber;
  final bool profileCompleted;
  final bool isCurrentUser;
  final bool canEditRole;
  final bool isUpdating;
  final VoidCallback? onEditRole;

  const _MemberTile({
    required this.name,
    required this.email,
    required this.roleLabel,
    required this.profileRole,
    required this.designation,
    required this.researchArea,
    required this.contactNumber,
    required this.profileCompleted,
    required this.isCurrentUser,
    required this.canEditRole,
    required this.isUpdating,
    required this.onEditRole,
  });

  Widget _buildDetail(BuildContext context, String label, String value) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final palette = context.labmate;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: palette.mutedText,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.35,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: palette.panelAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.person_rounded, color: colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _buildDetail(context, 'Email', email),
                _buildDetail(
                  context,
                  'Profile Role',
                  profileRole.trim().isEmpty ? 'Not set' : profileRole,
                ),
                _buildDetail(context, 'Lab Access', roleLabel),
                _buildDetail(context, 'Designation', designation),
                _buildDetail(context, 'Research area', researchArea),
                _buildDetail(context, 'Contact', contactNumber),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MemberBadge(
                      label: profileCompleted
                          ? 'Profile Complete'
                          : 'Profile Incomplete',
                      accentColor: profileCompleted
                          ? colorScheme.primary
                          : null,
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
  final Color? accentColor;

  const _MemberBadge({required this.label, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final color = accentColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color ?? palette.panelAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color ?? palette.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == null ? palette.mutedText : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
