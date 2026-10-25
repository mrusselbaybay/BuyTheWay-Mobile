// ============================================================================
// BuyTheWay Design System — Glassmorphism Edition
// ----------------------------------------------------------------------------
// A self-contained set of reusable, animated, glass-styled primitives used
// across the auth flow (and reusable anywhere else in the app). Every
// interactive element ships with a small, purposeful micro-interaction:
// press-scale on buttons, focus-glow on fields, animated check-pop on
// uploads, and a spring-y sliding indicator on steps.
// ============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Palette — teal stays the non-negotiable primary accent, everything else
// exists to make the glass panels legible and the states (error/success)
// unambiguous.
// ---------------------------------------------------------------------------
class AppColors {
  AppColors._();

  // Teal — primary
  static const Color teal50 = Color(0xFFEFFCFA);
  static const Color teal100 = Color(0xFFCCFBF1);
  static const Color teal300 = Color(0xFF5EEAD4);
  static const Color teal400 = Color(0xFF2DD4BF);
  static const Color teal500 = Color(0xFF14B8A6);
  static const Color teal600 = Color(0xFF0D9488);
  static const Color teal700 = Color(0xFF0F766E);
  static const Color teal900 = Color(0xFF042F2E);

  // Supporting accent used sparingly in background blobs for depth
  static const Color cyan400 = Color(0xFF22D3EE);
  static const Color emerald400 = Color(0xFF34D399);

  // Neutrals
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  // Status
  static const Color errorRed = Color(0xFFEF4444);
  static const Color successGreen = Color(0xFF10B981);
}

// ---------------------------------------------------------------------------
// Animated gradient + floating blurred blobs backdrop. This is what gives
// the frosted-glass panels something worth refracting — a flat color behind
// glass just looks like grey plastic.
// ---------------------------------------------------------------------------
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.child});
  final Widget child;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 14))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.teal900, AppColors.teal700, Color(0xFF0B4A45)],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value * 6.28318;
            return Stack(
              children: [
                _blob(
                  color: AppColors.teal400,
                  size: 260,
                  dx: 0.15 + 0.10 * (0.5 + 0.5 * -1 * (t.abs() % 1)),
                  offset: Offset(80 * (1 + 0.4 * (t / 6.28318)) - 40,
                      -60 + 30 * (t / 6.28318)),
                ),
                _blob(
                  color: AppColors.cyan400,
                  size: 220,
                  dx: 0.7,
                  offset: Offset(20 + 20 * (0.5 - (t / 6.28318)), 140),
                ),
                _blob(
                  color: AppColors.emerald400,
                  size: 200,
                  dx: 0.4,
                  offset: Offset(-30, 420 + 20 * (t / 6.28318)),
                ),
              ],
            );
          },
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
          child: Container(color: Colors.transparent),
        ),
        widget.child,
      ],
    );
  }

  Widget _blob(
      {required Color color,
      required double size,
      required double dx,
      required Offset offset}) {
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.35),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GlassPanel — the core frosted-glass container. Wraps BackdropFilter with
// a translucent gradient fill + hairline border + soft shadow so it reads
// as "glass" rather than "grey box".
// ---------------------------------------------------------------------------
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 24,
    this.blur = 22,
    this.opacity = 0.55,
    this.tint = Colors.white,
    this.borderOpacity = 0.5,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;
  final double opacity;
  final Color tint;
  final double borderOpacity;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tint.withOpacity(opacity),
                tint.withOpacity(opacity * 0.65),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(borderOpacity),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.teal900.withOpacity(0.18),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PressableScale — generic micro-interaction wrapper: scales down slightly
// on press for tactile feedback, used by buttons/cards/tiles alike.
// ---------------------------------------------------------------------------
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleDown = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _down = false),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scaleDown : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GradientButton — primary CTA. Teal gradient fill, press-scale, animated
// loading state (spinner cross-fades in), subtle glow shadow.
// ---------------------------------------------------------------------------
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return PressableScale(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: disabled
                ? [AppColors.slate300, AppColors.slate400]
                : [AppColors.teal400, AppColors.teal600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: disabled
              ? []
              : [
                  BoxShadow(
                    color: AppColors.teal500.withOpacity(0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: loading
                ? const SizedBox(
                    key: ValueKey('spinner'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white),
                  )
                : Row(
                    key: const ValueKey('label'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// OutlineActionButton — secondary action, glass-outlined.
// ---------------------------------------------------------------------------
class OutlineActionButton extends StatelessWidget {
  const OutlineActionButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onPressed,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.5),
          border: Border.all(color: AppColors.teal600.withOpacity(0.4)),
        ),
        child: Text(label,
            style: const TextStyle(
                color: AppColors.teal700,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LabeledField — glass text field with animated focus glow + shake-free
// inline error transition.
// ---------------------------------------------------------------------------
class LabeledField extends StatefulWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.required = false,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
    this.error,
    this.maxLength,
  });

  final String label;
  final TextEditingController controller;
  final bool required;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final String? error;
  final int? maxLength;

  @override
  State<LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<LabeledField> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = (widget.error ?? '').isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(widget.label, widget.required),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withOpacity(0.55),
            border: Border.all(
              color: hasError
                  ? AppColors.errorRed
                  : (_focused ? AppColors.teal500 : Colors.white.withOpacity(0.6)),
              width: _focused || hasError ? 1.6 : 1,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: AppColors.teal400.withOpacity(0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            obscureText: widget.obscure,
            keyboardType: widget.keyboardType,
            maxLength: widget.maxLength,
            inputFormatters: widget.keyboardType == TextInputType.number
                ? [FilteringTextInputFormatter.digitsOnly]
                : null,
            style: const TextStyle(fontSize: 14, color: AppColors.slate800),
            decoration: InputDecoration(
              counterText: '',
              hintText: widget.hint,
              hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 13),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: InputBorder.none,
              suffixIcon: widget.suffix,
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 5, left: 2),
                  child: Text(widget.error!,
                      style: const TextStyle(
                          color: AppColors.errorRed, fontSize: 11.5)),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

Widget _fieldLabel(String label, bool required) {
  return RichText(
    text: TextSpan(
      style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: AppColors.slate700),
      children: [
        TextSpan(text: label),
        if (required)
          const TextSpan(
              text: ' *', style: TextStyle(color: AppColors.teal600)),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// LabeledDropdown — glass dropdown, matches LabeledField chrome exactly.
// ---------------------------------------------------------------------------
class LabeledDropdown extends StatelessWidget {
  const LabeledDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.onChanged,
    this.required = false,
    this.value,
    this.displayItems,
    this.hint,
    this.enabled = true,
  });

  final String label;
  final bool required;
  final String? value;
  final List<String> items;
  final List<String>? displayItems;
  final String? hint;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label, required),
        const SizedBox(height: 6),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: enabled ? 1 : 0.55,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withOpacity(0.55),
              border: Border.all(color: Colors.white.withOpacity(0.6)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: value,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.teal600),
                borderRadius: BorderRadius.circular(14),
                hint: Text(hint ?? 'Select',
                    style:
                        const TextStyle(color: AppColors.slate400, fontSize: 13)),
                style: const TextStyle(fontSize: 14, color: AppColors.slate800),
                items: [
                  for (int i = 0; i < items.length; i++)
                    DropdownMenuItem(
                      value: items[i],
                      child: Text(
                          displayItems != null && i < displayItems!.length
                              ? displayItems![i]
                              : items[i]),
                    ),
                ],
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// LabeledDateField — glass date picker trigger, opens a teal-themed picker.
// ---------------------------------------------------------------------------
class LabeledDateField extends StatelessWidget {
  const LabeledDateField({
    super.key,
    required this.label,
    required this.onChanged,
    this.required = false,
    this.value,
    this.error,
  });

  final String label;
  final bool required;
  final DateTime? value;
  final String? error;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasError = (error ?? '').isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label, required),
        const SizedBox(height: 6),
        PressableScale(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime(now.year - 20),
              firstDate: DateTime(1920),
              lastDate: now,
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.teal600,
                    onPrimary: Colors.white,
                    onSurface: AppColors.slate800,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) onChanged(picked);
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withOpacity(0.55),
              border: Border.all(
                  color: hasError
                      ? AppColors.errorRed
                      : Colors.white.withOpacity(0.6)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 16, color: AppColors.teal600),
                const SizedBox(width: 10),
                Text(
                  value == null
                      ? 'Select date'
                      : '${value!.month}/${value!.day}/${value!.year}',
                  style: TextStyle(
                      fontSize: 14,
                      color: value == null
                          ? AppColors.slate400
                          : AppColors.slate800),
                ),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 2),
            child: Text(error!,
                style: const TextStyle(color: AppColors.errorRed, fontSize: 11.5)),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// StepIndicator — glass track with an animated teal pill that slides/grows
// between steps, plus a subtle pulse on the active dot.
// ---------------------------------------------------------------------------
class StepIndicator extends StatelessWidget {
  const StepIndicator({super.key, required this.total, required this.currentIndex});
  final int total;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final safeIndex = currentIndex.clamp(0, total - 1);
    return Row(
      children: List.generate(total, (i) {
        final active = i <= safeIndex;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: active
                    ? AppColors.teal500
                    : Colors.white.withOpacity(0.45),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: AppColors.teal400.withOpacity(0.5),
                          blurRadius: 6,
                        )
                      ]
                    : null,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// MessageBanner — animated slide+fade in/out for error/success text, glass
// pill background so it doesn't look like a bare system alert.
// ---------------------------------------------------------------------------
class MessageBanner extends StatelessWidget {
  const MessageBanner({super.key, this.error = '', this.success = ''});
  final String error;
  final String success;

  @override
  Widget build(BuildContext context) {
    final hasMsg = error.isNotEmpty || success.isNotEmpty;
    final isError = error.isNotEmpty;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SizeTransition(sizeFactor: anim, child: child),
      ),
      child: !hasMsg
          ? const SizedBox.shrink(key: ValueKey('empty'))
          : Padding(
              key: ValueKey(isError ? error : success),
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: (isError ? AppColors.errorRed : AppColors.successGreen)
                      .withOpacity(0.12),
                  border: Border.all(
                    color:
                        (isError ? AppColors.errorRed : AppColors.successGreen)
                            .withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isError
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 16,
                      color: isError ? AppColors.errorRed : AppColors.successGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isError ? error : success,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isError
                              ? AppColors.errorRed
                              : AppColors.successGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// UploadTile — glass dropzone-style tile. Idle state invites a tap; once
// uploaded, an animated check badge pops in and the tile shifts to a
// success tint, with the filename sliding in beneath.
// ---------------------------------------------------------------------------
class UploadTile extends StatelessWidget {
  const UploadTile({
    super.key,
    required this.label,
    required this.uploaded,
    required this.onTap,
    this.required = false,
    this.fileName,
  });

  final String label;
  final bool required;
  final bool uploaded;
  final String? fileName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: uploaded
              ? AppColors.successGreen.withOpacity(0.10)
              : Colors.white.withOpacity(0.5),
          border: Border.all(
            color: uploaded
                ? AppColors.successGreen.withOpacity(0.4)
                : AppColors.teal400.withOpacity(0.35),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: uploaded
                    ? AppColors.successGreen.withOpacity(0.18)
                    : AppColors.teal500.withOpacity(0.14),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (c, a) =>
                    ScaleTransition(scale: a, child: c),
                child: Icon(
                  uploaded
                      ? Icons.check_circle_rounded
                      : Icons.cloud_upload_outlined,
                  key: ValueKey(uploaded),
                  color: uploaded ? AppColors.successGreen : AppColors.teal600,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate800),
                      children: [
                        TextSpan(text: label),
                        if (required)
                          const TextSpan(
                              text: ' *',
                              style: TextStyle(color: AppColors.teal600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    uploaded ? (fileName ?? 'Uploaded') : 'Tap to upload · JPG, PNG or PDF · Max 10MB',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: uploaded ? AppColors.successGreen : AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.slate300, size: 20),
          ],
        ),
      ),
    );
  }
}