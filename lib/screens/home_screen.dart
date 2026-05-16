import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../widgets/add_action_sheet.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/responsive_page_container.dart';
import 'add_event_screen.dart';
import 'add_new_chemical_screen.dart';
import 'add_requirement_screen.dart';
import 'calculator_screen.dart';
import 'cart_screen.dart';
import 'chemical_inventory_screen.dart';
import 'edit_profile_screen.dart';
import 'electronic_lab_manual_screen.dart';
import 'events_screen.dart';
import 'export_reports_screen.dart';
import 'glass_apparatus_screen.dart';
import 'home_dashboard_tab.dart';
import 'import_inventory_screen.dart';
import 'instruments_screen.dart';
import 'latest_articles_screen.dart';
import 'native_chemdraw_screen.dart';
import 'orders_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppState appState;

  const HomeScreen({super.key, required this.appState});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;
  String? activeHomeOverlay;

  void changeTab(int index) {
    setState(() {
      selectedIndex = index;
      activeHomeOverlay = null;
    });
  }

  void openOverlay(String overlayName) {
    setState(() {
      selectedIndex = 0;
      activeHomeOverlay = overlayName;
    });
  }

  void openAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AddActionSheet(
          onAddRequirement: () {
            Navigator.pop(context);
            Navigator.push(
              this.context,
              MaterialPageRoute(builder: (_) => const AddRequirementScreen()),
            );
          },
          onAddNewChemical: () {
            Navigator.pop(context);
            Navigator.push(
              this.context,
              MaterialPageRoute(builder: (_) => const AddNewChemicalScreen()),
            );
          },
          onAddEvent: () {
            Navigator.pop(context);
            Navigator.push(
              this.context,
              MaterialPageRoute(builder: (_) => const AddEventScreen()),
            );
          },
        );
      },
    );
  }

  void openImportInventory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImportInventoryScreen()),
    );
  }

  void openExportReports() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExportReportsScreen(appState: widget.appState),
      ),
    );
  }

  void openMoleculeDraw() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NativeChemDrawScreen()),
    );
  }

  Future<void> signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Sign Out?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'This will sign you out of Firebase and clear the current lab session on this device.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Sign Out',
                style: TextStyle(color: Color(0xFFFB7185)),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await FirebaseAuth.instance.signOut();
      await widget.appState.clearSessionContext();

      if (!mounted) return;

      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not sign out: $error')));
    }
  }

  String get appBarTitle {
    switch (activeHomeOverlay) {
      case 'chemicals':
        return 'Chemical Library';
      case 'calculator':
        return 'Calculator';
      case 'instruments':
        return 'Instruments';
      case 'glass_apparatus':
        return 'Glass Apparatus';
      case 'orders':
        return 'Orders';
      case 'cart':
        return 'Cart';
      case 'lab_manual':
        return 'Electronic Lab Manual';
    }

    switch (selectedIndex) {
      case 1:
        return 'Events';
      case 2:
        return 'Latest Articles';
      case 3:
        return 'Personal Information';
      default:
        return 'Labmate';
    }
  }

  Widget get currentScreen {
    if (activeHomeOverlay == 'chemicals') {
      return const ChemicalInventoryScreen();
    }
    if (activeHomeOverlay == 'calculator') {
      return const CalculatorScreen();
    }
    if (activeHomeOverlay == 'instruments') {
      return const InstrumentsScreen();
    }
    if (activeHomeOverlay == 'glass_apparatus') {
      return const GlassApparatusScreen();
    }
    if (activeHomeOverlay == 'orders') {
      return const OrdersScreen();
    }
    if (activeHomeOverlay == 'cart') {
      return const CartScreen();
    }
    if (activeHomeOverlay == 'lab_manual') {
      return const ElectronicLabManualScreen();
    }
    return IndexedStack(
      index: selectedIndex,
      children: [
        HomeDashboardTab(
          appState: widget.appState,
          onOpenChemicals: () => openOverlay('chemicals'),
          onOpenCalculator: () => openOverlay('calculator'),
          onOpenProfile: () => changeTab(3),
          onOpenEvents: () => changeTab(1),
          onOpenArticles: () => changeTab(2),
          onOpenInstruments: () => openOverlay('instruments'),
          onOpenGlassApparatus: () => openOverlay('glass_apparatus'),
          onOpenOrders: () => openOverlay('orders'),
          onOpenCart: () => openOverlay('cart'),
          onOpenLabManual: () => openOverlay('lab_manual'),
          onOpenChemDraw: openMoleculeDraw,
          onOpenMore: () {},
        ),
        const EventsScreen(),
        const LatestArticlesScreen(),
        EditProfileScreen(appState: widget.appState),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showBackButton = activeHomeOverlay != null;
    final bool showMainAddButton = activeHomeOverlay == null;

    return Scaffold(
      appBar: AppBar(
        leading: showBackButton
            ? IconButton(
                onPressed: () {
                  setState(() {
                    activeHomeOverlay = null;
                  });
                },
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              )
            : null,
        title: Text(
          appBarTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          PopupMenuButton<_HomeOverflowAction>(
            tooltip: 'More options',
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            color: const Color(0xFF1E293B),
            onSelected: (action) {
              switch (action) {
                case _HomeOverflowAction.importInventory:
                  openImportInventory();
                  break;
                case _HomeOverflowAction.exportReports:
                  openExportReports();
                  break;
                case _HomeOverflowAction.signOut:
                  signOut();
                  break;
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem(
                  value: _HomeOverflowAction.importInventory,
                  child: _OverflowMenuItem(
                    icon: Icons.file_upload_rounded,
                    label: 'Import Inventory (Excel)',
                    color: Color(0xFF38BDF8),
                  ),
                ),
                PopupMenuItem(
                  value: _HomeOverflowAction.exportReports,
                  child: _OverflowMenuItem(
                    icon: Icons.file_download_rounded,
                    label: 'Export Reports',
                    color: Color(0xFF14B8A6),
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: _HomeOverflowAction.signOut,
                  child: _OverflowMenuItem(
                    icon: Icons.logout_rounded,
                    label: 'Sign Out',
                    color: Color(0xFFFB7185),
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: ResponsivePageContainer(child: currentScreen),
      floatingActionButton: showMainAddButton
          ? FloatingActionButton(
              onPressed: openAddSheet,
              backgroundColor: const Color(0xFF14B8A6),
              elevation: 6,
              shape: const CircleBorder(),
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavBar(
        currentIndex: selectedIndex,
        onTap: changeTab,
      ),
    );
  }
}

enum _HomeOverflowAction { importInventory, exportReports, signOut }

class _OverflowMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _OverflowMenuItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
