import 'package:flutter/material.dart';

import '../../driver/driver_theme.dart';
import '../widgets/buyer_widgets.dart';

// ============================================================
// Shared chrome for every buyer account / settings page — white app
// bar on the grey canvas, grouped cards, skeletons and empty states,
// so all of them read as one system (and match the Account tab).
// ============================================================

const kSettingsGap = SizedBox(height: 24);

AppBar settingsAppBar(String title, {PreferredSizeWidget? bottom, List<Widget>? actions, bool centerTitle = false, Color backgroundColor = Colors.white, Color foregroundColor = DriverColors.textPrimary}) => AppBar(
      backgroundColor: backgroundColor,
      surfaceTintColor: backgroundColor,
      centerTitle: centerTitle,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      foregroundColor: foregroundColor,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      bottom: bottom,
      actions: actions,
    );

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.title, required this.children, this.onRefresh, this.bottomBar, this.actions});

  final String title;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final Widget? bottomBar;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16, 18, 16, MediaQuery.paddingOf(context).bottom + 24),
      children: children,
    );
    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: settingsAppBar(title, actions: actions),
      body: onRefresh == null ? list : RefreshIndicator(color: DriverColors.primary, onRefresh: onRefresh!, child: list),
      bottomNavigationBar: bottomBar,
    );
  }
}

Widget settingsSpinner({Color color = DriverColors.primary}) => SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: color));

/// Card with a leading tile + text lines; used by the skeletons below.
class RowsSkeleton extends StatelessWidget {
  const RowsSkeleton({super.key, this.count = 3, this.tile = 40});
  final int count;
  final double tile;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: DriverColors.border)),
        child: Column(children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                SkeletonBox(width: tile, height: tile, radius: 12),
                const SizedBox(width: 14),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SkeletonBox(width: 150, height: 12), SizedBox(height: 7), SkeletonBox(width: 90, height: 10)])),
              ]),
            ),
        ]),
      );
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.icon, required this.title, this.message, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: DriverColors.border)),
        child: Column(children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: DriverColors.primarySurface, shape: BoxShape.circle),
            child: Icon(icon, size: 28, color: DriverColors.primary),
          ),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: DriverColors.textPrimary)),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(message!, textAlign: TextAlign.center, style: DriverText.caption.copyWith(height: 1.4)),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(backgroundColor: DriverColors.primary, minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 22)),
              child: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      );
}

class LoadMore extends StatelessWidget {
  const LoadMore({super.key, required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Center(
          child: loading
              ? settingsSpinner()
              : TextButton(onPressed: onTap, child: const Text('Load more', style: TextStyle(fontWeight: FontWeight.w700, color: DriverColors.primary))),
        ),
      );
}

/// Read-only bullet used for "what others see" style explanations.
class SettingsBullet extends StatelessWidget {
  const SettingsBullet(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 5, color: DriverColors.primary)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: DriverText.body.copyWith(height: 1.4))),
        ]),
      );
}

/// Small status pill (verified, default, primary, …).
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, this.color, {super.key, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}

/// Rounded store logo that is really fetched ([logo] from the API) and
/// falls back to a storefront glyph while loading, when missing, or on error.
class StoreAvatar extends StatelessWidget {
  const StoreAvatar({super.key, this.logo, this.size = 44, this.muted = false});
  final String? logo;
  final double size;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = muted ? DriverColors.textSecondary : DriverColors.primary;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(size * 0.3), border: Border.all(color: DriverColors.border)),
      child: ColorFiltered(
        // Blocked shops read as "dimmed" without hiding who they are.
        colorFilter: muted ? const ColorFilter.mode(Colors.grey, BlendMode.saturation) : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
        child: NetImage(logo, fallbackIcon: Icons.storefront_rounded),
      ),
    );
  }
}

/// Rounded-tile icon used as a row/section leading element.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.color = DriverColors.primary, this.size = 34});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(size * 0.3)),
        child: Icon(icon, size: size * 0.5, color: color),
      );
}
