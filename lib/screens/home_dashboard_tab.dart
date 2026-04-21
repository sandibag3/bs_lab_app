import 'package:flutter/material.dart';
import '../app_state.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/newly_arrived_section.dart';
import '../widgets/search_bar_widget.dart';
import 'consumables_inventory_screen.dart';
import 'newly_arrived_items_screen.dart';

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

  void _openNewlyArrived(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NewlyArrivedItemsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        final about = profile.about.trim();
        final headlineText = about.isEmpty
            ? 'Manage inventory, requirements, orders, and newly arrived items in one place.'
            : about;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SearchBarWidget(
                  onTap: onOpenChemicals,
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
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
                              fontSize: 14,
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
                              appState.demoUserRole.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        resolvedName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        headlineText,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
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
                _WorkflowEntryCard(
                  title: 'Newly Arrived',
                  subtitle: 'Review delivered chemicals and consumables waiting for inventory entry.',
                  icon: Icons.inventory_2_rounded,
                  accentColor: const Color(0xFFF59E0B),
                  onTap: () => _openNewlyArrived(context),
                ),
                const SizedBox(height: 12),
                _WorkflowEntryCard(
                  title: 'Chemical Inventory',
                  subtitle: 'Browse stock, search by CAS, and review bottle-level details.',
                  icon: Icons.science_rounded,
                  accentColor: const Color(0xFF14B8A6),
                  onTap: onOpenChemicals,
                ),
                const SizedBox(height: 12),
                _WorkflowEntryCard(
                  title: 'Consumables Inventory',
                  subtitle: 'Open the current consumables list added through the intake flow.',
                  icon: Icons.inventory_rounded,
                  accentColor: const Color(0xFF38BDF8),
                  onTap: () => _openConsumablesInventory(context),
                ),
                const SizedBox(height: 12),
                _WorkflowEntryCard(
                  title: 'Requirements / Cart',
                  subtitle: 'Review submitted requirements and continue the approval workflow.',
                  icon: Icons.assignment_rounded,
                  accentColor: const Color(0xFFA78BFA),
                  onTap: onOpenCart,
                ),
                const SizedBox(height: 12),
                _WorkflowEntryCard(
                  title: 'Orders',
                  subtitle: 'Track ordered items, delivery status, and inventory intake progress.',
                  icon: Icons.local_shipping_rounded,
                  accentColor: const Color(0xFFFB7185),
                  onTap: onOpenOrders,
                ),
                const SizedBox(height: 24),
                const NewlyArrivedSection(),
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
