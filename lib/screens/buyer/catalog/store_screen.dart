
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/api_service.dart';
import '../../../services/buyer_api_service.dart';
import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../chat/chat_thread_screen.dart';
import '../product/product_detail_screen.dart';
import '../product/reviews_screen.dart';
import '../widgets/buyer_widgets.dart';
import '../widgets/deal_ticket.dart';
import '../widgets/success_popup.dart';
import 'search_screen.dart';

const _tabNames = ['Shop', 'Products', 'Reviews'];

/// The shop's customer-facing page: identity header (search, follow, chat,
/// share / report / block menu), then Shop · Products · Reviews.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, required this.storeId, this.name, this.logo});

  final String storeId;
  final String? name;
  final String? logo;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final store = BuyerStore.instance;

  Map<String, dynamic>? info;
  bool notFound = false;
  String? error;

  bool? following;
  int followers = 0;
  bool followBusy = false;

  List<Coupon> vouchers = [];
  final Set<String> claimed = {};
  final Set<String> claiming = {};
  bool walletLoaded = false; // avoids flashing already-claimed vouchers

  final products = <Product>[];
  int productPage = 0;
  int productLast = 1;
  bool loadingProducts = false;
  String sort = 'newest';

  ReviewSummary? reviewSummary;
  List<Review> reviews = [];

  int tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------------- Data ----------------

  Future<void> _load() async {
    setState(() => error = null);
    try {
      final data = await store.api.storeInfo(widget.storeId);
      if (!mounted) return;
      setState(() {
        info = data;
        following = data['isFollowing'] as bool?;
        followers = (data['followerCount'] as num?)?.toInt() ?? 0;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // Blocked, hidden or removed shops come back as 404.
      setState(() => e.statusCode == 404 ? notFound = true : error = e.message);
      return;
    } catch (e) {
      if (mounted) setState(() => error = store.handleError(e));
      return;
    }
    _loadProducts(reset: true);
    store.api.storeVouchers(widget.storeId).then((list) {
      if (mounted) setState(() => vouchers = list);
    }).catchError((_) {});
    store.api.couponWallet().then((wallet) {
      if (mounted) {
        setState(() {
          claimed.addAll(wallet.map((w) => w.couponId).whereType<String>());
          walletLoaded = true;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => walletLoaded = true);
    });
    store.api.storeReviews(widget.storeId, perPage: 5).then((r) {
      if (mounted) {
        setState(() {
          reviews = r.$1;
          reviewSummary = r.$2;
        });
      }
    }).catchError((_) {});
  }

  Future<void> _loadProducts({bool reset = false}) async {
    if (loadingProducts) return;
    if (reset) {
      products.clear();
      productPage = 0;
      productLast = 1;
    }
    if (productPage >= productLast) return;
    setState(() => loadingProducts = true);
    try {
      final (list, last) = await store.api.products(sellerId: widget.storeId, sort: sort == 'newest' ? null : sort, page: productPage + 1, perPage: 20);
      if (!mounted) return;
      setState(() {
        products.addAll(list);
        productPage++;
        productLast = last;
      });
    } catch (_) {
      // The grid just stops growing; pulling to refresh retries.
    } finally {
      if (mounted) setState(() => loadingProducts = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (followBusy || following == null) return;
    setState(() => followBusy = true);
    try {
      if (following!) {
        await store.api.unfollowStore(widget.storeId);
        if (mounted) {
          setState(() {
            following = false;
            followers = (followers - 1).clamp(0, 1 << 31);
          });
        }
      } else {
        final now = await store.api.followStore(widget.storeId);
        if (mounted) {
          setState(() {
            following = now;
            if (now) followers++;
          });
        }
      }
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    } finally {
      if (mounted) setState(() => followBusy = false);
    }
  }

  Future<void> _claim(Coupon c) async {
    setState(() => claiming.add(c.id));
    try {
      await store.api.claimCoupon(c.id);
      if (!mounted) return;
      setState(() => claimed.add(c.id));
      HapticFeedback.selectionClick();
      showToast(context, 'Voucher claimed — applied automatically at checkout');
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    } finally {
      if (mounted) setState(() => claiming.remove(c.id));
    }
  }

  // ---------------- Menu: share / report / block ----------------

  String get _name => '${info?['name'] ?? widget.name ?? 'Shop'}';

  Future<void> _share() async {
    await Clipboard.setData(ClipboardData(text: '${BuyerApiService.origin}/buyer/dashboard?store=${widget.storeId}'));
    if (mounted) showToast(context, 'Shop link copied');
  }

  Future<void> _report() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: BColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ReportSheet(targetId: widget.storeId, name: _name),
    );
    if (sent == true && mounted) {
      await showSuccessPopup(context, title: 'Report submitted', message: 'Thanks — our team will review it. You can follow it in Help & Support → My Reports.');
    }
  }

  Future<void> _showActions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: BColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: BColors.border, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Align(alignment: Alignment.centerLeft, child: Text(_name, maxLines: 1, overflow: TextOverflow.ellipsis, style: BText.title)),
        ),
        _ActionTile(icon: Icons.ios_share_rounded, color: BColors.brand, title: 'Share shop', subtitle: 'Copy a link to this shop', onTap: () => Navigator.pop(context, 'share')),
        _ActionTile(icon: Icons.flag_rounded, color: const Color(0xFFD97706), title: 'Report shop', subtitle: 'Tell us about a problem with this shop', onTap: () => Navigator.pop(context, 'report')),
        _ActionTile(icon: Icons.block_rounded, color: BColors.error, title: 'Block shop', subtitle: 'Hide this shop and its products from you', onTap: () => Navigator.pop(context, 'block')),
        SizedBox(height: 12 + MediaQuery.paddingOf(context).bottom),
      ]),
    );
    if (!mounted) return;
    switch (action) {
      case 'share':
        _share();
      case 'report':
        _report();
      case 'block':
        _block();
    }
  }

  Future<bool> _confirmBlock() async {
    const effects = [
      (Icons.visibility_off_outlined, 'Its shop, products and vouchers are hidden from you'),
      (Icons.archive_outlined, 'Your chat with it is archived'),
      (Icons.receipt_long_outlined, 'Order conversations stay available'),
      (Icons.lock_open_rounded, 'Unblock anytime in Privacy & Account'),
    ];
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true, // lets the sheet use the full height, so short screens scroll instead of overflowing
      backgroundColor: BColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: BColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: BColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.block_rounded, size: 32, color: BColors.error),
          ),
          const SizedBox(height: 14),
          Text('Block $_name?', textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: BColors.ink)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: BColors.background, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              for (final (icon, text) in effects)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Icon(icon, size: 19, color: BColors.muted),
                    const SizedBox(width: 12),
                    Expanded(child: Text(text, style: BText.body)),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: BColors.error, minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
            child: const Text('Block shop', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: BColors.muted),
            child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
    return ok == true;
  }

  Future<void> _block() async {
    final ok = await _confirmBlock();
    if (!ok || !mounted) return;
    try {
      await store.api.blockShop(widget.storeId);
      if (!mounted) return;
      showToast(context, 'Shop blocked');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    }
  }

  void _openSearch() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SearchScreen(sellerId: widget.storeId, shopName: _name)));

  // ---------------- Build ----------------

  @override
  Widget build(BuildContext context) {
    if (notFound || (info == null && error != null)) {
      return Scaffold(
        backgroundColor: BColors.background,
        appBar: AppBar(backgroundColor: BColors.surface, foregroundColor: BColors.ink, surfaceTintColor: BColors.surface),
        body: notFound
            ? EmptyState(icon: Icons.storefront_outlined, title: 'This shop isn\'t available', message: 'It may have been removed, or you\'ve blocked it.', actionLabel: 'Go back', onAction: () => Navigator.pop(context))
            : ErrorState(message: error!, onRetry: _load),
      );
    }
    return Scaffold(
      backgroundColor: BColors.background,
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (tab == 1 && n.metrics.extentAfter < 600) _loadProducts();
          return false;
        },
        child: RefreshIndicator(
          color: BColors.brand,
          edgeOffset: 120,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(child: _header()),
              SliverPersistentHeader(pinned: true, delegate: _TabsDelegate(index: tab, onTap: (i) => setState(() => tab = i))),
              if (info == null)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: BColors.brand))))
              else
                ..._content(),
              SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final data = info;
    final logo = (data?['logo'] as String?) ?? widget.logo;
    final banner = data?['banner'] as String?;
    final rating = data?['rating'] is num ? (data!['rating'] as num).toDouble() : null;
    final verified = data?['isVerified'] == true;
    final location = data?['location'] as String?;
    Widget circle(Widget child) => Container(width: 40, height: 40, decoration: const BoxDecoration(color: Color(0x66000000), shape: BoxShape.circle), child: child);
    const onBanner = Colors.white;
    const dot = Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: SizedBox(height: 12, child: VerticalDivider(width: 1, color: Colors.white54)));

    return Stack(children: [
      Positioned.fill(child: Container(color: BColors.brandDark, child: banner != null && banner.isNotEmpty ? NetImage(banner) : null)),
      // Darkens toward the bottom so the white identity text stays readable on any banner.
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.25), Colors.black.withValues(alpha: 0.62)]),
          ),
        ),
      ),
      SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 40),
          child: Column(children: [
            Row(children: [
              IconButton(tooltip: 'Back', onPressed: () => Navigator.pop(context), icon: circle(const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white))),
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _openSearch,
                    child: const Row(children: [
                      Icon(Icons.search_rounded, size: 20, color: BColors.muted),
                      SizedBox(width: 8),
                      Expanded(child: Text('Search in shop', style: TextStyle(color: BColors.muted, fontSize: 14.5))),
                    ]),
                  ),
                ),
              ),
              IconButton(tooltip: 'Shop actions', onPressed: _showActions, icon: circle(const Icon(Icons.more_vert_rounded, size: 20, color: Colors.white))),
            ]),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Container(
                  width: 72,
                  height: 72,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5)),
                  child: NetImage(logo, fallbackIcon: Icons.storefront_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(_name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: onBanner, height: 1.2))),
                      if (verified) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified_rounded, size: 18, color: onBanner)),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      if (rating != null) ...[
                        const Icon(Icons.star_rounded, size: 16, color: BColors.star),
                        const SizedBox(width: 3),
                        Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: onBanner)),
                        dot,
                      ],
                      Flexible(
                        child: Text('${_compact(followers)} ${followers == 1 ? 'Follower' : 'Followers'}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: onBanner)),
                      ),
                    ]),
                    if (location != null && location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Colors.white70),
                        const SizedBox(width: 3),
                        Flexible(child: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white70))),
                      ]),
                    ],
                  ]),
                ),
                const SizedBox(width: 10),
                // Follow over Chat, same width.
                Column(mainAxisSize: MainAxisSize.min, children: [
                  _HeaderButton(
                    icon: following == true ? Icons.check_rounded : Icons.add_rounded,
                    label: following == true ? 'Following' : 'Follow',
                    filled: following != true,
                    busy: followBusy,
                    onTap: following == null ? null : _toggleFollow,
                  ),
                  const SizedBox(height: 8),
                  _HeaderButton(icon: Icons.chat_bubble_outline_rounded, label: 'Chat', onTap: () => openSellerChat(context, sellerId: widget.storeId)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }

  static String _compact(int n) => n >= 1000000 ? '${(n / 1000000).toStringAsFixed(1)}M' : (n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : '$n');

  List<Widget> _content() => switch (tab) {
        0 => _shopTab(),
        1 => _productsTab(),
        _ => _reviewsTab(),
      };

  // ---- Shop ----

  List<Widget> _shopTab() {
    final d = info!;
    final description = d['description'] as String?;
    final policy = d['returnPolicy'] as String?;
    final joined = d['joinedAt'] != null ? DateTime.tryParse('${d['joinedAt']}') : null;
    // Right under the tabs: claim a voucher, or use one you already claimed.
    final shown = walletLoaded ? vouchers : const <Coupon>[];
    return [
      if (shown.isNotEmpty)
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: shown.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final v = shown[i];
                  return DealTicket(
                    coupon: v,
                    claimed: claimed.contains(v.id),
                    claiming: claiming.contains(v.id),
                    onClaim: () => _claim(v),
                    onUse: () => setState(() => tab = 1),
                  );
                },
              ),
            ),
          ),
        ),
      if (products.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 8, 10),
            child: Row(children: [
              const Expanded(child: Text('Popular products', style: BText.title)),
              TextButton(onPressed: () => setState(() => tab = 1), child: const Text('See all', style: TextStyle(fontWeight: FontWeight.w800, color: BColors.brand))),
            ]),
          ),
        ),
        _grid(products.take(6).toList()),
      ],
      SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 18, 12, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: BColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('About this shop', style: BText.title),
            const SizedBox(height: 10),
            if (description != null && description.isNotEmpty) Text(description, style: BText.body) else const Text('This shop hasn\'t added a description yet.', style: BText.small),
            const SizedBox(height: 12),
            if ((d['category'] as String?)?.isNotEmpty == true) _aboutRow(Icons.category_outlined, '${d['category']}'),
            if (joined != null) _aboutRow(Icons.event_outlined, 'Joined ${formatDate(joined)}'),
            if (policy != null && policy.isNotEmpty) ...[
              const Divider(height: 24, color: BColors.divider),
              const Text('Return policy', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(policy, style: BText.body),
            ],
          ]),
        ),
      ),
    ];
  }

  Widget _aboutRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [Icon(icon, size: 17, color: BColors.brand), const SizedBox(width: 10), Expanded(child: Text(text, style: BText.small))]),
      );

  Widget _grid(List<Product> list) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: kGridPadding),
        sliver: SliverGrid.builder(
          gridDelegate: productGridDelegate(context),
          itemCount: list.length,
          itemBuilder: (_, i) => ProductCard(product: list[i], onTap: () => openProduct(context, list[i])),
        ),
      );

  // ---- Products ----

  List<Widget> _productsTab() {
    const sorts = {'newest': 'Newest', 'price-asc': 'Price: low to high', 'price-desc': 'Price: high to low'};
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
          child: Row(children: [
            Expanded(child: Text('${info?['productCount'] ?? products.length} products', style: BText.small)),
            PopupMenuButton<String>(
              tooltip: 'Sort products',
              initialValue: sort,
              onSelected: (v) {
                setState(() => sort = v);
                _loadProducts(reset: true);
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              itemBuilder: (_) => [for (final e in sorts.entries) PopupMenuItem(value: e.key, child: Text(e.value, style: TextStyle(fontWeight: e.key == sort ? FontWeight.w800 : FontWeight.w500)))],
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: BColors.border)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.swap_vert_rounded, size: 18, color: BColors.brand),
                  const SizedBox(width: 6),
                  Text(sorts[sort]!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
        ),
      ),
      if (products.isEmpty && !loadingProducts)
        const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(24), child: EmptyState(icon: Icons.inventory_2_outlined, title: 'No products yet', message: 'This shop hasn\'t listed anything yet.')))
      else
        _grid(products),
      if (loadingProducts) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(20), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: BColors.brand))))),
    ];
  }

  // ---- Reviews ----

  List<Widget> _reviewsTab() {
    final s = reviewSummary;
    if (s == null || s.total == 0) {
      return const [SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(24), child: EmptyState(icon: Icons.rate_review_outlined, title: 'No reviews yet', message: 'Reviews appear here after buyers receive their orders.')))];
    }
    return [
      SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 14, 12, 0),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: BColors.border)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Column(children: [
                  Text(s.average?.toStringAsFixed(1) ?? '–', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, height: 1)),
                  const SizedBox(height: 6),
                  StarRow(s.average ?? 0, size: 16),
                  const SizedBox(height: 4),
                  Text('${s.total} reviews', style: BText.tiny),
                ]),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(children: [
                    for (final star in [5, 4, 3, 2, 1])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.5),
                        child: Row(children: [
                          SizedBox(width: 12, child: Text('$star', style: BText.tiny)),
                          const Icon(Icons.star_rounded, size: 12, color: BColors.star),
                          const SizedBox(width: 6),
                          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: s.total == 0 ? 0 : (s.breakdown[star] ?? 0) / s.total, minHeight: 6, backgroundColor: BColors.divider, color: BColors.star))),
                          SizedBox(width: 30, child: Text('${s.breakdown[star] ?? 0}', textAlign: TextAlign.right, style: BText.tiny)),
                        ]),
                      ),
                  ]),
                ),
              ]),
            ),
            for (final r in reviews) Column(children: [const Divider(height: 1, color: BColors.divider), ReviewTile(review: r, showProduct: true)]),
            const Divider(height: 1, color: BColors.divider),
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReviewsScreen(storeId: widget.storeId, initialSummary: s))),
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: BColors.brand),
              child: const Text('See all reviews', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ),
    ];
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: color == BColors.error ? BColors.error : BColors.ink)),
        subtitle: Text(subtitle, style: BText.small),
        trailing: const Icon(Icons.chevron_right_rounded, color: BColors.faint),
      );
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.label, required this.onTap, this.filled = false, this.busy = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 38,
        child: Material(
          color: filled ? BColors.brand : Colors.transparent,
          shape: const StadiumBorder(side: BorderSide(color: BColors.brand, width: 1.3)),
          child: InkWell(
            onTap: busy ? null : onTap,
            customBorder: const StadiumBorder(),
            child: Container(
              constraints: const BoxConstraints(minWidth: 100),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              child: busy
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: filled ? Colors.white : BColors.brand))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 17, color: filled ? Colors.white : BColors.brand),
                      const SizedBox(width: 5),
                      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: filled ? Colors.white : BColors.brand)),
                    ]),
            ),
          ),
        ),
      );
}

/// Pinned Shop · Products · Categories · Reviews tabs on a white rounded sheet.
class _TabsDelegate extends SliverPersistentHeaderDelegate {
  const _TabsDelegate({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  double get minExtent => 50;
  @override
  double get maxExtent => 50;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: overlapsContent ? null : const BorderRadius.vertical(top: Radius.circular(22)), border: const Border(bottom: BorderSide(color: BColors.border))),
        child: Row(children: [
          for (var i = 0; i < _tabNames.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Expanded(child: Center(child: Text(_tabNames[i], style: TextStyle(fontSize: 14.5, fontWeight: i == index ? FontWeight.w800 : FontWeight.w600, color: i == index ? BColors.brand : BColors.muted)))),
                  AnimatedContainer(duration: const Duration(milliseconds: 200), height: 3, width: i == index ? 36 : 0, decoration: BoxDecoration(color: BColors.brand, borderRadius: BorderRadius.circular(3))),
                ]),
              ),
            ),
        ]),
      );

  @override
  bool shouldRebuild(covariant _TabsDelegate old) => old.index != index;
}

// ============================================================
// Report sheet
// ============================================================

const _reportReasons = [
  ('fraud_deception', 'Fraud and Deception'),
  ('legal_regulatory', 'Legal and Regulatory'),
  ('discriminatory_offensive', 'Discriminatory or Offensive Conduct'),
  ('policy_violations', 'Policy Violations'),
  ('product_issues', 'Product Issues'),
  ('pricing_fees', 'Pricing and Fees'),
  ('shipping_problems', 'Shipping Problems'),
  ('customer_service', 'Customer Service and Communication'),
];

const _productReportReasons = [
  ('prohibited_items', 'Prohibited (Banned) Items'),
  ('counterfeit_copyright', 'Counterfeits and Copyright'),
  ('offensive_items', 'Offensive or Potentially Offensive Items'),
  ('fraudulent_listing', 'Fraudulent Listings (illegal seller demands, etc.)'),
  ('off_platform_transactions', 'Directing Transactions Outside BuyTheWay'),
  ('others', 'Others'),
];

/// Report a shop, or a product when [product] is true.
class ReportSheet extends StatefulWidget {
  const ReportSheet({super.key, required this.targetId, required this.name, this.product = false});

  final String targetId;
  final String name;
  final bool product;

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final store = BuyerStore.instance;
  final details = TextEditingController();
  String? reason;
  bool anonymous = false;
  bool sending = false;
  String? error;

  static const _maxEvidence = 8;
  final List<(String, Uint8List)> evidence = [];

  @override
  void dispose() {
    details.dispose();
    super.dispose();
  }

  Future<void> _pickEvidence() async {
    final room = _maxEvidence - evidence.length;
    if (room <= 0) return;
    final picker = ImagePicker();
    // pickMultiImage's limit must be at least 2.
    final files = room == 1
        ? [if (await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80) case final XFile one) one]
        : await picker.pickMultiImage(maxWidth: 1600, imageQuality: 80, limit: room);
    if (files.isEmpty) return;
    final picked = <(String, Uint8List)>[];
    for (final f in files.take(room)) {
      picked.add((f.name, await f.readAsBytes()));
    }
    if (!mounted) return;
    setState(() {
      evidence.addAll(picked);
      error = null;
    });
  }

  Future<void> _submit() async {
    if (reason == null) {
      setState(() => error = 'Choose a reason for your report.');
      return;
    }
    if (details.text.trim().isEmpty) {
      setState(() => error = 'Tell us what happened.');
      return;
    }
    if (evidence.isEmpty) {
      setState(() => error = 'Add at least one photo as evidence.');
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      final paths = await Future.wait(evidence.map((e) => store.api.uploadReportEvidence(e.$2, e.$1)));
      widget.product
          ? await store.api.reportProduct(widget.targetId, reason: reason!, details: details.text.trim(), anonymous: anonymous, evidence: paths)
          : await store.api.reportStore(widget.targetId, reason: reason!, details: details.text.trim(), anonymous: anonymous, evidence: paths);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          sending = false;
          error = store.handleError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: BColors.border, borderRadius: BorderRadius.circular(2))),
          SizedBox(
            height: 56,
            child: Row(children: [
              const SizedBox(width: 48),
              Expanded(child: Text('Report ${widget.name}', textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
              IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              const SizedBox(width: 4),
            ]),
          ),
          const Divider(height: 1, color: BColors.border),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              children: [
                const Text('What\'s the problem?', style: BText.section),
                const SizedBox(height: 6),
                RadioGroup<String>(
                  groupValue: reason ?? '',
                  onChanged: (v) => setState(() {
                    reason = v;
                    error = null;
                  }),
                  child: Column(children: [
                    for (final (key, label) in (widget.product ? _productReportReasons : _reportReasons)) RadioListTile<String>(value: key, dense: true, contentPadding: EdgeInsets.zero, activeColor: BColors.brand, title: Text(label, style: const TextStyle(fontSize: 14))),
                  ]),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: details,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() => error = null),
                  decoration: InputDecoration(
                    hintText: 'Describe what happened',
                    filled: true,
                    fillColor: BColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: BColors.brand, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  const Text('Evidence', style: BText.section),
                  const SizedBox(width: 6),
                  const Text('required', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: BColors.error)),
                  const Spacer(),
                  Text('${evidence.length}/$_maxEvidence', style: BText.tiny),
                ]),
                const SizedBox(height: 4),
                const Text('Screenshots or photos that show the problem.', style: BText.tiny),
                const SizedBox(height: 10),
                SizedBox(
                  height: 84,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    if (evidence.length < _maxEvidence)
                      InkWell(
                        onTap: sending ? null : _pickEvidence,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 84,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(color: BColors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: BColors.border)),
                          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.add_photo_alternate_outlined, color: BColors.brand, size: 26),
                            SizedBox(height: 4),
                            Text('Add photos', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: BColors.brand)),
                          ]),
                        ),
                      ),
                    for (var i = 0; i < evidence.length; i++)
                      Container(
                        width: 84,
                        margin: const EdgeInsets.only(right: 10),
                        child: Stack(fit: StackFit.expand, children: [
                          ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(evidence[i].$2, fit: BoxFit.cover, cacheWidth: 250)),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: InkWell(
                              onTap: sending ? null : () => setState(() => evidence.removeAt(i)),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(color: Color(0xAA000000), shape: BoxShape.circle),
                                child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ]),
                      ),
                  ]),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  value: anonymous,
                  onChanged: (v) => setState(() => anonymous = v),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeTrackColor: BColors.brand,
                  title: const Text('Report anonymously', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  subtitle: const Text('The shop won\'t see that it was you.', style: BText.tiny),
                ),
                if (error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(error!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: BColors.error))),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + MediaQuery.paddingOf(context).bottom),
            child: FilledButton(
              onPressed: sending ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: BColors.error, minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
              child: sending ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : const Text('Submit report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      );
}
