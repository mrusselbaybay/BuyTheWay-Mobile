import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../buyer_models.dart';
import '../buyer_shell.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../product/variant_sheet.dart';
import '../widgets/buyer_widgets.dart';

/// Re-adds [items] to the cart (Buy again / Add to cart), matching each
/// original variation by label and asking for one only when it can't.
/// With [goToCart] it opens the Cart tab once anything was added.
Future<void> reorderItems(BuildContext context, List<OrderItem> items, {required bool goToCart}) async {
  final store = BuyerStore.instance;
  HapticFeedback.lightImpact();
  var added = 0;
  String? lastMessage;
  try {
    for (final item in items) {
      if (item.productId == null) continue;
      final product = await store.api.product(item.productId!);
      if (!context.mounted) return;
      if (product == null) {
        lastMessage = '${item.name} is no longer available.';
        continue;
      }
      ProductVariant? variant;
      if (product.usesVariants) {
        variant = product.variants.where((v) => v.isActive && v.label == item.variation).firstOrNull;
        if (variant == null) {
          final pick = await showVariantSheet(context, product, VariantSheetMode.addToCart);
          if (!context.mounted || pick == null) continue;
          variant = pick.variant;
        }
      }
      final r = store.addToCart(product, variant, item.quantity);
      lastMessage = r.message;
      if (r.ok) added++;
    }
  } catch (e) {
    lastMessage = store.handleError(e);
  }
  if (!context.mounted) return;
  if (added > 0 && goToCart) {
    BuyerShell.goTo(context, 2);
  } else if (lastMessage != null) {
    showToast(context, lastMessage, error: added == 0);
  }
}

const _cancelReasons = [
  'Need to change delivery address',
  'Need to change the item or quantity',
  'Found a better price elsewhere',
  'Ordered by mistake',
  'Don\'t want to buy anymore',
];

/// Cancel (while "New") and Order Received (delivered, not yet confirmed)
/// — shared by the order card and the detail page. Returns the updated
/// order through [onUpdated].
class OrderActionButtons extends StatefulWidget {
  const OrderActionButtons({super.key, required this.order, this.onUpdated, this.expand = false});

  final Order order;
  final ValueChanged<Order>? onUpdated;
  final bool expand;

  @override
  State<OrderActionButtons> createState() => _OrderActionButtonsState();
}

class _OrderActionButtonsState extends State<OrderActionButtons> {
  final store = BuyerStore.instance;
  bool busy = false;

  Future<void> _cancel() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: BColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(BRadius.md))),
      builder: (_) => const _CancelSheet(),
    );
    if (reason == null || !mounted) return;
    setState(() => busy = true);
    try {
      final updated = await store.api.cancelOrder(widget.order.number, reason);
      store.replaceOrder(updated);
      widget.onUpdated?.call(updated);
      if (mounted) showToast(context, 'Order ${widget.order.orderId} cancelled');
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _receive() async {
    final ok = await confirmDialog(
      context,
      title: 'Confirm order received?',
      message: 'Only confirm once you\'ve checked that everything arrived as described. '
          'This releases payment to the seller.',
      confirmLabel: 'Yes, I received it',
      cancelLabel: 'Not yet',
    );
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      final updated = await store.api.receiveOrder(widget.order.number);
      store.replaceOrder(updated);
      widget.onUpdated?.call(updated);
      if (mounted) showToast(context, 'Thanks! Order marked as received.');
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final buttons = <Widget>[
      if (o.canCancel)
        OutlinedButton(
          onPressed: busy ? null : _cancel,
          style: BButtons.outline(height: widget.expand ? 46 : 40, color: BColors.muted).copyWith(shape: const WidgetStatePropertyAll(StadiumBorder())),
          child: const Text('Cancel Order'),
        ),
      if (o.awaitingReceipt)
        ElevatedButton(
          onPressed: busy ? null : _receive,
          style: BButtons.brand(height: widget.expand ? 46 : 40).copyWith(shape: const WidgetStatePropertyAll(StadiumBorder())),
          child: busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Order Received'),
        ),
    ];
    if (widget.expand) {
      return Row(children: [for (final b in buttons) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: b))]);
    }
    return Wrap(spacing: 8, children: buttons);
  }
}

class _CancelSheet extends StatefulWidget {
  const _CancelSheet();

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  String? selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('Why are you cancelling?', style: BText.title),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('Stock goes back to the seller and nothing is charged.', style: BText.small),
        ),
        RadioGroup<String>(
          groupValue: selected,
          onChanged: (v) => setState(() => selected = v),
          child: Column(
            children: _cancelReasons
                .map((r) => RadioListTile<String>(
                      value: r,
                      activeColor: BColors.brand,
                      dense: true,
                      title: Text(r, style: const TextStyle(fontSize: 14)),
                    ))
                .toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton(
            onPressed: selected == null ? null : () => Navigator.pop(context, selected),
            style: ElevatedButton.styleFrom(
              backgroundColor: BColors.error,
              foregroundColor: Colors.white,
              disabledBackgroundColor: BColors.errorSurface,
              disabledForegroundColor: BColors.error,
              elevation: 0,
              minimumSize: const Size(0, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BRadius.sm)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            child: const Text('Cancel Order'),
          ),
        ),
      ]),
    );
  }
}
