import 'package:flutter/material.dart';

import '../../driver/driver_theme.dart';
import '../buyer_models.dart';
import '../buyer_store.dart';
import '../widgets/buyer_widgets.dart';
import 'address_form_screen.dart';
import 'settings_kit.dart';

/// Address book. In [pickMode] (from checkout) tapping an address returns
/// it; otherwise tapping edits it.
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key, this.pickMode = false, this.selectedId});

  final bool pickMode;
  final String? selectedId;

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final store = BuyerStore.instance;

  @override
  void initState() {
    super.initState();
    store.loadAddresses();
  }

  Future<void> _edit([Address? address]) async {
    final saved = await Navigator.of(context).push<Address>(MaterialPageRoute(builder: (_) => AddressFormScreen(initial: address)));
    if (saved != null && widget.pickMode && mounted && saved.isComplete) Navigator.pop(context, saved);
  }

  Future<void> _delete(Address a) async {
    final ok = await confirmDialog(context, title: 'Delete address?', message: a.formatted, confirmLabel: 'Delete', destructive: true);
    if (!ok) return;
    try {
      await store.deleteAddress(a.id);
      if (mounted) showToast(context, 'Address deleted');
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    }
  }

  Future<void> _setDefault(Address a) async {
    try {
      await store.setDefaultAddress(a.id);
      if (mounted) showToast(context, 'Default address updated');
    } catch (e) {
      if (mounted) showToast(context, store.handleError(e), error: true);
    }
  }

  static IconData _labelIcon(String label) => switch (label) {
        'Home' => Icons.home_rounded,
        'Work' => Icons.work_rounded,
        _ => Icons.place_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: settingsAppBar(widget.pickMode ? 'Select Address' : 'My Addresses'),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = store.addresses;
          if (list.isEmpty && store.loadingAddresses) return const Padding(padding: EdgeInsets.all(16), child: RowsSkeleton(count: 3, tile: 44));
          if (list.isEmpty && store.addressError != null) {
            return ErrorState(message: store.addressError!, onRetry: () => store.loadAddresses(force: true));
          }
          if (list.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: EmptyCard(
                icon: Icons.location_off_outlined,
                title: 'No saved addresses',
                message: 'Add where you\'d like your orders delivered.',
                actionLabel: 'Add address',
                onAction: _edit,
              ),
            );
          }
          return RefreshIndicator(
            color: DriverColors.primary,
            onRefresh: () => store.loadAddresses(force: true),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final a = list[i];
                return _AddressCard(
                  address: a,
                  icon: _labelIcon(a.label),
                  pickMode: widget.pickMode,
                  selected: widget.pickMode && a.id == widget.selectedId,
                  onTap: () => widget.pickMode && a.isComplete ? Navigator.pop(context, a) : _edit(a),
                  onEdit: () => _edit(a),
                  onDefault: a.isDefault ? null : () => _setDefault(a),
                  onDelete: () => _delete(a),
                );
              },
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: DriverColors.border))),
          child: FilledButton.icon(
            onPressed: _edit,
            style: FilledButton.styleFrom(backgroundColor: DriverColors.primary, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Add New Address', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.icon,
    required this.pickMode,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDefault,
    required this.onDelete,
  });

  final Address address;
  final IconData icon;
  final bool pickMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDefault;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final a = address;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? DriverColors.primary : DriverColors.border, width: selected ? 1.6 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconTile(icon, size: 40, color: a.isComplete ? DriverColors.primary : DriverColors.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(a.label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: DriverColors.textPrimary)),
                    if (a.isDefault) const StatusPill('Default', DriverColors.primary, icon: Icons.check_rounded),
                    if (!a.isComplete) const StatusPill('Incomplete', DriverColors.warning, icon: Icons.error_outline_rounded),
                    if (a.hasPin) const StatusPill('Pinned', DriverColors.success, icon: Icons.pin_drop_outlined) else const StatusPill('No map pin', DriverColors.warning, icon: Icons.location_off_outlined),
                  ]),
                  const SizedBox(height: 4),
                  Text('${a.fullName}  ·  ${a.phone}', maxLines: 1, overflow: TextOverflow.ellipsis, style: DriverText.body.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(a.formatted, style: DriverText.caption.copyWith(fontSize: 12.5, height: 1.4)),
                  if (!a.isComplete) ...[
                    const SizedBox(height: 4),
                    const Text('Tap to finish this address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: DriverColors.warning)),
                  ],
                ]),
              ),
              if (pickMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 8),
                  child: Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: selected ? DriverColors.primary : Colors.grey[400], size: 22),
                ),
            ]),
            const Divider(height: 16, color: DriverColors.border),
            Row(children: [
              _Action(icon: Icons.edit_outlined, label: 'Edit', onTap: onEdit),
              if (onDefault != null) _Action(icon: Icons.check_circle_outline_rounded, label: 'Set default', onTap: onDefault!),
              const Spacer(),
              _Action(icon: Icons.delete_outline_rounded, label: 'Delete', color: DriverColors.error, onTap: onDelete),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap, this.color = DriverColors.textSecondary});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        style: TextButton.styleFrom(foregroundColor: color, minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 10)),
      );
}
