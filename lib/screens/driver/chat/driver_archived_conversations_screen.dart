import 'dart:async';

import 'package:flutter/material.dart';

import '../driver_theme.dart';
import '../widgets/driver_shared_widgets.dart';
import 'chat_models.dart';
import 'driver_chat_controller.dart';
import 'driver_chat_conversation_screen.dart';
import 'driver_chat_list_screen.dart';

/// A dedicated, separate destination for archived conversations — same row
/// design as the main inbox (see [ChatConversationRow]) so it reads as
/// another state of the same messaging system, not a different app.
class DriverArchivedConversationsScreen extends StatefulWidget {
  final DriverChatController controller;
  const DriverArchivedConversationsScreen({super.key, required this.controller});

  @override
  State<DriverArchivedConversationsScreen> createState() => _DriverArchivedConversationsScreenState();
}

class _DriverArchivedConversationsScreenState extends State<DriverArchivedConversationsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<ChatConversation> _conversations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.controller.loadArchivedConversations(search: _searchController.text.trim());
      if (!mounted) return;
      setState(() {
        _conversations = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach the server. Check your connection and try again.';
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _openConversation(ChatConversation conversation) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DriverChatConversationScreen(controller: widget.controller, conversation: conversation),
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: DriverColors.textPrimary,
        title: const Text('Archived', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: DriverRefreshable(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: [
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: DriverColors.border)),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 18, color: DriverColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: DriverText.body,
                      decoration: const InputDecoration(hintText: 'Search archived', hintStyle: DriverText.caption, border: InputBorder.none, isDense: true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loading) ...[
              const DriverCardSkeleton(),
              const DriverCardSkeleton(),
            ] else if (_error != null)
              DriverEmptyState(icon: Icons.wifi_off_rounded, title: "Couldn't load archived", subtitle: _error!)
            else if (_conversations.isEmpty)
              const DriverEmptyState(icon: Icons.archive_outlined, title: 'No archived conversations', subtitle: 'Conversations you archive will show up here.')
            else
              ..._conversations.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ChatConversationRow(
                      conversation: c,
                      priority: false,
                      onTap: () => _openConversation(c),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
