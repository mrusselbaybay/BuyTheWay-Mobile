import 'package:flutter/material.dart';

import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../widgets/buyer_widgets.dart';
import 'address_form_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BColors.background,
      appBar: AppBar(
        backgroundColor: BColors.surface,
        surfaceTintColor: BColors.surface,
        foregroundColor: BColors.ink,
        title: Text(widget.pickMode ? 'Select Address' : 'My Addresses', style: BText.title),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = store.addresses;
          if (list.isEmpty && store.loadingAddresses) return const Center(child: CircularProgressIndicator(color: BColors.brand));
          if (list.isEmpty && store.addressError != null) {
            return ErrorState(message: store.addressError!, onRetry: () => store.loadAddresses(force: true));
          }
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.location_off_outlined,
              title: 'No saved addresses',
              message: 'Add where you\'d like your orders delivered.',
              actionLabel: 'Add address',
              onAction: _edit,
            );
          }
          return RefreshIndicator(
            color: BColors.brand,
            onRefresh: () => store.loadAddresses(force: true),
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: BColors.divider),
              itemBuilder: (_, i) {
                final a = list[i];
                final selected = widget.pickMode && a.id == widget.selectedId;
                return Material(
                  color: BColors.surface,
                  child: InkWell(
                    onTap: () {
                      if (widget.pickMode && a.isComplete) {
                        Navigator.pop(context, a);
                      } else {
                        _edit(a);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (widget.pickMode)
                          Padding(
                            padding: const EdgeInsets.only(right: 10, top: 2),
                            child: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: selected ? BColors.cta : BColors.faint, size: 20),
                          ),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text.rich(TextSpan(children: [
                              TextSpan(text: a.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              TextSpan(text: '  |  ${a.phone}', style: const TextStyle(color: BColors.muted)),
                            ]), style: const TextStyle(fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(a.formatted, style: const TextStyle(fontSize: 13, height: 1.35)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 6, runSpacing: 6, children: [
                              if (a.isDefault) const _Tag('Default', BColors.cta),
                              _Tag(a.label, BColors.muted),
                              if (!a.isComplete) const _Tag('Incomplete — tap to finish', BColors.error),
                            ]),
                          ]),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'More',
                          icon: const Icon(Icons.more_vert, color: BColors.muted),
                          onSelected: (v) {
                            if (v == 'edit') _edit(a);
                            if (v == 'default') _setDefault(a);
                            if (v == 'delete') _delete(a);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            if (!a.isDefault) const PopupMenuItem(value: 'default', child: Text('Set as default')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: BColors.error))),
                          ],
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: _edit,
            style: BButtons.brand(height: 48),
            icon: const Icon(Icons.add),
            label: const Text('Add New Address'),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(2)),
        child: Text(text, style: TextStyle(fontSize: 11, color: color)),
      );
}
