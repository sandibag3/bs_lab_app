import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/lab_membership_model.dart';
import '../models/notebook_project_model.dart';
import '../services/firestore_access_guard.dart';
import '../services/lab_membership_service.dart';
import '../services/lab_notebook_service.dart';
import '../theme/labmate_theme.dart';
import '../widgets/responsive_page_container.dart';
import 'add_notebook_project_screen.dart';
import 'notebook_project_detail_screen.dart';

class LabNotebookScreen extends StatelessWidget {
  final AppState appState;
  final String? notebookOwnerUid;
  final String? notebookOwnerEmail;
  final String? notebookOwnerLabel;
  final bool showMemberNotebookBrowser;
  final LabNotebookService _labNotebookService = LabNotebookService();
  final LabMembershipService _labMembershipService = LabMembershipService();

  LabNotebookScreen({
    super.key,
    required this.appState,
    this.notebookOwnerUid,
    this.notebookOwnerEmail,
    this.notebookOwnerLabel,
    this.showMemberNotebookBrowser = false,
  });

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _resolveNotebookOwnerUid() {
    return _labNotebookService.resolveNotebookOwnerUid(notebookOwnerUid);
  }

  String _resolveNotebookOwnerLabel() {
    final explicitLabel = (notebookOwnerLabel ?? '').trim();
    if (explicitLabel.isNotEmpty) {
      return explicitLabel;
    }

    final explicitEmail = (notebookOwnerEmail ?? '').trim();
    if (explicitEmail.isNotEmpty) {
      return explicitEmail;
    }

    final ownerUid = _resolveNotebookOwnerUid();
    if (ownerUid == appState.authenticatedUserId.trim()) {
      final ownEmail = appState.authenticatedUserEmail.trim();
      return ownEmail.isEmpty ? 'My Notebook' : ownEmail;
    }

    return ownerUid;
  }

  bool _isReadOnlyView() {
    final currentUserId = appState.authenticatedUserId.trim();
    final ownerUid = _resolveNotebookOwnerUid();
    if (currentUserId.isEmpty || ownerUid.isEmpty) {
      return false;
    }

    return currentUserId != ownerUid;
  }

  bool _isPiAdminNotebookHome() {
    return appState.isPiAdmin &&
        !_isReadOnlyView() &&
        !showMemberNotebookBrowser;
  }

  Future<void> _openAddProject(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddNotebookProjectScreen(appState: appState),
      ),
    );
  }

  Future<void> _openMemberNotebookBrowser(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LabNotebookScreen(
          appState: appState,
          showMemberNotebookBrowser: true,
        ),
      ),
    );
  }

  Future<void> _openMemberNotebook(
    BuildContext context,
    LabMembershipModel membership,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LabNotebookScreen(
          appState: appState,
          notebookOwnerUid: membership.userId.trim(),
          notebookOwnerEmail: membership.userEmail.trim(),
          notebookOwnerLabel: _memberDisplayName(membership),
        ),
      ),
    );
  }

  String _memberDisplayName(LabMembershipModel membership) {
    final userName = membership.userName.trim();
    if (userName.isNotEmpty) {
      return membership.userEmail.trim().isEmpty
          ? userName
          : '$userName (${membership.userEmail.trim()})';
    }

    final userEmail = membership.userEmail.trim();
    if (userEmail.isNotEmpty) {
      return userEmail;
    }

    return membership.userId.trim();
  }

  Widget _buildBlockedState() {
    return const _NotebookNotice(
      icon: Icons.apartment_rounded,
      title: 'Lab Notebook needs an active lab',
      message:
          'Select, create, or join a lab to start tracking notebook projects and experiments.',
      accent: Color(0xFF38BDF8),
    );
  }

  Widget _buildAuthRequiredState() {
    return const _NotebookNotice(
      icon: Icons.lock_outline_rounded,
      title: 'Sign in to access private notebooks',
      message:
          'Lab Notebook is now private per member. Sign in with your lab account to open your notebook or browse member notebooks as PI/Admin.',
      accent: Color(0xFFFBBF24),
    );
  }

  Widget _buildReadOnlyBanner(BuildContext context) {
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
              'Read-only view: you are viewing another member\'s notebook.',
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

  Widget _buildNotebookRail({
    required BuildContext context,
    required bool canCreate,
    required bool isWide,
    required int projectCount,
    required String visibleOwnerLabel,
  }) {
    final selectedLabName = appState.selectedLabName.trim();
    final visibleLabName = selectedLabName.isEmpty
        ? 'No lab selected'
        : selectedLabName;
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final isReadOnly = _isReadOnlyView();
    final isMemberBrowser = showMemberNotebookBrowser;
    final isPiAdminHome = _isPiAdminNotebookHome();

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
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFF5EEAD4),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMemberBrowser ? 'Member Notebooks' : 'Lab Notebook',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 15.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isMemberBrowser
                          ? 'Browse private notebooks'
                          : 'Private notebook workspace',
                      style: TextStyle(
                        color: palette.subtleText,
                        fontSize: 11.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NotebookBadge(
            icon: Icons.apartment_rounded,
            label: visibleLabName,
            accent: const Color(0xFF5EEAD4),
          ),
          const SizedBox(height: 8),
          _NotebookBadge(
            icon: isMemberBrowser
                ? Icons.groups_rounded
                : isReadOnly
                ? Icons.visibility_outlined
                : Icons.lock_outline_rounded,
            label: isMemberBrowser
                ? 'PI/Admin viewer'
                : isReadOnly
                ? visibleOwnerLabel
                : 'My Notebook',
            accent: isReadOnly ? const Color(0xFFFBBF24) : null,
          ),
          const SizedBox(height: 10),
          Text(
            isMemberBrowser
                ? 'Open any lab member notebook in read-only mode. PI/Admin can inspect records but cannot edit another member\'s work.'
                : isReadOnly
                ? 'You can review this notebook, but editing actions stay locked because this notebook belongs to another lab member.'
                : 'Your notebook is private to you. PI/Admin can review it in read-only mode when needed.',
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 12.2,
              height: 1.38,
            ),
          ),
          const SizedBox(height: 12),
          if (isWide)
            Row(
              children: [
                Expanded(
                  child: _NotebookMetric(
                    label: isMemberBrowser ? 'Members' : 'Projects',
                    value: projectCount.toString(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NotebookMetric(
                    label: 'Mode',
                    value: isReadOnly
                        ? 'Read-only'
                        : isMemberBrowser
                        ? 'Viewer'
                        : 'Owner',
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _NotebookBadge(
                  icon: isMemberBrowser
                      ? Icons.groups_rounded
                      : Icons.folder_copy_rounded,
                  label:
                      '$projectCount ${isMemberBrowser ? 'members' : 'project${projectCount == 1 ? '' : 's'}'}',
                ),
                _NotebookBadge(
                  icon: isReadOnly
                      ? Icons.visibility_outlined
                      : Icons.edit_note_rounded,
                  label: isReadOnly ? 'Read-only' : 'Editable',
                ),
              ],
            ),
          if (canCreate) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openAddProject(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'New Project',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
          if (isPiAdminHome) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openMemberNotebookBrowser(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: BorderSide(color: palette.border),
                ),
                icon: const Icon(Icons.groups_rounded, size: 18),
                label: const Text(
                  'View Member Notebooks',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectCard(
    BuildContext context,
    NotebookProjectModel project, {
    bool compact = false,
    required String notebookOwnerUid,
    required String notebookOwnerLabel,
    required bool isReadOnly,
  }) {
    final description = project.description.trim();
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Material(
      color: palette.panel,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NotebookProjectDetailScreen(
                appState: appState,
                project: project,
                notebookOwnerUid: notebookOwnerUid,
                notebookOwnerLabel: notebookOwnerLabel,
                isReadOnly: isReadOnly,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.folder_open_rounded,
                      color: Color(0xFF5EEAD4),
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PROJECT',
                          style: TextStyle(
                            color: Color(0xFF5EEAD4),
                            fontSize: 10.6,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          project.title.trim().isEmpty
                              ? 'Untitled project'
                              : project.title.trim(),
                          maxLines: compact ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 14.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: palette.subtleText,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: palette.panelAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  description.isEmpty
                      ? 'No project description yet. Open the project to start building the experiment workspace.'
                      : description,
                  maxLines: compact ? 4 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: description.isEmpty
                        ? palette.subtleText
                        : palette.mutedText,
                    fontSize: 12.2,
                    height: 1.38,
                  ),
                ),
              ),
              const Spacer(),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _NotebookBadge(
                    icon: Icons.schedule_rounded,
                    label: _formatDate(project.createdAt),
                  ),
                  _NotebookBadge(
                    icon: Icons.person_outline_rounded,
                    label: project.ownerLabel,
                    accent: isReadOnly ? const Color(0xFFFBBF24) : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectsPanel(
    BuildContext context,
    List<NotebookProjectModel> projects, {
    required String notebookOwnerUid,
    required String notebookOwnerLabel,
    required bool isReadOnly,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1180
            ? 3
            : width >= 740
            ? 2
            : 1;

        Widget body;
        if (projects.isEmpty) {
          body = Center(
            child: _NotebookNotice(
              icon: Icons.folder_open_rounded,
              title: 'No notebook projects yet',
              message: isReadOnly
                  ? '$notebookOwnerLabel has not added any notebook projects yet.'
                  : 'Create your first project to start organizing experiments and reaction notes.',
              accent: const Color(0xFF14B8A6),
            ),
          );
        } else if (columns == 1) {
          body = ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: projects.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return SizedBox(
                height: 190,
                child: _buildProjectCard(
                  context,
                  projects[index],
                  notebookOwnerUid: notebookOwnerUid,
                  notebookOwnerLabel: notebookOwnerLabel,
                  isReadOnly: isReadOnly,
                ),
              );
            },
          );
        } else {
          body = GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: projects.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: columns == 3 ? 1.32 : 1.26,
            ),
            itemBuilder: (context, index) {
              return _buildProjectCard(
                context,
                projects[index],
                compact: true,
                notebookOwnerUid: notebookOwnerUid,
                notebookOwnerLabel: notebookOwnerLabel,
                isReadOnly: isReadOnly,
              );
            },
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: context.labmate.panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.labmate.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isReadOnly
                              ? '${notebookOwnerLabel.split(' ').first} Notebook'
                              : 'Projects',
                          style: TextStyle(
                            color: context.colorScheme.onSurface,
                            fontSize: 15.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isReadOnly
                              ? 'Read-only project list'
                              : 'Open a project to view its experiment workspace',
                          style: TextStyle(
                            color: context.labmate.subtleText,
                            fontSize: 11.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _NotebookBadge(
                    icon: Icons.folder_copy_rounded,
                    label: '${projects.length}',
                    accent: const Color(0xFF5EEAD4),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMemberNotebookBrowser(BuildContext context, String labId) {
    if (!appState.isPiAdmin) {
      return const _NotebookNotice(
        icon: Icons.lock_outline_rounded,
        title: 'Notebook viewer unavailable',
        message: 'Only PI/Admin can browse other member notebooks.',
        accent: Color(0xFFFB7185),
      );
    }

    return FutureBuilder<List<LabMembershipModel>>(
      future: _labMembershipService.getMembershipsForLab(labId: labId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                FirestoreAccessGuard.messageFor(snapshot.error),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.labmate.mutedText, height: 1.4),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final currentUserId = appState.authenticatedUserId.trim();
        final members = (snapshot.data ?? [])
            .where((member) => member.userId.trim().isNotEmpty)
            .where((member) => member.userId.trim() != currentUserId)
            .toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            final rail = _buildNotebookRail(
              context: context,
              canCreate: false,
              isWide: isWide,
              projectCount: members.length,
              visibleOwnerLabel: 'PI/Admin viewer',
            );
            final panel = _buildMemberListPanel(context, members);

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 280, child: rail),
                  const SizedBox(width: 10),
                  Expanded(child: panel),
                ],
              );
            }

            return Column(
              children: [
                rail,
                const SizedBox(height: 10),
                Expanded(child: panel),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMemberListPanel(
    BuildContext context,
    List<LabMembershipModel> members,
  ) {
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'View Member Notebooks',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 15.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Select a member to open their notebook in read-only mode',
                      style: TextStyle(
                        color: palette.subtleText,
                        fontSize: 11.4,
                      ),
                    ),
                  ],
                ),
              ),
              _NotebookBadge(
                icon: Icons.groups_rounded,
                label: '${members.length}',
                accent: const Color(0xFF5EEAD4),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: members.isEmpty
                ? const _NotebookNotice(
                    icon: Icons.group_off_rounded,
                    title: 'No other members found',
                    message:
                        'There are no additional active lab members with notebooks to browse right now.',
                    accent: Color(0xFF38BDF8),
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: members.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return Material(
                        color: palette.panelAlt,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _openMemberNotebook(context, member),
                          child: Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: palette.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  height: 38,
                                  width: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF14B8A6,
                                    ).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: const Icon(
                                    Icons.person_outline_rounded,
                                    color: Color(0xFF5EEAD4),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _memberDisplayName(member),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                          fontSize: 13.6,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _NotebookBadge(
                                            icon: Icons.badge_outlined,
                                            label: appState.roleLabelFor(
                                              member.role.trim(),
                                            ),
                                          ),
                                          if (member.userEmail
                                              .trim()
                                              .isNotEmpty)
                                            _NotebookBadge(
                                              icon: Icons.email_outlined,
                                              label: member.userEmail.trim(),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 15,
                                  color: palette.subtleText,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspace(
    BuildContext context,
    String labId, {
    required String notebookOwnerUid,
    required String notebookOwnerLabel,
    required bool isReadOnly,
  }) {
    return StreamBuilder<List<NotebookProjectModel>>(
      stream: _labNotebookService.getProjects(
        labId: labId,
        notebookOwnerUid: notebookOwnerUid,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                FirestoreAccessGuard.messageFor(snapshot.error),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.labmate.mutedText, height: 1.4),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final projects = snapshot.data ?? [];

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            final rail = _buildNotebookRail(
              context: context,
              canCreate:
                  !isReadOnly &&
                  !showMemberNotebookBrowser &&
                  appState.authenticatedUserId.trim().isNotEmpty,
              isWide: isWide,
              projectCount: projects.length,
              visibleOwnerLabel: notebookOwnerLabel,
            );
            final panel = _buildProjectsPanel(
              context,
              projects,
              notebookOwnerUid: notebookOwnerUid,
              notebookOwnerLabel: notebookOwnerLabel,
              isReadOnly: isReadOnly,
            );

            final content = isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 280, child: rail),
                      const SizedBox(width: 10),
                      Expanded(child: panel),
                    ],
                  )
                : Column(
                    children: [
                      rail,
                      const SizedBox(height: 10),
                      Expanded(child: panel),
                    ],
                  );

            if (!isReadOnly) {
              return content;
            }

            return Column(
              children: [
                _buildReadOnlyBanner(context),
                const SizedBox(height: 10),
                Expanded(child: content),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobileWidth = MediaQuery.sizeOf(context).width < 900;
    final canQuery = FirestoreAccessGuard.shouldQueryLabScopedData(
      appState: appState,
    );
    final hasAuthenticatedOwner = appState.authenticatedUserId
        .trim()
        .isNotEmpty;
    final labId = appState.selectedLabId.trim();
    final effectiveNotebookOwnerUid = _resolveNotebookOwnerUid();
    final effectiveNotebookOwnerLabel = _resolveNotebookOwnerLabel();
    final isReadOnly = _isReadOnlyView();

    final title = showMemberNotebookBrowser
        ? 'Member Notebooks'
        : isReadOnly
        ? 'Member Notebook'
        : 'Lab Notebook';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton:
          canQuery &&
              hasAuthenticatedOwner &&
              !showMemberNotebookBrowser &&
              !isReadOnly &&
              isMobileWidth
          ? FloatingActionButton.extended(
              onPressed: () => _openAddProject(context),
              backgroundColor: const Color(0xFF14B8A6),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Project',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: ResponsivePageContainer(
        maxWidth: 1500,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: !canQuery
              ? _buildBlockedState()
              : !hasAuthenticatedOwner
              ? _buildAuthRequiredState()
              : showMemberNotebookBrowser
              ? _buildMemberNotebookBrowser(context, labId)
              : _buildWorkspace(
                  context,
                  labId,
                  notebookOwnerUid: effectiveNotebookOwnerUid,
                  notebookOwnerLabel: effectiveNotebookOwnerLabel,
                  isReadOnly: isReadOnly,
                ),
        ),
      ),
    );
  }
}

class _NotebookNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color accent;

  const _NotebookNotice({
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

class _NotebookMetric extends StatelessWidget {
  final String label;
  final String value;

  const _NotebookMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14.0,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotebookBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accent;

  const _NotebookBadge({required this.icon, required this.label, this.accent});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final effectiveAccent = accent ?? colorScheme.primary;

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
            Icon(icon, size: 13, color: effectiveAccent),
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
