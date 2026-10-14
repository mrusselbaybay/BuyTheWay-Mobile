import 'package:flutter/material.dart';

import '../account/address_form_screen.dart';
import '../account/settings_kit.dart';
import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../widgets/buyer_widgets.dart';
import '../widgets/success_popup.dart';

/// "Select address" bottom sheet: pick the delivery address (it becomes the
/// default, which checkout and the cart header use) or add a new one.
Future<void> showAddressSheet(BuildContext context) async {
  final chosen = await showModalBottomSheet<Address>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: BColors.surface,
    showDragHandle: false,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (_) => const _AddressSheet(),
  );
  if (chosen != null && context.mounted) {
    await showSuccessPopup(context, title: 'Delivery address updated', message: chosen.formatted);
  }
}

/// `(+63)91******67` — enough to recognise the number without showing it.
String _maskedPhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('63')) digits = '0${digits.substring(2)}';
  if (digits.length < 6) return raw;
  return '(+63)${digits.substring(1, 3)}${'*' * (digits.length - 5)}${digits.substring(digits.length - 2)}';
}

class _AddressSheet extends StatefulWidget {
  const _AddressSheet();

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  final store = BuyerStore.instance;
  String? busyId;

  @override
  void initState() {
    super.initState();
    store.loadAddresses();
  }

  Future<void> _select(Address a) async {
    if (a.isDefault) {
      Navigator.pop(context);
      return;
    }
    if (!a.isComplete) {
      await _edit(a); // finish it first
      return;
    }
    setState(() => busyId = a.id);
    try {
      await store.setDefaultAddress(a.id);
      if (!mounted) return;
      Navigator.pop(context, a);
    } catch (e) {
      if (mounted) {
        setState(() => busyId = null);
        showToast(context, store.handleError(e), error: true);
      }
    }
  }

  Future<void> _edit([Address? address]) async {
    await Navigator.of(context).push<Address>(MaterialPageRoute(builder: (_) => AddressFormScreen(initial: address)));
    if (mounted) store.loadAddresses(force: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 8),
      Container(width: 40, height: 4, decoration: BoxDecoration(color: BColors.border, borderRadius: BorderRadius.circular(2))),
      SizedBox(
        height: 56,
        child: Row(children: [
          const SizedBox(width: 48),
          const Expanded(child: Text('Select address', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: BColors.ink))),
          IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          const SizedBox(width: 4),
        ]),
      ),
      const Divider(height: 1, color: BColors.border),
      Flexible(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final list = store.addresses;
            if (list.isEmpty && store.loadingAddresses) {
              return const Padding(padding: EdgeInsets.all(16), child: RowsSkeleton(count: 3, tile: 40));
            }
            if (list.isEmpty) {
              return const Padding(padding: EdgeInsets.all(24), child: EmptyCard(icon: Icons.location_off_outlined, title: 'No saved addresses', message: 'Add where you\'d like your orders delivered.'));
            }
            return ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: BColors.divider),
              itemBuilder: (_, i) {
                final a = list[i];
                return InkWell(
                  onTap: busyId == null ? () => _select(a) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.fullName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: BColors.ink)),
                          const SizedBox(height: 4),
                          Text(_maskedPhone(a.phone), style: const TextStyle(fontSize: 13, color: BColors.muted)),
                          const SizedBox(height: 4),
                          Text(a.formatted, style: const TextStyle(fontSize: 13.5, height: 1.4, color: BColors.ink)),
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            if (a.isDefault) const StatusPill('Default', BColors.brand, icon: Icons.check_rounded),
                            StatusPill(a.label, BColors.muted),
                            if (!a.isComplete) const StatusPill('Incomplete — tap to finish', BColors.warning, icon: Icons.error_outline_rounded),
                          ]),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      busyId == a.id
                          ? const Padding(padding: EdgeInsets.all(4), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: BColors.brand)))
                          : Icon(a.isDefault ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, size: 26, color: a.isDefault ? BColors.brand : BColors.faint),
                    ]),
                  ),
                );
              },
            );
          },
        ),
      ),
      const Divider(height: 1, color: BColors.border),
      Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
        child: FilledButton(
          onPressed: _edit,
          style: FilledButton.styleFrom(backgroundColor: BColors.brand, minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
          child: const Text('Add address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ),
    ]);
  }
}
