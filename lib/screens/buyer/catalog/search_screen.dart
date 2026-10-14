import 'dart:async';

import 'package:flutter/material.dart';

import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../product/product_detail_screen.dart';
import '../widgets/buyer_widgets.dart';
import '../widgets/product_pager.dart';
import 'product_list_screen.dart';
import 'store_screen.dart';

/// Full-screen search: autofocused field, recent searches, quick
/// categories. Submitting opens the results list.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initial, this.sellerId, this.shopName});

  final String? initial;

  /// Scopes suggestions and results to one shop.
  final String? sellerId;
  final String? shopName;

  bool get inShop => sellerId != null;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final controller = TextEditingController(text: widget.initial);
  final store = BuyerStore.instance;
  late final _discover = ProductPager(sellerId: widget.sellerId);

  static const _minLength = 2;

  Timer? _debounce;
  String _text = '';
  String _suggested = ''; // the query the current suggestions belong to
  bool _loading = false;
  List<Map<String, dynamic>> _products = const [];
  List<Map<String, dynamic>> _stores = const [];

  @override
  void initState() {
    super.initState();
    controller.addListener(_onChanged);
    _discover.loadMore();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _discover.dispose();
    controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    final text = controller.text.trim();
    if (text == _text) return;
    _text = text;
    _debounce?.cancel();
    if (text.length < _minLength) {
      setState(() {
        _loading = false;
        _suggested = '';
        _products = const [];
        _stores = const [];
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 250), () => _fetch(text));
  }

  Future<void> _fetch(String text) async {
    try {
      final result = await store.api.searchSuggestions(text, sellerId: widget.sellerId);
      if (!mounted || text != _text) return; // stale response
      setState(() {
        _loading = false;
        _suggested = text;
        _products = result.products;
        _stores = result.stores;
      });
    } catch (_) {
      if (!mounted || text != _text) return;
      // Suggestions are optional; Enter still searches.
      setState(() {
        _loading = false;
        _suggested = text;
        _products = const [];
        _stores = const [];
      });
    }
  }

  void _openProduct(String id) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: id)));

  void _openStore(Map<String, dynamic> s) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => StoreScreen(storeId: '${s['id']}', name: s['name'] as String?, logo: s['logo'] as String?),
      ));

  Widget _suggestions() {
    final hasResults = _products.isNotEmpty || _stores.isNotEmpty;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        if (_loading && !hasResults) const LinearProgressIndicator(minHeight: 2, color: BColors.brand),
        for (final s in _stores)
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(BRadius.sm),
              child: SizedBox(width: 44, height: 44, child: NetImage(s['logo'] as String?, fallbackIcon: Icons.storefront_outlined)),
            ),
            title: Text('${s['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: BText.body),
            subtitle: Text(s['category'] == null ? 'Shop' : 'Shop · ${s['category']}', maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => _openStore(s),
          ),
        for (final p in _products)
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(BRadius.sm),
              child: SizedBox(width: 44, height: 44, child: NetImage(p['image'] as String?)),
            ),
            title: Text('${p['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: BText.body),
            subtitle: Text(peso((p['price'] as num?) ?? 0)),
            onTap: () => _openProduct('${p['id']}'),
          ),
        if (!_loading && _suggested == _text && !hasResults)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('No quick matches for "$_text"', style: const TextStyle(color: BColors.muted, fontSize: 13)),
          ),
        // Always offered, so a typed query can be searched without a suggestion.
        ListTile(
          leading: const Icon(Icons.search, color: BColors.brand),
          title: Text('Search for "$_text"', style: BText.body),
          trailing: const Icon(Icons.north_west, size: 18, color: BColors.faint),
          onTap: () => _submit(_text),
        ),
      ],
    );
  }

  void _submit(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    store.rememberSearch(query);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ProductListScreen(title: widget.inShop ? (widget.shopName ?? query) : query, search: query, sellerId: widget.sellerId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BColors.surface,
      appBar: AppBar(
        backgroundColor: BColors.surface,
        foregroundColor: BColors.ink,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: BColors.border)),
        titleSpacing: 0,
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: BColors.background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BColors.border),
          ),
          child: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: _submit,
            style: const TextStyle(fontSize: 14, color: BColors.ink),
            decoration: InputDecoration(
              hintText: widget.inShop ? 'Search in ${widget.shopName ?? 'shop'}' : 'Search products, brands, shops',
              hintStyle: const TextStyle(color: BColors.faint, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: BColors.muted, size: 20),
              suffixIcon: ValueListenableBuilder(
                valueListenable: controller,
                builder: (_, value, __) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close, size: 18, color: BColors.muted),
                        onPressed: controller.clear,
                      ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body: _text.length >= _minLength
          ? _suggestions()
          : NotificationListener<ScrollNotification>(
              onNotification: (n) => handleNearEnd(n, _discover.loadMore),
              child: ListenableBuilder(
                listenable: Listenable.merge([store, _discover]),
                builder: (context, _) => CustomScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(child: _recent()),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Row(children: [
                          Icon(Icons.favorite_border_rounded, size: 18, color: BColors.ink),
                          SizedBox(width: 8),
                          Text('You may also like', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: BColors.ink)),
                        ]),
                      ),
                    ),
                    ...productGridSlivers(context, _discover, empty: const SizedBox.shrink()),
                    SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _recent() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...[
            if (store.recentSearches.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text('Recent searches', style: BText.section),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ...store.recentSearches.map((q) => ActionChip(
                          avatar: const Icon(Icons.history, size: 16, color: BColors.muted),
                          label: Text(q, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onPressed: () => _submit(q),
                          backgroundColor: BColors.background,
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                          labelStyle: const TextStyle(fontSize: 14, color: BColors.ink),
                        )),
                    IconButton.filledTonal(
                      tooltip: 'Clear recent searches',
                      onPressed: store.clearRecentSearches,
                      icon: const Icon(Icons.delete_outline, size: 20),
                      style: IconButton.styleFrom(backgroundColor: BColors.background, foregroundColor: BColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
      ],
    ]);
  }
}
