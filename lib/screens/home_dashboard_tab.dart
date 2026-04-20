import 'package:flutter/material.dart';
import '../app_state.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/newly_arrived_section.dart';
import '../widgets/search_bar_widget.dart';

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

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> dashboardItems = [
      {
        'title': 'Chemical Library',
        'icon': Icons.biotech_rounded,
      },
      {
        'title': 'Instruments',
        'icon': Icons.precision_manufacturing_rounded,
      },
      {
        'title': 'Orders',
        'icon': Icons.shopping_cart_rounded,
      },
      {
        'title': 'Cart',
        'icon': Icons.shopping_bag_rounded,
      },
      {
        'title': 'Calculator',
        'icon': Icons.calculate_rounded,
      },
      {
        'title': 'Electronic Lab Manual',
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
                      const Text(
                        'Welcome back!',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        profile.name.trim().isEmpty
                            ? 'Your Name'
                            : profile.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        profile.about.trim().isEmpty
                            ? 'Your chemistry lab partner'
                            : profile.about,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const NewlyArrivedSection(),

                const SizedBox(height: 24),

                Row(
                  children: [
                    const Text(
                      'Upcoming Events',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: onOpenEvents,
                      child: const Text(
                        'View all',
                        style: TextStyle(
                          color: Color(0xFF14B8A6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2435),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.06),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _eventRow(
                        icon: Icons.science_rounded,
                        title: 'Research Seminar',
                        subtitle: 'Today • 4:00 PM • CSB Seminar Hall',
                        status: 'Upcoming',
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 12),
                      _eventRow(
                        icon: Icons.delete_outline_rounded,
                        title: 'Waste Disposal',
                        subtitle: 'Tomorrow • 10:30 AM • Lab',
                        status: 'Scheduled',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Dashboard',
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
                  itemCount: dashboardItems.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemBuilder: (context, index) {
                    final item = dashboardItems[index];

                    return DashboardCard(
                      title: item['title'],
                      icon: item['icon'],
                      onTap: () {
                        if (item['title'] == 'Chemical Library') {
                          onOpenChemicals();
                        } else if (item['title'] == 'Calculator') {
                          onOpenCalculator();
                        } else if (item['title'] == 'Instruments') {
                          onOpenInstruments();
                        } else if (item['title'] == 'Orders') {
                          onOpenOrders();
                        } else if (item['title'] == 'Cart') {
                          onOpenCart();
                        } else if (item['title'] == 'Electronic Lab Manual') {
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

  Widget _eventRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0x2214B8A6),
          child: Icon(
            icon,
            color: const Color(0xFF14B8A6),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
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
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: const Color(0x2214B8A6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            status,
            style: const TextStyle(
              color: Color(0xFF14B8A6),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
