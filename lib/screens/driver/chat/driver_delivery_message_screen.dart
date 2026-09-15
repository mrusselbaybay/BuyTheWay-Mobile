import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../driver_theme.dart';
import '../widgets/driver_shared_widgets.dart';
import 'chat_models.dart';
import 'driver_chat_controller.dart';
import 'driver_chat_conversation_screen.dart';

/// Pushed the instant the "Message" button on a delivery's Buyer/Seller
/// contact row is tapped (assigned_delivery_detail_screen.dart) — before
/// the conversation is even known to exist yet, so the rider sees a
/// conversation-shaped screen immediately instead of waiting on a network
/// round trip before navigation happens at all.
///
/// [DriverChatController.startDeliveryConversation] is cache-first: a
/// repeat tap for the same (delivery, contact) pairing resolves from
/// already-held state with no network call, so this screen's skeleton
/// only actually shows for a genuine first-time resolution. Once resolved,
/// this swaps itself (in place — no second navigation/route transition)
/// for the real [DriverChatConversationScreen], already carrying whatever
/// messages the create call itself returned.
class DriverDeliveryMessageScreen extends StatefulWidget {
  final DriverChatController controller;
  final String parcelAssignmentId;
  final String contact;

  const DriverDeliveryMessageScreen({
    super.key,
    required this.controller,
    required this.parcelAssignmentId,
    required this.contact,
  });

  @override
  State<DriverDeliveryMessageScreen> createState() => _DriverDeliveryMessageScreenState();
}

class _DriverDeliveryMessageScreenState extends State<DriverDeliveryMessageScreen> {
  ChatConversation? _conversation;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Deferred for the same reason every other controller call from
    // initState() in this module is — a cache hit resolves synchronously
    // and notifies listeners before this screen's own first build/frame
    // has finished, which trips "setState() called during build" on
    // whatever's above it in the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    try {
      final conversation = await widget.controller.startDeliveryConversation(
        parcelAssignmentId: widget.parcelAssignmentId,
        contact: widget.contact,
      );
      if (mounted) setState(() => _conversation = conversation);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is ApiException ? e.message : 'Could not start a conversation. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    if (conversation != null) {
      return DriverChatConversationScreen(controller: widget.controller, conversation: conversation);
    }

    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: DriverColors.textPrimary,
        titleSpacing: 0,
        title: const Padding(padding: EdgeInsets.only(right: 16), child: DriverChatHeaderSkeleton()),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DriverEmptyState(icon: Icons.wifi_off_rounded, title: "Couldn't start conversation", subtitle: _error!),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {
                        _error = null;
                        WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
                      }),
                      style: ElevatedButton.styleFrom(backgroundColor: DriverColors.primary, foregroundColor: Colors.white),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : const DriverChatSkeleton(),
    );
  }
}
