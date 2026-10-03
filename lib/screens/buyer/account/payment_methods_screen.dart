import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../payments_util.dart';
import '../widgets/buyer_widgets.dart';

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

  Future<void> _add() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(BRadius.md))),
      builder: (_) => _AddMethodSheet(isFirst: (methods ?? []).isEmpty),
    );
    if (added == true && mounted) {
      showToast(context, 'Payment method saved');
      _load();
    }
  }

  Future<void> _setPrimary(PaymentMethod m) async {
    try {
      await store.api.setPrimaryPaymentMethod(m.id);
      _load();
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    }
  }

  Future<void> _delete(PaymentMethod m) async {
    final ok = await confirmDialog(context, title: 'Remove ${m.display}?', message: 'You can add it again anytime.', confirmLabel: 'Remove', destructive: true);
    if (!ok) return;
    try {
      await store.api.deletePaymentMethod(m.id);
      _load();
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = methods;
    return Scaffold(
      backgroundColor: BColors.background,
      appBar: AppBar(
        backgroundColor: BColors.surface,
        surfaceTintColor: BColors.surface,
        foregroundColor: BColors.ink,
        title: const Text('Payment Methods', style: BText.title),
      ),
      body: list == null
          ? (error != null ? ErrorState(message: error!, onRetry: _load) : const Center(child: CircularProgressIndicator(color: BColors.brand)))
          : ListView(padding: const EdgeInsets.only(top: 8), children: [
              const Panel(
                child: Row(children: [
                  Icon(Icons.payments_outlined, color: BColors.brand),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Cash on Delivery', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('Always available at checkout', style: BText.tiny),
                    ]),
                  ),
                ]),
              ),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No saved cards or wallets yet. Save one here or at checkout to pay faster next time.', textAlign: TextAlign.center, style: BText.small),
                ),
              for (final m in list)
                Container(
                  color: BColors.surface,
                  margin: const EdgeInsets.only(bottom: 1),
                  child: ListTile(
                    leading: Icon(m.type == 'card' ? Icons.credit_card : Icons.account_balance_wallet_outlined, color: BColors.brand),
                    title: Row(children: [
                      Flexible(child: Text(m.display, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                      if (m.isPrimary) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(border: Border.all(color: BColors.cta), borderRadius: BorderRadius.circular(2)),
                          child: const Text('Primary', style: TextStyle(fontSize: 10.5, color: BColors.cta)),
                        ),
                      ],
                    ]),
                    subtitle: Text(
                      m.type == 'card' ? [m.holder, if (m.expiry != null) 'Exp ${m.expiry}'].whereType<String>().join(' · ') : 'E-wallet',
                      style: BText.tiny,
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'More',
                      onSelected: (v) => v == 'primary' ? _setPrimary(m) : _delete(m),
                      itemBuilder: (_) => [
                        if (!m.isPrimary) const PopupMenuItem(value: 'primary', child: Text('Set as primary')),
                        const PopupMenuItem(value: 'delete', child: Text('Remove', style: TextStyle(color: BColors.error))),
                      ],
                    ),
                  ),
                ),
            ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(onPressed: _add, style: BButtons.brand(height: 48), icon: const Icon(Icons.add), label: const Text('Add Card or Wallet')),
        ),
      ),
    );
  }
}

class _AddMethodSheet extends StatefulWidget {
  const _AddMethodSheet({required this.isFirst});

  final bool isFirst;

  @override
  State<_AddMethodSheet> createState() => _AddMethodSheetState();
}

class _AddMethodSheetState extends State<_AddMethodSheet> {
  final store = BuyerStore.instance;
  String type = 'card';
  String provider = 'GCash';
  final holder = TextEditingController();
  final number = TextEditingController();
  final expiry = TextEditingController();
  final phone = TextEditingController();
  late bool primary = widget.isFirst;
  bool saving = false;
  bool showErrors = false;

  @override
  void dispose() {
    for (final c in [holder, number, expiry, phone]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get problem {
    if (type == 'wallet') return validPhPhone(phone.text) ? null : 'Enter a valid mobile number (09XX XXX XXXX).';
    if (holder.text.trim().isEmpty) return 'Enter the cardholder name.';
    if (!luhnValid(number.text)) return 'Enter a valid card number.';
    final exp = parseExpiry(expiry.text);
    if (exp == null) return 'Enter the expiry as MM/YY.';
    if (expiryPassed(exp)) return 'This card has expired.';
    return null;
  }

  Future<void> _save() async {
    setState(() => showErrors = true);
    final p = problem;
    if (p != null) {
      showToast(context, p, error: true);
      return;
    }
    setState(() => saving = true);
    try {
      if (type == 'card') {
        final digits = digitsOnly(number.text);
        final (month, year) = parseExpiry(expiry.text)!;
        await store.api.addPaymentMethod({
          'type': 'card',
          'brand': detectCardBrand(digits),
          'last4': digits.substring(digits.length - 4),
          'holder': holder.text.trim(),
          'exp_month': month.toString().padLeft(2, '0'),
          'exp_year': year,
          'is_primary': primary,
        });
      } else {
        await store.api.addPaymentMethod({
          'type': 'wallet',
          'provider': provider,
          'phone_masked': maskPhone(phone.text),
          'is_primary': primary,
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      showToast(context, store.handleError(e), error: true);
    }
  }

  InputDecoration _dec(String label, {String? hint, String? error}) => InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(BRadius.sm)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BRadius.sm), borderSide: const BorderSide(color: BColors.brand, width: 1.5)),
      );

  @override
  Widget build(BuildContext context) {
    final brand = detectCardBrand(number.text);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Add payment method', style: BText.title),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'card', icon: Icon(Icons.credit_card), label: Text('Card')),
                ButtonSegment(value: 'wallet', icon: Icon(Icons.account_balance_wallet_outlined), label: Text('E-wallet')),
              ],
              selected: {type},
              onSelectionChanged: (v) => setState(() {
                type = v.first;
                showErrors = false;
              }),
              style: SegmentedButton.styleFrom(selectedBackgroundColor: BColors.brandSurface, selectedForegroundColor: BColors.brand),
            ),
            const SizedBox(height: 16),
            if (type == 'card') ...[
              TextField(controller: holder, textCapitalization: TextCapitalization.words, decoration: _dec('Cardholder name')),
              const SizedBox(height: 12),
              TextField(
                controller: number,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')), LengthLimitingTextInputFormatter(23)],
                decoration: _dec('Card number').copyWith(
                  suffixText: digitsOnly(number.text).isEmpty ? null : brand,
                  errorText: showErrors && !luhnValid(number.text) ? 'Invalid card number' : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: expiry,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')), LengthLimitingTextInputFormatter(5)],
                decoration: _dec('Expiry', hint: 'MM/YY'),
              ),
              const SizedBox(height: 6),
              const Row(children: [
                Icon(Icons.lock_outline, size: 13, color: BColors.muted),
                SizedBox(width: 4),
                Expanded(child: Text('We only keep the brand, last 4 digits and expiry. No CVC needed.', style: BText.tiny)),
              ]),
            ] else ...[
              Wrap(spacing: 8, children: [
                for (final p in const ['GCash', 'Maya'])
                  ChoiceChip(
                    label: Text(p),
                    selected: provider == p,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => provider = p),
                    selectedColor: BColors.brandSurface,
                    side: BorderSide(color: provider == p ? BColors.brand : BColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BRadius.sm)),
                  ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')), LengthLimitingTextInputFormatter(16)],
                decoration: _dec('$provider mobile number', hint: '09XX XXX XXXX'),
              ),
            ],
            SwitchListTile(
              value: primary,
              onChanged: widget.isFirst ? null : (v) => setState(() => primary = v),
              activeTrackColor: BColors.brand,
              contentPadding: EdgeInsets.zero,
              title: const Text('Set as primary', style: TextStyle(fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: saving ? null : _save,
              style: BButtons.brand(height: 48),
              child: saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('Save'),
            ),
          ]),
        ),
      ),
    );
  }
}
