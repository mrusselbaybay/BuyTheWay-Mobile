import 'package:flutter/material.dart';

import '../driver_models.dart';
import '../driver_theme.dart';
import '../widgets/driver_shared_widgets.dart';

enum _EarningsPeriod { today, week, month }

class DriverEarningsScreen extends StatefulWidget {
  final double todayEarnings;
  final double availableBalance;
  final List<WithdrawalRecord> withdrawals;
  final void Function(double amount, String destination) onWithdraw;

  const DriverEarningsScreen({
    super.key,
    required this.todayEarnings,
    required this.availableBalance,
    required this.withdrawals,
    required this.onWithdraw,
  });

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  _EarningsPeriod _period = _EarningsPeriod.week;

  List<EarningsBreakdownLine> get _breakdown => switch (_period) {
        _EarningsPeriod.today => todayBreakdown,
        _EarningsPeriod.week => weekBreakdown,
        _EarningsPeriod.month => monthBreakdown,
      };

  double get _total => _breakdown.fold(0, (sum, e) => sum + e.amount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, foregroundColor: DriverColors.textPrimary, title: const Text('Earnings', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          _heroCard(),
          const SizedBox(height: 20),
          _balanceCard(context),
          const SizedBox(height: 20),
          const DriverSectionHeader(title: 'This week'),
          const SizedBox(height: 12),
          _weeklyChart(),
          const SizedBox(height: 20),
          const DriverSectionHeader(title: 'Breakdown'),
          const SizedBox(height: 12),
          _breakdownCard(),
          const SizedBox(height: 20),
          const DriverSectionHeader(title: 'Withdrawal history'),
          const SizedBox(height: 12),
          if (widget.withdrawals.isEmpty)
            const DriverEmptyState(icon: Icons.account_balance_wallet_outlined, title: 'No withdrawals yet', subtitle: 'Your withdrawal history will show up here.')
          else
            ...widget.withdrawals.map((w) => _withdrawalRow(w)),
        ],
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: DriverColors.primaryGradient),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: DriverColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total earnings', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12.5, fontWeight: FontWeight.w600)),
              _periodSelector(),
            ],
          ),
          const SizedBox(height: 10),
          Text('₱${_total.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _periodSelector() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _EarningsPeriod.values.map((p) {
          final selected = p == _period;
          final label = switch (p) {
            _EarningsPeriod.today => 'Day',
            _EarningsPeriod.week => 'Week',
            _EarningsPeriod.month => 'Month',
          };
          return GestureDetector(
            onTap: () => setState(() => _period = p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: selected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(16)),
              child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? DriverColors.primaryDark : Colors.white70)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _balanceCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Available balance', style: DriverText.caption),
                const SizedBox(height: 2),
                Text('₱${widget.availableBalance.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: DriverColors.textPrimary)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showWithdrawSheet(context),
            icon: const Icon(Icons.arrow_upward_rounded, size: 16),
            label: const Text('Withdraw'),
            style: ElevatedButton.styleFrom(backgroundColor: DriverColors.primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          ),
        ],
      ),
    );
  }

  void _showWithdrawSheet(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Withdraw funds', style: DriverText.title),
              const SizedBox(height: 4),
              Text('Available: ₱${widget.availableBalance.toStringAsFixed(0)}', style: DriverText.caption),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: '₱ ',
                  hintText: 'Amount to withdraw',
                  filled: true,
                  fillColor: DriverColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: DriverColors.primarySurface, borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, size: 16, color: DriverColors.primary),
                    SizedBox(width: 8),
                    Text('GCash •••• 4821', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: DriverColors.textPrimary)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final amount = double.tryParse(controller.text.trim());
                    if (amount == null || amount <= 0 || amount > widget.availableBalance) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(content: Text('Enter a valid amount within your available balance.'), behavior: SnackBarBehavior.floating),
                      );
                      return;
                    }
                    widget.onWithdraw(amount, 'GCash •••• 4821');
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('₱${amount.toStringAsFixed(0)} withdrawal requested.'), behavior: SnackBarBehavior.floating, backgroundColor: DriverColors.primaryDark),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: DriverColors.primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Confirm withdrawal', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _weeklyChart() {
    final maxAmount = weeklyEarningsChart.map((d) => d.amount).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: weeklyEarningsChart.map((day) {
                final isPeak = day.amount == maxAmount;
                final barHeight = 90 * (day.amount / maxAmount);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('₱${day.amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 8.5, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: barHeight),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (context, height, _) => Container(
                            height: height,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isPeak ? DriverColors.primaryGradient : const [DriverColors.primaryLight, DriverColors.primarySurface],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weeklyEarningsChart.map((d) => Expanded(child: Text(d.label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, color: Colors.grey[500], fontWeight: FontWeight.w600)))).toList(),
          ),
        ],
      ),
    );
  }

  Widget _breakdownCard() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        children: List.generate(_breakdown.length, (i) {
          final line = _breakdown[i];
          final negative = line.amount < 0;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(child: Text(line.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: DriverColors.textPrimary))),
                    Text(
                      '${negative ? '-' : ''}₱${line.amount.abs().toStringAsFixed(0)}',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: negative ? DriverColors.error : DriverColors.textPrimary),
                    ),
                  ],
                ),
              ),
              if (i != _breakdown.length - 1) const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          );
        }),
      ),
    );
  }

  Widget _withdrawalRow(WithdrawalRecord w) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: DriverColors.border)),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: DriverColors.primarySurface, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_upward_rounded, size: 16, color: DriverColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.destination, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                Text(_formatDate(w.requestedAt), style: DriverText.caption),
              ],
            ),
          ),
          Text('-₱${w.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: DriverColors.textPrimary)),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final local = d.toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }
}
