import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/fund_model.dart';
import '../models/fund_transaction_model.dart';
import '../services/firestore_access_guard.dart';
import '../services/fund_service.dart';
import 'purchase_orders_screen.dart';
import '../theme/labmate_theme.dart';
import '../widgets/responsive_page_container.dart';

class FundsDashboardScreen extends StatefulWidget {
  const FundsDashboardScreen({super.key, required this.labId});

  final String labId;

  @override
  State<FundsDashboardScreen> createState() => _FundsDashboardScreenState();
}

enum _FundStatusFilter { all, active, expired, closed }

class _FundsDashboardScreenState extends State<FundsDashboardScreen> {
  late final FundService _fundService;
  late Stream<List<FundModel>> _fundsStream;
  _FundStatusFilter _statusFilter = _FundStatusFilter.all;

  @override
  void initState() {
    super.initState();
    _fundService = FundService();
    _fundsStream = _createFundsStream();
  }

  @override
  void didUpdateWidget(covariant FundsDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.labId != widget.labId) {
      setState(() {
        _statusFilter = _FundStatusFilter.all;
        _fundsStream = _createFundsStream();
      });
    }
  }

  Stream<List<FundModel>> _createFundsStream() {
    return _fundService.streamFunds(widget.labId);
  }

  void _refreshStream() {
    setState(() {
      _fundsStream = _createFundsStream();
    });
  }

  void _selectStatusFilter(_FundStatusFilter filter) {
    if (_statusFilter == filter) {
      return;
    }

    setState(() {
      _statusFilter = filter;
    });
  }

  bool get _canManageFunds => AppState.instance.isPiAdmin;

  String get _currentUserIdentity {
    final userId = AppState.instance.authenticatedUserId.trim();
    if (userId.isNotEmpty) {
      return userId;
    }

    return AppState.instance.authenticatedUserEmail.trim();
  }

  bool _canEditFund(FundModel fund) {
    if (!_canManageFunds) {
      return false;
    }

    final status = fund.effectiveStatus;
    return status == FundModel.statusActive ||
        status == FundModel.statusExpired;
  }

  bool _canCloseFund(FundModel fund) {
    if (!_canManageFunds) {
      return false;
    }

    final status = fund.effectiveStatus;
    return status == FundModel.statusActive ||
        status == FundModel.statusExpired;
  }

  Future<bool?> _openFundForm({FundModel? initialFund}) async {
    if (!_canManageFunds) {
      return false;
    }

    final isEditing = initialFund != null;
    final isDesktopModal = MediaQuery.sizeOf(context).width >= 720;
    return isDesktopModal
        ? showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: _FundFormCard(
                    labId: widget.labId,
                    currentUserIdentity: _currentUserIdentity,
                    fundService: _fundService,
                    isBottomSheet: false,
                    initialFund: initialFund,
                    isEditing: isEditing,
                  ),
                ),
              );
            },
          )
        : showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            isDismissible: false,
            enableDrag: false,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (sheetContext) {
              final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
              return Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset + 12),
                child: _FundFormCard(
                  labId: widget.labId,
                  currentUserIdentity: _currentUserIdentity,
                  fundService: _fundService,
                  isBottomSheet: true,
                  initialFund: initialFund,
                  isEditing: isEditing,
                ),
              );
            },
          );
  }

  Future<void> _openAddFundFlow() async {
    if (!_canManageFunds) {
      return;
    }

    final result = await _openFundForm();

    if (result == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fund added successfully.')));
    }
  }

  Future<void> _openEditFundFlow(FundModel fund) async {
    if (!_canEditFund(fund)) {
      return;
    }

    final result = await _openFundForm(initialFund: fund);
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fund updated successfully.')),
      );
    }
  }

  Future<void> _openCloseFundFlow(FundModel fund) async {
    if (!_canCloseFund(fund)) {
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _CloseFundDialog(
          fund: fund,
          labId: widget.labId,
          fundService: _fundService,
        );
      },
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fund closed successfully.')),
      );
    }
  }

  Future<void> _openFundHistoryFlow(FundModel fund) async {
    final isDesktopModal = MediaQuery.sizeOf(context).width >= 720;

    if (isDesktopModal) {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: _FundHistorySheet(
                fund: fund,
                labId: widget.labId,
                fundService: _fundService,
                isBottomSheet: false,
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
          heightFactor: 0.92,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _FundHistorySheet(
              fund: fund,
              labId: widget.labId,
              fundService: _fundService,
              isBottomSheet: true,
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPurchaseOrdersFlow() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PurchaseOrdersScreen(labId: widget.labId),
      ),
    );
  }

  String? _errorDetail(Object? error) {
    final message = FirestoreAccessGuard.messageFor(
      error,
      fallback: 'Unable to load funds.',
    );
    if (message.trim().isEmpty || message.trim() == 'Unable to load funds.') {
      return null;
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Funds & Expenditure')),
          body: SafeArea(
            child: ResponsivePageContainer(
              maxWidth: 1120,
              child: StreamBuilder<List<FundModel>>(
                stream: _fundsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _ErrorFundsState(
                      detail: _errorDetail(snapshot.error),
                      onRetry: _refreshStream,
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const _LoadingFundsState();
                  }

                  final funds = snapshot.data ?? const <FundModel>[];
                  final summary = _FundsSummary.fromFunds(funds);
                  final filteredFunds = _filterFundsByStatus(
                    funds,
                    _statusFilter,
                  );
                  final filterCounts = _FundStatusCounts.fromFunds(funds);

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 900;
                      final pagePadding = isDesktop ? 12.0 : 16.0;
                      final sectionGap = isDesktop ? 12.0 : 16.0;

                      return ListView(
                        padding: EdgeInsets.all(pagePadding),
                        children: [
                          _FundsHeaderCard(
                            totalFunds: summary.totalFunds,
                            dense: isDesktop,
                            canAddFunds: _canManageFunds,
                            onOpenPurchaseOrders: _openPurchaseOrdersFlow,
                            onAddFund: _openAddFundFlow,
                          ),
                          SizedBox(height: sectionGap),
                          _FundSummarySection(summary: summary),
                          SizedBox(height: sectionGap),
                          if (funds.isEmpty)
                            _EmptyFundsState(
                              canAddFunds: _canManageFunds,
                              onAddFund: _openAddFundFlow,
                            )
                          else ...[
                            _FundStatusFilterSection(
                              selectedFilter: _statusFilter,
                              counts: filterCounts,
                              onSelected: _selectStatusFilter,
                            ),
                            SizedBox(height: sectionGap),
                            if (filteredFunds.isEmpty)
                              _FilteredFundsEmptyState(filter: _statusFilter)
                            else
                              _FundsListSection(
                                funds: filteredFunds,
                                dense: isDesktop,
                                canManageFunds: _canManageFunds,
                                onEditFund: _openEditFundFlow,
                                onCloseFund: _openCloseFundFlow,
                                onViewHistory: _openFundHistoryFlow,
                                statusFilter: _statusFilter,
                                totalFundsInStream: funds.length,
                              ),
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FundsHeaderCard extends StatelessWidget {
  final int totalFunds;
  final bool dense;
  final bool canAddFunds;
  final VoidCallback onOpenPurchaseOrders;
  final VoidCallback onAddFund;

  const _FundsHeaderCard({
    required this.totalFunds,
    required this.dense,
    required this.canAddFunds,
    required this.onOpenPurchaseOrders,
    required this.onAddFund,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dense ? 16 : 18),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: dense ? 48 : 56,
            width: dense ? 48 : 56,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: colorScheme.primary,
              size: dense ? 24 : 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: dense && canAddFunds
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _FundsHeaderCopy(
                          totalFunds: totalFunds,
                          dense: dense,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _PurchaseOrdersButton(
                            onPressed: onOpenPurchaseOrders,
                          ),
                          _AddFundButton(onPressed: onAddFund),
                        ],
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FundsHeaderCopy(totalFunds: totalFunds, dense: dense),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _PurchaseOrdersButton(
                            onPressed: onOpenPurchaseOrders,
                          ),
                          if (canAddFunds) _AddFundButton(onPressed: onAddFund),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _FundsHeaderCopy extends StatelessWidget {
  final int totalFunds;
  final bool dense;

  const _FundsHeaderCopy({required this.totalFunds, required this.dense});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lab funds overview',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: dense ? 17 : 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          totalFunds == 0
              ? 'View sanctioned, available, and utilized balances across all funds in one place.'
              : '$totalFunds ${totalFunds == 1 ? 'fund' : 'funds'} currently tracked across active, expired, and closed tenure windows.',
          style: TextStyle(
            color: palette.subtleText,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _AddFundButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _AddFundButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: context.colorScheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text(
        'Add Fund',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PurchaseOrdersButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _PurchaseOrdersButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      icon: const Icon(Icons.folder_copy_outlined, size: 18),
      label: const Text(
        'Purchase Orders',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FundSummarySection extends StatelessWidget {
  final _FundsSummary summary;

  const _FundSummarySection({required this.summary});

  @override
  Widget build(BuildContext context) {
    const spacing = 12.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 980
            ? 3
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final cardWidth = columnCount == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (spacing * (columnCount - 1))) /
                  columnCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Total Funds',
                value: '${summary.totalFunds}',
                accentColor: const Color(0xFF0EA5E9),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                icon: Icons.payments_outlined,
                label: 'Total Sanctioned',
                value: _formatIndianCurrency(summary.totalSanctioned),
                accentColor: const Color(0xFFF59E0B),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                icon: Icons.savings_outlined,
                label: 'Total Available',
                value: _formatIndianCurrency(summary.totalAvailable),
                accentColor: const Color(0xFF10B981),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
  });

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
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: TextStyle(
              color: palette.subtleText,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _FundStatusFilterSection extends StatelessWidget {
  final _FundStatusFilter selectedFilter;
  final _FundStatusCounts counts;
  final ValueChanged<_FundStatusFilter> onSelected;

  const _FundStatusFilterSection({
    required this.selectedFilter,
    required this.counts,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final filters = _FundStatusFilter.values;

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
            'Status filters',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filters
                .map((filter) {
                  final isSelected = selectedFilter == filter;
                  final count = counts.countFor(filter);

                  return ChoiceChip(
                    label: Text('${_statusFilterChipLabel(filter)} $count'),
                    selected: isSelected,
                    selectedColor: colorScheme.primary.withValues(alpha: 0.16),
                    backgroundColor: palette.panelAlt,
                    side: BorderSide(
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.28)
                          : palette.border,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? colorScheme.primary
                          : palette.mutedText,
                      fontSize: 12.6,
                      fontWeight: FontWeight.w700,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => onSelected(filter),
                  );
                })
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _FundsListSection extends StatelessWidget {
  final List<FundModel> funds;
  final bool dense;
  final bool canManageFunds;
  final ValueChanged<FundModel> onEditFund;
  final ValueChanged<FundModel> onCloseFund;
  final ValueChanged<FundModel> onViewHistory;
  final _FundStatusFilter statusFilter;
  final int totalFundsInStream;

  const _FundsListSection({
    required this.funds,
    required this.dense,
    required this.canManageFunds,
    required this.onEditFund,
    required this.onCloseFund,
    required this.onViewHistory,
    required this.statusFilter,
    required this.totalFundsInStream,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _statusFilterHeading(statusFilter),
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: dense ? 17 : 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _statusFilterDescription(
                  statusFilter,
                  matchingCount: funds.length,
                  totalCount: totalFundsInStream,
                ),
                style: TextStyle(
                  color: palette.subtleText,
                  fontSize: 12.8,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        ...funds.map((fund) {
          final canManageThisFund =
              canManageFunds &&
              (fund.effectiveStatus == FundModel.statusActive ||
                  fund.effectiveStatus == FundModel.statusExpired);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _FundCard(
              fund: fund,
              onClose: canManageThisFund ? () => onCloseFund(fund) : null,
              onEdit: canManageThisFund ? () => onEditFund(fund) : null,
              onViewHistory: () => onViewHistory(fund),
            ),
          );
        }),
      ],
    );
  }
}

class _FundCard extends StatelessWidget {
  final FundModel fund;
  final VoidCallback? onEdit;
  final VoidCallback? onClose;
  final VoidCallback onViewHistory;

  const _FundCard({
    required this.fund,
    required this.onEdit,
    required this.onClose,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final cleanCode = fund.fundCode?.trim();
    final cleanNotes = fund.notes?.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _FundIdentityBlock(
                        fundName: fund.fundName,
                        fundCode: cleanCode,
                        tenureText: _formatFundTenure(
                          fund.startDate,
                          fund.endDate,
                        ),
                        isWide: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _FundCardActions(
                      status: fund.effectiveStatus,
                      onEdit: onEdit,
                      onClose: onClose,
                      onViewHistory: onViewHistory,
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _FundIdentityBlock(
                        fundName: fund.fundName,
                        fundCode: cleanCode,
                        tenureText: _formatFundTenure(
                          fund.startDate,
                          fund.endDate,
                        ),
                        isWide: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _FundCardActions(
                      status: fund.effectiveStatus,
                      onEdit: onEdit,
                      onClose: onClose,
                      onViewHistory: onViewHistory,
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              _FundDateSection(
                startDate: fund.startDate,
                endDate: fund.endDate,
              ),
              const SizedBox(height: 14),
              _FundAmountSection(fund: fund),
              if (cleanNotes != null && cleanNotes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
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
                      Text(
                        'Notes',
                        style: TextStyle(
                          color: palette.subtleText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cleanNotes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FundCardActions extends StatelessWidget {
  final String status;
  final VoidCallback? onEdit;
  final VoidCallback? onClose;
  final VoidCallback onViewHistory;

  const _FundCardActions({
    required this.status,
    required this.onEdit,
    required this.onClose,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    final hasActions = true;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (hasActions)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: PopupMenuButton<_FundCardMenuAction>(
              tooltip: 'Fund actions',
              onSelected: (action) {
                switch (action) {
                  case _FundCardMenuAction.history:
                    onViewHistory();
                    break;
                  case _FundCardMenuAction.edit:
                    onEdit?.call();
                    break;
                  case _FundCardMenuAction.close:
                    onClose?.call();
                    break;
                }
              },
              itemBuilder: (context) {
                return [
                  const PopupMenuItem<_FundCardMenuAction>(
                    value: _FundCardMenuAction.history,
                    child: _FundCardMenuRow(
                      icon: Icons.history_outlined,
                      label: 'View history',
                    ),
                  ),
                  if (onEdit != null)
                    const PopupMenuItem<_FundCardMenuAction>(
                      value: _FundCardMenuAction.edit,
                      child: _FundCardMenuRow(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                      ),
                    ),
                  if (onClose != null)
                    const PopupMenuItem<_FundCardMenuAction>(
                      value: _FundCardMenuAction.close,
                      child: _FundCardMenuRow(
                        icon: Icons.lock_outline,
                        label: 'Close Fund',
                      ),
                    ),
                ];
              },
              icon: const Icon(Icons.more_vert_rounded),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: const EdgeInsets.all(8),
            ),
          ),
        _StatusBadge(status: status),
      ],
    );
  }
}

enum _FundCardMenuAction { history, edit, close }

class _FundCardMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FundCardMenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.onSurface),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: palette.mutedText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CloseFundDialog extends StatefulWidget {
  final FundModel fund;
  final String labId;
  final FundService fundService;

  const _CloseFundDialog({
    required this.fund,
    required this.labId,
    required this.fundService,
  });

  @override
  State<_CloseFundDialog> createState() => _CloseFundDialogState();
}

class _CloseFundDialogState extends State<_CloseFundDialog> {
  bool _isClosing = false;
  String? _submitError;

  String get _fundName {
    final cleaned = widget.fund.fundName.trim();
    return cleaned.isEmpty ? 'Untitled fund' : cleaned;
  }

  Future<void> _closeFund() async {
    if (_isClosing) {
      return;
    }

    final cleanLabId = widget.labId.trim();
    final cleanFundId = widget.fund.id.trim();
    if (cleanLabId.isEmpty || cleanFundId.isEmpty) {
      setState(() {
        _submitError =
            'This fund is missing required identifiers and cannot be closed right now.';
      });
      return;
    }

    setState(() {
      _isClosing = true;
      _submitError = null;
    });

    try {
      await widget.fundService.closeFund(
        labId: cleanLabId,
        fundId: cleanFundId,
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
        _submitError = _readableFundErrorMessage(
          error,
          fallback: 'Could not close fund.',
        );
        _isClosing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return PopScope(
      canPop: !_isClosing,
      child: AlertDialog(
        backgroundColor: colorScheme.surface,
        title: const Text('Close this fund?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_submitError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: palette.danger.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    _submitError!,
                    style: TextStyle(
                      color: palette.danger,
                      fontSize: 12.8,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                'The fund will remain in expenditure history but cannot be selected for future allocations.',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: 13.2,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Fund: $_fundName',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 13.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isClosing
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _isClosing ? null : _closeFund,
            child: _isClosing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Close Fund'),
          ),
        ],
      ),
    );
  }
}

class _FundHistorySheet extends StatefulWidget {
  final FundModel fund;
  final String labId;
  final FundService fundService;
  final bool isBottomSheet;

  const _FundHistorySheet({
    required this.fund,
    required this.labId,
    required this.fundService,
    required this.isBottomSheet,
  });

  @override
  State<_FundHistorySheet> createState() => _FundHistorySheetState();
}

class _FundHistorySheetState extends State<_FundHistorySheet> {
  late Stream<List<FundTransactionModel>> _transactionsStream;

  @override
  void initState() {
    super.initState();
    _transactionsStream = _createTransactionsStream();
  }

  Stream<List<FundTransactionModel>> _createTransactionsStream() {
    return widget.fundService.streamFundTransactions(
      labId: widget.labId,
      fundId: widget.fund.id,
    );
  }

  void _refreshTransactions() {
    setState(() {
      _transactionsStream = _createTransactionsStream();
    });
  }

  String? _historyErrorDetail(Object? error) {
    final message = FirestoreAccessGuard.messageFor(
      error,
      fallback: 'Unable to load fund history.',
    );
    if (message.trim().isEmpty ||
        message.trim() == 'Unable to load fund history.') {
      return null;
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final cleanFundCode = _normalizedOptionalText(widget.fund.fundCode);

    return Container(
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(widget.isBottomSheet ? 24 : 28),
        border: Border.all(color: palette.border),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
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
                            'Fund transaction history',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.fund.fundName.trim().isEmpty
                                ? 'Untitled fund'
                                : widget.fund.fundName.trim(),
                            style: TextStyle(
                              color: palette.mutedText,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
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
                _FundHistoryHeaderSummary(
                  fundCode: cleanFundCode,
                  availableAmount: widget.fund.availableAmount,
                  totalAmount: widget.fund.totalAmount,
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: StreamBuilder<List<FundTransactionModel>>(
                    stream: _transactionsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _FundHistoryErrorState(
                          detail: _historyErrorDetail(snapshot.error),
                          onRetry: _refreshTransactions,
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const _FundHistoryLoadingState();
                      }

                      final transactions =
                          snapshot.data ?? const <FundTransactionModel>[];
                      if (transactions.isEmpty) {
                        return const _FundHistoryEmptyState();
                      }

                      final summary = _FundHistorySummary.fromTransactions(
                        transactions,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FundHistoryTotals(summary: summary),
                          const SizedBox(height: 14),
                          Expanded(
                            child: ListView.separated(
                              itemCount: transactions.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                return _FundTransactionCard(
                                  transaction: transactions[index],
                                  currentFundDisplayName:
                                      widget.fund.fundName.trim().isNotEmpty
                                      ? widget.fund.fundName.trim()
                                      : cleanFundCode ?? '',
                                );
                              },
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
      ),
    );
  }
}

class _FundHistoryHeaderSummary extends StatelessWidget {
  final String? fundCode;
  final double availableAmount;
  final double totalAmount;

  const _FundHistoryHeaderSummary({
    required this.fundCode,
    required this.availableAmount,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fundCode != null && fundCode!.isNotEmpty) ...[
            Text(
              'Code: ${fundCode!}',
              style: TextStyle(
                color: palette.subtleText,
                fontSize: 12.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FundHistoryTopStat(
                label: 'Available amount',
                value: _formatIndianCurrency(availableAmount),
                icon: Icons.savings_outlined,
              ),
              _FundHistoryTopStat(
                label: 'Total sanctioned',
                value: _formatIndianCurrency(totalAmount),
                icon: Icons.payments_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FundHistoryTopStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _FundHistoryTopStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: palette.subtleText,
                    fontSize: 11.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 13.4,
                    fontWeight: FontWeight.w800,
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

class _FundHistoryTotals extends StatelessWidget {
  final _FundHistorySummary summary;

  const _FundHistoryTotals({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _FundHistoryTotalTile(
          label: 'Total transactions',
          value: summary.totalTransactions.toString(),
          icon: Icons.receipt_long_outlined,
        ),
        _FundHistoryTotalTile(
          label: 'Total allocated',
          value: _formatIndianCurrency(summary.totalAllocated),
          icon: Icons.account_balance_wallet_outlined,
        ),
      ],
    );
  }
}

class _FundHistoryTotalTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _FundHistoryTotalTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: palette.subtleText,
                    fontSize: 11.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 13.6,
                    fontWeight: FontWeight.w800,
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

class _FundTransactionCard extends StatelessWidget {
  final FundTransactionModel transaction;
  final String currentFundDisplayName;

  const _FundTransactionCard({
    required this.transaction,
    required this.currentFundDisplayName,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final cleanNotes = _normalizedOptionalText(transaction.notes);
    final cleanRequirementId = transaction.requirementId.trim();
    final snapshotFundName = transaction.fundDisplayName.trim();
    final shouldShowSnapshotFund =
        snapshotFundName.isNotEmpty &&
        snapshotFundName.toLowerCase() != currentFundDisplayName.toLowerCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
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
                      _transactionValueLabel(transaction.type),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      transaction.itemNameSnapshot.trim().isEmpty
                          ? 'Unnamed item'
                          : transaction.itemNameSnapshot.trim(),
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: 13.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _formatIndianCurrency(transaction.amount),
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 14.4,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.schedule_outlined,
                label: _formatHistoryDateTime(transaction.createdAt),
              ),
              _MetaChip(
                icon: Icons.person_outline_rounded,
                label:
                    'Created by: ${transaction.createdBy.trim().isEmpty ? '-' : transaction.createdBy.trim()}',
              ),
              _MetaChip(
                icon: Icons.flag_outlined,
                label: 'Status: ${_transactionValueLabel(transaction.status)}',
              ),
              if (cleanRequirementId.isNotEmpty)
                _MetaChip(
                  icon: Icons.link_outlined,
                  label: 'Requirement: $cleanRequirementId',
                ),
              if (shouldShowSnapshotFund)
                _MetaChip(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Snapshot fund: $snapshotFundName',
                ),
            ],
          ),
          if (cleanNotes != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.panelAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.border),
              ),
              child: Text(
                cleanNotes,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 12.8,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FundHistoryLoadingState extends StatelessWidget {
  const _FundHistoryLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _FundHistoryErrorState extends StatelessWidget {
  final String? detail;
  final VoidCallback onRetry;

  const _FundHistoryErrorState({required this.detail, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: palette.panelAlt,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_toggle_off_rounded,
                color: palette.danger,
                size: 34,
              ),
              const SizedBox(height: 12),
              Text(
                'Unable to load fund history.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
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
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FundHistoryEmptyState extends StatelessWidget {
  const _FundHistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: palette.panelAlt,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_outlined,
                color: colorScheme.primary,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                'No transactions have been recorded for this fund yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FundHistorySummary {
  final int totalTransactions;
  final double totalAllocated;

  const _FundHistorySummary({
    required this.totalTransactions,
    required this.totalAllocated,
  });

  factory _FundHistorySummary.fromTransactions(
    List<FundTransactionModel> transactions,
  ) {
    final totalAllocated = transactions.fold<double>(0, (sum, transaction) {
      if (transaction.isAllocation && transaction.isActive) {
        return sum + _safeAmount(transaction.amount);
      }
      return sum;
    });

    return _FundHistorySummary(
      totalTransactions: transactions.length,
      totalAllocated: totalAllocated,
    );
  }
}

class _FundIdentityBlock extends StatelessWidget {
  final String fundName;
  final String? fundCode;
  final String tenureText;
  final bool isWide;

  const _FundIdentityBlock({
    required this.fundName,
    required this.fundCode,
    required this.tenureText,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fundName.trim().isEmpty ? 'Untitled fund' : fundName.trim(),
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: isWide ? 17 : 16,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (fundCode != null && fundCode!.isNotEmpty)
              _MetaChip(icon: Icons.badge_outlined, label: fundCode!),
            _MetaChip(icon: Icons.date_range_outlined, label: tenureText),
          ],
        ),
      ],
    );
  }
}

class _FundDateSection extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;

  const _FundDateSection({required this.startDate, required this.endDate});

  @override
  Widget build(BuildContext context) {
    const spacing = 10.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 620
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: itemWidth,
              child: _InfoTile(
                label: 'Start date',
                value: _formatFundDate(startDate),
                icon: Icons.event_available_outlined,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _InfoTile(
                label: 'End date',
                value: _formatFundDate(endDate),
                icon: Icons.event_busy_outlined,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FundAmountSection extends StatelessWidget {
  final FundModel fund;

  const _FundAmountSection({required this.fund});

  @override
  Widget build(BuildContext context) {
    const spacing = 10.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 960
            ? 3
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final itemWidth = columnCount == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (spacing * (columnCount - 1))) /
                  columnCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: itemWidth,
              child: _AmountTile(
                label: 'Total amount',
                value: _formatIndianCurrency(fund.totalAmount),
                icon: Icons.payments_outlined,
                accentColor: const Color(0xFFF59E0B),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _AmountTile(
                label: 'Available amount',
                value: _formatIndianCurrency(fund.availableAmount),
                icon: Icons.savings_outlined,
                accentColor: const Color(0xFF10B981),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _AmountTile(
                label: 'Utilized amount',
                value: _formatIndianCurrency(fund.utilizedAmount),
                icon: Icons.bar_chart_rounded,
                accentColor: const Color(0xFF0EA5E9),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AmountTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;

  const _AmountTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: palette.subtleText,
                    fontSize: 11.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
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

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: palette.subtleText,
                    fontSize: 11.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
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

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(context, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: colors.foreground,
          fontSize: 12.2,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  _StatusPalette _statusColors(BuildContext context, String value) {
    final palette = context.labmate;

    switch (value) {
      case FundModel.statusClosed:
        return _StatusPalette(
          background: palette.panelAlt,
          border: palette.border,
          foreground: palette.mutedText,
        );
      case FundModel.statusExpired:
        return _StatusPalette(
          background: palette.warning.withValues(alpha: 0.14),
          border: palette.warning.withValues(alpha: 0.28),
          foreground: palette.warning,
        );
      case FundModel.statusActive:
      default:
        return _StatusPalette(
          background: palette.success.withValues(alpha: 0.14),
          border: palette.success.withValues(alpha: 0.28),
          foreground: palette.success,
        );
    }
  }
}

class _LoadingFundsState extends StatelessWidget {
  const _LoadingFundsState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorFundsState extends StatelessWidget {
  final String? detail;
  final VoidCallback onRetry;

  const _ErrorFundsState({required this.detail, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: palette.panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: palette.danger,
                size: 34,
              ),
              const SizedBox(height: 12),
              Text(
                'Unable to load funds.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
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
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFundsState extends StatelessWidget {
  final bool canAddFunds;
  final VoidCallback onAddFund;

  const _EmptyFundsState({required this.canAddFunds, required this.onAddFund});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: palette.selected,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No funds have been added yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Once funds are created for this lab, their sanctioned, available, and utilized balances will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (canAddFunds) ...[
            const SizedBox(height: 16),
            _AddFundButton(onPressed: onAddFund),
          ],
        ],
      ),
    );
  }
}

class _FilteredFundsEmptyState extends StatelessWidget {
  final _FundStatusFilter filter;

  const _FilteredFundsEmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: palette.panelAlt,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.filter_list_off_rounded,
              color: colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _filteredEmptyTitle(filter),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try another status filter to view funds in a different state.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FundFormCard extends StatefulWidget {
  final String labId;
  final String currentUserIdentity;
  final FundService fundService;
  final bool isBottomSheet;
  final FundModel? initialFund;
  final bool isEditing;

  const _FundFormCard({
    required this.labId,
    required this.currentUserIdentity,
    required this.fundService,
    required this.isBottomSheet,
    required this.initialFund,
    required this.isEditing,
  });

  @override
  State<_FundFormCard> createState() => _FundFormCardState();
}

class _FundFormCardState extends State<_FundFormCard> {
  static const double _amountTolerance = 0.000001;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fundNameController = TextEditingController();
  final TextEditingController _fundCodeController = TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _isSaving = false;
  bool _showDateErrors = false;
  String? _submitError;

  bool get _isEditing => widget.isEditing;
  FundModel? get _initialFund => widget.initialFund;
  FundModel get _existingFund => _initialFund!;
  double get _utilizedAmount => _isEditing ? _existingFund.utilizedAmount : 0;

  @override
  void initState() {
    super.initState();
    final fund = _initialFund;
    if (fund == null) {
      return;
    }

    _fundNameController.text = fund.fundName.trim();
    _fundCodeController.text = fund.fundCode?.trim() ?? '';
    _totalAmountController.text = _formatAmountForInput(fund.totalAmount);
    _notesController.text = fund.notes?.trim() ?? '';
    _selectedStartDate = fund.startDate;
    _selectedEndDate = fund.endDate;
  }

  @override
  void dispose() {
    _fundNameController.dispose();
    _fundCodeController.dispose();
    _totalAmountController.dispose();
    _notesController.dispose();
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
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  String get _titleText => _isEditing ? 'Edit Fund' : 'Add Fund';

  String get _descriptionText {
    if (_isEditing) {
      return 'Update fund details. Available amount will be recalculated safely while preserving the amount already utilized.';
    }

    return 'Create a fund record for this lab. Available amount will start equal to the total sanctioned amount.';
  }

  String get _saveButtonText => _isEditing ? 'Update Fund' : 'Save Fund';

  String? get _startDateError {
    if (!_showDateErrors || _selectedStartDate != null) {
      return null;
    }
    return 'Select a start date.';
  }

  String? get _endDateError {
    if (!_showDateErrors) {
      return null;
    }

    if (_selectedEndDate == null) {
      return 'Select an end date.';
    }

    final startDate = _selectedStartDate;
    if (startDate != null &&
        _dateOnly(_selectedEndDate!).isBefore(_dateOnly(startDate))) {
      return 'End date cannot be before start date.';
    }

    return null;
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final initialDate = _selectedStartDate ?? _selectedEndDate ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 50),
      builder: (context, child) {
        return Theme(data: Theme.of(context), child: child!);
      },
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      _selectedStartDate = pickedDate;
      if (_selectedEndDate != null &&
          _dateOnly(_selectedEndDate!).isBefore(_dateOnly(pickedDate))) {
        _selectedEndDate = pickedDate;
      }
      _submitError = null;
    });
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final earliestDate = _selectedStartDate ?? DateTime(now.year - 20);
    final initialBase = _selectedEndDate ?? _selectedStartDate ?? now;
    final initialDate = _dateOnly(initialBase).isBefore(_dateOnly(earliestDate))
        ? earliestDate
        : initialBase;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: earliestDate,
      lastDate: DateTime(now.year + 50),
      builder: (context, child) {
        return Theme(data: Theme.of(context), child: child!);
      },
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      _selectedEndDate = pickedDate;
      _submitError = null;
    });
  }

  String? _validateFundName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Fund name is required.';
    }
    return null;
  }

  String? _validateTotalAmount(String? value) {
    final cleanValue = (value ?? '').trim();
    if (cleanValue.isEmpty) {
      return 'Total amount is required.';
    }

    final parsedAmount = double.tryParse(cleanValue);
    if (parsedAmount == null || !parsedAmount.isFinite) {
      return 'Enter a valid total amount.';
    }

    if (parsedAmount <= 0) {
      return 'Total amount must be greater than zero.';
    }

    if (_isEditing && parsedAmount < _utilizedAmount - _amountTolerance) {
      return 'Cannot go below utilized amount.';
    }

    return null;
  }

  bool _validateDates() {
    setState(() {
      _showDateErrors = true;
    });

    return _startDateError == null && _endDateError == null;
  }

  void _clearSubmitError() {
    if (_submitError != null) {
      setState(() {
        _submitError = null;
      });
    }
  }

  String _amountReductionMessage(double utilizedAmount) {
    final formattedUtilized = _formatIndianCurrency(utilizedAmount);
    return 'This fund has already utilized $formattedUtilized.\n'
        'The total amount cannot be reduced below $formattedUtilized.';
  }

  Future<void> _saveFund() async {
    if (_isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

    final isFormValid = _formKey.currentState?.validate() ?? false;
    final hasValidDates = _validateDates();
    if (!isFormValid || !hasValidDates) {
      return;
    }

    final creatorIdentity = widget.currentUserIdentity.trim();
    if (creatorIdentity.isEmpty) {
      setState(() {
        _submitError = 'User information is missing. Please sign in again.';
      });
      return;
    }

    final totalAmount = double.tryParse(_totalAmountController.text.trim());
    if (totalAmount == null || !totalAmount.isFinite || totalAmount <= 0) {
      setState(() {
        _submitError = 'Total amount must be greater than zero.';
      });
      return;
    }

    if (_isEditing && totalAmount < _utilizedAmount - _amountTolerance) {
      setState(() {
        _submitError = _amountReductionMessage(_utilizedAmount);
      });
      return;
    }

    final startDate = _selectedStartDate;
    final endDate = _selectedEndDate;
    if (startDate == null || endDate == null) {
      setState(() {
        _submitError = 'Start date and end date are required.';
      });
      return;
    }

    if (_dateOnly(endDate).isBefore(_dateOnly(startDate))) {
      setState(() {
        _submitError = 'End date cannot be before start date.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _submitError = null;
    });

    try {
      if (_isEditing) {
        final updatedFund = _existingFund.copyWith(
          fundName: _fundNameController.text.trim(),
          fundCode: _normalizedOptionalText(_fundCodeController.text),
          totalAmount: totalAmount,
          startDate: startDate,
          endDate: endDate,
          notes: _normalizedOptionalText(_notesController.text),
        );

        await widget.fundService.updateFund(
          labId: widget.labId,
          fund: updatedFund,
        );
      } else {
        final fund = FundModel(
          id: '',
          labId: widget.labId.trim(),
          fundName: _fundNameController.text.trim(),
          fundCode: _normalizedOptionalText(_fundCodeController.text),
          totalAmount: totalAmount,
          availableAmount: totalAmount,
          startDate: startDate,
          endDate: endDate,
          notes: _normalizedOptionalText(_notesController.text),
          status: FundModel.statusActive,
          createdBy: creatorIdentity,
          createdAt: null,
          updatedAt: null,
        );

        await widget.fundService.addFund(labId: widget.labId, fund: fund);
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submitError = _readableFundErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(widget.isBottomSheet ? 24 : 28),
        border: Border.all(color: palette.border),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 680;
                final fieldWidth = isWide
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: widget.isBottomSheet
                          ? Container(
                              width: 42,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: palette.border,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _titleText,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _descriptionText,
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
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.of(context).pop(),
                          tooltip: 'Close',
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (_submitError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: palette.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: palette.danger.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          _submitError!,
                          style: TextStyle(
                            color: palette.danger,
                            fontSize: 12.8,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _fundNameController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: _inputDecoration('Fund name *'),
                      textInputAction: TextInputAction.next,
                      validator: _validateFundName,
                      onChanged: (_) => _clearSubmitError(),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: fieldWidth,
                          child: TextFormField(
                            controller: _fundCodeController,
                            style: TextStyle(color: colorScheme.onSurface),
                            decoration: _inputDecoration('Fund code'),
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => _clearSubmitError(),
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: TextFormField(
                            controller: _totalAmountController,
                            style: TextStyle(color: colorScheme.onSurface),
                            decoration: _inputDecoration('Total amount *'),
                            textInputAction: TextInputAction.next,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: _validateTotalAmount,
                            onChanged: (_) => _clearSubmitError(),
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: _DatePickerField(
                            label: 'Start date *',
                            value: _selectedStartDate == null
                                ? 'Select start date'
                                : _formatFundDate(_selectedStartDate!),
                            icon: Icons.event_available_outlined,
                            errorText: _startDateError,
                            onTap: _pickStartDate,
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: _DatePickerField(
                            label: 'End date *',
                            value: _selectedEndDate == null
                                ? 'Select end date'
                                : _formatFundDate(_selectedEndDate!),
                            icon: Icons.event_busy_outlined,
                            errorText: _endDateError,
                            onTap: _pickEndDate,
                          ),
                        ),
                      ],
                    ),
                    if (_isEditing) ...[
                      const SizedBox(height: 12),
                      _FundEditAmountContext(
                        utilizedAmount: _utilizedAmount,
                        availableAmount: _existingFund.availableAmount,
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: _inputDecoration('Notes'),
                      minLines: 3,
                      maxLines: 4,
                      onChanged: (_) => _clearSubmitError(),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.end,
                      children: [
                        SizedBox(
                          width: isWide ? 180 : constraints.maxWidth,
                          child: OutlinedButton(
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        SizedBox(
                          width: isWide ? 220 : constraints.maxWidth,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveFund,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(_saveButtonText),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FundEditAmountContext extends StatelessWidget {
  final double utilizedAmount;
  final double availableAmount;

  const _FundEditAmountContext({
    required this.utilizedAmount,
    required this.availableAmount,
  });

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
          Text(
            'Amount context',
            style: TextStyle(
              color: palette.subtleText,
              fontSize: 11.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Already utilized: ${_formatIndianCurrency(utilizedAmount)}',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Currently available: ${_formatIndianCurrency(availableAmount)}',
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

class _DatePickerField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? errorText;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.errorText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                color: palette.mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: palette.panelAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              errorText: null,
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: value.startsWith('Select ')
                          ? palette.subtleText
                          : colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(
              errorText!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _FundsSummary {
  final int totalFunds;
  final double totalSanctioned;
  final double totalAvailable;

  const _FundsSummary({
    required this.totalFunds,
    required this.totalSanctioned,
    required this.totalAvailable,
  });

  factory _FundsSummary.fromFunds(List<FundModel> funds) {
    return _FundsSummary(
      totalFunds: funds.length,
      totalSanctioned: funds.fold<double>(
        0,
        (sum, fund) => sum + _safeAmount(fund.totalAmount),
      ),
      totalAvailable: funds.fold<double>(
        0,
        (sum, fund) => sum + _safeAmount(fund.availableAmount),
      ),
    );
  }
}

class _FundStatusCounts {
  final int all;
  final int active;
  final int expired;
  final int closed;

  const _FundStatusCounts({
    required this.all,
    required this.active,
    required this.expired,
    required this.closed,
  });

  factory _FundStatusCounts.fromFunds(List<FundModel> funds) {
    var activeCount = 0;
    var expiredCount = 0;
    var closedCount = 0;

    for (final fund in funds) {
      switch (fund.effectiveStatus) {
        case FundModel.statusClosed:
          closedCount++;
          break;
        case FundModel.statusExpired:
          expiredCount++;
          break;
        case FundModel.statusActive:
        default:
          activeCount++;
          break;
      }
    }

    return _FundStatusCounts(
      all: funds.length,
      active: activeCount,
      expired: expiredCount,
      closed: closedCount,
    );
  }

  int countFor(_FundStatusFilter filter) {
    switch (filter) {
      case _FundStatusFilter.all:
        return all;
      case _FundStatusFilter.active:
        return active;
      case _FundStatusFilter.expired:
        return expired;
      case _FundStatusFilter.closed:
        return closed;
    }
  }
}

class _StatusPalette {
  final Color background;
  final Color border;
  final Color foreground;

  const _StatusPalette({
    required this.background,
    required this.border,
    required this.foreground,
  });
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

String _formatIndianCurrency(double value) {
  final normalizedValue = _safeAmount(value);
  if (!normalizedValue.isFinite) {
    return '₹0';
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
    return '$sign₹$groupedInteger';
  }

  return '$sign₹$groupedInteger.$decimalPart';
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

String _formatFundDate(DateTime value) {
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

String _formatFundTenure(DateTime startDate, DateTime endDate) {
  return '${_formatFundDate(startDate)} - ${_formatFundDate(endDate)}';
}

String _formatAmountForInput(double value) {
  final normalized = _safeAmount(value);
  if (!normalized.isFinite) {
    return '';
  }

  if (normalized == normalized.roundToDouble()) {
    return normalized.toStringAsFixed(0);
  }

  return normalized.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

String _statusLabel(String status) {
  switch (status) {
    case FundModel.statusClosed:
      return 'Closed';
    case FundModel.statusExpired:
      return 'Expired';
    case FundModel.statusActive:
    default:
      return 'Active';
  }
}

String _transactionValueLabel(String rawValue) {
  final cleaned = rawValue.trim();
  if (cleaned.isEmpty) {
    return 'Unknown';
  }

  final withSpaces = cleaned
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      );
  final words = withSpaces
      .split(RegExp(r'\s+'))
      .where((word) => word.trim().isNotEmpty)
      .map((word) {
        final lower = word.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .toList(growable: false);

  return words.isEmpty ? 'Unknown' : words.join(' ');
}

String _formatHistoryDateTime(DateTime? value) {
  if (value == null) {
    return 'Date unavailable';
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

List<FundModel> _filterFundsByStatus(
  List<FundModel> funds,
  _FundStatusFilter filter,
) {
  if (filter == _FundStatusFilter.all) {
    return funds;
  }

  String targetStatus;
  switch (filter) {
    case _FundStatusFilter.all:
      targetStatus = '';
      break;
    case _FundStatusFilter.active:
      targetStatus = FundModel.statusActive;
      break;
    case _FundStatusFilter.expired:
      targetStatus = FundModel.statusExpired;
      break;
    case _FundStatusFilter.closed:
      targetStatus = FundModel.statusClosed;
      break;
  }

  return funds
      .where((fund) => fund.effectiveStatus == targetStatus)
      .toList(growable: false);
}

String _statusFilterChipLabel(_FundStatusFilter filter) {
  switch (filter) {
    case _FundStatusFilter.all:
      return 'All';
    case _FundStatusFilter.active:
      return 'Active';
    case _FundStatusFilter.expired:
      return 'Expired';
    case _FundStatusFilter.closed:
      return 'Closed';
  }
}

String _statusFilterHeading(_FundStatusFilter filter) {
  switch (filter) {
    case _FundStatusFilter.all:
      return 'All Funds';
    case _FundStatusFilter.active:
      return 'Active Funds';
    case _FundStatusFilter.expired:
      return 'Expired Funds';
    case _FundStatusFilter.closed:
      return 'Closed Funds';
  }
}

String _statusFilterDescription(
  _FundStatusFilter filter, {
  required int matchingCount,
  required int totalCount,
}) {
  if (filter == _FundStatusFilter.all) {
    return 'Sorted by active, expired, and closed status, then by newest tenure.';
  }

  final label = _statusFilterChipLabel(filter).toLowerCase();
  final noun = matchingCount == 1 ? 'fund' : 'funds';
  return 'Showing $matchingCount of $totalCount $noun with $label status.';
}

String _filteredEmptyTitle(_FundStatusFilter filter) {
  switch (filter) {
    case _FundStatusFilter.all:
      return 'No funds found.';
    case _FundStatusFilter.active:
      return 'No active funds found.';
    case _FundStatusFilter.expired:
      return 'No expired funds found.';
    case _FundStatusFilter.closed:
      return 'No closed funds found.';
  }
}

String? _normalizedOptionalText(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

String _readableFundErrorMessage(
  Object error, {
  String fallback = 'Could not add fund.',
}) {
  if (error is ArgumentError) {
    final message = error.message?.toString().trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
  }

  if (error is StateError) {
    final message = error.message.trim();
    if (message.isNotEmpty) {
      return message;
    }
  }

  final raw = FirestoreAccessGuard.messageFor(error, fallback: fallback).trim();
  if (raw.startsWith('Invalid argument(s): ')) {
    return raw.substring('Invalid argument(s): '.length).trim();
  }

  return raw.isEmpty ? fallback : raw;
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}
