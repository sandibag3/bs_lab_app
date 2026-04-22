import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/lab_context_model.dart';
import '../models/lab_membership_model.dart';
import '../services/lab_membership_service.dart';
import '../services/lab_service.dart';

class LabSwitcherScreen extends StatefulWidget {
  final AppState appState;

  const LabSwitcherScreen({
    super.key,
    required this.appState,
  });

  @override
  State<LabSwitcherScreen> createState() => _LabSwitcherScreenState();
}

class _LabSwitcherScreenState extends State<LabSwitcherScreen> {
  final LabMembershipService _labMembershipService = LabMembershipService();
  final LabService _labService = LabService();

  late Future<List<_LabOption>> _optionsFuture;
  String _switchingLabId = '';

  @override
  void initState() {
    super.initState();
    _optionsFuture = _loadOptions();
  }

  Future<List<_LabOption>> _loadOptions() async {
    final appState = widget.appState;
    final options = <_LabOption>[];
    final seenLabIds = <String>{};

    void addOption(_LabOption option) {
      final cleanLabId = option.labId.trim();
      if (cleanLabId.isEmpty || !seenLabIds.add(cleanLabId)) {
        return;
      }
      options.add(option);
    }

    addOption(
      _LabOption(
        labId: AppState.demoLabId,
        labName: AppState.demoLabName,
        roleName: appState.demoUserRole.name,
        sourceLabel: 'Demo',
        localRoleName: appState.demoUserRole.name,
      ),
    );

    if (appState.isLocalFallbackLabSelected) {
      addOption(
        _LabOption(
          labId: appState.selectedLabId,
          labName: appState.selectedLabName.trim().isEmpty
              ? 'Local Lab'
              : appState.selectedLabName,
          roleName: appState.currentRoleName,
          sourceLabel: 'Local',
          localRoleName: appState.currentRoleName,
        ),
      );
    }

    final userId = appState.authenticatedUserId;
    if (userId.isNotEmpty) {
      List<LabMembershipModel> memberships = [];
      try {
        memberships = await _labMembershipService.getMembershipsForUser(
          userId: userId,
        );
      } catch (_) {
        memberships = [];
      }

      for (final membership in memberships) {
        var resolvedLabName = membership.labName.trim();

        if (resolvedLabName.isEmpty) {
          try {
            final labContext = await _labService.getLabContextById(
              membership.labId,
            );
            resolvedLabName = labContext?.selectedLabName ?? '';
          } catch (_) {
            resolvedLabName = '';
          }
        }

        addOption(
          _LabOption(
            labId: membership.labId,
            labName: resolvedLabName.isEmpty ? membership.labId : resolvedLabName,
            roleName: membership.role.trim().isEmpty
                ? DemoUserRole.researcher.name
                : membership.role.trim(),
            sourceLabel: 'Member',
            localRoleName: '',
          ),
        );
      }
    }

    if (appState.hasSelectedLab &&
        !appState.isDemoLabSelected &&
        !appState.isLocalFallbackLabSelected) {
      addOption(
        _LabOption(
          labId: appState.selectedLabId,
          labName: appState.selectedLabName.trim().isEmpty
              ? appState.selectedLabId
              : appState.selectedLabName,
          roleName: appState.currentRoleName,
          sourceLabel: 'Member',
          localRoleName: '',
        ),
      );
    }

    options.sort((a, b) {
      final currentLabId = appState.selectedLabId.trim();
      final aIsCurrent = a.labId == currentLabId;
      final bIsCurrent = b.labId == currentLabId;

      if (aIsCurrent && !bIsCurrent) return -1;
      if (!aIsCurrent && bIsCurrent) return 1;

      if (a.sourceLabel == 'Demo' && b.sourceLabel != 'Demo') return -1;
      if (a.sourceLabel != 'Demo' && b.sourceLabel == 'Demo') return 1;

      return a.labName.toLowerCase().compareTo(b.labName.toLowerCase());
    });

    return options;
  }

  Future<void> _refreshOptions() async {
    setState(() {
      _optionsFuture = _loadOptions();
    });
    await _optionsFuture;
  }

  Future<void> _switchLab(_LabOption option) async {
    if (_switchingLabId.isNotEmpty) return;

    setState(() {
      _switchingLabId = option.labId;
    });

    try {
      if (option.labId == AppState.demoLabId) {
        await widget.appState.enterDemoLab();
      } else {
        await widget.appState.saveSelectedLabContextWithRole(
          LabContextModel(
            selectedLabId: option.labId,
            selectedLabName: option.labName,
          ),
          localRoleName: option.localRoleName,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() {
          _switchingLabId = '';
        });
      }
    }
  }

  Widget _buildHeaderCard() {
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
            'Switch between the demo lab and any shared labs you belong to.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Switch Lab',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<_LabOption>>(
          future: _optionsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final options = snapshot.data ?? [];

            return RefreshIndicator(
              onRefresh: _refreshOptions,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: options.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildHeaderCard();
                  }

                  final option = options[index - 1];
                  final isSelected =
                      option.labId.trim() == widget.appState.selectedLabId.trim();
                  final isSwitching = _switchingLabId == option.labId;

                  return Material(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: isSwitching ? null : () => _switchLab(option),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              height: 46,
                              width: 46,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                option.sourceLabel == 'Demo'
                                    ? Icons.play_circle_outline_rounded
                                    : Icons.apartment_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.labName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _InlineBadge(label: option.sourceLabel),
                                      _InlineBadge(
                                        label: widget.appState.roleLabelFor(
                                          option.roleName,
                                        ),
                                      ),
                                      if (isSelected)
                                        const _InlineBadge(
                                          label: 'Current',
                                          accentColor: Color(0xFF14B8A6),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            isSwitching
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.arrow_forward_ios_rounded,
                                    color: isSelected
                                        ? const Color(0xFF14B8A6)
                                        : Colors.white.withOpacity(0.65),
                                    size: isSelected ? 20 : 16,
                                  ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LabOption {
  final String labId;
  final String labName;
  final String roleName;
  final String sourceLabel;
  final String localRoleName;

  const _LabOption({
    required this.labId,
    required this.labName,
    required this.roleName,
    required this.sourceLabel,
    required this.localRoleName,
  });
}

class _InlineBadge extends StatelessWidget {
  final String label;
  final Color accentColor;

  const _InlineBadge({
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
