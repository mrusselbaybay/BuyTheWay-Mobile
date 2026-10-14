import 'package:flutter/material.dart';

import '../../driver/driver_theme.dart';
import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../product/product_detail_screen.dart';
import '../widgets/buyer_widgets.dart';
import 'settings_kit.dart';

const _amberSoft = Color(0xFFFFFBEB);
const _amber = Color(0xFFF59E0B);
const _amberDark = Color(0xFFB45309);

enum _Sort {
  recent('Most recent', Icons.schedule_rounded),
  lowest('Lowest to highest', Icons.trending_up_rounded),
  highest('Highest to lowest', Icons.trending_down_rounded);

  const _Sort(this.label, this.icon);
  final String label;
  final IconData icon;
}

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  final store = BuyerStore.instance;
  final searchController = TextEditingController();
  List<MyReview>? reviews;
  String? error;
  int ratingFilter = 0; // 0 = all
  _Sort sort = _Sort.recent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => error = null);
    try {
      final list = await store.api.myReviews();
      if (mounted) setState(() => reviews = list);
    } catch (e) {
      if (mounted) setState(() => error = store.handleError(e));
    }
  }

  Future<void> _delete(MyReview r) async {
    final ok = await confirmDialog(context, title: 'Delete this review?', message: 'Your review of ${r.productName} will be permanently removed.', confirmLabel: 'Delete', destructive: true);
    if (!ok) return;
    final previous = reviews;
    setState(() => reviews = reviews?.where((x) => x.id != r.id).toList());
    try {
      await store.api.deleteReview(r.id);
      if (mounted) showToast(context, 'Review deleted');
    } catch (e) {
      if (!mounted) return;
      setState(() => reviews = previous);
      showToast(context, store.handleError(e), error: true);
    }
  }

  bool get _filtering => ratingFilter != 0 || searchController.text.trim().isNotEmpty || sort != _Sort.recent;

  void _clearFilters() => setState(() {
        ratingFilter = 0;
        sort = _Sort.recent;
        searchController.clear();
      });

  List<MyReview> _visible(List<MyReview> all) {
    final query = searchController.text.trim().toLowerCase();
    final list = all.where((r) {
      if (ratingFilter != 0 && r.rating != ratingFilter) return false;
      if (query.isEmpty) return true;
      return r.productName.toLowerCase().contains(query) || (r.comment ?? '').toLowerCase().contains(query);
    }).toList();
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    switch (sort) {
      case _Sort.recent:
        list.sort((a, b) => (b.createdAt ?? epoch).compareTo(a.createdAt ?? epoch));
      case _Sort.lowest:
        list.sort((a, b) => a.rating.compareTo(b.rating));
      case _Sort.highest:
        list.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final all = reviews;
    if (all == null) {
      return Scaffold(
        backgroundColor: DriverColors.background,
        appBar: settingsAppBar('My Reviews', centerTitle: true, backgroundColor: DriverColors.primarySurface),
        body: error != null ? ErrorState(message: error!, onRetry: _load) : const Padding(padding: EdgeInsets.all(16), child: RowsSkeleton(count: 3, tile: 52)),
      );
    }
    final list = _visible(all);
    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: settingsAppBar('My Reviews', centerTitle: true, backgroundColor: DriverColors.primarySurface),
      body: RefreshIndicator(
        color: DriverColors.primary,
        onRefresh: _load,
        child: all.isEmpty
            ? ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: const [
                EmptyCard(icon: Icons.rate_review_outlined, title: 'No reviews yet', message: 'Rate items from your delivered orders to help other shoppers.'),
              ])
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(child: _hero(all)),
                  SliverPersistentHeader(pinned: true, delegate: _PinnedHeader(extent: 118, child: _controls(all))),
                  SliverToBoxAdapter(child: _resultLine(all.length, list.length)),
                  if (list.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(padding: const EdgeInsets.all(16), child: EmptyCard(icon: Icons.search_off_rounded, title: 'No matching reviews', message: 'Try a different search or rating.', actionLabel: 'Clear filters', onAction: _clearFilters)),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.paddingOf(context).bottom + 24),
                      sliver: SliverList.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _ReviewCard(review: list[i], onDelete: () => _delete(list[i])),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  /// Average rating, how the ratings are spread (tap a bar to filter), and
  /// how many were left this month.
  Widget _hero(List<MyReview> all) {
    final now = DateTime.now();
    final average = all.fold<int>(0, (sum, r) => sum + r.rating) / all.length;
    final thisMonth = all.where((r) => r.createdAt != null && r.createdAt!.toLocal().year == now.year && r.createdAt!.toLocal().month == now.month).length;
    final counts = {for (var s = 1; s <= 5; s++) s: all.where((r) => r.rating == s).length};
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [DriverColors.primarySurface, DriverColors.background])),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: softShadow(0.08)),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(average.toStringAsFixed(1), style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, height: 1, color: DriverColors.textPrimary, letterSpacing: -1)),
              const SizedBox(height: 6),
              StarRow(average, size: 15),
              const SizedBox(height: 6),
              const Text('Avg. rating', style: DriverText.caption),
            ]),
            const SizedBox(width: 18),
            Expanded(
              child: Column(children: [
                for (var s = 5; s >= 1; s--)
                  _DistributionBar(
                    stars: s,
                    count: counts[s]!,
                    total: all.length,
                    selected: ratingFilter == s,
                    onTap: () => setState(() => ratingFilter = ratingFilter == s ? 0 : s),
                  ),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _MiniStat(icon: Icons.rate_review_rounded, label: 'Total reviews', value: '${all.length}', color: DriverColors.primary)),
            const SizedBox(width: 10),
            Expanded(child: _MiniStat(icon: Icons.calendar_month_rounded, label: 'This month', value: '$thisMonth', color: const Color(0xFF6366F1))),
          ]),
        ]),
      ),
    );
  }

  /// Pinned: search bar + sort, then the star-filter chips.
  Widget _controls(List<MyReview> all) {
    final hasText = searchController.text.isNotEmpty;
    return Container(
      color: DriverColors.background,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        Row(children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: softShadow(0.06)),
              child: TextField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                style: DriverText.body.copyWith(fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'Search reviews',
                  hintStyle: DriverText.body.copyWith(fontSize: 14.5, color: DriverColors.textSecondary),
                  prefixIcon: const Icon(Icons.search_rounded, size: 22, color: DriverColors.primary),
                  suffixIcon: hasText ? IconButton(tooltip: 'Clear search', icon: const Icon(Icons.close_rounded, size: 19), onPressed: () => setState(searchController.clear)) : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: DriverColors.primary, width: 1.5)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<_Sort>(
            tooltip: 'Sort reviews',
            initialValue: sort,
            onSelected: (v) => setState(() => sort = v),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            itemBuilder: (_) => [
              for (final option in _Sort.values)
                PopupMenuItem(
                  value: option,
                  child: Row(children: [
                    Icon(option.icon, size: 18, color: option == sort ? DriverColors.primary : DriverColors.textSecondary),
                    const SizedBox(width: 10),
                    Text(option.label, style: TextStyle(fontWeight: option == sort ? FontWeight.w800 : FontWeight.w500)),
                  ]),
                ),
            ],
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: sort == _Sort.recent ? Colors.white : DriverColors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: softShadow(0.06),
              ),
              child: Icon(Icons.swap_vert_rounded, color: sort == _Sort.recent ? DriverColors.primary : Colors.white),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            _RatingChip(label: 'All', selected: ratingFilter == 0, onTap: () => setState(() => ratingFilter = 0)),
            for (var stars = 5; stars >= 1; stars--) _RatingChip(label: '$stars', icon: Icons.star_rounded, selected: ratingFilter == stars, onTap: () => setState(() => ratingFilter = ratingFilter == stars ? 0 : stars)),
          ]),
        ),
      ]),
    );
  }

  Widget _resultLine(int total, int shown) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 12, 6),
        child: Row(children: [
          Expanded(
            child: Text(
              shown == total ? '$total ${total == 1 ? 'review' : 'reviews'} · ${sort.label}' : '$shown of $total reviews · ${sort.label}',
              style: DriverText.caption.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          if (_filtering) TextButton(onPressed: _clearFilters, style: TextButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 8)), child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w800))),
        ]),
      );
}

/// Fixed-height pinned header for the search + filter block.
class _PinnedHeader extends SliverPersistentHeaderDelegate {
  const _PinnedHeader({required this.extent, required this.child});
  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _PinnedHeader old) => true;
}

/// One "5 ★ ▓▓▓▓░░ 12" row of the rating breakdown; tap to filter.
class _DistributionBar extends StatelessWidget {
  const _DistributionBar({required this.stars, required this.count, required this.total, required this.selected, required this.onTap});
  final int stars;
  final int count;
  final int total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;
    return Semantics(
      button: true,
      selected: selected,
      label: '$stars star reviews, $count',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.5),
          child: Row(children: [
            SizedBox(
              width: 26,
              child: Row(children: [
                Text('$stars', style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w900 : FontWeight.w700, color: selected ? _amberDark : DriverColors.textSecondary)),
                const Icon(Icons.star_rounded, size: 12, color: _amber),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: fraction, minHeight: 7, backgroundColor: const Color(0xFFF1F5F9), valueColor: AlwaysStoppedAnimation(selected ? _amberDark : _amber)),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 22, child: Text('$count', textAlign: TextAlign.right, style: DriverText.caption.copyWith(fontWeight: FontWeight.w700))),
          ]),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, height: 1.1, color: DriverColors.textPrimary)),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: DriverText.caption.copyWith(fontSize: 11)),
            ]),
          ),
        ]),
      );
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.label, required this.selected, required this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: icon == null ? null : Icon(icon, size: 16, color: selected ? Colors.white : _amber),
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          onSelected: (_) => onTap(),
          selectedColor: DriverColors.primary,
          backgroundColor: Colors.white,
          side: BorderSide(color: selected ? DriverColors.primary : DriverColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: selected ? Colors.white : DriverColors.textPrimary),
        ),
      );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.onDelete});

  final MyReview review;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final r = review;
    final hasComment = r.comment != null && r.comment!.isNotEmpty;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: DriverColors.border), boxShadow: softShadow(0.04)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          onTap: r.productId == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: r.productId!))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
            child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(14), child: CategoryThumb(category: r.category, image: r.image, size: 54)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.productName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, height: 1.25, color: DriverColors.textPrimary)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.calendar_today_rounded, size: 12, color: DriverColors.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(child: Text('${formatDate(r.createdAt)}${r.isEdited ? ' · Edited' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: DriverText.caption)),
                  ]),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: _amberSoft, borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star_rounded, size: 16, color: _amber),
                  const SizedBox(width: 3),
                  Text('${r.rating}.0', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _amberDark)),
                ]),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StarRow(r.rating.toDouble(), size: 17),
            const SizedBox(height: 8),
            Text(
              hasComment ? r.comment! : 'No written comment was added.',
              style: DriverText.body.copyWith(height: 1.45, color: hasComment ? DriverColors.textPrimary : DriverColors.textSecondary, fontStyle: hasComment ? FontStyle.normal : FontStyle.italic),
            ),
          ]),
        ),
        if (r.sellerResponse != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: DriverColors.primarySurface, borderRadius: BorderRadius.circular(14)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const IconTile(Icons.storefront_rounded, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Seller response', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: DriverColors.primary)),
                  const SizedBox(height: 3),
                  Text(r.sellerResponse!, style: const TextStyle(fontSize: 12.5, height: 1.4, color: DriverColors.textPrimary)),
                ]),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
              style: TextButton.styleFrom(foregroundColor: DriverColors.textSecondary, minimumSize: const Size(0, 40)),
            ),
          ),
        ),
      ]),
    );
  }
}
