import 'dart:math' as math;

import 'package:flutter/material.dart';

class FailedAttemptSheet extends StatefulWidget {
  const FailedAttemptSheet({super.key});

  @override
  State<FailedAttemptSheet> createState() => _FailedAttemptSheetState();
}

class _FailedAttemptSheetState extends State<FailedAttemptSheet> {
  static const _reasons = {
    'recipient_unavailable': 'Recipient not available',
    'incorrect_address': 'Wrong or incomplete address',
    'refused_delivery': 'Recipient refused delivery',
    'unreachable_by_phone': 'Recipient unreachable by phone',
    'business_closed': 'Business closed',
    'access_denied': 'Access denied / gated location',
    'weather_or_roads': 'Weather or road conditions',
    'package_damaged': 'Package damaged',
    'others': 'Others',
  };

  static const _ink = Color(0xFF132A30);
  static const _muted = Color(0xFF60777B);
  static const _canvas = Color(0xFFF8FAF8);
  static const _line = Color(0xFFDDE7E4);
  static const _teal = Color(0xFF087C72);

  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _reasonFieldKey = GlobalKey();
  String? _reason;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _chooseReason() async {
    final box =
        _reasonFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final position = box.localToGlobal(Offset.zero);
    final screen = MediaQuery.sizeOf(context);
    final safeTop = MediaQuery.paddingOf(context).top;
    final spaceAbove = position.dy - safeTop - 16;
    final menuHeight = math.min(478.0, math.max(160.0, spaceAbove));
    final menuTop = math.max(safeTop + 8, position.dy - menuHeight - 8);
    final menuWidth = math.min(box.size.width, screen.width - 32);
    final menuLeft = position.dx.clamp(16.0, screen.width - menuWidth - 16);

    final selected = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close reasons',
      barrierColor: Colors.black.withValues(alpha: 0.08),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, _, __) => Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(dialogContext).pop(),
              ),
            ),
            Positioned(
              left: menuLeft,
              top: menuTop,
              width: menuWidth,
              height: menuHeight,
              child: Material(
                color: Colors.white,
                elevation: 14,
                shadowColor: _ink.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 15, 18, 13),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: _line)),
                      ),
                      child: const Text('SELECT A REASON',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 11,
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w800,
                          )),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        itemCount: _reasons.length,
                        itemBuilder: (itemContext, index) {
                          final entry = _reasons.entries.elementAt(index);
                          final isSelected = entry.key == _reason;
                          return InkWell(
                            onTap: () =>
                                Navigator.pop(dialogContext, entry.key),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 49),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 12),
                              color: isSelected
                                  ? const Color(0xFFEAF6F2)
                                  : Colors.transparent,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(entry.value,
                                        style: TextStyle(
                                          color: isSelected ? _teal : _ink,
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        )),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_rounded,
                                        size: 18, color: _teal),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null && mounted) setState(() => _reason = selected);
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _reason != null &&
        (_reason != 'others' || _description.text.trim().isNotEmpty);

    return Container(
      decoration: const BoxDecoration(
        color: _canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 11, 18, 22),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEAF4F1),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(26)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 35,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFB7CFCA),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE9BD),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(Icons.route_outlined,
                                  size: 23, color: _ink),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('DELIVERY EXCEPTION',
                                      style: TextStyle(
                                          color: _teal,
                                          fontSize: 10,
                                          letterSpacing: 1.4,
                                          fontWeight: FontWeight.w800)),
                                  SizedBox(height: 4),
                                  Text('Report an attempt',
                                      style: TextStyle(
                                          color: _ink,
                                          fontSize: 21,
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon:
                                  const Icon(Icons.close_rounded, color: _ink),
                              tooltip: 'Cancel',
                            ),
                          ],
                        ),
                        const SizedBox(height: 13),
                        const Text('Record what happened at this stop.',
                            style: TextStyle(color: _muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const _StepPill(
                                number: '01', label: 'REASON', active: true),
                            const SizedBox(width: 8),
                            Container(width: 18, height: 1, color: _line),
                            const SizedBox(width: 8),
                            const _StepPill(
                                number: '02', label: 'PHOTO', active: false),
                          ],
                        ),
                        const SizedBox(height: 25),
                        const Text('What stopped the delivery?',
                            style: TextStyle(
                                color: _ink,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 5),
                        const Text('Select the closest reason.',
                            style: TextStyle(color: _muted, fontSize: 13)),
                        const SizedBox(height: 14),
                        Semantics(
                          button: true,
                          label:
                              'Reason, ${_reason == null ? 'not selected' : _reasons[_reason]}',
                          child: InkWell(
                            key: _reasonFieldKey,
                            onTap: _chooseReason,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 64),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                    color: _reason == null ? _line : _teal,
                                    width: _reason == null ? 1.2 : 1.6),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.fact_check_outlined,
                                      color: _teal, size: 22),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('REASON',
                                            style: TextStyle(
                                                color: _muted,
                                                fontSize: 10,
                                                letterSpacing: 1.1,
                                                fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 4),
                                        Text(
                                            _reason == null
                                                ? 'Choose a reason'
                                                : _reasons[_reason]!,
                                            style: TextStyle(
                                                color: _reason == null
                                                    ? _muted
                                                    : _ink,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_up_rounded,
                                      color: _teal),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_reason == 'others') ...[
                          const SizedBox(height: 13),
                          TextFormField(
                            controller: _description,
                            maxLength: 1000,
                            minLines: 3,
                            maxLines: 5,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: 'Describe what happened',
                              hintText: 'Add details for dispatch',
                              alignLabelWithHint: true,
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'A description is required.'
                                    : null,
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                        if (_reason == 'refused_delivery') ...[
                          const SizedBox(height: 13),
                          const _Notice(
                            icon: Icons.assignment_return_outlined,
                            text:
                                'Refused delivery may start a return to seller.',
                          ),
                        ],
                        const SizedBox(height: 18),
                        const _Notice(
                          icon: Icons.schedule_outlined,
                          text:
                              'The next attempt can start tomorrow. Repeated failures need dispatcher approval.',
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _teal,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFFCFDCD8),
                              disabledForegroundColor: _muted,
                              elevation: 0,
                              minimumSize: const Size.fromHeight(58),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                            onPressed: !canSubmit
                                ? null
                                : () {
                                    if (_formKey.currentState!.validate()) {
                                      Navigator.pop(context, (
                                        _reason!,
                                        _reason == 'others'
                                            ? _description.text.trim()
                                            : null
                                      ));
                                    }
                                  },
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('Confirm failed attempt'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Center(
                          child: Text('Photo evidence is required next',
                              style: TextStyle(color: _muted, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill(
      {required this.number, required this.label, required this.active});

  final String number;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE4F3EF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border:
              active ? null : Border.all(color: _FailedAttemptSheetState._line),
        ),
        child: Text('$number  $label',
            style: TextStyle(
              color: active
                  ? _FailedAttemptSheetState._teal
                  : _FailedAttemptSheetState._muted,
              fontSize: 10,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w800,
            )),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF9A6016)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: Color(0xFF654B29), fontSize: 12.5, height: 1.35)),
            ),
          ],
        ),
      );
}
