import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/order_model.dart';
import '../services/activity_service.dart';
import '../services/firestore_access_guard.dart';
import '../services/fund_reconciliation_service.dart';
import '../services/order_service.dart';
import '../services/purchase_order_service.dart';
import '../theme/labmate_theme.dart';
import '../widgets/responsive_page_container.dart';

enum OrdersViewMode { compact, detailed }

enum OrdersSortOption { newestFirst, oldestFirst, status, type }

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const String _allFilterValue = 'All';
  static const int _purchaseOrderSelectionLimit = 50;
  final OrderService orderService = OrderService();
  final FundReconciliationService _fundReconciliationService =
      FundReconciliationService();
  final PurchaseOrderService _purchaseOrderService = PurchaseOrderService();

  OrdersViewMode _viewMode = OrdersViewMode.compact;
  OrdersSortOption _sortOption = OrdersSortOption.newestFirst;
  String _selectedBrand = _allFilterValue;
  String _selectedVendor = _allFilterValue;
  String _selectedOrderedBy = _allFilterValue;
  String _selectedModeOfPurchase = _allFilterValue;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _filtersExpanded = false;
  bool _purchaseOrderSelectionMode = false;
  final Set<String> _selectedOrderIds = <String>{};
  final Set<String> _deliveringOrderIds = <String>{};
  String? _selectedFundId;
  String _lastSeenLabId = '';

  String get _currentUserName => AppState.instance.authenticatedUserName;

  String get _activeLabId => AppState.instance.selectedLabId.trim();

  String _resolvePurchaseOrderCreatorIdentity() {
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

  bool _isEligiblePurchaseOrderStatus(OrderModel order) {
    final normalizedStatus = order.status.trim().toLowerCase();
    return normalizedStatus == 'ordered' || normalizedStatus == 'delivered';
  }

  bool _hasValidPurchaseOrderAllocation(OrderModel order) {
    final cleanFundId = order.fundId?.trim() ?? '';
    final cleanFundTransactionId = order.fundTransactionId?.trim() ?? '';
    final allocatedAmount = order.allocatedAmount;

    return cleanFundId.isNotEmpty &&
        cleanFundTransactionId.isNotEmpty &&
        allocatedAmount != null &&
        allocatedAmount.isFinite &&
        allocatedAmount > 0;
  }

  bool _isEligibleForPurchaseOrder(OrderModel order) {
    final cleanFundAdjustmentTransactionId =
        order.fundAdjustmentTransactionId?.trim() ?? '';

    return order.labId.trim() == _activeLabId &&
        _isEligiblePurchaseOrderStatus(order) &&
        _hasValidPurchaseOrderAllocation(order) &&
        !order.isAssignedToPurchaseOrder &&
        !order.costReconciled &&
        cleanFundAdjustmentTransactionId.isEmpty;
  }

  bool _matchesSelectedFund(OrderModel order) {
    final selectedFundId = _selectedFundId?.trim() ?? '';
    if (selectedFundId.isEmpty) {
      return true;
    }

    return (order.fundId?.trim() ?? '') == selectedFundId;
  }

  String? _purchaseOrderSelectionBlockReason(OrderModel order) {
    if (order.labId.trim() != _activeLabId) {
      return 'This order does not belong to the active lab.';
    }

    if (order.isAssignedToPurchaseOrder) {
      final label = order.purchaseOrderDisplayLabel.trim();
      return label.isEmpty
          ? 'This order already belongs to a Purchase Order.'
          : 'This order already belongs to Purchase Order $label.';
    }

    final cleanFundAdjustmentTransactionId =
        order.fundAdjustmentTransactionId?.trim() ?? '';
    if (order.costReconciled || cleanFundAdjustmentTransactionId.isNotEmpty) {
      return 'Cost already reconciled individually';
    }

    if (!_hasValidPurchaseOrderAllocation(order)) {
      return 'No valid fund allocation found on this order or its linked requirement.';
    }

    if (!_isEligiblePurchaseOrderStatus(order)) {
      return 'Only ordered or delivered orders are eligible for a Purchase Order.';
    }

    final selectedFundId = _selectedFundId?.trim() ?? '';
    final cleanFundId = order.fundId?.trim() ?? '';
    if (selectedFundId.isNotEmpty && cleanFundId != selectedFundId) {
      return 'A Purchase Order can contain orders allocated from only one fund.';
    }

    return null;
  }

  String? _purchaseOrderSelectionHint(OrderModel order) {
    if (order.isAssignedToPurchaseOrder) {
      return null;
    }

    final cleanFundAdjustmentTransactionId =
        order.fundAdjustmentTransactionId?.trim() ?? '';
    if (order.costReconciled || cleanFundAdjustmentTransactionId.isNotEmpty) {
      return 'Cost already reconciled individually';
    }

    if (!_hasValidPurchaseOrderAllocation(order)) {
      return 'No valid fund allocation found on this order or its linked requirement.';
    }

    if (!_isEligiblePurchaseOrderStatus(order)) {
      return 'Only ordered or delivered orders are eligible';
    }

    final selectedFundId = _selectedFundId?.trim() ?? '';
    final cleanFundId = order.fundId?.trim() ?? '';
    if (selectedFundId.isNotEmpty && cleanFundId != selectedFundId) {
      return 'Different fund selected';
    }

    return null;
  }

  void _resetPurchaseOrderSelectionState({bool exitSelectionMode = true}) {
    _selectedOrderIds.clear();
    _selectedFundId = null;
    if (exitSelectionMode) {
      _purchaseOrderSelectionMode = false;
    }
  }

  void _clearPurchaseOrderSelection({bool exitSelectionMode = true}) {
    setState(() {
      _resetPurchaseOrderSelectionState(exitSelectionMode: exitSelectionMode);
    });
  }

  void _showPurchaseOrderSelectionMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _syncPurchaseOrderSelectionState(List<OrderModel> allOrders) {
    final activeLabId = _activeLabId;
    if (_lastSeenLabId != activeLabId) {
      _lastSeenLabId = activeLabId;
      _resetPurchaseOrderSelectionState();
      return;
    }

    if (_selectedOrderIds.isEmpty) {
      _selectedFundId = null;
      return;
    }

    final orderById = <String, OrderModel>{
      for (final order in allOrders) order.id.trim(): order,
    };

    _selectedOrderIds.removeWhere((orderId) {
      final order = orderById[orderId];
      return order == null || !_isEligibleForPurchaseOrder(order);
    });

    if (_selectedOrderIds.isEmpty) {
      _selectedFundId = null;
      return;
    }

    String? nextFundId;
    for (final orderId in _selectedOrderIds) {
      final cleanFundId = orderById[orderId]?.fundId?.trim() ?? '';
      if (cleanFundId.isNotEmpty) {
        nextFundId = cleanFundId;
        break;
      }
    }

    if (nextFundId == null) {
      _resetPurchaseOrderSelectionState(exitSelectionMode: false);
      return;
    }

    _selectedFundId = nextFundId;
    _selectedOrderIds.removeWhere(
      (orderId) => (orderById[orderId]?.fundId?.trim() ?? '') != nextFundId,
    );

    if (_selectedOrderIds.isEmpty) {
      _selectedFundId = null;
    }
  }

  void _enterPurchaseOrderSelectionMode() {
    setState(() {
      _purchaseOrderSelectionMode = true;
    });
  }

  List<OrderModel> _selectedOrdersFrom(List<OrderModel> allOrders) {
    final selectedIds = _selectedOrderIds;
    if (selectedIds.isEmpty) {
      return const <OrderModel>[];
    }

    return allOrders
        .where((order) => selectedIds.contains(order.id.trim()))
        .toList(growable: false);
  }

  _PurchaseOrderSelectionSummary _buildPurchaseOrderSelectionSummary(
    List<OrderModel> selectedOrders,
  ) {
    double estimatedTotal = 0;
    double allocatedTotal = 0;
    String fundName = '';
    String? fundCode;

    for (final order in selectedOrders) {
      final estimated = order.estimatedTotal;
      if (estimated != null && estimated.isFinite && estimated > 0) {
        estimatedTotal = _roundCurrency(estimatedTotal + estimated);
      }

      final allocated = order.allocatedAmount;
      if (allocated != null && allocated.isFinite && allocated > 0) {
        allocatedTotal = _roundCurrency(allocatedTotal + allocated);
      }

      if (fundName.isEmpty) {
        fundName = order.fundNameSnapshot?.trim() ?? '';
      }
      fundCode ??= _normalizedOptionalText(order.fundCodeSnapshot);
    }

    return _PurchaseOrderSelectionSummary(
      orderCount: selectedOrders.length,
      fundName: fundName.isEmpty ? 'Fund' : fundName,
      fundCode: fundCode,
      estimatedTotal: estimatedTotal,
      allocatedTotal: allocatedTotal,
    );
  }

  String? _normalizedOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  Color _statusColor(BuildContext context, String status) {
    final palette = context.labmate;
    switch (status.toLowerCase()) {
      case 'delivered':
        return palette.success;
      default:
        return context.colorScheme.primary;
    }
  }

  String _statusText(OrderModel order) {
    return order.status.toLowerCase() == 'delivered' ? 'Delivered' : 'Ordered';
  }

  int _statusSortWeight(String status) {
    switch (status.toLowerCase()) {
      case 'ordered':
        return 0;
      case 'delivered':
        return 1;
      default:
        return 2;
    }
  }

  String _sortLabel(OrdersSortOption option) {
    switch (option) {
      case OrdersSortOption.newestFirst:
        return 'Newest first';
      case OrdersSortOption.oldestFirst:
        return 'Oldest first';
      case OrdersSortOption.status:
        return 'Status';
      case OrdersSortOption.type:
        return 'Type';
    }
  }

  String _formatShortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String _formatOrderedNote(OrderModel order) {
    final date = order.orderedAt.toDate();
    return 'Ordered on ${_formatShortDate(date)} by ${order.orderedBy}';
  }

  String _formatDeliveredNote(OrderModel order) {
    if (order.deliveredAt == null) return '';
    final date = order.deliveredAt!.toDate();
    return 'Delivered on ${_formatShortDate(date)} received by ${order.receivedBy}';
  }

  List<OrderModel> _sortOrders(List<OrderModel> input) {
    final list = [...input];

    list.sort((a, b) {
      switch (_sortOption) {
        case OrdersSortOption.newestFirst:
          return b.orderedAt.compareTo(a.orderedAt);

        case OrdersSortOption.oldestFirst:
          return a.orderedAt.compareTo(b.orderedAt);

        case OrdersSortOption.status:
          final statusComparison = _statusSortWeight(
            a.status,
          ).compareTo(_statusSortWeight(b.status));
          if (statusComparison != 0) {
            return statusComparison;
          }
          return b.orderedAt.compareTo(a.orderedAt);

        case OrdersSortOption.type:
          final typeComparison = a.typeLabel.toLowerCase().compareTo(
            b.typeLabel.toLowerCase(),
          );
          if (typeComparison != 0) {
            return typeComparison;
          }
          return b.orderedAt.compareTo(a.orderedAt);
      }
    });

    return list;
  }

  List<String> _filterOptions(
    List<OrderModel> orders,
    String Function(OrderModel order) selector,
  ) {
    final values =
        orders
            .map((order) => selector(order).trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return [_allFilterValue, ...values];
  }

  bool _matchesTextFilter(String value, String selectedValue) {
    return selectedValue == _allFilterValue || value.trim() == selectedValue;
  }

  bool _matchesDateRange(OrderModel order) {
    final orderedDate = order.orderedAt.toDate();
    final orderedDay = DateTime(
      orderedDate.year,
      orderedDate.month,
      orderedDate.day,
    );

    if (_startDate != null) {
      final startDay = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
      );
      if (orderedDay.isBefore(startDay)) {
        return false;
      }
    }

    if (_endDate != null) {
      final endDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
      if (orderedDay.isAfter(endDay)) {
        return false;
      }
    }

    return true;
  }

  List<OrderModel> _applyFilters(List<OrderModel> orders) {
    return orders.where((order) {
      return _matchesTextFilter(order.brand, _selectedBrand) &&
          _matchesTextFilter(order.vendor, _selectedVendor) &&
          _matchesTextFilter(order.orderedBy, _selectedOrderedBy) &&
          _matchesTextFilter(order.modeOfPurchase, _selectedModeOfPurchase) &&
          _matchesDateRange(order);
    }).toList();
  }

  bool get _hasActiveFilters {
    return _selectedBrand != _allFilterValue ||
        _selectedVendor != _allFilterValue ||
        _selectedOrderedBy != _allFilterValue ||
        _selectedModeOfPurchase != _allFilterValue ||
        _startDate != null ||
        _endDate != null;
  }

  int get _activeFilterCount {
    var count = 0;
    if (_selectedBrand != _allFilterValue) count++;
    if (_selectedVendor != _allFilterValue) count++;
    if (_selectedOrderedBy != _allFilterValue) count++;
    if (_selectedModeOfPurchase != _allFilterValue) count++;
    if (_startDate != null) count++;
    if (_endDate != null) count++;
    return count;
  }

  Future<void> _pickFilterDate({required bool isStartDate}) async {
    final now = DateTime.now();
    final initialDate = isStartDate
        ? (_startDate ?? _endDate ?? now)
        : (_endDate ?? _startDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(data: ThemeData.dark(), child: child!);
      },
    );

    if (picked == null) {
      return;
    }

    setState(() {
      if (isStartDate) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
        if (_startDate != null && _startDate!.isAfter(picked)) {
          _startDate = picked;
        }
      }
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedBrand = _allFilterValue;
      _selectedVendor = _allFilterValue;
      _selectedOrderedBy = _allFilterValue;
      _selectedModeOfPurchase = _allFilterValue;
      _startDate = null;
      _endDate = null;
    });
  }

  Future<bool> _markDelivered(OrderModel order) async {
    if (_deliveringOrderIds.contains(order.id)) {
      return false;
    }

    if (mounted) {
      setState(() {
        _deliveringOrderIds.add(order.id);
      });
    }

    try {
      await orderService.updateOrderStatus(
        docId: order.id,
        status: 'delivered',
        receivedBy: _currentUserName,
      );

      try {
        await ActivityService().addActivity(
          labId: AppState.instance.resolveWriteLabId(order.labId),
          type: 'order_delivered',
          message: 'Order delivered for ${order.displayName}',
          actorName: _currentUserName,
          createdBy: AppState.instance.authenticatedUserId,
          relatedId: order.id,
        );
      } catch (error) {
        debugPrint('Failed to record delivery activity: $error');
      }
    } finally {
      if (mounted && _deliveringOrderIds.contains(order.id)) {
        setState(() {
          _deliveringOrderIds.remove(order.id);
        });
      }
    }

    return true;
  }

  bool _canRecordActualCost(OrderModel order) {
    final cleanTransactionId = order.fundAdjustmentTransactionId?.trim() ?? '';
    return AppState.instance.isPiAdmin &&
        order.status.trim().toLowerCase() == 'delivered' &&
        !order.costReconciled &&
        cleanTransactionId.isEmpty &&
        !order.isCostManagedThroughPurchaseOrder;
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

  Future<void> _openRecordActualCostFlow(OrderModel order) async {
    if (order.isCostManagedThroughPurchaseOrder) {
      final purchaseOrderLabel = order.purchaseOrderDisplayLabel.trim();
      final message = purchaseOrderLabel.isEmpty
          ? 'Actual cost for this order must be recorded through its Purchase Order.'
          : 'Actual cost for this order must be recorded through Purchase Order $purchaseOrderLabel.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final isDesktopModal = MediaQuery.sizeOf(context).width >= 720;
    final userIdentity = _resolveReconciledByIdentity();

    final content = _RecordActualCostSheet(
      order: order,
      userIdentity: userIdentity,
      fundReconciliationService: _fundReconciliationService,
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
                  constraints: const BoxConstraints(maxWidth: 620),
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
                heightFactor: 0.94,
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
            'Actual cost recorded and fund reconciled successfully.',
          ),
        ),
      );
    }
  }

  void _handlePurchaseOrderCardTap(OrderModel order) {
    final orderId = order.id.trim();
    if (orderId.isEmpty) {
      _showPurchaseOrderSelectionMessage(
        'One or more selected order IDs are invalid.',
      );
      return;
    }

    final isSelected = _selectedOrderIds.contains(orderId);
    if (isSelected) {
      setState(() {
        _selectedOrderIds.remove(orderId);
        if (_selectedOrderIds.isEmpty) {
          _selectedFundId = null;
        }
      });
      return;
    }

    final blockReason = _purchaseOrderSelectionBlockReason(order);
    if (blockReason != null) {
      if (_selectedFundId?.trim().isNotEmpty == true &&
          (order.fundId?.trim() ?? '') != _selectedFundId?.trim() &&
          _isEligiblePurchaseOrderStatus(order) &&
          _hasValidPurchaseOrderAllocation(order) &&
          !order.isAssignedToPurchaseOrder &&
          !order.costReconciled &&
          (order.fundAdjustmentTransactionId?.trim() ?? '').isEmpty) {
        _showPurchaseOrderSelectionMessage(
          'These orders cannot be grouped.\n\nA Purchase Order can contain orders allocated from only one fund.',
        );
        return;
      }

      _showPurchaseOrderSelectionMessage(blockReason);
      return;
    }

    if (_selectedOrderIds.length >= _purchaseOrderSelectionLimit) {
      _showPurchaseOrderSelectionMessage(
        'A Purchase Order can contain at most $_purchaseOrderSelectionLimit orders.',
      );
      return;
    }

    setState(() {
      _selectedOrderIds.add(orderId);
      _selectedFundId ??= order.fundId?.trim();
    });
  }

  Future<void> _openCreatePurchaseOrderFlow(
    List<OrderModel> selectedOrders,
  ) async {
    if (selectedOrders.isEmpty) {
      return;
    }

    final activeLabId = _activeLabId;
    final userIdentity = _resolvePurchaseOrderCreatorIdentity();
    final isDesktopModal = MediaQuery.sizeOf(context).width >= 720;
    final summary = _buildPurchaseOrderSelectionSummary(selectedOrders);
    final content = _CreatePurchaseOrderSheet(
      activeLabId: activeLabId,
      selectedOrders: selectedOrders,
      userIdentity: userIdentity,
      summary: summary,
      purchaseOrderService: _purchaseOrderService,
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
      _clearPurchaseOrderSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purchase Order folder created successfully.'),
        ),
      );
    }
  }

  Future<void> _openLegacyOrderRepairFlow() async {
    final result = await showDialog<OrderFinancialBackfillResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _LegacyOrderFundRepairDialog(orderService: orderService);
      },
    );

    if (result == null || !mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Order repair completed.'),
          content: Text(
            'Scanned: ${result.scanned}\n'
            'Updated: ${result.updated}\n'
            'Already complete/skipped: ${result.skipped}\n'
            'Unresolved: ${result.unresolved}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildViewToggle() {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    Widget buildSegment({required OrdersViewMode mode, required String label}) {
      final isSelected = _viewMode == mode;

      return Expanded(
        child: Material(
          color: isSelected ? palette.selected : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              if (isSelected) return;
              setState(() {
                _viewMode = mode;
              });
            },
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? colorScheme.primary : palette.mutedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: palette.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            buildSegment(mode: OrdersViewMode.compact, label: 'Compact'),
            const SizedBox(width: 6),
            buildSegment(mode: OrdersViewMode.detailed, label: 'Detailed'),
          ],
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return SizedBox(
      height: 40,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: palette.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<OrdersSortOption>(
            value: _sortOption,
            dropdownColor: palette.panel,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 12.8,
              fontWeight: FontWeight.w600,
            ),
            icon: Icon(
              Icons.swap_vert_rounded,
              color: palette.mutedText,
              size: 17,
            ),
            isExpanded: true,
            items: OrdersSortOption.values.map((option) {
              return DropdownMenuItem<OrdersSortOption>(
                value: option,
                child: Text(
                  _sortLabel(option),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _sortOption = value;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    final safeValue = options.contains(value) ? value : _allFilterValue;
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          dropdownColor: palette.panel,
          style: TextStyle(color: colorScheme.onSurface, fontSize: 12.8),
          isExpanded: true,
          items: options.map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(
                option == _allFilterValue ? '$label: All' : option,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 12.6),
              ),
            );
          }).toList(),
          onChanged: (selected) {
            if (selected == null) return;
            onChanged(selected);
          },
        ),
      ),
    );
  }

  Widget _buildDateFilterButton({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: palette.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value == null ? label : '$label: ${_formatShortDate(value)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: 12.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.calendar_today_rounded,
              color: colorScheme.primary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetFiltersButton({required bool fullWidth}) {
    final palette = context.labmate;

    final button = OutlinedButton.icon(
      onPressed: _hasActiveFilters ? _resetFilters : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        side: BorderSide(color: palette.border),
        foregroundColor: palette.mutedText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.filter_alt_off_rounded, size: 17),
      label: const Text(
        'Reset Filters',
        style: TextStyle(fontSize: 12.4, fontWeight: FontWeight.w700),
      ),
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }

  Widget _buildFilterToggleButton({required bool isExpanded}) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final isActive = _hasActiveFilters || isExpanded;

    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _filtersExpanded = !_filtersExpanded;
          });
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          backgroundColor: isActive
              ? colorScheme.primary.withValues(alpha: 0.08)
              : palette.panel,
          foregroundColor: isActive ? colorScheme.primary : palette.mutedText,
          side: BorderSide(
            color: isActive
                ? colorScheme.primary.withValues(alpha: 0.28)
                : palette.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isExpanded
                  ? Icons.filter_list_off_rounded
                  : Icons.filter_list_rounded,
              size: 17,
            ),
            const SizedBox(width: 8),
            const Text(
              'Filters',
              style: TextStyle(fontSize: 12.6, fontWeight: FontWeight.w700),
            ),
            if (_activeFilterCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$_activeFilterCount',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseOrderSelectionEntryButton() {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: _enterPurchaseOrderSelectionMode,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          backgroundColor: palette.panel,
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.playlist_add_check_outlined, size: 18),
        label: const Text(
          'Select for PO',
          style: TextStyle(fontSize: 12.6, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildLegacyOrderRepairButton() {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: _openLegacyOrderRepairFlow,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          backgroundColor: palette.panel,
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.build_circle_outlined, size: 18),
        label: const Text(
          'Repair legacy order fund data',
          style: TextStyle(fontSize: 12.6, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildPurchaseOrderSelectionToolbar({
    required bool isDesktop,
    required List<OrderModel> selectedOrders,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final summary = _buildPurchaseOrderSelectionSummary(selectedOrders);
    final hasSelection = selectedOrders.isNotEmpty;

    final actionRow = isDesktop
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () => _clearPurchaseOrderSelection(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: hasSelection
                    ? () => _openCreatePurchaseOrderFlow(selectedOrders)
                    : null,
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: const Text('Create PO Folder'),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton(
                onPressed: () => _clearPurchaseOrderSelection(),
                child: const Text('Cancel'),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: hasSelection
                    ? () => _openCreatePurchaseOrderFlow(selectedOrders)
                    : null,
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: const Text('Create PO Folder'),
              ),
            ],
          );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected: ${selectedOrders.length}',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasSelection
                            ? 'Selected fund: ${summary.fundName}'
                            : 'Selected fund: Choose an eligible order to lock a fund',
                        style: TextStyle(
                          color: palette.mutedText,
                          fontSize: 12.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if ((summary.fundCode ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Fund code: ${summary.fundCode}',
                          style: TextStyle(
                            color: palette.mutedText,
                            fontSize: 12.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                actionRow,
              ],
            )
          else ...[
            Text(
              'Selected: ${selectedOrders.length}',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasSelection
                  ? 'Selected fund: ${summary.fundName}'
                  : 'Selected fund: Choose an eligible order to lock a fund',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 12.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            if ((summary.fundCode ?? '').isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                'Fund code: ${summary.fundCode}',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: 12.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            actionRow,
          ],
          if (!hasSelection) ...[
            const SizedBox(height: 10),
            Text(
              'Select one or more eligible orders to create a Purchase Order folder.',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 12.6,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterToolbar({
    required bool isDesktop,
    required List<OrderModel> allOrders,
  }) {
    final brandOptions = _filterOptions(allOrders, (order) => order.brand);
    final vendorOptions = _filterOptions(allOrders, (order) => order.vendor);
    final orderedByOptions = _filterOptions(
      allOrders,
      (order) => order.orderedBy,
    );
    final modeOptions = _filterOptions(
      allOrders,
      (order) => order.modeOfPurchase,
    );

    final controls = <Widget>[
      SizedBox(
        width: isDesktop ? 180 : double.infinity,
        child: _buildFilterDropdown(
          label: 'Brand',
          value: _selectedBrand,
          options: brandOptions,
          onChanged: (value) {
            setState(() {
              _selectedBrand = value;
            });
          },
        ),
      ),
      SizedBox(
        width: isDesktop ? 180 : double.infinity,
        child: _buildFilterDropdown(
          label: 'Vendor',
          value: _selectedVendor,
          options: vendorOptions,
          onChanged: (value) {
            setState(() {
              _selectedVendor = value;
            });
          },
        ),
      ),
      SizedBox(
        width: isDesktop ? 190 : double.infinity,
        child: _buildFilterDropdown(
          label: 'Ordered by',
          value: _selectedOrderedBy,
          options: orderedByOptions,
          onChanged: (value) {
            setState(() {
              _selectedOrderedBy = value;
            });
          },
        ),
      ),
      SizedBox(
        width: isDesktop ? 170 : double.infinity,
        child: _buildFilterDropdown(
          label: 'Mode',
          value: _selectedModeOfPurchase,
          options: modeOptions,
          onChanged: (value) {
            setState(() {
              _selectedModeOfPurchase = value;
            });
          },
        ),
      ),
      SizedBox(
        width: isDesktop ? 168 : double.infinity,
        child: _buildDateFilterButton(
          label: 'Start date',
          value: _startDate,
          onTap: () => _pickFilterDate(isStartDate: true),
        ),
      ),
      SizedBox(
        width: isDesktop ? 168 : double.infinity,
        child: _buildDateFilterButton(
          label: 'End date',
          value: _endDate,
          onTap: () => _pickFilterDate(isStartDate: false),
        ),
      ),
    ];

    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int index = 0; index < controls.length; index++) ...[
            controls[index],
            if (index != controls.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          _buildResetFiltersButton(fullWidth: true),
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [...controls, _buildResetFiltersButton(fullWidth: false)],
    );
  }

  Widget _buildControlsCard({
    required int filteredCount,
    required int totalCount,
    required List<OrderModel> allOrders,
    required List<OrderModel> selectedOrders,
    required bool isDesktop,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final orderCountText = _hasActiveFilters
        ? '$filteredCount of $totalCount orders'
        : '$totalCount ${totalCount == 1 ? 'order' : 'orders'}';
    final showFilters = _filtersExpanded;

    return Container(
      margin: EdgeInsets.fromLTRB(12, isDesktop ? 2 : 4, 12, 6),
      padding: EdgeInsets.fromLTRB(12, 10, 12, showFilters ? 10 : 8),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    orderCountText,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  runSpacing: 8,
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(width: 188, child: _buildViewToggle()),
                    SizedBox(width: 180, child: _buildSortDropdown()),
                    _buildFilterToggleButton(isExpanded: showFilters),
                    if (AppState.instance.isPiAdmin)
                      _buildLegacyOrderRepairButton(),
                    if (!_purchaseOrderSelectionMode)
                      _buildPurchaseOrderSelectionEntryButton(),
                  ],
                ),
              ],
            )
          else ...[
            Text(
              orderCountText,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(width: 188, child: _buildViewToggle()),
                SizedBox(width: 180, child: _buildSortDropdown()),
                _buildFilterToggleButton(isExpanded: showFilters),
                if (AppState.instance.isPiAdmin)
                  _buildLegacyOrderRepairButton(),
                if (!_purchaseOrderSelectionMode)
                  _buildPurchaseOrderSelectionEntryButton(),
              ],
            ),
          ],
          if (_purchaseOrderSelectionMode)
            _buildPurchaseOrderSelectionToolbar(
              isDesktop: isDesktop,
              selectedOrders: selectedOrders,
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: showFilters
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 1,
                          color: palette.border.withValues(alpha: 0.42),
                        ),
                        const SizedBox(height: 8),
                        _buildFilterToolbar(
                          isDesktop: isDesktop,
                          allOrders: allOrders,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(OrderModel order) {
    final isConsumable = order.isConsumable;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isConsumable ? const Color(0x2238BDF8) : const Color(0x2214B8A6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        order.typeLabel,
        style: TextStyle(
          color: isConsumable
              ? const Color(0xFF38BDF8)
              : const Color(0xFF14B8A6),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(OrderModel order) {
    final color = _statusColor(context, order.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _statusText(order),
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildDeliveredAction({
    required BuildContext context,
    required OrderModel order,
  }) {
    final isDelivered = order.status.toLowerCase() == 'delivered';
    if (isDelivered) {
      return const SizedBox.shrink();
    }
    final isDelivering = _deliveringOrderIds.contains(order.id);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isDelivering
            ? null
            : () async {
                try {
                  final didMarkDelivered = await _markDelivered(order);
                  if (!didMarkDelivered) {
                    return;
                  }

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Order marked as delivered')),
                  );
                } catch (error) {
                  debugPrint('Failed to mark order as delivered: $error');
                  if (!context.mounted) return;
                  final message = error is OrderDeliveryException
                      ? error.message
                      : 'Failed to mark order as delivered. Please try again.';
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        child: Text(isDelivering ? 'Marking...' : 'Mark as Delivered'),
      ),
    );
  }

  Widget? _buildDeliveredOrderSupplement({
    required BuildContext context,
    required OrderModel order,
  }) {
    if (order.costReconciled) {
      return _ReconciledCostSummary(order: order);
    }

    if (order.isCostManagedThroughPurchaseOrder) {
      return _PurchaseOrderManagedCostPanel(order: order);
    }

    if (!_canRecordActualCost(order)) {
      return null;
    }

    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return OutlinedButton.icon(
      onPressed: () => _openRecordActualCostFlow(order),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        foregroundColor: colorScheme.primary,
        side: BorderSide(color: palette.border),
        backgroundColor: palette.panelAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.receipt_long_outlined, size: 18),
      label: const Text(
        'Record Actual Cost',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget? _buildOrderFinancialSummary({
    required BuildContext context,
    required OrderModel order,
    bool isCompact = false,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final fundName = order.fundNameSnapshot?.trim() ?? '';
    final fundCode = order.fundCodeSnapshot?.trim() ?? '';
    final estimatedTotal = order.estimatedTotal;
    final allocatedAmount = order.allocatedAmount;
    final hasFinancialContext =
        estimatedTotal != null ||
        allocatedAmount != null ||
        fundName.isNotEmpty ||
        fundCode.isNotEmpty;

    if (!hasFinancialContext) {
      return null;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 12,
        vertical: isCompact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (estimatedTotal != null)
            Text(
              'Estimated total: ${_formatIndianCurrency(estimatedTotal)}',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: isCompact ? 12.3 : 12.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (estimatedTotal != null && allocatedAmount != null)
            const SizedBox(height: 4),
          if (allocatedAmount != null)
            Text(
              'Allocated: ${_formatIndianCurrency(allocatedAmount)}',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: isCompact ? 12.3 : 12.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          if ((estimatedTotal != null || allocatedAmount != null) &&
              (fundName.isNotEmpty || fundCode.isNotEmpty))
            const SizedBox(height: 6),
          if (fundName.isNotEmpty)
            Text(
              'Fund: $fundName',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: isCompact ? 12 : 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (fundName.isNotEmpty && fundCode.isNotEmpty)
            const SizedBox(height: 3),
          if (fundCode.isNotEmpty)
            Text(
              'Fund code: $fundCode',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: isCompact ? 12 : 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget? _buildPurchaseOrderStatusSection({
    required BuildContext context,
    required OrderModel order,
    bool isCompact = false,
  }) {
    final isSelected = _selectedOrderIds.contains(order.id.trim());
    final isAssigned = order.isAssignedToPurchaseOrder;
    final canToggleSelection =
        _isEligibleForPurchaseOrder(order) &&
        (_matchesSelectedFund(order) || isSelected);
    final selectionHint = _purchaseOrderSelectionHint(order);
    final showSelectionControl = _purchaseOrderSelectionMode;
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final selectedFundMismatch =
        _selectedFundId?.trim().isNotEmpty == true &&
        !isSelected &&
        !_matchesSelectedFund(order) &&
        _hasValidPurchaseOrderAllocation(order) &&
        _isEligiblePurchaseOrderStatus(order) &&
        !order.isAssignedToPurchaseOrder &&
        !order.costReconciled &&
        (order.fundAdjustmentTransactionId?.trim() ?? '').isEmpty;

    if (!showSelectionControl && !isAssigned) {
      return null;
    }

    final badgeBackground = isAssigned
        ? palette.success.withValues(alpha: 0.12)
        : (isSelected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : palette.panelAlt);
    final badgeBorderColor = isAssigned
        ? palette.success.withValues(alpha: 0.4)
        : (isSelected
              ? colorScheme.primary.withValues(alpha: 0.32)
              : palette.border);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 12,
        vertical: isCompact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: badgeBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSelectionControl)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AbsorbPointer(
                  child: Checkbox(
                    value: isSelected,
                    onChanged: canToggleSelection ? (_) {} : null,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(
                      horizontal: -4,
                      vertical: -4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSelected
                            ? 'Selected for Purchase Order'
                            : isAssigned
                            ? 'PO Created'
                            : 'Select for Purchase Order',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: isCompact ? 12.5 : 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (isAssigned) ...[
                        const SizedBox(height: 3),
                        Text(
                          'PO: ${order.purchaseOrderDisplayLabel.trim().isEmpty ? '-' : order.purchaseOrderDisplayLabel.trim()}',
                          style: TextStyle(
                            color: palette.mutedText,
                            fontSize: isCompact ? 12 : 12.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else if (selectionHint != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          selectedFundMismatch
                              ? 'A Purchase Order can contain orders allocated from only one fund.'
                              : selectionHint,
                          style: TextStyle(
                            color: palette.mutedText,
                            fontSize: isCompact ? 12 : 12.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  size: 17,
                  color: palette.success,
                ),
                const SizedBox(width: 8),
                Text(
                  'PO Created',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: isCompact ? 12.5 : 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'PO: ${order.purchaseOrderDisplayLabel.trim().isEmpty ? '-' : order.purchaseOrderDisplayLabel.trim()}',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: isCompact ? 12 : 12.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderCardShell({
    required BuildContext context,
    required OrderModel order,
    required Widget child,
    required BorderRadius borderRadius,
  }) {
    if (!_purchaseOrderSelectionMode) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () => _handlePurchaseOrderCardTap(order),
        child: child,
      ),
    );
  }

  Widget _buildCompactCard({
    required BuildContext context,
    required OrderModel order,
  }) {
    final isDelivered = order.status.toLowerCase() == 'delivered';
    final isSelected = _selectedOrderIds.contains(order.id.trim());
    final actionArea = _buildDeliveredAction(context: context, order: order);
    final purchaseOrderSection = _buildPurchaseOrderStatusSection(
      context: context,
      order: order,
      isCompact: true,
    );
    final financialSummary = _buildOrderFinancialSummary(
      context: context,
      order: order,
      isCompact: true,
    );
    final deliveredSupplement = isDelivered
        ? _buildDeliveredOrderSupplement(context: context, order: order)
        : null;
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    const cardRadius = BorderRadius.all(Radius.circular(14));

    return _buildOrderCardShell(
      context: context,
      order: order,
      borderRadius: cardRadius,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.06)
              : palette.panel,
          borderRadius: cardRadius,
          border: Border.all(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.36)
                : palette.border,
            width: isSelected ? 1.4 : 1,
          ),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _buildTypeBadge(order),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: palette.panelAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text(
                    'Qty: ${order.quantity.isEmpty ? "-" : order.quantity}',
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _buildStatusBadge(order),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: palette.panelAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text(
                    'Ordered: ${_formatShortDate(order.orderedAt.toDate())}',
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (purchaseOrderSection != null) ...[
              const SizedBox(height: 10),
              purchaseOrderSection,
            ],
            if (financialSummary != null) ...[
              const SizedBox(height: 10),
              financialSummary,
            ],
            if (!isDelivered) ...[const SizedBox(height: 12), actionArea],
            if (isDelivered && deliveredSupplement != null) ...[
              const SizedBox(height: 12),
              deliveredSupplement,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedCard({
    required BuildContext context,
    required OrderModel order,
  }) {
    final isDelivered = order.status.toLowerCase() == 'delivered';
    final isSelected = _selectedOrderIds.contains(order.id.trim());
    final purchaseOrderSection = _buildPurchaseOrderStatusSection(
      context: context,
      order: order,
    );
    final financialSummary = _buildOrderFinancialSummary(
      context: context,
      order: order,
    );
    final deliveredSupplement = isDelivered
        ? _buildDeliveredOrderSupplement(context: context, order: order)
        : null;
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    const cardRadius = BorderRadius.all(Radius.circular(18));

    return _buildOrderCardShell(
      context: context,
      order: order,
      borderRadius: cardRadius,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.06)
              : palette.panel,
          borderRadius: cardRadius,
          boxShadow: Theme.of(context).brightness == Brightness.dark
              ? const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
          border: Border.all(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.36)
                : palette.border,
            width: isSelected ? 1.4 : 1,
          ),
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
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _buildTypeBadge(order),
              ],
            ),
            const SizedBox(height: 8),
            if (order.isChemical && order.cas.trim().isNotEmpty) ...[
              Text(
                'CAS: ${order.cas}',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (order.packSize.trim().isNotEmpty) ...[
              Text(
                'Pack Size: ${order.packSize}',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (order.brand.trim().isNotEmpty) ...[
              Text(
                'Brand: ${order.brand}',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (order.vendor.trim().isNotEmpty) ...[
              Text(
                'Vendor: ${order.vendor}',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              'Quantity: ${order.quantity.isEmpty ? "-" : order.quantity}',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (order.modeOfPurchase.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Mode: ${order.modeOfPurchase}',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (purchaseOrderSection != null) ...[
              const SizedBox(height: 10),
              purchaseOrderSection,
            ],
            if (financialSummary != null) ...[
              const SizedBox(height: 10),
              financialSummary,
            ],
            const SizedBox(height: 8),
            Text(
              _formatOrderedNote(order),
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isDelivered) ...[
              const SizedBox(height: 6),
              Text(
                _formatDeliveredNote(order),
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 8),
            _buildStatusBadge(order),
            if (isDelivered && deliveredSupplement != null) ...[
              const SizedBox(height: 12),
              deliveredSupplement,
            ],
            if (!isDelivered) ...[
              const SizedBox(height: 12),
              _buildDeliveredAction(context: context, order: order),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
                Icons.local_shipping_outlined,
                color: colorScheme.primary,
                size: 30,
              ),
              const SizedBox(height: 12),
              Text(
                'No orders yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Approved requirements will appear here after they are placed as orders.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilteredEmptyState() {
    final palette = context.labmate;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: palette.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
          ),
          child: Text(
            'No orders match current filters.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _resetPurchaseOrderSelectionState();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeLabId = _activeLabId;
    if (_lastSeenLabId != activeLabId) {
      _lastSeenLabId = activeLabId;
      _resetPurchaseOrderSelectionState();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: ResponsivePageContainer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            return StreamBuilder<List<OrderModel>>(
              stream: orderService.getOrders(),
              builder: (context, snapshot) {
                if (!FirestoreAccessGuard.shouldQueryLabScopedData()) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        FirestoreAccessGuard.userMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.labmate.mutedText,
                          height: 1.4,
                        ),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        FirestoreAccessGuard.messageFor(snapshot.error),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.labmate.mutedText,
                          height: 1.4,
                        ),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allOrders = snapshot.data!;
                _syncPurchaseOrderSelectionState(allOrders);
                final selectedOrders = _selectedOrdersFrom(allOrders);
                final filteredOrders = _applyFilters(allOrders);
                final orders = _sortOrders(filteredOrders);

                if (allOrders.isEmpty) {
                  return _buildEmptyState();
                }

                return Column(
                  children: [
                    _buildControlsCard(
                      filteredCount: orders.length,
                      totalCount: allOrders.length,
                      allOrders: allOrders,
                      selectedOrders: selectedOrders,
                      isDesktop: isDesktop,
                    ),
                    Expanded(
                      child: orders.isEmpty
                          ? _buildFilteredEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              itemCount: orders.length,
                              itemBuilder: (context, index) {
                                final order = orders[index];

                                if (_viewMode == OrdersViewMode.compact) {
                                  return _buildCompactCard(
                                    context: context,
                                    order: order,
                                  );
                                }

                                return _buildDetailedCard(
                                  context: context,
                                  order: order,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ReconciledCostSummary extends StatelessWidget {
  const _ReconciledCostSummary({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final actualTotal = order.actualTotal;
    final deltaText = _buildReconciliationDeltaText(
      order.reconciliationDifference,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_outlined, size: 18, color: palette.success),
              const SizedBox(width: 8),
              Text(
                'Cost reconciled',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 13.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            actualTotal == null
                ? 'Actual total: Not available'
                : 'Actual total: ${_formatIndianCurrency(actualTotal)}',
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 12.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (deltaText != null) ...[
            const SizedBox(height: 4),
            Text(
              deltaText,
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 12.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PurchaseOrderManagedCostPanel extends StatelessWidget {
  const _PurchaseOrderManagedCostPanel({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final purchaseOrderLabel = order.purchaseOrderDisplayLabel.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_copy_outlined,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Cost managed through Purchase Order',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 13.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (purchaseOrderLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'PO: $purchaseOrderLabel',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 12.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordActualCostSheet extends StatefulWidget {
  const _RecordActualCostSheet({
    required this.order,
    required this.userIdentity,
    required this.fundReconciliationService,
  });

  final OrderModel order;
  final String userIdentity;
  final FundReconciliationService fundReconciliationService;

  @override
  State<_RecordActualCostSheet> createState() => _RecordActualCostSheetState();
}

class _RecordActualCostSheetState extends State<_RecordActualCostSheet> {
  late final TextEditingController _actualTotalController;
  bool _isSubmitting = false;
  String? _submissionError;

  bool get _hasUserIdentity => widget.userIdentity.trim().isNotEmpty;

  double? get _parsedActualTotal =>
      _parseActualTotalInput(_actualTotalController.text);

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
        _submissionError = 'Unable to identify the user recording this cost.';
      });
      return;
    }

    final parsedActualTotal = _parsedActualTotal;
    if (parsedActualTotal == null || parsedActualTotal <= 0) {
      setState(() {
        _submissionError = 'Enter a valid actual total greater than zero.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      await widget.fundReconciliationService.reconcileOrderActualCost(
        orderId: widget.order.id,
        labId: widget.order.labId,
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
        _submissionError = _friendlyReconciliationErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final canSubmit =
        !_isSubmitting && _hasUserIdentity && (_parsedActualTotal ?? 0) > 0;

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
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
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
                              'Record Actual Cost',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'The final cost will be reconciled against the amount allocated during requirement approval.',
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
                                  widget.order.displayName,
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _OrderInfoLine(
                                  label: 'Order ID',
                                  value: widget.order.id.trim().isEmpty
                                      ? '-'
                                      : widget.order.id.trim(),
                                ),
                                _OrderInfoLine(
                                  label: 'Vendor',
                                  value: widget.order.vendor.trim().isEmpty
                                      ? '-'
                                      : widget.order.vendor.trim(),
                                ),
                                _OrderInfoLine(
                                  label: 'Quantity',
                                  value: widget.order.quantity.trim().isEmpty
                                      ? '-'
                                      : widget.order.quantity.trim(),
                                ),
                                _OrderInfoLine(
                                  label: 'Delivered date',
                                  value: widget.order.deliveredAt == null
                                      ? 'Date unavailable'
                                      : _formatShortDateValue(
                                          widget.order.deliveredAt!.toDate(),
                                        ),
                                ),
                                _OrderInfoLine(
                                  label: 'Status',
                                  value: _readableOrderStatus(
                                    widget.order.status,
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
                              labelText: 'Actual total *',
                              helperText:
                                  'Enter the final total purchase cost, including any applicable tax or delivery charges.',
                              hintText: '\u20B98,500',
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
                          if (!_hasUserIdentity) ...[
                            const SizedBox(height: 12),
                            _InlineMessageCard(
                              title:
                                  'Unable to identify the user recording this cost.',
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
                              : const Text('Reconcile Cost'),
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

class _LegacyOrderFundRepairDialog extends StatefulWidget {
  const _LegacyOrderFundRepairDialog({required this.orderService});

  final OrderService orderService;

  @override
  State<_LegacyOrderFundRepairDialog> createState() =>
      _LegacyOrderFundRepairDialogState();
}

class _LegacyOrderFundRepairDialogState
    extends State<_LegacyOrderFundRepairDialog> {
  bool _isSubmitting = false;
  String? _submissionError;

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      final result = await widget.orderService.backfillOrderFinancialSnapshots(
        labId: AppState.instance.selectedLabId,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
        _submissionError = _friendlyOrderRepairErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: AlertDialog(
        title: const Text('Repair legacy order fund data?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will copy missing estimated-cost and fund-allocation snapshots from linked requirements into older orders. Existing order values will not be overwritten.',
              ),
              if (_isSubmitting) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
                const SizedBox(height: 10),
                const Text('Running repair...'),
              ],
              if (_submissionError != null) ...[
                const SizedBox(height: 14),
                _InlineMessageCard(
                  title: _submissionError!,
                  tone: _InlineMessageTone.error,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Run Repair'),
          ),
        ],
      ),
    );
  }
}

class _CreatePurchaseOrderSheet extends StatefulWidget {
  const _CreatePurchaseOrderSheet({
    required this.activeLabId,
    required this.selectedOrders,
    required this.userIdentity,
    required this.summary,
    required this.purchaseOrderService,
  });

  final String activeLabId;
  final List<OrderModel> selectedOrders;
  final String userIdentity;
  final _PurchaseOrderSelectionSummary summary;
  final PurchaseOrderService purchaseOrderService;

  @override
  State<_CreatePurchaseOrderSheet> createState() =>
      _CreatePurchaseOrderSheetState();
}

class _CreatePurchaseOrderSheetState extends State<_CreatePurchaseOrderSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _indentNumberController;
  late final TextEditingController _institutePoNumberController;
  late final TextEditingController _vendorController;
  late final TextEditingController _modeOfPurchaseController;
  late final TextEditingController _notesController;

  bool _isSubmitting = false;
  String? _submissionError;

  bool get _hasUserIdentity => widget.userIdentity.trim().isNotEmpty;

  bool get _hasSelectedOrders => widget.selectedOrders.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _indentNumberController = TextEditingController();
    _institutePoNumberController = TextEditingController();
    _vendorController = TextEditingController();
    _modeOfPurchaseController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _indentNumberController.dispose();
    _institutePoNumberController.dispose();
    _vendorController.dispose();
    _modeOfPurchaseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_hasSelectedOrders) {
      setState(() {
        _submissionError = 'Select at least one order.';
      });
      return;
    }

    if (!_hasUserIdentity) {
      setState(() {
        _submissionError =
            'Unable to identify the user creating this Purchase Order.';
      });
      return;
    }

    final selectedOrderIds = widget.selectedOrders
        .map((order) => order.id.trim())
        .where((orderId) => orderId.isNotEmpty)
        .toList(growable: false);
    if (selectedOrderIds.isEmpty) {
      setState(() {
        _submissionError = 'Select at least one order.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      await widget.purchaseOrderService.createPurchaseOrder(
        labId: widget.activeLabId,
        orderIds: selectedOrderIds,
        createdBy: widget.userIdentity,
        title: _titleController.text,
        indentNumber: _indentNumberController.text,
        institutePoNumber: _institutePoNumberController.text,
        vendor: _vendorController.text,
        modeOfPurchase: _modeOfPurchaseController.text,
        notes: _notesController.text,
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
        _submissionError = _friendlyPurchaseOrderErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final canSubmit = !_isSubmitting && _hasSelectedOrders && _hasUserIdentity;
    final summary = widget.summary;

    Widget buildTextField({
      required TextEditingController controller,
      required String label,
      String? hintText,
      int maxLines = 1,
    }) {
      return TextField(
        controller: controller,
        enabled: !_isSubmitting,
        maxLines: maxLines,
        onChanged: (_) {
          if (_submissionError != null) {
            setState(() {
              _submissionError = null;
            });
          }
        },
        style: TextStyle(color: colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.primary),
          ),
        ),
      );
    }

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
                              'Create Purchase Order Folder',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Group the selected orders into one draft Purchase Order folder. Vendor and mode of purchase are plain text fields in this first version.',
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
                                  'Selection summary',
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _OrderInfoLine(
                                  label: 'Selected orders',
                                  value: '${summary.orderCount}',
                                ),
                                _OrderInfoLine(
                                  label: 'Selected fund',
                                  value: summary.fundName,
                                ),
                                if ((summary.fundCode ?? '').isNotEmpty)
                                  _OrderInfoLine(
                                    label: 'Fund code',
                                    value: summary.fundCode!,
                                  ),
                                _OrderInfoLine(
                                  label: 'Estimated total',
                                  value: _formatIndianCurrency(
                                    summary.estimatedTotal,
                                  ),
                                ),
                                _OrderInfoLine(
                                  label: 'Allocated total',
                                  value: _formatIndianCurrency(
                                    summary.allocatedTotal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          buildTextField(
                            controller: _titleController,
                            label: 'Title',
                            hintText: 'Optional folder title',
                          ),
                          const SizedBox(height: 12),
                          buildTextField(
                            controller: _indentNumberController,
                            label: 'Indent number',
                          ),
                          const SizedBox(height: 12),
                          buildTextField(
                            controller: _institutePoNumberController,
                            label: 'Institute PO number',
                          ),
                          const SizedBox(height: 12),
                          buildTextField(
                            controller: _vendorController,
                            label: 'Vendor',
                            hintText: 'Optional plain text vendor',
                          ),
                          const SizedBox(height: 12),
                          buildTextField(
                            controller: _modeOfPurchaseController,
                            label: 'Mode of purchase',
                            hintText: 'Optional plain text mode',
                          ),
                          const SizedBox(height: 12),
                          buildTextField(
                            controller: _notesController,
                            label: 'Notes',
                            maxLines: 4,
                          ),
                          if (!_hasUserIdentity) ...[
                            const SizedBox(height: 12),
                            const _InlineMessageCard(
                              title:
                                  'Unable to identify the user creating this Purchase Order.',
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
                        child: ElevatedButton.icon(
                          onPressed: canSubmit ? _submit : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          icon: _isSubmitting
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
                              : const Icon(
                                  Icons.create_new_folder_outlined,
                                  size: 18,
                                ),
                          label: Text(
                            _isSubmitting ? 'Creating...' : 'Create PO Folder',
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
      ),
    );
  }
}

class _PurchaseOrderSelectionSummary {
  const _PurchaseOrderSelectionSummary({
    required this.orderCount,
    required this.fundName,
    required this.fundCode,
    required this.estimatedTotal,
    required this.allocatedTotal,
  });

  final int orderCount;
  final String fundName;
  final String? fundCode;
  final double estimatedTotal;
  final double allocatedTotal;
}

class _OrderInfoLine extends StatelessWidget {
  const _OrderInfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 12.9,
          height: 1.35,
        ),
      ),
    );
  }
}

enum _InlineMessageTone { error }

class _InlineMessageCard extends StatelessWidget {
  const _InlineMessageCard({required this.title, required this.tone});

  final String title;
  final _InlineMessageTone tone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final accentColor = switch (tone) {
      _InlineMessageTone.error => Colors.redAccent,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: tone == _InlineMessageTone.error
              ? accentColor
              : colorScheme.onSurface,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }
}

String _readableOrderStatus(String rawStatus) {
  final normalized = rawStatus.trim().toLowerCase();
  if (normalized.isEmpty) {
    return 'Unknown';
  }

  return normalized
      .split(RegExp(r'[\s_-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String? _buildReconciliationDeltaText(double? delta) {
  if (delta == null) {
    return null;
  }

  if (delta > 0) {
    return 'Additional deduction: ${_formatIndianCurrency(delta)}';
  }

  if (delta < 0) {
    return 'Returned to fund: ${_formatIndianCurrency(delta.abs())}';
  }

  return 'Matched allocated amount';
}

double? _parseActualTotalInput(String rawValue) {
  var cleaned = rawValue.trim();
  if (cleaned.isEmpty) {
    return null;
  }

  cleaned = cleaned.replaceAll(',', '').trim();
  cleaned = cleaned
      .replaceFirst(RegExp('^(?:\\u20B9|\\u00E2\\u201A\\u00B9)\\s*'), '')
      .trim();
  if (cleaned.startsWith('â‚¹')) {
    cleaned = cleaned.substring(1).trim();
  } else if (cleaned.startsWith('Ã¢â€šÂ¹')) {
    cleaned = cleaned.substring('Ã¢â€šÂ¹'.length).trim();
  }

  final parsed = double.tryParse(cleaned);
  if (parsed == null || !parsed.isFinite || parsed <= 0) {
    return null;
  }

  final rounded = _roundCurrency(parsed);
  if (!rounded.isFinite || rounded <= 0) {
    return null;
  }

  return rounded;
}

String _friendlyOrderRepairErrorMessage(Object error) {
  if (FirestoreAccessGuard.isPermissionDenied(error)) {
    return 'Order repair was blocked by Firebase permissions.';
  }

  final raw = error.toString().trim();
  if (raw.startsWith('Invalid argument(s): ')) {
    final message = raw.substring('Invalid argument(s): '.length).trim();
    return message.isEmpty ? 'Unable to repair legacy orders.' : message;
  }

  if (raw.startsWith('Bad state: ')) {
    final message = raw.substring('Bad state: '.length).trim();
    return message.isEmpty ? 'Unable to repair legacy orders.' : message;
  }

  final cleaned = raw.replaceFirst('Exception: ', '').trim();
  return cleaned.isEmpty ? 'Unable to repair legacy orders.' : cleaned;
}

String _friendlyPurchaseOrderErrorMessage(Object error) {
  if (FirestoreAccessGuard.isPermissionDenied(error)) {
    return 'Purchase Order creation was blocked by Firebase permissions. The deployed Firestore rules may need updating.';
  }

  final raw = error.toString().trim();
  if (raw.startsWith('Invalid argument(s): ')) {
    final message = raw.substring('Invalid argument(s): '.length).trim();
    return message.isEmpty
        ? 'Unable to create Purchase Order folder.'
        : message;
  }

  if (raw.startsWith('Bad state: ')) {
    final message = raw.substring('Bad state: '.length).trim();
    return message.isEmpty
        ? 'Unable to create Purchase Order folder.'
        : message;
  }

  final cleaned = raw.replaceFirst('Exception: ', '').trim();
  return cleaned.isEmpty ? 'Unable to create Purchase Order folder.' : cleaned;
}

String _friendlyReconciliationErrorMessage(Object error) {
  if (FirestoreAccessGuard.isPermissionDenied(error)) {
    return 'Reconciliation was blocked by Firebase permissions. The deployed Firestore rules may need updating.';
  }

  final raw = error.toString().trim();
  if (raw.startsWith('Invalid argument(s): ')) {
    final message = raw.substring('Invalid argument(s): '.length).trim();
    return message.isEmpty ? 'Unable to record actual cost.' : message;
  }

  if (raw.startsWith('Bad state: ')) {
    final message = raw.substring('Bad state: '.length).trim();
    return message.isEmpty ? 'Unable to record actual cost.' : message;
  }

  final cleaned = raw.replaceFirst('Exception: ', '').trim();
  return cleaned.isEmpty ? 'Unable to record actual cost.' : cleaned;
}

String _formatIndianCurrency(double value) {
  if (!value.isFinite) {
    return '\u20B90';
  }

  final rounded = _roundCurrency(value);
  final normalized = rounded == 0 ? 0 : rounded;
  final absoluteValue = normalized.abs();
  final fixed = absoluteValue.toStringAsFixed(2);
  final parts = fixed.split('.');
  final integerPart = parts[0];
  final decimalPart = parts.length > 1 ? parts[1] : '00';
  final groupedInteger = _formatIndianDigits(integerPart);
  final hasFraction = decimalPart != '00';
  final amountText = hasFraction
      ? '$groupedInteger.${decimalPart.replaceFirst(RegExp(r'0+$'), '')}'
      : groupedInteger;
  final prefix = normalized < 0 ? '-\u20B9' : '\u20B9';
  return '$prefix$amountText';
}

String _formatIndianDigits(String digits) {
  if (digits.length <= 3) {
    return digits;
  }

  final lastThree = digits.substring(digits.length - 3);
  var leading = digits.substring(0, digits.length - 3);
  final parts = <String>[];

  while (leading.length > 2) {
    parts.insert(0, leading.substring(leading.length - 2));
    leading = leading.substring(0, leading.length - 2);
  }

  if (leading.isNotEmpty) {
    parts.insert(0, leading);
  }

  return '${parts.join(',')},$lastThree';
}

double _roundCurrency(double value) {
  return (value * 100).roundToDouble() / 100;
}

String _formatShortDateValue(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  return '$day/$month/$year';
}
