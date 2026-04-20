import 'package:flutter/material.dart';
import '../app_state.dart';
import '../widgets/add_action_sheet.dart';
import '../widgets/bottom_nav_bar.dart';
import 'add_event_screen.dart';
import 'add_new_chemical_screen.dart';
import 'add_requirement_screen.dart';
import 'calculator_screen.dart';
import 'cart_screen.dart';
import 'chemdraw_screen.dart';
import 'chemical_inventory_screen.dart';
import 'edit_profile_screen.dart';
import 'electronic_lab_manual_screen.dart';
import 'events_screen.dart';
import 'home_dashboard_tab.dart';
import 'instruments_screen.dart';
import 'latest_articles_screen.dart';
import 'more_screen.dart';
import 'orders_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppState appState;

  const HomeScreen({
    super.key,
    required this.appState,
  });

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
              MaterialPageRoute(
                builder: (_) => const AddRequirementScreen(),
              ),
            );
          },
          onAddNewChemical: () {
            Navigator.pop(context);
            Navigator.push(
              this.context,
              MaterialPageRoute(
                builder: (_) => const AddNewChemicalScreen(),
              ),
            );
          },
          onAddEvent: () {
            Navigator.pop(context);
            Navigator.push(
              this.context,
              MaterialPageRoute(
                builder: (_) => const AddEventScreen(),
              ),
            );
          },
        );
      },
    );
  }

  String get appBarTitle {
    switch (activeHomeOverlay) {
      case 'chemicals':
        return 'Chemical Library';
      case 'calculator':
        return 'Calculator';
      case 'instruments':
        return 'Instruments';
      case 'orders':
        return 'Orders';
      case 'cart':
        return 'Cart';
      case 'lab_manual':
        return 'Electronic Lab Manual';
      case 'chemdraw':
        return 'ChemDraw';
      case 'more':
        return 'More';
    }

    switch (selectedIndex) {
      case 1:
        return 'Events';
      case 2:
        return 'Latest Articles';
      case 3:
        return 'Edit Profile';
      default:
        return 'Labmate Dashboard';
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
    if (activeHomeOverlay == 'orders') {
      return const OrdersScreen();
    }
    if (activeHomeOverlay == 'cart') {
      return const CartScreen();
    }
    if (activeHomeOverlay == 'lab_manual') {
      return const ElectronicLabManualScreen();
    }
    if (activeHomeOverlay == 'chemdraw') {
      return const ChemDrawScreen();
    }
    if (activeHomeOverlay == 'more') {
      return const MoreScreen();
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
          onOpenOrders: () => openOverlay('orders'),
          onOpenCart: () => openOverlay('cart'),
          onOpenLabManual: () => openOverlay('lab_manual'),
          onOpenChemDraw: () => openOverlay('chemdraw'),
          onOpenMore: () => openOverlay('more'),
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
    final bool showEditIcon = selectedIndex == 0 && activeHomeOverlay == null;
    final bool showHomeAddButton =
        selectedIndex == 0 && activeHomeOverlay == null;

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
        actions: showEditIcon
            ? [
                IconButton(
                  tooltip: 'Edit Profile',
                  onPressed: () => changeTab(3),
                  icon: const Icon(
                    Icons.edit_rounded,
                    color: Color(0xFF14B8A6),
                  ),
                ),
              ]
            : [],
      ),
      body: currentScreen,
      floatingActionButton: showHomeAddButton
          ? FloatingActionButton.extended(
              onPressed: openAddSheet,
              backgroundColor: const Color(0xFF14B8A6),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
      bottomNavigationBar: BottomNavBar(
        currentIndex: selectedIndex,
        onTap: changeTab,
      ),
    );
  }
}
