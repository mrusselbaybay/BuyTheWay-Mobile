import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../services/poller.dart';
import '../../services/push_service.dart';
import '../auth/auth_screen.dart';
import '../driver/driver_theme.dart';
import 'dashboard/logistics_dashboard_screen.dart';
import 'inventory/logistics_inventory_screen.dart';
import 'logistics_models.dart';
import 'notifications/logistics_notifications_screen.dart';
import 'settings/logistics_settings_screen.dart';
import 'widgets/logistics_nav_bar.dart';

/// Top-level shell for the Logistics mobile app — reuses the courier app's
/// design system (DriverColors/DriverText, DriverNavBar's visual language
/// via LogisticsNavBar) but with only the three sections the Logistics
/// spec calls for: Dashboard, Inventory, User Settings. No delivery/pickup
/// tabs — that's the courier/driver app's job, not this one's.
///
/// Owns the signed-in account (loaded from `GET /api/auth/user`, the same
/// generic endpoint AuthScreen already uses — there's no dedicated
/// `/logistics/profile` endpoint) and the two inventory lists (Tab 1/Tab 2
/// of the Inventory section), so both the Dashboard's counters and the
/// Inventory screen itself read from one shared, lifted state instead of
/// each re-fetching independently.
class LogisticsShell extends StatefulWidget {
  const LogisticsShell({super.key});

  @override
  State<LogisticsShell> createState() => _LogisticsShellState();
}

class _LogisticsShellState extends State<LogisticsShell> {
  final ApiService _api = ApiService();

  int _tabIndex = 0;

  String? _accessToken;
  LogisticsAccount? _account;
  bool _loadingAccount = true;
  String? _accountLoadError;

  List<InventoryParcel> _pending = [];
  List<InventoryParcel> _scanned = [];
  bool _loadingInventory = true;
  String? _inventoryError;
  bool _inventoryLoaded = false;
  bool _reconnecting = false;

  // ---- Notification bell (Dashboard app bar) ----
  // The unread count rides the same 30s poll tick as the lists. While a scan
  // is open/in flight a new count is held, then applied when it releases, so
  // the shell never repaints under the scanner.
  int _notifUnread = 0;
  int? _heldUnread;

  // ---- Background refresh ----
  // One 30s poll feeds Inventory, For Inventory, the Dashboard counters and the
  // nav badge. Held while a scan is open/in flight; a response that started
  // before a scan finished is dropped (epoch) so it can't put the parcel back
  // into "For Inventory".
  int _epoch = 0;
  int _scanHolds = 0;
  ModalRoute<dynamic>? _route;

  late final Poller _poller = Poller(
    (isActive) async {
      final token = _accessToken;
      if (token == null) return;
      final epoch = _epoch;
      // Failure of the count alone is silent; the lists decide the poll's fate.
      final count = _api.getLogisticsUnreadCount(accessToken: token).then<int?>((c) => c).catchError((_) => null);
      final lists = await _fetchLists(token);
      final unread = await count;
      if (!isActive() || !mounted) return;
      if (unread != null) _setNotifUnread(unread);
      if (epoch != _epoch || _scanHolds > 0) return;
      _applyLists(lists.pending, lists.scanned);
    },
    interval: const Duration(seconds: 30),
    // Not on Settings, not while a detail/scanner route covers the shell.
    shouldSkip: () => _tabIndex == 2 || _scanHolds > 0 || _route?.isCurrent == false,
    onError: _onPollError,
  );

  void _onPollError(Object error) {
    if (!mounted) return;
    if (error is ApiException && (error.statusCode == 401 || error.statusCode == 403)) {
      setState(() {
        _reconnecting = false;
        _inventoryError = 'Your session has expired. Please sign in again.';
      });
    } else if (!_reconnecting) {
      setState(() => _reconnecting = true);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAccount();
    // A tapped push (also a cold-start one) opens the notifications inbox.
    PushService.instance.pendingTap.addListener(_onPushTap);
  }

  void _onPushTap() {
    final tap = PushService.instance.pendingTap.value;
    // Not ready yet (cold start): stays pending until the account has loaded.
    if (tap == null || !mounted || _accessToken == null) return;
    PushService.instance.clearTap();
    // The staff app has no chat; every push opens the inbox.
    Navigator.of(context).popUntil((route) => route.isFirst);
    unawaited(_openNotifications());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    PushService.instance.pendingTap.removeListener(_onPushTap);
    _poller.stop();
    super.dispose();
  }

  /// A scan started/finished somewhere below; bumping the epoch invalidates
  /// any poll already in flight.
  void _setScanActive(bool active) {
    _scanHolds = active ? _scanHolds + 1 : (_scanHolds > 0 ? _scanHolds - 1 : 0);
    _epoch++;
    if (_scanHolds == 0 && _heldUnread != null) {
      final held = _heldUnread!;
      _heldUnread = null;
      // After the frame: the release can happen while the scan route is popping.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setNotifUnread(held);
      });
    }
  }

  /// Shows a new unread count, or holds it while a scan is active.
  void _setNotifUnread(int count) {
    if (_scanHolds > 0) {
      _heldUnread = count;
      return;
    }
    if (count == _notifUnread) return;
    setState(() => _notifUnread = count);
  }

  Future<void> _refreshNotifUnread() async {
    final token = _accessToken;
    if (token == null) return;
    try {
      final count = await _api.getLogisticsUnreadCount(accessToken: token);
      if (mounted) _setNotifUnread(count);
    } catch (_) {
      // Silent: a stale badge is fine, the next poll tick corrects it.
    }
  }

  Future<void> _openNotifications() async {
    final token = _accessToken;
    if (token == null || _scanHolds > 0) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LogisticsNotificationsScreen(
          accessToken: token,
          onUnreadChanged: _setNotifUnread,
          onOpenInventory: () => _selectTab(1),
          isScanActive: () => _scanHolds > 0,
          onScanActive: _setScanActive,
          onScanned: _onParcelScanned,
          onPollError: _onPollError,
        ),
      ),
    );
    // Back on the shell: reconcile the badge and the lists.
    if (mounted) {
      unawaited(_refreshNotifUnread());
      unawaited(_poller.refreshIfStale());
    }
  }

  /// Optimistic move after a confirmed scan; the follow-up refresh reconciles.
  void _onParcelScanned(InventoryParcel parcel) {
    _epoch++;
    setState(() {
      _pending = _pending.where((p) => p.id != parcel.id).toList();
      _scanned = [parcel, ..._scanned.where((p) => p.id != parcel.id)];
    });
    unawaited(_poller.refreshNow());
  }

  String _fingerprint(InventoryParcel p) => [
        p.status,
        p.inventoryScannedAt,
        p.forInventoryAt,
        p.courier?.id,
        p.courier?.firstName,
        p.courier?.lastName,
        p.hubName,
        p.transferToCompanyName,
        p.trackingNumber,
        p.confirmationToken,
        p.isReturn,
        p.items.length,
      ].join('|');

  /// Keeps the existing object for every unchanged parcel.
  List<InventoryParcel> _merge(List<InventoryParcel> old, List<InventoryParcel> fresh) {
    final byId = {for (final p in old) p.id: p};
    return [
      for (final f in fresh)
        if (byId[f.id] case final o? when _fingerprint(o) == _fingerprint(f)) o else f,
    ];
  }

  bool _sameList(List<InventoryParcel> a, List<InventoryParcel> b) =>
      a.length == b.length && [for (var i = 0; i < a.length; i++) identical(a[i], b[i])].every((e) => e);

  /// Rebuilds only when something visible changed.
  void _applyLists(List<InventoryParcel> pending, List<InventoryParcel> scanned) {
    final nextPending = _merge(_pending, pending);
    final nextScanned = _merge(_scanned, scanned);
    final changed = !_sameList(nextPending, _pending) || !_sameList(nextScanned, _scanned) || _reconnecting || _inventoryError != null || _loadingInventory;
    if (!changed) return;
    setState(() {
      _pending = nextPending;
      _scanned = nextScanned;
      _reconnecting = false;
      _inventoryError = null;
      _loadingInventory = false;
      _inventoryLoaded = true;
    });
  }

  Future<({List<InventoryParcel> pending, List<InventoryParcel> scanned})> _fetchLists(String token) async {
    final results = await Future.wait([
      _api.getPendingInventory(accessToken: token),
      _api.getInventory(accessToken: token),
    ]);
    List<InventoryParcel> parse(dynamic body) =>
        (body['data'] as List? ?? []).map((row) => InventoryParcel.fromApi(Map<String, dynamic>.from(row as Map))).toList();
    return (pending: parse(results[0]), scanned: parse(results[1]));
  }

  Future<void> _loadAccount() async {
    setState(() {
      _loadingAccount = true;
      _accountLoadError = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      setState(() {
        _loadingAccount = false;
        _accountLoadError = 'Your session has expired. Please sign in again.';
      });
      return;
    }

    try {
      final response = await _api.getUser(token);
      if (!mounted) return;
      setState(() {
        _accessToken = token;
        _account = LogisticsAccount.fromUserResponse(response);
        _loadingAccount = false;
      });
      unawaited(_loadInventory().then((_) {
        if (mounted && _accessToken != null) _poller.start();
      }));
      unawaited(_refreshNotifUnread());
      unawaited(PushService.instance.register(token));
      WidgetsBinding.instance.addPostFrameCallback((_) => _onPushTap());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAccount = false;
        _accountLoadError = e.statusCode == 401 ? 'Your session has expired. Please sign in again.' : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingAccount = false;
        _accountLoadError = 'Could not reach the server. Check your connection and try again.';
      });
    }
  }

  /// First load and explicit refreshes. The skeleton only shows on the very
  /// first load; later calls keep the current lists on screen.
  Future<void> _loadInventory() async {
    final token = _accessToken;
    if (token == null) return;

    if (!_inventoryLoaded) {
      setState(() {
        _loadingInventory = true;
        _inventoryError = null;
      });
    }

    final epoch = _epoch;
    try {
      final lists = await _fetchLists(token);
      if (!mounted) return;
      if (epoch != _epoch || _scanHolds > 0) {
        // A scan landed meanwhile: its own refresh will bring the truth.
        if (!_inventoryLoaded) setState(() => _loadingInventory = false);
        return;
      }
      _applyLists(lists.pending, lists.scanned);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingInventory = false;
        if (!_inventoryLoaded || e.statusCode == 401) {
          _inventoryError = e.statusCode == 401 ? 'Your session has expired. Please sign in again.' : e.message;
        } else {
          _reconnecting = true; // keep last good data
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingInventory = false;
        if (!_inventoryLoaded) {
          _inventoryError = 'Could not reach the server. Check your connection and try again.';
        } else {
          _reconnecting = true;
        }
      });
    }
  }

  /// Pull-to-refresh + the landing point after a successful scan moves one
  /// row from [_pending] to [_scanned] — re-fetches both lists rather than
  /// patching in place, since a scan also affects Dashboard's counters.
  Future<void> _refreshAll() async {
    await _loadInventory();
  }

  void _selectTab(int i) {
    if (i == _tabIndex) return;
    setState(() => _tabIndex = i);
    if (i != 2) unawaited(_poller.refreshIfStale());
  }

  Future<void> _signOutToLogin() async {
    _poller.stop();
    await PushService.instance.unregister(); // needs the session, so before it is cleared
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthScreen(portal: AuthPortal.partner)), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingAccount) {
      return const Scaffold(
        backgroundColor: DriverColors.background,
        body: Center(child: CircularProgressIndicator(color: DriverColors.primary)),
      );
    }

    final account = _account;
    final accessToken = _accessToken;
    if (account == null || accessToken == null) {
      return Scaffold(
        backgroundColor: DriverColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 48, color: DriverColors.textSecondary),
                  const SizedBox(height: 16),
                  Text(_accountLoadError ?? 'Something went wrong loading your account.', textAlign: TextAlign.center, style: DriverText.body),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loadAccount,
                    style: ElevatedButton.styleFrom(backgroundColor: DriverColors.primary, foregroundColor: Colors.white),
                    child: const Text('Try again'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(onPressed: _signOutToLogin, child: const Text('Back to sign in')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final pages = [
      LogisticsDashboardScreen(
        account: account,
        pending: _pending,
        scanned: _scanned,
        loading: _loadingInventory,
        error: _inventoryError,
        onRefresh: _refreshAll,
        onOpenInventory: () => _selectTab(1),
        unreadNotifications: _notifUnread,
        onOpenNotifications: _openNotifications,
      ),
      LogisticsInventoryScreen(
        pending: _pending,
        scanned: _scanned,
        loading: _loadingInventory,
        error: _inventoryError,
        accessToken: accessToken,
        onRefresh: _refreshAll,
        reconnecting: _reconnecting,
        onScanActive: _setScanActive,
        onScanned: _onParcelScanned,
      ),
      LogisticsSettingsScreen(
        account: account,
        accessToken: accessToken,
        onSignOut: _signOutToLogin,
        onRefresh: _refreshAll,
      ),
    ];

    return Scaffold(
      backgroundColor: DriverColors.background,
      body: IndexedStack(index: _tabIndex, children: pages),
      bottomNavigationBar: LogisticsNavBar(currentIndex: _tabIndex, onTap: _selectTab, badges: {1: _pending.length}),
    );
  }
}
