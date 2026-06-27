import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/user_profile_service.dart';
import '../theme/labmate_theme.dart';
import '../widgets/add_action_sheet.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/responsive_page_container.dart';
import 'add_event_screen.dart';
import 'add_new_chemical_screen.dart';
import 'add_requirement_screen.dart';
import 'app_settings_screen.dart';
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
import 'inventory_analytics_screen.dart';
import 'instruments_screen.dart';
import 'latest_articles_screen.dart';
import 'more_screen.dart';
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
  bool _profileCompletionPromptShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowProfileCompletionPrompt();
    });
  }

  Future<void> _maybeShowProfileCompletionPrompt() async {
    if (!mounted || _profileCompletionPromptShown) {
      return;
    }

    final userId = widget.appState.authenticatedUserId;
    if (userId.isEmpty || widget.appState.profile.profileCompleted == true) {
      return;
    }

    _profileCompletionPromptShown = true;
    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProfileCompletionDialog(appState: widget.appState),
    );

    if (!mounted) {
      return;
    }

    if (completed == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile details saved')));
    }
  }

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

  void openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppSettingsScreen(appState: widget.appState),
      ),
    );
  }

  void openMore() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MoreScreen(
          appState: widget.appState,
          onNavigateHome: () => changeTab(0),
        ),
      ),
    );
  }

  Future<void> signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Sign Out?'),
          content: const Text(
            'This will sign you out of Firebase and clear the current lab session on this device.',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
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
      case 'inventory_analytics':
        return 'Inventory Analytics';
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
    if (activeHomeOverlay == 'inventory_analytics') {
      return const InventoryAnalyticsScreen();
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
          onOpenInventoryAnalytics: () => openOverlay('inventory_analytics'),
          onOpenMore: openMore,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktopNavigation = constraints.maxWidth >= 900;

        return Scaffold(
          appBar: AppBar(
            leading: showBackButton
                ? IconButton(
                    onPressed: () {
                      setState(() {
                        activeHomeOverlay = null;
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                  )
                : null,
            title: Text(
              appBarTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            actions: [
              PopupMenuButton<_HomeOverflowAction>(
                tooltip: 'More options',
                icon: const Icon(Icons.more_vert_rounded),
                color: Theme.of(context).colorScheme.surface,
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
          body: useDesktopNavigation
              ? Row(
                  children: [
                    _DesktopHomeSidebar(
                      selectedIndex: selectedIndex,
                      activeOverlay: activeHomeOverlay,
                      onSelectTab: changeTab,
                      onAdd: openAddSheet,
                      onOpenInventoryAnalytics: () {
                        openOverlay('inventory_analytics');
                      },
                      onOpenSettings: openSettings,
                    ),
                    Expanded(
                      child: ResponsivePageContainer(
                        maxWidth: 1280,
                        child: currentScreen,
                      ),
                    ),
                  ],
                )
              : ResponsivePageContainer(child: currentScreen),
          floatingActionButton: !useDesktopNavigation && showMainAddButton
              ? FloatingActionButton(
                  onPressed: openAddSheet,
                  backgroundColor: const Color(0xFF14B8A6),
                  elevation: 6,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                )
              : null,
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: useDesktopNavigation
              ? null
              : BottomNavBar(currentIndex: selectedIndex, onTap: changeTab),
        );
      },
    );
  }
}

class _ProfileCompletionDialog extends StatefulWidget {
  final AppState appState;

  const _ProfileCompletionDialog({required this.appState});

  @override
  State<_ProfileCompletionDialog> createState() =>
      _ProfileCompletionDialogState();
}

class _ProfileCompletionDialogState extends State<_ProfileCompletionDialog> {
  final _formKey = GlobalKey<FormState>();
  final UserProfileService _userProfileService = UserProfileService();

  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late final TextEditingController _designationController;
  late final TextEditingController _researchAreaController;

  late bool _showEmailToLabMembers;
  late bool _showMobileToLabMembers;
  bool _isSaving = false;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.appState.profile;
    final profileName = profile.name.trim();
    _nameController = TextEditingController(
      text: profileName == 'Your Name' ? '' : profileName,
    );
    _contactController = TextEditingController(text: profile.contactNumber);
    _designationController = TextEditingController(
      text: profile.designation ?? '',
    );
    _researchAreaController = TextEditingController(
      text: profile.researchArea ?? '',
    );
    _showEmailToLabMembers = profile.showEmailToLabMembers;
    _showMobileToLabMembers = profile.showMobileToLabMembers;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _designationController.dispose();
    _researchAreaController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label) {
    final palette = context.labmate;
    return InputDecoration(
      labelText: label,
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
    );
  }

  Future<void> _saveProfile() async {
    if (_isSaving || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _userProfileService.completeBasicProfile(
        uid: widget.appState.authenticatedUserId,
        name: _nameController.text,
        contactNumber: _contactController.text,
        designation: _designationController.text,
        researchArea: _researchAreaController.text,
        showEmailToLabMembers: _showEmailToLabMembers,
        showMobileToLabMembers: _showMobileToLabMembers,
      );
      await widget.appState.loadAuthenticatedUserProfile();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      debugPrint('Failed to save profile completion details: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save profile. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    if (_isSigningOut || _isSaving) {
      return;
    }

    setState(() {
      _isSigningOut = true;
    });

    try {
      await FirebaseAuth.instance.signOut();
      await widget.appState.clearSessionContext();

      if (!mounted) {
        return;
      }

      final navigator = Navigator.of(context);
      navigator.pop(false);
      navigator.popUntil((route) => route.isFirst);
    } catch (error) {
      debugPrint('Could not sign out from profile completion dialog: $error');
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: palette.panel,
        title: Text(
          'Complete your profile',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Please complete your basic profile details. Members of the same lab will be able to view these basic details in read-only mode.',
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration('Name'),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contactController,
                    decoration: _inputDecoration('Contact number (optional)'),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _designationController,
                    decoration: _inputDecoration('Designation (optional)'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _researchAreaController,
                    decoration: _inputDecoration('Research area (optional)'),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _saveProfile(),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show my email to lab members'),
                    value: _showEmailToLabMembers,
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            setState(() {
                              _showEmailToLabMembers = value;
                            });
                          },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show my mobile number to lab members'),
                    value: _showMobileToLabMembers,
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            setState(() {
                              _showMobileToLabMembers = value;
                            });
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving || _isSigningOut ? null : _signOut,
            child: _isSigningOut
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Sign out', style: TextStyle(color: palette.mutedText)),
          ),
          ElevatedButton(
            onPressed: _isSaving || _isSigningOut ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}

enum _HomeOverflowAction { importInventory, exportReports, signOut }

class _DesktopHomeSidebar extends StatelessWidget {
  final int selectedIndex;
  final String? activeOverlay;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onAdd;
  final VoidCallback onOpenInventoryAnalytics;
  final VoidCallback onOpenSettings;

  const _DesktopHomeSidebar({
    required this.selectedIndex,
    required this.activeOverlay,
    required this.onSelectTab,
    required this.onAdd,
    required this.onOpenInventoryAnalytics,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 224,
      decoration: BoxDecoration(
        color: context.labmate.sidebar,
        border: Border(right: BorderSide(color: context.labmate.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  'Labmate',
                  style: TextStyle(
                    color: context.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _DesktopSidebarItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isSelected:
                    selectedIndex == 0 &&
                    activeOverlay != 'inventory_analytics',
                onTap: () => onSelectTab(0),
              ),
              _DesktopSidebarItem(
                icon: Icons.insights_rounded,
                label: 'Inventory Analytics',
                isSelected: activeOverlay == 'inventory_analytics',
                onTap: onOpenInventoryAnalytics,
              ),
              _DesktopSidebarItem(
                icon: Icons.event_rounded,
                label: 'Events',
                isSelected: activeOverlay == null && selectedIndex == 1,
                onTap: () => onSelectTab(1),
              ),
              _DesktopSidebarItem(
                icon: Icons.article_rounded,
                label: 'Articles',
                isSelected: activeOverlay == null && selectedIndex == 2,
                onTap: () => onSelectTab(2),
              ),
              _DesktopSidebarItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                isSelected: activeOverlay == null && selectedIndex == 3,
                onTap: () => onSelectTab(3),
              ),
              _DesktopSidebarItem(
                icon: Icons.settings_rounded,
                label: 'Settings',
                isSelected: false,
                onTap: onOpenSettings,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onAdd,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Add',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopSidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DesktopSidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isSelected ? context.labmate.selected : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? context.colorScheme.primary
                      : context.labmate.subtleText,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? context.colorScheme.onSurface
                        : context.labmate.mutedText,
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
