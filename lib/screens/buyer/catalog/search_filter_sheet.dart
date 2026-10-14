import 'package:flutter/material.dart';

import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../widgets/product_pager.dart';

/// Bottom sheet with the web's search filters: category, price, rating and
/// availability. Facets (category counts, price range) come from the search
/// itself, so the options always match what the results page can show.
Future<void> showSearchFilters(BuildContext context, ProductPager pager, String search) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: BColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _FilterSheet(pager: pager, search: search),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.pager, required this.search});

  final ProductPager pager;
  final String search;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final Future<Map<String, dynamic>> _facets = BuyerStore.instance.api.searchFacets(widget.search, sellerId: widget.pager.sellerId);

  late String? _category = widget.pager.category;
  late num? _min = widget.pager.priceMin;
  late num? _max = widget.pager.priceMax;
  late num? _rating = widget.pager.minRating;
  late bool _inStock = widget.pager.inStock;
  late bool _onSale = widget.pager.onSale;

  late final _minCtrl = TextEditingController(text: _min == null ? '' : '$_min');
  late final _maxCtrl = TextEditingController(text: _max == null ? '' : '$_max');

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
        _category = null;
        _min = _max = _rating = null;
        _inStock = _onSale = false;
        _minCtrl.clear();
        _maxCtrl.clear();
      });

  void _apply() {
    widget.pager.applyFilters(category: _category, priceMin: _min, priceMax: _max, minRating: _rating, inStock: _inStock, onSale: _onSale);
    Navigator.of(context).pop();
  }

  void _setPrice({num? min, num? max, required bool fromSlider}) {
    setState(() {
      _min = min;
      _max = max;
      if (fromSlider) {
        _minCtrl.text = min == null ? '' : '${min.round()}';
        _maxCtrl.text = max == null ? '' : '${max.round()}';
      }
    });
  }

  num? _parse(String v) => v.trim().isEmpty ? null : num.tryParse(v.trim());

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: BColors.border, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
          child: Row(children: [
            const Expanded(child: Text('Filter products', style: BText.section)),
            IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Align(alignment: Alignment.centerLeft, child: Text('Applies to product results only.', style: BText.tiny)),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _facets,
            builder: (context, snap) {
              final facets = snap.data ?? const <String, dynamic>{};
              return ListView(
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _section('Category', _categories(facets, snap.connectionState != ConnectionState.done)),
                  _section('Price', _price(facets)),
                  _section('Rating', _ratings(facets), initiallyExpanded: _rating != null),
                  _section('Availability', _availability(), initiallyExpanded: _inStock || _onSale),
                ],
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _reset,
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: BColors.ink),
                child: const Text('Reset'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _apply,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: BColors.brand),
                child: const Text('Show results'),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _section(String title, Widget child, {bool initiallyExpanded = true}) => Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Text(title, style: BText.section),
          children: [child],
        ),
      );

  Widget _categories(Map<String, dynamic> facets, bool loading) {
    if (loading) return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator(minHeight: 2));
    final cats = (facets['categories'] as List? ?? const []).whereType<Map>().toList();
    final total = (facets['total'] as num?)?.toInt() ?? 0;
    Widget row(String label, String? value, int count) => RadioListTile<String?>(
          value: value,
          groupValue: _category,
          onChanged: (v) => setState(() => _category = v),
          activeColor: BColors.brand,
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(label, style: BText.body),
          secondary: Text('$count', style: BText.tiny),
          controlAffinity: ListTileControlAffinity.leading,
        );
    return Column(children: [
      row('All categories', null, total),
      for (final c in cats) row('${c['name']}', '${c['name']}', (c['count'] as num?)?.toInt() ?? 0),
    ]);
  }

  Widget _price(Map<String, dynamic> facets) {
    final range = facets['price'] is Map ? facets['price'] as Map : null;
    // The API sends decimals as strings ("120.00").
    final lo = double.tryParse('${range?['min'] ?? ''}');
    final hi = double.tryParse('${range?['max'] ?? ''}');
    final canSlide = lo != null && hi != null && hi > lo;

    Widget field(String label, TextEditingController c, void Function(num?) onChanged) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: BText.tiny),
            const SizedBox(height: 4),
            TextField(
              controller: c,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => setState(() => onChanged(_parse(v))),
              decoration: InputDecoration(
                prefixText: '₱ ',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(BRadius.sm), borderSide: const BorderSide(color: BColors.border)),
              ),
            ),
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        field('Min', _minCtrl, (v) => _min = v),
        const SizedBox(width: 12),
        field('Max', _maxCtrl, (v) => _max = v),
      ]),
      if (canSlide)
        RangeSlider(
          activeColor: BColors.brand,
          min: lo,
          max: hi,
          values: RangeValues(
            (_min ?? lo).toDouble().clamp(lo, hi),
            (_max ?? hi).toDouble().clamp(lo, hi),
          ),
          onChanged: (v) => _setPrice(
            min: v.start <= lo ? null : v.start.roundToDouble(),
            max: v.end >= hi ? null : v.end.roundToDouble(),
            fromSlider: true,
          ),
        ),
      if (lo != null && hi != null) Text('Prices here run ${peso(lo)} to ${peso(hi)}', style: BText.tiny),
    ]);
  }

  Widget _ratings(Map<String, dynamic> facets) {
    final hasRatings = facets['has_ratings'] != false;
    if (!hasRatings) return const Align(alignment: Alignment.centerLeft, child: Text('No rated products here yet.', style: BText.tiny));
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final r in const [4, 3, 2, 1])
        ChoiceChip(
          selected: _rating == r,
          onSelected: (on) => setState(() => _rating = on ? r : null),
          avatar: const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)),
          label: Text(r == 4 ? '4 & up' : '$r & up'),
          selectedColor: BColors.brand.withValues(alpha: 0.15),
          showCheckmark: false,
        ),
    ]);
  }

  Widget _availability() => Column(children: [
        CheckboxListTile(
          value: _inStock,
          onChanged: (v) => setState(() => _inStock = v ?? false),
          activeColor: BColors.brand,
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('In stock', style: BText.body),
        ),
        CheckboxListTile(
          value: _onSale,
          onChanged: (v) => setState(() => _onSale = v ?? false),
          activeColor: BColors.brand,
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('On sale', style: BText.body),
        ),
      ]);
}
