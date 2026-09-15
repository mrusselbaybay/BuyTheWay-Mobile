import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import 'auth/driver_login_screen.dart';
import 'chat/driver_chat_controller.dart';
import 'chat/driver_chat_list_screen.dart';
import 'deliveries/driver_deliveries_screen.dart';
import 'driver_models.dart';
import 'driver_theme.dart';
import 'earnings/driver_earnings_screen.dart';
import 'history/driver_history_screen.dart';
import 'home/deliver_order_screen.dart';
import 'home/delivery_request_details_screen.dart';
import 'home/driver_home_screen.dart';
import 'home/pickup_order_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  void _onChatControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
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
      final response = await _api.getDriverProfile(accessToken: token);
      if (!mounted) return;
      final account = DriverAccount.fromApi(response);
      setState(() {
        _accessToken = token;
        _account = account;
        _chatController ??= DriverChatController(api: _api, accessToken: token)..addListener(_onChatControllerChanged);
        _loadingAccount = false;
        // Restore the "Go online" state the rider left the app in — it's
        // persisted server-side (driver_details/courier_details.delivery_status),
        // toggled from the Settings screen.
        _isOnline = account.isOnline;
        if (_isOnline) {
          _shiftStart ??= DateTime.now();
          if (_availableRequests.isEmpty) _availableRequests = mockAvailableRequests();
        }
      });
      // Fire-and-forget — Deliveries has its own loading/error state and
      // shouldn't hold up the rest of the shell rendering.
      unawaited(_loadDeliveries());
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
        _accountLoadError = 'Could not reach the server. Check your connection and try again.';
      });
    }
  }

  /// Loads the Deliveries tab from `GET /api/driver/deliveries`. Called
  /// once the account (and therefore the access token) is available, and
  /// again on pull-to-refresh from DriverDeliveriesScreen.
  Future<void> _loadDeliveries() async {
    final token = _accessToken;
    if (token == null) return;

    setState(() {
      _loadingDeliveries = true;
      _deliveriesError = null;
    });

    try {
      final response = await _api.getDriverDeliveries(accessToken: token);
      final rows = (response['data'] as List? ?? [])
          .map((row) => AssignedDelivery.fromApi(Map<String, dynamic>.from(row as Map)))
          .toList();
      if (!mounted) return;
      setState(() {
        _assignedDeliveries = rows;
        _loadingDeliveries = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDeliveries = false;
        _deliveriesError = e.statusCode == 401
            ? 'Your session has expired. Please sign in again.'
            : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDeliveries = false;
        _deliveriesError = 'Could not reach the server. Check your connection and try again.';
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
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, backgroundColor: DriverColors.error),
      );
    }

    await _loadDeliveries();
  }

  Future<void> _signOutToLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const DriverLoginScreen()), (route) => false);
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
        if (_availableRequests.isEmpty) _availableRequests = mockAvailableRequests();
      } else {
        _shiftStart = null;
        _availableRequests = <DeliveryRequest>[];
      }
    });

    _availabilityWrite?.cancel();
    _availabilityWrite = Timer(const Duration(milliseconds: 450), () => _persistAvailability(online));
  }

  Future<void> _persistAvailability(bool online) async {
    final token = _accessToken;
    if (token == null) return;
    // Nothing to do if the server already holds this value (e.g. the rider
    // toggled off then back on within the debounce window).
    if ((_account?.isOnline ?? false) == online) return;

    try {
      await _api.updateDriverAvailability(accessToken: token, online: online);
      _account?.deliveryStatus = online ? 'available' : 'unavailable';
    } catch (e) {
      if (!mounted || _isOnline != online) return; // superseded by a newer toggle
      setState(() {
        _isOnline = !online;
        if (online) {
          _shiftStart = null;
          _availableRequests = <DeliveryRequest>[];
        } else {
          _shiftStart ??= DateTime.now();
          if (_availableRequests.isEmpty) _availableRequests = mockAvailableRequests();
        }
      });
      final message = e is ApiException ? e.message : 'Could not update your status. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, backgroundColor: DriverColors.error),
      );
    }
  }

  Future<void> _refreshRequests() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted || !_isOnline) return;
    setState(() => _availableRequests = mockAvailableRequests());
  }

  Future<void> _openRequestDetails(DeliveryRequest request) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DeliveryRequestDetailsScreen(request: request)),
    );
    if (!mounted) return;
    if (result == true) {
      setState(() {
        _availableRequests.removeWhere((r) => r.id == request.id);
        _activeDelivery = ActiveDelivery(request: request);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delivery accepted — head to ${request.pickupLabel}.'), behavior: SnackBarBehavior.floating, backgroundColor: DriverColors.primaryDark),
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
          actualMinutes: DateTime.now().difference(active.request.requestedAt).inMinutes,
        ),
      );
      _availableBalance += active.request.estimatedFare;
      _activeDelivery = null;
    });
  }

  Future<void> _openActiveDeliveryFlow() async {
    final active = _activeDelivery;
    if (active == null) return;

    if (active.stage == DeliveryStage.headingToPickup || active.stage == DeliveryStage.atPickup) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PickupOrderScreen(
            delivery: active,
            onArrived: () => _updateActiveDelivery((d) => d.stage = DeliveryStage.atPickup),
            onPhotoAttached: () => _updateActiveDelivery((d) => d.pickupPhotoAttached = true),
            onConfirmPickup: () {
              _updateActiveDelivery((d) => d.stage = DeliveryStage.headingToDropoff);
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
            onArrived: () => _updateActiveDelivery((d) => d.stage = DeliveryStage.atDropoff),
            onPhotoAttached: () => _updateActiveDelivery((d) => d.deliveryPhotoAttached = true),
            onNotesChanged: (text) => _updateActiveDelivery((d) => d.deliveryNotes = text),
            onMarkDelivered: () {
              _completeActiveDelivery();
              Navigator.pop(context);
              DriverTopNotification.show(context, message: 'Delivery completed!');
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
      _withdrawals.insert(0, WithdrawalRecord(id: 'w-${DateTime.now().millisecondsSinceEpoch}', amount: amount, requestedAt: DateTime.now(), destination: destination));
    });
  }

  int get _unreadChats => _chatController?.unreadTotal ?? 0;

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  double get _todayEarnings =>
      _history.where((h) => h.status == HistoryStatus.completed && _isToday(h.completedAt)).fold(0, (sum, h) => sum + h.earnings);

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
                  const Icon(Icons.wifi_off_rounded, size: 48, color: DriverColors.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    _accountLoadError ?? 'Something went wrong loading your account.',
                    textAlign: TextAlign.center,
                    style: DriverText.body,
                  ),
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
      DriverHomeScreen(
        isOnline: _isOnline,
        shiftStart: _shiftStart,
        account: account,
        activeDelivery: _activeDelivery,
        availableRequests: _availableRequests,
        todayEarnings: _todayEarnings,
        completedToday: _history.where((h) => h.status == HistoryStatus.completed && _isToday(h.completedAt)).length,
        onGoOnline: () => _setOnline(true),
        onOpenRequest: _openRequestDetails,
        onContinueActiveDelivery: _openActiveDeliveryFlow,
        onRefreshRequests: _refreshRequests,
      ),
      DriverDeliveriesScreen(
        deliveries: _assignedDeliveries,
        accessToken: accessToken,
        loading: _loadingDeliveries,
        error: _deliveriesError,
        onRefresh: _loadDeliveries,
        onOpenHistory: _openHistory,
        controller: _chatController!,
      ),
      DriverEarningsScreen(
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
        onNotificationsChanged: (v) => setState(() => _notificationsEnabled = v),
        soundEnabled: _soundEnabled,
        onSoundChanged: (v) => setState(() => _soundEnabled = v),
        language: _language,
        onLanguageChanged: (v) => setState(() => _language = v),
        onRefresh: _refreshAll,
      ),
    ];

    return Scaffold(
      backgroundColor: DriverColors.background,
      extendBody: true,
      body: IndexedStack(index: _tabIndex, children: pages),
      bottomNavigationBar: DriverNavBar(currentIndex: _tabIndex, unreadChats: _unreadChats, onTap: (i) => setState(() => _tabIndex = i)),
    );
  }
}
