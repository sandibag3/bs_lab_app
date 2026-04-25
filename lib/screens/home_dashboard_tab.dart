import 'package:flutter/material.dart';
import '../app_state.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/newly_arrived_section.dart';
import '../widgets/search_bar_widget.dart';
import 'consumables_inventory_screen.dart';
import 'lab_members_screen.dart';
import 'lab_settings_screen.dart';
import 'lab_switcher_screen.dart';

class HomeDashboardTab extends StatelessWidget {
  final AppState appState;
  final VoidCallback onOpenChemicals;
  final VoidCallback onOpenCalculator;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenEvents;
  final VoidCallback onOpenArticles;
  final VoidCallback onOpenInstruments;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenLabManual;
  final VoidCallback onOpenChemDraw;
  final VoidCallback onOpenMore;

  const HomeDashboardTab({
    super.key,
    required this.appState,
    required this.onOpenChemicals,
    required this.onOpenCalculator,
    required this.onOpenProfile,
    required this.onOpenEvents,
    required this.onOpenArticles,
    required this.onOpenInstruments,
    required this.onOpenOrders,
    required this.onOpenCart,
    required this.onOpenLabManual,
    required this.onOpenChemDraw,
    required this.onOpenMore,
  });

  void _openConsumablesInventory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ConsumablesInventoryScreen(),
      ),
    );
  }

  Future<void> _openLabSwitcher(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LabSwitcherScreen(appState: appState),
      ),
    );
  }

  void _openLabMembers(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LabMembersScreen(appState: appState),
      ),
    );
  }

  void _openLabSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LabSettingsScreen(appState: appState),
      ),
    );
  }

  Future<void> _openHeroActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lab Actions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Switch labs, view members, or open settings for the current workspace.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _LabActionTile(
                    icon: Icons.swap_horiz_rounded,
                    title: 'Switch Lab',
                    subtitle: 'Choose a different lab context you belong to.',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _openLabSwitcher(context);
                    },
                  ),
                  const SizedBox(height: 10),
                  _LabActionTile(
                    icon: Icons.groups_rounded,
                    title: 'Lab Members',
                    subtitle: 'View the current lab membership list and roles.',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openLabMembers(context);
                    },
                  ),
                  const SizedBox(height: 10),
                  _LabActionTile(
                    icon: Icons.settings_rounded,
                    title: 'Lab Settings',
                    subtitle: 'Open join code, lab details, and workspace settings.',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openLabSettings(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> workflowItems = [
      {
        'title': 'Chemical Inventory',
        'icon': Icons.science_rounded,
        'onTap': onOpenChemicals,
      },
      {
        'title': 'Consumables Inventory',
        'icon': Icons.inventory_rounded,
        'onTap': () => _openConsumablesInventory(context),
      },
      {
        'title': 'Cart',
        'icon': Icons.assignment_rounded,
        'onTap': onOpenCart,
      },
      {
        'title': 'Orders',
        'icon': Icons.local_shipping_rounded,
        'onTap': onOpenOrders,
      },
    ];

    final List<Map<String, dynamic>> toolItems = [
      {
        'title': 'Calculator',
        'icon': Icons.calculate_rounded,
      },
      {
        'title': 'Instruments',
        'icon': Icons.precision_manufacturing_rounded,
      },
      {
        'title': 'Lab Manual',
        'icon': Icons.description_rounded,
      },
      {
        'title': 'ChemDraw',
        'icon': Icons.draw_rounded,
      },
      {
        'title': 'More',
        'icon': Icons.more_horiz_rounded,
      },
    ];

    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final profile = appState.profile;
        final profileName = profile.name.trim();
        final resolvedName =
            profileName.isEmpty || profileName == 'Your Name'
                ? appState.authenticatedUserName
                : profileName;
        final selectedLabName = appState.selectedLabName.trim();

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SearchBarWidget(
                  onTap: onOpenChemicals,
                ),
                const SizedBox(height: 14),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => _openHeroActions(context),
                    child: Ink(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF0F766E),
                            Color(0xFF0EA5E9),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Labmate',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  appState.currentRoleLabel,
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
                            resolvedName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.apartment_rounded,
                                      color: Colors.white,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        selectedLabName.isEmpty
                                            ? 'Tap to open lab actions'
                                            : selectedLabName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.8,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const NewlyArrivedSection(),
                const SizedBox(height: 24),
                const Text(
                  'Upcoming Events',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Keep lab reminders, meetings, and scheduling updates visible.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                _WorkflowEntryCard(
                  title: 'Open Events',
                  subtitle: 'View upcoming meetings, reminders, and lab schedules in the Events section.',
                  icon: Icons.event_note_rounded,
                  accentColor: const Color(0xFFF59E0B),
                  onTap: onOpenEvents,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Core Workflows',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Quick entry points for the modules used most in Labmate.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: workflowItems.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.22,
                  ),
                  itemBuilder: (context, index) {
                    final item = workflowItems[index];
                    final title = item['title'] as String;
                    final icon = item['icon'] as IconData;
                    final onTap = item['onTap'] as VoidCallback;

                    return DashboardCard(
                      title: title,
                      icon: icon,
                      onTap: onTap,
                    );
                  },
                ),
                const SizedBox(height: 20),
                _WorkflowEntryCard(
                  title: 'Open More Tools',
                  subtitle: 'Access calculator, instruments, lab manual, ChemDraw, and other shortcuts.',
                  icon: Icons.widgets_rounded,
                  accentColor: const Color(0xFF38BDF8),
                  onTap: onOpenMore,
                ),
                const SizedBox(height: 24),
                const Text(
                  'More Tools',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: toolItems.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemBuilder: (context, index) {
                    final item = toolItems[index];

                    return DashboardCard(
                      title: item['title'],
                      icon: item['icon'],
                      onTap: () {
                        if (item['title'] == 'Calculator') {
                          onOpenCalculator();
                        } else if (item['title'] == 'Instruments') {
                          onOpenInstruments();
                        } else if (item['title'] == 'Lab Manual') {
                          onOpenLabManual();
                        } else if (item['title'] == 'ChemDraw') {
                          onOpenChemDraw();
                        } else if (item['title'] == 'More') {
                          onOpenMore();
                        } else if (item['title'] == 'Events') {
                          onOpenEvents();
                        } else if (item['title'] == 'Latest Articles') {
                          onOpenArticles();
                        } else if (item['title'] == 'Profile') {
                          onOpenProfile();
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WorkflowEntryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _WorkflowEntryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.6),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LabActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0x2214B8A6),
                child: Icon(icon, color: const Color(0xFF14B8A6)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
