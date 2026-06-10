import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/order_model.dart';
import '../models/purchase_order_model.dart';
import '../services/firestore_access_guard.dart';
import '../services/purchase_order_service.dart';
import '../theme/labmate_theme.dart';
import '../widgets/responsive_page_container.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key, required this.labId});

  final String labId;

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

enum _PurchaseOrderStatusFilter {
  all,
  draft,
  submitted,
  processing,
  completed,
  cancelled,
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  late final PurchaseOrderService _purchaseOrderService;
  late final TextEditingController _searchController;
  late Stream<List<PurchaseOrderModel>> _purchaseOrdersStream;
  _PurchaseOrderStatusFilter _statusFilter = _PurchaseOrderStatusFilter.all;
  String _searchQuery = '';
  bool? _analyticsExpandedPreference;

  @override
  void initState() {
    super.initState();
    _purchaseOrderService = PurchaseOrderService();
    _searchController = TextEditingController();
    _purchaseOrdersStream = _createPurchaseOrdersStream();
  }

  @override
  void didUpdateWidget(covariant PurchaseOrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.labId != widget.labId) {
      setState(() {
        _statusFilter = _PurchaseOrderStatusFilter.all;
        _searchQuery = '';
        _searchController.clear();
        _purchaseOrdersStream = _createPurchaseOrdersStream();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<PurchaseOrderModel>> _createPurchaseOrdersStream() {
    return _purchaseOrderService.streamPurchaseOrders(widget.labId);
  }

  void _refreshStream() {
    setState(() {
      _purchaseOrdersStream = _createPurchaseOrdersStream();
    });
  }

  void _selectStatusFilter(_PurchaseOrderStatusFilter filter) {
    if (_statusFilter == filter) {
      return;
    }

    setState(() {
      _statusFilter = filter;
    });
  }

  void _toggleAnalyticsExpanded(bool currentValue) {
    setState(() {
      _analyticsExpandedPreference = !currentValue;
    });
  }

  bool _matchesStatusFilter(PurchaseOrderModel purchaseOrder) {
    if (_statusFilter == _PurchaseOrderStatusFilter.all) {
      return true;
    }

    final normalizedStatus = _normalizedStatus(purchaseOrder.status);
    switch (_statusFilter) {
      case _PurchaseOrderStatusFilter.all:
        return true;
      case _PurchaseOrderStatusFilter.draft:
        return normalizedStatus == 'draft';
      case _PurchaseOrderStatusFilter.submitted:
        return normalizedStatus == 'submitted';
      case _PurchaseOrderStatusFilter.processing:
        return normalizedStatus == 'processing';
      case _PurchaseOrderStatusFilter.completed:
        return normalizedStatus == 'completed';
      case _PurchaseOrderStatusFilter.cancelled:
        return normalizedStatus == 'cancelled';
    }
  }

  bool _matchesSearchQuery(PurchaseOrderModel purchaseOrder) {
    final cleanQuery = _searchQuery.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      return true;
    }

    final haystacks = <String>[
      purchaseOrder.folderNumber,
      purchaseOrder.institutePoNumber ?? '',
      purchaseOrder.indentNumber ?? '',
      purchaseOrder.title ?? '',
      purchaseOrder.fundNameSnapshot,
      purchaseOrder.fundCodeSnapshot ?? '',
      purchaseOrder.vendor ?? '',
    ];

    return haystacks.any((value) => value.toLowerCase().contains(cleanQuery));
  }

  List<PurchaseOrderModel> _applyFilters(
    List<PurchaseOrderModel> purchaseOrders,
  ) {
    return purchaseOrders
        .where(_matchesStatusFilter)
        .where(_matchesSearchQuery)
        .toList(growable: false);
  }

  Future<void> _openPurchaseOrderDetails(
    PurchaseOrderModel purchaseOrder,
  ) async {
    final isDesktop = MediaQuery.sizeOf(context).width >= 720;

    if (isDesktop) {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: _PurchaseOrderDetailsSheet(
                purchaseOrder: purchaseOrder,
                labId: widget.labId,
                purchaseOrderService: _purchaseOrderService,
              ),
            ),
          );
        },
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.96,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _PurchaseOrderDetailsSheet(
              purchaseOrder: purchaseOrder,
              labId: widget.labId,
              purchaseOrderService: _purchaseOrderService,
            ),
          ),
        );
      },
    );
  }

  String? _errorDetail(Object? error) {
    final message = FirestoreAccessGuard.messageFor(
      error,
      fallback: 'Unable to load Purchase Orders.',
    );
    if (message.trim().isEmpty ||
        message.trim() == 'Unable to load Purchase Orders.') {
      return null;
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Orders')),
      body: SafeArea(
        child: ResponsivePageContainer(
          maxWidth: 1120,
          child: StreamBuilder<List<PurchaseOrderModel>>(
            stream: _purchaseOrdersStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _PurchaseOrdersErrorState(
                  detail: _errorDetail(snapshot.error),
                  onRetry: _refreshStream,
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const _PurchaseOrdersLoadingState();
              }

              final purchaseOrders =
                  snapshot.data ?? const <PurchaseOrderModel>[];
              final filteredPurchaseOrders = _applyFilters(purchaseOrders);
              final summary = _PurchaseOrdersSummary.fromPurchaseOrders(
                purchaseOrders,
              );

              if (purchaseOrders.isEmpty) {
                return const _PurchaseOrdersEmptyState();
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 900;
                  final pagePadding = isDesktop ? 12.0 : 16.0;
                  final sectionGap = isDesktop ? 12.0 : 16.0;
                  final analyticsExpanded =
                      _analyticsExpandedPreference ?? isDesktop;
                  final analytics = _PurchaseOrderAnalytics.fromPurchaseOrders(
                    purchaseOrders,
                  );

                  return ListView(
                    padding: EdgeInsets.all(pagePadding),
                    children: [
                      _PurchaseOrdersSummarySection(summary: summary),
                      SizedBox(height: sectionGap),
                      _PurchaseOrdersAnalyticsSection(
                        analytics: analytics,
                        isExpanded: analyticsExpanded,
                        onToggleExpanded: () =>
                            _toggleAnalyticsExpanded(analyticsExpanded),
                      ),
                      SizedBox(height: sectionGap),
                      _PurchaseOrdersFilterSection(
                        searchController: _searchController,
                        searchQuery: _searchQuery,
                        selectedFilter: _statusFilter,
                        allCount: purchaseOrders.length,
                        visibleCount: filteredPurchaseOrders.length,
                        onSearchChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        onClearSearch: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                        onFilterSelected: _selectStatusFilter,
                      ),
                      SizedBox(height: sectionGap),
                      if (filteredPurchaseOrders.isEmpty)
                        const _PurchaseOrdersFilteredEmptyState()
                      else
                        ...filteredPurchaseOrders.map(
                          (purchaseOrder) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PurchaseOrderCard(
                              purchaseOrder: purchaseOrder,
                              onTap: () =>
                                  _openPurchaseOrderDetails(purchaseOrder),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PurchaseOrdersSummarySection extends StatelessWidget {
  const _PurchaseOrdersSummarySection({required this.summary});

  final _PurchaseOrdersSummary summary;

  @override
  Widget build(BuildContext context) {
    const spacing = 12.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 1080
            ? 4
            : constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        final cardWidth = columnCount == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (spacing * (columnCount - 1))) /
                  columnCount;

        final cards = <_SummaryCardData>[
          _SummaryCardData(
            icon: Icons.folder_copy_outlined,
            label: 'Total Purchase Orders',
            value: '${summary.totalPurchaseOrders}',
            accentColor: const Color(0xFF0EA5E9),
          ),
          _SummaryCardData(
            icon: Icons.edit_note_outlined,
            label: 'Draft',
            value: '${summary.draftCount}',
            accentColor: const Color(0xFFF59E0B),
          ),
          _SummaryCardData(
            icon: Icons.pending_actions_outlined,
            label: 'Processing',
            value: '${summary.processingCount}',
            accentColor: const Color(0xFF6366F1),
          ),
          _SummaryCardData(
            icon: Icons.verified_outlined,
            label: 'Completed',
            value: '${summary.completedCount}',
            accentColor: const Color(0xFF10B981),
          ),
          _SummaryCardData(
            icon: Icons.calculate_outlined,
            label: 'Estimated Value',
            value: _formatIndianCurrency(summary.estimatedValue),
            accentColor: const Color(0xFF14B8A6),
          ),
          _SummaryCardData(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Allocated Value',
            value: _formatIndianCurrency(summary.allocatedValue),
            accentColor: const Color(0xFFF97316),
          ),
          _SummaryCardData(
            icon: Icons.payments_outlined,
            label: 'Actual Expenditure',
            value: _formatIndianCurrency(summary.actualExpenditure),
            accentColor: const Color(0xFFEF4444),
          ),
          _SummaryCardData(
            icon: Icons.south_west_rounded,
            label: 'Total Savings',
            value: _formatIndianCurrency(summary.totalSavings),
            accentColor: const Color(0xFF10B981),
          ),
          _SummaryCardData(
            icon: Icons.north_east_rounded,
            label: 'Additional Expenditure',
            value: _formatIndianCurrency(summary.additionalExpenditure),
            accentColor: const Color(0xFFF97316),
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map(
                (card) => SizedBox(
                  width: cardWidth,
                  child: _PurchaseOrderSummaryCard(data: card),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _PurchaseOrdersFilterSection extends StatelessWidget {
  const _PurchaseOrdersFilterSection({
    required this.searchController,
    required this.searchQuery,
    required this.selectedFilter,
    required this.allCount,
    required this.visibleCount,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onFilterSelected,
  });

  final TextEditingController searchController;
  final String searchQuery;
  final _PurchaseOrderStatusFilter selectedFilter;
  final int allCount;
  final int visibleCount;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<_PurchaseOrderStatusFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final filters = _PurchaseOrderStatusFilter.values;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search and filters',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText:
                  'Search folder number, institute PO, indent, title, fund, fund code, or vendor',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchQuery.trim().isEmpty
                  ? null
                  : IconButton(
                      onPressed: onClearSearch,
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Clear search',
                    ),
              filled: true,
              fillColor: palette.panelAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filters
                .map((filter) {
                  final isSelected = selectedFilter == filter;
                  return ChoiceChip(
                    label: Text(_statusFilterLabel(filter)),
                    selected: isSelected,
                    selectedColor: colorScheme.primary.withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? colorScheme.primary
                          : palette.mutedText,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.32)
                          : palette.border,
                    ),
                    backgroundColor: palette.panelAlt,
                    onSelected: (_) => onFilterSelected(filter),
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
          Text(
            allCount == visibleCount
                ? '$allCount ${allCount == 1 ? 'folder' : 'folders'} visible'
                : '$visibleCount of $allCount folders visible',
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 12.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseOrderCard extends StatelessWidget {
  const _PurchaseOrderCard({required this.purchaseOrder, required this.onTap});

  final PurchaseOrderModel purchaseOrder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final statusPalette = _purchaseOrderStatusPalette(
      context,
      purchaseOrder.status,
    );
    final displayNumber = purchaseOrder.displayNumber.trim();
    final folderNumber = purchaseOrder.folderNumber.trim();
    final showFolderNumber =
        displayNumber != folderNumber && folderNumber.isNotEmpty;
    final title = purchaseOrder.title?.trim() ?? '';
    final fundCode = purchaseOrder.fundCodeSnapshot?.trim() ?? '';
    final vendor = purchaseOrder.vendor?.trim() ?? '';
    final indentNumber = purchaseOrder.indentNumber?.trim() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayNumber.isEmpty
                              ? purchaseOrder.id
                              : displayNumber,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (showFolderNumber) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Folder: $folderNumber',
                            style: TextStyle(
                              color: palette.subtleText,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (title.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            title,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _PurchaseOrderStatusBadge(
                    label: _readableStatusLabel(purchaseOrder.status),
                    palette: statusPalette,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    label: 'Fund',
                    value: purchaseOrder.fundNameSnapshot,
                  ),
                  if (fundCode.isNotEmpty)
                    _InfoChip(label: 'Fund code', value: fundCode),
                  _InfoChip(
                    label: 'Orders',
                    value: '${purchaseOrder.orderCount}',
                  ),
                  _InfoChip(
                    label: 'Created',
                    value: _formatDateOrFallback(purchaseOrder.createdAt),
                  ),
                  if (indentNumber.isNotEmpty)
                    _InfoChip(label: 'Indent', value: indentNumber),
                  if (vendor.isNotEmpty)
                    _InfoChip(label: 'Vendor', value: vendor),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  _MetricLine(
                    label: 'Estimated total',
                    value: _formatIndianCurrency(purchaseOrder.estimatedTotal),
                  ),
                  _MetricLine(
                    label: 'Allocated total',
                    value: _formatIndianCurrency(purchaseOrder.allocatedTotal),
                  ),
                  if (purchaseOrder.hasActualCost)
                    _MetricLine(
                      label: 'Actual total',
                      value: _formatIndianCurrency(
                        purchaseOrder.actualTotal ?? 0.0,
                      ),
                    ),
                  if (purchaseOrder.hasActualCost &&
                      purchaseOrder.savingsAmount > 0)
                    _MetricLine(
                      label: 'Savings',
                      value: _formatIndianCurrency(purchaseOrder.savingsAmount),
                    ),
                  if (purchaseOrder.hasActualCost &&
                      purchaseOrder.additionalExpenditure > 0)
                    _MetricLine(
                      label: 'Additional expenditure',
                      value: _formatIndianCurrency(
                        purchaseOrder.additionalExpenditure,
                      ),
                    ),
                  if (purchaseOrder.hasActualCost &&
                      purchaseOrder.savingsAmount == 0 &&
                      purchaseOrder.additionalExpenditure == 0)
                    const _MetricLine(
                      label: 'Reconciliation',
                      value: 'Matched allocation',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseOrderDetailsSheet extends StatefulWidget {
  const _PurchaseOrderDetailsSheet({
    required this.purchaseOrder,
    required this.labId,
    required this.purchaseOrderService,
  });

  final PurchaseOrderModel purchaseOrder;
  final String labId;
  final PurchaseOrderService purchaseOrderService;

  @override
  State<_PurchaseOrderDetailsSheet> createState() =>
      _PurchaseOrderDetailsSheetState();
}

class _PurchaseOrderDetailsSheetState
    extends State<_PurchaseOrderDetailsSheet> {
  late Future<List<OrderModel>> _linkedOrdersFuture;
  late Stream<List<PurchaseOrderModel>> _purchaseOrdersStream;

  @override
  void initState() {
    super.initState();
    _linkedOrdersFuture = _loadLinkedOrders();
    _purchaseOrdersStream = _createPurchaseOrdersStream();
  }

  @override
  void didUpdateWidget(covariant _PurchaseOrderDetailsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.purchaseOrder.id != widget.purchaseOrder.id ||
        oldWidget.labId != widget.labId) {
      _linkedOrdersFuture = _loadLinkedOrders();
      _purchaseOrdersStream = _createPurchaseOrdersStream();
    }
  }

  Stream<List<PurchaseOrderModel>> _createPurchaseOrdersStream() {
    return widget.purchaseOrderService.streamPurchaseOrders(widget.labId);
  }

  Future<List<OrderModel>> _loadLinkedOrders() {
    return widget.purchaseOrderService.getPurchaseOrderOrders(
      labId: widget.labId,
      orderIds: widget.purchaseOrder.orderIds,
    );
  }

  void _retryLinkedOrders() {
    setState(() {
      _linkedOrdersFuture = _loadLinkedOrders();
    });
  }

  PurchaseOrderModel _resolvedPurchaseOrder(
    AsyncSnapshot<List<PurchaseOrderModel>> snapshot,
  ) {
    final purchaseOrders = snapshot.data;
    if (purchaseOrders != null) {
      for (final purchaseOrder in purchaseOrders) {
        if (purchaseOrder.id == widget.purchaseOrder.id) {
          return purchaseOrder;
        }
      }
    }

    return widget.purchaseOrder;
  }

  bool _canRecordActualPurchaseOrderCost(PurchaseOrderModel purchaseOrder) {
    if (!AppState.instance.isPiAdmin) {
      return false;
    }

    if (purchaseOrder.costReconciled) {
      return false;
    }

    final cleanTransactionId = purchaseOrder.fundTransactionId?.trim() ?? '';
    if (cleanTransactionId.isNotEmpty) {
      return false;
    }

    if (_normalizedStatus(purchaseOrder.status) == 'cancelled') {
      return false;
    }

    final cleanOrderIds = purchaseOrder.orderIds
        .map((orderId) => orderId.trim())
        .where((orderId) => orderId.isNotEmpty)
        .toList(growable: false);
    if (cleanOrderIds.isEmpty) {
      return false;
    }

    final allocatedTotal = purchaseOrder.allocatedTotal;
    return allocatedTotal.isFinite && allocatedTotal > 0;
  }

  String _resolveReconciledByIdentity() {
    final appState = AppState.instance;
    final userId = appState.authenticatedUserId.trim();
    if (userId.isNotEmpty) {
      return userId;
    }

    final userEmail = appState.authenticatedUserEmail.trim();
    if (userEmail.isNotEmpty) {
      return userEmail;
    }

    return '';
  }

  Future<void> _openRecordActualPurchaseOrderCostFlow(
    PurchaseOrderModel purchaseOrder,
  ) async {
    if (!_canRecordActualPurchaseOrderCost(purchaseOrder)) {
      return;
    }

    final isDesktopModal = MediaQuery.sizeOf(context).width >= 720;
    final userIdentity = _resolveReconciledByIdentity();
    final content = _RecordActualPurchaseOrderCostSheet(
      purchaseOrder: purchaseOrder,
      labId: widget.labId,
      userIdentity: userIdentity,
      purchaseOrderService: widget.purchaseOrderService,
    );

    final result = isDesktopModal
        ? await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: content,
                ),
              );
            },
          )
        : await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            enableDrag: false,
            isDismissible: false,
            backgroundColor: Colors.transparent,
            builder: (sheetContext) {
              return FractionallySizedBox(
                heightFactor: 0.96,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: content,
                ),
              );
            },
          );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Purchase Order cost recorded and fund reconciled successfully.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          child: StreamBuilder<List<PurchaseOrderModel>>(
            stream: _purchaseOrdersStream,
            builder: (context, purchaseOrderSnapshot) {
              final purchaseOrder = _resolvedPurchaseOrder(
                purchaseOrderSnapshot,
              );
              final statusPalette = _purchaseOrderStatusPalette(
                context,
                purchaseOrder.status,
              );

              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Purchase Order Details',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _PurchaseOrderStatusBadge(
                                label: _readableStatusLabel(
                                  purchaseOrder.status,
                                ),
                                palette: statusPalette,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Close',
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionCard(
                              title: purchaseOrder.displayNumber.trim().isEmpty
                                  ? purchaseOrder.id
                                  : purchaseOrder.displayNumber.trim(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _DetailLine(
                                    label: 'Folder number',
                                    value: purchaseOrder.folderNumber,
                                  ),
                                  _DetailLine(
                                    label: 'Institute PO number',
                                    value: purchaseOrder.institutePoNumber,
                                  ),
                                  _DetailLine(
                                    label: 'Title',
                                    value: purchaseOrder.title,
                                  ),
                                  _DetailLine(
                                    label: 'Status',
                                    value: _readableStatusLabel(
                                      purchaseOrder.status,
                                    ),
                                  ),
                                  _DetailLine(
                                    label: 'Fund',
                                    value: purchaseOrder.fundNameSnapshot,
                                  ),
                                  _DetailLine(
                                    label: 'Fund code',
                                    value: purchaseOrder.fundCodeSnapshot,
                                  ),
                                  _DetailLine(
                                    label: 'Created by',
                                    value: purchaseOrder.createdBy,
                                  ),
                                  _DetailLine(
                                    label: 'Created date',
                                    value: _formatDateTimeValue(
                                      purchaseOrder.createdAt,
                                    ),
                                  ),
                                  _DetailLine(
                                    label: 'Updated date',
                                    value: purchaseOrder.updatedAt == null
                                        ? null
                                        : _formatDateTimeValue(
                                            purchaseOrder.updatedAt,
                                          ),
                                  ),
                                  _DetailLine(
                                    label: 'Indent number',
                                    value: purchaseOrder.indentNumber,
                                  ),
                                  _DetailLine(
                                    label: 'Vendor',
                                    value: purchaseOrder.vendor,
                                  ),
                                  _DetailLine(
                                    label: 'Mode of purchase',
                                    value: purchaseOrder.modeOfPurchase,
                                  ),
                                  _DetailLine(
                                    label: 'Notes',
                                    value: purchaseOrder.notes,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _SectionCard(
                              title: 'Financial summary',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _DetailLine(
                                    label: 'Estimated total',
                                    value: _formatIndianCurrency(
                                      purchaseOrder.estimatedTotal,
                                    ),
                                  ),
                                  _DetailLine(
                                    label: 'Allocated total',
                                    value: _formatIndianCurrency(
                                      purchaseOrder.allocatedTotal,
                                    ),
                                  ),
                                  if (purchaseOrder.costReconciled) ...[
                                    const SizedBox(height: 12),
                                    _PurchaseOrderReconciliationSummary(
                                      purchaseOrder: purchaseOrder,
                                    ),
                                  ] else if (_canRecordActualPurchaseOrderCost(
                                    purchaseOrder,
                                  )) ...[
                                    const SizedBox(height: 12),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            _openRecordActualPurchaseOrderCostFlow(
                                              purchaseOrder,
                                            ),
                                        icon: const Icon(
                                          Icons.receipt_long_outlined,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Record Actual PO Cost',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _SectionCard(
                              title: 'Linked orders',
                              child: FutureBuilder<List<OrderModel>>(
                                future: _linkedOrdersFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                          ConnectionState.waiting &&
                                      !snapshot.hasData) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Text('Loading linked orders...'),
                                        ],
                                      ),
                                    );
                                  }

                                  if (snapshot.hasError) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Unable to load linked orders.',
                                          style: TextStyle(
                                            color: colorScheme.onSurface,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        OutlinedButton.icon(
                                          onPressed: _retryLinkedOrders,
                                          icon: const Icon(
                                            Icons.refresh_rounded,
                                            size: 18,
                                          ),
                                          label: const Text('Retry'),
                                        ),
                                      ],
                                    );
                                  }

                                  final orders =
                                      snapshot.data ?? const <OrderModel>[];
                                  if (orders.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Text('No linked orders found.'),
                                    );
                                  }

                                  final missingOrders =
                                      purchaseOrder.orderIds.length -
                                      orders.length;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (missingOrders > 0) ...[
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: Colors.amber.withValues(
                                                alpha: 0.38,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            'One or more linked orders could not be loaded.',
                                            style: TextStyle(
                                              color: colorScheme.onSurface,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                      ...orders.map(
                                        (order) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: _LinkedOrderCard(order: order),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LinkedOrderCard extends StatelessWidget {
  const _LinkedOrderCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  order.displayName,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _OrderStatusPill(status: order.status),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _InfoChip(
                label: 'Quantity',
                value: order.quantity.trim().isEmpty
                    ? '-'
                    : order.quantity.trim(),
              ),
              if (order.vendor.trim().isNotEmpty)
                _InfoChip(label: 'Vendor', value: order.vendor.trim()),
              if (order.estimatedTotal != null)
                _InfoChip(
                  label: 'Estimated',
                  value: _formatIndianCurrency(order.estimatedTotal ?? 0.0),
                ),
              if (order.allocatedAmount != null)
                _InfoChip(
                  label: 'Allocated',
                  value: _formatIndianCurrency(order.allocatedAmount ?? 0.0),
                ),
              _InfoChip(
                label: 'Ordered',
                value: _formatDate(order.orderedAt.toDate()),
              ),
              if (order.deliveredAt != null)
                _InfoChip(
                  label: 'Delivered',
                  value: _formatDate(order.deliveredAt!.toDate()),
                ),
              const _InfoChip(label: 'PO marker', value: 'PO linked'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PurchaseOrdersAnalyticsSection extends StatelessWidget {
  const _PurchaseOrdersAnalyticsSection({
    required this.analytics,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final _PurchaseOrderAnalytics analytics;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purchase Order Analytics',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Local analytics based on the full streamed Purchase Order list.',
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: 12.8,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: onToggleExpanded,
                icon: Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                ),
                label: Text(isExpanded ? 'Hide analytics' : 'Show analytics'),
              ),
            ],
          ),
          if (isExpanded) ...[
            if (analytics.earliestCreatedAt != null ||
                analytics.latestCreatedAt != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (analytics.earliestCreatedAt != null)
                    _InfoChip(
                      label: 'Earliest PO',
                      value: _formatDate(analytics.earliestCreatedAt!),
                    ),
                  if (analytics.latestCreatedAt != null)
                    _InfoChip(
                      label: 'Latest PO',
                      value: _formatDate(analytics.latestCreatedAt!),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final showSideBySide = constraints.maxWidth >= 900;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showSideBySide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _PurchaseOrderStatusOverviewCard(
                              overview: analytics.statusOverview,
                              totalPurchaseOrders:
                                  analytics.totalPurchaseOrders,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PurchaseOrderReconciliationOverviewCard(
                              overview: analytics.reconciliationOverview,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _PurchaseOrderStatusOverviewCard(
                        overview: analytics.statusOverview,
                        totalPurchaseOrders: analytics.totalPurchaseOrders,
                      ),
                      const SizedBox(height: 12),
                      _PurchaseOrderReconciliationOverviewCard(
                        overview: analytics.reconciliationOverview,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _PurchaseOrderFundAnalyticsCard(
                      groups: analytics.fundGroups,
                    ),
                    const SizedBox(height: 12),
                    _PurchaseOrderVendorAnalyticsCard(
                      groups: analytics.vendorGroups,
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _PurchaseOrderStatusOverviewCard extends StatelessWidget {
  const _PurchaseOrderStatusOverviewCard({
    required this.overview,
    required this.totalPurchaseOrders,
  });

  final _PurchaseOrderStatusOverview overview;
  final int totalPurchaseOrders;

  @override
  Widget build(BuildContext context) {
    final rows = <_StatusOverviewRowData>[
      _StatusOverviewRowData(
        label: 'Draft',
        count: overview.draftCount,
        palette: _purchaseOrderStatusPalette(context, 'draft'),
      ),
      _StatusOverviewRowData(
        label: 'Submitted',
        count: overview.submittedCount,
        palette: _purchaseOrderStatusPalette(context, 'submitted'),
      ),
      _StatusOverviewRowData(
        label: 'Processing',
        count: overview.processingCount,
        palette: _purchaseOrderStatusPalette(context, 'processing'),
      ),
      _StatusOverviewRowData(
        label: 'Completed',
        count: overview.completedCount,
        palette: _purchaseOrderStatusPalette(context, 'completed'),
      ),
      _StatusOverviewRowData(
        label: 'Cancelled',
        count: overview.cancelledCount,
        palette: _purchaseOrderStatusPalette(context, 'cancelled'),
      ),
      _StatusOverviewRowData(
        label: 'Other',
        count: overview.otherCount,
        palette: _purchaseOrderStatusPalette(context, ''),
      ),
    ];

    return _AnalyticsPanel(
      title: 'Status overview',
      subtitle: 'Full-stream workflow status counts',
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StatusOverviewRow(
                  data: row,
                  totalPurchaseOrders: totalPurchaseOrders,
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _PurchaseOrderReconciliationOverviewCard extends StatelessWidget {
  const _PurchaseOrderReconciliationOverviewCard({required this.overview});

  final _PurchaseOrderReconciliationOverview overview;

  @override
  Widget build(BuildContext context) {
    return _AnalyticsPanel(
      title: 'Reconciliation overview',
      subtitle: 'Read-only reconciliation totals',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _AnalyticsStatChip(
            label: 'Reconciled POs',
            value: '${overview.reconciledCount}',
          ),
          _AnalyticsStatChip(
            label: 'Unreconciled POs',
            value: '${overview.unreconciledCount}',
          ),
          _AnalyticsStatChip(
            label: 'Actual below allocation',
            value: '${overview.belowAllocationCount}',
          ),
          _AnalyticsStatChip(
            label: 'Actual above allocation',
            value: '${overview.aboveAllocationCount}',
          ),
          _AnalyticsStatChip(
            label: 'Exact matches',
            value: '${overview.exactMatchCount}',
          ),
        ],
      ),
    );
  }
}

class _PurchaseOrderFundAnalyticsCard extends StatelessWidget {
  const _PurchaseOrderFundAnalyticsCard({required this.groups});

  final List<_PurchaseOrderFundAnalyticsGroup> groups;

  @override
  Widget build(BuildContext context) {
    return _AnalyticsPanel(
      title: 'Fund-wise expenditure',
      subtitle: 'Grouped by allocated fund',
      child: groups.isEmpty
          ? const Text('No fund analytics available.')
          : Column(
              children: groups
                  .map(
                    (group) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PurchaseOrderFundAnalyticsTile(group: group),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _PurchaseOrderVendorAnalyticsCard extends StatelessWidget {
  const _PurchaseOrderVendorAnalyticsCard({required this.groups});

  final List<_PurchaseOrderVendorAnalyticsGroup> groups;

  @override
  Widget build(BuildContext context) {
    return _AnalyticsPanel(
      title: 'Vendor-wise expenditure',
      subtitle: 'Grouped by normalized vendor name',
      child: groups.isEmpty
          ? const Text('No vendor analytics available.')
          : Column(
              children: groups
                  .map(
                    (group) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PurchaseOrderVendorAnalyticsTile(group: group),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _AnalyticsPanel extends StatelessWidget {
  const _AnalyticsPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14.8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 12.4,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatusOverviewRowData {
  const _StatusOverviewRowData({
    required this.label,
    required this.count,
    required this.palette,
  });

  final String label;
  final int count;
  final _StatusPalette palette;
}

class _StatusOverviewRow extends StatelessWidget {
  const _StatusOverviewRow({
    required this.data,
    required this.totalPurchaseOrders,
  });

  final _StatusOverviewRowData data;
  final int totalPurchaseOrders;

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final progress = totalPurchaseOrders == 0
        ? 0.0
        : (data.count / totalPurchaseOrders).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                data.label,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 12.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${data.count}',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 12.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: progress,
            backgroundColor: palette.border,
            valueColor: AlwaysStoppedAnimation<Color>(data.palette.foreground),
          ),
        ),
      ],
    );
  }
}

class _AnalyticsStatChip extends StatelessWidget {
  const _AnalyticsStatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 11.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseOrderFundAnalyticsTile extends StatelessWidget {
  const _PurchaseOrderFundAnalyticsTile({required this.group});

  final _PurchaseOrderFundAnalyticsGroup group;

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.fundName,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14.4,
              fontWeight: FontWeight.w800,
            ),
          ),
          if ((group.fundCode ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Fund code: ${group.fundCode!.trim()}',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 12.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _InfoChip(label: 'PO count', value: '${group.poCount}'),
              _InfoChip(
                label: 'Allocated',
                value: _formatIndianCurrency(group.allocatedTotal),
              ),
              _InfoChip(
                label: 'Actual',
                value: _formatIndianCurrency(group.actualExpenditure),
              ),
              _InfoChip(
                label: 'Savings',
                value: _formatIndianCurrency(group.savings),
              ),
              _InfoChip(
                label: 'Additional',
                value: _formatIndianCurrency(group.additionalExpenditure),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PurchaseOrderVendorAnalyticsTile extends StatelessWidget {
  const _PurchaseOrderVendorAnalyticsTile({required this.group});

  final _PurchaseOrderVendorAnalyticsGroup group;

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.vendorLabel,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14.4,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _InfoChip(label: 'PO count', value: '${group.poCount}'),
              _InfoChip(
                label: 'Allocated',
                value: _formatIndianCurrency(group.allocatedTotal),
              ),
              _InfoChip(
                label: 'Actual',
                value: _formatIndianCurrency(group.actualExpenditure),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PurchaseOrderReconciliationSummary extends StatelessWidget {
  const _PurchaseOrderReconciliationSummary({required this.purchaseOrder});

  final PurchaseOrderModel purchaseOrder;

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_outlined, color: palette.success, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Purchase Order cost reconciled',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 13.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _DetailLine(
            label: 'Actual total',
            value: _formatIndianCurrency(purchaseOrder.actualTotal ?? 0.0),
          ),
          if (purchaseOrder.savingsAmount > 0)
            _DetailLine(
              label: 'Returned to fund',
              value: _formatIndianCurrency(purchaseOrder.savingsAmount),
            ),
          if (purchaseOrder.additionalExpenditure > 0)
            _DetailLine(
              label: 'Additional deduction',
              value: _formatIndianCurrency(purchaseOrder.additionalExpenditure),
            ),
          if (purchaseOrder.savingsAmount == 0 &&
              purchaseOrder.additionalExpenditure == 0)
            const _DetailLine(
              label: 'Adjustment result',
              value: 'Matched allocated total',
            ),
          _DetailLine(
            label: 'Reconciled by',
            value: purchaseOrder.costReconciledBy,
          ),
          _DetailLine(
            label: 'Reconciled at',
            value: _formatDateTimeValue(purchaseOrder.costReconciledAt),
          ),
        ],
      ),
    );
  }
}

class _RecordActualPurchaseOrderCostSheet extends StatefulWidget {
  const _RecordActualPurchaseOrderCostSheet({
    required this.purchaseOrder,
    required this.labId,
    required this.userIdentity,
    required this.purchaseOrderService,
  });

  final PurchaseOrderModel purchaseOrder;
  final String labId;
  final String userIdentity;
  final PurchaseOrderService purchaseOrderService;

  @override
  State<_RecordActualPurchaseOrderCostSheet> createState() =>
      _RecordActualPurchaseOrderCostSheetState();
}

class _RecordActualPurchaseOrderCostSheetState
    extends State<_RecordActualPurchaseOrderCostSheet> {
  late final TextEditingController _actualTotalController;
  bool _isSubmitting = false;
  String? _submissionError;

  bool get _hasUserIdentity => widget.userIdentity.trim().isNotEmpty;

  double? get _parsedActualTotal =>
      _parsePurchaseOrderActualTotalInput(_actualTotalController.text);

  double? get _previewDelta {
    final parsedActualTotal = _parsedActualTotal;
    if (parsedActualTotal == null) {
      return null;
    }

    return _roundCurrency(
      parsedActualTotal - widget.purchaseOrder.allocatedTotal,
    );
  }

  @override
  void initState() {
    super.initState();
    _actualTotalController = TextEditingController();
  }

  @override
  void dispose() {
    _actualTotalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_hasUserIdentity) {
      setState(() {
        _submissionError =
            'Unable to identify the user recording this Purchase Order cost.';
      });
      return;
    }

    final parsedActualTotal = _parsedActualTotal;
    if (parsedActualTotal == null || parsedActualTotal <= 0) {
      setState(() {
        _submissionError =
            'Enter a valid Purchase Order total greater than zero.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      await widget.purchaseOrderService.reconcilePurchaseOrderActualCost(
        purchaseOrderId: widget.purchaseOrder.id,
        labId: widget.labId,
        actualTotal: parsedActualTotal,
        reconciledBy: widget.userIdentity,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
        _submissionError = _friendlyPurchaseOrderReconciliationErrorMessage(
          error,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final canSubmit =
        !_isSubmitting && _hasUserIdentity && (_parsedActualTotal ?? 0) > 0;
    final displayNumber = widget.purchaseOrder.displayNumber.trim().isEmpty
        ? widget.purchaseOrder.id.trim()
        : widget.purchaseOrder.displayNumber.trim();
    final orderCount = widget.purchaseOrder.orderCount > 0
        ? widget.purchaseOrder.orderCount
        : widget.purchaseOrder.orderIds.length;
    final previewDelta = _previewDelta;

    return PopScope(
      canPop: !_isSubmitting,
      child: Container(
        decoration: BoxDecoration(
          color: palette.panel,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: palette.border),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.92,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Record Actual Purchase Order Cost',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'The final total will be reconciled against the allocated Purchase Order amount.',
                              style: TextStyle(
                                color: palette.mutedText,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(false),
                        tooltip: 'Close',
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: palette.panelAlt,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: palette.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayNumber.isEmpty ? '-' : displayNumber,
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _PurchaseOrderInfoLine(
                                  label: 'Folder number',
                                  value: widget.purchaseOrder.folderNumber,
                                ),
                                _PurchaseOrderInfoLine(
                                  label: 'Institute PO number',
                                  value: widget.purchaseOrder.institutePoNumber,
                                ),
                                _PurchaseOrderInfoLine(
                                  label: 'Fund',
                                  value: widget.purchaseOrder.fundNameSnapshot,
                                ),
                                _PurchaseOrderInfoLine(
                                  label: 'Fund code',
                                  value: widget.purchaseOrder.fundCodeSnapshot,
                                ),
                                _PurchaseOrderInfoLine(
                                  label: 'Order count',
                                  value: '$orderCount',
                                ),
                                _PurchaseOrderInfoLine(
                                  label: 'Estimated total',
                                  value: _formatIndianCurrency(
                                    widget.purchaseOrder.estimatedTotal,
                                  ),
                                ),
                                _PurchaseOrderInfoLine(
                                  label: 'Allocated total',
                                  value: _formatIndianCurrency(
                                    widget.purchaseOrder.allocatedTotal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _actualTotalController,
                            enabled: !_isSubmitting,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) {
                              if (_submissionError != null) {
                                setState(() {
                                  _submissionError = null;
                                });
                              } else {
                                setState(() {});
                              }
                            },
                            style: TextStyle(color: colorScheme.onSurface),
                            decoration: InputDecoration(
                              labelText: 'Actual Purchase Order total *',
                              helperText:
                                  'Enter the final total value from the institute Purchase Order or final purchase document.',
                              hintText: '\u20B927,500',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          if (previewDelta != null) ...[
                            const SizedBox(height: 12),
                            _InlineMessageCard(
                              title: 'Adjustment preview',
                              body: _purchaseOrderPreviewMessage(previewDelta),
                              tone: _InlineMessageTone.info,
                            ),
                          ],
                          const SizedBox(height: 12),
                          const _InlineMessageCard(
                            title:
                                'This action will finalize the Purchase Order expenditure and update the allocated fund automatically.',
                            body:
                                'This cannot be edited or submitted again in the current version.',
                            tone: _InlineMessageTone.warning,
                          ),
                          if (!_hasUserIdentity) ...[
                            const SizedBox(height: 12),
                            const _InlineMessageCard(
                              title:
                                  'Unable to identify the user recording this Purchase Order cost.',
                              tone: _InlineMessageTone.error,
                            ),
                          ],
                          if (_submissionError != null) ...[
                            const SizedBox(height: 12),
                            _InlineMessageCard(
                              title: _submissionError!,
                              tone: _InlineMessageTone.error,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: canSubmit ? _submit : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('Reconcile Purchase Order'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PurchaseOrderInfoLine extends StatelessWidget {
  const _PurchaseOrderInfoLine({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final cleanValue = value?.trim() ?? '';
    if (cleanValue.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = context.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '$label: $cleanValue',
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 12.9,
          height: 1.35,
        ),
      ),
    );
  }
}

enum _InlineMessageTone { info, warning, error }

class _InlineMessageCard extends StatelessWidget {
  const _InlineMessageCard({
    required this.title,
    required this.tone,
    this.body,
  });

  final String title;
  final String? body;
  final _InlineMessageTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    late final Color accentColor;
    late final IconData icon;

    if (tone == _InlineMessageTone.info) {
      accentColor = colorScheme.primary;
      icon = Icons.info_outline_rounded;
    } else if (tone == _InlineMessageTone.warning) {
      accentColor = const Color(0xFFF59E0B);
      icon = Icons.warning_amber_rounded;
    } else {
      accentColor = Colors.redAccent;
      icon = Icons.error_outline_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                if (body != null && body!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    body!,
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: 12.6,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseOrderSummaryCard extends StatelessWidget {
  const _PurchaseOrderSummaryCard({required this.data});

  final _SummaryCardData data;

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: data.accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: data.accentColor, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            data.label,
            style: TextStyle(
              color: palette.subtleText,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseOrderStatusBadge extends StatelessWidget {
  const _PurchaseOrderStatusBadge({required this.label, required this.palette});

  final String label;
  final _StatusPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OrderStatusPill extends StatelessWidget {
  const _OrderStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final normalizedStatus = _normalizedStatus(status);
    final accentColor = normalizedStatus == 'delivered'
        ? palette.success
        : context.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _readableStatusLabel(status),
        style: TextStyle(
          color: accentColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 12.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Text(
      '$label: $value',
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 12.9,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final cleanValue = value?.trim() ?? '';
    if (cleanValue.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = context.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '$label: $cleanValue',
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 12.9,
          height: 1.35,
        ),
      ),
    );
  }
}

class _PurchaseOrdersLoadingState extends StatelessWidget {
  const _PurchaseOrdersLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _PurchaseOrdersErrorState extends StatelessWidget {
  const _PurchaseOrdersErrorState({
    required this.detail,
    required this.onRetry,
  });

  final String? detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: palette.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_off_outlined,
                color: colorScheme.primary,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                'Unable to load Purchase Orders.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseOrdersEmptyState extends StatelessWidget {
  const _PurchaseOrdersEmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: palette.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_copy_outlined,
                color: colorScheme.primary,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                'No Purchase Order folders have been created yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
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

class _PurchaseOrdersFilteredEmptyState extends StatelessWidget {
  const _PurchaseOrdersFilteredEmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        'No Purchase Orders match the current search or filters.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: palette.mutedText,
          fontSize: 13.5,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PurchaseOrdersSummary {
  const _PurchaseOrdersSummary({
    required this.totalPurchaseOrders,
    required this.draftCount,
    required this.processingCount,
    required this.completedCount,
    required this.estimatedValue,
    required this.allocatedValue,
    required this.actualExpenditure,
    required this.totalSavings,
    required this.additionalExpenditure,
  });

  final int totalPurchaseOrders;
  final int draftCount;
  final int processingCount;
  final int completedCount;
  final double estimatedValue;
  final double allocatedValue;
  final double actualExpenditure;
  final double totalSavings;
  final double additionalExpenditure;

  factory _PurchaseOrdersSummary.fromPurchaseOrders(
    List<PurchaseOrderModel> purchaseOrders,
  ) {
    var draftCount = 0;
    var processingCount = 0;
    var completedCount = 0;

    for (final purchaseOrder in purchaseOrders) {
      final status = _normalizedStatus(purchaseOrder.status);
      if (status == 'draft') {
        draftCount++;
      } else if (status == 'processing') {
        processingCount++;
      } else if (status == 'completed') {
        completedCount++;
      }
    }

    return _PurchaseOrdersSummary(
      totalPurchaseOrders: purchaseOrders.length,
      draftCount: draftCount,
      processingCount: processingCount,
      completedCount: completedCount,
      estimatedValue: purchaseOrders.fold<double>(
        0,
        (sum, purchaseOrder) =>
            _roundCurrency(sum + _safeAmount(purchaseOrder.estimatedTotal)),
      ),
      allocatedValue: purchaseOrders.fold<double>(
        0,
        (sum, purchaseOrder) =>
            _roundCurrency(sum + _safeAmount(purchaseOrder.allocatedTotal)),
      ),
      actualExpenditure: purchaseOrders.fold<double>(
        0,
        (sum, purchaseOrder) =>
            _roundCurrency(sum + _safeAmount(purchaseOrder.actualTotal ?? 0.0)),
      ),
      totalSavings: purchaseOrders.fold<double>(
        0,
        (sum, purchaseOrder) =>
            _roundCurrency(sum + _safeAmount(purchaseOrder.savingsAmount)),
      ),
      additionalExpenditure: purchaseOrders.fold<double>(
        0,
        (sum, purchaseOrder) => _roundCurrency(
          sum + _safeAmount(purchaseOrder.additionalExpenditure),
        ),
      ),
    );
  }
}

class _PurchaseOrderAnalytics {
  const _PurchaseOrderAnalytics({
    required this.totalPurchaseOrders,
    required this.statusOverview,
    required this.fundGroups,
    required this.vendorGroups,
    required this.reconciliationOverview,
    required this.earliestCreatedAt,
    required this.latestCreatedAt,
  });

  final int totalPurchaseOrders;
  final _PurchaseOrderStatusOverview statusOverview;
  final List<_PurchaseOrderFundAnalyticsGroup> fundGroups;
  final List<_PurchaseOrderVendorAnalyticsGroup> vendorGroups;
  final _PurchaseOrderReconciliationOverview reconciliationOverview;
  final DateTime? earliestCreatedAt;
  final DateTime? latestCreatedAt;

  factory _PurchaseOrderAnalytics.fromPurchaseOrders(
    List<PurchaseOrderModel> purchaseOrders,
  ) {
    var draftCount = 0;
    var submittedCount = 0;
    var processingCount = 0;
    var completedCount = 0;
    var cancelledCount = 0;
    var otherCount = 0;

    var reconciledCount = 0;
    var unreconciledCount = 0;
    var belowAllocationCount = 0;
    var aboveAllocationCount = 0;
    var exactMatchCount = 0;

    final fundGroups = <String, _MutablePurchaseOrderFundAnalytics>{};
    final vendorGroups = <String, _MutablePurchaseOrderVendorAnalytics>{};
    DateTime? earliestCreatedAt;
    DateTime? latestCreatedAt;

    for (final purchaseOrder in purchaseOrders) {
      final normalizedStatus = _normalizedStatus(purchaseOrder.status);
      switch (normalizedStatus) {
        case 'draft':
          draftCount++;
          break;
        case 'submitted':
          submittedCount++;
          break;
        case 'processing':
          processingCount++;
          break;
        case 'completed':
          completedCount++;
          break;
        case 'cancelled':
          cancelledCount++;
          break;
        default:
          otherCount++;
          break;
      }

      if (purchaseOrder.costReconciled) {
        reconciledCount++;
        final normalizedDelta = _safeAmount(
          purchaseOrder.reconciledDeltaAmount ?? 0.0,
        );
        if (normalizedDelta > _analyticsDeltaTolerance) {
          aboveAllocationCount++;
        } else if (normalizedDelta < -_analyticsDeltaTolerance) {
          belowAllocationCount++;
        } else {
          exactMatchCount++;
        }
      } else {
        unreconciledCount++;
      }

      final fundGroupKey = _normalizedFundGroupKey(purchaseOrder.fundId);
      final currentFundName = purchaseOrder.fundNameSnapshot.trim();
      final currentFundCode = purchaseOrder.fundCodeSnapshot?.trim();
      final fundGroup = fundGroups.putIfAbsent(
        fundGroupKey,
        () => _MutablePurchaseOrderFundAnalytics(
          groupKey: fundGroupKey,
          fundName: currentFundName.isEmpty ? 'Unknown Fund' : currentFundName,
          fundCode: _normalizedOptionalAnalyticsString(currentFundCode),
        ),
      );
      fundGroup.absorb(purchaseOrder);

      final vendorGroupKey = _normalizedVendorGroupKey(purchaseOrder.vendor);
      final vendorGroup = vendorGroups.putIfAbsent(
        vendorGroupKey,
        () => _MutablePurchaseOrderVendorAnalytics(
          vendorKey: vendorGroupKey,
          vendorLabel: _vendorDisplayLabel(purchaseOrder.vendor),
        ),
      );
      vendorGroup.absorb(purchaseOrder);

      final createdAt = purchaseOrder.createdAt;
      if (createdAt != null) {
        if (earliestCreatedAt == null ||
            createdAt.isBefore(earliestCreatedAt)) {
          earliestCreatedAt = createdAt;
        }
        if (latestCreatedAt == null || createdAt.isAfter(latestCreatedAt)) {
          latestCreatedAt = createdAt;
        }
      }
    }

    final sortedFundGroups =
        fundGroups.values.map((group) => group.build()).toList(growable: false)
          ..sort((a, b) {
            final actualComparison = b.actualExpenditure.compareTo(
              a.actualExpenditure,
            );
            if (actualComparison != 0) {
              return actualComparison;
            }

            final allocatedComparison = b.allocatedTotal.compareTo(
              a.allocatedTotal,
            );
            if (allocatedComparison != 0) {
              return allocatedComparison;
            }

            return a.fundName.toLowerCase().compareTo(b.fundName.toLowerCase());
          });

    final sortedVendorGroups =
        vendorGroups.values
            .map((group) => group.build())
            .toList(growable: false)
          ..sort((a, b) {
            final actualComparison = b.actualExpenditure.compareTo(
              a.actualExpenditure,
            );
            if (actualComparison != 0) {
              return actualComparison;
            }

            return a.vendorLabel.toLowerCase().compareTo(
              b.vendorLabel.toLowerCase(),
            );
          });

    return _PurchaseOrderAnalytics(
      totalPurchaseOrders: purchaseOrders.length,
      statusOverview: _PurchaseOrderStatusOverview(
        draftCount: draftCount,
        submittedCount: submittedCount,
        processingCount: processingCount,
        completedCount: completedCount,
        cancelledCount: cancelledCount,
        otherCount: otherCount,
      ),
      fundGroups: sortedFundGroups,
      vendorGroups: sortedVendorGroups,
      reconciliationOverview: _PurchaseOrderReconciliationOverview(
        reconciledCount: reconciledCount,
        unreconciledCount: unreconciledCount,
        belowAllocationCount: belowAllocationCount,
        aboveAllocationCount: aboveAllocationCount,
        exactMatchCount: exactMatchCount,
      ),
      earliestCreatedAt: earliestCreatedAt,
      latestCreatedAt: latestCreatedAt,
    );
  }
}

class _PurchaseOrderStatusOverview {
  const _PurchaseOrderStatusOverview({
    required this.draftCount,
    required this.submittedCount,
    required this.processingCount,
    required this.completedCount,
    required this.cancelledCount,
    required this.otherCount,
  });

  final int draftCount;
  final int submittedCount;
  final int processingCount;
  final int completedCount;
  final int cancelledCount;
  final int otherCount;
}

class _PurchaseOrderReconciliationOverview {
  const _PurchaseOrderReconciliationOverview({
    required this.reconciledCount,
    required this.unreconciledCount,
    required this.belowAllocationCount,
    required this.aboveAllocationCount,
    required this.exactMatchCount,
  });

  final int reconciledCount;
  final int unreconciledCount;
  final int belowAllocationCount;
  final int aboveAllocationCount;
  final int exactMatchCount;
}

class _PurchaseOrderFundAnalyticsGroup {
  const _PurchaseOrderFundAnalyticsGroup({
    required this.groupKey,
    required this.fundName,
    required this.fundCode,
    required this.poCount,
    required this.allocatedTotal,
    required this.actualExpenditure,
    required this.savings,
    required this.additionalExpenditure,
  });

  final String groupKey;
  final String fundName;
  final String? fundCode;
  final int poCount;
  final double allocatedTotal;
  final double actualExpenditure;
  final double savings;
  final double additionalExpenditure;
}

class _PurchaseOrderVendorAnalyticsGroup {
  const _PurchaseOrderVendorAnalyticsGroup({
    required this.vendorKey,
    required this.vendorLabel,
    required this.poCount,
    required this.allocatedTotal,
    required this.actualExpenditure,
  });

  final String vendorKey;
  final String vendorLabel;
  final int poCount;
  final double allocatedTotal;
  final double actualExpenditure;
}

class _MutablePurchaseOrderFundAnalytics {
  _MutablePurchaseOrderFundAnalytics({
    required this.groupKey,
    required String fundName,
    required String? fundCode,
  }) : _fundName = fundName,
       _fundCode = fundCode;

  final String groupKey;
  String _fundName;
  String? _fundCode;
  int poCount = 0;
  double allocatedTotal = 0.0;
  double actualExpenditure = 0.0;
  double savings = 0.0;
  double additionalExpenditure = 0.0;

  void absorb(PurchaseOrderModel purchaseOrder) {
    final nextFundName = purchaseOrder.fundNameSnapshot.trim();
    if (_fundName == 'Unknown Fund' && nextFundName.isNotEmpty) {
      _fundName = nextFundName;
    }

    final nextFundCode = _normalizedOptionalAnalyticsString(
      purchaseOrder.fundCodeSnapshot,
    );
    _fundCode ??= nextFundCode;

    poCount++;
    allocatedTotal = _roundCurrency(
      allocatedTotal + _safeAmount(purchaseOrder.allocatedTotal),
    );
    actualExpenditure = _roundCurrency(
      actualExpenditure + _safeAmount(purchaseOrder.actualTotal ?? 0.0),
    );
    savings = _roundCurrency(
      savings + _safeAmount(purchaseOrder.savingsAmount),
    );
    additionalExpenditure = _roundCurrency(
      additionalExpenditure + _safeAmount(purchaseOrder.additionalExpenditure),
    );
  }

  _PurchaseOrderFundAnalyticsGroup build() {
    return _PurchaseOrderFundAnalyticsGroup(
      groupKey: groupKey,
      fundName: _fundName,
      fundCode: _fundCode,
      poCount: poCount,
      allocatedTotal: allocatedTotal,
      actualExpenditure: actualExpenditure,
      savings: savings,
      additionalExpenditure: additionalExpenditure,
    );
  }
}

class _MutablePurchaseOrderVendorAnalytics {
  _MutablePurchaseOrderVendorAnalytics({
    required this.vendorKey,
    required String vendorLabel,
  }) : _vendorLabel = vendorLabel;

  final String vendorKey;
  String _vendorLabel;
  int poCount = 0;
  double allocatedTotal = 0.0;
  double actualExpenditure = 0.0;

  void absorb(PurchaseOrderModel purchaseOrder) {
    final nextVendorLabel = _vendorDisplayLabel(purchaseOrder.vendor);
    if (_vendorLabel == 'Vendor not specified' &&
        nextVendorLabel != 'Vendor not specified') {
      _vendorLabel = nextVendorLabel;
    }

    poCount++;
    allocatedTotal = _roundCurrency(
      allocatedTotal + _safeAmount(purchaseOrder.allocatedTotal),
    );
    actualExpenditure = _roundCurrency(
      actualExpenditure + _safeAmount(purchaseOrder.actualTotal ?? 0.0),
    );
  }

  _PurchaseOrderVendorAnalyticsGroup build() {
    return _PurchaseOrderVendorAnalyticsGroup(
      vendorKey: vendorKey,
      vendorLabel: _vendorLabel,
      poCount: poCount,
      allocatedTotal: allocatedTotal,
      actualExpenditure: actualExpenditure,
    );
  }
}

class _SummaryCardData {
  const _SummaryCardData({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;
}

class _StatusPalette {
  const _StatusPalette({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}

_StatusPalette _purchaseOrderStatusPalette(
  BuildContext context,
  String status,
) {
  final normalizedStatus = _normalizedStatus(status);
  final colorScheme = context.colorScheme;
  final palette = context.labmate;

  switch (normalizedStatus) {
    case 'draft':
      return _StatusPalette(
        background: const Color(0xFFF59E0B).withValues(alpha: 0.14),
        border: const Color(0xFFF59E0B).withValues(alpha: 0.32),
        foreground: const Color(0xFFF59E0B),
      );
    case 'submitted':
      return _StatusPalette(
        background: colorScheme.primary.withValues(alpha: 0.12),
        border: colorScheme.primary.withValues(alpha: 0.24),
        foreground: colorScheme.primary,
      );
    case 'processing':
      return _StatusPalette(
        background: const Color(0xFF6366F1).withValues(alpha: 0.14),
        border: const Color(0xFF6366F1).withValues(alpha: 0.28),
        foreground: const Color(0xFF6366F1),
      );
    case 'completed':
      return _StatusPalette(
        background: palette.success.withValues(alpha: 0.12),
        border: palette.success.withValues(alpha: 0.24),
        foreground: palette.success,
      );
    case 'cancelled':
      return _StatusPalette(
        background: Colors.redAccent.withValues(alpha: 0.12),
        border: Colors.redAccent.withValues(alpha: 0.24),
        foreground: Colors.redAccent,
      );
    default:
      return _StatusPalette(
        background: palette.panelAlt,
        border: palette.border,
        foreground: context.colorScheme.onSurface,
      );
  }
}

String _statusFilterLabel(_PurchaseOrderStatusFilter filter) {
  switch (filter) {
    case _PurchaseOrderStatusFilter.all:
      return 'All';
    case _PurchaseOrderStatusFilter.draft:
      return 'Draft';
    case _PurchaseOrderStatusFilter.submitted:
      return 'Submitted';
    case _PurchaseOrderStatusFilter.processing:
      return 'Processing';
    case _PurchaseOrderStatusFilter.completed:
      return 'Completed';
    case _PurchaseOrderStatusFilter.cancelled:
      return 'Cancelled';
  }
}

String _normalizedStatus(String value) {
  return value.trim().toLowerCase();
}

String _readableStatusLabel(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return 'Unknown';
  }

  return normalized
      .toLowerCase()
      .split(RegExp(r'[\s_-]+'))
      .where((segment) => segment.isNotEmpty)
      .map((segment) => '${segment[0].toUpperCase()}${segment.substring(1)}')
      .join(' ');
}

const double _analyticsDeltaTolerance = 0.01;

String _normalizedFundGroupKey(String fundId) {
  final normalizedFundId = fundId.trim();
  if (normalizedFundId.isEmpty) {
    return '__unknown_fund__';
  }

  return normalizedFundId;
}

String _normalizedVendorGroupKey(String? vendor) {
  final normalizedVendor = vendor?.trim().toLowerCase() ?? '';
  if (normalizedVendor.isEmpty) {
    return '__vendor_not_specified__';
  }

  return normalizedVendor;
}

String _vendorDisplayLabel(String? vendor) {
  final normalizedVendor = vendor?.trim() ?? '';
  if (normalizedVendor.isEmpty) {
    return 'Vendor not specified';
  }

  return normalizedVendor;
}

String? _normalizedOptionalAnalyticsString(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return normalized;
}

double? _parsePurchaseOrderActualTotalInput(String input) {
  var normalized = input.trim();
  if (normalized.isEmpty) {
    return null;
  }

  normalized = normalized.replaceAll(',', '');
  normalized = normalized.replaceFirst(RegExp('^\u20B9\\s*'), '');

  final parsedValue = double.tryParse(normalized);
  if (parsedValue == null || !parsedValue.isFinite || parsedValue <= 0) {
    return null;
  }

  final roundedValue = _roundCurrency(parsedValue);
  if (!roundedValue.isFinite || roundedValue <= 0) {
    return null;
  }

  return roundedValue;
}

String _purchaseOrderPreviewMessage(double delta) {
  final normalizedDelta = _roundCurrency(delta);

  if (normalizedDelta > 0) {
    return 'Expected additional deduction: ${_formatIndianCurrency(normalizedDelta)}\n\nPreview only: the service will re-read current data transactionally before final reconciliation.';
  }

  if (normalizedDelta < 0) {
    return 'Expected refund to fund: ${_formatIndianCurrency(normalizedDelta.abs())}\n\nPreview only: the service will re-read current data transactionally before final reconciliation.';
  }

  return 'No fund balance adjustment expected.\n\nPreview only: the service will re-read current data transactionally before final reconciliation.';
}

double _safeAmount(double value) {
  if (!value.isFinite) {
    return 0;
  }

  if (value.abs() < 0.005) {
    return 0;
  }

  return value;
}

double _roundCurrency(double value) {
  return (value * 100).roundToDouble() / 100;
}

String _formatIndianCurrency(double value) {
  final normalizedValue = _safeAmount(value);
  if (!normalizedValue.isFinite) {
    return '\u20B90';
  }

  final isNegative = normalizedValue < 0;
  final absoluteValue = normalizedValue.abs();
  final fixed = absoluteValue.toStringAsFixed(2);
  final parts = fixed.split('.');
  final integerPart = parts.first;
  final rawDecimalPart = parts.length > 1 ? parts[1] : '';
  final decimalPart = rawDecimalPart.replaceFirst(RegExp(r'0+$'), '');
  final groupedInteger = _formatIndianDigits(integerPart);
  final sign = isNegative ? '-' : '';

  if (decimalPart.isEmpty) {
    return '$sign\u20B9$groupedInteger';
  }

  return '$sign\u20B9$groupedInteger.$decimalPart';
}

String _formatIndianDigits(String digits) {
  if (digits.length <= 3) {
    return digits;
  }

  final lastThree = digits.substring(digits.length - 3);
  var leading = digits.substring(0, digits.length - 3);
  final groups = <String>[];

  while (leading.length > 2) {
    groups.insert(0, leading.substring(leading.length - 2));
    leading = leading.substring(0, leading.length - 2);
  }

  if (leading.isNotEmpty) {
    groups.insert(0, leading);
  }

  return '${groups.join(',')},$lastThree';
}

String _formatDate(DateTime value) {
  const monthNames = [
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

  final day = value.day.toString().padLeft(2, '0');
  final month = monthNames[value.month - 1];
  final year = value.year.toString();
  return '$day $month $year';
}

String _formatDateOrFallback(DateTime? value) {
  if (value == null) {
    return 'Date unavailable';
  }

  return _formatDate(value);
}

String _formatDateTimeValue(DateTime? value) {
  if (value == null) {
    return '';
  }

  const monthNames = [
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

  final day = value.day.toString().padLeft(2, '0');
  final month = monthNames[value.month - 1];
  final year = value.year.toString();
  final hour24 = value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12Base = hour24 % 12;
  final hour12 = hour12Base == 0 ? 12 : hour12Base;

  return '$day $month $year, ${hour12.toString().padLeft(2, '0')}:$minute $period';
}

String _friendlyPurchaseOrderReconciliationErrorMessage(Object error) {
  if (FirestoreAccessGuard.isPermissionDenied(error)) {
    return 'Purchase Order reconciliation was blocked by Firebase permissions. The deployed Firestore rules may need updating.';
  }

  final raw = error.toString().trim();
  if (raw.startsWith('Invalid argument(s): ')) {
    final message = raw.substring('Invalid argument(s): '.length).trim();
    return message.isEmpty
        ? 'Unable to record Purchase Order actual cost.'
        : message;
  }

  if (raw.startsWith('Bad state: ')) {
    final message = raw.substring('Bad state: '.length).trim();
    return message.isEmpty
        ? 'Unable to record Purchase Order actual cost.'
        : message;
  }

  final cleaned = raw.replaceFirst('Exception: ', '').trim();
  return cleaned.isEmpty
      ? 'Unable to record Purchase Order actual cost.'
      : cleaned;
}
