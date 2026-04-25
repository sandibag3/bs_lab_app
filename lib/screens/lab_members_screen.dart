import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/lab_membership_model.dart';
import '../services/lab_membership_service.dart';

class LabMembersScreen extends StatefulWidget {
  final AppState appState;

  const LabMembersScreen({
    super.key,
    required this.appState,
  });

  @override
  State<LabMembersScreen> createState() => _LabMembersScreenState();
}

class _LabMembersScreenState extends State<LabMembersScreen> {
  final LabMembershipService _labMembershipService = LabMembershipService();

  late Future<List<LabMembershipModel>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _membersFuture = _loadMembers();
  }

  Future<List<LabMembershipModel>> _loadMembers() async {
    final labId = widget.appState.selectedLabId.trim();
    if (labId.isEmpty ||
        widget.appState.isDemoLabSelected ||
        widget.appState.isLocalFallbackLabSelected) {
      return [];
    }

    try {
      return await _labMembershipService.getMembershipsForLab(labId: labId);
    } catch (_) {
      return [];
    }
  }

  Future<void> _refreshMembers() async {
    setState(() {
      _membersFuture = _loadMembers();
    });
    await _membersFuture;
  }

  String _memberName(LabMembershipModel membership) {
    final userName = membership.userName.trim();
    if (userName.isNotEmpty) {
      return userName;
    }

    final userEmail = membership.userEmail.trim();
    if (userEmail.isNotEmpty) {
      return userEmail;
    }

    if (membership.userId.trim() == widget.appState.authenticatedUserId) {
      return widget.appState.authenticatedUserName;
    }

    return membership.userId.trim().isEmpty ? 'Member' : membership.userId.trim();
  }

  String _memberSubtitle(LabMembershipModel membership) {
    final userEmail = membership.userEmail.trim();
    if (userEmail.isNotEmpty && userEmail != _memberName(membership)) {
      return userEmail;
    }

    final userId = membership.userId.trim();
    if (userId.isNotEmpty && userId != _memberName(membership)) {
      return userId;
    }

    return 'Lab member';
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
              color: Colors.white.withOpacity(0.72),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalMemberCard({
    required String sourceLabel,
  }) {
    return Column(
      children: [
        _buildHeaderCard(
          'This lab context is using the local role flow, so only the current user is shown here for now.',
        ),
        const SizedBox(height: 12),
        _MemberTile(
          name: widget.appState.authenticatedUserName,
          subtitle: widget.appState.authenticatedUserEmail.isEmpty
              ? 'Current user'
              : widget.appState.authenticatedUserEmail,
          roleLabel: widget.appState.currentRoleLabel,
          isCurrentUser: true,
          sourceLabel: sourceLabel,
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
        style: TextStyle(
          color: Colors.white70,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabId = widget.appState.selectedLabId.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lab Members',
          style: TextStyle(color: Colors.white),
        ),
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
                  : FutureBuilder<List<LabMembershipModel>>(
                          future: _membersFuture,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final members = snapshot.data ?? [];

                            if (members.isEmpty) {
                              return RefreshIndicator(
                                onRefresh: _refreshMembers,
                                child: ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
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
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                itemCount: members.length + 1,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return _buildHeaderCard(
                                      'Roles are shown from the current lab membership records.',
                                    );
                                  }

                                  final member = members[index - 1];
                                  final isCurrentUser = member.userId.trim() ==
                                      widget.appState.authenticatedUserId;

                                  return _MemberTile(
                                    name: _memberName(member),
                                    subtitle: _memberSubtitle(member),
                                    roleLabel: widget.appState.roleLabelFor(
                                      member.role.trim(),
                                    ),
                                    isCurrentUser: isCurrentUser,
                                    sourceLabel: 'Member',
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

class _MemberTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final String roleLabel;
  final bool isCurrentUser;
  final String sourceLabel;

  const _MemberTile({
    required this.name,
    required this.subtitle,
    required this.roleLabel,
    required this.isCurrentUser,
    required this.sourceLabel,
  });

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
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
            ),
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
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MemberBadge(label: roleLabel),
                    _MemberBadge(label: sourceLabel),
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
        ],
      ),
    );
  }
}

class _MemberBadge extends StatelessWidget {
  final String label;
  final Color accentColor;

  const _MemberBadge({
    required this.label,
    this.accentColor = Colors.white24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
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
