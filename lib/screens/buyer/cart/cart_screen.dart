import 'package:flutter/material.dart';

import '../buyer_models.dart';
import '../buyer_shell.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../checkout/checkout_screen.dart';
import '../product/product_detail_screen.dart';
import '../widgets/buyer_widgets.dart';

/// Cart grouped by shop. Re-validated against the live catalog each time
/// it's shown so stale price/stock is flagged inline before checkout.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key, this.standalone = false});

  /// true when pushed as its own route (from a product page) rather than
  /// shown as the shell's Cart tab.
  final bool standalone;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final store = BuyerStore.instance;
  bool editing = false;
  DateTime? _validatedAt;

  @override
  void initState() {
    super.initState();
    if (widget.standalone) {
      _validate();
    } else {
      BuyerShell.tab.addListener(_onTabChange);
    }
  }

  @override
  void dispose() {
    BuyerShell.tab.removeListener(_onTabChange);
    super.dispose();
  }

  void _onTabChange() {
    if (BuyerShell.tab.value == 2) _validate();
  }

  void _validate() {
    final last = _validatedAt;
    if (last != null && DateTime.now().difference(last) < const Duration(seconds: 30)) return;
    _validatedAt = DateTime.now();
    store.validateCart();
  }

  void _remove(List<String> ids) {
    final removed = store.removeItems(ids);
    if (removed.isEmpty) return;
    showToast(
      context,
      removed.length == 1 ? 'Item removed' : '${removed.length} items removed',
      action: SnackBarAction(label: 'UNDO', textColor: const Color(0xFF5EEAD4), onPressed: () => store.restoreItems(removed)),
    );
  }

  void _checkout() {
    final items = store.selectedValidItems;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CheckoutScreen(items: items, fromCart: true)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final groups = store.cartBySeller;
        final empty = groups.isEmpty;
        return Scaffold(
          backgroundColor: BColors.background,
          appBar: AppBar(
            backgroundColor: BColors.surface,
            surfaceTintColor: BColors.surface,
            foregroundColor: BColors.ink,
            automaticallyImplyLeading: widget.standalone,
            title: Text(empty ? 'Shopping Cart' : 'Shopping Cart (${store.cartCount})', style: BText.title),
            actions: [
              if (!empty)
                TextButton(
                  onPressed: () => setState(() => editing = !editing),
                  child: Text(editing ? 'Done' : 'Edit', style: const TextStyle(color: BColors.ink, fontSize: 14)),
                ),
            ],
            bottom: store.validatingCart
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(2),
                    child: LinearProgressIndicator(minHeight: 2, color: BColors.brand, backgroundColor: BColors.brandSurface),
                  )
                : null,
          ),
          body: empty
              ? EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Your cart is empty',
                  message: 'Items you add will show up here.',
                  actionLabel: 'Start shopping',
                  onAction: () => BuyerShell.goTo(context, 0),
                )
              : RefreshIndicator(
                  color: BColors.brand,
                  onRefresh: () {
                    _validatedAt = DateTime.now();
                    return store.validateCart();
                  },
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      if (store.blockedCount > 0)
                        Notice(
                          '${store.blockedCount} ${store.blockedCount == 1 ? 'item is' : 'items are'} unavailable and won\'t be checked out.',
                          action: TextButton(
                            onPressed: () {
                              final n = store.removeUnavailable();
                              showToast(context, '$n unavailable ${n == 1 ? 'item' : 'items'} removed');
                            },
                            style: TextButton.styleFrom(foregroundColor: BColors.warning, padding: const EdgeInsets.symmetric(horizontal: 8)),
                            child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      for (final entry in groups.entries) _SellerGroup(seller: entry.key, items: entry.value, onRemove: _remove),
                    ],
                  ),
                ),
          bottomNavigationBar: empty ? null : _CheckoutBar(editing: editing, onCheckout: _checkout, onDelete: () {
            _remove(store.selectedItems.map((i) => i.cartId).toList());
            setState(() => editing = false);
          }),
        );
      },
    );
  }
}

class _SellerGroup extends StatelessWidget {
  const _SellerGroup({required this.seller, required this.items, required this.onRemove});

  final String seller;
  final List<CartItem> items;
  final void Function(List<String>) onRemove;

  @override
  Widget build(BuildContext context) {
    final store = BuyerStore.instance;
    final allSelected = items.every((i) => i.selected);
    return Container(
      color: BColors.surface,
      margin: const EdgeInsets.only(top: 8),
      child: Column(children: [
        Row(children: [
          BCheck(value: allSelected, onChanged: (v) => store.setSellerSelected(seller, v), semanticLabel: 'Select all from $seller'),
          const Icon(Icons.storefront, size: 18, color: BColors.ink),
          const SizedBox(width: 6),
          Expanded(child: Text(seller, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
          const SizedBox(width: 12),
        ]),
        const Divider(height: 1, color: BColors.divider),
        for (final item in items)
          Dismissible(
            key: ValueKey(item.cartId),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => onRemove([item.cartId]),
            background: Container(
              color: BColors.error,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            child: _CartLine(item: item),
          ),
      ]),
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final store = BuyerStore.instance;
    final blocked = item.isBlocked;
    final message = item.statusMessage;
    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BCheck(value: item.selected, onChanged: (_) => store.toggleItem(item.cartId), semanticLabel: 'Select ${item.name}'),
        GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: item.productId))),
          child: Opacity(
            opacity: blocked ? 0.45 : 1,
            child: CategoryThumb(category: item.category, image: item.image, size: 80),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, height: 1.3, color: blocked ? BColors.muted : BColors.ink)),
            if (item.variation != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: BColors.background,
                child: Text(item.variation!, maxLines: 1, overflow: TextOverflow.ellipsis, style: BText.tiny),
              ),
            ],
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(message, style: TextStyle(fontSize: 12, color: blocked ? BColors.error : BColors.warning)),
            ],
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: PriceText(item.effectivePrice, oldPrice: item.oldPrice, size: 14.5)),
              if (!blocked || item.status == 'insufficient_stock')
                QtyStepper(
                  value: item.quantity,
                  max: item.maxStock,
                  onChanged: (q) {
                    final warning = store.setQuantity(item.cartId, q);
                    if (warning != null) showToast(context, warning);
                  },
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.editing, required this.onCheckout, required this.onDelete});

  final bool editing;
  final VoidCallback onCheckout;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final store = BuyerStore.instance;
    final reason = store.checkoutBlockReason;
    final selectedLines = store.selectedItems.length;
    return Container(
      decoration: const BoxDecoration(color: BColors.surface, border: Border(top: BorderSide(color: BColors.border))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(children: [
            BCheck(value: store.allSelected, onChanged: store.setAllSelected, semanticLabel: 'Select all'),
            const Text('All', style: TextStyle(fontSize: 13.5)),
            if (editing) ...[
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: OutlinedButton(
                  onPressed: selectedLines == 0 ? null : onDelete,
                  style: BButtons.outline(height: 40, color: BColors.error),
                  child: Text('Delete${selectedLines > 0 ? ' ($selectedLines)' : ''}'),
                ),
              ),
            ] else ...[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(TextSpan(children: [
                        const TextSpan(text: 'Total ', style: TextStyle(fontSize: 13, color: BColors.ink)),
                        TextSpan(text: peso(store.selectedSubtotal), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: BColors.cta)),
                      ])),
                    ),
                    if (reason.isNotEmpty && selectedLines > 0)
                      Text(reason, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: BColors.error)),
                  ]),
                ),
              ),
              SizedBox(
                height: 60,
                child: ElevatedButton(
                  onPressed: reason.isEmpty ? onCheckout : null,
                  style: BButtons.cta(height: 60).copyWith(shape: const WidgetStatePropertyAll(RoundedRectangleBorder())),
                  child: Text('Check Out (${store.selectedCount})'),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
