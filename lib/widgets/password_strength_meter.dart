import 'package:flutter/material.dart';

import 'common.dart';

/// How strong a password is, scored purely on its composition. The web
/// signup wizard (resources/js/app.js) only ever *blocks* on
/// `password.length >= 8` — the same rule Laravel enforces with
/// `password => required|string|min:8` — so this scoring is advisory:
/// [PasswordStrength.weak] is still submittable. It exists to steer people
/// away from an 8-character password that happens to be "password".
enum PasswordStrength { empty, weak, fair, good, strong }

extension PasswordStrengthX on PasswordStrength {
  String get label {
    switch (this) {
      case PasswordStrength.empty:
        return '';
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.fair:
        return 'Fair';
      case PasswordStrength.good:
        return 'Good';
      case PasswordStrength.strong:
        return 'Strong';
    }
  }

  Color get color {
    switch (this) {
      case PasswordStrength.empty:
        return AppColors.slate300;
      case PasswordStrength.weak:
        return AppColors.errorRed;
      case PasswordStrength.fair:
        return const Color(0xFFF59E0B);
      case PasswordStrength.good:
        return AppColors.teal500;
      case PasswordStrength.strong:
        return AppColors.successGreen;
    }
  }

  /// Filled segments out of [PasswordStrengthMeter._segments].
  int get filledSegments {
    switch (this) {
      case PasswordStrength.empty:
        return 0;
      case PasswordStrength.weak:
        return 1;
      case PasswordStrength.fair:
        return 2;
      case PasswordStrength.good:
        return 3;
      case PasswordStrength.strong:
        return 4;
    }
  }
}

/// One thing the password does or doesn't do yet.
class PasswordRule {
  final String label;
  final bool satisfied;

  const PasswordRule(this.label, this.satisfied);
}

/// Scores [password] and lists which rules it currently meets. Kept as a
/// plain function (not baked into the widget) so validation code can reuse
/// the same rules without building UI.
class PasswordStrengthReport {
  final PasswordStrength strength;
  final List<PasswordRule> rules;

  const PasswordStrengthReport(this.strength, this.rules);

  /// The only hard requirement — mirrors app.js's validatePassword().
  bool get meetsMinimum => rules.first.satisfied;

  factory PasswordStrengthReport.of(String password) {
    final rules = <PasswordRule>[
      PasswordRule('At least 8 characters', password.length >= 8),
      PasswordRule(
        'Upper & lower case letters',
        RegExp(r'[a-z]').hasMatch(password) &&
            RegExp(r'[A-Z]').hasMatch(password),
      ),
      PasswordRule('At least one number', RegExp(r'\d').hasMatch(password)),
      PasswordRule(
        'A symbol (!, @, #, …)',
        RegExp(r'[^A-Za-z0-9]').hasMatch(password),
      ),
    ];

    if (password.isEmpty) {
      return PasswordStrengthReport(PasswordStrength.empty, rules);
    }

    var score = rules.where((rule) => rule.satisfied).length;
    // A long passphrase is genuinely strong even without symbol soup, and
    // anything under the 8-character floor can never read as more than weak.
    if (password.length >= 14) score += 1;
    if (password.length < 8) score = 1;

    final strength = score <= 1
        ? PasswordStrength.weak
        : score == 2
            ? PasswordStrength.fair
            : score == 3
                ? PasswordStrength.good
                : PasswordStrength.strong;

    return PasswordStrengthReport(strength, rules);
  }
}

/// Segmented strength bar + unmet-requirement hints, shown under the
/// password field while the person is typing. Collapses to nothing when
/// the field is empty so an untouched form isn't shouting requirements.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({
    super.key,
    required this.password,
    this.showChecklist = true,
  });

  final String password;

  /// Whether to list the individual rules under the bar. Off for the
  /// "confirm password" style cases where the bar alone is enough.
  final bool showChecklist;

  static const int _segments = 4;

  @override
  Widget build(BuildContext context) {
    final report = PasswordStrengthReport.of(password);

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: password.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (int i = 0; i < _segments; i++) ...[
                        if (i > 0) const SizedBox(width: 5),
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOut,
                            height: 4,
                            decoration: BoxDecoration(
                              color: i < report.strength.filledSegments
                                  ? report.strength.color
                                  : AppColors.slate200,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 46,
                        child: Text(
                          report.strength.label,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: report.strength.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (showChecklist) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        for (final rule in report.rules) _ruleChip(rule),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _ruleChip(PasswordRule rule) {
    final color = rule.satisfied ? AppColors.successGreen : AppColors.slate500;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          rule.satisfied
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          rule.label,
          style: TextStyle(
            fontSize: 11.5,
            color: color,
            fontWeight: rule.satisfied ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
