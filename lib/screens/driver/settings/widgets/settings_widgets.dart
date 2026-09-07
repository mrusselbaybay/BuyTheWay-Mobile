import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../driver_theme.dart';
import '../../widgets/driver_shared_widgets.dart';

// ============================================================
// SETTINGS MODULE — SHARED WIDGETS & FORMATTING
// ------------------------------------------------------------
// Every screen under lib/screens/driver/settings/ is built from this
// small set of primitives (grouped list cards, nav/switch rows, form
// fields, toasts) instead of each screen hand-rolling its own card/row
// styling. That's what keeps the settings hub and its sub-pages reading
// as one consistent system rather than five different "settings looks".
// ============================================================

/// Formatting + calculation helpers shared across the settings screens —
/// pulled out of what used to be private methods on one giant State class
/// so every settings screen (not just one) can use them.
class SettingsFormat {
  SettingsFormat._();

  static const _fullMonths = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String dateLong(DateTime d) {
    final local = d.toLocal();
    return '${_fullMonths[local.month - 1]} ${local.day}, ${local.year}';
  }

  static String dateShort(DateTime d) {
    final local = d.toLocal();
    return '${_shortMonths[local.month - 1]} ${local.day}, ${local.year}';
  }

  static String dateTime(DateTime d) {
    final local = d.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${dateShort(local)} · $h:$m $period';
  }

  static String isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static int? ageFor(DateTime? birthday) {
    if (birthday == null) return null;
    final now = DateTime.now();
    int years = now.year - birthday.year;
    if (now.month < birthday.month || (now.month == birthday.month && now.day < birthday.day)) {
      years -= 1;
    }
    return years;
  }

  static String maskedEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final user = parts[0];
    final visible = user.substring(0, user.length < 2 ? user.length : 2);
    final masked = '*' * (user.length - visible.length).clamp(1, 20);
    return '$visible$masked@${parts[1]}';
  }

  static String roleLabel(String role) => role == 'courier' ? 'Courier' : 'Driver';

  static String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Every success/error/info message across the settings module goes
/// through this one shared top-of-screen toast (backed by the app's
/// existing [DriverTopNotification]) instead of a plain SnackBar — one
/// consistent feedback style for the whole module.
class SettingsToast {
  SettingsToast._();

  static void success(BuildContext context, String message) =>
      DriverTopNotification.show(context, message: message);

  static void error(BuildContext context, String message) => DriverTopNotification.show(
        context,
        message: message,
        icon: Icons.error_outline_rounded,
        accent: DriverColors.error,
      );

  static void info(BuildContext context, String message) => DriverTopNotification.show(
        context,
        message: message,
        icon: Icons.info_outline_rounded,
        accent: DriverColors.primary,
      );
}

/// A generic silhouette placeholder avatar (never borrowed initials) with
/// an optional "edit photo" camera badge.
class SettingsAvatar extends StatelessWidget {
  final double size;
  final bool showCameraBadge;
  final VoidCallback? onTap;
  final Color background;
  final Color foreground;

  /// Public URL of the uploaded profile picture (DriverAccount.avatarUrl).
  /// Null/empty, or a URL that fails to load, falls back to the generic
  /// person glyph.
  final String? imageUrl;

  /// Locally cropped bytes shown immediately after an upload, before the
  /// (cache-busted) network image would have had a chance to refresh —
  /// takes precedence over [imageUrl] while set.
  final Uint8List? imageBytes;

  /// Dims the avatar and overlays a spinner while an upload is in flight.
  final bool busy;

  const SettingsAvatar({
    super.key,
    this.size = 56,
    this.showCameraBadge = false,
    this.onTap,
    this.background = DriverColors.primarySurface,
    this.foreground = DriverColors.primary,
    this.imageUrl,
    this.imageBytes,
    this.busy = false,
  });

  Widget _photo() {
    if (imageBytes != null) {
      return Image.memory(imageBytes!, fit: BoxFit.cover, gaplessPlayback: true);
    }
    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.person_rounded, color: foreground, size: size * 0.52),
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Center(
              child: SizedBox(
                width: size * 0.3,
                height: size * 0.3,
                child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = imageBytes != null || (imageUrl != null && imageUrl!.isNotEmpty);
    final circle = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
        border: Border.all(color: foreground.withOpacity(0.3), width: 1.4),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasPhoto)
            _photo()
          else
            Icon(Icons.person_rounded, color: foreground, size: size * 0.52),
          if (busy)
            Container(
              color: Colors.black.withOpacity(0.35),
              alignment: Alignment.center,
              child: SizedBox(
                width: size * 0.3,
                height: size * 0.3,
                child: const CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
              ),
            ),
        ],
      ),
    );
    if (!showCameraBadge) return circle;
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          circle,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: size * 0.34,
              height: size * 0.34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: DriverColors.primary, width: 1.4),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Icon(Icons.camera_alt_rounded, size: size * 0.17, color: DriverColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact, tappable profile summary shown at the top of the Settings hub
/// — replaces the old full-bleed gradient hero (that visual belongs to the
/// Account tab, which already shows it) with something scannable that
/// opens straight into Personal Information.
class SettingsProfileSummary extends StatelessWidget {
  final String name;
  final String email;
  final String status;
  final String role;
  final DateTime memberSince;
  final VoidCallback onTap;

  /// Profile picture URL — see [SettingsAvatar.imageUrl].
  final String? avatarUrl;

  const SettingsProfileSummary({
    super.key,
    required this.name,
    required this.email,
    required this.status,
    required this.role,
    required this.memberSince,
    required this.onTap,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final active = status.toLowerCase() == 'active';
    final statusColor = active ? DriverColors.success : DriverColors.warning;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: DriverColors.border),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              SettingsAvatar(size: 52, imageUrl: avatarUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: DriverColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(email, style: DriverText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, size: 6, color: statusColor),
                              const SizedBox(width: 5),
                              Text(SettingsFormat.capitalize(status), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: statusColor)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$role · since ${SettingsFormat.dateShort(memberSince)}',
                            style: DriverText.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small uppercase eyebrow label above each grouped section.
class SettingsSectionLabel extends StatelessWidget {
  final String label;
  final bool danger;
  const SettingsSectionLabel(this.label, {super.key, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: danger ? DriverColors.error : DriverColors.textSecondary),
      ),
    );
  }
}

/// One flat, bordered (no heavy shadow) rounded container holding a list
/// of rows with hairline dividers between them — the single "grouped
/// list" style every settings section reuses, instead of one differently
/// styled card per section.
class SettingsGroupCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final double dividerIndent;

  const SettingsGroupCard({super.key, required this.children, this.padding, this.dividerIndent = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DriverColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) Divider(height: 1, indent: dividerIndent, endIndent: 16, color: DriverColors.border),
          ],
        ],
      ),
    );
  }
}

/// One row inside a [SettingsGroupCard]: icon, title, optional subtitle,
/// optional trailing value, chevron when [onTap] is set.
class SettingsNavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final Color? iconColor;
  final Color? titleColor;
  final VoidCallback? onTap;

  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.iconColor,
    this.titleColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? DriverColors.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: titleColor ?? DriverColors.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: DriverText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            if (trailingText != null) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Text(trailingText!, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: DriverColors.textSecondary, fontWeight: FontWeight.w600)),
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 19, color: Colors.grey[400]),
            ],
          ],
        ),
      ),
    );
  }
}

/// A toggle row for the Preferences section — fires a light haptic tick
/// on every change so flipping a switch reads as an immediate, physical
/// action rather than a silent state flip.
class SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? iconColor;

  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? DriverColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: DriverColors.textPrimary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: DriverText.caption),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: DriverColors.primary,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

/// Like [SettingsSwitchTile], but the switch flips (and its subtitle
/// updates) the instant it's tapped — before [onChanged]'s async work
/// resolves — so the toggle always feels immediate even while a network
/// write is in flight. If the parent later reports a different [value]
/// (e.g. a failed write that rolled back), the switch animates to match.
///
/// Only the switch itself rebuilds on tap; the parent list is not
/// disturbed until it chooses to act on [onChanged].
class SettingsOptimisticSwitchTile extends StatefulWidget {
  final IconData icon;
  final String title;

  /// Subtitle for the given on/off state — evaluated against the tile's
  /// own optimistic state so the caption tracks the thumb exactly.
  final String Function(bool on)? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? iconColor;

  const SettingsOptimisticSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.iconColor,
  });

  @override
  State<SettingsOptimisticSwitchTile> createState() => _SettingsOptimisticSwitchTileState();
}

class _SettingsOptimisticSwitchTileState extends State<SettingsOptimisticSwitchTile> {
  late bool _on = widget.value;

  @override
  void didUpdateWidget(SettingsOptimisticSwitchTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reconcile only when the parent's value actually moved and disagrees
    // with what we're showing (a rollback or an external change) — a
    // parent rebuild that already matches our optimistic state is a no-op.
    if (widget.value != oldWidget.value && widget.value != _on) {
      setState(() => _on = widget.value);
    }
  }

  void _handle(bool next) {
    HapticFeedback.selectionClick();
    setState(() => _on = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.iconColor ?? DriverColors.primary;
    final subtitle = widget.subtitle?.call(_on);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(widget.icon, size: 17, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: DriverColors.textPrimary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: DriverText.caption),
                ],
              ],
            ),
          ),
          Switch(
            value: _on,
            activeThumbColor: DriverColors.primary,
            onChanged: _handle,
          ),
        ],
      ),
    );
  }
}

/// Read-only label/value row — used by the Vehicle & Documents page.
class SettingsInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const SettingsInfoRow({super.key, required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 18, color: DriverColors.primary),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: DriverColors.textSecondary, fontWeight: FontWeight.w500))),
          Flexible(
            child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor ?? DriverColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// Small "here's why" banner, used above read-only sections.
class SettingsInfoNote extends StatelessWidget {
  final String message;
  const SettingsInfoNote(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: DriverColors.primarySurface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: DriverColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 11.5, color: DriverColors.textSecondary, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

/// Inline error banner with a Retry action — used when the PSGC address
/// lookups fail to load.
class SettingsErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const SettingsErrorBanner({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: DriverColors.errorSurface, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 15, color: DriverColors.error),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 11.5, color: DriverColors.error, fontWeight: FontWeight.w600))),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('Retry', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ---- Form fields (Personal Information / Home Address page) ----

class SettingsFieldLabel extends StatelessWidget {
  final String text;
  const SettingsFieldLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text, style: DriverText.label);
}

class SettingsFieldError extends StatelessWidget {
  final String? error;
  const SettingsFieldError(this.error, {super.key});
  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(error!, style: const TextStyle(color: DriverColors.error, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class SettingsTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final String? error;
  final TextInputType? keyboardType;
  final int? maxLength;
  final String? hint;
  final TextCapitalization textCapitalization;

  const SettingsTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.enabled,
    this.error,
    this.keyboardType,
    this.maxLength,
    this.hint,
    this.textCapitalization = TextCapitalization.words,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsFieldLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          style: DriverText.body,
          decoration: InputDecoration(
            counterText: '',
            hintText: hint,
            filled: true,
            fillColor: enabled ? DriverColors.background : DriverColors.background.withOpacity(0.6),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: error != null ? DriverColors.error : Colors.transparent),
            ),
          ),
        ),
        SettingsFieldError(error),
      ],
    );
  }
}

class SettingsReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final String? note;
  final IconData? trailingIcon;
  const SettingsReadOnlyField({super.key, required this.label, required this.value, this.note, this.trailingIcon});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsFieldLabel(label),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: DriverColors.background.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Expanded(child: Text(value, style: DriverText.body)),
              if (trailingIcon != null) Icon(trailingIcon, size: 15, color: DriverColors.textSecondary),
            ],
          ),
        ),
        if (note != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(note!, style: DriverText.caption)),
      ],
    );
  }
}

class SettingsChoiceField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final bool enabled;
  final String? error;
  final ValueChanged<String?>? onChanged;

  const SettingsChoiceField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.enabled,
    this.error,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsFieldLabel(label),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: enabled ? DriverColors.background : DriverColors.background.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: error != null ? Border.all(color: DriverColors.error) : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: const Text('Select', style: DriverText.body),
              isExpanded: true,
              icon: enabled ? const Icon(Icons.keyboard_arrow_down_rounded, size: 18) : const SizedBox.shrink(),
              style: DriverText.body,
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
        SettingsFieldError(error),
      ],
    );
  }
}

class SettingsDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final bool enabled;
  final String? error;
  final VoidCallback? onTap;

  const SettingsDateField({super.key, required this.label, required this.value, required this.enabled, this.error, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsFieldLabel(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: enabled ? DriverColors.background : DriverColors.background.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
              border: error != null ? Border.all(color: DriverColors.error) : null,
            ),
            child: Row(
              children: [
                Expanded(child: Text(value != null ? SettingsFormat.dateShort(value!) : 'Select date', style: DriverText.body)),
                if (enabled) const Icon(Icons.calendar_today_rounded, size: 14, color: DriverColors.textSecondary),
              ],
            ),
          ),
        ),
        SettingsFieldError(error),
      ],
    );
  }
}

/// Cascading PSGC dropdown (province / municipality / barangay) — [items]
/// is the raw `{code, name}` list from ApiService.
class SettingsDropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<dynamic> items;
  final String valueField;
  final bool enabled;
  final bool loading;
  final String hint;
  final String? error;
  final ValueChanged<String?>? onChanged;

  const SettingsDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    this.valueField = 'code',
    required this.enabled,
    this.loading = false,
    this.hint = 'Select',
    this.error,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && !loading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsFieldLabel(label),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: active ? DriverColors.background : DriverColors.background.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: error != null ? Border.all(color: DriverColors.error) : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text(hint, style: DriverText.body, overflow: TextOverflow.ellipsis),
              isExpanded: true,
              icon: active ? const Icon(Icons.keyboard_arrow_down_rounded, size: 18) : const SizedBox.shrink(),
              style: DriverText.body,
              items: items
                  .map((item) => DropdownMenuItem<String>(
                        value: (item[valueField] ?? '').toString(),
                        child: Text((item['name'] ?? '').toString(), overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: active ? onChanged : null,
            ),
          ),
        ),
        SettingsFieldError(error),
      ],
    );
  }
}

/// Sticky bottom Save/Cancel bar shown only while a settings sub-page is
/// in edit mode — thumb-reachable rather than buried mid-scroll, and
/// visually pinned above the safe area.
class SettingsSaveBar extends StatelessWidget {
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final String saveLabel;

  const SettingsSaveBar({super.key, required this.saving, required this.onCancel, required this.onSave, this.saveLabel = 'Save Changes'});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: DriverColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: saving ? null : onCancel,
                style: OutlinedButton.styleFrom(foregroundColor: DriverColors.textSecondary, side: const BorderSide(color: DriverColors.border), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: saving ? null : onSave,
                style: ElevatedButton.styleFrom(backgroundColor: DriverColors.primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text(saveLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
