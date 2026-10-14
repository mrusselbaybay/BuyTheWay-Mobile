import 'package:flutter/material.dart';

import '../../driver/driver_theme.dart';
import '../../driver/settings/widgets/settings_widgets.dart';
import '../buyer_models.dart';
import '../buyer_store.dart';
import '../widgets/buyer_widgets.dart';
import 'settings_kit.dart';

/// Saved cards and e-wallets for faster checkout. Only display-safe data is
/// stored server-side (brand, last 4, expiry / masked number).
class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final store = BuyerStore.instance;
  List<PaymentMethod>? methods;
  String? error;
  String? removingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => error = null);
    try {
      final list = await store.api.paymentMethods();
      if (mounted) setState(() => methods = list);
    } catch (e) {
      if (mounted) setState(() => error = store.handleError(e));
    }
  }

  Future<void> _delete(PaymentMethod m) async {
    final ok = await confirmDialog(context, title: 'Remove ${m.display}?', message: 'This saved method cannot currently be used at checkout.', confirmLabel: 'Remove', destructive: true);
    if (!ok || !mounted) return;
    setState(() => removingId = m.id);
    try {
      await store.api.deletePaymentMethod(m.id);
      await _load();
      if (mounted) showToast(context, 'Removed ${m.display}');
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    } finally {
      if (mounted) setState(() => removingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = methods;
    if (list == null) {
      return Scaffold(
        backgroundColor: DriverColors.background,
        appBar: settingsAppBar('Payment Methods'),
        body: error != null ? ErrorState(message: error!, onRetry: _load) : const Padding(padding: EdgeInsets.all(16), child: RowsSkeleton(count: 2)),
      );
    }
    return SettingsPage(title: 'Payment Methods', onRefresh: _load, children: [
      const SettingsSectionLabel('Available at checkout'),
      const SettingsGroupCard(children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            IconTile(Icons.payments_outlined, size: 40, color: DriverColors.success),
            SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Cash on Delivery', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: DriverColors.textPrimary)),
                SizedBox(height: 2),
                Text('Pay the courier when your parcel arrives', style: DriverText.caption),
              ]),
            ),
            StatusPill('Active', DriverColors.success, icon: Icons.check_circle_outline_rounded),
          ]),
        ),
      ]),
      const SizedBox(height: 10),
      const SettingsInfoNote('Only cash on delivery is available right now. Card and e-wallet payments are coming later.'),
      if (list.isNotEmpty) ...[
        kSettingsGap,
        const SettingsSectionLabel('Previously saved'),
        SettingsGroupCard(children: [
          for (final m in list)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(children: [
                IconTile(m.type == 'card' ? Icons.credit_card_rounded : Icons.account_balance_wallet_outlined, size: 40, color: DriverColors.textSecondary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text(m.display, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: DriverColors.textPrimary)),
                      if (m.isPrimary) const StatusPill('Primary', DriverColors.primary),
                    ]),
                    const SizedBox(height: 2),
                    Text(m.type == 'card' ? [m.holder, if (m.expiry != null) 'Exp ${m.expiry}'].whereType<String>().join(' · ') : 'E-wallet', style: DriverText.caption),
                  ]),
                ),
                removingId == m.id
                    ? Padding(padding: const EdgeInsets.all(14), child: settingsSpinner())
                    : IconButton(tooltip: 'Remove', onPressed: () => _delete(m), icon: const Icon(Icons.delete_outline_rounded, color: DriverColors.error, size: 21)),
              ]),
            ),
        ]),
        const SizedBox(height: 8),
        const Padding(padding: EdgeInsets.only(left: 4), child: Text('These can\'t be used at checkout. You can remove them.', style: DriverText.caption)),
      ],
    ]);
  }
}
