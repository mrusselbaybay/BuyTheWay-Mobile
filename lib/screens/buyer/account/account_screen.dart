import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/auth_screen.dart';
import '../../driver/driver_theme.dart';
import '../../driver/settings/widgets/settings_widgets.dart';
import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../orders/orders_screen.dart';
import '../widgets/buyer_widgets.dart';
import 'addresses_screen.dart';
import 'my_reviews_screen.dart';
import 'payment_methods_screen.dart';
import 'profile_screen.dart';
import 'vouchers_screen.dart';
import 'wishlist_screen.dart';

/// Account tab — built from the courier app's own Settings components
/// (SettingsProfileSummary / SettingsSectionLabel / SettingsGroupCard /
/// SettingsNavTile) so both apps share one visual language exactly.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final ok = await confirmDialog(context, title: 'Log out?', message: 'Your cart stays saved on this device.', confirmLabel: 'Log out', destructive: true);
    if (!ok || !context.mounted) return;
    final nav = Navigator.of(context);
    await BuyerStore.instance.signOut();
    nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
  }

  void _push(BuildContext context, Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  String _count(int n, String noun) => n == 0 ? 'None yet' : '$n $noun${n == 1 ? '' : 's'}';

  @override
  Widget build(BuildContext context) {
    final store = BuyerStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final name = store.displayName.isEmpty ? 'Shopper' : store.displayName;
        final address = store.defaultAddress;
        return Scaffold(
          backgroundColor: DriverColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            foregroundColor: DriverColors.textPrimary,
            automaticallyImplyLeading: false,
            title: const Text('Account', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          body: RefreshIndicator(
            color: DriverColors.primary,
            onRefresh: () {
              HapticFeedback.lightImpact();
              return Future.wait([store.loadOrders(), store.loadWishlist(), store.loadProfile(), store.loadAddresses(force: true)]);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 18, 16, MediaQuery.paddingOf(context).bottom + 24),
              children: [
                SettingsProfileSummary(
                  name: name,
                  email: store.email,
                  status: 'active',
                  role: 'Buyer',
                  memberSince: store.profile?.memberSince ?? DateTime.now(),
                  avatarUrl: store.avatarUrl,
                  onTap: () => _push(context, const ProfileScreen()),
                ),
                const SizedBox(height: 26),
                _PurchasesCard(
                  toShip: store.countOrders(OrderStatus.toShip),
                  processing: store.countOrders(OrderStatus.processing),
                  toReceive: store.countOrders(OrderStatus.inTransit),
                  toRate: store.orders.where((o) => o.status == OrderStatus.delivered && o.returnState == null && o.items.any((i) => !i.reviewed)).length,
                  onOpen: (tab) => _push(context, OrdersScreen(initialTab: tab)),
                ),
                const SizedBox(height: 26),
                const SettingsSectionLabel('Shopping'),
                const SizedBox(height: 8),
                SettingsGroupCard(children: [
                  SettingsNavTile(
                    icon: Icons.favorite_border_rounded,
                    title: 'Wishlist',
                    subtitle: _count(store.favorites.length, 'saved item'),
                    onTap: () => _push(context, const WishlistScreen()),
                  ),
                  SettingsNavTile(
                    icon: Icons.confirmation_number_outlined,
                    title: 'Vouchers',
                    subtitle: 'Claimed vouchers apply at checkout',
                    onTap: () => _push(context, const VouchersScreen()),
                  ),
                  SettingsNavTile(
                    icon: Icons.rate_review_outlined,
                    title: 'My Reviews',
                    subtitle: 'Ratings you\'ve given',
                    onTap: () => _push(context, const MyReviewsScreen()),
                  ),
                ]),
                const SizedBox(height: 26),
                const SettingsSectionLabel('Account'),
                const SizedBox(height: 8),
                SettingsGroupCard(children: [
                  SettingsNavTile(
                    icon: Icons.badge_outlined,
                    title: 'Personal Information',
                    subtitle: 'Name, contact number, birthday',
                    onTap: () => _push(context, const ProfileScreen()),
                  ),
                  SettingsNavTile(
                    icon: Icons.location_on_outlined,
                    title: 'Addresses',
                    subtitle: address == null ? 'No address on file yet' : address.formatted,
                    onTap: () => _push(context, const AddressesScreen()),
                  ),
                  SettingsNavTile(
                    icon: Icons.credit_card_rounded,
                    title: 'Payment Methods',
                    subtitle: 'Cards and e-wallets',
                    onTap: () => _push(context, const PaymentMethodsScreen()),
                  ),
                ]),
                const SizedBox(height: 26),
                _SupportCard(onCustomerService: () => showToast(context, 'Customer service chat is coming soon.')),
                const SizedBox(height: 26),
                SettingsGroupCard(children: [
                  SettingsNavTile(
                    icon: Icons.logout_rounded,
                    title: 'Log Out',
                    iconColor: DriverColors.error,
                    titleColor: DriverColors.error,
                    onTap: () => _signOut(context),
                  ),
                ]),
                const SizedBox(height: 18),
                const Center(child: Text('BuyTheWay', style: BText.tiny)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// "My Purchases" card: title + "View Purchase History", then the four
/// status shortcuts. Same white / hairline-border card as the courier
/// Settings groups.
class _PurchasesCard extends StatelessWidget {
  const _PurchasesCard({required this.toShip, required this.processing, required this.toReceive, required this.toRate, required this.onOpen});

  final int toShip;
  final int processing;
  final int toReceive;
  final int toRate;

  /// Opens Orders on the given tab (0 All, 1 To Ship, 2 Processing, 3 To Receive, 4 Completed).
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: DriverColors.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          InkWell(
            onTap: () => onOpen(0),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 12, 10),
              child: Row(children: [
                Expanded(child: Text('My Purchases', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DriverColors.textPrimary))),
                Text('View Purchase History', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: DriverColors.primary)),
                Icon(Icons.chevron_right_rounded, size: 19, color: DriverColors.primary),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Row(children: [
              _PurchaseShortcut(icon: Icons.inventory_2_outlined, label: 'To Ship', count: toShip, onTap: () => onOpen(1)),
              _PurchaseShortcut(icon: Icons.inventory_outlined, label: 'Processing', count: processing, onTap: () => onOpen(2)),
              _PurchaseShortcut(icon: Icons.local_shipping_outlined, label: 'To Receive', count: toReceive, onTap: () => onOpen(3)),
              _PurchaseShortcut(icon: Icons.stars_outlined, label: 'To Rate', count: toRate, onTap: () => onOpen(4)),
            ]),
          ),
        ]),
      );
}

class _PurchaseShortcut extends StatelessWidget {
  const _PurchaseShortcut({required this.icon, required this.label, required this.count, required this.onTap});

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Semantics(
          button: true,
          label: count > 0 ? '$label, $count' : label,
          excludeSemantics: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(children: [
                Badge(
                  isLabelVisible: count > 0,
                  label: Text(count > 99 ? '99+' : '$count'),
                  backgroundColor: DriverColors.primaryDark,
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: DriverColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
                    child: Icon(icon, size: 22, color: DriverColors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DriverColors.textPrimary)),
              ]),
            ),
          ),
        ),
      );
}

/// "Support" card: title inside the card, rows below.
class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.onCustomerService});

  final VoidCallback onCustomerService;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: DriverColors.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text('Support', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DriverColors.textPrimary)),
          ),
          SettingsNavTile(
            icon: Icons.headset_mic_outlined,
            title: 'Customer Service',
            subtitle: 'Questions about an order or your account',
            onTap: onCustomerService,
          ),
        ]),
      );
}
