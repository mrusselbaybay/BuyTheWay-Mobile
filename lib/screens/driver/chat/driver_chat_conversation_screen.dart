import 'package:flutter/material.dart';

import '../driver_models.dart';
import '../driver_theme.dart';
import '../widgets/driver_shared_widgets.dart';

/// A single conversation. There's no real chat backend behind this, so the
/// screen mutates [thread] (a shared, mutable object also held by
/// DriverShell) directly and simulates a customer reply after a short
/// delay — an honest, self-contained mock rather than a half-wired
/// real-time integration.
class DriverChatConversationScreen extends StatefulWidget {
  final ChatThread thread;
  const DriverChatConversationScreen({super.key, required this.thread});

  @override
  State<DriverChatConversationScreen> createState() => _DriverChatConversationScreenState();
}

class _DriverChatConversationScreenState extends State<DriverChatConversationScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _customerTyping = false;

  static const _quickReplies = ['On my way', 'Running late', "I'm here", 'Thank you!'];
  static const _autoReplies = ['Got it, thank you!', 'Sounds good.', "Okay, I'll be here.", 'Thanks for the update!'];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  void _send([String? presetText]) {
    final text = (presetText ?? _inputController.text).trim();
    if (text.isEmpty) return;

    setState(() {
      widget.thread.messages.add(ChatMessage(id: 'm-${DateTime.now().millisecondsSinceEpoch}', text: text, fromDriver: true, sentAt: DateTime.now()));
      _customerTyping = true;
    });
    _inputController.clear();
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        _customerTyping = false;
        widget.thread.messages.add(
          ChatMessage(id: 'm-${DateTime.now().millisecondsSinceEpoch}r', text: _autoReplies[text.length % _autoReplies.length], fromDriver: false, sentAt: DateTime.now()),
        );
      });
      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: DriverColors.textPrimary,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: const BoxDecoration(gradient: LinearGradient(colors: DriverColors.primaryGradient), shape: BoxShape.circle),
              child: Text(widget.thread.avatarInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Text(widget.thread.customerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              children: [
                ...widget.thread.messages.map((m) => ChatBubble(message: m)),
                if (_customerTyping) _typingIndicator(),
              ],
            ),
          ),
          _quickReplyRow(),
          _composer(),
        ],
      ),
    );
  }

  Widget _typingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: DriverColors.border)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => _typingDot(i)),
        ),
      ),
    );
  }

  Widget _typingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1),
      duration: Duration(milliseconds: 500 + index * 120),
      curve: Curves.easeInOut,
      builder: (context, value, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Opacity(
          opacity: value,
          child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: DriverColors.textSecondary, shape: BoxShape.circle)),
        ),
      ),
    );
  }

  Widget _quickReplyRow() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: _quickReplies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final reply = _quickReplies[i];
          return OutlinedButton(
            onPressed: () => _send(reply),
            style: OutlinedButton.styleFrom(
              foregroundColor: DriverColors.primaryDark,
              side: BorderSide(color: DriverColors.primary.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(reply, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          );
        },
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo attachments in chat are not wired up in this preview.'), behavior: SnackBarBehavior.floating)),
            icon: const Icon(Icons.image_outlined, color: DriverColors.textSecondary),
          ),
          Expanded(
            child: TextField(
              controller: _inputController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type a message',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: DriverColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: DriverColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: DriverColors.primary, width: 1.4)),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(gradient: LinearGradient(colors: DriverColors.primaryGradient), shape: BoxShape.circle),
            child: IconButton(onPressed: () => _send(), icon: const Icon(Icons.send_rounded, color: Colors.white, size: 19)),
          ),
        ],
      ),
    );
  }
}
