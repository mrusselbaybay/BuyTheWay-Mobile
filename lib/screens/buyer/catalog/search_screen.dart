import 'package:flutter/material.dart';

import '../buyer_store.dart';
import '../buyer_theme.dart';
import 'product_list_screen.dart';

/// Full-screen search: autofocused field, recent searches, quick
/// categories. Submitting opens the results list.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initial});

  final String? initial;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final controller = TextEditingController(text: widget.initial);
  final store = BuyerStore.instance;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    store.rememberSearch(query);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ProductListScreen(title: query, search: query),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BColors.surface,
      appBar: AppBar(
        backgroundColor: BColors.brand,
        foregroundColor: Colors.white,
        surfaceTintColor: BColors.brand,
        titleSpacing: 0,
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(BRadius.sm)),
          child: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: _submit,
            style: const TextStyle(fontSize: 14, color: BColors.ink),
            decoration: InputDecoration(
              hintText: 'Search products, brands, shops',
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
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            if (store.recentSearches.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
                child: Row(children: [
                  const Expanded(child: Text('Recent searches', style: BText.section)),
                  TextButton(onPressed: store.clearRecentSearches, child: const Text('Clear', style: TextStyle(color: BColors.muted))),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: store.recentSearches
                      .map((q) => ActionChip(
                            label: Text(q),
                            onPressed: () => _submit(q),
                            backgroundColor: BColors.background,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BRadius.sm)),
                            labelStyle: const TextStyle(fontSize: 13, color: BColors.ink),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Browse categories', style: BText.section),
            ),
            ...kCategories.map((c) => ListTile(
                  leading: Icon(categoryIcon(c), color: BColors.brand),
                  title: Text(c, style: BText.body),
                  trailing: const Icon(Icons.chevron_right, color: BColors.faint),
                  onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (_) => ProductListScreen(title: c, category: c),
                  )),
                )),
          ],
        ),
      ),
    );
  }
}
