import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../driver/driver_theme.dart';
import '../../../widgets/sign_in_methods_section.dart';
import '../../driver/settings/widgets/settings_widgets.dart';
import '../buyer_store.dart';
import '../catalog/store_screen.dart';
import '../orders/orders_screen.dart';
import '../widgets/buyer_widgets.dart';
import 'profile_screen.dart';
import 'my_reports_screen.dart';
import 'settings_kit.dart';

final _buyer = BuyerStore.instance;

/// One row in a followed / blocked shops list, with the store's real logo.
class _ShopRow extends StatelessWidget {
  const _ShopRow(
      {required this.name,
      this.logo,
      this.subtitle,
      required this.actionLabel,
      required this.busy,
      required this.onAction,
      this.onTap,
      this.blocked = false});

  final String name;
  final String? logo;
  final String? subtitle;
  final String actionLabel;
  final bool busy;
  final VoidCallback onAction;
  final VoidCallback? onTap;
  final bool blocked;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(children: [
            StoreAvatar(logo: logo, size: 48, muted: blocked),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: DriverColors.textPrimary)),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DriverText.caption),
                    ],
                  ]),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 36,
              child: busy
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: settingsSpinner())
                  : OutlinedButton(
                      onPressed: onAction,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: blocked
                            ? DriverColors.primary
                            : DriverColors.textSecondary,
                        side: BorderSide(
                            color: blocked
                                ? DriverColors.primary
                                : DriverColors.border),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(actionLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ),
            ),
          ]),
        ),
      );
}

// ============================================================
// Login & Security
// ============================================================

class BuyerSecurityScreen extends StatefulWidget {
  const BuyerSecurityScreen({super.key});

  @override
  State<BuyerSecurityScreen> createState() => _BuyerSecurityScreenState();
}

class _BuyerSecurityScreenState extends State<BuyerSecurityScreen> {
  bool signingOutOthers = false;

  Future<void> _signOutOthers() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Sign out of other devices?',
      message:
          'Other phones and browsers will need to sign in again. This device stays signed in.',
      confirmLabel: 'Sign out others',
    );
    if (!confirmed || !mounted) return;
    setState(() => signingOutOthers = true);
    try {
      await _buyer.api.signOutOtherDevices();
      if (mounted) showToast(context, 'Other devices were signed out');
    } catch (e) {
      if (mounted) showToast(context, _buyer.handleError(e), error: true);
    } finally {
      if (mounted) setState(() => signingOutOthers = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _buyer,
        builder: (context, _) {
          final verified = _buyer.emailVerified;
          final phone = _buyer.profile?.contactNo;
          return SettingsPage(title: 'Login & Security', children: [
            const SignInMethodsSection(),
            const SettingsSectionLabel('Sign-in'),
            SettingsGroupCard(children: [
              SettingsNavTile(
                icon: Icons.email_outlined,
                title: 'Sign-in email',
                subtitle:
                    _buyer.email.isEmpty ? 'Loading account…' : _buyer.email,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(64, 0, 16, 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: verified == null
                      ? const SkeletonBox(width: 80, height: 18, radius: 8)
                      : verified
                          ? const StatusPill(
                              'Email verified', DriverColors.success,
                              icon: Icons.check_circle_outline_rounded)
                          : const StatusPill(
                              'Not verified', DriverColors.warning,
                              icon: Icons.info_outline_rounded),
                ),
              ),
              SettingsNavTile(
                icon: Icons.phone_iphone_rounded,
                title: 'Mobile number',
                subtitle: phone == null || phone.isEmpty ? 'Not added' : phone,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen())),
              ),
            ]),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                  'Changing your sign-in email and phone verification are not available yet.',
                  style: DriverText.caption),
            ),
            kSettingsGap,
            const SettingsSectionLabel('Other devices'),
            SettingsGroupCard(children: [
              SettingsNavTile(
                icon: Icons.phonelink_erase_outlined,
                title: signingOutOthers
                    ? 'Signing out…'
                    : 'Sign out other devices',
                subtitle:
                    'Signed in somewhere you don\'t recognise? Keep only this device.',
                iconColor: DriverColors.error,
                titleColor: DriverColors.error,
                onTap: signingOutOthers ? null : _signOutOthers,
              ),
            ]),
          ]);
        },
      );
}

// ============================================================
// Notifications
// ============================================================

class BuyerNotificationsScreen extends StatefulWidget {
  const BuyerNotificationsScreen({super.key});

  @override
  State<BuyerNotificationsScreen> createState() =>
      _BuyerNotificationsScreenState();
}

class _BuyerNotificationsScreenState extends State<BuyerNotificationsScreen> {
  Map<String, dynamic>? preferences;
  List<Map<String, dynamic>> notices = [];
  final busy = <String>{};
  String? error;
  String? noticesError;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
      noticesError = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _buyer.api.notificationPreferences(),
        _buyer.api.reportNotifications().catchError((Object e) {
          noticesError = _buyer.handleError(e);
          return <Map<String, dynamic>>[];
        }),
      ]);
      if (mounted) {
        setState(() {
          preferences = results[0] as Map<String, dynamic>;
          notices = results[1] as List<Map<String, dynamic>>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = _buyer.handleError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// Flips the switch immediately; rolls back if the save fails.
  Future<void> _toggle(String key, bool value) async {
    final before = preferences;
    setState(() {
      busy.add(key);
      preferences = {...?before, key: value};
    });
    try {
      final saved = await _buyer.api.saveNotificationPreference(key, value);
      if (mounted) setState(() => preferences = saved);
    } catch (e) {
      if (mounted) {
        setState(() => preferences = before);
        showToast(context, _buyer.handleError(e), error: true);
      }
    } finally {
      if (mounted) setState(() => busy.remove(key));
    }
  }

  Widget _choice(String key, IconData icon, String title, String description) =>
      Opacity(
        opacity: busy.contains(key) ? 0.6 : 1,
        child: IgnorePointer(
          ignoring: busy.contains(key),
          child: SettingsSwitchTile(
              icon: icon,
              title: title,
              subtitle: description,
              value: preferences?[key] == true,
              onChanged: (v) => _toggle(key, v)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (error != null && preferences == null) {
      return Scaffold(
        backgroundColor: DriverColors.background,
        appBar: AppBar(title: const Text('Notifications')),
        body: ErrorState(message: error!, onRetry: _load),
      );
    }
    return SettingsPage(
      title: 'Notifications',
      onRefresh: _load,
      children: [
        if (loading && preferences == null) ...[
          const RowsSkeleton(),
        ] else ...[
          const SettingsSectionLabel('Optional emails'),
          SettingsGroupCard(dividerIndent: 64, children: [
            _choice('order_updates_email', Icons.local_shipping_outlined,
                'Order updates', 'Saved for when order emails launch.'),
            _choice(
                'promotions_email',
                Icons.local_offer_outlined,
                'Deals and recommendations',
                'Optional emails about offers and products.'),
            _choice(
                'case_updates_email',
                Icons.flag_outlined,
                'Report case updates',
                'Email when a submitted report is reviewed.'),
          ]),
          kSettingsGap,
          const SettingsSectionLabel('Always sent'),
          const SettingsGroupCard(children: [
            SettingsInfoRow(
                icon: Icons.verified_user_outlined,
                label: 'Account approval and status changes',
                value: ''),
            SettingsInfoRow(
                icon: Icons.password_rounded,
                label: 'Password reset codes you request',
                value: ''),
          ]),
          kSettingsGap,
          const SettingsSectionLabel('Report updates'),
          if (noticesError != null)
            SettingsErrorBanner(message: noticesError!, onRetry: _load)
          else if (notices.isEmpty)
            const EmptyCard(
                icon: Icons.mark_email_read_outlined,
                title: 'No report outcomes yet',
                message: 'Updates on reports you submit will appear here.')
          else
            SettingsGroupCard(children: [
              for (final notice in notices) _NoticeRow(notice),
            ]),
        ],
      ],
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow(this.notice);
  final Map<String, dynamic> notice;

  @override
  Widget build(BuildContext context) {
    final created = DateTime.tryParse('${notice['created_at'] ?? ''}');
    final message = '${notice['message'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: DriverColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.mark_email_read_outlined,
              size: 17, color: DriverColors.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${notice['title'] ?? 'Report update'}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: DriverColors.textPrimary)),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(message,
                  style: DriverText.body.copyWith(
                      color: DriverColors.textSecondary, height: 1.35)),
            ],
            if (created != null) ...[
              const SizedBox(height: 4),
              Text(SettingsFormat.dateTime(created), style: DriverText.caption),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ============================================================
// Followed stores
// ============================================================

class BuyerFollowingScreen extends StatefulWidget {
  const BuyerFollowingScreen({super.key});

  @override
  State<BuyerFollowingScreen> createState() => _BuyerFollowingScreenState();
}

class _BuyerFollowingScreenState extends State<BuyerFollowingScreen> {
  final stores = <Map<String, dynamic>>[];
  int page = 0;
  int lastPage = 1;
  bool loading = false;
  String? error;
  String? busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next = reset ? 1 : page + 1;
      final result = await _buyer.api.followedStores(page: next);
      if (mounted) {
        setState(() {
          if (reset) stores.clear();
          stores.addAll(result.$1);
          page = next;
          lastPage = result.$2;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = _buyer.handleError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _unfollow(Map<String, dynamic> store) async {
    final id = '${store['id']}';
    final confirmed = await confirmDialog(context,
        title: 'Unfollow ${store['name']}?',
        message: 'You can follow this store again later.',
        confirmLabel: 'Unfollow');
    if (!confirmed || !mounted) return;
    setState(() => busyId = id);
    try {
      await _buyer.api.unfollowStore(id);
      if (mounted) {
        setState(() => stores.removeWhere((item) => '${item['id']}' == id));
        showToast(context, 'Unfollowed ${store['name']}');
      }
    } catch (e) {
      if (mounted) showToast(context, _buyer.handleError(e), error: true);
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) => SettingsPage(
        title: 'Followed Stores',
        onRefresh: () => _load(reset: true),
        children: [
          if (loading && stores.isEmpty)
            const RowsSkeleton()
          else if (error != null && stores.isEmpty)
            SettingsErrorBanner(
                message: error!, onRetry: () => _load(reset: true))
          else if (stores.isEmpty)
            const EmptyCard(
                icon: Icons.storefront_outlined,
                title: 'You\'re not following any stores yet',
                message: 'Follow stores from their product or store pages.')
          else ...[
            if (error != null)
              SettingsErrorBanner(message: error!, onRetry: _load),
            SettingsGroupCard(dividerIndent: 78, children: [
              for (final store in stores)
                _ShopRow(
                  name: '${store['name'] ?? 'Store'}',
                  logo: store['logo'] as String?,
                  subtitle: '${store['category'] ?? ''}',
                  actionLabel: 'Unfollow',
                  busy: busyId == '${store['id']}',
                  onAction: () => _unfollow(store),
                  onTap: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => StoreScreen(storeId: '${store['id']}', name: '${store['name'] ?? 'Store'}', logo: store['logo'] as String?)));
                    if (mounted) _load(reset: true);
                  },
                ),
            ]),
            if (page < lastPage) LoadMore(loading: loading, onTap: _load),
          ],
        ],
      );
}

// ============================================================
// Privacy & Account
// ============================================================

class BuyerPrivacyScreen extends StatefulWidget {
  const BuyerPrivacyScreen({super.key});

  @override
  State<BuyerPrivacyScreen> createState() => _BuyerPrivacyScreenState();
}

class _BuyerPrivacyScreenState extends State<BuyerPrivacyScreen> {
  bool exporting = false;
  String? blockedLabel;

  @override
  void initState() {
    super.initState();
    _loadBlockedCount();
  }

  Future<void> _loadBlockedCount() async {
    try {
      final (shops, lastPage) = await _buyer.api.blockedShops(page: 1);
      if (mounted) {
        setState(() => blockedLabel = lastPage > 1 ? '${shops.length}+' : '${shops.length}');
      }
    } catch (_) {}
  }

  Future<void> _export() async {
    setState(() => exporting = true);
    try {
      final data = await _buyer.api.exportAccountData();
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save your BuyTheWay data',
        fileName: 'buytheway-my-data-$date.json',
        bytes: utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
      );
      if (mounted && path != null) showToast(context, 'Your data was saved');
    } catch (e) {
      if (mounted) showToast(context, _buyer.handleError(e), error: true);
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _loadBlockedCount();
  }

  /// "Maria S." — how the buyer's name appears on their public reviews.
  String get _reviewerName {
    final p = _buyer.profile;
    if (p == null || p.firstName.isEmpty) return 'First name + last initial';
    return p.lastName.isEmpty
        ? p.firstName
        : '${p.firstName} ${p.lastName[0].toUpperCase()}.';
  }

  Widget _hero() => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: DriverColors.heroGradient),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle),
            child: const Icon(Icons.shield_outlined,
                size: 30, color: Colors.white),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your data, your control',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              SizedBox(height: 4),
              Text(
                  'See what\'s shared, take a copy of your data, or close your account.',
                  style: TextStyle(
                      fontSize: 12.5, height: 1.35, color: Color(0xE6FFFFFF))),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: DriverColors.background,
        appBar: settingsAppBar('Privacy & Account',
            centerTitle: true,
            backgroundColor: DriverColors.primary,
            foregroundColor: Colors.white),
        body: ListenableBuilder(
          listenable: _buyer,
          // Header stays put; only the content below it scrolls.
          builder: (context, _) => Column(children: [
            _hero(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom + 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SettingsSectionLabel('Who can see what'),
                          SettingsGroupCard(dividerIndent: 64, children: [
                            const _VisibilityRow(
                              icon: Icons.local_shipping_outlined,
                              title: 'Name, mobile number & delivery address',
                              detail:
                                  'Shared with sellers on orders you place with them, so they can deliver.',
                              audience: 'Sellers you buy from',
                              color: DriverColors.primary,
                            ),
                            _VisibilityRow(
                              icon: Icons.star_outline_rounded,
                              title: 'Your name on reviews',
                              detail: 'Shown to everyone as "$_reviewerName".',
                              audience: 'Public',
                              color: const Color(0xFFB45309),
                            ),
                            const _VisibilityRow(
                              icon: Icons.lock_outline_rounded,
                              title: 'Email, birthday & saved addresses',
                              detail: 'Never shown to sellers or other buyers.',
                              audience: 'Only you',
                              color: DriverColors.success,
                            ),
                            _VisibilityRow(
                              icon: Icons.mark_email_unread_outlined,
                              title: 'Marketing emails',
                              detail:
                                  'Off unless you turn them on in Notifications.',
                              audience: 'Opt-in',
                              color: const Color(0xFF6366F1),
                              onTap: () =>
                                  _push(const BuyerNotificationsScreen()),
                            ),
                          ]),
                          kSettingsGap,
                          const SettingsSectionLabel('Your data'),
                          SettingsGroupCard(children: [
                            SettingsNavTile(
                                icon: Icons.manage_accounts_outlined,
                                title: 'View & correct my information',
                                subtitle:
                                    'Name, mobile number, birthday and photo',
                                onTap: () => _push(const ProfileScreen())),
                            SettingsNavTile(
                              icon: Icons.download_outlined,
                              title: exporting
                                  ? 'Preparing your file…'
                                  : 'Download my data',
                              subtitle:
                                  'A JSON copy of your profile, addresses, orders, reviews, wishlist, followed stores and email choices',
                              onTap: exporting ? null : _export,
                            ),
                            SettingsNavTile(
                              icon: Icons.block_outlined,
                              title: 'Blocked shops',
                              subtitle: 'Review and unblock shops',
                              trailingText: blockedLabel,
                              onTap: () =>
                                  _push(const BuyerBlockedShopsScreen()),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.gavel_rounded,
                                      size: 14,
                                      color: DriverColors.textSecondary),
                                  SizedBox(width: 8),
                                  Expanded(
                                      child: Text(
                                          'Your personal data is handled under the Data Privacy Act of 2012 (RA 10173): you can access, correct and take a copy of it, and ask for it to be removed.',
                                          style: DriverText.caption)),
                                ]),
                          ),
                          kSettingsGap,
                          const SettingsSectionLabel('Close your account',
                              danger: true),
                          _CloseAccountCard(
                              onDeactivate: () =>
                                  startAccountDeactivation(context)),
                        ]),
                  ),
                ],
              ),
            ),
          ]),
        ),
      );
}

/// One "what's shared, and with whom" row with an audience pill.
class _VisibilityRow extends StatelessWidget {
  const _VisibilityRow(
      {required this.icon,
      required this.title,
      required this.detail,
      required this.audience,
      required this.color,
      this.onTap});
  final IconData icon;
  final String title;
  final String detail;
  final String audience;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconTile(icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                            color: DriverColors.textPrimary)),
                    const SizedBox(height: 4),
                    StatusPill(audience, color),
                    const SizedBox(height: 6),
                    Text(detail,
                        style: DriverText.caption.copyWith(height: 1.4)),
                  ]),
            ),
            if (onTap != null)
              Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 19, color: Colors.grey[400])),
          ]),
        ),
      );
}

/// Deactivate vs delete, explained, with the one self-service action.
class _CloseAccountCard extends StatelessWidget {
  const _CloseAccountCard({required this.onDeactivate});
  final VoidCallback onDeactivate;

  Widget _option(IconData icon, String title, String body) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: DriverColors.background,
              borderRadius: BorderRadius.circular(14)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20, color: DriverColors.textSecondary),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: DriverColors.textPrimary)),
            const SizedBox(height: 4),
            Text(body,
                style:
                    DriverText.caption.copyWith(fontSize: 11.5, height: 1.4)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFECACA))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _option(Icons.pause_circle_outline_rounded, 'Deactivate',
                  'Switches your account off and signs you out. It can be turned back on later with everything as you left it.'),
              const SizedBox(width: 10),
              _option(Icons.delete_outline_rounded, 'Delete',
                  'Removes your profile, addresses, wishlist and preferences for good. Past order records stay with the sellers.'),
            ]),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onDeactivate,
              icon: const Icon(Icons.person_off_outlined, size: 19),
              label: const Text('Deactivate my account',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(
                  foregroundColor: DriverColors.error,
                  side: const BorderSide(color: DriverColors.error),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
            ),
          ),
          const SizedBox(height: 10),
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.support_agent_rounded,
                size: 15, color: DriverColors.textSecondary),
            SizedBox(width: 8),
            Expanded(
                child: Text(
                    'Permanent deletion isn\'t self-service yet — it\'s done by our team on request.',
                    style: DriverText.caption)),
          ]),
        ]),
      );
}

// ============================================================
// Blocked shops
// ============================================================

class BuyerBlockedShopsScreen extends StatefulWidget {
  const BuyerBlockedShopsScreen({super.key});

  @override
  State<BuyerBlockedShopsScreen> createState() =>
      _BuyerBlockedShopsScreenState();
}

class _BuyerBlockedShopsScreenState extends State<BuyerBlockedShopsScreen> {
  final shops = <Map<String, dynamic>>[];
  int page = 0;
  int lastPage = 1;
  bool loading = false;
  String? error;
  String? busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next = reset ? 1 : page + 1;
      final result = await _buyer.api.blockedShops(page: next);
      if (mounted) {
        setState(() {
          if (reset) shops.clear();
          shops.addAll(result.$1);
          page = next;
          lastPage = result.$2;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = _buyer.handleError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _unblock(Map<String, dynamic> shop) async {
    final id = '${shop['id']}';
    final confirmed = await confirmDialog(context,
        title: 'Unblock ${shop['name']}?',
        message: 'Its products and messages will be visible again.',
        confirmLabel: 'Unblock');
    if (!confirmed || !mounted) return;
    setState(() => busyId = id);
    try {
      await _buyer.api.unblockShop(id);
      if (mounted) {
        setState(() => shops.removeWhere((item) => '${item['id']}' == id));
        showToast(context, 'Unblocked ${shop['name']}');
      }
    } catch (e) {
      if (mounted) showToast(context, _buyer.handleError(e), error: true);
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) => SettingsPage(
        title: 'Blocked Shops',
        onRefresh: () => _load(reset: true),
        children: [
          if (loading && shops.isEmpty)
            const RowsSkeleton()
          else if (error != null && shops.isEmpty)
            SettingsErrorBanner(
                message: error!, onRetry: () => _load(reset: true))
          else if (shops.isEmpty)
            const EmptyCard(
                icon: Icons.block_outlined,
                title: 'No blocked shops',
                message:
                    'Shops you block will be listed here so you can unblock them any time.')
          else ...[
            if (error != null)
              SettingsErrorBanner(message: error!, onRetry: _load),
            SettingsGroupCard(dividerIndent: 78, children: [
              for (final shop in shops)
                _ShopRow(
                  name: '${shop['name'] ?? 'Shop'}',
                  logo: shop['logo'] as String?,
                  subtitle: shop['blockedAt'] == null
                      ? null
                      : 'Blocked ${SettingsFormat.dateShort(DateTime.tryParse('${shop['blockedAt']}') ?? DateTime.now())}',
                  actionLabel: 'Unblock',
                  blocked: true,
                  busy: busyId == '${shop['id']}',
                  onAction: () => _unblock(shop),
                ),
            ]),
            if (page < lastPage) LoadMore(loading: loading, onTap: _load),
          ],
        ],
      );
}

// ============================================================
// Help & Support
// ============================================================

class BuyerHelpScreen extends StatelessWidget {
  const BuyerHelpScreen({super.key});

  static const _faqs = <(IconData, String, String)>[
    (
      Icons.payments_outlined,
      'How can I pay?',
      'Cash on delivery is currently available. Pay the courier when your parcel arrives; nothing is charged online.'
    ),
    (
      Icons.local_shipping_outlined,
      'How much is shipping?',
      'The shipping fee is shown at checkout and charged once per seller order, however many items you buy from that seller.'
    ),
    (
      Icons.cancel_outlined,
      'Can I cancel an order?',
      'Yes, while it is still New, before the seller starts preparing it. Open the order in My Orders and choose Cancel. After that, message the seller.'
    ),
    (
      Icons.assignment_return_outlined,
      'How do returns and refunds work?',
      'After delivery, open the order and request a return or refund for the item. Each item can have one open request at a time, and the seller reviews it.'
    ),
    (
      Icons.star_outline_rounded,
      'When can I review a product?',
      'After the order is delivered. Items waiting for your review appear in My Reviews.'
    ),
    (
      Icons.chat_bubble_outline_rounded,
      'How do I contact a seller?',
      'Use Chat with seller on a product page or Contact seller on an order. Replies appear in Messages.'
    ),
  ];

  void _push(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) =>
      SettingsPage(title: 'Help & Support', children: [
        const SettingsSectionLabel('Your cases'),
        SettingsGroupCard(children: [
          SettingsNavTile(
              icon: Icons.flag_outlined,
              title: 'My Reports',
              subtitle: 'Track reports you submitted',
              onTap: () => _push(context, const BuyerReportsScreen())),
          SettingsNavTile(
              icon: Icons.receipt_long_outlined,
              title: 'Where is my order?',
              subtitle: 'Open My Orders for status and tracking',
              onTap: () => _push(context, const OrdersScreen())),
        ]),
        kSettingsGap,
        const SettingsSectionLabel('Common questions'),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: SettingsGroupCard(children: [
            for (final (icon, question, answer) in _faqs)
              ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(64, 0, 16, 14),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                iconColor: DriverColors.primary,
                collapsedIconColor: Colors.grey[400],
                leading: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: DriverColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 17, color: DriverColors.primary),
                ),
                title: Text(question,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: DriverColors.textPrimary)),
                children: [
                  Text(answer,
                      style: DriverText.body.copyWith(
                          color: DriverColors.textSecondary, height: 1.45))
                ],
              ),
          ]),
        ),
      ]);
}
