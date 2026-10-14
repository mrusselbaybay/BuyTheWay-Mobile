import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../driver/driver_theme.dart';
import '../../driver/settings/widgets/settings_widgets.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../widgets/buyer_widgets.dart';
import 'settings_kit.dart';

final _buyer = BuyerStore.instance;

// ---------------------------------------------------------------
// Shared look-ups
// ---------------------------------------------------------------

/// Icon + label for what a report is about.
(IconData, String) _kind(String? kind) => switch (kind) {
      'product' => (Icons.inventory_2_outlined, 'Product'),
      'shop' => (Icons.storefront_outlined, 'Shop'),
      'order' => (Icons.receipt_long_outlined, 'Delivered order'),
      'chat' => (Icons.chat_bubble_outline_rounded, 'Chat'),
      _ => (Icons.flag_outlined, 'Report'),
    };

/// (text, background) for a status key from the API.
(Color, Color) _status(String? key) => switch (key) {
      'in_review' => (const Color(0xFF1D4ED8), const Color(0xFFDBEAFE)),
      'waiting' => (const Color(0xFFA16207), const Color(0xFFFEF3C7)),
      'resolved' => (const Color(0xFF15803D), const Color(0xFFDCFCE7)),
      'closed' => (const Color(0xFF64748B), const Color(0xFFF1F5F9)),
      _ => (const Color(0xFF475569), const Color(0xFFE2E8F0)), // submitted
    };

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.statusKey, this.label);
  final String? statusKey;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = _status(statusKey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

/// Three-segment progress bar: Submitted → In review → Resolved / Closed.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.step, this.finalLabel, this.labels = false});
  final int step; // 1..3
  final String? finalLabel;
  final bool labels;

  @override
  Widget build(BuildContext context) {
    final names = ['Submitted', 'In review', step == 3 ? (finalLabel ?? 'Resolved') : 'Resolved'];
    return Column(children: [
      Row(children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(color: i < step ? DriverColors.primary : DriverColors.border, borderRadius: BorderRadius.circular(3)),
            ),
          ),
        ],
      ]),
      if (labels) ...[
        const SizedBox(height: 8),
        Row(children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: Text(
                names[i],
                textAlign: i == 0 ? TextAlign.left : (i == 2 ? TextAlign.right : TextAlign.center),
                style: TextStyle(fontSize: 11, fontWeight: i + 1 == step ? FontWeight.w800 : FontWeight.w600, color: i < step ? DriverColors.primaryDark : DriverColors.textSecondary),
              ),
            ),
        ]),
      ],
    ]);
  }
}

// ---------------------------------------------------------------
// List
// ---------------------------------------------------------------

class BuyerReportsScreen extends StatefulWidget {
  const BuyerReportsScreen({super.key});

  @override
  State<BuyerReportsScreen> createState() => _BuyerReportsScreenState();
}

class _BuyerReportsScreenState extends State<BuyerReportsScreen> {
  final reports = <Map<String, dynamic>>[];
  String state = 'open';
  int page = 0;
  int lastPage = 1;
  int openCount = 0;
  int closedCount = 0;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next = reset ? 1 : page + 1;
      final result = await _buyer.api.myReports(state: state, page: next);
      if (mounted) {
        setState(() {
          if (reset) reports.clear();
          reports.addAll(result.items);
          page = next;
          lastPage = result.lastPage;
          openCount = result.open;
          closedCount = result.closed;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = _buyer.handleError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _selectState(String value) {
    if (state == value || loading) return;
    setState(() {
      state = value;
      page = 0;
      reports.clear();
    });
    _load();
  }

  Widget _tab(String value, String label, int count) {
    final selected = state == value;
    return Expanded(
      child: InkWell(
        onTap: () => _selectState(value),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: selected ? DriverColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(value == 'open' ? Icons.hourglass_top_rounded : Icons.task_alt_rounded, size: 17, color: selected ? Colors.white : DriverColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: selected ? Colors.white : DriverColors.textPrimary)),
            if (count > 0) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(color: selected ? Colors.white.withValues(alpha: 0.25) : DriverColors.border, borderRadius: BorderRadius.circular(999)),
                child: Text('$count', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: selected ? Colors.white : DriverColors.textSecondary)),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: DriverColors.background,
        appBar: settingsAppBar('My Reports', centerTitle: true, backgroundColor: DriverColors.primarySurface),
        body: RefreshIndicator(
          color: DriverColors.primary,
          onRefresh: () => _load(reset: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [DriverColors.primarySurface, DriverColors.background])),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(padding: EdgeInsets.only(left: 2, bottom: 12), child: Text('Track what you reported and what we did about it.', style: DriverText.caption)),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: softShadow(0.07)),
                      child: Row(children: [_tab('open', 'Open', openCount), _tab('closed', 'Closed', closedCount)]),
                    ),
                  ]),
                ),
              ),
              if (loading && reports.isEmpty)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 16), child: RowsSkeleton(count: 3, tile: 44)))
              else if (error != null && reports.isEmpty)
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: SettingsErrorBanner(message: error!, onRetry: () => _load(reset: true))))
              else if (reports.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: EmptyCard(
                      icon: state == 'open' ? Icons.flag_outlined : Icons.task_alt_rounded,
                      title: state == 'open' ? 'No open reports' : 'No closed reports',
                      message: state == 'open' ? 'Report a product, shop, chat or delivered order from its page and it\'ll show up here.' : 'Reports we\'ve finished reviewing will be listed here.',
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  sliver: SliverList.separated(
                    itemCount: reports.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _ReportCard(report: reports[i]),
                  ),
                ),
                if (page < lastPage) SliverToBoxAdapter(child: LoadMore(loading: loading, onTap: _load)),
              ],
              SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24)),
            ],
          ),
        ),
      );
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});
  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context) {
    final (icon, kindLabel) = _kind(report['kind'] as String?);
    final filed = _date(report['filedAt']);
    final updated = _date(report['updatedAt']);
    final step = (report['step'] as num?)?.toInt() ?? 1;
    final showUpdated = filed != null && updated != null && updated.difference(filed).inHours >= 1;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BuyerReportDetailScreen(id: '${report['id']}'))),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: DriverColors.border), boxShadow: softShadow(0.04)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconTile(icon, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(kindLabel.toUpperCase(), style: DriverText.label.copyWith(letterSpacing: 0.8)),
                  const SizedBox(height: 2),
                  Text('${report['target'] ?? 'Report'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, height: 1.25, color: DriverColors.textPrimary)),
                  const SizedBox(height: 3),
                  Text('${report['reason'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: DriverText.body.copyWith(fontSize: 13, color: DriverColors.textSecondary)),
                ]),
              ),
              const SizedBox(width: 8),
              _StatusPill(report['status'] as String?, '${report['statusLabel'] ?? ''}'),
            ]),
            const SizedBox(height: 14),
            _StepBar(step: step),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.calendar_today_rounded, size: 12, color: DriverColors.textSecondary),
              const SizedBox(width: 5),
              Expanded(child: Text('Filed ${formatDate(filed)}${showUpdated ? ' · Updated ${formatDate(updated)}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: DriverText.caption)),
              Text('#${report['reference'] ?? ''}', style: DriverText.caption.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey[400]),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Detail
// ---------------------------------------------------------------

class BuyerReportDetailScreen extends StatefulWidget {
  const BuyerReportDetailScreen({super.key, required this.id});
  final String id;

  @override
  State<BuyerReportDetailScreen> createState() => _BuyerReportDetailScreenState();
}

class _BuyerReportDetailScreenState extends State<BuyerReportDetailScreen> {
  Map<String, dynamic>? report;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await _buyer.api.myReport(widget.id);
      if (mounted) {
        setState(() {
          report = value;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = _buyer.handleError(e));
    }
  }

  List<Map<String, dynamic>> _maps(dynamic v) => v is List ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : const [];

  Future<void> _copyReference(String ref) async {
    await Clipboard.setData(ClipboardData(text: ref));
    if (mounted) showToast(context, 'Reference copied');
  }

  void _openEvidence(Map<String, dynamic> file) {
    final url = '${file['url']}';
    if (file['kind'] == 'image') {
      showDialog<void>(
        context: context,
        builder: (_) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(children: [
            Positioned.fill(child: InteractiveViewer(child: NetImage(url, fit: BoxFit.contain, fallbackIcon: Icons.broken_image_outlined))),
            SafeArea(child: Align(alignment: Alignment.topRight, child: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), tooltip: 'Close', onPressed: () => Navigator.pop(context)))),
          ]),
        ),
      );
    } else {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Widget _card({required Widget child, Color color = Colors.white, Color? border}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18), border: Border.all(color: border ?? DriverColors.border)),
        child: child,
      );

  Widget _fact(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: DriverColors.primary),
          const SizedBox(width: 12),
          SizedBox(width: 62, child: Text(label, style: DriverText.caption.copyWith(fontSize: 12.5))),
          Expanded(child: Text(value, style: DriverText.body.copyWith(fontWeight: FontWeight.w700, height: 1.35))),
        ]),
      );

  Widget _hero(Map<String, dynamic> r) {
    final (icon, kindLabel) = _kind(r['kind'] as String?);
    final step = (r['step'] as num?)?.toInt() ?? 1;
    final ref = '${r['reference'] ?? ''}';
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _StatusPill(r['status'] as String?, '${r['statusLabel'] ?? 'Report'}'),
          const Spacer(),
          InkWell(
            onTap: () => _copyReference(ref),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('#$ref', style: DriverText.caption.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(width: 4),
                const Icon(Icons.copy_rounded, size: 13, color: DriverColors.textSecondary),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          IconTile(icon, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(kindLabel.toUpperCase(), style: DriverText.label.copyWith(letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text('${r['target'] ?? 'Report'}', style: DriverText.title.copyWith(fontSize: 17, height: 1.25)),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        _StepBar(step: step, finalLabel: '${r['statusLabel'] ?? ''}', labels: true),
        if ('${r['statusHint'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: DriverColors.primarySurface, borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded, size: 17, color: DriverColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text('${r['statusHint']}', style: DriverText.body.copyWith(fontSize: 13, height: 1.4))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _outcome(Map<String, dynamic> outcome) {
    final resolved = outcome['type'] == 'resolved';
    final at = _date(outcome['at']);
    final color = resolved ? const Color(0xFF15803D) : DriverColors.textSecondary;
    return _card(
      color: resolved ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
      border: resolved ? const Color(0xFFBBF7D0) : DriverColors.border,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconTile(resolved ? Icons.check_circle_outline_rounded : Icons.do_not_disturb_on_outlined, color: color, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(resolved ? 'Outcome — resolved' : 'Outcome — closed', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 4),
            Text('${outcome['text'] ?? ''}', style: DriverText.body.copyWith(height: 1.45)),
            if (at != null) ...[const SizedBox(height: 6), Text(SettingsFormat.dateTime(at), style: DriverText.caption)],
          ]),
        ),
      ]),
    );
  }

  Widget _refund(Map<String, dynamic> refund) {
    final state = '${refund['state']}';
    final (Color fg, Color bg, Color line) = switch (state) {
      'done' => (const Color(0xFF15803D), const Color(0xFFF0FDF4), const Color(0xFFBBF7D0)),
      'stopped' => (const Color(0xFFB45309), const Color(0xFFFFFBEB), const Color(0xFFFDE68A)),
      _ => (const Color(0xFF1D4ED8), const Color(0xFFEFF6FF), const Color(0xFFBFDBFE)),
    };
    final amount = refund['amount'] is num ? (refund['amount'] as num).toDouble() : null;
    final note = refund['note'];
    return _card(
      color: bg,
      border: line,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.payments_outlined, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(child: Text('${refund['label'] ?? 'Refund'}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: fg))),
          if (amount != null) Text(peso(amount), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: fg)),
        ]),
        if (note != null && '$note'.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('$note', style: DriverText.body.copyWith(fontSize: 13, height: 1.4)),
        ],
      ]),
    );
  }

  Widget _yourReport(Map<String, dynamic> r, List<Map<String, dynamic>> evidence) {
    final (_, kindLabel) = _kind(r['kind'] as String?);
    final details = '${r['details'] ?? ''}';
    final order = r['orderNumber'];
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _fact(Icons.category_outlined, 'About', '$kindLabel · ${r['target'] ?? ''}'),
        const Divider(height: 1, color: DriverColors.border),
        _fact(Icons.help_outline_rounded, 'Reason', '${r['reason'] ?? ''}'),
        if (order != null) ...[const Divider(height: 1, color: DriverColors.border), _fact(Icons.receipt_long_outlined, 'Order', '#$order')],
        const Divider(height: 1, color: DriverColors.border),
        _fact(Icons.event_outlined, 'Filed', SettingsFormat.dateTime(_date(r['filedAt']) ?? DateTime.now())),
        if (details.isNotEmpty) ...[
          const SizedBox(height: 10),
          const SettingsFieldLabel('YOUR DETAILS'),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(color: DriverColors.background, borderRadius: BorderRadius.all(Radius.circular(12)), border: Border(left: BorderSide(color: DriverColors.primary, width: 3))),
            child: Text(details, style: DriverText.body.copyWith(height: 1.5)),
          ),
        ],
        if (evidence.isNotEmpty) ...[
          const SizedBox(height: 14),
          const SettingsFieldLabel('EVIDENCE'),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final file in evidence)
              InkWell(
                onTap: () => _openEvidence(file),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 76,
                  height: 76,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: DriverColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: DriverColors.border)),
                  child: file['kind'] == 'image' ? NetImage('${file['url']}', fallbackIcon: Icons.image_outlined) : const Icon(Icons.play_circle_fill_rounded, size: 34, color: DriverColors.textSecondary),
                ),
              ),
          ]),
        ],
      ]),
    );
  }

  Widget _timeline(List<Map<String, dynamic>> entries) {
    final list = entries.reversed.toList(); // newest first
    return _card(
      child: Column(children: [
        for (var i = 0; i < list.length; i++)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: 22,
                child: Column(children: [
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(top: 3),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: i == 0 ? DriverColors.primary : Colors.white, border: Border.all(color: i == 0 ? DriverColors.primary : DriverColors.border, width: 2)),
                  ),
                  if (i != list.length - 1) Expanded(child: Container(width: 2, color: DriverColors.border)),
                ]),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: i == list.length - 1 ? 0 : 18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${list[i]['title'] ?? ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: DriverColors.textPrimary)),
                    if (_date(list[i]['at']) != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(SettingsFormat.dateTime(_date(list[i]['at'])!), style: DriverText.caption)),
                    if (list[i]['body'] != null && '${list[i]['body']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${list[i]['body']}', style: DriverText.body.copyWith(fontSize: 13, height: 1.45))),
                  ]),
                ),
              ),
            ]),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = report;
    if (r == null) {
      return Scaffold(
        backgroundColor: DriverColors.background,
        appBar: settingsAppBar('Report details', centerTitle: true),
        body: error == null ? const Padding(padding: EdgeInsets.all(16), child: RowsSkeleton(count: 3, tile: 44)) : ErrorState(message: error!, onRetry: _load),
      );
    }
    final outcome = r['outcome'] is Map ? Map<String, dynamic>.from(r['outcome'] as Map) : null;
    final refund = r['refund'] is Map ? Map<String, dynamic>.from(r['refund'] as Map) : null;
    final timeline = _maps(r['timeline']);
    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: settingsAppBar('Report details', centerTitle: true),
      body: RefreshIndicator(
        color: DriverColors.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.paddingOf(context).bottom + 24),
          children: [
            _hero(r),
            if (outcome != null) ...[const SizedBox(height: 14), _outcome(outcome)],
            if (refund != null) ...[const SizedBox(height: 14), _refund(refund)],
            kSettingsGap,
            const SettingsSectionLabel('Your report'),
            _yourReport(r, _maps(r['evidence'])),
            if (timeline.isNotEmpty) ...[
              kSettingsGap,
              const SettingsSectionLabel('Updates'),
              _timeline(timeline),
            ],
          ],
        ),
      ),
    );
  }
}
