import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../auth/auth_screen.dart';
import '../driver/driver_theme.dart';
import 'dashboard/logistics_dashboard_screen.dart';
import 'inventory/logistics_inventory_screen.dart';
import 'logistics_models.dart';
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

  @override
  void initState() {
    super.initState();
    _loadAccount();
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
      unawaited(_loadInventory());
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

  Future<void> _loadInventory() async {
    final token = _accessToken;
    if (token == null) return;

    setState(() {
      _loadingInventory = true;
      _inventoryError = null;
    });

    try {
      final results = await Future.wait([
        _api.getPendingInventory(accessToken: token),
        _api.getInventory(accessToken: token),
      ]);
      final pendingRows = (results[0]['data'] as List? ?? [])
          .map((row) => InventoryParcel.fromApi(Map<String, dynamic>.from(row as Map)))
          .toList();
      final scannedRows = (results[1]['data'] as List? ?? [])
          .map((row) => InventoryParcel.fromApi(Map<String, dynamic>.from(row as Map)))
          .toList();
      if (!mounted) return;
      setState(() {
        _pending = pendingRows;
        _scanned = scannedRows;
        _loadingInventory = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingInventory = false;
        _inventoryError = e.statusCode == 401 ? 'Your session has expired. Please sign in again.' : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingInventory = false;
        _inventoryError = 'Could not reach the server. Check your connection and try again.';
      });
    }
  }

  /// Pull-to-refresh + the landing point after a successful scan moves one
  /// row from [_pending] to [_scanned] — re-fetches both lists rather than
  /// patching in place, since a scan also affects Dashboard's counters.
  Future<void> _refreshAll() async {
    await _loadInventory();
  }

  Future<void> _signOutToLogin() async {
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
        onOpenInventory: () => setState(() => _tabIndex = 1),
      ),
      LogisticsInventoryScreen(
        pending: _pending,
        scanned: _scanned,
        loading: _loadingInventory,
        error: _inventoryError,
        accessToken: accessToken,
        onRefresh: _refreshAll,
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
      bottomNavigationBar: LogisticsNavBar(currentIndex: _tabIndex, onTap: (i) => setState(() => _tabIndex = i)),
    );
  }
}
