import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../buyer_models.dart';
import '../buyer_shell.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../cart/cart_screen.dart';
import '../widgets/product_pager.dart';

/// Post-checkout confirmation: a branded header with the order status, Home /
/// My Orders shortcuts, then a "You may also like" product feed.
class OrderPlacedScreen extends StatefulWidget {
  const OrderPlacedScreen({super.key, required this.references, required this.total, required this.paymentMethod});

  final List<String> references;
  final double total;
  final String paymentMethod;

  @override
  State<OrderPlacedScreen> createState() => _OrderPlacedScreenState();
}

class _OrderPlacedScreenState extends State<OrderPlacedScreen> {
  final store = BuyerStore.instance;
  final pager = ProductPager()..loadMore();

  @override
  void dispose() {
    pager.dispose();
    super.dispose();
  }

  String get _subtitle {
    final refs = widget.references;
    if (refs.length > 1) return '${refs.length} orders were created — one per shop.';
    if (refs.isNotEmpty) return 'Order ${refs.first}';
    return 'Your order is on its way to the seller.';
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    Widget check = Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: const Icon(Icons.check_rounded, color: BColors.success, size: 40),
    );
    if (!reduceMotion) check = check.animate().scale(begin: const Offset(0.6, 0.6), duration: 320.ms, curve: Curves.easeOutBack);

    return Scaffold(
      backgroundColor: BColors.background,
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) => handleNearEnd(n, pager.loadMore),
        child: ListenableBuilder(
          listenable: pager,
          builder: (context, _) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header(context, check)),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.favorite_border_rounded, size: 18, color: BColors.ink),
                    SizedBox(width: 8),
                    Text('You may also like', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: BColors.ink)),
                  ]),
                ),
              ),
              ...productGridSlivers(context, pager, empty: const SizedBox.shrink()),
              SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Widget check) {
    const onBrand = Colors.white;
    final outline = OutlinedButton.styleFrom(
      foregroundColor: onBrand,
      side: const BorderSide(color: onBrand, width: 1.2),
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BRadius.md)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
    return Container(
      color: BColors.brand,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Row(children: [
            IconButton(
              tooltip: 'Back to home',
              onPressed: () => BuyerShell.goTo(context, 0),
              icon: const Icon(Icons.arrow_back_rounded, color: onBrand),
            ),
            const Spacer(),
            ListenableBuilder(
              listenable: store,
              builder: (_, __) => IconButton(
                tooltip: 'Cart',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen(standalone: true))),
                icon: Badge(
                  isLabelVisible: store.cartCount > 0,
                  label: Text(store.cartCount > 99 ? '99+' : '${store.cartCount}'),
                  backgroundColor: const Color(0xFFDC2626),
                  child: const Icon(Icons.shopping_cart_outlined, color: onBrand),
                ),
              ),
            ),
          ]),
          check,
          const SizedBox(height: 14),
          const Text('Order placed!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: onBrand)),
          const SizedBox(height: 6),
          Text(_subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: onBrand)),
          const SizedBox(height: 4),
          Text(
            widget.paymentMethod == 'cod'
                ? 'Pay ${peso(widget.total)} on delivery — please prepare the exact amount.'
                : '${paymentLabel(widget.paymentMethod)} · ${peso(widget.total)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFFFFE9DD)),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: outline,
                  onPressed: () => BuyerShell.goTo(context, 0),
                  icon: const Icon(Icons.home_outlined, size: 20),
                  label: const Text('Home'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: outline,
                  onPressed: () => BuyerShell.goTo(context, 1),
                  icon: const Icon(Icons.receipt_long_outlined, size: 20),
                  label: const Text('My Purchases'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
