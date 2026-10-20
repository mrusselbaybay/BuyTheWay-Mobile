import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../driver/notifications/notification_inbox.dart';
import '../inventory/inventory_detail_screen.dart';
import '../logistics_models.dart';

/// The staff notification inbox, opened from the bell on the Dashboard.
/// Newest first, paged; read state lives on the server and is shared with
/// the web portal. Only events tagged for this app are listed. The list,
/// polling and read handling are the shared [NotificationInbox]; this file
/// only wires the staff endpoints and what a tap opens.
///
/// Opening it (or a row) never starts a scan; a tap is ignored while a scan
/// is active.
class LogisticsNotificationsScreen extends StatelessWidget {
  final String accessToken;

  /// Shell state: the unread count changed (read marks, polls).
  final ValueChanged<int> onUnreadChanged;

  /// Shell state: switch to the Inventory tab (fallback for a gone parcel).
  final VoidCallback onOpenInventory;

  /// True while a scan is open/in flight anywhere in the app.
  final bool Function() isScanActive;

  /// Same scan hooks the Inventory tab hands to its detail screens.
  final ValueChanged<bool>? onScanActive;
  final ValueChanged<InventoryParcel>? onScanned;

  /// Shell's poll error path (401/403 → session-expired state).
  final void Function(Object error)? onPollError;

  const LogisticsNotificationsScreen({
    super.key,
    required this.accessToken,
    required this.onUnreadChanged,
    required this.onOpenInventory,
    required this.isScanActive,
    this.onScanActive,
    this.onScanned,
    this.onPollError,
  });

  static final ApiService _api = ApiService();

  void _toInventory(BuildContext context) {
    onOpenInventory();
    Navigator.of(context).pop();
  }

  Future<void> _open(BuildContext context, LogisticsNotification n) async {
    final parcelId = n.parcelId;
    if (parcelId == null) {
      _toInventory(context);
      return;
    }

    // Fetch the parcel itself so it opens even if the inventory lists never
    // loaded or it has since moved on; if it is gone, land on the Inventory tab.
    try {
      await _api.getInventoryDetail(parcelAssignmentId: parcelId, accessToken: accessToken);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      if (e.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This parcel is no longer available.')));
        _toInventory(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the parcel. Check your connection.')));
      return;
    }

    if (!context.mounted || isScanActive()) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InventoryDetailScreen(
          parcelId: parcelId,
          accessToken: accessToken,
          onScanActive: onScanActive,
          onScanned: onScanned,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => NotificationInbox(
        fetchPage: (page) => _api.getLogisticsNotifications(accessToken: accessToken, page: page),
        markRead: (id) => _api.markLogisticsNotificationRead(accessToken: accessToken, id: id),
        markAllRead: () => _api.markAllLogisticsNotificationsRead(accessToken: accessToken),
        onUnreadChanged: onUnreadChanged,
        isBusy: isScanActive,
        onPollError: onPollError,
        onOpen: _open,
        emptySubtitle: 'Parcel and transfer updates will appear here.',
      );
}
