import 'package:flutter/material.dart';

import '../../services/push_service.dart';
import '../auth/auth_screen.dart';
import 'account/account_screen.dart';
import 'account/notifications_screen.dart';
import 'buyer_store.dart';
import 'buyer_theme.dart';
import 'cart/cart_screen.dart';
import 'catalog/home_screen.dart';
import 'chat/chat_list_screen.dart';
import 'orders/orders_screen.dart';
import 'widgets/buyer_nav_bar.dart';
import 'widgets/buyer_widgets.dart';

/// Buyer app root: Home · Orders · Cart · Chat · Account. The floating glass
/// nav pill only surfaces Orders · Home · Account (Home centered) — Cart and
/// Chat are reached via the shortcuts beside the home search bar, and
/// Categories is a step away from Home's hero banner / category rail. Tabs
/// Visited tabs are kept alive so switching never re-fetches or loses scroll
/// position. Unvisited tabs do not start their requests at login.
class BuyerShell extends StatefulWidget {
  const BuyerShell({super.key});

  /// Lets any screen inside the shell jump to a tab (e.g. empty cart →
  /// "Start shopping" → Home). Pops pushed routes first.
  static final ValueNotifier<int> tab = ValueNotifier<int>(0);

  static void goTo(BuildContext context, int index) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    tab.value = index;
  }

  @override
  State<BuyerShell> createState() => _BuyerShellState();
}

class _BuyerShellState extends State<BuyerShell> {
  final store = BuyerStore.instance;
  final Set<int> _visitedTabs = {0};

  @override
  void initState() {
    super.initState();
    BuyerShell.tab.value = 0;
    store.init();
    // A tapped push (also a cold-start one) opens chat or the notifications inbox.
    PushService.instance.pendingTap.addListener(_onPushTap);
    store.addListener(_onPushTap);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPushTap());
  }

  @override
  void dispose() {
    PushService.instance.pendingTap.removeListener(_onPushTap);
    store.removeListener(_onPushTap);
    super.dispose();
  }

  void _onPushTap() {
    final tap = PushService.instance.pendingTap.value;
    // Not ready yet (cold start): stays pending until the store has loaded.
    if (tap == null || !mounted || !store.initialized || store.sessionExpired) return;
    PushService.instance.clearTap();
    if (tap.isMessage) {
      BuyerShell.goTo(context, 3);
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    }
  }

  Future<void> _backToSignIn() async {
    await store.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, BuyerShell.tab]),
      builder: (context, _) {
        if (!store.initialized) {
          return const Scaffold(
            backgroundColor: BColors.background,
            body:
                Center(child: CircularProgressIndicator(color: BColors.brand)),
          );
        }
        if (store.sessionExpired) {
          return Scaffold(
            backgroundColor: BColors.surface,
            body: SafeArea(
              child: EmptyState(
                icon: Icons.lock_clock_outlined,
                title: 'Your session has expired',
                message:
                    'Sign in again to keep shopping. Your cart is saved on this device.',
                actionLabel: 'Sign in',
                onAction: _backToSignIn,
              ),
            ),
          );
        }

        final index = BuyerShell.tab.value;
        _visitedTabs.add(index);
        // Background refresh only runs for the tab being looked at, and not
        // while another route (product page, sheet, …) covers the shell.
        final covered = ModalRoute.of(context)?.isCurrent == false;
        store.ordersTabActive = index == 1 && !covered;
        store.cartTabActive = index == 2 && !covered;
        return PopScope(
          canPop: index == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) BuyerShell.tab.value = 0;
          },
          child: Scaffold(
            backgroundColor: BColors.background,
            extendBody: true,
            body: IndexedStack(
              index: index,
              children: [
                const HomeScreen(),
                if (_visitedTabs.contains(1))
                  const OrdersScreen()
                else
                  const SizedBox.shrink(),
                if (_visitedTabs.contains(2))
                  const CartScreen()
                else
                  const SizedBox.shrink(),
                if (_visitedTabs.contains(3))
                  const ChatListScreen(embedded: true)
                else
                  const SizedBox.shrink(),
                if (_visitedTabs.contains(4))
                  const AccountScreen()
                else
                  const SizedBox.shrink(),
              ],
            ),
            bottomNavigationBar: BuyerNavBar(
              currentIndex: index,
              onTap: (i) => BuyerShell.tab.value = i,
            ),
          ),
        );
      },
    );
  }
}
