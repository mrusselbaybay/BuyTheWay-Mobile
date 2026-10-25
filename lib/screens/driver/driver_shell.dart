import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../services/push_service.dart';
import '../../services/poller.dart';
import '../auth/auth_screen.dart';
import 'chat/driver_chat_controller.dart';
import 'chat/driver_chat_list_screen.dart';
import 'deliveries/driver_deliveries_screen.dart';
import 'deliveries/assigned_delivery_detail_screen.dart';
import 'driver_models.dart';
import 'driver_theme.dart';
import 'earnings/driver_earnings_screen.dart';
import 'history/driver_history_screen.dart';
import 'home/deliver_order_screen.dart';
import 'home/delivery_request_details_screen.dart';
import 'home/courier_home_screen.dart';
import 'home/driver_home_screen.dart';
import 'home/pickup_order_screen.dart';
import 'notifications/driver_notifications_screen.dart';
import '../../services/remittance_api_service.dart';
import '../remittances/remittances_screen.dart';
import 'settings/driver_settings_screen.dart';
import 'widgets/driver_nav_bar.dart';
import 'widgets/driver_shared_widgets.dart';

/// Owns every piece of shared state for the driver app (online status,
/// the in-progress delivery, available requests, history, chat threads,
/// earnings balance) so it survives tab switches — the same lifted-state
/// pattern used by [CourierDashboard] (courier_dashboard.dart).
///
/// The signed-in [DriverAccount] itself is real, not mock: it's loaded
/// from `GET /api/driver/profile` on startup using the token
/// [DriverLoginScreen] saved. Everything else in this shell (deliveries,
/// history, chat, earnings) is still the module's existing mock data —
/// only the Settings/account data was in scope to become functional.
class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  final ApiService _api = ApiService();

  int _tabIndex = 0;
  bool _isOnline = false;
  DateTime? _shiftStart;
  ActiveDelivery? _activeDelivery;
  List<DeliveryRequest> _availableRequests = [];

  // ---- Deliveries tab — real data from GET /api/driver/deliveries, not
  // hardcoded (see AssignedDelivery.fromApi / DriverDeliveryController).
  List<AssignedDelivery> _assignedDeliveries = [];
  Map<String, dynamic>? _parcelCapacity;
  bool _loadingDeliveries = true;
  String? _deliveriesError;

  final List<HistoryEntry> _history = mockHistory();
  DriverChatController? _chatController;
  double _availableBalance = 4820;
  final List<WithdrawalRecord> _withdrawals = mockWithdrawals();

  // Settings preferences — lifted up here (same pattern as the rest of this
  // shell's state) so they survive switching away from the Account tab and
  // stay in sync between the Account screen and the Settings screen.
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  String _language = 'English';

  // ---- Real account loading state ----
  String? _accessToken;
  DriverAccount? _account;
  bool _loadingAccount = true;
  String? _accountLoadError;

  // ---- Background refresh of the deliveries list ----
  // One poll feeds Home, Deliveries and History (they all read
  // _assignedDeliveries). 30s while online on a data tab, ~every 2 min when
  // offline. Held while the availability toggle is saving, while another route
  // covers the shell (detail screens poll themselves), and a response that
  // started before a toggle/load finished is dropped (epoch).
  int _deliveriesEpoch = 0;
  int _pollTicks = 0;
  bool _deliveriesLoaded = false;
  ModalRoute<dynamic>? _route;

  // ---- Notification bell (Home header) ----
  // The unread count rides the deliveries poll tick below (no second poller).
  // While a pickup/scan/photo flow opened from the inbox is running, a new
  // count is held and applied when it releases, so the shell never repaints
  // under the rider's hands. Offline riders still refresh the count about
  // every 45s (see _countDue) so the badge can't get stuck.
  int _notifUnread = 0;
  int? _heldUnread;
  int _busyHolds = 0;
  DateTime _unreadAt = DateTime.fromMillisecondsSinceEpoch(0);

  late final Poller _deliveriesPoller = Poller(
    (isActive) async {
      final token = _accessToken;
      if (token == null) return;
      // Offline riders only need an occasional check (every 4th tick).
      final deliveriesDue = _isOnline || ++_pollTicks % 4 == 0;
      final countDue = deliveriesDue ||
          DateTime.now().difference(_unreadAt) > const Duration(seconds: 45);
      if (!countDue) return;
      // Failure of the count alone is silent; the deliveries call decides the poll's fate.
      final count = _fetchUnread(token);
      if (!deliveriesDue) {
        final unread = await count;
        if (isActive() && mounted && unread != null) _setNotifUnread(unread);
        return;
      }
      final epoch = _deliveriesEpoch;
      final response = await _api.getDriverDeliveries(accessToken: token);
      final rows = (response['data'] as List? ?? [])
          .map((row) =>
              AssignedDelivery.fromApi(Map<String, dynamic>.from(row as Map)))
          .toList();
      final unread = await count;
      if (!isActive() || !mounted) return;
      if (unread != null) _setNotifUnread(unread);
      // The count never touches delivery state; a stale delivery response is still dropped.
      if (epoch != _deliveriesEpoch ||
          _togglePending ||
          _route?.isCurrent == false) {
        return;
      }
      _mergeDeliveries(rows);
    },
    interval: const Duration(seconds: 30),
    shouldSkip: () =>
        _accessToken == null ||
        _togglePending ||
        _tabIndex == 3 ||
        _tabIndex == 4 ||
        _route?.isCurrent == false,
    onError: _onPollError,
  );

  /// 401/403 halts the poller (Poller does that) and flags the session as expired.
  void _onPollError(Object e) {
    if (mounted &&
        e is ApiException &&
        (e.statusCode == 401 || e.statusCode == 403)) {
      setState(() =>
          _deliveriesError = 'Your session has expired. Please sign in again.');
    }
  }

  Future<int?> _fetchUnread(String token) =>
      _api.getDriverUnreadCount(accessToken: token).then<int?>((c) {
        _unreadAt = DateTime.now();
        return c;
      }).catchError((_) => null);

  /// Shows a new unread count, or holds it while a flow is running.
  void _setNotifUnread(int count) {
    if (_busyHolds > 0) {
      _heldUnread = count;
      return;
    }
    if (count == _notifUnread) return;
    setState(() => _notifUnread = count);
  }

  /// A pickup/scan/photo flow opened from the inbox started/finished.
  void _setNotifBusy(bool busy) {
    _busyHolds = busy ? _busyHolds + 1 : (_busyHolds > 0 ? _busyHolds - 1 : 0);
    if (_busyHolds != 0) return;
    final held = _heldUnread;
    _heldUnread = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (held != null) _setNotifUnread(held);
      _onPushTap();
    });
  }

  Future<void> _refreshNotifUnread() async {
    final token = _accessToken;
    if (token == null) return;
    final count = await _fetchUnread(token);
    if (mounted && count != null) _setNotifUnread(count);
  }

  Future<void> _openNotifications() async {
    final token = _accessToken;
    final chat = _chatController;
    if (token == null || chat == null || _busyHolds > 0) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DriverNotificationsScreen(
          accessToken: token,
          controller: chat,
          onUnreadChanged: _setNotifUnread,
          onOpenDeliveries: () => _selectTab(1),
          onOpenTarget: (target) => _selectTab(target == 'account' ? 4 : 2),
          isBusy: () => _busyHolds > 0,
          onBusy: _setNotifBusy,
          onPollError: _onPollError,
        ),
      ),
    );
    // Back on the shell: reconcile the badge and the lists.
    if (mounted) {
      unawaited(_refreshNotifUnread());
      unawaited(_deliveriesPoller.refreshIfStale());
    }
  }

  bool get _togglePending =>
      (_availabilityWrite?.isActive ?? false) || _toggleInFlight;
  bool _toggleInFlight = false;

  /// Replaces only the rows that changed; no rebuild when nothing did.
  void _mergeDeliveries(List<AssignedDelivery> fresh) {
    final byId = {for (final d in _assignedDeliveries) d.id: d};
    final merged = [
      for (final f in fresh)
        if (byId[f.id] case final old? when old.fingerprint == f.fingerprint)
          old
        else
          f,
    ];
    final same = merged.length == _assignedDeliveries.length &&
        [
          for (var i = 0; i < merged.length; i++)
            identical(merged[i], _assignedDeliveries[i])
        ].every((e) => e);
    if (same && !_loadingDeliveries && _deliveriesError == null) return;
    setState(() {
      _assignedDeliveries = merged;
      _loadingDeliveries = false;
      _deliveriesError = null;
      _deliveriesLoaded = true;
    });
  }

  void _selectTab(int i) {
    if (i == _tabIndex) return;
    setState(() => _tabIndex = i);
    if (i <= 2) unawaited(_deliveriesPoller.refreshIfStale());
  }

  /// Seam for push/realtime: a notification handler can call this to pull
  /// deliveries immediately (new assignment, cancellation).
  Future<void> refreshDeliveriesNow() => _deliveriesPoller.refreshNow();

  @override
  void initState() {
    super.initState();
    _loadAccount();
    // A tapped push (also a cold-start one) opens chat or the notifications inbox.
    PushService.instance.pendingTap.addListener(_onPushTap);
  }

  void _onPushTap() {
    final tap = PushService.instance.pendingTap.value;
    // Not ready yet (cold start): stays pending until the account has loaded.
    if (tap == null ||
        !mounted ||
        _accessToken == null ||
        _chatController == null ||
        _busyHolds > 0) {
      return;
    }
    PushService.instance.clearTap();
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (tap.isMessage) {
      _selectTab(3);
    } else if (tap.target == 'deliveries') {
      if (tap.parcelId != null) {
        unawaited(_openPushParcel(tap.parcelId!));
      } else {
        _selectTab(1);
      }
    } else if (tap.target == 'remittances' || tap.target == 'earnings') {
      _selectTab(2);
    } else if (tap.target == 'account') {
      _selectTab(4);
    } else {
      unawaited(_openNotifications());
    }
  }

  Future<void> _openPushParcel(String parcelId) async {
    final token = _accessToken;
    final controller = _chatController;
    if (token == null || controller == null || _busyHolds > 0) return;
    try {
      final response =
          await _api.getDriverDelivery(accessToken: token, id: parcelId);
      if (!mounted) return;
      final delivery = AssignedDelivery.fromApi(
          Map<String, dynamic>.from(response['data'] as Map));
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AssignedDeliveryDetailScreen(
            delivery: delivery,
            accessToken: token,
            controller: controller,
            onBusyChanged: _setNotifBusy),
      ));
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 404) {
        _selectTab(1);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No longer assigned to you')));
      } else {
        _onPollError(error);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Could not open the delivery. Check your connection.')));
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  void _onChatControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    PushService.instance.pendingTap.removeListener(_onPushTap);
    _deliveriesPoller.stop();
    _availabilityWrite?.cancel();
    _chatController?.removeListener(_onChatControllerChanged);
    _chatController?.dispose();
    super.dispose();
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
      final accountPrefsKey = token.hashCode.toString();
      _notificationsEnabled = prefs.getBool('driver_notifications_enabled_$accountPrefsKey') ?? true;
      _soundEnabled = prefs.getBool('driver_sound_enabled_$accountPrefsKey') ?? true;
      final response = await _api.getDriverProfile(accessToken: token);
      if (!mounted) return;
      final account = DriverAccount.fromApi(response);
      try {
        final preferenceResponse = await _api.getDriverNotificationPreferences(accessToken: token);
        final preferenceData = Map<String, dynamic>.from(preferenceResponse['data'] as Map? ?? {});
        _notificationsEnabled = preferenceData['push_enabled'] != false;
        _soundEnabled = preferenceData['sound_enabled'] != false;
        await prefs.setBool('driver_notifications_enabled_$accountPrefsKey', _notificationsEnabled);
        await prefs.setBool('driver_sound_enabled_$accountPrefsKey', _soundEnabled);
      } catch (_) {
        // Older deployments can still use the local preference cache.
      }
      setState(() {
        _accessToken = token;
        _account = account;
        _chatController ??= DriverChatController(api: _api, accessToken: token)
          ..addListener(_onChatControllerChanged);
        _loadingAccount = false;
        // Restore the "Go online" state the rider left the app in — it's
        // persisted server-side (driver_details/courier_details.delivery_status),
        // toggled from the Settings screen.
        _isOnline = account.isOnline;
        if (_isOnline) {
          _shiftStart ??= DateTime.now();
          if (_availableRequests.isEmpty) {
            _availableRequests = mockAvailableRequests();
          }
        }
      });
      // Fire-and-forget — Deliveries has its own loading/error state and
      // shouldn't hold up the rest of the shell rendering.
      unawaited(_loadDeliveries().then((_) {
        if (mounted && _accessToken != null) _deliveriesPoller.start();
      }));
      unawaited(_refreshNotifUnread());
      unawaited(PushService.instance.register(token));
      WidgetsBinding.instance.addPostFrameCallback((_) => _onPushTap());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAccount = false;
        _accountLoadError = e.statusCode == 401
            ? 'Your session has expired. Please sign in again.'
            : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAccount = false;
        _accountLoadError =
            'Could not reach the server. Check your connection and try again.';
      });
    }
  }

  Future<void> _saveNotificationPreference(
    String token, {
    bool? pushEnabled,
    bool? soundEnabled,
    required bool previous,
    required bool isSound,
  }) async {
    try {
      await _api.updateDriverNotificationPreferences(
        accessToken: token,
        pushEnabled: pushEnabled,
        soundEnabled: soundEnabled,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (isSound) {
          _soundEnabled = previous;
        } else {
          _notificationsEnabled = previous;
        }
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(isSound ? 'driver_sound_enabled_${token.hashCode}' : 'driver_notifications_enabled_${token.hashCode}', previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save notification setting. Try again.')),
      );
    }
  }

  /// Loads the Deliveries tab from `GET /api/driver/deliveries`. Called
  /// once the account (and therefore the access token) is available, and
  /// again on pull-to-refresh from DriverDeliveriesScreen.
  Future<void> _loadDeliveries() async {
    final token = _accessToken;
    if (token == null) return;

    // The skeleton is for the very first load only; later calls (pull to
    // refresh, returning from a detail) keep the list on screen.
    if (!_deliveriesLoaded) {
      setState(() {
        _loadingDeliveries = true;
        _deliveriesError = null;
      });
    }

    final epoch = _deliveriesEpoch;
    try {
      final response = await _api.getDriverDeliveries(accessToken: token);
      final rows = (response['data'] as List? ?? [])
          .map((row) =>
              AssignedDelivery.fromApi(Map<String, dynamic>.from(row as Map)))
          .toList();
      if (!mounted) return;
      if (epoch != _deliveriesEpoch && _deliveriesLoaded) return;
      _parcelCapacity = response['capacity'] is Map
          ? Map<String, dynamic>.from(response['capacity'] as Map)
          : null;
      _mergeDeliveries(rows);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDeliveries = false;
        if (!_deliveriesLoaded || e.statusCode == 401) {
          _deliveriesError = e.statusCode == 401
              ? 'Your session has expired. Please sign in again.'
              : e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDeliveries = false;
        if (!_deliveriesLoaded) {
          _deliveriesError =
              'Could not reach the server. Check your connection and try again.';
        }
      });
    }
  }

  /// Pull-to-refresh for every tab: re-reads the profile and the
  /// assigned deliveries together. Unlike [_loadAccount] it deliberately
  /// doesn't flip `_loadingAccount`, because that would swap the whole
  /// shell for a spinner underneath the refresh indicator that triggered
  /// it. A failure leaves the last-known data on screen and surfaces as a
  /// snackbar — the pull was an update, not a fresh load.
  Future<void> _refreshAll() async {
    final token = _accessToken;
    if (token == null) {
      await _loadAccount();
      return;
    }

    try {
      final response = await _api.getDriverProfile(accessToken: token);
      if (!mounted) return;
      final account = DriverAccount.fromApi(response);
      setState(() {
        // Mutated in place: the same DriverAccount instance is handed by
        // reference to every tab and to already-pushed detail pages.
        _account?.applyFrom(account);
        _isOnline = account.isOnline;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.message
          : 'Could not reach the server. Check your connection and try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            backgroundColor: DriverColors.error),
      );
    }

    unawaited(_refreshNotifUnread());
    await _loadDeliveries();
  }

  Future<void> _signOutToLogin() async {
    _deliveriesPoller.stop();
    await PushService.instance
        .unregister(); // needs the session, so before it is cleared
    PushService.instance.clearTap();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => const AuthScreen(portal: AuthPortal.partner)),
        (route) => false);
  }

  /// Pending debounced availability write (see [_setOnline]).
  Timer? _availabilityWrite;

  /// Flips the "Go online" shift flag. The Settings switch animates itself
  /// the instant it's tapped; this only updates the shell-level state the
  /// Home tab reads (shift clock, request list) and schedules the backend
  /// write. The write (`PUT /api/driver/availability` →
  /// driver_details/courier_details.delivery_status) is debounced so a
  /// flurry of taps costs one request carrying the final value, and rolls
  /// the UI back if it fails. Invoked from the Settings toggle and the
  /// Home tab's empty-state prompt.
  void _setOnline(bool online) {
    if (online == _isOnline) return;

    setState(() {
      _isOnline = online;
      if (online) {
        _shiftStart ??= DateTime.now();
        if (_availableRequests.isEmpty) {
          _availableRequests = mockAvailableRequests();
        }
      } else {
        _shiftStart = null;
        _availableRequests = <DeliveryRequest>[];
      }
    });

    _deliveriesEpoch++;
    _availabilityWrite?.cancel();
    _availabilityWrite = Timer(
        const Duration(milliseconds: 450), () => _persistAvailability(online));
  }

  Future<void> _persistAvailability(bool online) async {
    final token = _accessToken;
    if (token == null) return;
    // Nothing to do if the server already holds this value (e.g. the rider
    // toggled off then back on within the debounce window).
    if ((_account?.isOnline ?? false) == online) return;

    _toggleInFlight = true;
    try {
      await _api.updateDriverAvailability(accessToken: token, online: online);
      _account?.deliveryStatus = online ? 'available' : 'unavailable';
    } catch (e) {
      if (!mounted || _isOnline != online) {
        return; // superseded by a newer toggle
      }
      setState(() {
        _isOnline = !online;
        if (online) {
          _shiftStart = null;
          _availableRequests = <DeliveryRequest>[];
        } else {
          _shiftStart ??= DateTime.now();
          if (_availableRequests.isEmpty) {
            _availableRequests = mockAvailableRequests();
          }
        }
      });
      final message = e is ApiException
          ? e.message
          : 'Could not update your status. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            backgroundColor: DriverColors.error),
      );
    } finally {
      _toggleInFlight = false;
      _deliveriesEpoch++;
    }
  }

  Future<void> _refreshRequests() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted || !_isOnline) return;
    setState(() => _availableRequests = mockAvailableRequests());
  }

  Future<void> _openRequestDetails(DeliveryRequest request) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => DeliveryRequestDetailsScreen(
              request: request, capacity: _parcelCapacity)),
    );
    if (!mounted) return;
    if (result == true) {
      setState(() {
        _availableRequests.removeWhere((r) => r.id == request.id);
        _activeDelivery = ActiveDelivery(request: request);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Delivery accepted — head to ${request.pickupLabel}.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: DriverColors.primaryDark),
      );
    } else if (result == false) {
      setState(() => _availableRequests.removeWhere((r) => r.id == request.id));
    }
  }

  void _updateActiveDelivery(void Function(ActiveDelivery) mutate) {
    final active = _activeDelivery;
    if (active == null) return;
    setState(() => mutate(active));
  }

  void _completeActiveDelivery() {
    final active = _activeDelivery;
    if (active == null) return;
    setState(() {
      _history.insert(
        0,
        HistoryEntry(
          id: 'h-${DateTime.now().millisecondsSinceEpoch}',
          customerName: active.request.customerName,
          pickupLabel: active.request.pickupLabel,
          dropoffLabel: active.request.dropoffLabel,
          completedAt: DateTime.now(),
          earnings: active.request.estimatedFare,
          status: HistoryStatus.completed,
          etaMinutes: active.request.etaMinutes,
          actualMinutes:
              DateTime.now().difference(active.request.requestedAt).inMinutes,
        ),
      );
      _availableBalance += active.request.estimatedFare;
      _activeDelivery = null;
    });
  }

  Future<void> _openActiveDeliveryFlow() async {
    final active = _activeDelivery;
    if (active == null) return;

    if (active.stage == DeliveryStage.headingToPickup ||
        active.stage == DeliveryStage.atPickup) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PickupOrderScreen(
            delivery: active,
            onArrived: () =>
                _updateActiveDelivery((d) => d.stage = DeliveryStage.atPickup),
            onPhotoAttached: () =>
                _updateActiveDelivery((d) => d.pickupPhotoAttached = true),
            onConfirmPickup: () {
              _updateActiveDelivery(
                  (d) => d.stage = DeliveryStage.headingToDropoff);
              Navigator.pop(context);
            },
          ),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DeliverOrderScreen(
            delivery: active,
            onArrived: () =>
                _updateActiveDelivery((d) => d.stage = DeliveryStage.atDropoff),
            onPhotoAttached: () =>
                _updateActiveDelivery((d) => d.deliveryPhotoAttached = true),
            onNotesChanged: (text) =>
                _updateActiveDelivery((d) => d.deliveryNotes = text),
            onMarkDelivered: () {
              _completeActiveDelivery();
              Navigator.pop(context);
              DriverTopNotification.show(context,
                  message: 'Delivery completed!');
            },
          ),
        ),
      );
    }
  }

  // History no longer has its own bottom-nav tab — it's reached as a
  // pushed screen (with Flutter's own back button) from the compact icon
  // shortcut in the Deliveries app bar, rather than a persistent tab, per
  // the "compact utility, not a full nav tab" requirement.
  //
  // Fed the same real `_assignedDeliveries` list (and its loading/error
  // state + refresh callback) the Deliveries tab already loads from
  // `GET /api/driver/deliveries` — History just filters it down to the
  // delivered rows, rather than pulling from the module's separate mock
  // `_history` list. `_history`/mockHistory() itself is still used
  // elsewhere in this shell (Earnings balance, Home tab's today stats,
  // completing a mock Home-tab delivery) — none of that is backed by a
  // real earnings API yet, so it stays mock for now; only History's own
  // screen moved to real data.
  void _openHistory() {
    final token = _accessToken;
    if (token == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DriverHistoryScreen(
        deliveries: _assignedDeliveries,
        accessToken: token,
        loading: _loadingDeliveries,
        error: _deliveriesError,
        onRefresh: _loadDeliveries,
      ),
    ));
  }

  void _withdraw(double amount, String destination) {
    setState(() {
      _availableBalance -= amount;
      _withdrawals.insert(
          0,
          WithdrawalRecord(
              id: 'w-${DateTime.now().millisecondsSinceEpoch}',
              amount: amount,
              requestedAt: DateTime.now(),
              destination: destination));
    });
  }

  int get _unreadChats => _chatController?.unreadTotal ?? 0;

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  double get _todayEarnings => _history
      .where(
          (h) => h.status == HistoryStatus.completed && _isToday(h.completedAt))
      .fold(0, (sum, h) => sum + h.earnings);

  @override
  Widget build(BuildContext context) {
    if (_loadingAccount) {
      return const Scaffold(
        backgroundColor: DriverColors.background,
        body: Center(
          child: CircularProgressIndicator(color: DriverColors.primary),
        ),
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
                  const Icon(Icons.wifi_off_rounded,
                      size: 48, color: DriverColors.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    _accountLoadError ??
                        'Something went wrong loading your account.',
                    textAlign: TextAlign.center,
                    style: DriverText.body,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loadAccount,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: DriverColors.primary,
                        foregroundColor: Colors.white),
                    child: const Text('Try again'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                      onPressed: _signOutToLogin,
                      child: const Text('Back to sign in')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final pages = [
      if (account.role == 'courier')
        CourierHomeScreen(
          account: account,
          accessToken: accessToken,
          isOnline: _isOnline,
          deliveries: _assignedDeliveries,
          loading: _loadingDeliveries,
          error: _deliveriesError,
          controller: _chatController!,
          onRefresh: _loadDeliveries,
          onOpenDeliveries: () => _selectTab(1),
          onOpenRemittances: () => _selectTab(2),
          unreadNotifications: _notifUnread,
          onOpenNotifications: _openNotifications,
        )
      else
        DriverHomeScreen(
          isOnline: _isOnline,
          shiftStart: _shiftStart,
          account: account,
          activeDelivery: _activeDelivery,
          availableRequests: _availableRequests,
          todayEarnings: _todayEarnings,
          completedToday: _history
              .where((h) =>
                  h.status == HistoryStatus.completed &&
                  _isToday(h.completedAt))
              .length,
          onGoOnline: () => _setOnline(true),
          onOpenRequest: _openRequestDetails,
          onContinueActiveDelivery: _openActiveDeliveryFlow,
          onRefreshRequests: _refreshRequests,
          unreadNotifications: _notifUnread,
          onOpenNotifications: _openNotifications,
        ),
      DriverDeliveriesScreen(
        deliveries: _assignedDeliveries,
        capacity: _parcelCapacity,
        accessToken: accessToken,
        loading: _loadingDeliveries,
        error: _deliveriesError,
        onRefresh: _loadDeliveries,
        onOpenHistory: _openHistory,
        controller: _chatController!,
      ),
      account.role == 'courier'
          ? RemittancesScreen(
              accessToken: accessToken,
              role: RemittanceRole.courier,
              active: _tabIndex == 2,
            )
          : DriverEarningsScreen(
              todayEarnings: _todayEarnings,
              availableBalance: _availableBalance,
              withdrawals: _withdrawals,
              onWithdraw: _withdraw,
              onRefresh: _refreshAll,
            ),
      DriverChatListScreen(
        controller: _chatController!,
        isActive: _tabIndex == 3,
      ),
      DriverSettingsScreen(
        account: account,
        accessToken: accessToken,
        deliveryOnline: _isOnline,
        onDeliveryOnlineChanged: _setOnline,
        notificationsEnabled: _notificationsEnabled,
        onNotificationsChanged: (v) {
            final previous = _notificationsEnabled;
          setState(() => _notificationsEnabled = v);
            final token = _accessToken;
            if (token != null) SharedPreferences.getInstance().then((prefs) => prefs.setBool('driver_notifications_enabled_${token.hashCode}', v));
            if (token != null) unawaited(_saveNotificationPreference(token, pushEnabled: v, previous: previous, isSound: false));
        },
        soundEnabled: _soundEnabled,
        onSoundChanged: (v) {
            final previous = _soundEnabled;
          setState(() => _soundEnabled = v);
            final token = _accessToken;
            if (token != null) SharedPreferences.getInstance().then((prefs) => prefs.setBool('driver_sound_enabled_${token.hashCode}', v));
            if (token != null) unawaited(_saveNotificationPreference(token, soundEnabled: v, previous: previous, isSound: true));
        },
        language: _language,
        onLanguageChanged: (v) => setState(() => _language = v),
        onRefresh: _refreshAll,
      ),
    ];

    return Scaffold(
      backgroundColor: DriverColors.background,
      extendBody: true,
      body: IndexedStack(index: _tabIndex, children: pages),
      bottomNavigationBar: DriverNavBar(
          currentIndex: _tabIndex,
          unreadChats: _unreadChats,
          isCourier: account.role == 'courier',
          onTap: _selectTab),
    );
  }
}
