import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/notebook_project_model.dart';
import '../services/firestore_access_guard.dart';
import '../services/lab_notebook_service.dart';
import '../widgets/responsive_page_container.dart';
import 'add_notebook_project_screen.dart';
import 'notebook_project_detail_screen.dart';

class LabNotebookScreen extends StatelessWidget {
  final AppState appState;
  final LabNotebookService _labNotebookService = LabNotebookService();

  LabNotebookScreen({super.key, required this.appState});

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _openAddProject(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddNotebookProjectScreen(appState: appState),
      ),
    );
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

  Widget _buildNotebookRail({
    required BuildContext context,
    required bool canCreate,
    required bool isWide,
    required int projectCount,
  }) {
    final selectedLabName = appState.selectedLabName.trim();
    final visibleLabName = selectedLabName.isEmpty
        ? 'No lab selected'
        : selectedLabName;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lab Notebook',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Project workspace',
                      style: TextStyle(
                        color: Colors.white54,
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
          const SizedBox(height: 10),
          const Text(
            'Organize research by project, then open each project as an experiment workspace.',
            style: TextStyle(
              color: Colors.white70,
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
                    label: 'Projects',
                    value: projectCount.toString(),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: _NotebookMetric(label: 'Mode', value: 'ELN V1'),
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _NotebookBadge(
                  icon: Icons.folder_copy_rounded,
                  label: '$projectCount project${projectCount == 1 ? '' : 's'}',
                ),
                const _NotebookBadge(
                  icon: Icons.grid_view_rounded,
                  label: 'ELN workspace',
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
        ],
      ),
    );
  }

  Widget _buildProjectCard(
    BuildContext context,
    NotebookProjectModel project, {
    bool compact = false,
  }) {
    final description = project.description.trim();

    return Material(
      color: const Color(0xFF111827),
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
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                          style: const TextStyle(
                            color: Colors.white,
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
                    color: Colors.white.withValues(alpha: 0.42),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1220),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  description.isEmpty
                      ? 'No project description yet. Open the project to start building the experiment workspace.'
                      : description,
                  maxLines: compact ? 4 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: description.isEmpty
                        ? Colors.white54
                        : Colors.white70,
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
                    label: project.creatorLabel,
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
    List<NotebookProjectModel> projects,
  ) {
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
          body = const Center(
            child: _NotebookNotice(
              icon: Icons.folder_open_rounded,
              title: 'No notebook projects yet',
              message:
                  'Create your first project to start organizing experiments and reaction notes.',
              accent: Color(0xFF14B8A6),
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
                child: _buildProjectCard(context, projects[index]),
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
              return _buildProjectCard(context, projects[index], compact: true);
            },
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Projects',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Open a project to view its experiment workspace',
                          style: TextStyle(
                            color: Colors.white54,
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

  Widget _buildWorkspace(BuildContext context, String labId) {
    return StreamBuilder<List<NotebookProjectModel>>(
      stream: _labNotebookService.getProjects(labId: labId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                FirestoreAccessGuard.messageFor(snapshot.error),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
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
              canCreate: true,
              isWide: isWide,
              projectCount: projects.length,
            );
            final panel = _buildProjectsPanel(context, projects);

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

  @override
  Widget build(BuildContext context) {
    final isMobileWidth = MediaQuery.sizeOf(context).width < 900;

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text(
          'Lab Notebook',
          style: TextStyle(color: Colors.white),
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final canCreate = FirestoreAccessGuard.shouldQueryLabScopedData(
            appState: appState,
          );
          if (!canCreate || !isMobileWidth) {
            return const SizedBox.shrink();
          }

          return FloatingActionButton.extended(
            onPressed: () => _openAddProject(context),
            backgroundColor: const Color(0xFF14B8A6),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Project',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          );
        },
      ),
      body: ResponsivePageContainer(
        maxWidth: 1500,
        child: AnimatedBuilder(
          animation: appState,
          builder: (context, _) {
            final labId = appState.selectedLabId.trim();
            final canQuery = FirestoreAccessGuard.shouldQueryLabScopedData(
              appState: appState,
            );

            return Padding(
              padding: const EdgeInsets.all(12),
              child: canQuery
                  ? _buildWorkspace(context, labId)
                  : _buildBlockedState(),
            );
          },
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 28),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
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
                  color: accent ?? Colors.white70,
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
