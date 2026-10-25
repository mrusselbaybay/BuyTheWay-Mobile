import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../chat/driver_chat_controller.dart';
import '../deliveries/assigned_delivery_detail_screen.dart';
import '../driver_models.dart';
import 'notification_inbox.dart';
import '../../logistics/logistics_models.dart' show LogisticsNotification;

/// The courier's notification inbox, opened from the bell on Home. Work,
/// employment, money and account updates; chat messages and the Deliveries
/// counters are NOT here. Tapping a parcel update opens that delivery
/// (fetched by id, so it works before the Deliveries list has loaded); if it
/// is no longer the courier's, they land on the Deliveries tab instead.
class DriverNotificationsScreen extends StatelessWidget {
  final String accessToken;
  final DriverChatController controller;

  /// Shell state: the unread count changed (read marks, polls).
  final ValueChanged<int> onUnreadChanged;

  /// Shell state: switch to the Deliveries tab.
  final VoidCallback onOpenDeliveries;
  final ValueChanged<String> onOpenTarget;

  /// True while a pickup/scan/photo flow is running anywhere in the app.
  final bool Function() isBusy;

  /// Reported by a delivery detail opened from here, so the shell can hold badge updates.
  final ValueChanged<bool>? onBusy;

  /// Shell's poll error path (401/403 → session-expired state).
  final void Function(Object error)? onPollError;

  const DriverNotificationsScreen({
    super.key,
    required this.accessToken,
    required this.controller,
    required this.onUnreadChanged,
    required this.onOpenDeliveries,
    required this.onOpenTarget,
    required this.isBusy,
    this.onBusy,
    this.onPollError,
  });

  static final ApiService _api = ApiService();

  void _toDeliveries(BuildContext context, {String? message}) {
    final messenger = ScaffoldMessenger.of(context);
    onOpenDeliveries();
    Navigator.of(context).pop();
    if (message != null)
      messenger.showSnackBar(SnackBar(
          content: Text(message), behavior: SnackBarBehavior.floating));
  }

  Future<void> _open(BuildContext context, LogisticsNotification n) async {
    final parcelId = n.parcelId;
    if (parcelId == null) {
      // Employment, money and account updates are read in place.
      if (n.target == 'deliveries') {
        _toDeliveries(context);
      } else if (n.target == 'remittances' ||
          n.target == 'earnings' ||
          n.target == 'account') {
        onOpenTarget(n.target!);
        Navigator.of(context).pop();
      }
      return;
    }

    final AssignedDelivery delivery;
    try {
      final response =
          await _api.getDriverDelivery(accessToken: accessToken, id: parcelId);
      delivery = AssignedDelivery.fromApi(
          Map<String, dynamic>.from(response['data'] as Map));
    } on ApiException catch (e) {
      if (!context.mounted) return;
      if (e.statusCode == 404) {
        _toDeliveries(context, message: 'No longer assigned to you');
      } else if (e.statusCode == 401 || e.statusCode == 403) {
        onPollError?.call(e);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Could not open the delivery. Check your connection.')));
      return;
    }

    if (!context.mounted || isBusy()) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssignedDeliveryDetailScreen(
            delivery: delivery,
            accessToken: accessToken,
            controller: controller,
            onBusyChanged: onBusy),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => NotificationInbox(
        fetchPage: (page) =>
            _api.getDriverNotifications(accessToken: accessToken, page: page),
        markRead: (id) =>
            _api.markDriverNotificationRead(accessToken: accessToken, id: id),
        markAllRead: () =>
            _api.markAllDriverNotificationsRead(accessToken: accessToken),
        onUnreadChanged: onUnreadChanged,
        isBusy: isBusy,
        onPollError: onPollError,
        onOpen: _open,
        emptySubtitle: 'Parcel, team and payout updates will appear here.',
      );
}
