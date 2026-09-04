import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'driver_work_screen.dart' show WorkAppColors, GlassIconButton;

/// Renders a document (the courier's resignation letter — PDF, DOC or
/// DOCX) inside the app instead of handing the user off to an external
/// browser. Routed through Google's viewer so all three formats render
/// the same way without bundling a native PDF/Office renderer; if that
/// fails to load, an "Open in browser" fallback keeps the document
/// reachable rather than leaving the courier stuck.
class DocumentViewerScreen extends StatefulWidget {
  final String title;
  final String url;

  const DocumentViewerScreen({super.key, required this.title, required this.url});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final viewerUrl = 'https://docs.google.com/viewer?embedded=true&url=${Uri.encodeComponent(widget.url)}';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (_) {
          if (mounted) {
            setState(() {
              _loading = false;
              _failed = true;
            });
          }
        },
      ))
      ..loadRequest(Uri.parse(viewerUrl));
  }

  Future<void> _openExternally() async {
    final uri = Uri.tryParse(widget.url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkAppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: WorkAppColors.textPrimary,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
        ),
        title: Text(widget.title, style: const TextStyle(color: WorkAppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          IconButton(
            tooltip: 'Open in browser',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: _openExternally,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!_failed) WebViewWidget(controller: _controller),
          if (_loading && !_failed)
            const Center(child: CircularProgressIndicator(color: WorkAppColors.primary)),
          if (_failed)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.description_outlined, size: 48, color: WorkAppColors.textSecondary),
                    const SizedBox(height: 16),
                    const Text(
                      'Could not preview this document here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: WorkAppColors.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _openExternally,
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Open in browser'),
                      style: FilledButton.styleFrom(backgroundColor: WorkAppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
