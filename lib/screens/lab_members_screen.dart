import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/lab_join_request_model.dart';
import '../models/lab_membership_model.dart';
import '../models/user_profile.dart';
import '../services/lab_membership_service.dart';
import '../services/person_display_resolver.dart';
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
  static const List<String> _monthLabels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final LabMembershipService _labMembershipService = LabMembershipService();
  final UserProfileService _userProfileService = UserProfileService();

  late Future<_LabMembersData> _membersFuture;
  String _updatingMemberUserId = '';
  String _reviewingRequestId = '';

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
        includeExpired: widget.appState.isPi,
      );
      final pendingRequests = widget.appState.isPi
          ? await _labMembershipService.getPendingJoinRequestsForLab(
              labId: labId,
            )
          : <LabJoinRequestModel>[];
      final currentUserId = widget.appState.authenticatedUserId.trim();
      final profileUserIds = widget.appState.isPi
          ? memberships.map((membership) => membership.userId)
          : memberships
                .where(
                  (membership) => membership.userId.trim() == currentUserId,
                )
                .map((membership) => membership.userId);
      var profiles = <String, UserProfile>{};
      try {
        profiles = await _userProfileService.getUserProfilesByIds(
          profileUserIds,
        );
      } catch (_) {
        profiles = <String, UserProfile>{};
      }

      return _LabMembersData(
        pendingRequests: pendingRequests,
        members: memberships.map((membership) {
          final userId = membership.userId.trim();
          return _LabMemberDetails(
            membership: membership,
            profile: profiles[userId],
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
    final isCurrentUser =
        member.membership.userId.trim() == widget.appState.authenticatedUserId;

    return PersonDisplayResolver.resolvePersonDisplayName(
      profile: isCurrentUser ? widget.appState.profile : member.profile,
      membership: member.membership,
      firebaseDisplayName: isCurrentUser
          ? widget.appState.authenticatedUserName
          : null,
      email: member.membership.userEmail,
      uid: member.membership.userId,
      fallbackLabel: 'Member',
    );
  }

  String _memberEmail(_LabMemberDetails member) {
    final userEmail = member.membership.userEmail.trim();
    if (userEmail.isNotEmpty) {
      return userEmail;
    }

    return member.membership.userId.trim();
  }

  String _profileFullName(_LabMemberDetails member) {
    final profile = member.profile;
    final parts = [profile?.prefix.trim() ?? '', profile?.name.trim() ?? '']
        .where((part) {
          return part.isNotEmpty && part.toLowerCase() != 'your name';
        })
        .toList();

    if (parts.isNotEmpty) {
      return parts.join(' ');
    }

    return _memberName(member);
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = _monthLabels[value.month - 1];
    return '$day $month ${value.year}';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Unknown date';
    }

    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${_formatDate(value)} $hour:$minute';
  }

  String _membershipTenureLabel(LabMembershipModel membership) {
    final startAt = membership.membershipStartAt;
    final endAt = membership.membershipEndAt;
    if (startAt == null && endAt == null) {
      return '';
    }

    final startLabel = startAt == null ? 'Start not set' : _formatDate(startAt);
    final endLabel = endAt == null ? 'End not set' : _formatDate(endAt);
    return '$startLabel -> $endLabel';
  }

  String _membershipStatusLabel(LabMembershipModel membership) {
    final status = membership.effectiveStatus.trim();
    if (status.isEmpty) {
      return 'Active';
    }

    return status[0].toUpperCase() + status.substring(1);
  }

  Widget _buildProfileDetailLine(
    BuildContext context,
    String label,
    String value,
  ) {
    final cleanValue = value.trim();
    if (cleanValue.isEmpty) {
      return const SizedBox.shrink();
    }

    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            cleanValue,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 13.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _basicProfileDetails(
    BuildContext context,
    _LabMemberDetails member,
  ) {
    final profile = member.profile;
    final membership = member.membership;
    final isCurrentUser =
        membership.userId.trim() == widget.appState.authenticatedUserId.trim();
    final showEmail = isCurrentUser || profile?.showEmailToLabMembers == true;
    final showMobile = isCurrentUser || profile?.showMobileToLabMembers == true;
    final profileComplete = profile == null
        ? ''
        : (profile.profileCompleted || profile.isComplete)
        ? 'Complete'
        : 'Incomplete';

    return [
      _buildProfileDetailLine(context, 'Display name', _memberName(member)),
      _buildProfileDetailLine(
        context,
        'Lab Access',
        _accessRoleLabel(membership),
      ),
      _buildProfileDetailLine(
        context,
        'Profile Role',
        profile?.joinAs.trim() ?? '',
      ),
      _buildProfileDetailLine(
        context,
        'Designation',
        profile?.designation?.trim() ?? '',
      ),
      _buildProfileDetailLine(
        context,
        'Research area',
        profile?.researchArea?.trim() ?? '',
      ),
      _buildProfileDetailLine(
        context,
        'Email',
        showEmail ? _memberEmail(member) : 'Hidden',
      ),
      _buildProfileDetailLine(
        context,
        'Contact',
        showMobile ? profile?.contactNumber.trim() ?? '' : 'Hidden',
      ),
      _buildProfileDetailLine(context, 'Profile status', profileComplete),
    ];
  }

  List<Widget> _piDetailedProfileDetails(
    BuildContext context,
    _LabMemberDetails member,
  ) {
    final profile = member.profile;
    final membership = member.membership;
    final dob = profile?.dob.trim() ?? '';

    return [
      _buildProfileDetailLine(context, 'Full name', _profileFullName(member)),
      _buildProfileDetailLine(
        context,
        'Lab Access',
        _accessRoleLabel(membership),
      ),
      _buildProfileDetailLine(
        context,
        'Membership status',
        _membershipStatusLabel(membership),
      ),
      _buildProfileDetailLine(
        context,
        'Membership start',
        membership.membershipStartAt == null
            ? ''
            : _formatDate(membership.membershipStartAt!),
      ),
      _buildProfileDetailLine(
        context,
        'Membership end',
        membership.membershipEndAt == null
            ? ''
            : _formatDate(membership.membershipEndAt!),
      ),
      _buildProfileDetailLine(context, 'Email', _memberEmail(member)),
      _buildProfileDetailLine(
        context,
        'Contact number',
        profile?.contactNumber.trim() ?? '',
      ),
      _buildProfileDetailLine(
        context,
        'Date of birth',
        dob.isEmpty ? '' : UserProfile.formatDateOfBirthForDisplay(dob),
      ),
      _buildProfileDetailLine(
        context,
        'Profile Role',
        profile?.joinAs.trim() ?? '',
      ),
      _buildProfileDetailLine(
        context,
        'Designation',
        profile?.designation?.trim() ?? '',
      ),
      _buildProfileDetailLine(
        context,
        'Research area',
        profile?.researchArea?.trim() ?? '',
      ),
      _buildProfileDetailLine(context, 'Roll number', profile?.rollNo ?? ''),
      _buildProfileDetailLine(context, 'Batch', profile?.batch ?? ''),
      _buildProfileDetailLine(
        context,
        'Present address',
        profile?.presentAddress.trim() ?? '',
      ),
      _buildProfileDetailLine(
        context,
        'Permanent address',
        profile?.permanentAddress.trim() ?? '',
      ),
      _buildProfileDetailLine(
        context,
        'Emergency contact',
        profile?.emergencyContactPerson.trim() ?? '',
      ),
      _buildProfileDetailLine(
        context,
        'Emergency relationship',
        profile?.emergencyRelationship.trim() ?? '',
      ),
      _buildProfileDetailLine(
        context,
        'Emergency phone',
        profile?.emergencyContactNumber.trim() ?? '',
      ),
      _buildProfileDetailLine(
        context,
        'Blood group',
        profile?.bloodGroup.trim() ?? '',
      ),
      _buildProfileDetailLine(
        context,
        'Hobbies',
        profile?.hobbies.trim() ?? '',
      ),
      _buildProfileDetailLine(context, 'About', profile?.about.trim() ?? ''),
      _buildProfileDetailLine(
        context,
        'Profile status',
        profile == null
            ? 'Not available'
            : (profile.profileCompleted || profile.isComplete)
            ? 'Complete'
            : 'Incomplete',
      ),
    ];
  }

  Future<void> _showMemberProfile(_LabMemberDetails member) async {
    final isPi = widget.appState.isPi;

    await showDialog<void>(
      context: context,
      builder: (context) {
        final palette = context.labmate;
        final colorScheme = context.colorScheme;
        final details = isPi
            ? _piDetailedProfileDetails(context, member)
            : _basicProfileDetails(context, member);

        return AlertDialog(
          backgroundColor: palette.panel,
          title: Text(
            isPi ? 'Member Profile' : 'Basic Profile',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: details,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<_TenureSelection?> _showApprovalDialog(
    LabJoinRequestModel request,
  ) async {
    var startDate = LabMembershipService.dateOnly(DateTime.now());
    DateTime? endDate;
    String errorText = '';

    return showDialog<_TenureSelection>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final palette = context.labmate;
            final colorScheme = context.colorScheme;

            Future<void> pickStartDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: startDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(DateTime.now().year + 15),
              );
              if (picked == null) {
                return;
              }
              setDialogState(() {
                startDate = LabMembershipService.dateOnly(picked);
                if (endDate != null && endDate!.isBefore(startDate)) {
                  endDate = null;
                }
                errorText = '';
              });
            }

            Future<void> pickEndDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: endDate ?? startDate,
                firstDate: startDate,
                lastDate: DateTime(DateTime.now().year + 15),
              );
              if (picked == null) {
                return;
              }
              setDialogState(() {
                endDate = LabMembershipService.dateOnly(picked);
                errorText = '';
              });
            }

            return AlertDialog(
              backgroundColor: palette.panel,
              title: Text(
                'Approve Join Request',
                style: TextStyle(color: colorScheme.onSurface),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.userName.trim().isEmpty
                        ? request.userEmail
                        : request.userName,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.userEmail.trim().isEmpty
                        ? request.userId
                        : request.userEmail,
                    style: TextStyle(color: palette.mutedText, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  _TenureDateButton(
                    label: 'Start date',
                    value: _formatDate(startDate),
                    onPressed: pickStartDate,
                  ),
                  const SizedBox(height: 10),
                  _TenureDateButton(
                    label: 'End date',
                    value: endDate == null
                        ? 'Select end date'
                        : _formatDate(endDate!),
                    onPressed: pickEndDate,
                  ),
                  if (errorText.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText,
                      style: TextStyle(
                        color: colorScheme.error,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
                FilledButton(
                  onPressed: () {
                    if (endDate == null) {
                      setDialogState(() {
                        errorText = 'Select a membership end date.';
                      });
                      return;
                    }

                    Navigator.pop(
                      context,
                      _TenureSelection(startAt: startDate, endAt: endDate!),
                    );
                  },
                  child: const Text('Approve'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _approveJoinRequest(LabJoinRequestModel request) async {
    if (!widget.appState.isPi || _reviewingRequestId.isNotEmpty) {
      return;
    }

    final selection = await _showApprovalDialog(request);
    if (selection == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _reviewingRequestId = request.id;
    });

    try {
      await _labMembershipService.approveJoinRequest(
        requestId: request.id,
        labId: widget.appState.selectedLabId,
        reviewerUid: widget.appState.authenticatedUserId,
        reviewerName: widget.appState.authenticatedUserName,
        membershipStartAt: selection.startAt,
        membershipEndAt: selection.endAt,
      );
      await _refreshMembers();

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Join request approved.')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not approve request: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _reviewingRequestId = '';
        });
      }
    }
  }

  Future<void> _rejectJoinRequest(LabJoinRequestModel request) async {
    if (!widget.appState.isPi || _reviewingRequestId.isNotEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final palette = context.labmate;
        final colorScheme = context.colorScheme;
        return AlertDialog(
          backgroundColor: palette.panel,
          title: Text(
            'Reject Join Request?',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          content: Text(
            'This will reject the request without creating a membership.',
            style: TextStyle(color: palette.mutedText, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: palette.mutedText)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Reject', style: TextStyle(color: colorScheme.error)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }
    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _reviewingRequestId = request.id;
    });

    try {
      await _labMembershipService.rejectJoinRequest(
        requestId: request.id,
        labId: widget.appState.selectedLabId,
        reviewerUid: widget.appState.authenticatedUserId,
        reviewerName: widget.appState.authenticatedUserName,
      );
      await _refreshMembers();

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Join request rejected.')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not reject request: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _reviewingRequestId = '';
        });
      }
    }
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

  Widget _buildPendingJoinRequestsCard(
    List<LabJoinRequestModel> pendingRequests,
  ) {
    if (pendingRequests.isEmpty) {
      return const SizedBox.shrink();
    }

    final palette = context.labmate;
    final colorScheme = context.colorScheme;

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
          Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pending Join Requests',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _MemberBadge(
                label: pendingRequests.length.toString(),
                accentColor: colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Only the Principal Investigator can approve or reject lab access requests.',
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < pendingRequests.length; index++) ...[
            _JoinRequestTile(
              request: pendingRequests[index],
              requestedAtLabel: _formatDateTime(
                pendingRequests[index].requestedAt,
              ),
              isBusy: _reviewingRequestId == pendingRequests[index].id,
              onApprove: () => _approveJoinRequest(pendingRequests[index]),
              onReject: () => _rejectJoinRequest(pendingRequests[index]),
            ),
            if (index != pendingRequests.length - 1)
              Divider(height: 18, color: palette.border),
          ],
        ],
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

                    final data =
                        snapshot.data ?? const _LabMembersData(members: []);
                    final members = data.members;
                    final pendingRequests = data.pendingRequests;
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
                            if (pendingRequests.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _buildPendingJoinRequestsCard(pendingRequests),
                            ],
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
                                if (pendingRequests.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _buildPendingJoinRequestsCard(
                                    pendingRequests,
                                  ),
                                ],
                              ],
                            );
                          }

                          final member = members[index - 1];
                          final membership = member.membership;
                          final profile = member.profile;
                          final isCurrentUser =
                              membership.userId.trim() ==
                              widget.appState.authenticatedUserId.trim();
                          final showEmail =
                              widget.appState.isPi ||
                              isCurrentUser ||
                              profile?.showEmailToLabMembers == true;
                          final showMobile =
                              widget.appState.isPi ||
                              isCurrentUser ||
                              profile?.showMobileToLabMembers == true;

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
                            tenureLabel: _membershipTenureLabel(membership),
                            isExpired: membership.effectiveStatus == 'expired',
                            profileCompleted:
                                profile?.profileCompleted == true ||
                                profile?.isComplete == true,
                            isCurrentUser: isCurrentUser,
                            canEditRole:
                                widget.appState.isPiOrAdmin &&
                                membership.effectiveStatus != 'expired',
                            isUpdating:
                                _updatingMemberUserId ==
                                membership.userId.trim(),
                            onTap: () => _showMemberProfile(member),
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
  final List<LabJoinRequestModel> pendingRequests;

  const _LabMembersData({
    required this.members,
    this.pendingRequests = const [],
  });
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
  final String tenureLabel;
  final bool isExpired;
  final bool profileCompleted;
  final bool isCurrentUser;
  final bool canEditRole;
  final bool isUpdating;
  final VoidCallback? onTap;
  final VoidCallback? onEditRole;

  const _MemberTile({
    required this.name,
    required this.email,
    required this.roleLabel,
    required this.profileRole,
    required this.designation,
    required this.researchArea,
    required this.contactNumber,
    this.tenureLabel = '',
    this.isExpired = false,
    required this.profileCompleted,
    required this.isCurrentUser,
    required this.canEditRole,
    required this.isUpdating,
    this.onTap,
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
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
                    _buildDetail(context, 'Tenure', tenureLabel),
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
                        if (isExpired)
                          _MemberBadge(
                            label: 'Expired',
                            accentColor: colorScheme.error,
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
        ),
      ),
    );
  }
}

class _JoinRequestTile extends StatelessWidget {
  final LabJoinRequestModel request;
  final String requestedAtLabel;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _JoinRequestTile({
    required this.request,
    required this.requestedAtLabel,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final displayName = request.userName.trim().isEmpty
        ? request.userEmail.trim()
        : request.userName.trim();
    final displayEmail = request.userEmail.trim().isEmpty
        ? request.userId.trim()
        : request.userEmail.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: palette.panelAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.person_outline_rounded,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName.isEmpty ? 'Member request' : displayName,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayEmail,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 12.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Requested: $requestedAtLabel',
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 12.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton(
                onPressed: isBusy ? null : onReject,
                child: const Text('Reject'),
              ),
              FilledButton(
                onPressed: isBusy ? null : onApprove,
                child: isBusy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Approve'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TenureDateButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onPressed;

  const _TenureDateButton({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TenureSelection {
  final DateTime startAt;
  final DateTime endAt;

  const _TenureSelection({required this.startAt, required this.endAt});
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
