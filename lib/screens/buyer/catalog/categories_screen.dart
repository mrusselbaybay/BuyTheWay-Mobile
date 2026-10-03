import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../buyer_theme.dart';
import '../widgets/buyer_widgets.dart';
import '../widgets/product_pager.dart';
import 'home_screen.dart';
import 'search_screen.dart';

/// Left category rail + product grid on the right (Lazada/Shopee category
/// tab). One pager per category, kept so switching back is instant.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> with AutomaticKeepAliveClientMixin {
  final Map<String, ProductPager> _pagers = {};
  String _selected = kCategories.first;

  @override
  bool get wantKeepAlive => true;

  ProductPager _pagerFor(String category) => _pagers.putIfAbsent(category, () => ProductPager(category: category)..loadMore());

  @override
  void dispose() {
    for (final p in _pagers.values) {
      p.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pager = _pagerFor(_selected);
    final media = MediaQuery.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: BColors.background,
        body: Column(children: [
          // Same hero language as Home so the two browse tabs feel like one place.
          Container(
            padding: EdgeInsets.fromLTRB(16, media.padding.top + 10, 16, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: kHeroGradient),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Categories', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              SearchBox(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen()))),
            ]),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: Row(children: [
                SizedBox(
                  width: 88,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(6, 10, 6, media.padding.bottom),
                    children: kCategories.map((c) {
                      final active = c == _selected;
                      final accent = categoryAccent(c);
                      return Semantics(
                        selected: active,
                        button: true,
                        label: c,
                        excludeSemantics: true,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Material(
                            color: active ? BColors.surface : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selected = c);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                child: Column(children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: active ? accent : accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(categoryIcon(c), size: 22, color: active ? Colors.white : accent),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    categoryShortLabel(c),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    style: TextStyle(
                                      fontSize: 11,
                                      height: 1.15,
                                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                                      color: active ? BColors.ink : BColors.muted,
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => ListenableBuilder(
                      listenable: pager,
                      builder: (context, _) => RefreshIndicator(
                        color: BColors.brand,
                        onRefresh: pager.refresh,
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (n) => handleNearEnd(n, pager.loadMore),
                          child: CustomScrollView(
                            key: PageStorageKey(_selected),
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
                                  child: Text(_selected, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: BColors.ink)),
                                ),
                              ),
                              ...productGridSlivers(
                                context,
                                pager,
                                width: constraints.maxWidth,
                                empty: const EmptyState(
                                  icon: Icons.inventory_2_outlined,
                                  title: 'Nothing here yet',
                                  message: 'No products are listed in this category yet.',
                                ),
                              ),
                              // Clears the floating nav bar (extendBody in the shell).
                              SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
