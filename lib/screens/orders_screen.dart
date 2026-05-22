import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/order_model.dart';
import '../services/activity_service.dart';
import '../services/firestore_access_guard.dart';
import '../services/order_service.dart';
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
  final OrderService orderService = OrderService();

  OrdersViewMode _viewMode = OrdersViewMode.compact;
  OrdersSortOption _sortOption = OrdersSortOption.newestFirst;
  String _selectedBrand = _allFilterValue;
  String _selectedVendor = _allFilterValue;
  String _selectedOrderedBy = _allFilterValue;
  String _selectedModeOfPurchase = _allFilterValue;
  DateTime? _startDate;
  DateTime? _endDate;

  String get _currentUserName => AppState.instance.authenticatedUserName;

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

  Future<void> _markDelivered(OrderModel order) async {
    await orderService.updateOrderStatus(
      docId: order.id,
      status: 'delivered',
      receivedBy: _currentUserName,
    );
    await ActivityService().addActivity(
      labId: AppState.instance.resolveWriteLabId(order.labId),
      type: 'order_delivered',
      message: 'Order delivered for ${order.displayName}',
      actorName: _currentUserName,
      createdBy: AppState.instance.authenticatedUserId,
      relatedId: order.id,
    );
  }

  Widget _buildViewToggle() {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Compact'),
          selected: _viewMode == OrdersViewMode.compact,
          selectedColor: palette.selected,
          backgroundColor: palette.panel,
          labelStyle: TextStyle(
            color: _viewMode == OrdersViewMode.compact
                ? colorScheme.primary
                : palette.mutedText,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) {
            setState(() {
              _viewMode = OrdersViewMode.compact;
            });
          },
        ),
        ChoiceChip(
          label: const Text('Detailed'),
          selected: _viewMode == OrdersViewMode.detailed,
          selectedColor: palette.selected,
          backgroundColor: palette.panel,
          labelStyle: TextStyle(
            color: _viewMode == OrdersViewMode.detailed
                ? colorScheme.primary
                : palette.mutedText,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) {
            setState(() {
              _viewMode = OrdersViewMode.detailed;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSortDropdown() {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<OrdersSortOption>(
          value: _sortOption,
          dropdownColor: palette.panel,
          style: TextStyle(color: colorScheme.onSurface),
          isExpanded: true,
          items: OrdersSortOption.values.map((option) {
            return DropdownMenuItem<OrdersSortOption>(
              value: option,
              child: Text(
                'Sort: ${_sortLabel(option)}',
                style: TextStyle(color: colorScheme.onSurface),
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
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          dropdownColor: palette.panel,
          style: TextStyle(color: colorScheme.onSurface),
          isExpanded: true,
          items: options.map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(
                option == _allFilterValue ? '$label: All' : option,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 12.8),
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
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: palette.panel,
          borderRadius: BorderRadius.circular(14),
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
                  fontSize: 12.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.calendar_today_rounded,
              color: colorScheme.primary,
              size: 17,
            ),
          ],
        ),
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

    final controls = [
      _buildFilterDropdown(
        label: 'Brand',
        value: _selectedBrand,
        options: brandOptions,
        onChanged: (value) {
          setState(() {
            _selectedBrand = value;
          });
        },
      ),
      _buildFilterDropdown(
        label: 'Vendor',
        value: _selectedVendor,
        options: vendorOptions,
        onChanged: (value) {
          setState(() {
            _selectedVendor = value;
          });
        },
      ),
      _buildFilterDropdown(
        label: 'Ordered by',
        value: _selectedOrderedBy,
        options: orderedByOptions,
        onChanged: (value) {
          setState(() {
            _selectedOrderedBy = value;
          });
        },
      ),
      _buildFilterDropdown(
        label: 'Mode',
        value: _selectedModeOfPurchase,
        options: modeOptions,
        onChanged: (value) {
          setState(() {
            _selectedModeOfPurchase = value;
          });
        },
      ),
      _buildDateFilterButton(
        label: 'Start',
        value: _startDate,
        onTap: () => _pickFilterDate(isStartDate: true),
      ),
      _buildDateFilterButton(
        label: 'End',
        value: _endDate,
        onTap: () => _pickFilterDate(isStartDate: false),
      ),
    ];

    if (!isDesktop) {
      return Column(
        children: [
          for (int index = 0; index < controls.length; index++) ...[
            controls[index],
            if (index != controls.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _hasActiveFilters ? _resetFilters : null,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
              label: const Text('Reset Filters'),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            for (int index = 0; index < controls.length; index++) ...[
              Expanded(child: controls[index]),
              if (index != controls.length - 1) const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _hasActiveFilters ? _resetFilters : null,
            icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
            label: const Text('Reset Filters'),
          ),
        ),
      ],
    );
  }

  Widget _buildControlsCard({
    required int filteredCount,
    required int totalCount,
    required List<OrderModel> allOrders,
    required bool isDesktop,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      margin: EdgeInsets.fromLTRB(12, isDesktop ? 10 : 12, 12, 8),
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
            _hasActiveFilters
                ? '$filteredCount of $totalCount orders'
                : '$totalCount ${totalCount == 1 ? 'order' : 'orders'}',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 190, child: _buildViewToggle()),
                const SizedBox(width: 12),
                SizedBox(width: 220, child: _buildSortDropdown()),
              ],
            )
          else ...[
            _buildViewToggle(),
            const SizedBox(height: 12),
            _buildSortDropdown(),
          ],
          const SizedBox(height: 12),
          _buildFilterToolbar(isDesktop: isDesktop, allOrders: allOrders),
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
        color: color.withOpacity(0.14),
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

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          await _markDelivered(order);

          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order marked as delivered')),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        child: const Text('Mark as Delivered'),
      ),
    );
  }

  Widget _buildCompactCard({
    required BuildContext context,
    required OrderModel order,
  }) {
    final isDelivered = order.status.toLowerCase() == 'delivered';
    final actionArea = _buildDeliveredAction(context: context, order: order);
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(14),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (!isDelivered) ...[const SizedBox(height: 12), actionArea],
        ],
      ),
    );
  }

  Widget _buildDetailedCard({
    required BuildContext context,
    required OrderModel order,
  }) {
    final isDelivered = order.status.toLowerCase() == 'delivered';
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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
              style: TextStyle(color: palette.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 4),
          ],
          if (order.packSize.trim().isNotEmpty) ...[
            Text(
              'Pack Size: ${order.packSize}',
              style: TextStyle(color: palette.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 4),
          ],
          if (order.brand.trim().isNotEmpty) ...[
            Text(
              'Brand: ${order.brand}',
              style: TextStyle(color: palette.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 4),
          ],
          if (order.vendor.trim().isNotEmpty) ...[
            Text(
              'Vendor: ${order.vendor}',
              style: TextStyle(color: palette.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            'Quantity: ${order.quantity.isEmpty ? "-" : order.quantity}',
            style: TextStyle(color: palette.mutedText, fontSize: 13),
          ),
          if (order.modeOfPurchase.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Mode: ${order.modeOfPurchase}',
              style: TextStyle(color: palette.mutedText, fontSize: 13),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _formatOrderedNote(order),
            style: TextStyle(color: palette.subtleText, fontSize: 12.5),
          ),
          if (isDelivered) ...[
            const SizedBox(height: 6),
            Text(
              _formatDeliveredNote(order),
              style: TextStyle(color: palette.subtleText, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 8),
          _buildStatusBadge(order),
          if (!isDelivered) ...[
            const SizedBox(height: 12),
            _buildDeliveredAction(context: context, order: order),
          ],
        ],
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
  Widget build(BuildContext context) {
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
