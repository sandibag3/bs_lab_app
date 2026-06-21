import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/fund_model.dart';
import '../models/order_model.dart';
import '../models/requirement_model.dart';
import '../services/activity_service.dart';
import '../services/firestore_access_guard.dart';
import '../services/fund_service.dart';
import '../services/order_service.dart';
import '../services/requirement_service.dart';
import '../theme/labmate_theme.dart';
import '../widgets/responsive_page_container.dart';

enum CartViewMode { compact, detailed }

enum CartSortOption { newestFirst, oldestFirst, status, type }

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final RequirementService requirementService = RequirementService();
  final FundService fundService = FundService();
  final OrderService orderService = OrderService();
  static const String _deleteRequirementStatusChangedMessage =
      'This requirement can no longer be deleted because its status has changed.';

  CartViewMode _viewMode = CartViewMode.compact;
  CartSortOption _sortOption = CartSortOption.newestFirst;
  String? _cancellingRequirementId;
  String? _placingOrderRequirementId;

  String _requirementDisplayName(RequirementModel req) {
    final mainType = req.mainType.trim().toLowerCase();
    final chemical = req.chemicalName.trim();
    final consumable = req.consumableType.trim();

    if (mainType == 'consumable') {
      if (consumable.isNotEmpty) return consumable;
      if (chemical.isNotEmpty) return chemical;
      return 'Consumable';
    }

    if (chemical.isNotEmpty) return chemical;
    if (consumable.isNotEmpty) return consumable;
    return 'Chemical';
  }

  bool _isConsumableRequirement(RequirementModel req) {
    return req.mainType.trim().toLowerCase() == 'consumable';
  }

  String _typeLabel(RequirementModel req) {
    return _isConsumableRequirement(req) ? 'Consumable' : 'Chemical';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.greenAccent;
      case 'rejected':
        return Colors.redAccent;
      case 'ordered':
        return const Color(0xFF14B8A6);
      default:
        return Colors.orangeAccent;
    }
  }

  String _statusText(RequirementModel req) {
    switch (req.status.toLowerCase()) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'ordered':
        return 'Order placed';
      default:
        return 'Waiting for approval';
    }
  }

  int _statusSortWeight(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 0;
      case 'approved':
        return 1;
      case 'ordered':
        return 2;
      case 'rejected':
        return 3;
      default:
        return 4;
    }
  }

  String _sortLabel(CartSortOption option) {
    switch (option) {
      case CartSortOption.newestFirst:
        return 'Newest first';
      case CartSortOption.oldestFirst:
        return 'Oldest first';
      case CartSortOption.status:
        return 'Status';
      case CartSortOption.type:
        return 'Type';
    }
  }

  List<RequirementModel> _sortRequirements(List<RequirementModel> input) {
    final list = [...input];

    list.sort((a, b) {
      switch (_sortOption) {
        case CartSortOption.newestFirst:
          return b.createdAt.compareTo(a.createdAt);

        case CartSortOption.oldestFirst:
          return a.createdAt.compareTo(b.createdAt);

        case CartSortOption.status:
          final statusComparison = _statusSortWeight(
            a.status,
          ).compareTo(_statusSortWeight(b.status));
          if (statusComparison != 0) {
            return statusComparison;
          }
          return b.createdAt.compareTo(a.createdAt);

        case CartSortOption.type:
          final typeComparison = _typeLabel(
            a,
          ).toLowerCase().compareTo(_typeLabel(b).toLowerCase());
          if (typeComparison != 0) {
            return typeComparison;
          }
          return b.createdAt.compareTo(a.createdAt);
      }
    });

    return list;
  }

  bool _isVisibleCartRequirement(RequirementModel req) {
    if ((req.orderId?.trim() ?? '').isNotEmpty) {
      return false;
    }

    final status = req.status.trim().toLowerCase();
    switch (status) {
      case 'pending':
      case 'approved':
        return true;
      case 'ordered':
      case 'delivered':
      case 'completed':
      case 'cancelled':
      case 'rejected':
      case 'received':
        return false;
      default:
        return false;
    }
  }

  List<RequirementModel> _visibleCartRequirements(
    List<RequirementModel> requirements,
  ) {
    return requirements.where(_isVisibleCartRequirement).toList();
  }

  bool _isCancellingRequirement(String requirementId) {
    return _cancellingRequirementId == requirementId;
  }

  bool _isPlacingOrder(String requirementId) {
    return _placingOrderRequirementId == requirementId;
  }

  bool _matchesCurrentRequester(RequirementModel req) {
    final appState = AppState.instance;
    final currentUserId = appState.authenticatedUserId.trim();
    final storedCreatedBy = req.createdBy.trim();
    if (storedCreatedBy.isNotEmpty) {
      return currentUserId.isNotEmpty && storedCreatedBy == currentUserId;
    }

    final requestedBy = req.userName.trim().toLowerCase();
    if (requestedBy.isEmpty) {
      return false;
    }

    final currentUserName = appState.authenticatedUserName.trim().toLowerCase();
    if (currentUserName.isNotEmpty && requestedBy == currentUserName) {
      return true;
    }

    final currentUserEmail = appState.authenticatedUserEmail
        .trim()
        .toLowerCase();
    return currentUserEmail.isNotEmpty && requestedBy == currentUserEmail;
  }

  bool _canRequesterDeleteRequirement(RequirementModel req) {
    final status = req.status.trim().toLowerCase();
    return _matchesCurrentRequester(req) &&
        status == 'pending' &&
        req.approvedBy.trim().isEmpty &&
        req.approvedAt == null &&
        !req.hasFundAllocation;
  }

  Future<void> _updateStatus({
    required RequirementModel req,
    required String status,
  }) async {
    final appState = AppState.instance;
    final currentUserName = appState.authenticatedUserName;

    await requirementService.updateRequirementStatus(
      docId: req.id,
      status: status,
      approvedBy: currentUserName,
    );
    await ActivityService().addActivity(
      labId: appState.resolveWriteLabId(req.labId),
      type: status == 'approved'
          ? 'requirement_approved'
          : 'requirement_rejected',
      message:
          'Requirement ${status == 'approved' ? 'approved' : 'rejected'} for ${_requirementDisplayName(req)}',
      actorName: currentUserName,
      createdBy: appState.authenticatedUserId,
      relatedId: req.id,
    );
  }

  String _resolveApproverIdentity() {
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

  Future<bool> _showDeleteRequirementConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete requirement?'),
          content: const Text(
            'This requirement will be removed from the active list. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  Future<void> _handleDeleteRequirement({
    required BuildContext context,
    required RequirementModel req,
  }) async {
    if (_isCancellingRequirement(req.id) ||
        !_canRequesterDeleteRequirement(req)) {
      return;
    }

    final confirmed = await _showDeleteRequirementConfirmation(context);
    if (!confirmed || !context.mounted) {
      return;
    }

    setState(() {
      _cancellingRequirementId = req.id;
    });

    try {
      await requirementService.cancelPendingRequirement(
        requirementId: req.id,
        requesterUid: AppState.instance.authenticatedUserId,
        requesterUserName: AppState.instance.authenticatedUserName,
        requesterEmail: AppState.instance.authenticatedUserEmail,
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Requirement deleted successfully.')),
      );
    } catch (error) {
      debugPrint('Requirement cancellation error: $error');

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyCancellationErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (_cancellingRequirementId == req.id) {
            _cancellingRequirementId = null;
          }
        });
      }
    }
  }

  Widget _buildDeleteRequirementButton({
    required BuildContext context,
    required RequirementModel req,
  }) {
    final isCancelling = _isCancellingRequirement(req.id);

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: isCancelling
            ? null
            : () async {
                await _handleDeleteRequirement(context: context, req: req);
              },
        style: TextButton.styleFrom(
          foregroundColor: Colors.redAccent,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        ),
        icon: isCancelling
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.delete_outline, size: 18),
        label: Text(isCancelling ? 'Deleting...' : 'Delete requirement'),
      ),
    );
  }

  Future<void> _recordApprovalActivity(RequirementModel req) async {
    final appState = AppState.instance;
    final currentUserName = appState.authenticatedUserName;

    try {
      await ActivityService().addActivity(
        labId: appState.resolveWriteLabId(req.labId),
        type: 'requirement_approved',
        message: 'Requirement approved for ${_requirementDisplayName(req)}',
        actorName: currentUserName,
        createdBy: appState.authenticatedUserId,
        relatedId: req.id,
      );
    } catch (error) {
      debugPrint('Failed to record requirement approval activity: $error');
    }
  }

  String _friendlyCancellationErrorMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.contains(_deleteRequirementStatusChangedMessage)) {
      return _deleteRequirementStatusChangedMessage;
    }

    return 'Failed to delete requirement. Please try again.';
  }

  Future<void> _handleApproveRequirement({
    required BuildContext context,
    required RequirementModel req,
  }) async {
    final appState = AppState.instance;
    final selectedLabId = appState.selectedLabId.trim();
    final requirementLabId = req.labId.trim();

    if (requirementLabId.isEmpty ||
        (selectedLabId.isNotEmpty && requirementLabId != selectedLabId)) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This requirement does not belong to the currently selected lab.',
          ),
        ),
      );
      return;
    }

    final approverIdentity = _resolveApproverIdentity();
    if (approverIdentity.isEmpty) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to identify the approving user.')),
      );
      return;
    }

    final approved = await _showApproveRequirementSheet(
      context: context,
      requirement: req,
      approverIdentity: approverIdentity,
    );

    if (approved != true || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Requirement approved and fund allocated successfully.'),
      ),
    );

    await _recordApprovalActivity(req);
  }

  Future<bool?> _showApproveRequirementSheet({
    required BuildContext context,
    required RequirementModel requirement,
    required String approverIdentity,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final content = _RequirementFundApprovalPanel(
      requirement: requirement,
      requirementService: requirementService,
      fundService: fundService,
      approverIdentity: approverIdentity,
      itemDisplayName: _requirementDisplayName(requirement),
    );

    if (width < 720) {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        enableDrag: false,
        isDismissible: false,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final sheetPalette = sheetContext.labmate;
          return FractionallySizedBox(
            heightFactor: 0.92,
            child: Container(
              decoration: BoxDecoration(
                color: sheetPalette.panel,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: content,
            ),
          );
        },
      );
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final dialogPalette = dialogContext.labmate;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          backgroundColor: dialogPalette.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: content,
        );
      },
    );
  }

  Future<void> _placeOrder(RequirementModel req) async {
    final appState = AppState.instance;
    final currentUserName = appState.authenticatedUserName;
    final estimatedTotal = _parseEstimatedTotal(req.estimatedTotal);

    final order = OrderModel(
      id: '',
      requirementId: req.id,
      labId: appState.resolveWriteLabId(req.labId),
      mainType: req.mainType,
      chemicalName: req.chemicalName,
      consumableType: req.consumableType,
      cas: req.cas,
      brand: req.brand,
      vendor: req.vendor,
      quantity: req.quantity,
      packSize: req.packSize,
      modeOfPurchase: req.modeOfPurchase,
      orderedBy: currentUserName,
      orderedAt: Timestamp.now(),
      status: 'ordered',
      receivedBy: '',
      deliveredAt: null,
      inventoryAdded: false,
      estimatedTotal: estimatedTotal,
      fundId: req.fundId,
      fundNameSnapshot: req.fundNameSnapshot,
      fundCodeSnapshot: req.fundCodeSnapshot,
      allocatedAmount: req.allocatedAmount,
      fundTransactionId: req.fundTransactionId,
    );

    final orderId = await orderService.placeOrderAndMarkRequirementOrdered(
      order: order,
      updatedBy: currentUserName,
    );
    try {
      await ActivityService().addActivity(
        labId: order.labId,
        type: 'order_placed',
        message: 'Order placed for ${order.displayName}',
        actorName: currentUserName,
        createdBy: appState.authenticatedUserId,
        relatedId: orderId,
      );
    } catch (error) {
      debugPrint('Failed to record order activity: $error');
    }
  }

  Future<void> _handlePlaceOrder({
    required BuildContext context,
    required RequirementModel req,
  }) async {
    if (_isPlacingOrder(req.id)) {
      return;
    }

    if (mounted) {
      setState(() {
        _placingOrderRequirementId = req.id;
      });
    }

    try {
      await _placeOrder(req);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed successfully')),
      );
    } catch (error) {
      debugPrint('Failed to place order: $error');
      if (!context.mounted) return;
      final message = error is OrderPlacementException
          ? error.message
          : 'Failed to place order. Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted && _placingOrderRequirementId == req.id) {
        setState(() {
          _placingOrderRequirementId = null;
        });
      }
    }
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
          selected: _viewMode == CartViewMode.compact,
          selectedColor: colorScheme.primary.withValues(alpha: 0.16),
          backgroundColor: palette.panelAlt,
          labelStyle: TextStyle(
            color: _viewMode == CartViewMode.compact
                ? colorScheme.primary
                : palette.mutedText,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) {
            setState(() {
              _viewMode = CartViewMode.compact;
            });
          },
        ),
        ChoiceChip(
          label: const Text('Detailed'),
          selected: _viewMode == CartViewMode.detailed,
          selectedColor: colorScheme.primary.withValues(alpha: 0.16),
          backgroundColor: palette.panelAlt,
          labelStyle: TextStyle(
            color: _viewMode == CartViewMode.detailed
                ? colorScheme.primary
                : palette.mutedText,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) {
            setState(() {
              _viewMode = CartViewMode.detailed;
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
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CartSortOption>(
          value: _sortOption,
          dropdownColor: palette.panel,
          style: TextStyle(color: colorScheme.onSurface),
          isExpanded: true,
          items: CartSortOption.values.map((option) {
            return DropdownMenuItem<CartSortOption>(
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

  Widget _buildControlsCard(int itemCount) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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
            '$itemCount ${itemCount == 1 ? 'item' : 'items'} in cart',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _buildViewToggle(),
          const SizedBox(height: 12),
          _buildSortDropdown(),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(RequirementModel req) {
    final isConsumable = _isConsumableRequirement(req);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isConsumable ? const Color(0x2238BDF8) : const Color(0x2214B8A6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _typeLabel(req),
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

  Widget _buildStatusBadge(RequirementModel req) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _statusColor(req.status).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _statusText(req),
        style: TextStyle(
          color: _statusColor(req.status),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildCompactActionArea({
    required BuildContext context,
    required RequirementModel req,
    required bool isPiAdmin,
  }) {
    final status = req.status.toLowerCase();
    final actions = <Widget>[];

    if (isPiAdmin && status == 'pending') {
      actions.add(
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await _handleApproveRequirement(context: context, req: req);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text('Approve'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await _updateStatus(req: req, status: 'rejected');

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Requirement rejected')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text('Reject'),
              ),
            ),
          ],
        ),
      );
    }

    if (status == 'approved') {
      final isPlacingOrder = _isPlacingOrder(req.id);
      actions.add(
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isPlacingOrder
                ? null
                : () async {
                    await _handlePlaceOrder(context: context, req: req);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14B8A6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: Text(isPlacingOrder ? 'Placing...' : 'Place Order'),
          ),
        ),
      );
    }

    if (_canRequesterDeleteRequirement(req)) {
      if (actions.isNotEmpty) {
        actions.add(const SizedBox(height: 8));
      }
      actions.add(_buildDeleteRequirementButton(context: context, req: req));
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: actions,
    );
  }

  Widget _buildDetailedApproveRejectActions({
    required BuildContext context,
    required RequirementModel req,
  }) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              await _handleApproveRequirement(context: context, req: req);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              await _updateStatus(req: req, status: 'rejected');

              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Requirement rejected')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedRequesterDeleteAction({
    required BuildContext context,
    required RequirementModel req,
  }) {
    if (!_canRequesterDeleteRequirement(req)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _buildDeleteRequirementButton(context: context, req: req),
    );
  }

  Widget _buildDetailedPlaceOrderAction({
    required BuildContext context,
    required RequirementModel req,
  }) {
    final isPlacingOrder = _isPlacingOrder(req.id);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isPlacingOrder
            ? null
            : () async {
                await _handlePlaceOrder(context: context, req: req);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF14B8A6),
          foregroundColor: Colors.white,
        ),
        child: Text(isPlacingOrder ? 'Placing...' : 'Place Order'),
      ),
    );
  }

  Widget _buildDetailedCard({
    required BuildContext context,
    required RequirementModel req,
    required bool isPiAdmin,
  }) {
    final isConsumable = _isConsumableRequirement(req);
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                  _requirementDisplayName(req),
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 15.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _buildTypeBadge(req),
            ],
          ),
          const SizedBox(height: 10),
          if (!isConsumable && req.cas.trim().isNotEmpty) ...[
            Text('CAS: ${req.cas}', style: TextStyle(color: palette.mutedText)),
            const SizedBox(height: 4),
          ],
          if (req.packSize.trim().isNotEmpty) ...[
            Text(
              'Pack Size: ${req.packSize}',
              style: TextStyle(color: palette.mutedText),
            ),
            const SizedBox(height: 4),
          ],
          if (req.brand.trim().isNotEmpty) ...[
            Text(
              'Brand: ${req.brand}',
              style: TextStyle(color: palette.mutedText),
            ),
            const SizedBox(height: 4),
          ],
          if (req.vendor.trim().isNotEmpty) ...[
            Text(
              'Vendor: ${req.vendor}',
              style: TextStyle(color: palette.mutedText),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            'Qty: ${req.quantity.isEmpty ? "-" : req.quantity}',
            style: TextStyle(color: palette.mutedText),
          ),
          if (req.modeOfPurchase.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Mode: ${req.modeOfPurchase}',
              style: TextStyle(color: palette.mutedText),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Requested by: ${req.userName.isEmpty ? "-" : req.userName}',
            style: TextStyle(color: palette.mutedText),
          ),
          const SizedBox(height: 10),
          _buildStatusBadge(req),
          if (req.hasFundAllocation) ...[
            const SizedBox(height: 8),
            _buildAllocationSummary(req: req),
          ],
          if (req.approvedBy.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Updated by: ${req.approvedBy}',
              style: TextStyle(color: palette.subtleText, fontSize: 12.5),
            ),
          ],
          if (isPiAdmin && req.status.toLowerCase() == 'pending') ...[
            const SizedBox(height: 12),
            _buildDetailedApproveRejectActions(context: context, req: req),
          ],
          if (_canRequesterDeleteRequirement(req))
            _buildDetailedRequesterDeleteAction(context: context, req: req),
          if (req.status.toLowerCase() == 'approved') ...[
            const SizedBox(height: 12),
            _buildDetailedPlaceOrderAction(context: context, req: req),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactCard({
    required BuildContext context,
    required RequirementModel req,
    required bool isPiAdmin,
  }) {
    final actionArea = _buildCompactActionArea(
      context: context,
      req: req,
      isPiAdmin: isPiAdmin,
    );
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
                  _requirementDisplayName(req),
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
              _buildTypeBadge(req),
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
                ),
                child: Text(
                  'Qty: ${req.quantity.isEmpty ? "-" : req.quantity}',
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildStatusBadge(req),
            ],
          ),
          if (req.hasFundAllocation) ...[
            const SizedBox(height: 10),
            _buildAllocationSummary(req: req, isCompact: true),
          ],
          if (actionArea is! SizedBox) ...[
            const SizedBox(height: 12),
            actionArea,
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
              const Icon(
                Icons.assignment_outlined,
                color: Color(0xFF14B8A6),
                size: 30,
              ),
              const SizedBox(height: 12),
              Text(
                'No pending cart items.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Approved items awaiting order placement and pending approvals will appear here.',
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

  Widget _buildAllocationSummary({
    required RequirementModel req,
    bool isCompact = false,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final fundName = req.fundDisplayName.trim();
    final allocatedAmount = req.allocatedAmount ?? 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 12,
        vertical: isCompact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0x2214B8A6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x3314B8A6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fund: ${fundName.isEmpty ? 'Allocated fund' : fundName}',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: isCompact ? 12.5 : 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Allocated: ${_formatIndianCurrency(allocatedAmount)}',
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

  @override
  Widget build(BuildContext context) {
    final appState = AppState.instance;
    final bool isPiAdmin = appState.isPiAdmin;
    final palette = context.labmate;

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: ResponsivePageContainer(
        child: StreamBuilder<List<RequirementModel>>(
          stream: requirementService.getRequirements(),
          builder: (context, snapshot) {
            if (!FirestoreAccessGuard.shouldQueryLabScopedData()) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    FirestoreAccessGuard.userMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.mutedText, height: 1.4),
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
                    style: TextStyle(color: palette.mutedText, height: 1.4),
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final visibleRequirements = _visibleCartRequirements(
              snapshot.data!,
            );
            final sortedList = _sortRequirements(visibleRequirements);

            if (sortedList.isEmpty) {
              return _buildEmptyState();
            }

            return Column(
              children: [
                _buildControlsCard(sortedList.length),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: sortedList.length,
                    itemBuilder: (context, index) {
                      final req = sortedList[index];

                      if (_viewMode == CartViewMode.compact) {
                        return _buildCompactCard(
                          context: context,
                          req: req,
                          isPiAdmin: isPiAdmin,
                        );
                      }

                      return _buildDetailedCard(
                        context: context,
                        req: req,
                        isPiAdmin: isPiAdmin,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RequirementFundApprovalPanel extends StatefulWidget {
  const _RequirementFundApprovalPanel({
    required this.requirement,
    required this.requirementService,
    required this.fundService,
    required this.approverIdentity,
    required this.itemDisplayName,
  });

  final RequirementModel requirement;
  final RequirementService requirementService;
  final FundService fundService;
  final String approverIdentity;
  final String itemDisplayName;

  @override
  State<_RequirementFundApprovalPanel> createState() =>
      _RequirementFundApprovalPanelState();
}

class _RequirementFundApprovalPanelState
    extends State<_RequirementFundApprovalPanel> {
  static const double _balanceTolerance = 0.000001;

  late Stream<List<FundModel>> _fundsStream;

  String? _selectedFundId;
  String? _submissionError;
  bool _isSubmitting = false;
  late final double? _estimatedTotal;

  @override
  void initState() {
    super.initState();
    _estimatedTotal = _parseEstimatedTotal(widget.requirement.estimatedTotal);
    _refreshFunds();
  }

  void _refreshFunds() {
    _fundsStream = widget.fundService.streamFunds(widget.requirement.labId);
  }

  Future<void> _submitApproval(FundModel selectedFund) async {
    if (_isSubmitting) {
      return;
    }

    final requirementLabId = widget.requirement.labId.trim();
    final selectedLabId = AppState.instance.selectedLabId.trim();
    if (requirementLabId.isEmpty ||
        (selectedLabId.isNotEmpty && requirementLabId != selectedLabId)) {
      setState(() {
        _submissionError =
            'This requirement does not belong to the currently selected lab.';
      });
      return;
    }

    final approverIdentity = widget.approverIdentity.trim();
    if (approverIdentity.isEmpty) {
      setState(() {
        _submissionError = 'Unable to identify the approving user.';
      });
      return;
    }

    final estimatedTotal = _estimatedTotal;
    if (estimatedTotal == null) {
      setState(() {
        _submissionError =
            'A valid estimated total greater than zero is required before approval.';
      });
      return;
    }

    if (!_hasSufficientDisplayedBalance(
      selectedFund.availableAmount,
      estimatedTotal,
      tolerance: _balanceTolerance,
    )) {
      setState(() {
        _submissionError =
            'This fund does not have sufficient available balance.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      await widget.requirementService.approveRequirementWithFund(
        requirementId: widget.requirement.id,
        labId: requirementLabId,
        fundId: selectedFund.id,
        approvedBy: approverIdentity,
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
        _submissionError = _friendlyApprovalErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final estimatedTotal = _estimatedTotal;
    final hasValidEstimatedTotal = estimatedTotal != null;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 720, maxHeight: maxHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Approve requirement',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRequirementSummaryCard(
                      context: context,
                      estimatedTotal: estimatedTotal,
                    ),
                    if (!hasValidEstimatedTotal) ...[
                      const SizedBox(height: 14),
                      _buildMessageCard(
                        context: context,
                        title:
                            'A valid estimated total greater than zero is required before approval.',
                        detail:
                            'This requirement cannot be approved with fund allocation until its estimated total is corrected.',
                        tone: _MessageTone.error,
                      ),
                    ],
                    if (hasValidEstimatedTotal) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Select fund',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder<List<FundModel>>(
                        stream: _fundsStream,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return _buildFundErrorState(
                              context: context,
                              detail: _friendlyFundLoadError(snapshot.error),
                            );
                          }

                          if (!snapshot.hasData) {
                            return _buildFundLoadingState(context: context);
                          }

                          final activeFunds = snapshot.data!
                              .where(
                                (fund) =>
                                    fund.effectiveStatus ==
                                    FundModel.statusActive,
                              )
                              .toList();

                          if (activeFunds.isEmpty) {
                            return _buildMessageCard(
                              context: context,
                              title:
                                  'No active funds are available for this requirement.',
                              detail:
                                  'Create or reopen a suitable fund outside this dialog before approving this requirement.',
                              tone: _MessageTone.info,
                            );
                          }

                          return Column(
                            children: activeFunds.map((fund) {
                              final canSelect = _hasSufficientDisplayedBalance(
                                fund.availableAmount,
                                estimatedTotal,
                                tolerance: _balanceTolerance,
                              );
                              final afterApproval = _roundCurrency(
                                fund.availableAmount - estimatedTotal,
                              );

                              return _buildFundOptionCard(
                                context: context,
                                fund: fund,
                                canSelect: canSelect,
                                afterApproval: afterApproval < 0
                                    ? 0
                                    : afterApproval,
                                estimatedTotal: estimatedTotal,
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                    if (_submissionError != null) ...[
                      const SizedBox(height: 14),
                      _buildMessageCard(
                        context: context,
                        title: _submissionError!,
                        tone: _MessageTone.error,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<FundModel>>(
              stream: _fundsStream,
              builder: (context, snapshot) {
                final funds = snapshot.data ?? const <FundModel>[];
                final selectedFund = funds.cast<FundModel?>().firstWhere(
                  (fund) => fund?.id == _selectedFundId,
                  orElse: () => null,
                );
                final canApprove =
                    !_isSubmitting &&
                    hasValidEstimatedTotal &&
                    selectedFund != null &&
                    selectedFund.effectiveStatus == FundModel.statusActive &&
                    _hasSufficientDisplayedBalance(
                      selectedFund.availableAmount,
                      estimatedTotal,
                      tolerance: _balanceTolerance,
                    );
                final approvableFund = canApprove ? selectedFund : null;

                return Row(
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
                        onPressed: approvableFund != null
                            ? () => _submitApproval(approvableFund)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
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
                            : const Text('Approve & Allocate'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementSummaryCard({
    required BuildContext context,
    required double? estimatedTotal,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
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
            widget.itemDisplayName,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Quantity: ${widget.requirement.quantity.trim().isEmpty ? '-' : widget.requirement.quantity.trim()}',
            style: TextStyle(color: palette.mutedText),
          ),
          const SizedBox(height: 4),
          Text(
            'Estimated total: ${estimatedTotal == null ? '-' : _formatIndianCurrency(estimatedTotal)}',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Requested by: ${widget.requirement.userName.trim().isEmpty ? '-' : widget.requirement.userName.trim()}',
            style: TextStyle(color: palette.mutedText),
          ),
        ],
      ),
    );
  }

  Widget _buildFundLoadingState({required BuildContext context}) {
    final palette = context.labmate;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildFundErrorState({
    required BuildContext context,
    required String detail,
  }) {
    return _buildMessageCard(
      context: context,
      title: 'Unable to load funds.',
      detail: detail,
      tone: _MessageTone.error,
      actionLabel: 'Retry',
      onAction: _isSubmitting
          ? null
          : () {
              setState(() {
                _selectedFundId = null;
                _refreshFunds();
              });
            },
    );
  }

  Widget _buildFundOptionCard({
    required BuildContext context,
    required FundModel fund,
    required bool canSelect,
    required double afterApproval,
    required double estimatedTotal,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final isSelected = _selectedFundId == fund.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? colorScheme.primary : palette.border,
          width: isSelected ? 1.4 : 1,
        ),
      ),
      child: RadioListTile<String>(
        value: fund.id,
        groupValue: _selectedFundId,
        onChanged: (!_isSubmitting && canSelect)
            ? (value) {
                setState(() {
                  _selectedFundId = value;
                  _submissionError = null;
                });
              }
            : null,
        activeColor: colorScheme.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        title: Text(
          fund.fundName,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((fund.fundCode ?? '').trim().isNotEmpty) ...[
                Text(
                  'Code: ${fund.fundCode!.trim()}',
                  style: TextStyle(color: palette.mutedText, fontSize: 12.5),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                'Available: ${_formatIndianCurrency(fund.availableAmount)}',
                style: TextStyle(color: palette.mutedText, fontSize: 12.5),
              ),
              const SizedBox(height: 4),
              Text(
                'After approval: ${_formatIndianCurrency(afterApproval)}',
                style: TextStyle(
                  color: canSelect ? palette.mutedText : Colors.redAccent,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Total sanctioned: ${_formatIndianCurrency(fund.totalAmount)}',
                style: TextStyle(color: palette.mutedText, fontSize: 12.5),
              ),
              const SizedBox(height: 4),
              Text(
                'Ends: ${_formatShortDate(fund.endDate)}',
                style: TextStyle(color: palette.mutedText, fontSize: 12.5),
              ),
              if (!canSelect) ...[
                const SizedBox(height: 6),
                Text(
                  estimatedTotal > fund.availableAmount + _balanceTolerance
                      ? 'Insufficient balance'
                      : 'This fund cannot be selected.',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageCard({
    required BuildContext context,
    required String title,
    String? detail,
    required _MessageTone tone,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final accentColor = switch (tone) {
      _MessageTone.error => Colors.redAccent,
      _MessageTone.info => colorScheme.primary,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone == _MessageTone.error
            ? Colors.redAccent.withValues(alpha: 0.10)
            : palette.panelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tone == _MessageTone.error ? accentColor : palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: tone == _MessageTone.error
                  ? accentColor
                  : colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (detail != null && detail.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              detail,
              style: TextStyle(color: palette.mutedText, height: 1.35),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ],
      ),
    );
  }

  String _friendlyFundLoadError(Object? error) {
    if (FirestoreAccessGuard.isPermissionDenied(error ?? '')) {
      return 'Approval was blocked by Firebase permissions. The deployed Firestore rules may need updating.';
    }

    final fallback = FirestoreAccessGuard.messageFor(
      error,
      fallback: 'Please try again.',
    );
    if (fallback == FirestoreAccessGuard.userMessage) {
      return 'Approval was blocked by Firebase permissions. The deployed Firestore rules may need updating.';
    }

    return fallback;
  }

  String _friendlyApprovalErrorMessage(Object error) {
    if (FirestoreAccessGuard.isPermissionDenied(error)) {
      return 'Approval was blocked by Firebase permissions. The deployed Firestore rules may need updating.';
    }

    final raw = error.toString().trim();
    if (raw.startsWith('Invalid argument(s): ')) {
      return raw.substring('Invalid argument(s): '.length).trim();
    }

    if (raw.startsWith('Bad state: ')) {
      return raw.substring('Bad state: '.length).trim();
    }

    final cleaned = raw.replaceFirst('Exception: ', '').trim();
    return cleaned.isEmpty ? 'Unable to approve requirement.' : cleaned;
  }
}

enum _MessageTone { info, error }

double? _parseEstimatedTotal(String rawValue) {
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
  }

  cleaned = cleaned.replaceFirst(RegExp(r'^[^\d\.-]+'), '').trim();

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

bool _hasSufficientDisplayedBalance(
  double availableAmount,
  double requiredAmount, {
  double tolerance = 0.000001,
}) {
  return availableAmount.isFinite &&
      requiredAmount.isFinite &&
      (availableAmount + tolerance) >= requiredAmount;
}

double _roundCurrency(double value) {
  return (value * 100).roundToDouble() / 100;
}

String _formatIndianCurrency(double value) {
  if (!value.isFinite) {
    return '₹0';
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
  final prefix = normalized < 0 ? '-₹' : '₹';
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

String _formatShortDate(DateTime date) {
  const months = <String>[
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

  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
}
