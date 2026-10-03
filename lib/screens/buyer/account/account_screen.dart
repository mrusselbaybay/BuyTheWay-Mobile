import 'package:flutter/material.dart';

import '../../auth/auth_screen.dart';
import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../orders/orders_screen.dart';
import '../widgets/buyer_widgets.dart';
import '../chat/chat_list_screen.dart';
import 'addresses_screen.dart';
import 'my_reviews_screen.dart';
import 'payment_methods_screen.dart';
import 'profile_screen.dart';
import 'vouchers_screen.dart';
import 'wishlist_screen.dart';

/// "Me" tab: profile header, purchase-status shortcuts (the To Ship / To
/// Receive row shoppers expect), then account menu.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final ok = await confirmDialog(context, title: 'Sign out?', message: 'Your cart stays saved on this device.', confirmLabel: 'Sign out', destructive: true);
    if (!ok || !context.mounted) return;
    final nav = Navigator.of(context);
    await BuyerStore.instance.signOut();
    nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
  }

  void _push(BuildContext context, Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final store = BuyerStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final name = store.displayName.isEmpty ? 'Shopper' : store.displayName;
        return Scaffold(
          backgroundColor: BColors.background,
          body: RefreshIndicator(
            color: BColors.brand,
            onRefresh: () => Future.wait([store.loadOrders(), store.loadWishlist(), store.loadProfile(), store.refreshChatUnread()]),
            child: ListView(padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 8), children: [
              Material(
                color: BColors.brand,
                child: InkWell(
                onTap: () => _push(context, const ProfileScreen()),
                child: Padding(
                padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 20, 8, 22),
                child: Row(children: [
                  ClipOval(
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: store.avatarUrl != null
                          ? NetImage(store.avatarUrl, fallbackIcon: Icons.person)
                          : ColoredBox(
                              color: Colors.white,
                              child: Center(
                                child: Text(name.characters.first.toUpperCase(),
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: BColors.brand)),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                      if (store.email.isNotEmpty)
                        Text(store.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
                      const SizedBox(height: 2),
                      Text('Edit profile', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85), decoration: TextDecoration.underline, decorationColor: Colors.white70)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ]),
              ),
              ),
              ),
              Panel(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  ListTile(
                    title: const Text('My Purchases', style: BText.section),
                    trailing: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('View history', style: BText.small),
                      Icon(Icons.chevron_right, color: BColors.faint),
                    ]),
                    onTap: () => _push(context, const OrdersScreen()),
                  ),
                  const Divider(height: 1, color: BColors.divider),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      _StatusShortcut(icon: Icons.inventory_2_outlined, label: 'To Ship', count: store.countOrders(OrderStatus.toShip), onTap: () => _push(context, const OrdersScreen(initialTab: 1))),
                      _StatusShortcut(icon: Icons.inventory_outlined, label: 'Processing', count: store.countOrders(OrderStatus.processing), onTap: () => _push(context, const OrdersScreen(initialTab: 2))),
                      _StatusShortcut(icon: Icons.local_shipping_outlined, label: 'To Receive', count: store.countOrders(OrderStatus.inTransit), onTap: () => _push(context, const OrdersScreen(initialTab: 3))),
                      _StatusShortcut(
                        icon: Icons.markunread_mailbox_outlined,
                        label: 'Delivered',
                        count: store.orders.where((o) => o.awaitingReceipt).length,
                        onTap: () => _push(context, const OrdersScreen(initialTab: 4)),
                      ),
                    ]),
                  ),
                ]),
              ),
              Panel(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  _MenuTile(
                    icon: Icons.chat_bubble_outline,
                    label: 'Messages',
                    badge: store.chatUnread,
                    onTap: () => _push(context, const ChatListScreen()),
                  ),
                  _MenuTile(icon: Icons.favorite_border, label: 'My Wishlist', trailing: store.favorites.isEmpty ? null : '${store.favorites.length}', onTap: () => _push(context, const WishlistScreen())),
                  _MenuTile(icon: Icons.confirmation_number_outlined, label: 'My Vouchers', onTap: () => _push(context, const VouchersScreen())),
                  _MenuTile(icon: Icons.rate_review_outlined, label: 'My Reviews', onTap: () => _push(context, const MyReviewsScreen())),
                  _MenuTile(icon: Icons.location_on_outlined, label: 'My Addresses', onTap: () => _push(context, const AddressesScreen())),
                  _MenuTile(icon: Icons.credit_card, label: 'Payment Methods', onTap: () => _push(context, const PaymentMethodsScreen())),
                ]),
              ),
              Panel(
                padding: EdgeInsets.zero,
                child: _MenuTile(icon: Icons.logout, label: 'Sign Out', color: BColors.error, onTap: () => _signOut(context)),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _StatusShortcut extends StatelessWidget {
  const _StatusShortcut({required this.icon, required this.label, required this.count, required this.onTap});

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(children: [
              Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                backgroundColor: BColors.cta,
                child: Icon(icon, color: BColors.ink, size: 26),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12, color: BColors.ink)),
            ]),
          ),
        ),
      );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.onTap, this.trailing, this.color, this.badge = 0});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;
  final Color? color;
  final int badge;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: color ?? BColors.brand),
        title: Text(label, style: TextStyle(fontSize: 14.5, color: color ?? BColors.ink)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (trailing != null) Text(trailing!, style: BText.small),
          if (badge > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(color: BColors.cta, borderRadius: BorderRadius.circular(10)),
              child: Text(badge > 99 ? '99+' : '$badge', style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          if (color == null) const Icon(Icons.chevron_right, color: BColors.faint),
        ]),
        onTap: onTap,
      );
}
