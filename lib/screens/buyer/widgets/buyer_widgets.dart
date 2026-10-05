import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../services/buyer_api_service.dart';
import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';

// ============================================================
// Images
// ============================================================

/// Renders a product image from whatever the API hands back: a full URL, a
/// site-relative path, or an inline `data:` URL (legacy uploads). Decodes at
/// display size (cacheWidth) so grid thumbnails never hold full-res bitmaps.
///
/// Network images go through [_LoadGate] (a few downloads at a time) and
/// retry with backoff: the backend can only serve one request at a time, so
/// a grid firing 20 requests at once used to time most of them out for good.
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover, this.fallbackIcon = Icons.image_outlined});

  final String? url;
  final BoxFit fit;
  final IconData fallbackIcon;

  /// Bumped on pull-to-refresh so images that gave up try again.
  static final ValueNotifier<int> retryEpoch = ValueNotifier<int>(0);
  static void retryFailed() => retryEpoch.value++;

  static final Map<String, Uint8List> _dataCache = {};

  static Uint8List? _decodeData(String url) {
    final cached = _dataCache[url];
    if (cached != null) return cached;
    final comma = url.indexOf(',');
    if (comma < 0) return null;
    try {
      final bytes = base64Decode(url.substring(comma + 1));
      if (_dataCache.length > 60) _dataCache.remove(_dataCache.keys.first);
      return _dataCache[url] = bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = url?.trim() ?? '';
    final fallback = _ImageFallback(icon: fallbackIcon);
    // The API's imageless placeholder is an SVG, which Image can't decode.
    if (raw.isEmpty || raw.toLowerCase().endsWith('.svg')) return fallback;

    return LayoutBuilder(builder: (context, constraints) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final width = constraints.maxWidth.isFinite ? (constraints.maxWidth * dpr).round() : null;

      if (raw.startsWith('data:')) {
        final bytes = _decodeData(raw);
        if (bytes == null) return fallback;
        return Image.memory(bytes, fit: fit, cacheWidth: width, gaplessPlayback: true, errorBuilder: (_, __, ___) => fallback);
      }

      final resolved = raw.startsWith('http') ? raw : '${BuyerApiService.origin}${raw.startsWith('/') ? '' : '/'}$raw';
      return _NetworkImageLoader(key: ValueKey('$resolved@$width'), url: resolved, cacheWidth: width, fit: fit, fallback: fallback);
    });
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final side = c.biggest.shortestSide;
          return Container(
            color: BColors.divider,
            alignment: Alignment.center,
            child: Icon(icon, color: BColors.faint, size: side.isFinite ? (side * 0.36).clamp(16.0, 30.0) : 28),
          );
        },
      );
}

/// Caps concurrent image downloads (FIFO) so a single-worker backend isn't
/// flooded and the images nearest the top arrive first.
class _LoadGate {
  static const _max = 4;
  static int _active = 0;
  static final _waiting = Queue<Completer<void>>();

  static Future<void> acquire() {
    if (_active < _max) {
      _active++;
      return Future.value();
    }
    final c = Completer<void>();
    _waiting.add(c);
    return c.future;
  }

  static void release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _active--;
    }
  }
}

class _NetworkImageLoader extends StatefulWidget {
  const _NetworkImageLoader({super.key, required this.url, required this.cacheWidth, required this.fit, required this.fallback});

  final String url;
  final int? cacheWidth;
  final BoxFit fit;
  final Widget fallback;

  @override
  State<_NetworkImageLoader> createState() => _NetworkImageLoaderState();
}

class _NetworkImageLoaderState extends State<_NetworkImageLoader> {
  static const _maxAttempts = 4;
  static const _timeout = Duration(seconds: 20);

  late final ImageProvider _provider = ResizeImage.resizeIfNeeded(
      widget.cacheWidth,
      null,
      NetworkImage(
        widget.url,
        // Web: /storage files carry no CORS headers (artisan serve skips
        // middleware for static files), so fall back to an <img> element.
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      ));
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Timer? _timer;
  bool _holdingSlot = false;
  bool _ready = false;
  bool _fadeIn = false;
  bool _failed = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    NetImage.retryEpoch.addListener(_onRetryEpoch);
    _load();
  }

  void _onRetryEpoch() {
    if (!_failed) return;
    setState(() => _failed = false);
    _attempt = 0;
    _load();
  }

  Future<void> _load() async {
    final key = await _provider.obtainKey(ImageConfiguration.empty);
    if (!mounted) return;
    // Already decoded/in flight elsewhere (e.g. same image on another screen) — skip the queue.
    final status = PaintingBinding.instance.imageCache.statusForKey(key);
    if (status.keepAlive || status.live) {
      setState(() => _ready = true);
      return;
    }

    await _LoadGate.acquire();
    _holdingSlot = true;
    if (!mounted) return _releaseSlot();

    _listener = ImageStreamListener(
      (_, __) => _finish(success: true),
      onError: (_, __) => _finish(success: false),
    );
    _stream = _provider.resolve(createLocalImageConfiguration(context))..addListener(_listener!);
    _timer = Timer(_timeout, () => _finish(success: false));
  }

  void _finish({required bool success}) {
    _timer?.cancel();
    _detach();
    _releaseSlot();
    if (!mounted) return;
    if (success) {
      setState(() => _ready = _fadeIn = true);
      return;
    }
    _provider.evict();
    _attempt++;
    if (_attempt >= _maxAttempts) {
      setState(() => _failed = true);
      return;
    }
    // 0.8s, 1.6s, 3.2s (+ jitter so a whole grid doesn't retry in lockstep).
    final delay = Duration(milliseconds: 800 * (1 << (_attempt - 1)) + Random().nextInt(400));
    _timer = Timer(delay, () {
      if (mounted) _load();
    });
  }

  void _detach() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _listener = null;
    _stream = null;
  }

  void _releaseSlot() {
    if (!_holdingSlot) return;
    _holdingSlot = false;
    _LoadGate.release();
  }

  @override
  void dispose() {
    NetImage.retryEpoch.removeListener(_onRetryEpoch);
    _timer?.cancel();
    _detach();
    _releaseSlot();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.fallback;
    if (!_ready) return const ColoredBox(color: BColors.divider);
    final image = Image(
      image: _provider,
      fit: widget.fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => widget.fallback,
    );
    if (!_fadeIn || MediaQuery.disableAnimationsOf(context)) return image;
    return ColoredBox(color: BColors.divider, child: image.animate().fadeIn(duration: 220.ms));
  }
}

// ============================================================
// Price / rating
// ============================================================

class PriceText extends StatelessWidget {
  const PriceText(this.price, {super.key, this.oldPrice, this.size = 15, this.maxPrice});

  final double price;
  final double? maxPrice;
  final double? oldPrice;
  final double size;

  @override
  Widget build(BuildContext context) {
    final showOld = oldPrice != null && oldPrice! > price;
    final range = maxPrice != null && maxPrice! > price;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 6,
      children: [
        Text(
          range ? '${peso(price)} – ${peso(maxPrice!)}' : peso(price),
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: BColors.cta, height: 1.1),
        ),
        if (showOld && !range)
          Text(
            peso(oldPrice!),
            style: TextStyle(
              fontSize: size * 0.72,
              color: BColors.faint,
              decoration: TextDecoration.lineThrough,
              decorationColor: BColors.faint,
              height: 1.4,
            ),
          ),
      ],
    );
  }
}

class StarRow extends StatelessWidget {
  const StarRow(this.rating, {super.key, this.size = 13});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final fill = rating - i;
        final icon = fill >= 0.75 ? Icons.star_rounded : (fill >= 0.25 ? Icons.star_half_rounded : Icons.star_outline_rounded);
        return Icon(icon, size: size, color: BColors.star);
      }),
    );
  }
}

class DiscountBadge extends StatelessWidget {
  const DiscountBadge(this.percent, {super.key});

  final int percent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(color: BColors.ctaSurface, borderRadius: BorderRadius.circular(2)),
        child: Text('-$percent%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: BColors.cta)),
      );
}

// ============================================================
// Product card
// ============================================================

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final (low, high) = p.priceRange;
    final rating = p.rating;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(BRadius.tile), boxShadow: softShadow(0.04)),
      child: Material(
        color: BColors.surface,
        borderRadius: BorderRadius.circular(BRadius.tile),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Inset, separately rounded image — the card reads as a frame.
            Padding(
              padding: const EdgeInsets.fromLTRB(_kCardInset, _kCardInset, _kCardInset, 0),
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(BRadius.tile - _kCardInset + 2),
                  child: Stack(fit: StackFit.expand, children: [
                    NetImage(p.primaryImage, fallbackIcon: categoryIcon(p.category)),
                    if (p.discountPercent > 0 && !p.isSoldOut) Positioned(top: 8, left: 8, child: DiscountRibbon(p.discountPercent)),
                    Positioned(top: 4, right: 4, child: _WishHeart(productId: p.id)),
                    if (p.isSoldOut)
                      Container(
                        color: Colors.white.withValues(alpha: 0.55),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: BColors.ink.withValues(alpha: 0.82), borderRadius: BorderRadius.circular(20)),
                          child: const Text('Sold out', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  height: 34,
                  child: Text(p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w500, color: BColors.ink)),
                ),
                const SizedBox(height: 6),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(pesoCompact(low), maxLines: 1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: BColors.cta, height: 1.1)),
                  if (high > low) const Text(' +', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: BColors.cta)),
                  if (p.oldPrice != null && p.oldPrice! > low && high == low) ...[
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        pesoCompact(p.oldPrice!),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: const TextStyle(fontSize: 11, color: BColors.faint, decoration: TextDecoration.lineThrough, decorationColor: BColors.faint),
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 7),
                Row(children: [
                  const Icon(Icons.storefront_rounded, size: 13, color: BColors.faint),
                  const SizedBox(width: 3),
                  Expanded(child: Text(p.seller, maxLines: 1, overflow: TextOverflow.ellipsis, style: BText.tiny)),
                  if (rating != null && p.reviewCount > 0) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.star_rounded, size: 13, color: BColors.star),
                    Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: BColors.ink)),
                  ],
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Inset of the image inside a [ProductCard].
const double _kCardInset = 6;

/// Pill chip for real markdowns on product imagery.
class DiscountRibbon extends StatelessWidget {
  const DiscountRibbon(this.percent, {super.key});

  final int percent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: BColors.cta, borderRadius: BorderRadius.circular(20)),
        child: Text('-$percent%', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
      );
}

/// Quick-save heart on product imagery (optimistic, rolls back on error).
class _WishHeart extends StatelessWidget {
  const _WishHeart({required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context) {
    final store = BuyerStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final fav = store.isFavorite(productId);
        return Semantics(
          button: true,
          label: fav ? 'Remove from wishlist' : 'Save to wishlist',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              HapticFeedback.lightImpact();
              final error = await store.toggleFavorite(productId);
              if (error != null && context.mounted) showToast(context, error, error: true);
            },
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), shape: BoxShape.circle, boxShadow: softShadow(0.08)),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                  child: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      key: ValueKey(fav), size: 17, color: fav ? BColors.cta : BColors.muted),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

const double kGridPadding = 12;

/// Grid delegate shared by every product grid so cards line up everywhere.
/// Pair with [kGridPadding] around the sliver.
SliverGridDelegate productGridDelegate(BuildContext context, {double? width}) {
  width ??= MediaQuery.sizeOf(context).width;
  final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
  const spacing = 10.0;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    mainAxisSpacing: spacing,
    crossAxisSpacing: spacing,
    mainAxisExtent: (width - kGridPadding * 2 - spacing * (columns - 1)) / columns + 100, // inset image (w - 12) + 6 top + text block
  );
}

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(BRadius.tile),
        child: const ColoredBox(
          color: BColors.surface,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
                padding: EdgeInsets.fromLTRB(_kCardInset, _kCardInset, _kCardInset, 0),
                child: AspectRatio(aspectRatio: 1, child: SkeletonBox(radius: BRadius.tile - _kCardInset + 2))),
            Padding(
              padding: EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SkeletonBox(height: 12),
                SizedBox(height: 6),
                SkeletonBox(height: 12, width: 80),
                SizedBox(height: 10),
                SkeletonBox(height: 15, width: 64),
              ]),
            ),
          ]),
        ),
      );
}

// ============================================================
// States
// ============================================================

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.height, this.width, this.radius = 3});

  final double? height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final disableMotion = MediaQuery.disableAnimationsOf(context);
    final box = Container(
      height: height,
      width: width,
      decoration: BoxDecoration(color: const Color(0xFFE9ECF1), borderRadius: BorderRadius.circular(radius)),
    );
    if (disableMotion) return box;
    return box.animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.6));
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: BColors.brandSurface, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: BColors.brand),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: BText.section),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, textAlign: TextAlign.center, style: BText.small),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              ElevatedButton(onPressed: onAction, style: BButtons.brand(height: 42), child: Text(actionLabel!)),
            ],
          ]),
        ),
      );
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Couldn\'t load this',
        message: message,
        actionLabel: 'Try again',
        onAction: onRetry,
      );
}

/// Thin inline notice (warnings in cart / checkout).
class Notice extends StatelessWidget {
  const Notice(this.message, {super.key, this.tone = NoticeTone.warning, this.action});

  final String message;
  final NoticeTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (tone) {
      NoticeTone.warning => (BColors.warningSurface, BColors.warning, Icons.info_outline_rounded),
      NoticeTone.error => (BColors.errorSurface, BColors.error, Icons.error_outline_rounded),
      NoticeTone.info => (BColors.brandSurface, BColors.brand, Icons.info_outline_rounded),
    };
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Icon(icon, size: 16, color: fg),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: TextStyle(fontSize: 12.5, color: fg, height: 1.3))),
        if (action != null) action!,
      ]),
    );
  }
}

enum NoticeTone { warning, error, info }

// ============================================================
// Controls
// ============================================================

class QtyStepper extends StatelessWidget {
  const QtyStepper({super.key, required this.value, required this.onChanged, this.max, this.min = 1});

  final int value;
  final int min;
  final int? max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canDec = value > min;
    final canInc = max == null || value < max!;
    Widget btn(IconData icon, bool enabled, int next, String label) => Semantics(
          button: true,
          label: label,
          child: InkWell(
            onTap: enabled ? () => onChanged(next) : null,
            child: SizedBox(
              width: 32,
              height: 30,
              child: Icon(icon, size: 16, color: enabled ? BColors.ink : BColors.border),
            ),
          ),
        );
    return Container(
      decoration: BoxDecoration(border: Border.all(color: BColors.border), borderRadius: BorderRadius.circular(2)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn(Icons.remove, canDec, value - 1, 'Decrease quantity'),
        Container(
          width: 40,
          height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(border: Border.symmetric(vertical: BorderSide(color: BColors.border))),
          child: Text('$value', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        ),
        btn(Icons.add, canInc, value + 1, 'Increase quantity'),
      ]),
    );
  }
}

/// Square checkbox in brand color, 44px tap target.
class BCheck extends StatelessWidget {
  const BCheck({super.key, required this.value, required this.onChanged, this.semanticLabel});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        checked: value,
        label: semanticLabel,
        child: InkResponse(
          onTap: () => onChanged(!value),
          radius: 22,
          child: SizedBox(
            width: 40,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: value ? BColors.brand : Colors.white,
                  border: Border.all(color: value ? BColors.brand : BColors.faint, width: 1.4),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: value ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
            ),
          ),
        ),
      );
}

/// Section with a white background on the grey page — the standard
/// commerce "stacked panels" layout instead of floating cards.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.margin = const EdgeInsets.only(bottom: 8)});

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) => Container(color: BColors.surface, padding: padding, margin: margin, child: child);
}

void showToast(BuildContext context, String message, {bool error = false, SnackBarAction? action}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    behavior: SnackBarBehavior.floating,
    backgroundColor: error ? BColors.error : BColors.ink,
    duration: Duration(milliseconds: action != null ? 4000 : 2200),
    action: action,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BRadius.md)),
  ));
}

Future<bool> confirmDialog(BuildContext context,
    {required String title, required String message, required String confirmLabel, String cancelLabel = 'Cancel', bool destructive = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BRadius.md)),
      title: Text(title, style: BText.title),
      content: Text(message, style: BText.body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancelLabel, style: const TextStyle(color: BColors.muted))),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel, style: TextStyle(color: destructive ? BColors.error : BColors.cta, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Small thumbnail for order lines (orders don't carry images — the
/// category icon keeps rows scannable).
class CategoryThumb extends StatelessWidget {
  const CategoryThumb({super.key, this.category, this.image, this.size = 64});

  final String? category;
  final String? image;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(BRadius.sm),
        child: SizedBox(
          width: size,
          height: size,
          child: image != null
              ? NetImage(image, fallbackIcon: categoryIcon(category))
              : Container(color: BColors.divider, child: Icon(categoryIcon(category), color: BColors.faint, size: size * 0.42)),
        ),
      );
}

/// Order status text color (status label at the top-right of order cards).
Color orderStatusColor(String status) {
  switch (status) {
    case OrderStatus.delivered:
    case 'Returned':
      return BColors.success;
    case OrderStatus.cancelled:
      return BColors.muted;
    case 'To Return':
      return BColors.warning;
    default:
      return BColors.brand;
  }
}
