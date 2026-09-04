import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/api_service.dart';
import 'document_viewer_screen.dart';

// ============================================================
// MODELS
// ============================================================

/// Formats a peso amount the way the "Find Work" cards show it: no
/// decimals, thousands separators (e.g. 18000 -> "₱18,000").
String _formatPhp(num value) {
  final whole = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return '₱$buffer';
}

enum ApplicationStatus { pending, employed, rejected, withdrawn }

extension ApplicationStatusX on ApplicationStatus {
  String get label {
    switch (this) {
      case ApplicationStatus.pending:
        return 'Pending';
      case ApplicationStatus.employed:
        return 'Employed';
      case ApplicationStatus.rejected:
        return 'Rejected';
      case ApplicationStatus.withdrawn:
        return 'Withdrawn';
    }
  }

  Color get color {
    switch (this) {
      case ApplicationStatus.pending:
        return const Color(0xFFE8A400);
      case ApplicationStatus.employed:
        return const Color(0xFF1FA55C);
      case ApplicationStatus.rejected:
        return const Color(0xFFE0503A);
      case ApplicationStatus.withdrawn:
        return const Color(0xFF64748B);
    }
  }

  Color get surfaceColor {
    switch (this) {
      case ApplicationStatus.pending:
        return const Color(0xFFFFF4DC);
      case ApplicationStatus.employed:
        return const Color(0xFFE4F7EC);
      case ApplicationStatus.rejected:
        return const Color(0xFFFCE7E3);
      case ApplicationStatus.withdrawn:
        return const Color(0xFFF1F5F9);
    }
  }

  IconData get icon {
    switch (this) {
      case ApplicationStatus.pending:
        return Icons.hourglass_top_rounded;
      case ApplicationStatus.employed:
        return Icons.check_circle_rounded;
      case ApplicationStatus.rejected:
        return Icons.cancel_rounded;
      case ApplicationStatus.withdrawn:
        return Icons.remove_circle_outline_rounded;
    }
  }
}

class Company {
  final String id;
  final String name;
  final String role;
  final String region;
  final String industry;
  final String salaryRange;
  final String employmentType;
  final String logoInitial;
  final String description;
  final String? email;
  final String? contactNumber;
  final String? status;
  final DateTime? createdAt;
  /// Raw monthly salary the company is offering couriers, in PHP. Null
  /// when the company has not set one — `salaryRange` then reads
  /// "Salary not disclosed".
  final double? monthlySalary;
  /// Whether the company is currently accepting courier applications. The
  /// API already filters non-hiring companies out of the list, so this is
  /// effectively always true here; kept for completeness / labelling.
  final bool isHiring;

  const Company({
    required this.id,
    required this.name,
    required this.role,
    required this.region,
    required this.industry,
    required this.salaryRange,
    required this.employmentType,
    required this.logoInitial,
    required this.description,
    this.email,
    this.contactNumber,
    this.status,
    this.createdAt,
    this.monthlySalary,
    this.isHiring = true,
  });

  /// True when this company was added to the backend within the last two
  /// weeks — drives the "New" badge on company cards.
  bool get isNew =>
      createdAt != null && DateTime.now().difference(createdAt!).inDays <= 14;

  factory Company.fromApi(Map<String, dynamic> json) {
    final name = (json['company_name'] as String? ?? 'Unnamed company').trim();
    final email = (json['company_email'] as String? ?? '').trim();
    final contactNumber = (json['company_contact_no'] as String? ?? '').trim();
    final status = (json['status'] as String? ?? '').trim();
    final accountStatus = (json['account_status'] as String? ?? '').trim();

    // Courier-recruitment fields the logistics company sets from its
    // portal Account Settings page.
    final rawSalary = json['monthly_salary'];
    final monthlySalary = rawSalary is num
        ? rawSalary.toDouble()
        : double.tryParse(rawSalary?.toString() ?? '');
    // Absent (older backend) is treated as hiring; only an explicit false
    // hides the company.
    final isHiring = json['is_hiring'] != false;
    final apiDescription = (json['description'] as String? ?? '').trim();

    return Company(
      id: json['id'].toString(),
      name: name.isEmpty ? 'Unnamed company' : name,
      role: 'Logistics Company',
      region: (json['region'] as String? ?? '').trim().isEmpty
          ? 'Region not specified'
          : (json['region'] as String).trim(),
      industry: 'Logistics',
      salaryRange: monthlySalary != null
          ? '${_formatPhp(monthlySalary)} / month'
          : 'Salary not disclosed',
      employmentType: status.isEmpty
          ? (accountStatus.isEmpty ? 'Available' : accountStatus)
          : status,
      logoInitial: name.isEmpty ? '?' : name[0].toUpperCase(),
      description: apiDescription.isNotEmpty
          ? apiDescription
          : [
              if (email.isNotEmpty) 'Email: $email',
              if (contactNumber.isNotEmpty) 'Contact: $contactNumber',
              if (accountStatus.isNotEmpty) 'Account status: $accountStatus',
            ].join('\n'),
      email: email,
      contactNumber: contactNumber,
      status: status,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      monthlySalary: monthlySalary,
      isHiring: isHiring,
    );
  }
}

class ResumeFile {
  final String fileName;
  final int sizeBytes;
  // Exactly one of these is set once a file has actually been picked: bytes
  // on web (file_picker can't return a usable path there), path elsewhere.
  final Uint8List? bytes;
  final String? path;

  const ResumeFile({
    required this.fileName,
    required this.sizeBytes,
    this.bytes,
    this.path,
  });

  String get sizeLabel {
    final kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}

class JobApplication {
  final String id;
  final Company company;
  final ResumeFile resume;
  final ResumeFile license;
  final String? coverNote;
  final DateTime submittedAt;
  ApplicationStatus status;
  final bool hasResume;
  final bool hasLicense;
  final String? rejectionReason;
  final DateTime? reviewedAt;
  final DateTime? interviewInvitedAt;
  final DateTime? interviewScheduledAt;

  JobApplication({
    required this.id,
    required this.company,
    required this.resume,
    required this.license,
    this.coverNote,
    required this.submittedAt,
    this.status = ApplicationStatus.pending,
    this.hasResume = false,
    this.hasLicense = false,
    this.rejectionReason,
    this.reviewedAt,
    this.interviewInvitedAt,
    this.interviewScheduledAt,
  });

  factory JobApplication.fromApi(Map<String, dynamic> json) {
    final companyJson = json['company'];
    final submittedAt = DateTime.tryParse(json['applied_at'] as String? ?? '');
    final apiStatus = json['status'] as String? ?? 'pending';
    final resumeSize = json['resume_size'];
    final licenseSize = json['license_size'];

    return JobApplication(
      id: json['id'].toString(),
      company: Company.fromApi(Map<String, dynamic>.from(companyJson as Map)),
      resume: ResumeFile(
        fileName: (json['resume_original_name'] as String?)?.trim().isNotEmpty ==
                true
            ? json['resume_original_name'] as String
            : 'Application submitted',
        sizeBytes: resumeSize is num ? resumeSize.toInt() : 0,
      ),
      license: ResumeFile(
        fileName: (json['license_original_name'] as String?)?.trim().isNotEmpty ==
                true
            ? json['license_original_name'] as String
            : 'Application submitted',
        sizeBytes: licenseSize is num ? licenseSize.toInt() : 0,
      ),
      coverNote: (json['cover_note'] as String?)?.trim().isEmpty == true
          ? null
          : json['cover_note'] as String?,
      submittedAt: submittedAt ?? DateTime.now(),
      status: switch (apiStatus) {
        'accepted' || 'employed' => ApplicationStatus.employed,
        'rejected' => ApplicationStatus.rejected,
        'withdrawn' => ApplicationStatus.withdrawn,
        _ => ApplicationStatus.pending,
      },
      hasResume: json['has_resume'] == true,
      hasLicense: json['has_license'] == true,
      rejectionReason:
          (json['rejection_reason'] as String?)?.trim().isEmpty == true
              ? null
              : json['rejection_reason'] as String?,
      reviewedAt: DateTime.tryParse(json['reviewed_at'] as String? ?? ''),
      interviewInvitedAt:
          DateTime.tryParse(json['interview_invited_at'] as String? ?? ''),
      interviewScheduledAt:
          DateTime.tryParse(json['interview_scheduled_at'] as String? ?? ''),
    );
  }
}

/// The signed-in courier's current employment status, as tracked by
/// `courier_details` on the Laravel/Supabase backend (vehicle, plate number
/// and the logistics company that took them on, if any).
class EmploymentStatus {
  final bool isEmployed;
  final String? companyName;
  final String? companyEmail;
  final String? companyContactNo;
  final String? region;
  final String? description;
  final double? monthlySalary;
  final DateTime? employedSince;
  final String? vehicle;
  final String? plateNumber;

  /// The courier's still-pending resignation request, if any — when set,
  /// the employer card shows "awaiting review" + a Cancel action instead
  /// of the "Request resignation" button.
  final PendingResignation? pendingResignation;

  const EmploymentStatus({
    required this.isEmployed,
    this.companyName,
    this.companyEmail,
    this.companyContactNo,
    this.region,
    this.description,
    this.monthlySalary,
    this.employedSince,
    this.vehicle,
    this.plateNumber,
    this.pendingResignation,
  });

  factory EmploymentStatus.fromApi(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) => (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;
    final pr = json['pending_resignation'];
    final rawSalary = json['monthly_salary'];
    return EmploymentStatus(
      isEmployed: json['is_employed'] == true,
      companyName: json['company_name'] as String?,
      companyEmail: json['company_email'] as String?,
      companyContactNo: json['company_contact_no'] as String?,
      region: json['region'] as String?,
      description: json['description'] as String?,
      monthlySalary: rawSalary is num ? rawSalary.toDouble() : double.tryParse(rawSalary?.toString() ?? ''),
      employedSince: parseDate(json['employed_since']),
      vehicle: json['vehicle'] as String?,
      plateNumber: json['plate_number'] as String?,
      pendingResignation: pr is Map ? PendingResignation.fromApi(Map<String, dynamic>.from(pr)) : null,
    );
  }
}

/// A resignation request the courier has open with their employer.
class PendingResignation {
  final String id;
  final String status;
  final DateTime? submittedAt;

  const PendingResignation({required this.id, required this.status, this.submittedAt});

  factory PendingResignation.fromApi(Map<String, dynamic> json) {
    return PendingResignation(
      id: (json['id'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      submittedAt: json['submitted_at'] is String ? DateTime.tryParse(json['submitted_at'] as String) : null,
    );
  }
}

class UserProfile {
  String? employedCompanyId;
  String? employedCompanyName;
  final List<JobApplication> applications;

  UserProfile({
    this.employedCompanyId,
    this.employedCompanyName,
    List<JobApplication>? applications,
  }) : applications = applications ?? [];

  bool get isEmployed => employedCompanyId != null;
}

// ============================================================
// THEME / COLORS
// ============================================================

class WorkAppColors {
  WorkAppColors._();

  static const Color primary = Color(0xFF0F9B8E);
  static const Color primaryDark = Color(0xFF0B6E64);
  static const Color primaryDeep = Color(0xFF0D7A70);
  static const Color primaryLight = Color(0xFF5FC9BC);
  static const Color primarySurface = Color(0xFFE6F7F5);
  static const Color accent = Color(0xFF00C2A8);

  static const Color background = Color(0xFFF2F9F8);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF11221F);
  static const Color textSecondary = Color(0xFF5A6C69);

  static const Color coral = Color(0xFFFF6B6B);
  static const Color coralDark = Color(0xFFE0503A);
  static const Color coralSurface = Color(0xFFFFE9E7);

  static const Color pending = Color(0xFFE8A400);
  static const Color pendingSurface = Color(0xFFFFF4DC);
  static const Color employed = Color(0xFF1FA55C);
  static const Color employedSurface = Color(0xFFE4F7EC);
  static const Color rejected = coralDark;
  static const Color rejectedSurface = coralSurface;

  static const List<Color> primaryGradient = [primary, primaryDeep];
  static const List<Color> coralGradient = [Color(0xFFFF8A7A), coralDark];
}

// ============================================================
// SHARED HELPERS
// ============================================================

const List<List<Color>> _logoGradients = [
  [WorkAppColors.primary, WorkAppColors.primaryDeep],
  [Color(0xFF14B8A6), Color(0xFF0F766E)],
  [Color(0xFF06B6D4), WorkAppColors.primaryDark],
  [Color(0xFF10B981), Color(0xFF0B6E64)],
  [Color(0xFF0EA5A4), Color(0xFF134E4A)],
];

/// Picks one of a handful of on-brand teal gradient variants for a company
/// logo tile, keyed off its name so the same company always renders the
/// same gradient.
List<Color> gradientForName(String name) {
  final hash = name.codeUnits.fold<int>(0, (acc, c) => acc + c);
  return _logoGradients[hash % _logoGradients.length];
}

String formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${months[local.month - 1]} ${local.day}, $hour12:$minute $period';
}

/// A small icon + wrapping text row used for interview/rejection call-outs.
class InfoLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const InfoLine({super.key, required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ),
      ],
    );
  }
}

/// A counter that eases toward [value] whenever it changes, instead of
/// jumping straight to the new number.
class AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle? style;
  const AnimatedCount({super.key, required this.value, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return Text(animatedValue.round().toString(), style: style);
      },
    );
  }
}

/// A skeleton-loading block with a slow sweeping shimmer, used while company
/// data is still loading.
class ShimmerBox extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;
  const ShimmerBox({super.key, required this.height, this.width, this.radius = 10});

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: Container(
            height: widget.height,
            width: widget.width ?? double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 + t * 3, 0),
                end: Alignment(0 + t * 3, 0),
                colors: [Colors.grey.shade200, Colors.grey.shade100, Colors.grey.shade200],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Circular glass-look icon button used in the app bars.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const GlassIconButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.92),
      shape: const CircleBorder(),
      elevation: 1,
      shadowColor: WorkAppColors.primary.withOpacity(0.2),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: WorkAppColors.primary, size: 19),
        ),
      ),
    );
  }
}

/// Slide + fade page transition used when opening the apply flow.
Route<T> fadeSlideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

// ============================================================
// APPLICATION SUMMARY CARDS (PENDING & REJECTED ONLY)
// ============================================================

class ApplicationSummaryCards extends StatelessWidget {
  final List<JobApplication> applications;

  const ApplicationSummaryCards({super.key, required this.applications});

  int get pendingCount =>
      applications.where((a) => a.status == ApplicationStatus.pending).length;

  int get rejectedCount =>
      applications.where((a) => a.status == ApplicationStatus.rejected).length;

  int _thisWeek(ApplicationStatus status) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return applications
        .where((a) => a.status == status && a.submittedAt.isAfter(cutoff))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.hourglass_top_rounded,
            label: 'Pending',
            count: pendingCount,
            subtitle: '$pendingCount application${pendingCount != 1 ? 's' : ''} waiting',
            weekCount: _thisWeek(ApplicationStatus.pending),
            gradient: WorkAppColors.primaryGradient,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.cancel_rounded,
            label: 'Rejected',
            count: rejectedCount,
            subtitle: '$rejectedCount application${rejectedCount != 1 ? 's' : ''} declined',
            weekCount: _thisWeek(ApplicationStatus.rejected),
            gradient: WorkAppColors.coralGradient,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final String subtitle;
  final int weekCount;
  final List<Color> gradient;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.subtitle,
    required this.weekCount,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: gradient.last.withOpacity(0.32), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -14,
            top: -14,
            child: Icon(icon, size: 72, color: Colors.white.withOpacity(0.12)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: Colors.white, size: 17),
                  ),
                  const Spacer(),
                  if (weekCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.trending_up_rounded, color: Colors.white, size: 11),
                          const SizedBox(width: 2),
                          Text('+$weekCount wk',
                              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedCount(
                value: count,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 26),
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: 11.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 420.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }
}

// ============================================================
// EMPLOYMENT BANNER
// ============================================================

/// The "My Employer" card at the top of Find Work once a logistics company
/// has taken the courier on (an accepted courier_applications row). While
/// employed the rest of Find Work — the company browser and apply flow —
/// is hidden; this card shows the employer's details and offered salary,
/// plus the way out: request a resignation (attach a letter; the company
/// approves it before the courier is freed to apply elsewhere).
///
/// A two-page swipeable card: page 1 is everything above (company details,
/// salary, resignation actions); page 2 — only reachable when the company
/// has set a description — is just the "About" text, kept off page 1 so
/// a long description can't push the resignation actions out of easy
/// reach.
class EmploymentBanner extends StatefulWidget {
  final EmploymentStatus employment;
  final VoidCallback onRequestResignation;
  final VoidCallback onCancelResignation;
  final VoidCallback onViewLetter;
  final bool busy;

  const EmploymentBanner({
    super.key,
    required this.employment,
    required this.onRequestResignation,
    required this.onCancelResignation,
    required this.onViewLetter,
    this.busy = false,
  });

  @override
  State<EmploymentBanner> createState() => _EmploymentBannerState();
}

class _EmploymentBannerState extends State<EmploymentBanner> {
  int _page = 0;

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    final l = d.toLocal();
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[l.month - 1]} ${l.day}, ${l.year}';
  }

  void _goToPage(int page, int pageCount) {
    final clamped = page.clamp(0, pageCount - 1);
    if (clamped == _page) return;
    HapticFeedback.selectionClick();
    setState(() => _page = clamped);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.employment;
    final pending = e.pendingResignation;
    final busy = widget.busy;
    final about = (e.description ?? '').trim();
    final hasAbout = about.isNotEmpty;
    final pageCount = hasAbout ? 2 : 1;
    if (_page >= pageCount) _page = 0;

    Widget detail(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 14, color: Colors.white.withOpacity(0.85)),
              const SizedBox(width: 8),
              SizedBox(
                width: 68,
                child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11.5, fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );

    final rows = <Widget>[
      if ((e.region ?? '').trim().isNotEmpty) detail(Icons.place_rounded, 'Area', e.region!.trim()),
      if ((e.companyContactNo ?? '').trim().isNotEmpty) detail(Icons.call_rounded, 'Contact', e.companyContactNo!.trim()),
      if ((e.companyEmail ?? '').trim().isNotEmpty) detail(Icons.mail_rounded, 'Email', e.companyEmail!.trim()),
      if (e.monthlySalary != null) detail(Icons.payments_rounded, 'Salary', '${_formatPhp(e.monthlySalary!)} / month'),
      if (e.employedSince != null) detail(Icons.event_rounded, 'Since', _fmtDate(e.employedSince)),
    ];

    ButtonStyle ghost() => OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.65)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        );

    final detailsPage = Column(
      key: const ValueKey('employer-page-details'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.business_rounded, color: Colors.white, size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                e.companyName ?? 'Your logistics company',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 4),
          ...rows,
        ],
        const SizedBox(height: 16),
        Container(height: 1, color: Colors.white.withOpacity(0.18)),
        const SizedBox(height: 14),
        if (pending != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 15),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Resignation submitted ${_fmtDate(pending.submittedAt)} — awaiting ${e.companyName ?? 'the company'}’s review.',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, height: 1.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : widget.onViewLetter,
                  icon: const Icon(Icons.description_rounded, size: 15),
                  label: const Text('View letter'),
                  style: ghost(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : widget.onCancelResignation,
                  icon: const Icon(Icons.undo_rounded, size: 15),
                  label: Text(busy ? '…' : 'Cancel'),
                  style: ghost(),
                ),
              ),
            ],
          ),
        ] else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy ? null : widget.onRequestResignation,
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('Request resignation'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.7)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ),
          ),
      ],
    );

    final aboutPage = Column(
      key: const ValueKey('employer-page-about'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.notes_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text('About ${e.companyName ?? 'this company'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
          ],
        ),
        const SizedBox(height: 10),
        Text(about, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500, height: 1.5)),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: pageCount < 2
          ? null
          : (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -200) _goToPage(_page + 1, pageCount);
              if (velocity > 200) _goToPage(_page - 1, pageCount);
            },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [WorkAppColors.employed, Color(0xFF15703D)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: WorkAppColors.employed.withOpacity(0.32), blurRadius: 22, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(20)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, color: Colors.white, size: 13),
                      SizedBox(width: 4),
                      Text('CURRENT EMPLOYER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.6)),
                    ],
                  ),
                ),
                if (pageCount > 1) ...[
                  const Spacer(),
                  Icon(Icons.swipe_rounded, color: Colors.white.withOpacity(0.7), size: 15),
                  const SizedBox(width: 3),
                  Text('Swipe', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10.5, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _page == 0 ? detailsPage : aboutPage,
              ),
            ),
            if (pageCount > 1) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pageCount, (i) {
                  final active = i == _page;
                  return GestureDetector(
                    onTap: () => _goToPage(i, pageCount),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(active ? 0.95 : 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 420.ms).slideY(begin: -0.08, end: 0, curve: Curves.easeOutCubic);
  }
}

/// What [ResignationRequestSheet] hands back on submit — the picked letter
/// (bytes on web, path elsewhere) plus an optional reason.
class _ResignationDraft {
  final String fileName;
  final Uint8List? bytes;
  final String? filePath;
  final String? reason;

  const _ResignationDraft({required this.fileName, this.bytes, this.filePath, this.reason});
}

/// Bottom sheet for composing a resignation request: attach the letter
/// (PDF/DOC/DOCX), add an optional reason, submit. Pops a [_ResignationDraft]
/// on submit, or null if dismissed.
class ResignationRequestSheet extends StatefulWidget {
  const ResignationRequestSheet({super.key});

  @override
  State<ResignationRequestSheet> createState() => _ResignationRequestSheetState();
}

class _ResignationRequestSheetState extends State<ResignationRequestSheet> {
  final TextEditingController _reason = TextEditingController();
  String? _fileName;
  int? _fileSize;
  Uint8List? _bytes;
  String? _path;

  bool get _hasFile => _bytes != null || _path != null;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.single;
      setState(() {
        _fileName = f.name;
        _fileSize = f.size;
        _bytes = kIsWeb ? f.bytes : null;
        _path = kIsWeb ? null : f.path;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the file picker. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Request resignation', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: WorkAppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text(
              'Attach your resignation letter. Your logistics company reviews it — you stay employed until they approve it.',
              style: TextStyle(fontSize: 12.5, color: WorkAppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pick,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _hasFile ? WorkAppColors.primarySurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _hasFile ? WorkAppColors.primary : WorkAppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(_hasFile ? Icons.check_circle_rounded : Icons.upload_file_rounded, color: WorkAppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _hasFile
                            ? '${_fileName ?? 'Letter attached'}${_fileSize != null ? ' · ${(_fileSize! / 1024).round()} KB' : ''}'
                            : 'Attach letter (PDF, DOC, or DOCX)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: WorkAppColors.textPrimary),
                      ),
                    ),
                    if (_hasFile)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: WorkAppColors.textSecondary),
                        onPressed: () => setState(() {
                          _fileName = null;
                          _fileSize = null;
                          _bytes = null;
                          _path = null;
                        }),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLines: 3,
              maxLength: 2000,
              decoration: InputDecoration(
                hintText: 'Reason (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _hasFile
                    ? () => Navigator.pop(
                          context,
                          _ResignationDraft(
                            fileName: _fileName!,
                            bytes: _bytes,
                            filePath: _path,
                            reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
                          ),
                        )
                    : null,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Submit request'),
                style: FilledButton.styleFrom(
                  backgroundColor: WorkAppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centered pop-up used to confirm the *result* of a resignation action
/// (request sent / request cancelled) — a deliberate, must-acknowledge
/// modal in place of a SnackBar, since these are meaningful state changes
/// to the courier's employment rather than routine feedback.
class ResignationResultDialog extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String message;
  final String buttonLabel;

  const ResignationResultDialog({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.message,
    this.buttonLabel = 'Done',
  });

  static Future<void> show(
    BuildContext context, {
    required IconData icon,
    required Color accent,
    required String title,
    required String message,
    String buttonLabel = 'Done',
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ResignationResultDialog(icon: icon, accent: accent, title: title, message: message, buttonLabel: buttonLabel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: accent.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: accent, size: 32),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: WorkAppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: WorkAppColors.textSecondary, height: 1.45)),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 220.ms).scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1), curve: Curves.easeOutBack, duration: 260.ms);
  }
}

/// Centered "are you sure" confirmation used before cancelling a pending
/// resignation request — replaces the plain [AlertDialog] with something
/// that leads with a warning icon and gives the destructive action its own
/// visual weight, instead of two same-looking [TextButton]s.
class ResignationCancelConfirmDialog extends StatelessWidget {
  const ResignationCancelConfirmDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(context: context, builder: (_) => const ResignationCancelConfirmDialog());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: WorkAppColors.pending.withOpacity(0.14), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, color: WorkAppColors.pending, size: 32),
            ),
            const SizedBox(height: 18),
            const Text('Cancel resignation request?', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: WorkAppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'Your request will be withdrawn and you’ll stay employed. You can submit a new one later.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: WorkAppColors.textSecondary, height: 1.45),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: WorkAppColors.textPrimary,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Keep it', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.undo_rounded, size: 16),
                    label: const Text('Cancel it'),
                    style: FilledButton.styleFrom(
                      backgroundColor: WorkAppColors.coralDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 220.ms).scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1), curve: Curves.easeOutBack, duration: 260.ms);
  }
}

// ============================================================
// APPLICATION STATUS CARD
// ============================================================

/// A horizontal mini-timeline (Applied → Reviewed → Decision) reflecting an
/// application's current status.
class StatusTimeline extends StatelessWidget {
  final ApplicationStatus status;
  const StatusTimeline({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    const labels = ['Applied', 'Reviewed', 'Decision'];
    final filled = switch (status) {
      ApplicationStatus.pending => 1,
      ApplicationStatus.employed => 3,
      ApplicationStatus.rejected => 3,
      ApplicationStatus.withdrawn => 1,
    };
    final color = status.color;

    Widget dot(int index) {
      final on = index < filled;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: on ? 9 : 7,
            height: on ? 9 : 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? color : Colors.grey.shade300,
              boxShadow: on ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 5)] : null,
            ),
          ),
          const SizedBox(height: 3),
          Text(labels[index], style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: on ? color : Colors.grey[400])),
        ],
      );
    }

    Widget line(int index) {
      final on = index < filled - 1;
      return Expanded(
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 2,
          color: on ? color : Colors.grey.shade200,
        ),
      );
    }

    return Row(children: [dot(0), line(0), dot(1), line(1), dot(2)]);
  }
}

class WorkApplicationStatusCard extends StatefulWidget {
  final JobApplication application;
  final VoidCallback? onWithdraw;
  final bool isWithdrawing;
  final VoidCallback? onViewResume;
  const WorkApplicationStatusCard({
    super.key,
    required this.application,
    this.onWithdraw,
    this.isWithdrawing = false,
    this.onViewResume,
  });

  @override
  State<WorkApplicationStatusCard> createState() => _WorkApplicationStatusCardState();
}

class _WorkApplicationStatusCardState extends State<WorkApplicationStatusCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final application = widget.application;
    final status = application.status;
    final canWithdraw = status == ApplicationStatus.pending && widget.onWithdraw != null;
    final canViewResume = application.hasResume && widget.onViewResume != null;

    final card = _buildCard(status);

    if (!canWithdraw && !canViewResume) return card;

    return Dismissible(
      key: ValueKey('app-${application.id}'),
      direction: canWithdraw && canViewResume
          ? DismissDirection.horizontal
          : canViewResume
              ? DismissDirection.startToEnd
              : DismissDirection.endToStart,
      background: canViewResume
          ? _swipeBackground(alignment: Alignment.centerLeft, color: WorkAppColors.primary, icon: Icons.description_rounded, label: 'View resume')
          : const SizedBox.shrink(),
      secondaryBackground: canWithdraw
          ? _swipeBackground(alignment: Alignment.centerRight, color: WorkAppColors.rejected, icon: Icons.close_rounded, label: 'Withdraw')
          : const SizedBox.shrink(),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd && canViewResume) {
          widget.onViewResume?.call();
        } else if (direction == DismissDirection.endToStart && canWithdraw) {
          widget.onWithdraw?.call();
        }
        return false; // snap back — swiping only triggers the action
      },
      child: card,
    );
  }

  Widget _swipeBackground({required Alignment alignment, required Color color, required IconData icon, required String label}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: alignment,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: alignment == Alignment.centerLeft
            ? [Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))]
            : [Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), const SizedBox(width: 8), Icon(icon, color: Colors.white, size: 20)],
      ),
    );
  }

  Widget _buildCard(ApplicationStatus status) {
    final application = widget.application;
    final daysAgo = DateTime.now().difference(application.submittedAt).inDays;
    final timeAgo = daysAgo == 0 ? 'Today' : daysAgo == 1 ? 'Yesterday' : '$daysAgo days ago';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(left: BorderSide(color: status.color, width: 4)),
        boxShadow: [BoxShadow(color: status.color.withOpacity(0.10), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradientForName(application.company.name)),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(application.company.logoInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(application.company.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: WorkAppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                              child: Text(timeAgo, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                            ),
                            if (application.company.region.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.location_on_rounded, size: 11, color: Colors.grey[400]),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(application.company.region,
                                    style: TextStyle(fontSize: 10.5, color: Colors.grey[500], fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: status.surfaceColor, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [Icon(status.icon, size: 12, color: status.color), const SizedBox(width: 4), Text(status.label, style: TextStyle(color: status.color, fontWeight: FontWeight.w700, fontSize: 10))],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(Icons.expand_more_rounded, color: Colors.grey[400], size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StatusTimeline(status: status),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: _expanded ? _expandedDetails(status) : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _expandedDetails(ApplicationStatus status) {
    final application = widget.application;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          if (application.coverNote != null) ...[
            Text('Cover note', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 0.4)),
            const SizedBox(height: 4),
            Text(application.coverNote!, style: const TextStyle(fontSize: 12.5, color: WorkAppColors.textSecondary, height: 1.4)),
            const SizedBox(height: 10),
          ],
          if (status == ApplicationStatus.pending && application.interviewScheduledAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InfoLine(icon: Icons.event_available_rounded, color: WorkAppColors.primaryDark, text: 'Interview scheduled for ${formatDateTime(application.interviewScheduledAt!)}'),
            )
          else if (status == ApplicationStatus.pending && application.interviewInvitedAt != null)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: InfoLine(icon: Icons.event_note_rounded, color: WorkAppColors.primaryDark, text: 'You have been invited to an interview'),
            ),
          if (status == ApplicationStatus.rejected && application.rejectionReason != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InfoLine(icon: Icons.info_outline_rounded, color: WorkAppColors.rejected, text: 'Reason: ${application.rejectionReason}'),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (application.hasResume && widget.onViewResume != null)
                _pillButton(label: 'View resume', color: WorkAppColors.primary, onPressed: widget.onViewResume),
              if (status == ApplicationStatus.pending && widget.onWithdraw != null)
                _pillButton(label: widget.isWithdrawing ? 'Withdrawing...' : 'Withdraw', color: WorkAppColors.rejected, onPressed: widget.isWithdrawing ? null : widget.onWithdraw),
            ],
          ),
          const SizedBox(height: 2),
          Text('Tip: swipe the card for quick actions', style: TextStyle(fontSize: 10, color: Colors.grey[400], fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _pillButton({required String label, required Color color, required VoidCallback? onPressed}) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

// ============================================================
// SEARCH / FILTER WIDGETS
// ============================================================

class WorkRegionFilterChips extends StatelessWidget {
  final List<String> regions;
  final String selectedRegion;
  final ValueChanged<String> onSelected;

  const WorkRegionFilterChips({
    super.key,
    required this.regions,
    required this.selectedRegion,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: regions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final region = regions[index];
          final selected = region == selectedRegion;
          return GestureDetector(
            onTap: () => onSelected(region),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                gradient: selected ? const LinearGradient(colors: WorkAppColors.primaryGradient) : null,
                color: selected ? null : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: selected ? Colors.transparent : WorkAppColors.primary.withOpacity(0.18)),
                boxShadow: selected
                    ? [BoxShadow(color: WorkAppColors.primary.withOpacity(0.28), blurRadius: 10, offset: const Offset(0, 4))]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(selected ? Icons.check_rounded : Icons.location_on_outlined, size: 15, color: selected ? Colors.white : WorkAppColors.primaryDark),
                  const SizedBox(width: 6),
                  Text(region, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : WorkAppColors.primaryDark)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ClearFiltersButton extends StatelessWidget {
  final VoidCallback onPressed;
  const ClearFiltersButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.filter_alt_off_rounded, size: 15),
      label: const Text('Clear filters'),
      style: TextButton.styleFrom(
        foregroundColor: WorkAppColors.coralDark,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

class WorkResumePickerTile extends StatefulWidget {
  final ResumeFile? resume;
  final ValueChanged<ResumeFile?> onChanged;

  const WorkResumePickerTile({super.key, required this.resume, required this.onChanged});

  @override
  State<WorkResumePickerTile> createState() => _WorkResumePickerTileState();
}

class _WorkResumePickerTileState extends State<WorkResumePickerTile> {
  bool _hovering = false;

  Future<void> _pickFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        // Web has no filesystem path to hand to a multipart upload, so we
        // need the raw bytes there. Elsewhere the path is enough and
        // avoids loading the whole file into memory upfront.
        withData: kIsWeb,
      );
      if (result != null && result.files.isNotEmpty) {
        final f = result.files.single;
        widget.onChanged(ResumeFile(
          fileName: f.name,
          sizeBytes: f.size,
          bytes: kIsWeb ? f.bytes : null,
          path: kIsWeb ? null : f.path,
        ));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file picker. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resume = widget.resume;
    final hasResume = resume != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _pickFile(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: hasResume ? WorkAppColors.primarySurface : (_hovering ? WorkAppColors.primarySurface.withOpacity(0.6) : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasResume
                  ? WorkAppColors.primary
                  : (_hovering ? WorkAppColors.primary : WorkAppColors.primary.withOpacity(0.3)),
              width: hasResume || _hovering ? 1.6 : 1.2,
              style: hasResume ? BorderStyle.solid : BorderStyle.solid,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hasResume ? Colors.white : WorkAppColors.primarySurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  hasResume ? Icons.description_rounded : Icons.cloud_upload_rounded,
                  color: WorkAppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasResume ? resume.fileName : 'Drop your resume here, or tap to browse',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: WorkAppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasResume ? '${resume.sizeLabel} · Tap to replace' : 'PDF, DOC or DOCX · Required to apply',
                      style: const TextStyle(fontSize: 12, color: WorkAppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (hasResume)
                IconButton(
                  onPressed: () => widget.onChanged(null),
                  icon: const Icon(Icons.close_rounded, color: WorkAppColors.textSecondary),
                )
              else
                Icon(Icons.chevron_right_rounded, color: WorkAppColors.primary.withOpacity(_hovering ? 1 : 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Driver's license upload tile — identical UI/behavior to
/// [WorkResumePickerTile], just pointed at image/PDF license files instead
/// of resume documents.
class WorkLicensePickerTile extends StatefulWidget {
  final ResumeFile? license;
  final ValueChanged<ResumeFile?> onChanged;

  const WorkLicensePickerTile({super.key, required this.license, required this.onChanged});

  @override
  State<WorkLicensePickerTile> createState() => _WorkLicensePickerTileState();
}

class _WorkLicensePickerTileState extends State<WorkLicensePickerTile> {
  bool _hovering = false;

  Future<void> _pickFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        // Web has no filesystem path to hand to a multipart upload, so we
        // need the raw bytes there. Elsewhere the path is enough and
        // avoids loading the whole file into memory upfront.
        withData: kIsWeb,
      );
      if (result != null && result.files.isNotEmpty) {
        final f = result.files.single;
        widget.onChanged(ResumeFile(
          fileName: f.name,
          sizeBytes: f.size,
          bytes: kIsWeb ? f.bytes : null,
          path: kIsWeb ? null : f.path,
        ));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file picker. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final license = widget.license;
    final hasLicense = license != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _pickFile(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: hasLicense ? WorkAppColors.primarySurface : (_hovering ? WorkAppColors.primarySurface.withOpacity(0.6) : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasLicense
                  ? WorkAppColors.primary
                  : (_hovering ? WorkAppColors.primary : WorkAppColors.primary.withOpacity(0.3)),
              width: hasLicense || _hovering ? 1.6 : 1.2,
              style: hasLicense ? BorderStyle.solid : BorderStyle.solid,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hasLicense ? Colors.white : WorkAppColors.primarySurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  hasLicense ? Icons.badge_rounded : Icons.cloud_upload_rounded,
                  color: WorkAppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasLicense ? license.fileName : "Drop your driver's license here, or tap to browse",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: WorkAppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasLicense ? '${license.sizeLabel} · Tap to replace' : 'PDF, JPG or PNG · Required to apply',
                      style: const TextStyle(fontSize: 12, color: WorkAppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (hasLicense)
                IconButton(
                  onPressed: () => widget.onChanged(null),
                  icon: const Icon(Icons.close_rounded, color: WorkAppColors.textSecondary),
                )
              else
                Icon(Icons.chevron_right_rounded, color: WorkAppColors.primary.withOpacity(_hovering ? 1 : 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// COMPANY CARD (list + grid)
// ============================================================

class WorkCompanyCard extends StatefulWidget {
  final Company company;
  final VoidCallback onTap;
  final bool alreadyApplied;
  final bool gridMode;

  const WorkCompanyCard({
    super.key,
    required this.company,
    required this.onTap,
    this.alreadyApplied = false,
    this.gridMode = false,
  });

  @override
  State<WorkCompanyCard> createState() => _WorkCompanyCardState();
}

class _WorkCompanyCardState extends State<WorkCompanyCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final company = widget.company;
    final gradient = gradientForName(company.name);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..scale(_hovering ? 1.015 : 1.0),
          transformAlignment: Alignment.center,
          height: widget.gridMode ? 240 : null,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: WorkAppColors.primary.withOpacity(_hovering ? 0.22 : 0.08)),
            boxShadow: [
              BoxShadow(
                color: WorkAppColors.primaryDark.withOpacity(_hovering ? 0.12 : 0.05),
                blurRadius: _hovering ? 22 : 14,
                offset: Offset(0, _hovering ? 10 : 6),
              ),
            ],
          ),
          child: widget.gridMode ? _gridContent(company, gradient) : _listContent(company, gradient),
        ),
      ),
    );
  }

  Widget _badgeRow(Company company) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.alreadyApplied) _badge('Applied', Icons.check_circle_rounded, WorkAppColors.pending, WorkAppColors.pendingSurface),
        if (widget.alreadyApplied && company.isNew) const SizedBox(width: 6),
        if (company.isNew) _badge('New', Icons.auto_awesome_rounded, WorkAppColors.primaryDark, WorkAppColors.primarySurface),
      ],
    );
  }

  Widget _badge(String label, IconData icon, Color color, Color surface) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10.5)),
        ],
      ),
    ).animate().scale(duration: 260.ms, curve: Curves.elasticOut, begin: const Offset(0.6, 0.6), end: const Offset(1, 1));
  }

  Widget _logo(Company company, List<Color> gradient, double size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [BoxShadow(color: gradient.last.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Text(company.logoInitial, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.38)),
    );
  }

  Widget _listContent(Company company, List<Color> gradient) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _logo(company, gradient, 50),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(company.role, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: WorkAppColors.textPrimary))),
                  _badgeRow(company),
                ],
              ),
              const SizedBox(height: 3),
              Text(company.name, style: const TextStyle(color: WorkAppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  WorkMetaChip(icon: Icons.location_on_rounded, label: company.region),
                  WorkMetaChip(icon: Icons.work_outline_rounded, label: company.employmentType),
                  WorkMetaChip(icon: Icons.payments_outlined, label: company.salaryRange),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right_rounded, color: WorkAppColors.textSecondary),
      ],
    );
  }

  Widget _gridContent(Company company, List<Color> gradient) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _logo(company, gradient, 44),
            const Spacer(),
            _badgeRow(company),
          ],
        ),
        const SizedBox(height: 12),
        Text(company.role, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: WorkAppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Text(company.name, style: const TextStyle(color: WorkAppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        const Spacer(),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            WorkMetaChip(icon: Icons.location_on_rounded, label: company.region),
            WorkMetaChip(icon: Icons.work_outline_rounded, label: company.employmentType),
          ],
        ),
      ],
    );
  }
}

class WorkMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const WorkMetaChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: WorkAppColors.primarySurface, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: WorkAppColors.primaryDark),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: WorkAppColors.primaryDark)),
        ],
      ),
    );
  }
}

// ============================================================
// EMPTY / LOADING STATES
// ============================================================

class EmptyApplicationsState extends StatelessWidget {
  const EmptyApplicationsState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: WorkAppColors.primarySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WorkAppColors.primary.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: WorkAppColors.primary.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Icon(Icons.rocket_launch_rounded, color: WorkAppColors.primary, size: 26),
          ),
          const SizedBox(height: 12),
          const Text('Start your courier journey', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: WorkAppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(
            'Browse logistics companies below and submit your first application — it only takes a minute.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: WorkAppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 380.ms);
  }
}

class CompanyCardSkeleton extends StatelessWidget {
  const CompanyCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
      child: Row(
        children: [
          const ShimmerBox(height: 50, width: 50, radius: 15),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(height: 14, width: 140),
                SizedBox(height: 8),
                ShimmerBox(height: 11, width: 100),
                SizedBox(height: 12),
                ShimmerBox(height: 22, width: 200),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill badge in the app bar showing how many applications are on file,
/// with a counter that eases toward new values.
class AppliedBadge extends StatelessWidget {
  final int count;
  const AppliedBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: WorkAppColors.primaryGradient),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: WorkAppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          AnimatedCount(value: count, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(width: 3),
          const Text('applied', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white70)),
        ],
      ),
    );
  }
}

/// Bottom sheet opened from the floating action button — a compact list of
/// every application and its status, for a quick glance without scrolling.
class QuickTrackerSheet extends StatelessWidget {
  final List<JobApplication> applications;
  final void Function(JobApplication application) onViewResume;
  const QuickTrackerSheet({super.key, required this.applications, required this.onViewResume});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.track_changes_rounded, color: WorkAppColors.primary),
                  const SizedBox(width: 8),
                  const Text('Application tracker', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const Spacer(),
                  Text('${applications.length}', style: const TextStyle(color: WorkAppColors.textSecondary, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              if (applications.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No applications yet.', style: TextStyle(color: WorkAppColors.textSecondary)),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: applications.length,
                    separatorBuilder: (_, __) => const Divider(height: 18),
                    itemBuilder: (context, index) {
                      final a = applications[index];
                      return Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: a.status.color)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.company.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(a.status.label, style: TextStyle(fontSize: 11, color: a.status.color, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          if (a.hasResume)
                            IconButton(
                              onPressed: () => onViewResume(a),
                              icon: const Icon(Icons.description_outlined, size: 18, color: WorkAppColors.primary),
                            ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// WORK SCREEN (MAIN PAGE)
// ============================================================

class DriverWorkScreen extends StatefulWidget {
  final String accessToken;

  const DriverWorkScreen({super.key, required this.accessToken});

  @override
  State<DriverWorkScreen> createState() => _DriverWorkScreenState();
}

class _DriverWorkScreenState extends State<DriverWorkScreen> {
  static const _allRegions = 'All Regions';

  final ApiService _apiService = ApiService();
  List<String> _regions = const [_allRegions];
  List<Company> _companies = const [];
  String _selectedRegion = _allRegions;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final UserProfile _user = UserProfile();
  Timer? _searchDebounce;
  bool _isLoadingCompanies = true;
  String? _loadError;
  int _requestNumber = 0;
  String? _withdrawingApplicationId;
  EmploymentStatus? _employment;
  bool _resignationBusy = false;

  bool get _isEmployed => _employment?.isEmployed == true;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    _loadApplications();
    _loadEmploymentStatus();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    final requestNumber = ++_requestNumber;
    setState(() {
      _isLoadingCompanies = true;
      _loadError = null;
    });

    try {
      final response = await _apiService.getLogisticsCompanies(
        region: _selectedRegion == _allRegions ? null : _selectedRegion,
        search: _searchQuery,
      );

      final data = response['data'] as List? ?? const [];
      final companies = data
          .whereType<Map>()
          .map((item) => Company.fromApi(Map<String, dynamic>.from(item)))
          // The API only returns companies that are currently hiring; this
          // is a belt-and-braces guard in case an older backend is in play.
          .where((company) => company.isHiring)
          .toList();

      final meta = response['meta'] as Map? ?? {};
      final apiRegions = (meta['regions'] as List? ?? const [])
          .whereType<String>()
          .where((region) => region.trim().isNotEmpty)
          .toList();

      if (!mounted || requestNumber != _requestNumber) return;
      setState(() {
        _companies = companies;
        _regions = [_allRegions, ...apiRegions];
        _isLoadingCompanies = false;
      });
    } catch (e) {
      if (!mounted || requestNumber != _requestNumber) return;
      setState(() {
        _isLoadingCompanies = false;
        _loadError = 'Could not load logistics companies. Check that Laravel is running and try again.';
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadCompanies);
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedRegion = _allRegions;
    });
    _loadCompanies();
  }

  List<Company> get _filteredCompanies => _companies;

  bool get _hasActiveFilters => _selectedRegion != _allRegions || _searchQuery.trim().isNotEmpty;

  Future<void> _loadApplications() async {
    try {
      final response = await _apiService.getCourierApplications(accessToken: widget.accessToken);
      final applications = (response['data'] as List? ?? const [])
          .whereType<Map>()
          .where((item) => item['company'] is Map)
          .map((item) => JobApplication.fromApi(Map<String, dynamic>.from(item)))
          .where((application) => application.status != ApplicationStatus.withdrawn)
          .toList();
      if (!mounted) return;
      setState(() {
        _user.applications
          ..clear()
          ..addAll(applications);
      });
    } catch (_) {
      // Company browsing remains available if the saved application list
      // cannot be refreshed (for example, the user is not authenticated).
    }
  }

  bool _alreadyApplied(Company c) {
    return _user.applications.any((a) => a.company.id == c.id);
  }

  Future<void> _loadEmploymentStatus() async {
    try {
      final response = await _apiService.getCourierEmploymentStatus(accessToken: widget.accessToken);
      final data = response['data'];
      if (!mounted || data is! Map) return;
      setState(() {
        _employment = EmploymentStatus.fromApi(Map<String, dynamic>.from(data));
      });
    } catch (_) {
      // Employment status is a nice-to-have banner; browsing/applying still
      // works if it cannot be fetched.
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  /// Opens the "Request resignation" sheet — attach a letter (PDF/DOC/DOCX)
  /// and, optionally, a reason. On success the employer card switches to
  /// its "awaiting review" state.
  Future<void> _openResignationSheet() async {
    final result = await showModalBottomSheet<_ResignationDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ResignationRequestSheet(),
    );
    if (result == null || !mounted) return;

    setState(() => _resignationBusy = true);
    try {
      await _apiService.submitResignationRequest(
        accessToken: widget.accessToken,
        letterFileName: result.fileName,
        letterBytes: result.bytes,
        letterFilePath: result.filePath,
        reason: result.reason,
      );
      await _loadEmploymentStatus();
      if (mounted) {
        ResignationResultDialog.show(
          context,
          icon: Icons.mark_email_read_rounded,
          accent: WorkAppColors.employed,
          title: 'Resignation request sent',
          message: '${_employment?.companyName ?? 'Your employer'} will review your letter. You stay employed until they approve it.',
        );
      }
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not send the resignation request. Please try again.');
    } finally {
      if (mounted) setState(() => _resignationBusy = false);
    }
  }

  Future<void> _cancelResignation() async {
    final id = _employment?.pendingResignation?.id;
    if (id == null || id.isEmpty) return;

    final ok = await ResignationCancelConfirmDialog.show(context);
    if (ok != true || !mounted) return;

    setState(() => _resignationBusy = true);
    try {
      await _apiService.cancelResignationRequest(resignationRequestId: id, accessToken: widget.accessToken);
      await _loadEmploymentStatus();
      if (mounted) {
        ResignationResultDialog.show(
          context,
          icon: Icons.undo_rounded,
          accent: WorkAppColors.primary,
          title: 'Resignation request cancelled',
          message: 'Your request was withdrawn. You can submit a new one any time.',
        );
      }
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not cancel the request. Please try again.');
    } finally {
      if (mounted) setState(() => _resignationBusy = false);
    }
  }

  Future<void> _viewResignationLetter() async {
    final id = _employment?.pendingResignation?.id;
    if (id == null || id.isEmpty) return;
    try {
      final response = await _apiService.getResignationLetterUrl(resignationRequestId: id, accessToken: widget.accessToken);
      final url = response['url'] as String?;
      if (url == null || url.isEmpty) throw Exception('Missing letter URL.');
      if (!mounted) return;
      Navigator.of(context).push(fadeSlideRoute(
        DocumentViewerScreen(title: 'Resignation Letter', url: url),
      ));
    } catch (_) {
      _snack('Could not open the resignation letter. Please try again.');
    }
  }

  Future<void> _viewResume(JobApplication application) async {
    try {
      final response = await _apiService.getCourierApplicationResume(
        applicationId: application.id,
        accessToken: widget.accessToken,
      );
      final url = response['url'] as String?;
      final uri = url == null ? null : Uri.tryParse(url);
      if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch resume URL.');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open your resume. Please try again.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _viewLicense(JobApplication application) async {
    try {
      final response = await _apiService.getCourierApplicationLicense(
        applicationId: application.id,
        accessToken: widget.accessToken,
      );
      final url = response['url'] as String?;
      final uri = url == null ? null : Uri.tryParse(url);
      if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception("Could not launch driver's license URL.");
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open your driver's license. Please try again."), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _showQuickTracker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => QuickTrackerSheet(applications: _user.applications, onViewResume: _viewResume),
    );
  }

  Future<void> _openApply(Company company) async {
    final result = await Navigator.of(context).push<JobApplication>(
      fadeSlideRoute(
        _ApplyPage(
          company: company,
          userProfile: _user,
          submitApplication: _submitApplication,
          viewResume: _viewResume,
          viewLicense: _viewLicense,
          similarCompanies: _companies.where((c) => c.id != company.id).toList(),
          onSelectSimilar: _openApply,
        ),
      ),
    );

    if (result != null) {
      setState(() => _user.applications.insert(0, result));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: WorkAppColors.primaryDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text('Application sent to ${company.name}. Status: Pending.'),
          ),
        );
      }
    }
  }

  Future<JobApplication> _submitApplication(
    Company company,
    ResumeFile resume,
    ResumeFile license,
    String? coverNote,
  ) async {
    final response = await _apiService.submitCourierApplication(
      logisticsCompanyId: company.id,
      accessToken: widget.accessToken,
      resumeFileName: resume.fileName,
      resumeBytes: resume.bytes,
      resumeFilePath: resume.path,
      licenseFileName: license.fileName,
      licenseBytes: license.bytes,
      licenseFilePath: license.path,
      coverNote: coverNote,
    );

    final application = response['data'];
    if (application is! Map) {
      throw ApiException(message: 'The server returned an invalid application response.', statusCode: 500);
    }

    return JobApplication.fromApi(Map<String, dynamic>.from(application));
  }

  Future<void> _withdrawApplication(JobApplication application) async {
    if (application.status != ApplicationStatus.pending || _withdrawingApplicationId != null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Withdraw application?'),
        content: Text('Your pending application to ${application.company.name} will be withdrawn.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep application')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WorkAppColors.rejected),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _withdrawingApplicationId = application.id);
    try {
      await _apiService.withdrawCourierApplication(applicationId: application.id, accessToken: widget.accessToken);
      if (!mounted) return;
      setState(() => _user.applications.removeWhere((a) => a.id == application.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application withdrawn.'), behavior: SnackBarBehavior.floating),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message), behavior: SnackBarBehavior.floating));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not withdraw the application. Please try again.'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _withdrawingApplicationId = null);
    }
  }

  int get _appliedCount => _user.applications.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkAppColors.background,
      floatingActionButton: _user.applications.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _showQuickTracker,
              backgroundColor: WorkAppColors.primary,
              icon: const Icon(Icons.track_changes_rounded),
              label: Text('Track ($_appliedCount)'),
            ).animate().scale(delay: 300.ms, duration: 300.ms, curve: Curves.easeOutBack),
      body: LayoutBuilder(
        builder: (context, constraints) => _buildContent(constraints.maxWidth),
      ),
    );
  }

  Widget _buildContent(double width) {
    final isDesktop = width >= 760;
    final crossAxisCount = width >= 1200 ? 3 : (width >= 760 ? 2 : 1);
    final horizontalPadding = isDesktop ? 40.0 : 20.0;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 68,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.78),
                  border: Border(bottom: BorderSide(color: WorkAppColors.primary.withOpacity(0.06))),
                ),
              ),
            ),
          ),
          leadingWidth: 60,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
          ),
          title: const Text('Find Work', style: TextStyle(color: WorkAppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
          centerTitle: false,
          actions: [
            Padding(padding: const EdgeInsets.only(right: 16), child: AppliedBadge(count: _appliedCount)),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isEmployed) ...[
                  EmploymentBanner(
                    employment: _employment!,
                    busy: _resignationBusy,
                    onRequestResignation: _openResignationSheet,
                    onCancelResignation: _cancelResignation,
                    onViewLetter: _viewResignationLetter,
                  ),
                  const SizedBox(height: 16),
                ],

                ApplicationSummaryCards(applications: _user.applications),

                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Your applications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    if (_user.applications.isNotEmpty)
                      Text('${_user.applications.length}', style: const TextStyle(color: WorkAppColors.textSecondary, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                if (_user.applications.isEmpty)
                  const EmptyApplicationsState()
                else
                  ..._user.applications.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: WorkApplicationStatusCard(
                        application: a,
                        onWithdraw: () => _withdrawApplication(a),
                        isWithdrawing: _withdrawingApplicationId == a.id,
                        onViewResume: a.hasResume ? () => _viewResume(a) : null,
                      ),
                    ),
                  ),

                if (!_isEmployed) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Available logistics companies', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    if (_hasActiveFilters) ClearFiltersButton(onPressed: _clearFilters),
                  ],
                ),
                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: WorkAppColors.primary.withOpacity(0.10)),
                    boxShadow: [BoxShadow(color: WorkAppColors.primaryDark.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 6))],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search company or email',
                      hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500),
                      prefixIcon: const Icon(Icons.search_rounded, color: WorkAppColors.primary, size: 22),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.mic_none_rounded, color: WorkAppColors.primary),
                        tooltip: 'Voice search',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Voice search is coming soon.'), behavior: SnackBarBehavior.floating),
                          );
                        },
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                WorkRegionFilterChips(
                  regions: _regions,
                  selectedRegion: _selectedRegion,
                  onSelected: (r) {
                    setState(() => _selectedRegion = r);
                    _loadCompanies();
                  },
                ),
                const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
        if (_isEmployed)
          const SliverToBoxAdapter(child: SizedBox(height: 24))
        else if (_isLoadingCompanies)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 24),
            sliver: SliverList.separated(
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => const CompanyCardSkeleton(),
            ),
          )
        else if (_loadError != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: WorkAppColors.primary, size: 48),
                    const SizedBox(height: 14),
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(onPressed: _loadCompanies, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
                  ],
                ),
              ),
            ),
          )
        else if (_filteredCompanies.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.search_off_rounded, color: WorkAppColors.primary, size: 48),
                    const SizedBox(height: 14),
                    Text(
                      'No logistics companies match your filters right now.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: WorkAppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                    if (_hasActiveFilters) ...[
                      const SizedBox(height: 12),
                      ClearFiltersButton(onPressed: _clearFilters),
                    ],
                  ],
                ),
              ),
            ),
          )
        else if (crossAxisCount == 1)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 100),
            sliver: SliverList.separated(
              itemCount: _filteredCompanies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final company = _filteredCompanies[index];
                return WorkCompanyCard(
                  company: company,
                  alreadyApplied: _alreadyApplied(company),
                  onTap: () => _openApply(company),
                ).animate().fadeIn(delay: (index * 40).ms, duration: 320.ms).slideY(begin: 0.05, end: 0);
              },
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 100),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: 240,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final company = _filteredCompanies[index];
                  return WorkCompanyCard(
                    company: company,
                    alreadyApplied: _alreadyApplied(company),
                    onTap: () => _openApply(company),
                    gridMode: true,
                  ).animate().fadeIn(delay: (index * 40).ms, duration: 320.ms).slideY(begin: 0.05, end: 0);
                },
                childCount: _filteredCompanies.length,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// APPLY PAGE WIDGETS
// ============================================================

/// Horizontal 3-step progress indicator for the apply wizard.
class StepIndicator extends StatelessWidget {
  final int currentStep;
  const StepIndicator({super.key, required this.currentStep});

  static const _labels = ['Resume', 'Cover Note', 'Review'];

  @override
  Widget build(BuildContext context) {
    Widget node(int i) {
      final active = i <= currentStep;
      final isCurrent = i == currentStep;
      final isDone = i < currentStep;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: isCurrent ? 30 : 26,
            height: isCurrent ? 30 : 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: active ? const LinearGradient(colors: WorkAppColors.primaryGradient) : null,
              color: active ? null : Colors.grey.shade200,
              boxShadow: isCurrent ? [BoxShadow(color: WorkAppColors.primary.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3))] : null,
            ),
            alignment: Alignment.center,
            child: isDone
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
                : Text('${i + 1}', style: TextStyle(color: active ? Colors.white : Colors.grey[500], fontWeight: FontWeight.w800, fontSize: 12)),
          ),
          const SizedBox(height: 5),
          Text(_labels[i], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? WorkAppColors.primaryDark : Colors.grey[400])),
        ],
      );
    }

    Widget line(int i) {
      final on = i < currentStep;
      return Expanded(child: Container(margin: const EdgeInsets.only(bottom: 17), height: 2, color: on ? WorkAppColors.primary : Colors.grey.shade200));
    }

    return Row(children: [node(0), line(0), node(1), line(1), node(2)]);
  }
}

class _TimelineStep {
  final String label;
  final String detail;
  final bool done;
  const _TimelineStep(this.label, this.detail, this.done);
}

/// Vertical progress timeline for an application that's already been
/// submitted (shown in the apply page once a courier has applied).
class VerticalStatusTimeline extends StatelessWidget {
  final JobApplication application;
  const VerticalStatusTimeline({super.key, required this.application});

  @override
  Widget build(BuildContext context) {
    final status = application.status;
    final awaitingReview = status == ApplicationStatus.pending &&
        application.interviewInvitedAt == null &&
        application.interviewScheduledAt == null;

    final steps = <_TimelineStep>[
      _TimelineStep('Application submitted', formatDateTime(application.submittedAt), true),
      _TimelineStep('Under review', awaitingReview ? 'In progress' : 'Completed', true),
      if (application.interviewScheduledAt != null || application.interviewInvitedAt != null)
        _TimelineStep(
          'Interview',
          application.interviewScheduledAt != null ? formatDateTime(application.interviewScheduledAt!) : 'Invited',
          true,
        ),
      _TimelineStep(
        status == ApplicationStatus.rejected
            ? 'Application rejected'
            : status == ApplicationStatus.employed
                ? 'Application accepted'
                : 'Awaiting decision',
        status == ApplicationStatus.pending ? 'Pending' : (application.reviewedAt != null ? formatDateTime(application.reviewedAt!) : ''),
        status != ApplicationStatus.pending,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length, (i) {
        final step = steps[i];
        final isLast = i == steps.length - 1;
        final dotColor = !step.done ? Colors.grey.shade300 : (isLast ? status.color : WorkAppColors.primary);
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [BoxShadow(color: dotColor.withOpacity(0.4), blurRadius: 4)],
                    ),
                  ),
                  if (!isLast) Expanded(child: Container(width: 2, color: step.done ? WorkAppColors.primary.withOpacity(0.3) : Colors.grey.shade200)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: step.done ? WorkAppColors.textPrimary : Colors.grey[400])),
                      if (step.detail.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(step.detail, style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ============================================================
// APPLY PAGE (MAIN)
// ============================================================

class _ApplyPage extends StatefulWidget {
  final Company company;
  final UserProfile userProfile;
  final Future<JobApplication> Function(
    Company company,
    ResumeFile resume,
    ResumeFile license,
    String? coverNote,
  ) submitApplication;
  final Future<void> Function(JobApplication application)? viewResume;
  final Future<void> Function(JobApplication application)? viewLicense;
  final List<Company> similarCompanies;
  final void Function(Company company)? onSelectSimilar;

  const _ApplyPage({
    required this.company,
    required this.userProfile,
    required this.submitApplication,
    this.viewResume,
    this.viewLicense,
    this.similarCompanies = const [],
    this.onSelectSimilar,
  });

  @override
  State<_ApplyPage> createState() => __ApplyPageState();
}

class __ApplyPageState extends State<_ApplyPage> {
  ResumeFile? _resume;
  ResumeFile? _license;
  final _coverController = TextEditingController();
  bool _submitting = false;
  bool _hasApplied = false;
  bool _isLoading = true;
  ApplicationStatus? _applicationStatus;
  JobApplication? _existingApplication;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _checkIfApplied();
  }

  @override
  void dispose() {
    _coverController.dispose();
    super.dispose();
  }

  Future<void> _checkIfApplied() async {
    await Future.delayed(const Duration(milliseconds: 300));

    final matches = widget.userProfile.applications.where((a) => a.company.id == widget.company.id);
    final application = matches.isEmpty ? null : matches.first;

    setState(() {
      _existingApplication = application;
      _applicationStatus = application?.status;
      _hasApplied = application != null;
      _isLoading = false;
    });
  }

  void _goToStep(int step) {
    if (step > _step && _step == 0 && _resume == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach your resume to continue.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (step > _step && _step == 0 && _license == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please attach your driver's license to continue."), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _step = step);
  }

  Future<void> _submit() async {
    if (_resume == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach your resume before applying.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (_license == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please attach your driver's license before applying."), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final application = await widget.submitApplication(
        widget.company,
        _resume!,
        _license!,
        _coverController.text.trim().isEmpty ? null : _coverController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(application);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message), behavior: SnackBarBehavior.floating));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit your application. Please try again.'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = widget.company;

    return Scaffold(
      backgroundColor: WorkAppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: WorkAppColors.primary))
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                return CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      backgroundColor: Colors.white,
                      elevation: 0,
                      leading: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
                      ),
                      title: const Text('Job Details', style: TextStyle(color: WorkAppColors.textPrimary, fontWeight: FontWeight.w800)),
                      actions: [_statusPill(company)],
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(isWide ? 40 : 20, 20, isWide ? 40 : 20, 24),
                      sliver: SliverToBoxAdapter(child: isWide ? _wideLayout(company) : _narrowLayout(company)),
                    ),
                  ],
                );
              },
            ),
      bottomNavigationBar: _isLoading ? null : _bottomBar(),
    );
  }

  Widget _statusPill(Company company) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _hasApplied
            ? (_applicationStatus == ApplicationStatus.pending
                ? WorkAppColors.pendingSurface
                : _applicationStatus == ApplicationStatus.rejected
                    ? WorkAppColors.rejectedSurface
                    : WorkAppColors.employedSurface)
            : WorkAppColors.primarySurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _hasApplied
                  ? (_applicationStatus == ApplicationStatus.pending
                      ? WorkAppColors.pending
                      : _applicationStatus == ApplicationStatus.rejected
                          ? WorkAppColors.rejected
                          : WorkAppColors.employed)
                  : WorkAppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _hasApplied
                ? (_applicationStatus == ApplicationStatus.pending
                    ? 'Application Pending'
                    : _applicationStatus == ApplicationStatus.rejected
                        ? 'Application Rejected'
                        : 'Application Accepted')
                : 'Hiring',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _hasApplied
                  ? (_applicationStatus == ApplicationStatus.pending
                      ? WorkAppColors.pending
                      : _applicationStatus == ApplicationStatus.rejected
                          ? WorkAppColors.rejected
                          : WorkAppColors.employed)
                  : WorkAppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _wideLayout(Company company) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _jobDetailsColumn(company)),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: _applicationFormColumn(company)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _similarJobsSection(),
      ],
    );
  }

  Widget _narrowLayout(Company company) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _jobDetailsColumn(company),
        const SizedBox(height: 20),
        _applicationFormColumn(company),
        const SizedBox(height: 28),
        _similarJobsSection(),
      ],
    );
  }

  Widget _jobDetailsColumn(Company company) {
    final gradient = gradientForName(company.name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: WorkAppColors.primary.withOpacity(0.08)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 5))],
          ),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: gradient.last.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
                ),
                child: Text(company.logoInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28)),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(company.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: WorkAppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(company.role, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: WorkAppColors.textSecondary)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _infoBadge(Icons.location_on_rounded, company.region),
                        _infoBadge(Icons.work_outline_rounded, company.employmentType),
                        if (company.isNew) _infoBadge(Icons.auto_awesome_rounded, 'New listing'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          icon: Icons.info_outline_rounded,
          title: 'About this role',
          child: Text(
            company.description.isEmpty ? 'No additional description provided by this company yet.' : company.description,
            style: const TextStyle(fontSize: 14, height: 1.6, color: WorkAppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          icon: Icons.dashboard_outlined,
          title: 'Key details',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _detailChip(Icons.category_outlined, 'Industry', company.industry),
              _detailChip(Icons.payments_outlined, 'Salary', company.salaryRange),
              if (company.contactNumber != null && company.contactNumber!.isNotEmpty) _detailChip(Icons.phone_rounded, 'Contact', company.contactNumber!),
              if (company.email != null && company.email!.isNotEmpty) _detailChip(Icons.email_rounded, 'Email', company.email!),
            ],
          ),
        ),
      ],
    );
  }

  Widget _applicationFormColumn(Company company) {
    if (_hasApplied) return _appliedStatusCard();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Apply now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: WorkAppColors.textPrimary)),
          const SizedBox(height: 16),
          StepIndicator(currentStep: _step),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(animation), child: child),
            ),
            child: KeyedSubtree(key: ValueKey(_step), child: _stepContent()),
          ),
        ],
      ),
    );
  }

  Widget _stepContent() {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Upload your resume', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: WorkAppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('PDF, DOC or DOCX — required to apply.', style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
            const SizedBox(height: 12),
            WorkResumePickerTile(resume: _resume, onChanged: (r) => setState(() => _resume = r)),
            const SizedBox(height: 20),
            const Text("Upload your driver's license", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: WorkAppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('PDF, JPG or PNG — required to apply.', style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
            const SizedBox(height: 12),
            WorkLicensePickerTile(license: _license, onChanged: (l) => setState(() => _license = l)),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cover note (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: WorkAppColors.textPrimary)),
            const SizedBox(height: 4),
            Text("Tell the hiring team briefly why you're a good fit.", style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
            const SizedBox(height: 12),
            TextField(
              controller: _coverController,
              minLines: 5,
              maxLines: 8,
              maxLength: 2000,
              decoration: InputDecoration(
                hintText: 'I have 2 years of delivery experience and my own motorcycle...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: WorkAppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ],
        );
      default:
        return _reviewStep();
    }
  }

  Widget _reviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Review your application', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: WorkAppColors.textPrimary)),
        const SizedBox(height: 12),
        _reviewRow(Icons.description_rounded, 'Resume', _resume?.fileName ?? 'Not attached'),
        const SizedBox(height: 10),
        _reviewRow(Icons.badge_rounded, "Driver's license", _license?.fileName ?? 'Not attached'),
        const SizedBox(height: 10),
        _reviewRow(Icons.edit_note_rounded, 'Cover note', _coverController.text.trim().isEmpty ? 'Not added' : _coverController.text.trim()),
        const SizedBox(height: 10),
        _reviewRow(Icons.apartment_rounded, 'Applying to', '${widget.company.name} · ${widget.company.role}'),
      ],
    );
  }

  Widget _reviewRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: WorkAppColors.primarySurface, borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 14, color: WorkAppColors.primaryDark),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.grey[500])),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: WorkAppColors.textPrimary), maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _appliedStatusCard() {
    final status = _applicationStatus ?? ApplicationStatus.pending;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: status.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color.withOpacity(0.25), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(status.icon, color: status.color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status == ApplicationStatus.pending
                      ? 'Application ongoing'
                      : status == ApplicationStatus.rejected
                          ? 'Application rejected'
                          : 'Application accepted',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: WorkAppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_existingApplication != null) VerticalStatusTimeline(application: _existingApplication!),
          if (status == ApplicationStatus.rejected && _existingApplication?.rejectionReason != null) ...[
            const SizedBox(height: 12),
            InfoLine(icon: Icons.info_outline_rounded, color: WorkAppColors.rejected, text: 'Reason: ${_existingApplication!.rejectionReason}'),
          ],
          if ((_existingApplication?.hasResume == true && widget.viewResume != null) ||
              (_existingApplication?.hasLicense == true && widget.viewLicense != null)) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (_existingApplication?.hasResume == true && widget.viewResume != null)
                  OutlinedButton.icon(
                    onPressed: () => widget.viewResume!(_existingApplication!),
                    icon: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('View submitted resume'),
                    style: OutlinedButton.styleFrom(foregroundColor: WorkAppColors.primaryDark, side: BorderSide(color: WorkAppColors.primary.withOpacity(0.4))),
                  ),
                if (_existingApplication?.hasLicense == true && widget.viewLicense != null)
                  OutlinedButton.icon(
                    onPressed: () => widget.viewLicense!(_existingApplication!),
                    icon: const Icon(Icons.badge_outlined, size: 16),
                    label: const Text('View submitted license'),
                    style: OutlinedButton.styleFrom(foregroundColor: WorkAppColors.primaryDark, side: BorderSide(color: WorkAppColors.primary.withOpacity(0.4))),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _similarJobsSection() {
    if (widget.similarCompanies.isEmpty) return const SizedBox.shrink();
    final items = widget.similarCompanies.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Similar jobs', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: WorkAppColors.textPrimary)),
        const SizedBox(height: 4),
        Text('Other logistics companies hiring couriers right now', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final c = items[index];
              final gradient = gradientForName(c.name);
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onSelectSimilar?.call(c);
                },
                child: Container(
                  width: 160,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(gradient: LinearGradient(colors: gradient), borderRadius: BorderRadius.circular(11)),
                        child: Text(c.logoInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                      const Spacer(),
                      Text(c.role, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(c.name, style: TextStyle(fontSize: 11, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 11, color: Colors.grey[400]),
                          const SizedBox(width: 2),
                          Expanded(child: Text(c.region, style: TextStyle(fontSize: 10, color: Colors.grey[400]), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required IconData icon, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 18, color: WorkAppColors.primary), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: WorkAppColors.textPrimary))]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _hasApplied
              ? OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WorkAppColors.primary,
                    side: BorderSide(color: WorkAppColors.primary.withOpacity(0.5), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    minimumSize: const Size(double.infinity, 54),
                  ),
                  child: const Text('Application Submitted', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                )
              : (_step < 2 ? _wizardNav() : _submitButton()),
        ),
      ),
    );
  }

  Widget _wizardNav() {
    return Row(
      children: [
        if (_step > 0)
          OutlinedButton.icon(
            onPressed: () => _goToStep(_step - 1),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Back'),
            style: OutlinedButton.styleFrom(
              foregroundColor: WorkAppColors.primaryDark,
              side: BorderSide(color: WorkAppColors.primary.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            ),
          )
        else
          const SizedBox.shrink(),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () => _goToStep(_step + 1),
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          label: const Text('Next'),
          style: ElevatedButton.styleFrom(
            backgroundColor: WorkAppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _submitButton() {
    final missingLabel = _resume == null
        ? 'Attach Resume to Apply'
        : (_license == null ? "Attach Driver's License to Apply" : null);
    return ElevatedButton.icon(
      onPressed: _submitting || missingLabel != null ? null : _submit,
      icon: _submitting
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
          : const Icon(Icons.send_rounded, size: 20),
      label: Text(
        _submitting ? 'Submitting...' : (missingLabel ?? 'Submit Application'),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(double.infinity, 54),
      ),
    );
  }

  Widget _infoBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: WorkAppColors.primarySurface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: WorkAppColors.primary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: WorkAppColors.primary)),
        ],
      ),
    );
  }

  Widget _detailChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: WorkAppColors.primarySurface, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: WorkAppColors.primary),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.w600)),
              Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: WorkAppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}
