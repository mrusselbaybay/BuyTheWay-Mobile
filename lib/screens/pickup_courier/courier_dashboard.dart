import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/common.dart';
import '../../widgets/navigation/courier_navbar.dart';

const Color _teal = Color(0xFF0D9488);
const Color _tealDark = Color(0xFF0F766E);

// ============================================================
// MOCK DATA MODELS
// ------------------------------------------------------------
// No backend endpoints exist yet for shifts, pickups, earnings or the
// driver profile — these shapes mirror what a future API would return so
// the screens below can be rewired to real data without a UI rewrite.
// ============================================================

enum PickupPriority { high, normal, low }

extension PickupPriorityX on PickupPriority {
  String get label {
    switch (this) {
      case PickupPriority.high:
        return 'Priority';
      case PickupPriority.normal:
        return 'Standard';
      case PickupPriority.low:
        return 'Flexible';
    }
  }

  Color get color {
    switch (this) {
      case PickupPriority.high:
        return const Color(0xFFEF4444);
      case PickupPriority.normal:
        return AppColors.teal600;
      case PickupPriority.low:
        return AppColors.slate400;
    }
  }
}

enum PickupStatus { ready, notReady, completed }

class PickupTask {
  final String id;
  final String seller;
  final int parcels;
  final double distanceKm;
  final int etaMinutes;
  final String time;
  PickupStatus status;
  final String address;
  final PickupPriority priority;

  PickupTask({
    required this.id,
    required this.seller,
    required this.parcels,
    required this.distanceKm,
    required this.etaMinutes,
    required this.time,
    required this.status,
    required this.address,
    this.priority = PickupPriority.normal,
  });
}

class DriverProfile {
  final String name;
  final double rating;
  final String vehicle;
  final String plateNumber;
  final String hub;
  final String phone;
  final String email;
  final int completedDeliveries;
  final double onTimeRate;
  final double acceptanceRate;
  final DateTime joinedAt;

  const DriverProfile({
    required this.name,
    required this.rating,
    required this.vehicle,
    required this.plateNumber,
    required this.hub,
    required this.phone,
    required this.email,
    required this.completedDeliveries,
    required this.onTimeRate,
    required this.acceptanceRate,
    required this.joinedAt,
  });
}

List<PickupTask> mockTasks() => [
      PickupTask(
        id: 't1',
        seller: 'Shop ABC',
        parcels: 5,
        distanceKm: 2.3,
        etaMinutes: 9,
        time: '10:30 AM',
        status: PickupStatus.ready,
        address: '123 Main St, Brgy. San Juan',
        priority: PickupPriority.high,
      ),
      PickupTask(
        id: 't2',
        seller: 'Store XYZ',
        parcels: 3,
        distanceKm: 3.1,
        etaMinutes: 12,
        time: '11:00 AM',
        status: PickupStatus.ready,
        address: '456 Rizal Ave, QC',
        priority: PickupPriority.normal,
      ),
      PickupTask(
        id: 't3',
        seller: 'Market 123',
        parcels: 2,
        distanceKm: 1.8,
        etaMinutes: 7,
        time: '11:30 AM',
        status: PickupStatus.notReady,
        address: '789 Market St, Mandaluyong',
        priority: PickupPriority.low,
      ),
      PickupTask(
        id: 't4',
        seller: 'Fresh Grocer',
        parcels: 4,
        distanceKm: 4.6,
        etaMinutes: 16,
        time: '12:15 PM',
        status: PickupStatus.notReady,
        address: '22 Aurora Blvd, Cubao',
        priority: PickupPriority.normal,
      ),
    ];

final driverProfile = DriverProfile(
  name: 'Juan Dela Cruz',
  rating: 4.9,
  vehicle: 'Honda Click 125i',
  plateNumber: 'NBC 2245',
  hub: 'J&T Express · Manila Hub',
  phone: '+63 917 123 4567',
  email: 'juan.delacruz@nexmart.ph',
  completedDeliveries: 1284,
  onTimeRate: 0.97,
  acceptanceRate: 0.94,
  joinedAt: DateTime.utc(2023, 3, 14),
);

// ============================================================
// SHARED WIDGETS
// ============================================================

/// Title + optional trailing text-button action, used above every list on
/// the dashboard.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.slate800)),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: AppColors.teal600, padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Text(actionLabel!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

/// A small glass stat tile for the header's horizontal metrics strip.
class MetricChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final double? trend;

  const MetricChip({super.key, required this.icon, required this.value, required this.label, this.trend});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: Colors.white),
              const Spacer(),
              if (trend != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      trend! >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 11,
                      color: trend! >= 0 ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5),
                    ),
                    Text(
                      '${trend!.abs().toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: trend! >= 0 ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5)),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 10.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final PickupStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    late final IconData icon;
    switch (status) {
      case PickupStatus.ready:
        label = 'Ready';
        color = AppColors.successGreen;
        icon = Icons.check_circle_rounded;
        break;
      case PickupStatus.notReady:
        label = 'Not Ready';
        color = const Color(0xFFF59E0B);
        icon = Icons.hourglass_top_rounded;
        break;
      case PickupStatus.completed:
        label = 'Picked Up';
        color = AppColors.slate400;
        icon = Icons.done_all_rounded;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 11, color: color), const SizedBox(width: 3), Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700))],
      ),
    );
  }
}

/// Reusable pickup card with a priority-colored left border, a status
/// badge, and swipe-to-complete / swipe-to-mark-ready gestures. [compact]
/// hides the explicit action buttons (used in the Home screen's condensed
/// "Today's Pickups" list) so only the swipe gesture remains; the full
/// Pickups manifest keeps both.
class PickupTaskCard extends StatelessWidget {
  final PickupTask task;
  final VoidCallback? onComplete;
  final VoidCallback? onMarkReady;
  final VoidCallback? onContact;
  final bool compact;

  const PickupTaskCard({
    super.key,
    required this.task,
    this.onComplete,
    this.onMarkReady,
    this.onContact,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isReady = task.status == PickupStatus.ready;
    final isCompleted = task.status == PickupStatus.completed;

    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(left: BorderSide(color: task.priority.color, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(child: Text(task.seller, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15), overflow: TextOverflow.ellipsis)),
                      if (task.priority == PickupPriority.high) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.bolt_rounded, size: 14, color: task.priority.color),
                      ],
                    ],
                  ),
                ),
                _StatusBadge(status: task.status),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.place_rounded, size: 13, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Expanded(child: Text(task.address, style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _metaPill(Icons.inventory_2_rounded, '${task.parcels} parcels'),
                _metaPill(Icons.route_rounded, '${task.distanceKm.toStringAsFixed(1)} km'),
                _metaPill(Icons.timer_rounded, '${task.etaMinutes} min · ${task.time}'),
              ],
            ),
            if (!compact && !isCompleted) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onContact,
                      icon: const Icon(Icons.call_outlined, size: 15),
                      label: const Text('Contact'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.slate700,
                        side: const BorderSide(color: AppColors.slate300),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isReady ? onComplete : onMarkReady,
                      icon: Icon(isReady ? Icons.check_circle_outline_rounded : Icons.notifications_active_outlined, size: 15),
                      label: Text(isReady ? 'Pick Up' : 'Mark Ready'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isReady ? AppColors.teal600 : const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    final canSwipeComplete = isReady && onComplete != null;
    final canSwipeReady = task.status == PickupStatus.notReady && onMarkReady != null;
    if (!canSwipeComplete && !canSwipeReady) return card;

    return Dismissible(
      key: ValueKey('task-${task.id}'),
      direction: DismissDirection.startToEnd,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: canSwipeComplete ? AppColors.successGreen : const Color(0xFFF59E0B),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(canSwipeComplete ? Icons.check_circle_rounded : Icons.notifications_active_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(canSwipeComplete ? 'Picked up' : 'Mark ready', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        if (canSwipeComplete) {
          onComplete?.call();
        } else {
          onMarkReady?.call();
        }
        return false; // snap back — swiping only triggers the action
      },
      child: card,
    );
  }

  Widget _metaPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppColors.teal50, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 11, color: AppColors.teal700), const SizedBox(width: 3), Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.teal700))],
      ),
    );
  }
}

/// Shimmer skeleton for a [PickupTaskCard]-shaped slot, shown during the
/// simulated initial load.
class TaskCardSkeleton extends StatefulWidget {
  const TaskCardSkeleton({super.key});

  @override
  State<TaskCardSkeleton> createState() => _TaskCardSkeletonState();
}

class _TaskCardSkeletonState extends State<TaskCardSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _bar(double width, double height) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 + t * 3, 0),
                end: Alignment(0 + t * 3, 0),
                colors: [AppColors.slate100, Colors.grey.shade50, AppColors.slate100],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.slate100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bar(140, 14),
          const SizedBox(height: 8),
          _bar(200, 11),
          const SizedBox(height: 12),
          _bar(double.infinity, 22),
        ],
      ),
    );
  }
}

// ============================================================
// COURIER DASHBOARD (SHELL)
// ------------------------------------------------------------
// Owns the shift/task state so it survives tab switches (a task picked
// up on Home immediately reflects on the Pickups manifest, and the nav
// bar's badge count always matches).
// ============================================================

class CourierDashboard extends StatefulWidget {
  const CourierDashboard({super.key});

  @override
  State<CourierDashboard> createState() => _CourierDashboardState();
}

class _CourierDashboardState extends State<CourierDashboard> {
  // Nav order matches CourierNavBar indices: 0 Salary, 1 Home, 2 Pickups
  int _currentIndex = 1;
  bool _isOnDuty = true;
  final DateTime _shiftStart = DateTime.now().subtract(const Duration(hours: 4, minutes: 32));
  late List<PickupTask> _tasks = mockTasks();

  int get _pendingCount => _tasks.where((t) => t.status != PickupStatus.completed).length;

  void _toggleDuty() => setState(() => _isOnDuty = !_isOnDuty);

  void _completeTask(PickupTask task) {
    setState(() => task.status = PickupStatus.completed);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${task.seller} marked as picked up.'), behavior: SnackBarBehavior.floating, backgroundColor: _tealDark),
    );
  }

  void _markReady(PickupTask task) {
    setState(() => task.status = PickupStatus.ready);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${task.seller} marked ready for pickup.'), behavior: SnackBarBehavior.floating, backgroundColor: _tealDark),
    );
  }

  Future<void> _refreshTasks() async {
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _tasks = mockTasks());
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const SalaryScreen(),
      HomeScreen(
        tasks: _tasks,
        isOnDuty: _isOnDuty,
        shiftStart: _shiftStart,
        onToggleDuty: _toggleDuty,
        onComplete: _completeTask,
        onMarkReady: _markReady,
        onRefresh: _refreshTasks,
      ),
      PickupsScreen(tasks: _tasks, onComplete: _completeTask, onMarkReady: _markReady, onRefresh: _refreshTasks),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: pages),
      floatingActionButton: _dashboardFab(),
      bottomNavigationBar: CourierNavBar(
        currentIndex: _currentIndex,
        pendingPickups: _tasks.where((t) => t.status == PickupStatus.ready).length,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }

  Widget? _dashboardFab() {
    if (_currentIndex == 1) {
      return FloatingActionButton.extended(
        onPressed: _toggleDuty,
        backgroundColor: _isOnDuty ? const Color(0xFFEF4444) : AppColors.teal600,
        icon: Icon(_isOnDuty ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded),
        label: Text(_isOnDuty ? 'End Shift' : 'Go On Duty'),
      );
    }
    if (_currentIndex == 2 && _pendingCount > 0) {
      return FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.selectionClick();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Route optimization is coming soon.'), behavior: SnackBarBehavior.floating),
          );
        },
        backgroundColor: AppColors.teal600,
        icon: const Icon(Icons.alt_route_rounded),
        label: const Text('Optimize route'),
      );
    }
    return null;
  }
}

// ============================================================
// HOME SCREEN (Dashboard)
// ============================================================

class HomeScreen extends StatefulWidget {
  final List<PickupTask> tasks;
  final bool isOnDuty;
  final DateTime shiftStart;
  final VoidCallback onToggleDuty;
  final ValueChanged<PickupTask> onComplete;
  final ValueChanged<PickupTask> onMarkReady;
  final Future<void> Function() onRefresh;

  const HomeScreen({
    super.key,
    required this.tasks,
    required this.isOnDuty,
    required this.shiftStart,
    required this.onToggleDuty,
    required this.onComplete,
    required this.onMarkReady,
    required this.onRefresh,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  Timer? _clock;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.shiftStart);
    // Simulates the future initial API load so the shimmer state is real,
    // not decorative.
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _loading = false);
    });
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _elapsed = DateTime.now().difference(widget.shiftStart));
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String get _elapsedLabel {
    final h = _elapsed.inHours;
    final m = _elapsed.inMinutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  List<PickupTask> get _readyTasks => widget.tasks.where((t) => t.status != PickupStatus.completed).toList()
    ..sort((a, b) => a.status == PickupStatus.ready ? -1 : 1);

  int get _completedToday => widget.tasks.where((t) => t.status == PickupStatus.completed).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _teal,
          onRefresh: widget.onRefresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(title: "Today's Pickups", actionLabel: 'View Manifest', onAction: () {}),
                      const SizedBox(height: 12),
                      if (_loading)
                        const Column(children: [TaskCardSkeleton(), TaskCardSkeleton(), TaskCardSkeleton()])
                      else if (_readyTasks.isEmpty)
                        _emptyPickups()
                      else
                        ..._readyTasks.map(
                          (task) => PickupTaskCard(
                            task: task,
                            compact: true,
                            onComplete: () => widget.onComplete(task),
                            onMarkReady: () => widget.onMarkReady(task),
                            onContact: () => _contactSnack(context, task),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _contactSnack(BuildContext context, PickupTask task) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Calling ${task.seller}...'), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _emptyPickups() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(color: AppColors.teal50, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.celebration_rounded, color: _teal, size: 24),
          ),
          const SizedBox(height: 10),
          const Text('All caught up!', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.slate800)),
          const SizedBox(height: 4),
          Text('No more pickups scheduled right now.', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // ---------------- Header ----------------

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_teal, _tealDark]),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
        boxShadow: [BoxShadow(color: _teal.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // "Find Work" (browsing logistics companies / applications) now
              // lives in the driver app's Account tab — see
              // DriverWorkScreen — since courier and driver share that UI.
              // This spacer keeps the title centered.
              const SizedBox(width: 36, height: 36),
              const Text('NEXMART Courier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.4)),
              _headerIconButton(
                icon: Icons.person_rounded,
                tooltip: 'Profile',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.6), width: 2)),
                child: const CircleAvatar(radius: 24, backgroundColor: Colors.white24, child: Icon(Icons.person_rounded, color: Colors.white, size: 26)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(driverProfile.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 6),
                        Icon(Icons.star_rounded, size: 14, color: Colors.amber.shade300),
                        Text(driverProfile.rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.local_shipping_rounded, size: 12, color: Colors.white.withOpacity(0.8)),
                        const SizedBox(width: 4),
                        Expanded(child: Text(driverProfile.hub, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ],
                ),
              ),
              _dutyToggle(),
            ],
          ),

          const SizedBox(height: 16),
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                MetricChip(icon: Icons.inventory_2_rounded, value: '${widget.tasks.length}', label: 'Assigned'),
                const SizedBox(width: 10),
                MetricChip(icon: Icons.check_circle_rounded, value: '$_completedToday', label: 'Completed', trend: 12),
                const SizedBox(width: 10),
                MetricChip(icon: Icons.timer_rounded, value: _elapsedLabel, label: widget.isOnDuty ? 'On duty' : 'Off duty'),
                const SizedBox(width: 10),
                MetricChip(icon: Icons.star_rounded, value: driverProfile.rating.toStringAsFixed(1), label: 'Rating', trend: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dutyToggle() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onToggleDuty();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [_dutyPill('On', widget.isOnDuty), _dutyPill('Off', !widget.isOnDuty)]),
      ),
    );
  }

  Widget _dutyPill(String label, bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: active ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: active ? _tealDark : Colors.white70)),
    );
  }

  Widget _headerIconButton({required IconData icon, required String tooltip, required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.25))),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

// ============================================================
// SALARY SCREEN
// ============================================================

enum EarningsPeriod { today, week, month }

class _DayEarning {
  final String label;
  final double amount;
  const _DayEarning(this.label, this.amount);
}

class _EarningsLine {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  const _EarningsLine(this.label, this.amount, this.icon, this.color);
}

const _weeklyEarnings = [
  _DayEarning('Mon', 620),
  _DayEarning('Tue', 745),
  _DayEarning('Wed', 510),
  _DayEarning('Thu', 890),
  _DayEarning('Fri', 960),
  _DayEarning('Sat', 1120),
  _DayEarning('Sun', 430),
];

const _breakdownByPeriod = {
  EarningsPeriod.today: [
    _EarningsLine('Base pay', 380, Icons.local_shipping_rounded, AppColors.teal600),
    _EarningsLine('Delivery bonus', 40, Icons.bolt_rounded, Color(0xFFF59E0B)),
    _EarningsLine('Tips', 10, Icons.volunteer_activism_rounded, Color(0xFFEC4899)),
  ],
  EarningsPeriod.week: [
    _EarningsLine('Base pay', 3820, Icons.local_shipping_rounded, AppColors.teal600),
    _EarningsLine('Delivery bonus', 615, Icons.bolt_rounded, Color(0xFFF59E0B)),
    _EarningsLine('Peak hour bonus', 340, Icons.trending_up_rounded, Color(0xFF8B5CF6)),
    _EarningsLine('Tips', 500, Icons.volunteer_activism_rounded, Color(0xFFEC4899)),
  ],
  EarningsPeriod.month: [
    _EarningsLine('Base pay', 15420, Icons.local_shipping_rounded, AppColors.teal600),
    _EarningsLine('Delivery bonus', 2460, Icons.bolt_rounded, Color(0xFFF59E0B)),
    _EarningsLine('Peak hour bonus', 1360, Icons.trending_up_rounded, Color(0xFF8B5CF6)),
    _EarningsLine('Tips', 1980, Icons.volunteer_activism_rounded, Color(0xFFEC4899)),
  ],
};

const _trendByPeriod = {EarningsPeriod.today: 8.0, EarningsPeriod.week: 14.0, EarningsPeriod.month: -3.5};

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  EarningsPeriod _period = EarningsPeriod.week;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 550), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 600));
  }

  double get _total => _breakdownByPeriod[_period]!.fold(0, (sum, e) => sum + e.amount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Earnings'),
        centerTitle: true,
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_rounded),
            tooltip: 'Profile',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _teal,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _heroCard(),
            const SizedBox(height: 20),
            SectionHeader(title: 'This week'),
            const SizedBox(height: 12),
            _loading ? const TaskCardSkeleton() : _weeklyChart(),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Breakdown'),
            const SizedBox(height: 12),
            if (_loading)
              const Column(children: [TaskCardSkeleton(), TaskCardSkeleton()])
            else
              _breakdownCard(),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Incentives'),
            const SizedBox(height: 12),
            _incentiveCard(
              title: 'Weekly delivery streak',
              subtitle: 'Complete 50 deliveries this week',
              progress: 0.68,
              rewardLabel: '+₱500',
              icon: Icons.local_fire_department_rounded,
              color: const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 12),
            _incentiveCard(
              title: 'Perfect attendance',
              subtitle: 'Stay on duty every day this month',
              progress: 0.42,
              rewardLabel: '+₱1,200',
              icon: Icons.emoji_events_rounded,
              color: const Color(0xFF8B5CF6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCard() {
    final trend = _trendByPeriod[_period]!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_teal, _tealDark]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: _teal.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total earnings', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12.5, fontWeight: FontWeight.w600)),
              _periodSelector(),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₱${_total.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(trend >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 13, color: trend >= 0 ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5)),
                      const SizedBox(width: 3),
                      Text('${trend.abs().toStringAsFixed(1)}%', style: TextStyle(color: trend >= 0 ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5), fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('vs. last ${_periodNoun()}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
        ],
      ),
    );
  }

  String _periodNoun() {
    switch (_period) {
      case EarningsPeriod.today:
        return 'day';
      case EarningsPeriod.week:
        return 'week';
      case EarningsPeriod.month:
        return 'month';
    }
  }

  Widget _periodSelector() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: EarningsPeriod.values.map((p) {
          final selected = p == _period;
          final label = switch (p) {
            EarningsPeriod.today => 'Day',
            EarningsPeriod.week => 'Week',
            EarningsPeriod.month => 'Month',
          };
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _period = p);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: selected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(16)),
              child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? _tealDark : Colors.white70)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _weeklyChart() {
    final maxAmount = _weeklyEarnings.map((d) => d.amount).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _weeklyEarnings.map((day) {
                final isPeak = day.amount == maxAmount;
                final barHeight = 90 * (day.amount / maxAmount);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('₱${day.amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 8.5, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: barHeight),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (context, height, _) => Container(
                            height: height,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isPeak ? const [_teal, _tealDark] : [AppColors.teal300, AppColors.teal100],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _weeklyEarnings
                .map((d) => Expanded(child: Text(d.label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, color: Colors.grey[500], fontWeight: FontWeight.w600))))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _breakdownCard() {
    final lines = _breakdownByPeriod[_period]!;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        children: List.generate(lines.length, (i) {
          final line = lines[i];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: line.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                      child: Icon(line.icon, size: 17, color: line.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(line.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.slate800))),
                    Text('₱${line.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.slate800)),
                  ],
                ),
              ),
              if (i != lines.length - 1) const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          );
        }),
      ),
    );
  }

  Widget _incentiveCard({
    required String title,
    required String subtitle,
    required double progress,
    required String rewardLabel,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.slate800)),
                    Text(subtitle, style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(rewardLabel, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11.5)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Stack(
                children: [
                  Container(height: 8, color: AppColors.slate100),
                  FractionallySizedBox(widthFactor: v, child: Container(height: 8, color: color)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('${(progress * 100).toStringAsFixed(0)}% complete', style: TextStyle(fontSize: 10.5, color: Colors.grey[500], fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ============================================================
// PICKUPS SCREEN
// ============================================================

enum PickupFilter { all, ready, notReady, priority }

class PickupsScreen extends StatefulWidget {
  final List<PickupTask> tasks;
  final ValueChanged<PickupTask> onComplete;
  final ValueChanged<PickupTask> onMarkReady;
  final Future<void> Function() onRefresh;

  const PickupsScreen({
    super.key,
    required this.tasks,
    required this.onComplete,
    required this.onMarkReady,
    required this.onRefresh,
  });

  @override
  State<PickupsScreen> createState() => _PickupsScreenState();
}

class _PickupsScreenState extends State<PickupsScreen> {
  PickupFilter _filter = PickupFilter.all;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 550), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  List<PickupTask> get _filtered {
    switch (_filter) {
      case PickupFilter.all:
        return widget.tasks;
      case PickupFilter.ready:
        return widget.tasks.where((t) => t.status == PickupStatus.ready).toList();
      case PickupFilter.notReady:
        return widget.tasks.where((t) => t.status == PickupStatus.notReady).toList();
      case PickupFilter.priority:
        return widget.tasks.where((t) => t.priority == PickupPriority.high).toList();
    }
  }

  List<PickupTask> get _routeStops {
    final active = widget.tasks.where((t) => t.status != PickupStatus.completed).toList()
      ..sort((a, b) => a.etaMinutes.compareTo(b.etaMinutes));
    return active.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Pickups'),
        centerTitle: true,
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_rounded),
            tooltip: 'Profile',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _teal,
        onRefresh: widget.onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            if (_routeStops.isNotEmpty) ...[
              const SectionHeader(title: 'Route overview'),
              const SizedBox(height: 12),
              _routeCard(),
              const SizedBox(height: 20),
            ],
            SectionHeader(title: 'Manifest (${_filtered.length})'),
            const SizedBox(height: 12),
            _filterRow(),
            const SizedBox(height: 12),
            if (_loading)
              const Column(children: [TaskCardSkeleton(), TaskCardSkeleton(), TaskCardSkeleton()])
            else if (_filtered.isEmpty)
              _emptyState()
            else
              ..._filtered.map(
                (task) => PickupTaskCard(
                  task: task,
                  onComplete: () => widget.onComplete(task),
                  onMarkReady: () => widget.onMarkReady(task),
                  onContact: () => _contact(task),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _contact(PickupTask task) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Calling ${task.seller}...'), behavior: SnackBarBehavior.floating));
  }

  Widget _filterRow() {
    final filters = [
      (PickupFilter.all, 'All'),
      (PickupFilter.ready, 'Ready'),
      (PickupFilter.notReady, 'Not Ready'),
      (PickupFilter.priority, 'Priority'),
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final entry = filters[i];
          final selected = entry.$1 == _filter;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _filter = entry.$1);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.teal600 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? Colors.transparent : AppColors.slate200),
              ),
              child: Text(entry.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.slate600)),
            ),
          );
        },
      ),
    );
  }

  Widget _routeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.alt_route_rounded, color: _teal, size: 18),
              const SizedBox(width: 8),
              const Text('Suggested route', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
              const Spacer(),
              Text('${_routeStops.length} stops', style: TextStyle(fontSize: 11.5, color: Colors.grey[500], fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(_routeStops.length, (i) {
            final stop = _routeStops[i];
            final isLast = i == _routeStops.length - 1;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: i == 0 ? _teal : Colors.white, shape: BoxShape.circle, border: Border.all(color: _teal, width: 2)),
                        child: Text('${i + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: i == 0 ? Colors.white : _teal)),
                      ),
                      if (!isLast) Expanded(child: Container(width: 2, color: AppColors.teal100)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(stop.seller, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                Text(stop.address, style: TextStyle(fontSize: 11, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Text('${stop.etaMinutes} min', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _teal)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(color: AppColors.teal50, borderRadius: BorderRadius.circular(18)),
      child: const Column(
        children: [
          Icon(Icons.inbox_rounded, color: _teal, size: 32),
          SizedBox(height: 10),
          Text('No pickups match this filter', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.slate800)),
        ],
      ),
    );
  }
}

// ============================================================
// PROFILE SCREEN (reached via header/appbar icon, not the nav bar)
// ============================================================

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("You'll need to sign in again to access your courier account."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('auth_token');
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final years = DateTime.now().difference(driverProfile.joinedAt).inDays ~/ 365;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 210,
            backgroundColor: _teal,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_teal, _tealDark])),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        child: const CircleAvatar(radius: 36, backgroundColor: Colors.white24, child: Icon(Icons.person_rounded, color: Colors.white, size: 40)),
                      ),
                      const SizedBox(height: 10),
                      Text(driverProfile.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star_rounded, size: 15, color: Colors.amber.shade300),
                          const SizedBox(width: 3),
                          Text('${driverProfile.rating} · ${driverProfile.completedDeliveries} deliveries', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, size: 13, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Verified courier', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            sliver: SliverList.list(
              children: [
                const SectionHeader(title: 'Performance'),
                const SizedBox(height: 12),
                _statsGrid(),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Vehicle'),
                const SizedBox(height: 12),
                _infoCard([
                  _infoRow(Icons.two_wheeler_rounded, 'Vehicle', driverProfile.vehicle),
                  _infoRow(Icons.badge_outlined, 'Plate number', driverProfile.plateNumber),
                  _infoRow(Icons.store_rounded, 'Assigned hub', driverProfile.hub),
                ]),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Contact'),
                const SizedBox(height: 12),
                _infoCard([
                  _infoRow(Icons.call_outlined, 'Phone', driverProfile.phone),
                  _infoRow(Icons.email_outlined, 'Email', driverProfile.email),
                  _infoRow(Icons.event_available_outlined, 'Courier since', '$years yr${years == 1 ? '' : 's'}'),
                ]),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Settings'),
                const SizedBox(height: 12),
                _settingsCard(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid() {
    final stats = [
      ('${driverProfile.completedDeliveries}', 'Deliveries', Icons.local_shipping_rounded, _teal),
      ('${(driverProfile.onTimeRate * 100).toStringAsFixed(0)}%', 'On-time rate', Icons.schedule_rounded, const Color(0xFF8B5CF6)),
      ('${(driverProfile.acceptanceRate * 100).toStringAsFixed(0)}%', 'Acceptance', Icons.thumb_up_rounded, const Color(0xFFF59E0B)),
      (driverProfile.rating.toStringAsFixed(1), 'Rating', Icons.star_rounded, const Color(0xFFEC4899)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: stats.map((s) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: s.$4.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
                child: Icon(s.$3, size: 16, color: s.$4),
              ),
              const Spacer(),
              Text(s.$1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.slate800)),
              Text(s.$2, style: TextStyle(fontSize: 10.5, color: Colors.grey[500], fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _infoCard(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1) const Divider(height: 1, indent: 52, endIndent: 16),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _teal),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.slate600, fontWeight: FontWeight.w500))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.slate800)),
        ],
      ),
    );
  }

  Widget _settingsCard(BuildContext context) {
    Widget tile({required IconData icon, required String label, required VoidCallback onTap, Color? color}) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color ?? AppColors.slate600),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: color ?? AppColors.slate800))),
              Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey[400]),
            ],
          ),
        ),
      );
    }

    void comingSoon() => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This section is coming soon.'), behavior: SnackBarBehavior.floating),
        );

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        children: [
          tile(icon: Icons.notifications_outlined, label: 'Notifications', onTap: comingSoon),
          const Divider(height: 1, indent: 52, endIndent: 16),
          tile(icon: Icons.account_balance_outlined, label: 'Payment methods', onTap: comingSoon),
          const Divider(height: 1, indent: 52, endIndent: 16),
          tile(icon: Icons.support_agent_rounded, label: 'Support & help', onTap: comingSoon),
          const Divider(height: 1, indent: 52, endIndent: 16),
          tile(icon: Icons.description_outlined, label: 'Terms & privacy', onTap: comingSoon),
          const Divider(height: 1, indent: 52, endIndent: 16),
          tile(icon: Icons.logout_rounded, label: 'Log out', color: const Color(0xFFEF4444), onTap: () => _confirmLogout(context)),
        ],
      ),
    );
  }
}
