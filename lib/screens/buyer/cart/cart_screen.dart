import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../buyer_models.dart';
import '../buyer_shell.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../checkout/checkout_screen.dart';
import 'address_sheet.dart';
import '../catalog/store_screen.dart';
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
    store.loadAddresses();
    if (widget.standalone || BuyerShell.tab.value == 2) {
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
    if (BuyerShell.tab.value == 2) {
      _validate();
    }
  }

  void _validate() {
    final last = _validatedAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 30)) {
      return;
    }
    _validatedAt = DateTime.now();
    store.refreshCart();
  }

  void _remove(List<String> ids) {
    final removed = store.removeItems(ids);
    if (removed.isEmpty) return;
    showToast(
      context,
      removed.length == 1 ? 'Item removed' : '${removed.length} items removed',
      action: SnackBarAction(
          label: 'UNDO',
          textColor: const Color(0xFF5EEAD4),
          onPressed: () => store.restoreItems(removed)),
    );
  }

  void _checkout() {
    final items = store.selectedValidItems;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CheckoutScreen(items: items, fromCart: true)));
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
            backgroundColor: BColors.brandDark,
            surfaceTintColor: BColors.brandDark,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            toolbarHeight: 66,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(26))),
            flexibleSpace: const DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [BColors.brand, Color(0xFF14B8A6)])),
            ),
            leadingWidth: 56,
            leading: IconButton(
              tooltip: 'Back',
              onPressed: widget.standalone
                  ? () => Navigator.of(context).maybePop()
                  : () => BuyerShell.goTo(context, 0),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            ),
            title: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Shopping basket',
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                if (!empty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999)),
                    child: Text('${store.cartCount}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: BColors.brandDark)),
                  ),
                ],
              ]),
              const SizedBox(height: 4),
              const _AddressLine(),
            ]),
            actions: [
              if (!empty)
                TextButton(
                  onPressed: () => setState(() => editing = !editing),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14)),
                  child: Text(editing ? 'Done' : 'Edit',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                )
              else
                const SizedBox(width: 56),
            ],
            bottom: store.validatingCart
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(2),
                    child: LinearProgressIndicator(
                        minHeight: 2,
                        color: Colors.white,
                        backgroundColor: Colors.transparent),
                  )
                : null,
          ),
          body: empty
              ? _EmptyCart(onRefresh: () {
                  _validatedAt = DateTime.now();
                  return store.refreshCart();
                })
              : RefreshIndicator(
                  color: BColors.brand,
                  onRefresh: () {
                    _validatedAt = DateTime.now();
                    return store.refreshCart();
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                    children: [
                      const _VoucherStrip(),
                      if (store.cartSyncError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SyncNotice(
                              message: store.cartSyncError!,
                              onRetry: store.refreshCart),
                        ),
                      if (store.blockedCount > 0)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                          decoration: BoxDecoration(
                              color: BColors.warningSurface,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFFFDE68A))),
                          child: Row(children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 20, color: BColors.warning),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${store.blockedCount} ${store.blockedCount == 1 ? 'item is' : 'items are'} unavailable and won\'t be checked out.',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.3,
                                    fontWeight: FontWeight.w600,
                                    color: BColors.warning),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                final n = store.removeUnavailable();
                                showToast(context,
                                    '$n unavailable ${n == 1 ? 'item' : 'items'} removed');
                              },
                              style: TextButton.styleFrom(
                                  foregroundColor: BColors.warning),
                              child: const Text('Remove',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ]),
                        ),
                      for (final entry in groups.entries)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SellerCard(
                                seller: entry.key,
                                items: entry.value,
                                onRemove: _remove)),
                    ],
                  ),
                ),
          bottomNavigationBar: empty
              ? null
              : _CheckoutBar(
                  editing: editing,
                  onCheckout: _checkout,
                  onDelete: () {
                    _remove(store.selectedItems.map((i) => i.cartId).toList());
                    setState(() => editing = false);
                  },
                ),
        );
      },
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard(
      {required this.seller, required this.items, required this.onRemove});

  final String seller;
  final List<CartItem> items;
  final void Function(List<String>) onRemove;

  @override
  Widget build(BuildContext context) {
    final store = BuyerStore.instance;
    final allSelected = items.every((i) => i.selected);
    final sellerId =
        items.map((i) => i.sellerId).whereType<String>().firstOrNull;
    final picked = items.where((i) => i.selected && !i.isBlocked).toList();
    final subtotal =
        picked.fold<double>(0, (sum, i) => sum + i.effectivePrice * i.quantity);
    final pickedCount = picked.fold<int>(0, (sum, i) => sum + i.quantity);
    return Container(
      decoration: BoxDecoration(
          color: BColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BColors.border),
          boxShadow: softShadow(0.04)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Row(children: [
          BCheck(
              round: true,
              value: allSelected,
              onChanged: (v) => store.setSellerSelected(seller, v),
              semanticLabel: 'Select all from $seller'),
          Expanded(
            child: InkWell(
              onTap: sellerId == null
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          StoreScreen(storeId: sellerId, name: seller))),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  Flexible(
                      child: Text(seller,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: BColors.ink))),
                  if (sellerId != null)
                    const Icon(Icons.chevron_right_rounded,
                        size: 22, color: BColors.muted),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ]),
        const Divider(height: 1, color: BColors.divider),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, indent: 56, color: BColors.divider),
          Dismissible(
            key: ValueKey(items[i].cartId),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => onRemove([items[i].cartId]),
            background: Container(
              color: BColors.error,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.white),
                    Text('Remove',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ]),
            ),
            child: _CartLine(item: items[i]),
          ),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          color: BColors.brandSurface,
          child: Row(children: [
            Expanded(
                child: Text(
                    pickedCount == 0
                        ? 'No items selected'
                        : 'Subtotal · $pickedCount ${pickedCount == 1 ? 'item' : 'items'}',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: BColors.brandDark))),
            if (pickedCount > 0)
              pesoText(subtotal,
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: _kGreenDark)),
          ]),
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
    return Container(
      color: BColors.surface,
      padding: const EdgeInsets.only(right: 14, top: 12, bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BCheck(
            round: true,
            value: item.selected,
            onChanged: (_) => store.toggleItem(item.cartId),
            semanticLabel: 'Select ${item.name}'),
        GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ProductDetailScreen(productId: item.productId))),
          child: Stack(children: [
            Opacity(
              opacity: blocked ? 0.45 : 1,
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CategoryThumb(
                      category: item.category, image: item.image, size: 88)),
            ),
            if (blocked)
              Positioned.fill(
                child: Center(
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text('Unavailable',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700)))),
              ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.5,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: blocked ? BColors.muted : BColors.ink)),
            if (item.variation != null) ...[
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: BColors.brandSurface,
                    borderRadius: BorderRadius.circular(7)),
                child: Text(item.variation!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: BColors.brandDark)),
              ),
            ],
            if (message != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(
                    blocked
                        ? Icons.error_outline_rounded
                        : Icons.info_outline_rounded,
                    size: 14,
                    color: blocked ? BColors.error : BColors.warning),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(message,
                        style: TextStyle(
                            fontSize: 11.5,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: blocked ? BColors.error : BColors.warning))),
              ]),
            ],
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PriceText(item.effectivePrice, size: 16),
                      if ((item.oldPrice ?? 0) > item.effectivePrice) ...[
                        const SizedBox(height: 3),
                        Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(peso(item.oldPrice!),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: BColors.faint,
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: BColors.faint)),
                              DiscountBadge(
                                  (((item.oldPrice! - item.effectivePrice) /
                                              item.oldPrice!) *
                                          100)
                                      .round()),
                            ]),
                      ],
                    ]),
              ),
              if (!blocked || item.status == 'insufficient_stock')
                _QtyPill(
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

/// Rounded − 1 + stepper.
class _QtyPill extends StatelessWidget {
  const _QtyPill({required this.value, required this.onChanged, this.max});

  final int value;
  final int? max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canDec = value > 1;
    final canInc = max == null || value < max!;
    Widget btn(IconData icon, bool enabled, int next, String label) =>
        Semantics(
          button: true,
          label: label,
          child: InkResponse(
            onTap: enabled ? () => onChanged(next) : null,
            radius: 20,
            child: SizedBox(
                width: 34,
                height: 34,
                child: Icon(icon,
                    size: 18,
                    color: enabled ? BColors.brandDark : BColors.border)),
          ),
        );
    return Container(
      decoration: BoxDecoration(
          color: BColors.background, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn(Icons.remove_rounded, canDec, value - 1, 'Decrease quantity'),
        SizedBox(
            width: 26,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: BColors.ink))),
        btn(Icons.add_rounded, canInc, value + 1, 'Increase quantity'),
      ]),
    );
  }
}

const Color _kGreen = BColors.brand;
const Color _kGreenDark = BColors.brandDark;

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar(
      {required this.editing,
      required this.onCheckout,
      required this.onDelete});

  final bool editing;
  final VoidCallback onCheckout;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final store = BuyerStore.instance;
    final reason = store.checkoutBlockReason;
    final selectedLines = store.selectedItems.length;
    // What the sale prices already take off the original prices.
    final savings = store.selectedValidItems.fold<double>(
        0,
        (sum, i) =>
            sum +
            ((i.oldPrice ?? 0) > i.effectivePrice
                ? (i.oldPrice! - i.effectivePrice) * i.quantity
                : 0));
    return Container(
      decoration: BoxDecoration(
          color: BColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: softShadow(0.12)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 14, 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (!editing && reason.isNotEmpty && selectedLines > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 0, 4),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: BColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(reason,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: BColors.error))),
                ]),
              ),
            Row(children: [
              BCheck(
                  round: true,
                  value: store.allSelected,
                  onChanged: store.setAllSelected,
                  semanticLabel: 'Select all'),
              const Text('All',
                  style:
                      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              if (editing) ...[
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: selectedLines == 0 ? null : onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(
                      'Delete${selectedLines > 0 ? ' ($selectedLines)' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: BColors.error,
                      side: BorderSide(
                          color: selectedLines == 0
                              ? BColors.border
                              : BColors.error),
                      minimumSize: const Size(0, 46),
                      shape: const StadiumBorder()),
                ),
              ] else ...[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                              fit: BoxFit.scaleDown,
                              child: pesoText(store.selectedSubtotal,
                                  style: const TextStyle(
                                      fontSize: 21,
                                      height: 1.1,
                                      fontWeight: FontWeight.w900,
                                      color: _kGreenDark,
                                      letterSpacing: -0.4))),
                          if (savings > 0)
                            Text('${peso(savings)} off',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: _kGreen)),
                        ]),
                  ),
                ),
                ElevatedButton(
                  onPressed: reason.isEmpty ? onCheckout : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF99F6E4),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  child: Text('Check out (${store.selectedCount})'),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Default delivery address under the title (a frosted pill); tap to change it.
class _AddressLine extends StatelessWidget {
  const _AddressLine();

  @override
  Widget build(BuildContext context) {
    final address = BuyerStore.instance.defaultAddress;
    var text = address == null
        ? ''
        : [address.barangay, address.city, address.province]
            .where((e) => e.isNotEmpty)
            .join(', ');
    if (text.isEmpty) text = 'Add a delivery address';
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: () => showAddressSheet(context),
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 250),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 3, 6, 3),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.location_on_rounded,
                  size: 13, color: Colors.white),
              const SizedBox(width: 4),
              Flexible(
                  child: Text(text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white))),
              const Icon(Icons.keyboard_arrow_right_rounded,
                  size: 15, color: Colors.white),
            ]),
          ),
        ),
      ),
    );
  }
}

/// "Vouchers apply automatically" reminder above the shop groups.
class _VoucherStrip extends StatelessWidget {
  const _VoucherStrip();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: BColors.brandSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF99F6E4))),
        child: const Row(children: [
          Icon(Icons.confirmation_number_outlined,
              size: 18, color: _kGreenDark),
          SizedBox(width: 10),
          Expanded(
              child: Text(
                  'Your best vouchers are applied automatically at checkout',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _kGreenDark))),
        ]),
      );
}

/// Empty cart: shows a spinner while syncing with the account, the reason when
/// the sync failed, and can always be pulled down to try again.
class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final store = BuyerStore.instance;
    final Widget content;
    if (store.cartSyncing) {
      content = const Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: BColors.brand),
        SizedBox(height: 16),
        Text('Syncing your cart…', style: BText.small),
      ]);
    } else if (store.cartSyncError != null) {
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: _SyncNotice(message: store.cartSyncError!, onRetry: onRefresh),
      );
    } else {
      content = EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Your cart is empty',
        message: 'Items you add — here or on the website — will show up here.',
        actionLabel: 'Start shopping',
        onAction: () => BuyerShell.goTo(context, 0),
      );
    }
    return RefreshIndicator(
      color: BColors.brand,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: content)),
        ),
      ),
    );
  }
}

class _SyncNotice extends StatelessWidget {
  const _SyncNotice({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
            color: BColors.errorSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFECACA))),
        child: Row(children: [
          const Icon(Icons.cloud_off_rounded, size: 20, color: BColors.error),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Couldn\'t sync your cart with your account',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: BColors.error)),
              const SizedBox(height: 2),
              Text(message,
                  style: const TextStyle(
                      fontSize: 12, height: 1.3, color: BColors.error)),
            ]),
          ),
          TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: BColors.error),
              child: const Text('Retry',
                  style: TextStyle(fontWeight: FontWeight.w800))),
        ]),
      );
}
