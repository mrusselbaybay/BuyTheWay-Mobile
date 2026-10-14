import 'package:flutter/material.dart';

import '../buyer_theme.dart';
import 'voucher_quote.dart';

typedef VoucherPick = ({String? discount, String? shipping});

/// Bottom sheet to choose one discount and one shipping voucher for a shop
/// (or for the whole cart when [platform]). Non-stackable vouchers clear the
/// other slot, exactly like the web picker. Resolves the new pick, or null
/// when dismissed.
Future<VoucherPick?> showVoucherSheet(
  BuildContext context, {
  required String title,
  required VoucherOffer offer,
  required VoucherPick selected,
  bool platform = false,
}) =>
    showModalBottomSheet<VoucherPick>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: BColors.surface,
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => _VoucherSheet(title: title, offer: offer, initial: selected, platform: platform),
    );

class _VoucherSheet extends StatefulWidget {
  const _VoucherSheet({required this.title, required this.offer, required this.initial, required this.platform});

  final String title;
  final VoucherOffer offer;
  final VoucherPick initial;
  final bool platform;

  @override
  State<_VoucherSheet> createState() => _VoucherSheetState();
}

class _VoucherSheetState extends State<_VoucherSheet> {
  late String? discount = widget.initial.discount;
  late String? shipping = widget.initial.shipping;

  String? _get(String slot) => slot == 'shipping' ? shipping : discount;

  /// Picking a non-stackable voucher (or having one picked) clears the other slot.
  void _choose(String slot, String? id) {
    final other = slot == 'shipping' ? 'discount' : 'shipping';
    final picked = widget.offer.find(slot, id);
    final otherPicked = widget.offer.find(other, _get(other));
    setState(() {
      if (slot == 'shipping') {
        shipping = id;
      } else {
        discount = id;
      }
      if ((picked != null && !picked.stackable) || (picked != null && otherPicked != null && !otherPicked.stackable)) {
        if (other == 'shipping') {
          shipping = null;
        } else {
          discount = null;
        }
      }
    });
  }

  double get savings => (widget.offer.find('discount', discount)?.amount ?? 0) + (widget.offer.find('shipping', shipping)?.amount ?? 0);

  Widget _group(String slot) {
    final options = widget.offer.slot(slot);
    if (options.isEmpty) return const SizedBox.shrink();
    final best = slot == 'shipping' ? widget.offer.bestShippingId : widget.offer.bestDiscountId;
    final selectedId = _get(slot);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(children: [
            Icon(slot == 'shipping' ? Icons.local_shipping_outlined : Icons.sell_outlined, size: 17, color: slot == 'shipping' ? BColors.brand : BColors.cta),
            const SizedBox(width: 8),
            Text(slot == 'shipping' ? 'Shipping vouchers' : 'Discount vouchers', style: BText.section),
          ]),
        ),
        for (final o in options) _OptionTile(option: o, selected: selectedId == o.id, isBest: best == o.id, onTap: o.applicable ? () => _choose(slot, o.id) : null),
        _NoneTile(label: 'No ${slot == 'shipping' ? 'shipping' : 'discount'} voucher', selected: selectedId == null, onTap: () => _choose(slot, null)),
      ]),
    );
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
          Expanded(child: Text(widget.title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: BColors.ink))),
          IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          const SizedBox(width: 4),
        ]),
      ),
      const Divider(height: 1, color: BColors.border),
      Flexible(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          shrinkWrap: true,
          children: [
            if (widget.platform)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: BColors.brandSurface, borderRadius: BorderRadius.circular(12)),
                child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.verified_rounded, size: 18, color: BColors.brand),
                  SizedBox(width: 10),
                  Expanded(child: Text('BuyTheWay vouchers apply to your whole basket, on top of any shop vouchers.', style: TextStyle(fontSize: 12.5, height: 1.4, color: BColors.brandDark))),
                ]),
              ),
            _group('discount'),
            _group('shipping'),
          ],
        ),
      ),
      const Divider(height: 1, color: BColors.border),
      Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
        child: FilledButton(
          onPressed: () => Navigator.pop(context, (discount: discount, shipping: shipping)),
          style: FilledButton.styleFrom(backgroundColor: BColors.brand, minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
          child: Text(savings > 0 ? 'Apply · save ${peso(savings)}' : 'Apply', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ),
    ]);
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.option, required this.selected, required this.isBest, required this.onTap});

  final VoucherOption option;
  final bool selected;
  final bool isBest;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = option.applicable;
    final color = !enabled ? BColors.faint : (option.isShipping ? BColors.brand : BColors.cta);
    return Opacity(
      opacity: enabled ? 1 : 0.7,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? BColors.brand : BColors.border, width: selected ? 1.6 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(option.label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color))),
                    if (isBest && enabled) ...[const SizedBox(width: 8), const _Tag('Best value', BColors.success, BColors.successSurface)],
                    if (option.runningLow && enabled) ...[const SizedBox(width: 6), _Tag('${option.remaining ?? ''} left'.trim(), BColors.warning, BColors.warningSurface)],
                  ]),
                  const SizedBox(height: 4),
                  Text(option.conditions, style: BText.small),
                  if (option.expiresAt != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text('Valid till ${formatDate(option.expiresAt)}', style: BText.tiny)),
                  const SizedBox(height: 6),
                  if (enabled)
                    Text('Saves ${peso(option.amount)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: BColors.success))
                  else
                    Text(option.reason ?? 'Doesn\'t apply to this order', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: BColors.warning)),
                ]),
              ),
              const SizedBox(width: 10),
              Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, size: 24, color: selected ? BColors.brand : BColors.faint),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NoneTile extends StatelessWidget {
  const _NoneTile({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: BColors.muted))),
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, size: 24, color: selected ? BColors.brand : BColors.faint),
          ]),
        ),
      );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color, this.background);
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
      );
}
