import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_state.dart';
import '../models/attendance_record_model.dart';
import '../models/chemical_model.dart';
import '../models/event_model.dart';
import '../models/order_model.dart';
import '../models/requirement_model.dart';
import '../models/user_profile.dart';
import '../services/attendance_service.dart';
import '../services/consumables_inventory_service.dart';
import '../services/event_service.dart';
import '../services/firestore_access_guard.dart';
import '../services/inventory_service.dart';
import '../services/order_service.dart';
import '../services/requirement_service.dart';
import '../theme/labmate_theme.dart';
import '../widgets/newly_arrived_section.dart';
import '../widgets/search_bar_widget.dart';
import 'attendance_screen.dart';
import 'chemical_detail_screen.dart';
import 'consumables_inventory_screen.dart';
import 'lab_notebook_screen.dart';
import 'lab_members_screen.dart';
import 'lab_settings_screen.dart';
import 'msds_lookup_screen.dart';
import 'recent_activity_screen.dart';

class HomeDashboardTab extends StatefulWidget {
  final AppState appState;
  final VoidCallback onOpenChemicals;
  final VoidCallback onOpenCalculator;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenEvents;
  final VoidCallback onOpenArticles;
  final VoidCallback onOpenInstruments;
  final VoidCallback onOpenGlassApparatus;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenLabManual;
  final VoidCallback onOpenChemDraw;
  final VoidCallback onOpenInventoryAnalytics;
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
    required this.onOpenGlassApparatus,
    required this.onOpenOrders,
    required this.onOpenCart,
    required this.onOpenLabManual,
    required this.onOpenChemDraw,
    required this.onOpenInventoryAnalytics,
    required this.onOpenMore,
  });

  @override
  State<HomeDashboardTab> createState() => _HomeDashboardTabState();

  void _openConsumablesInventory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConsumablesInventoryScreen()),
    );
  }

  void _openLabMembers(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LabMembersScreen(appState: appState)),
    );
  }

  void _openLabSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LabSettingsScreen(appState: appState)),
    );
  }

  void _openRecentActivity(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecentActivityScreen(appState: appState),
      ),
    );
  }

  void _openLabNotebook(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LabNotebookScreen(appState: appState)),
    );
  }

  void _openMsdsLookup(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MsdsLookupScreen()),
    );
  }

  Future<void> _openAttendance(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AttendanceScreen()),
    );
  }

  void _showComingSoonMessage(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  int _pendingApprovalCount(List<RequirementModel> requirements) {
    if (!appState.isPiAdmin) {
      return 0;
    }

    return requirements.where((requirement) {
      final status = requirement.status.trim().toLowerCase();
      return status == 'pending' ||
          status == 'waiting approval' ||
          status == 'waiting_approval';
    }).length;
  }

  int _ordersInProgressCount(List<OrderModel> orders) {
    return orders.where((order) {
      final status = order.status.trim().toLowerCase();
      return status == 'ordered';
    }).length;
  }

  bool _chemicalNeedsAttention(ChemicalModel chemical) {
    final availability = chemical.availability.trim().toLowerCase();
    return availability == 'low' ||
        availability.contains('about') ||
        availability.contains('finished') ||
        availability.contains('empty') ||
        availability.contains('not available') ||
        availability.contains('unavailable') ||
        availability == 'nil' ||
        availability == '0';
  }

  int _chemicalAttentionCount(List<ChemicalModel> chemicals) {
    final grouped = InventoryService().groupByCas(chemicals);
    return grouped.values.where((group) {
      return group.any(_chemicalNeedsAttention);
    }).length;
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _consumablesInventoryStream() {
    return ConsumablesInventoryService().getConsumablesInventoryDocs();
  }

  String? _firstAccessMessage(List<Object?> errors) {
    if (!FirestoreAccessGuard.shouldQueryLabScopedData(appState: appState)) {
      return FirestoreAccessGuard.userMessage;
    }

    for (final error in errors) {
      if (error != null) {
        return FirestoreAccessGuard.messageFor(error);
      }
    }

    return null;
  }

  double? _readQuantityNumber(String quantity) {
    final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(quantity.trim());
    if (match == null) {
      return null;
    }

    return double.tryParse(match.group(0) ?? '');
  }

  int _consumablesLowStockCount(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final quantity = (doc.data()['quantity'] ?? '').toString();
      final numericQuantity = _readQuantityNumber(quantity);
      return numericQuantity != null && numericQuantity <= 2;
    }).length;
  }

  Widget _buildAccessNotice(String message) {
    return Builder(
      builder: (context) {
        final palette = context.labmate;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: palette.warning,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 12.8,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWorkflowGrid({
    required List<_DashboardToolItem> workflowItems,
    required int pendingApprovalCount,
    required int ordersInProgressCount,
    required int chemicalAttentionCount,
    required int consumablesLowStockCount,
  }) {
    final itemsWithBadges = workflowItems.map((item) {
      final badgeCount = item.id == 'cart'
          ? pendingApprovalCount
          : item.id == 'orders'
          ? ordersInProgressCount
          : item.id == 'chemical_inventory'
          ? chemicalAttentionCount
          : item.id == 'consumables_inventory'
          ? consumablesLowStockCount
          : 0;

      return item.copyWith(badgeCount: badgeCount);
    }).toList();

    return _ReorderableWorkflowGrid(items: itemsWithBadges);
  }

  Future<void> _openHeroActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = sheetContext.labmate;
        final colorScheme = sheetContext.colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.panel,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lab Actions',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'View members or open settings for the current workspace.',
                    style: TextStyle(
                      color: palette.subtleText,
                      fontSize: 13,
                      height: 1.4,
                    ),
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
                    subtitle:
                        'Open join code, lab details, and workspace settings.',
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
}

class _HomeDashboardTabState extends State<HomeDashboardTab> {
  final GlobalKey<_DashboardChemicalSearchState> _dashboardSearchKey =
      GlobalKey<_DashboardChemicalSearchState>();
  final FocusNode _dashboardKeyboardFocusNode = FocusNode(
    debugLabel: 'homeDashboardKeyboardScope',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_dashboardKeyboardFocusNode.hasFocus) {
        _dashboardKeyboardFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _dashboardKeyboardFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleDashboardKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final isShortcutPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (!isShortcutPressed || event.logicalKey != LogicalKeyboardKey.keyF) {
      return KeyEventResult.ignored;
    }

    _dashboardSearchKey.currentState?.focusSearch();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final List<_DashboardToolItem> workflowItems = [
      _DashboardToolItem(
        id: 'chemical_inventory',
        title: 'Chemical Inventory',
        icon: Icons.science_rounded,
        accentColor: const Color(0xFF2DD4BF),
        onTap: widget.onOpenChemicals,
      ),
      _DashboardToolItem(
        id: 'consumables_inventory',
        title: 'Consumables Inventory',
        icon: Icons.inventory_rounded,
        accentColor: const Color(0xFF60A5FA),
        onTap: () => widget._openConsumablesInventory(context),
      ),
      _DashboardToolItem(
        id: 'inventory_analytics',
        title: 'Inventory Analytics',
        icon: Icons.insights_rounded,
        accentColor: const Color(0xFF0891B2),
        onTap: widget.onOpenInventoryAnalytics,
      ),
      _DashboardToolItem(
        id: 'cart',
        title: 'Cart',
        icon: Icons.assignment_rounded,
        accentColor: const Color(0xFFFBBF24),
        onTap: widget.onOpenCart,
      ),
      _DashboardToolItem(
        id: 'orders',
        title: 'Orders',
        icon: Icons.local_shipping_rounded,
        accentColor: const Color(0xFF38BDF8),
        onTap: widget.onOpenOrders,
      ),
      _DashboardToolItem(
        id: 'calculator',
        title: 'Calculator',
        icon: Icons.calculate_rounded,
        accentColor: const Color(0xFFA78BFA),
        onTap: widget.onOpenCalculator,
      ),
      _DashboardToolItem(
        id: 'instruments',
        title: 'Instruments',
        icon: Icons.precision_manufacturing_rounded,
        accentColor: const Color(0xFF94A3B8),
        onTap: widget.onOpenInstruments,
      ),
      _DashboardToolItem(
        id: 'chemdraw',
        title: 'ChemDraw',
        icon: Icons.draw_rounded,
        accentColor: const Color(0xFFF472B6),
        onTap: widget.onOpenChemDraw,
      ),
      _DashboardToolItem(
        id: 'log_books',
        title: 'Log books',
        icon: Icons.menu_book_outlined,
        accentColor: const Color(0xFF22C55E),
        onTap: () =>
            widget._showComingSoonMessage(context, 'Log books coming soon'),
      ),
      _DashboardToolItem(
        id: 'glass_apparatus',
        title: 'Glass apparatus',
        icon: Icons.science_outlined,
        accentColor: const Color(0xFFFB923C),
        onTap: widget.onOpenGlassApparatus,
      ),
      _DashboardToolItem(
        id: 'lab_notebook',
        title: 'Lab Notebook',
        icon: Icons.edit_note_outlined,
        accentColor: const Color(0xFF38BDF8),
        onTap: () => widget._openLabNotebook(context),
      ),
      _DashboardToolItem(
        id: 'more',
        title: 'More',
        icon: Icons.apps_outlined,
        accentColor: const Color(0xFF94A3B8),
        onTap: widget.onOpenMore,
        isFixed: true,
      ),
    ];

    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final isDesktopLayout = MediaQuery.sizeOf(context).width >= 900;
        final pagePadding = isDesktopLayout
            ? const EdgeInsets.fromLTRB(12, 8, 12, 16)
            : const EdgeInsets.fromLTRB(16, 8, 16, 20);
        final heroSearchGap = isDesktopLayout ? 10.0 : 12.0;
        final searchSectionGap = isDesktopLayout ? 12.0 : 20.0;
        final sectionGap = isDesktopLayout ? 14.0 : 20.0;
        final heroPadding = isDesktopLayout
            ? const EdgeInsets.all(10)
            : const EdgeInsets.all(12);
        final heroRadius = BorderRadius.circular(isDesktopLayout ? 18 : 22);
        final profile = widget.appState.profile;
        final profileName = profile.name.trim();
        final resolvedName = profileName.isEmpty || profileName == 'Your Name'
            ? widget.appState.authenticatedUserName
            : profileName;
        final photoReference = profile.photoUrl.trim();
        final selectedLabName = widget.appState.selectedLabName.trim();
        final visibleLabName = selectedLabName.isEmpty
            ? 'No lab selected'
            : selectedLabName;

        return Focus(
          focusNode: _dashboardKeyboardFocusNode,
          autofocus: true,
          onKeyEvent: _handleDashboardKeyEvent,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) {
              if (!_dashboardKeyboardFocusNode.hasFocus) {
                _dashboardKeyboardFocusNode.requestFocus();
              }
            },
            child: SafeArea(
              child: SingleChildScrollView(
                padding: pagePadding,
                child: StreamBuilder<List<ChemicalModel>>(
                  stream: InventoryService().getChemicals(),
                  builder: (context, chemicalsSnapshot) {
                    final chemicalsAccessMessage = widget._firstAccessMessage([
                      chemicalsSnapshot.error,
                    ]);
                    final chemicals =
                        chemicalsSnapshot.data ?? const <ChemicalModel>[];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isDesktopLayout) ...[
                          _DashboardChemicalSearch(
                            key: _dashboardSearchKey,
                            chemicals: chemicals,
                            accessMessage: chemicalsAccessMessage,
                            isDesktopLayout: false,
                          ),
                          SizedBox(height: heroSearchGap),
                        ],
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: heroRadius,
                            onTap: () => widget._openHeroActions(context),
                            child: Ink(
                              width: double.infinity,
                              padding: heroPadding,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0F766E),
                                    Color(0xFF0EA5E9),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: heroRadius,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _HeroProfileAvatar(
                                    photoReference: photoReference,
                                    displayName: resolvedName,
                                    fallbackEmail:
                                        widget.appState.authenticatedUserEmail,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          resolvedName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          visibleLabName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      _AttendanceStatusButton(
                                        appState: widget.appState,
                                        onOpen: () =>
                                            widget._openAttendance(context),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.16,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          widget.appState.currentRoleLabel,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (isDesktopLayout) ...[
                          SizedBox(height: heroSearchGap),
                          _DashboardChemicalSearch(
                            key: _dashboardSearchKey,
                            chemicals: chemicals,
                            accessMessage: chemicalsAccessMessage,
                            isDesktopLayout: true,
                          ),
                          SizedBox(height: searchSectionGap),
                        ] else
                          SizedBox(height: sectionGap),
                        if (widget.appState.shouldShowProfileReminder) ...[
                          _WorkflowEntryCard(
                            title: 'Complete Personal Information',
                            subtitle:
                                'Your profile is still incomplete. You can keep using Labmate and finish it when convenient.',
                            icon: Icons.person_outline_rounded,
                            accentColor: const Color(0xFFF59E0B),
                            onTap: widget.onOpenProfile,
                          ),
                          SizedBox(height: sectionGap),
                        ],
                        if (isDesktopLayout)
                          SizedBox(
                            height: 176,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Expanded(
                                  flex: 3,
                                  child: NewlyArrivedSection(),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 2,
                                  child: _UpcomingEventsPreview(
                                    onViewAll: widget.onOpenEvents,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          const NewlyArrivedSection(),
                          SizedBox(height: sectionGap),
                          _UpcomingEventsPreview(
                            onViewAll: widget.onOpenEvents,
                          ),
                        ],
                        SizedBox(height: sectionGap),
                        StreamBuilder<List<RequirementModel>>(
                          stream: RequirementService().getRequirements(),
                          builder: (context, requirementsSnapshot) {
                            final requirementsAccessMessage = widget
                                ._firstAccessMessage([
                                  requirementsSnapshot.error,
                                ]);
                            if (requirementsAccessMessage != null) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  widget._buildAccessNotice(
                                    requirementsAccessMessage,
                                  ),
                                  const SizedBox(height: 12),
                                  widget._buildWorkflowGrid(
                                    workflowItems: workflowItems,
                                    pendingApprovalCount: widget
                                        ._pendingApprovalCount(
                                          requirementsSnapshot.data ?? [],
                                        ),
                                    ordersInProgressCount: 0,
                                    chemicalAttentionCount: 0,
                                    consumablesLowStockCount: 0,
                                  ),
                                ],
                              );
                            }

                            return StreamBuilder<List<OrderModel>>(
                              stream: OrderService().getOrders(),
                              builder: (context, ordersSnapshot) {
                                final ordersAccessMessage = widget
                                    ._firstAccessMessage([
                                      ordersSnapshot.error,
                                    ]);
                                if (ordersAccessMessage != null) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      widget._buildAccessNotice(
                                        ordersAccessMessage,
                                      ),
                                      const SizedBox(height: 12),
                                      widget._buildWorkflowGrid(
                                        workflowItems: workflowItems,
                                        pendingApprovalCount: widget
                                            ._pendingApprovalCount(
                                              requirementsSnapshot.data ?? [],
                                            ),
                                        ordersInProgressCount: 0,
                                        chemicalAttentionCount: 0,
                                        consumablesLowStockCount: 0,
                                      ),
                                    ],
                                  );
                                }

                                return StreamBuilder<
                                  List<
                                    QueryDocumentSnapshot<Map<String, dynamic>>
                                  >
                                >(
                                  stream: widget._consumablesInventoryStream(),
                                  builder: (context, consumablesSnapshot) {
                                    final consumablesAccessMessage = widget
                                        ._firstAccessMessage([
                                          consumablesSnapshot.error,
                                        ]);

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (chemicalsAccessMessage != null) ...[
                                          widget._buildAccessNotice(
                                            chemicalsAccessMessage,
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                        if (consumablesAccessMessage !=
                                            null) ...[
                                          widget._buildAccessNotice(
                                            consumablesAccessMessage,
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                        widget._buildWorkflowGrid(
                                          workflowItems: workflowItems,
                                          pendingApprovalCount: widget
                                              ._pendingApprovalCount(
                                                requirementsSnapshot.data ?? [],
                                              ),
                                          ordersInProgressCount: widget
                                              ._ordersInProgressCount(
                                                ordersSnapshot.data ?? [],
                                              ),
                                          chemicalAttentionCount:
                                              chemicalsAccessMessage == null
                                              ? widget._chemicalAttentionCount(
                                                  chemicals,
                                                )
                                              : 0,
                                          consumablesLowStockCount: widget
                                              ._consumablesLowStockCount(
                                                consumablesSnapshot.data ?? [],
                                              ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                        SizedBox(height: sectionGap),
                        _WorkflowEntryCard(
                          title: 'MSDS / Safety',
                          subtitle:
                              'Search by CAS number and review a PubChem-based safety summary before handling chemicals.',
                          icon: Icons.health_and_safety_rounded,
                          accentColor: const Color(0xFFF59E0B),
                          onTap: () => widget._openMsdsLookup(context),
                        ),
                        SizedBox(height: sectionGap),
                        _WorkflowEntryCard(
                          title: 'Recent Activity',
                          subtitle:
                              'View recent requirements, orders, deliveries, and inventory entries for this lab.',
                          icon: Icons.notifications_rounded,
                          accentColor: const Color(0xFF14B8A6),
                          onTap: () => widget._openRecentActivity(context),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardChemicalSearch extends StatefulWidget {
  final List<ChemicalModel> chemicals;
  final String? accessMessage;
  final bool isDesktopLayout;

  const _DashboardChemicalSearch({
    super.key,
    required this.chemicals,
    required this.accessMessage,
    required this.isDesktopLayout,
  });

  @override
  State<_DashboardChemicalSearch> createState() =>
      _DashboardChemicalSearchState();
}

class _DashboardChemicalSearchState extends State<_DashboardChemicalSearch> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(
    debugLabel: 'homeDashboardSearch',
  );
  Timer? _searchDebounce;

  String _debouncedQuery = '';
  bool _showResults = false;
  bool _isOpeningSearchResult = false;
  bool _isOpeningAllSearchResults = false;
  int _highlightedIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_handleSearchFocusChange);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchFocusNode
      ..removeListener(_handleSearchFocusChange)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void focusSearch() {
    if (_searchFocusNode.hasFocus) {
      return;
    }

    _searchFocusNode.requestFocus();

    final text = _searchController.text;
    _searchController.selection = TextSelection.collapsed(offset: text.length);

    if (text.trim().isNotEmpty && mounted) {
      setState(() {
        _showResults = true;
      });
    }
  }

  void _handleSearchFocusChange() {
    if (!mounted) {
      return;
    }

    setState(() {
      if (_searchFocusNode.hasFocus) {
        _showResults = _searchController.text.trim().isNotEmpty;
      } else {
        _showResults = false;
      }
    });
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _debouncedQuery = '';
        _showResults = false;
        _highlightedIndex = 0;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _debouncedQuery = trimmed;
        _showResults = true;
        _highlightedIndex = 0;
      });
    });
  }

  List<ChemicalModel> _allMatchingChemicalsFor(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return const <ChemicalModel>[];
    }

    bool matchesQuery(ChemicalModel chemical) {
      final normalizedName = chemical.chemicalName.trim().toLowerCase();
      final normalizedCas = chemical.cas.trim().toLowerCase();
      final normalizedLabel = chemical.label.trim().toLowerCase();

      return normalizedName.contains(query) ||
          normalizedCas.contains(query) ||
          normalizedLabel.contains(query);
    }

    int scoreFor(ChemicalModel chemical) {
      final normalizedName = chemical.chemicalName.trim().toLowerCase();
      final normalizedCas = chemical.cas.trim().toLowerCase();
      final normalizedLabel = chemical.label.trim().toLowerCase();

      if (normalizedName == query ||
          normalizedCas == query ||
          normalizedLabel == query) {
        return 0;
      }
      if (normalizedName.startsWith(query)) {
        return 1;
      }
      if (normalizedLabel.startsWith(query)) {
        return 2;
      }
      if (normalizedCas.startsWith(query)) {
        return 3;
      }
      if (normalizedName.contains(query)) {
        return 4;
      }
      if (normalizedLabel.contains(query)) {
        return 5;
      }
      return 6;
    }

    final groupedMatches = <String, List<ChemicalModel>>{};
    for (final chemical in widget.chemicals) {
      final groupKey = chemical.cas.trim().isEmpty
          ? 'name:${chemical.chemicalName.trim().toLowerCase()}'
          : chemical.cas.trim().toLowerCase();

      groupedMatches.putIfAbsent(groupKey, () => []).add(chemical);
    }

    final results = <MapEntry<ChemicalModel, int>>[];
    for (final group in groupedMatches.values) {
      final matchingBottles = group.where(matchesQuery).toList();
      if (matchingBottles.isEmpty) {
        continue;
      }

      final representative = _representativeBottle(group);
      final bestScore = matchingBottles
          .map(scoreFor)
          .reduce((best, score) => score < best ? score : best);
      results.add(MapEntry(representative, bestScore));
    }

    results.sort((a, b) {
      final scoreComparison = a.value.compareTo(b.value);
      if (scoreComparison != 0) {
        return scoreComparison;
      }

      final nameComparison = a.key.chemicalName.toLowerCase().compareTo(
        b.key.chemicalName.toLowerCase(),
      );
      if (nameComparison != 0) {
        return nameComparison;
      }

      return a.key.label.toLowerCase().compareTo(b.key.label.toLowerCase());
    });

    return results.map((entry) => entry.key).toList();
  }

  List<ChemicalModel> _matchingChemicalsFor(String rawQuery) {
    return _allMatchingChemicalsFor(rawQuery).take(8).toList();
  }

  int _representativePriority(ChemicalModel chemical) {
    if (chemical.isActiveBottle) return 0;

    final availability = chemical.availability.trim().toLowerCase();
    if (availability == 'available') return 1;
    if (availability == 'low' || availability.contains('about')) return 2;
    if (chemical.isAvailable) return 3;
    return 4;
  }

  ChemicalModel _representativeBottle(List<ChemicalModel> bottles) {
    final sorted = [...bottles];
    sorted.sort((a, b) {
      final priorityComparison = _representativePriority(
        a,
      ).compareTo(_representativePriority(b));
      if (priorityComparison != 0) {
        return priorityComparison;
      }
      return a.label.compareTo(b.label);
    });
    return sorted.first;
  }

  void _closeResults({bool unfocus = false}) {
    if (mounted) {
      setState(() {
        _showResults = false;
      });
    }

    if (unfocus) {
      _searchFocusNode.unfocus();
    }
  }

  void _openChemical(ChemicalModel chemical) {
    if (_isOpeningSearchResult) {
      return;
    }

    _isOpeningSearchResult = true;
    _searchDebounce?.cancel();
    _searchFocusNode.unfocus();

    if (mounted) {
      setState(() {
        _showResults = false;
      });
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChemicalDetailScreen(chemical: chemical),
      ),
    ).whenComplete(() {
      _isOpeningSearchResult = false;
    });
  }

  void _openTopResult() {
    if (widget.accessMessage != null) {
      return;
    }

    final results = _matchingChemicalsFor(_searchController.text);
    if (results.isEmpty) {
      if (mounted) {
        setState(() {
          _showResults = true;
        });
      }
      return;
    }

    final safeIndex = _highlightedIndex.clamp(0, results.length - 1);
    _openChemical(results[safeIndex]);
  }

  KeyEventResult _handleSearchKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_searchFocusNode.hasFocus) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _closeResults(unfocus: true);
      return KeyEventResult.handled;
    }

    final results = _matchingChemicalsFor(_searchController.text);
    if (!_showResults || results.isEmpty) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _highlightedIndex = (_highlightedIndex + 1) % results.length;
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _highlightedIndex =
            (_highlightedIndex - 1 + results.length) % results.length;
      });
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  String _buildResultSubtitle(ChemicalModel chemical) {
    final parts = <String>[];

    if (chemical.label.trim().isNotEmpty) {
      parts.add('Label ${chemical.label.trim()}');
    }
    if (chemical.location.trim().isNotEmpty) {
      parts.add(chemical.location.trim());
    }
    if (chemical.availability.trim().isNotEmpty) {
      parts.add(chemical.availability.trim());
    }

    return parts.join(' | ');
  }

  String _activeSearchQuery() {
    final debounced = _debouncedQuery.trim();
    if (debounced.isNotEmpty) {
      return debounced;
    }
    return _searchController.text.trim();
  }

  Widget _buildSearchResultRow({
    required ChemicalModel chemical,
    required VoidCallback onOpen,
    bool isHighlighted = false,
    bool openOnTapDown = true,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final subtitle = _buildResultSubtitle(chemical);

    return Material(
      color: isHighlighted ? palette.selected : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        onTapDown: openOnTapDown ? (_) => onOpen() : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chemical.chemicalName.trim().isEmpty
                          ? 'Untitled chemical'
                          : chemical.chemicalName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 13.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      chemical.cas.trim().isEmpty
                          ? 'No CAS number'
                          : chemical.cas,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: 12.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.subtleText,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Open chemical detail',
                onPressed: onOpen,
                icon: Icon(
                  Icons.arrow_outward_rounded,
                  size: 18,
                  color: palette.subtleText,
                ),
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewAllResultsButton() {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _handleViewAllSearchResults(),
      child: TextButton.icon(
        onPressed: _handleViewAllSearchResults,
        icon: const Icon(Icons.open_in_new_rounded, size: 16),
        label: const Text('View all results'),
      ),
    );
  }

  void _handleViewAllSearchResults() {
    if (_isOpeningAllSearchResults || widget.accessMessage != null) {
      return;
    }

    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _closeResults();
      return;
    }

    final allMatches = _allMatchingChemicalsFor(query);
    _isOpeningAllSearchResults = true;
    _closeResults();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _isOpeningAllSearchResults = false;
        return;
      }

      try {
        await _showAllResultsSheet(query, allMatches);
      } finally {
        _isOpeningAllSearchResults = false;
      }
    });
  }

  Future<void> _showAllResultsSheet(
    String query,
    List<ChemicalModel> allMatches,
  ) async {
    if (widget.accessMessage != null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = sheetContext.labmate;
        final colorScheme = sheetContext.colorScheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
                  maxWidth: widget.isDesktopLayout ? 720 : double.infinity,
                ),
                decoration: BoxDecoration(
                  color: palette.panel,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'All results for "$query"',
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${allMatches.length} matching chemical${allMatches.length == 1 ? '' : 's'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.mutedText,
                                    fontSize: 12.8,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: palette.border),
                    Flexible(
                      child: allMatches.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(18),
                              child: Text(
                                'No chemicals found. Try a different chemical name, CAS number, or bottle label.',
                                style: TextStyle(
                                  color: palette.mutedText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(8),
                              itemCount: allMatches.length,
                              separatorBuilder: (context, index) =>
                                  Divider(height: 1, color: palette.border),
                              itemBuilder: (context, index) {
                                final chemical = allMatches[index];
                                return _buildSearchResultRow(
                                  chemical: chemical,
                                  openOnTapDown: false,
                                  onOpen: () {
                                    Navigator.of(sheetContext).pop();
                                    _openChemical(chemical);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final activeQuery = _activeSearchQuery();
    final searchResults = _matchingChemicalsFor(activeQuery);
    final showPanel = _showResults && activeQuery.isNotEmpty;
    final safeHighlightedIndex = searchResults.isEmpty
        ? -1
        : _highlightedIndex.clamp(0, searchResults.length - 1);

    return TapRegion(
      onTapOutside: (_) => _closeResults(unfocus: true),
      child: Focus(
        onKeyEvent: _handleSearchKeyEvent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SearchBarWidget(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onTap: () {
                if (_searchController.text.trim().isNotEmpty) {
                  setState(() {
                    _showResults = true;
                  });
                }
              },
              onChanged: _handleSearchChanged,
              onSubmitted: (_) => _openTopResult(),
              hintText: 'Search chemicals by name, CAS, or label',
              isFocused: _searchFocusNode.hasFocus,
              compact: widget.isDesktopLayout,
              suffixIcon: widget.isDesktopLayout
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: palette.panelAlt.withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: palette.border.withValues(alpha: 0.72),
                        ),
                      ),
                      child: Text(
                        'Ctrl+F',
                        style: TextStyle(
                          color: palette.subtleText,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : null,
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: !showPanel
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        constraints: BoxConstraints(
                          maxHeight: widget.isDesktopLayout ? 380 : 320,
                        ),
                        decoration: BoxDecoration(
                          color: palette.panel,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: palette.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: widget.accessMessage != null
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  widget.accessMessage!,
                                  style: TextStyle(
                                    color: palette.mutedText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              )
                            : searchResults.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'No chemicals found',
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Try a different chemical name, CAS number, or bottle label.',
                                      style: TextStyle(
                                        color: palette.mutedText,
                                        fontSize: 12.8,
                                        fontWeight: FontWeight.w500,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: _buildViewAllResultsButton(),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: ListView.separated(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                      shrinkWrap: true,
                                      itemCount: searchResults.length,
                                      separatorBuilder: (context, index) =>
                                          Divider(
                                            height: 1,
                                            color: palette.border,
                                          ),
                                      itemBuilder: (context, index) {
                                        final chemical = searchResults[index];
                                        final isHighlighted =
                                            index == safeHighlightedIndex;

                                        return _buildSearchResultRow(
                                          chemical: chemical,
                                          isHighlighted: isHighlighted,
                                          onOpen: () => _openChemical(chemical),
                                        );
                                      },
                                    ),
                                  ),
                                  Divider(height: 1, color: palette.border),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${searchResults.length} quick result${searchResults.length == 1 ? '' : 's'}',
                                            style: TextStyle(
                                              color: palette.mutedText,
                                              fontSize: 12.4,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        _buildViewAllResultsButton(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroProfileAvatar extends StatelessWidget {
  final String photoReference;
  final String displayName;
  final String fallbackEmail;

  const _HeroProfileAvatar({
    required this.photoReference,
    required this.displayName,
    required this.fallbackEmail,
  });

  ImageProvider<Object>? _resolveImageProvider() {
    final cleanReference = photoReference.trim();
    if (cleanReference.isEmpty ||
        UserProfile.isScientificAvatarReference(cleanReference)) {
      return null;
    }

    final uri = Uri.tryParse(cleanReference);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return NetworkImage(cleanReference);
    }

    if (uri != null && uri.scheme == 'file') {
      final file = File.fromUri(uri);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }

    final file = File(cleanReference);
    if (file.existsSync()) {
      return FileImage(file);
    }

    return null;
  }

  String _fallbackInitials() {
    final identity = displayName.trim().isNotEmpty
        ? displayName.trim()
        : fallbackEmail.trim();
    if (identity.isEmpty) {
      return 'U';
    }

    final words = identity
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();

    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }

    final cleanIdentity = identity.contains('@')
        ? identity.split('@').first
        : identity;
    if (cleanIdentity.isEmpty) {
      return 'U';
    }
    final maxLength = cleanIdentity.length >= 2 ? 2 : 1;
    return cleanIdentity.substring(0, maxLength).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scientificAvatar = UserProfile.scientificAvatarFromReference(
      photoReference,
    );
    final imageProvider = _resolveImageProvider();
    final initials = _fallbackInitials();

    return Container(
      height: 72,
      width: 72,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.24),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: scientificAvatar != null
            ? _HeroProfileScientificAvatar(icon: scientificAvatar.icon)
            : imageProvider == null
            ? _HeroProfileInitials(initials: initials)
            : Image(
                image: imageProvider,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _HeroProfileInitials(initials: initials);
                },
              ),
      ),
    );
  }
}

enum _AttendanceDashboardState { notCheckedIn, present, checkedOut }

class _AttendanceStatusButton extends StatefulWidget {
  final AppState appState;
  final Future<void> Function() onOpen;

  const _AttendanceStatusButton({required this.appState, required this.onOpen});

  @override
  State<_AttendanceStatusButton> createState() =>
      _AttendanceStatusButtonState();
}

class _AttendanceStatusButtonState extends State<_AttendanceStatusButton> {
  final AttendanceService _attendanceService = AttendanceService();
  _AttendanceDashboardState _status = _AttendanceDashboardState.notCheckedIn;
  String _trackedLabId = '';
  String _trackedUserId = '';

  String get _currentLabId => widget.appState.selectedLabId.trim();
  String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void didUpdateWidget(covariant _AttendanceStatusButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_trackedLabId != _currentLabId || _trackedUserId != _currentUserId) {
      _refreshStatus();
    }
  }

  _AttendanceDashboardState _statusFromRecord(AttendanceRecordModel? record) {
    if (record == null) {
      return _AttendanceDashboardState.notCheckedIn;
    }

    if (record.isCheckedOut) {
      return _AttendanceDashboardState.checkedOut;
    }

    return _AttendanceDashboardState.present;
  }

  Future<void> _refreshStatus() async {
    final labId = _currentLabId;
    final userId = _currentUserId;

    _trackedLabId = labId;
    _trackedUserId = userId;

    if (!FirestoreAccessGuard.shouldQueryLabScopedData(
          appState: widget.appState,
        ) ||
        userId.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = _AttendanceDashboardState.notCheckedIn;
      });
      return;
    }

    try {
      final record = await _attendanceService.getTodayRecord(
        labId: labId,
        userId: userId,
      );
      if (!mounted) {
        return;
      }

      if (labId != _currentLabId || userId != _currentUserId) {
        return;
      }

      setState(() {
        _status = _statusFromRecord(record);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = _AttendanceDashboardState.notCheckedIn;
      });
    }
  }

  Future<void> _handleTap() async {
    await widget.onOpen();
    if (!mounted) {
      return;
    }

    await _refreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final IconData icon;
    late final Color accentColor;
    late final Color backgroundColor;

    switch (_status) {
      case _AttendanceDashboardState.present:
        label = 'Present';
        icon = Icons.check_circle_rounded;
        accentColor = const Color(0xFFBBF7D0);
        backgroundColor = const Color(0x3334D399);
        break;
      case _AttendanceDashboardState.checkedOut:
        label = 'Checked out';
        icon = Icons.logout_rounded;
        accentColor = const Color(0xFFBFDBFE);
        backgroundColor = const Color(0x3338BDF8);
        break;
      case _AttendanceDashboardState.notCheckedIn:
        label = 'Check in';
        icon = Icons.qr_code_scanner_rounded;
        accentColor = Colors.white;
        backgroundColor = Colors.white.withValues(alpha: 0.14);
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _handleTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accentColor.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14.5, color: accentColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 11.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroProfileScientificAvatar extends StatelessWidget {
  final IconData icon;

  const _HeroProfileScientificAvatar({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 36),
    );
  }
}

class _HeroProfileInitials extends StatelessWidget {
  final String initials;

  const _HeroProfileInitials({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _UpcomingEventsPreview extends StatelessWidget {
  final VoidCallback onViewAll;

  const _UpcomingEventsPreview({required this.onViewAll});

  String _formatDateTime(DateTime value) {
    final monthNames = const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final meridiem = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.day} ${monthNames[value.month - 1]}, $hour:$minute $meridiem';
  }

  List<EventModel> _nextUpcomingEvents(List<EventModel> events) {
    final now = DateTime.now();
    return events
        .where(
          (event) => !event.isCompleted && !event.scheduledAt.isBefore(now),
        )
        .take(3)
        .toList();
  }

  String _previewDetail(EventModel event) {
    final segments = <String>[_formatDateTime(event.scheduledAt)];
    final type = event.eventType.trim();
    final venue = event.venue.trim();

    if (type.isNotEmpty) {
      segments.add(type);
    } else if (venue.isNotEmpty) {
      segments.add(venue);
    }

    return segments.join(' - ');
  }

  static const double _eventItemHeight = 52;
  @override
  Widget build(BuildContext context) {
    final isDesktopLayout = MediaQuery.sizeOf(context).width >= 900;
    final eventItemHeight = isDesktopLayout ? 36.0 : _eventItemHeight;
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      padding: isDesktopLayout
          ? const EdgeInsets.fromLTRB(12, 10, 12, 10)
          : const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(20),
        border: isDesktopLayout ? Border.all(color: palette.border) : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Upcoming Events',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  foregroundColor: palette.warning,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'View All',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          StreamBuilder<List<EventModel>>(
            stream: EventService().getEvents(),
            builder: (context, snapshot) {
              if (!FirestoreAccessGuard.shouldQueryLabScopedData()) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      FirestoreAccessGuard.userMessage,
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      FirestoreAccessGuard.messageFor(snapshot.error),
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              }

              final upcomingEvents = _nextUpcomingEvents(snapshot.data ?? []);

              if (snapshot.connectionState == ConnectionState.waiting &&
                  upcomingEvents.isEmpty) {
                return SizedBox(
                  height: eventItemHeight,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                    ),
                  ),
                );
              }

              if (upcomingEvents.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No upcoming events for this lab yet.',
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: upcomingEvents.map((event) {
                  return _UpcomingEventTile(
                    title: event.normalizedTitle,
                    detail: _previewDetail(event),
                    height: eventItemHeight,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UpcomingEventTile extends StatelessWidget {
  final String title;
  final String detail;
  final double height;

  const _UpcomingEventTile({
    required this.title,
    required this.detail,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            height: 8,
            width: 8,
            decoration: BoxDecoration(
              color: palette.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colorScheme.onSurface,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardToolItem {
  final String id;
  final String title;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final int badgeCount;
  final bool isFixed;

  const _DashboardToolItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.badgeCount = 0,
    this.isFixed = false,
  });

  _DashboardToolItem copyWith({int? badgeCount}) {
    return _DashboardToolItem(
      id: id,
      title: title,
      icon: icon,
      accentColor: accentColor,
      onTap: onTap,
      badgeCount: badgeCount ?? this.badgeCount,
      isFixed: isFixed,
    );
  }
}

class _ReorderableWorkflowGrid extends StatefulWidget {
  final List<_DashboardToolItem> items;

  const _ReorderableWorkflowGrid({required this.items});

  @override
  State<_ReorderableWorkflowGrid> createState() =>
      _ReorderableWorkflowGridState();
}

class _ReorderableWorkflowGridState extends State<_ReorderableWorkflowGrid> {
  static const String _prefsKey = 'dashboard_tool_order_v1';
  static const double _spacing = 14.0;

  List<String>? _savedMovableIds;

  @override
  void initState() {
    super.initState();
    _loadSavedOrder();
  }

  Future<void> _loadSavedOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIds = prefs.getStringList(_prefsKey);
    final normalizedIds = _sanitizeMovableOrderIds(savedIds);
    if (!mounted) {
      return;
    }

    setState(() {
      _savedMovableIds = normalizedIds;
    });

    if (savedIds != null && !_sameStringList(savedIds, normalizedIds)) {
      await prefs.setStringList(_prefsKey, normalizedIds);
    }
  }

  List<_DashboardToolItem> get _movableItems {
    return widget.items.where((item) => !item.isFixed).toList();
  }

  bool _isMovableId(String id) {
    return _movableItems.any((item) => item.id == id);
  }

  bool _sameStringList(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }

    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) {
        return false;
      }
    }

    return true;
  }

  List<String> _sanitizeMovableOrderIds(List<String>? savedIds) {
    final availableIds = _movableItems.map((item) => item.id).toList();
    final sourceIds = savedIds ?? availableIds;

    final orderedIds = <String>[];
    for (final id in sourceIds) {
      if (availableIds.contains(id) && !orderedIds.contains(id)) {
        orderedIds.add(id);
      }
    }

    for (final id in availableIds) {
      if (!orderedIds.contains(id)) {
        orderedIds.add(id);
      }
    }

    return orderedIds;
  }

  List<String> _normalizedMovableOrderIds() {
    return _sanitizeMovableOrderIds(_savedMovableIds);
  }

  List<_DashboardToolItem> _orderedItems() {
    final itemsById = {for (final item in widget.items) item.id: item};

    final orderedMovableItems = _normalizedMovableOrderIds()
        .map((id) => itemsById[id])
        .whereType<_DashboardToolItem>()
        .toList();

    _DashboardToolItem? moreItem;
    for (final item in widget.items) {
      if (item.id == 'more' && item.isFixed) {
        moreItem = item;
        break;
      }
    }

    final orderedItems = List<_DashboardToolItem>.from(orderedMovableItems);
    if (moreItem != null) {
      orderedItems.add(moreItem);
    }

    return orderedItems;
  }

  Future<void> _persistMovableOrder(List<String> ids) async {
    _savedMovableIds = ids;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, ids);
  }

  Future<void> _reorderTile({
    required String draggedId,
    required String targetId,
  }) async {
    if (draggedId == targetId) {
      return;
    }

    final movableIds = _normalizedMovableOrderIds();
    if (!movableIds.contains(draggedId) || !movableIds.contains(targetId)) {
      return;
    }

    final nextOrder = List<String>.from(movableIds);
    final draggedIndex = nextOrder.indexOf(draggedId);
    final targetIndex = nextOrder.indexOf(targetId);
    nextOrder.remove(draggedId);
    final updatedTargetIndex = nextOrder.indexOf(targetId);
    if (updatedTargetIndex == -1) {
      nextOrder.add(draggedId);
    } else if (draggedIndex < targetIndex) {
      nextOrder.insert(updatedTargetIndex + 1, draggedId);
    } else {
      nextOrder.insert(updatedTargetIndex, draggedId);
    }

    if (mounted) {
      setState(() {
        _savedMovableIds = nextOrder;
      });
    }

    await _persistMovableOrder(nextOrder);
  }

  int _columnCountForWidth(double width) {
    if (width >= 1100) {
      return 6;
    }
    if (width >= 900) {
      return 5;
    }
    if (width > 700) {
      return 4;
    }
    if (width < 360) {
      return 3;
    }
    return 4;
  }

  double _aspectRatioForWidth({
    required double width,
    required int columnCount,
  }) {
    if (width > 700) {
      return 1.12;
    }
    return columnCount == 3 ? 0.96 : 0.92;
  }

  double? _tileExtentForWidth(double width) {
    if (width > 700) {
      return 118;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final orderedItems = _orderedItems();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = _columnCountForWidth(width);
        final childAspectRatio = _aspectRatioForWidth(
          width: width,
          columnCount: crossAxisCount,
        );
        final tileExtent = _tileExtentForWidth(width);
        final tileWidth =
            (width - ((crossAxisCount - 1) * _spacing)) / crossAxisCount;
        final tileHeight = tileExtent ?? tileWidth / childAspectRatio;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orderedItems.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: _spacing,
            crossAxisSpacing: _spacing,
            childAspectRatio: childAspectRatio,
            mainAxisExtent: tileExtent,
          ),
          itemBuilder: (context, index) {
            final item = orderedItems[index];
            final card = _HomeToolCard(
              title: item.title,
              icon: item.icon,
              accentColor: item.accentColor,
              onTap: item.onTap,
              badgeCount: item.badgeCount,
              isFixed: item.isFixed,
            );

            if (item.isFixed) {
              return card;
            }

            return DragTarget<String>(
              onWillAcceptWithDetails: (details) {
                final candidate = details.data;
                return candidate != item.id && _isMovableId(candidate);
              },
              onAcceptWithDetails: (details) {
                _reorderTile(draggedId: details.data, targetId: item.id);
              },
              builder: (context, candidateData, rejectedData) {
                final isActiveTarget = candidateData.isNotEmpty;

                return AnimatedScale(
                  scale: isActiveTarget ? 1.03 : 1.0,
                  duration: const Duration(milliseconds: 140),
                  child: LongPressDraggable<String>(
                    data: item.id,
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    feedback: SizedBox(
                      width: tileWidth,
                      height: tileHeight,
                      child: Transform.scale(
                        scale: 1.04,
                        child: Material(
                          color: Colors.transparent,
                          elevation: 10,
                          borderRadius: BorderRadius.circular(16),
                          child: card,
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.32,
                      child: IgnorePointer(child: card),
                    ),
                    child: card,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _HomeToolCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final int badgeCount;
  final bool isFixed;

  const _HomeToolCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.badgeCount = 0,
    this.isFixed = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight <= 130;
        final cardRadius = BorderRadius.circular(isCompact ? 14 : 18);
        final iconBoxSize = isCompact ? 36.0 : 42.0;
        final iconSize = isCompact ? 20.0 : 22.0;
        final verticalPadding = isCompact ? 8.0 : 10.0;
        final labelFontSize = isCompact ? 11.5 : 12.5;

        return Material(
          color: palette.panel,
          borderRadius: cardRadius,
          elevation: 1,
          child: InkWell(
            borderRadius: cardRadius,
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 6,
                vertical: verticalPadding,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: iconBoxSize,
                        width: iconBoxSize,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            isCompact ? 10 : 12,
                          ),
                        ),
                        child: Icon(icon, color: accentColor, size: iconSize),
                      ),
                      if (badgeCount > 0)
                        Positioned(
                          right: -8,
                          top: -8,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 22,
                              minHeight: 22,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFB7185),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: palette.panel,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              badgeCount > 99 ? '99+' : '$badgeCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      if (isFixed)
                        Positioned(
                          right: -7,
                          bottom: -7,
                          child: Container(
                            height: 18,
                            width: 18,
                            decoration: BoxDecoration(
                              color: palette.panelAlt,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: palette.border),
                            ),
                            child: Icon(
                              Icons.lock_rounded,
                              color: palette.subtleText,
                              size: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: isCompact ? 7 : 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
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
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Material(
      color: palette.panel,
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
                  color: accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: palette.subtleText,
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
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Material(
      color: palette.panel,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: palette.selected,
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: palette.subtleText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
