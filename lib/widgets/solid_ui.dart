// ============================================================================
// Solid UI kit — flat, no-gradient primitives for the Login / Sign Up
// screens. Deliberately separate from the glass/gradient kit in common.dart
// (still used by the driver app's own auth screens) so this redesign never
// touches that shared, still-in-use styling.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'brand_logo.dart';
import 'common.dart' show AppColors, PressableScale;

/// A field's chrome state, shared by every input in this kit so text
/// fields, dropdowns and the date picker read as one family.
class _FieldChrome extends StatelessWidget {
  const _FieldChrome({
    required this.child,
    required this.focused,
    required this.hasError,
    this.enabled = true,
  });

  final Widget child;
  final bool focused;
  final bool hasError;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = hasError
        ? AppColors.errorRed
        : (focused ? BrandColors.blue : Colors.transparent);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.55,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: focused ? Colors.white : AppColors.slate100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: child,
      ),
    );
  }
}

Widget _fieldLabel(String label, bool required) {
  return RichText(
    text: TextSpan(
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate700),
      children: [
        TextSpan(text: label),
        if (required)
          const TextSpan(text: ' *', style: TextStyle(color: BrandColors.blue)),
      ],
    ),
  );
}

Widget _fieldError(String? error) {
  final has = (error ?? '').isNotEmpty;
  return AnimatedSize(
    duration: const Duration(milliseconds: 140),
    child: !has
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline_rounded, size: 13, color: AppColors.errorRed),
              const SizedBox(width: 4),
              Flexible(
                child: Text(error!,
                    style: const TextStyle(color: AppColors.errorRed, fontSize: 12)),
              ),
            ]),
          ),
  );
}

// ---------------------------------------------------------------------------
// SolidField — flat filled text input with an optional leading icon.
// ---------------------------------------------------------------------------
class SolidField extends StatefulWidget {
  const SolidField({
    super.key,
    required this.label,
    required this.controller,
    this.required = false,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.icon,
    this.suffix,
    this.error,
    this.maxLength,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.onSubmitted,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final bool required;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final IconData? icon;
  final Widget? suffix;
  final String? error;
  final int? maxLength;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<SolidField> createState() => _SolidFieldState();
}

class _SolidFieldState extends State<SolidField> {
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
        const SizedBox(height: 7),
        _FieldChrome(
          focused: _focused,
          hasError: hasError,
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            obscureText: widget.obscure,
            keyboardType: widget.keyboardType,
            maxLength: widget.maxLength,
            autofillHints: widget.autofillHints,
            textCapitalization: widget.textCapitalization,
            textInputAction: widget.textInputAction,
            onSubmitted: widget.onSubmitted,
            inputFormatters: widget.inputFormatters ?? (widget.keyboardType == TextInputType.number
                ? [FilteringTextInputFormatter.digitsOnly]
                : null),
            style: const TextStyle(fontSize: 15, color: AppColors.slate900),
            decoration: InputDecoration(
              counterText: '',
              hintText: widget.hint,
              hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 14),
              prefixIcon: widget.icon == null
                  ? null
                  : Icon(widget.icon, size: 19,
                      color: _focused ? BrandColors.blue : AppColors.slate400),
              prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 22),
              contentPadding: EdgeInsets.symmetric(
                  horizontal: widget.icon == null ? 14 : 0, vertical: 14),
              border: InputBorder.none,
              suffixIcon: widget.suffix,
            ),
          ),
        ),
        _fieldError(widget.error),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SolidDropdown — matches SolidField's chrome exactly.
// ---------------------------------------------------------------------------
class SolidDropdown extends StatelessWidget {
  const SolidDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.onChanged,
    this.required = false,
    this.value,
    this.displayItems,
    this.hint,
    this.enabled = true,
    this.icon,
    this.error,
  });

  final String label;
  final bool required;
  final String? value;
  final List<String> items;
  final List<String>? displayItems;
  final String? hint;
  final bool enabled;
  final IconData? icon;
  final String? error;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasError = (error ?? '').isNotEmpty;
    final selectedValue = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label, required),
        const SizedBox(height: 7),
        LayoutBuilder(builder: (context, constraints) => MenuAnchor(
          style: MenuStyle(
            backgroundColor: const WidgetStatePropertyAll(Colors.white),
            elevation: const WidgetStatePropertyAll(4),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          ),
          menuChildren: [SizedBox(
            width: constraints.maxWidth,
            height: (items.length < 5 ? items.length : 5) * 48.0,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: items.length,
              itemBuilder: (context, index) => MenuItemButton(
                style: const ButtonStyle(padding: WidgetStatePropertyAll(EdgeInsets.zero)),
                onPressed: () => onChanged(items[index]),
                child: SizedBox(
                  height: 48,
                  width: constraints.maxWidth,
                  child: Align(alignment: Alignment.centerLeft, child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                    displayItems != null && index < displayItems!.length ? displayItems![index] : items[index],
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, color: AppColors.slate900),
                  ))),
                ),
              ),
            ),
          )],
          builder: (context, controller, child) => _FieldChrome(
            focused: controller.isOpen,
            hasError: hasError,
            enabled: enabled,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: enabled && items.isNotEmpty ? controller.open : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: SizedBox(height: 50, child: Row(children: [
                  if (icon != null) ...[
                    Icon(icon, size: 19, color: AppColors.slate500),
                    const SizedBox(width: 10),
                  ],
                  Expanded(child: Text(
                    selectedValue != null && items.contains(selectedValue)
                        ? (displayItems != null && items.indexOf(selectedValue) < displayItems!.length
                            ? displayItems![items.indexOf(selectedValue)] : selectedValue)
                        : (hint ?? 'Select'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, color: selectedValue == null ? AppColors.slate400 : AppColors.slate900),
                  )),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.slate400),
                ])),
              ),
            ),
          ),
        )),
        _fieldError(error),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SolidDateField
// ---------------------------------------------------------------------------
class SolidDateField extends StatelessWidget {
  const SolidDateField({
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
        const SizedBox(height: 7),
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
                    primary: BrandColors.blue,
                    onPrimary: Colors.white,
                    onSurface: AppColors.slate800,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) onChanged(picked);
          },
          child: _FieldChrome(
            focused: false,
            hasError: hasError,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 18,
                      color: value == null ? AppColors.slate400 : BrandColors.blue),
                  const SizedBox(width: 10),
                  Text(
                    value == null
                        ? 'Select date'
                        : '${value!.month}/${value!.day}/${value!.year}',
                    style: TextStyle(
                        fontSize: 15,
                        color: value == null ? AppColors.slate400 : AppColors.slate900),
                  ),
                ],
              ),
            ),
          ),
        ),
        _fieldError(error),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SolidButton — primary CTA. Flat fill, no gradient/shadow; a spinner
// cross-fades in for the submitting state and the tap target disables
// itself the same frame (via onPressed == null) to block duplicate taps.
// ---------------------------------------------------------------------------
class SolidButton extends StatelessWidget {
  const SolidButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return PressableScale(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: disabled ? AppColors.slate200 : BrandColors.blue,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: loading
              ? const SizedBox(
                  key: ValueKey('spinner'),
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18,
                          color: disabled ? AppColors.slate400 : Colors.white),
                      const SizedBox(width: 8),
                    ],
                    Text(label,
                        style: TextStyle(
                          color: disabled ? AppColors.slate400 : Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Secondary flat-outline button — "Log out", "Go to Login", etc.
class SolidOutlineButton extends StatelessWidget {
  const SolidOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onPressed,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
          border: Border.all(color: AppColors.slate300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.slate700),
              const SizedBox(width: 8),
            ],
            Text(label,
                style: const TextStyle(
                    color: AppColors.slate800, fontWeight: FontWeight.w700, fontSize: 14.5)),
          ],
        ),
      ),
    );
  }
}

/// "Continue with Google" — brand mark drawn inline (no asset/dependency)
/// beside a neutral outline button, matching [SolidOutlineButton]'s chrome.
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.onPressed, this.label = 'Continue with Google'});
  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onPressed,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
          border: Border.all(color: AppColors.slate300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 18, height: 18, child: GoogleMark()),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    color: AppColors.slate800, fontWeight: FontWeight.w600, fontSize: 14.5)),
          ],
        ),
      ),
    );
  }
}

/// The Google "G" mark (no asset needed), reused wherever Google is named.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _GoogleMarkPainter());
}

class _GoogleMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final stroke = size.width * 0.22;
    final rect = Rect.fromCircle(center: center, radius: r - stroke / 2);
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Four brand-color quadrants approximating the Google "G".
    canvas.drawArc(rect, -0.35, 1.6, false, arc(const Color(0xFF4285F4)));
    canvas.drawArc(rect, 1.25, 1.55, false, arc(const Color(0xFF34A853)));
    canvas.drawArc(rect, 2.8, 1.2, false, arc(const Color(0xFFFBBC05)));
    canvas.drawArc(rect, 4.0, 1.85, false, arc(const Color(0xFFEA4335)));

    // Crossbar of the G.
    final barPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(center.dx - stroke * 0.1, center.dy - stroke * 0.5, r, stroke),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// OrDivider — clear separation between authentication methods.
// ---------------------------------------------------------------------------
class OrDivider extends StatelessWidget {
  const OrDivider({super.key, this.label = 'or'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Expanded(child: Divider(color: AppColors.slate200, thickness: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(label,
            style: const TextStyle(color: AppColors.slate400, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ),
      const Expanded(child: Divider(color: AppColors.slate200, thickness: 1)),
    ]);
  }
}

/// A small uppercase section label with a hairline — groups related fields
/// within one step (e.g. "Contact details" under Personal) without adding
/// a card, border or shadow around the group itself.
class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label.toUpperCase(),
          style: const TextStyle(
              color: AppColors.slate400, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
      const SizedBox(width: 10),
      const Expanded(child: Divider(color: AppColors.slate200, thickness: 1)),
    ]);
  }
}

// ---------------------------------------------------------------------------
// SolidProgress — thin fixed-position track + fill, plus a "Step x of y"
// label so hierarchy comes from typography, not a dozen small dots.
// ---------------------------------------------------------------------------
class SolidProgress extends StatelessWidget {
  const SolidProgress({super.key, required this.total, required this.currentIndex, required this.stepLabel});
  final int total;
  final int currentIndex;
  final String stepLabel;

  @override
  Widget build(BuildContext context) {
    final safeIndex = currentIndex.clamp(0, total - 1);
    final fraction = total <= 1 ? 1.0 : (safeIndex + 1) / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Step ${safeIndex + 1} of $total',
                style: const TextStyle(color: AppColors.slate400, fontSize: 12.5, fontWeight: FontWeight.w600)),
            Text(stepLabel,
                style: const TextStyle(color: AppColors.slate700, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(children: [
            Container(height: 5, color: AppColors.slate200),
            AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              widthFactor: fraction,
              child: Container(height: 5, color: BrandColors.blue),
            ),
          ]),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SolidBanner — flat tinted status row (error / success), no border/shadow.
// ---------------------------------------------------------------------------
class SolidBanner extends StatelessWidget {
  const SolidBanner({super.key, this.error = '', this.success = ''});
  final String error;
  final String success;

  @override
  Widget build(BuildContext context) {
    final hasMsg = error.isNotEmpty || success.isNotEmpty;
    final isError = error.isNotEmpty;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: SizeTransition(sizeFactor: anim, child: child)),
      child: !hasMsg
          ? const SizedBox.shrink(key: ValueKey('empty'))
          : Padding(
              key: ValueKey(isError ? error : success),
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: (isError ? AppColors.errorRed : AppColors.successGreen).withOpacity(0.10),
                ),
                child: Row(children: [
                  Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                      size: 17, color: isError ? AppColors.errorRed : AppColors.successGreen),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(isError ? error : success,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: isError ? AppColors.errorRed : AppColors.successGreen,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// SolidUploadRow — flat document-upload row.
// ---------------------------------------------------------------------------
class SolidUploadRow extends StatelessWidget {
  const SolidUploadRow({
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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: uploaded ? AppColors.successGreen.withOpacity(0.08) : AppColors.slate100,
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: uploaded ? AppColors.successGreen.withOpacity(0.16) : Colors.white,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Icon(
                  uploaded ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                  key: ValueKey(uploaded),
                  color: uploaded ? AppColors.successGreen : AppColors.slate500,
                  size: 19,
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
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800),
                      children: [
                        TextSpan(text: label),
                        if (required) const TextSpan(text: ' *', style: TextStyle(color: BrandColors.blue)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    uploaded ? (fileName ?? 'Uploaded') : 'JPG, PNG or PDF · Max 10MB',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: uploaded ? AppColors.successGreen : AppColors.slate500),
                  ),
                ],
              ),
            ),
            Icon(uploaded ? Icons.chevron_right_rounded : Icons.add_rounded,
                color: AppColors.slate400, size: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SolidChoiceCard — role picker card (Buyer / Courier).
// ---------------------------------------------------------------------------
class SolidChoiceCard extends StatelessWidget {
  const SolidChoiceCard({
    super.key,
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? BrandColors.blueTint : AppColors.slate100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? BrandColors.blue : Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? BrandColors.blue : Colors.white,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 21, color: selected ? Colors.white : AppColors.slate500),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.slate900)),
                  const SizedBox(height: 2),
                  Text(description,
                      style: const TextStyle(fontSize: 12, color: AppColors.slate500, height: 1.3)),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: selected
                  ? const Icon(Icons.check_circle_rounded, key: ValueKey('sel'), size: 21, color: BrandColors.blue)
                  : const Icon(Icons.chevron_right_rounded, key: ValueKey('unsel'), size: 21, color: AppColors.slate300),
            ),
          ],
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// SolidSegmented — two-way switch (e.g. Log in / Sign up). Flat track with
// a sliding white thumb; the thumb moves instantly on tap.
// ---------------------------------------------------------------------------
class SolidSegmented extends StatelessWidget {
  const SolidSegmented({super.key, required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(12)),
      child: Stack(children: [
        AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment(labels.length == 1 ? 0 : -1 + 2 * index / (labels.length - 1), 0),
          child: FractionallySizedBox(
            widthFactor: 1 / labels.length,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.slate200),
              ),
            ),
          ),
        ),
        Row(children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: i == index ? null : () => onChanged(i),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: i == index ? AppColors.slate900 : AppColors.slate500,
                      ),
                      child: Text(labels[i]),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}
