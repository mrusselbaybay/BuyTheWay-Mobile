import 'package:flutter/material.dart';

import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../widgets/buyer_widgets.dart';

/// What a quick-question picker resolved to.
class ChatPick {
  const ChatPick({this.orderId, this.productId, this.variantId, this.productName, this.productImage, this.productPrice, this.orderNumber, this.orderStatus});

  final String? orderId;
  final String? productId;
  final String? variantId;
  final String? productName;
  final String? productImage;
  final double? productPrice;
  final String? orderNumber;
  final String? orderStatus;
}

const _sheetShape = RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24)));

// ============================================================
// Actions under an automatic reply (web: Menu / Add to cart / Chat with seller)
// ============================================================

class AssistantActions extends StatelessWidget {
  const AssistantActions({
    super.key,
    required this.questions,
    required this.menuOpen,
    required this.onToggleMenu,
    required this.onSelect,
    required this.onContact,
    this.onAddToCart,
  });

  final List<QuickQuestion> questions;
  final bool menuOpen;
  final VoidCallback onToggleMenu;
  final ValueChanged<QuickQuestion> onSelect;
  final VoidCallback onContact;
  final VoidCallback? onAddToCart;

  @override
  Widget build(BuildContext context) {
    final general = questions.where((q) => q.contextType == 'general').toList();
    final order = questions.where((q) => q.contextType == 'order').toList();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 390),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: menuOpen
              ? Container(
                  margin: const EdgeInsets.only(top: 8),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: BColors.border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _Section(title: 'General questions', questions: general, onSelect: onSelect),
                    const Divider(height: 1, color: BColors.border),
                    _Section(title: 'Order questions', questions: order, onSelect: onSelect),
                  ]),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Pill(icon: menuOpen ? Icons.keyboard_arrow_up_rounded : Icons.menu_rounded, label: 'Menu', onTap: onToggleMenu),
          if (onAddToCart != null) _Pill(icon: Icons.add_shopping_cart_rounded, label: 'Add to cart', onTap: onAddToCart!),
          _Pill(icon: Icons.chat_bubble_outline_rounded, label: 'Chat with seller', onTap: onContact, filled: true),
        ]),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.questions, required this.onSelect});

  final String title;
  final List<QuickQuestion> questions;
  final ValueChanged<QuickQuestion> onSelect;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: BColors.ink)),
        ),
        if (questions.isEmpty)
          const Padding(padding: EdgeInsets.fromLTRB(14, 2, 14, 12), child: Text('No questions available.', style: BText.tiny))
        else
          for (final q in questions)
            InkWell(
              onTap: () => onSelect(q),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: BColors.divider))),
                child: Row(children: [
                  Expanded(child: Text(q.question, style: const TextStyle(fontSize: 13, color: BColors.muted))),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: BColors.faint),
                ]),
              ),
            ),
      ]);
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.onTap, this.filled = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : BColors.ink;
    return Material(
      color: filled ? BColors.brand : BColors.surface,
      shape: StadiumBorder(side: BorderSide(color: filled ? BColors.brand : BColors.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: fg)),
          ]),
        ),
      ),
    );
  }
}

// ============================================================
// Pickers
// ============================================================

/// "Which of the shop's products?" — the stock question and "Ask about a product".
Future<ChatPick?> pickProduct(BuildContext context, String conversationId) => showModalBottomSheet<ChatPick>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BColors.surface,
      shape: _sheetShape,
      builder: (_) => _PickerSheet(conversationId: conversationId, orders: false),
    );

/// "+ > Order": undelivered orders with this shop, most recent preselected.
Future<ChatPick?> pickActiveOrder(BuildContext context, String conversationId) => showModalBottomSheet<ChatPick>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BColors.surface,
      shape: _sheetShape,
      builder: (_) => _PickerSheet(conversationId: conversationId, orders: true, active: true),
    );

/// "Which of your orders?" for order questions.
Future<ChatPick?> pickOrderItem(BuildContext context, String conversationId) => showModalBottomSheet<ChatPick>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BColors.surface,
      shape: _sheetShape,
      builder: (_) => _PickerSheet(conversationId: conversationId, orders: true),
    );

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({required this.conversationId, required this.orders, this.active = false});

  final String conversationId;
  final bool orders;
  final bool active;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final _search = TextEditingController();
  final _items = <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _lastPage = 1;
  int _selected = 0; // active-order mode: the most recent order is the default
  Map<String, dynamic>? _variantFor; // product whose variants are showing

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _items.clear();
        _page = 1;
      }
    });
    try {
      final next = more ? _page + 1 : 1;
      final (items, last) = await BuyerStore.instance.api.chatPickerItems(widget.conversationId, orders: widget.orders, active: widget.active, search: _search.text.trim(), page: next);
      if (!mounted) return;
      setState(() {
        _items.addAll(items);
        _page = next;
        _lastPage = last;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = BuyerStore.instance.handleError(e);
          _loading = false;
        });
      }
    }
  }

  ChatPick _orderPick(Map<String, dynamic> it) => ChatPick(
        orderId: '${it['orderId']}',
        productId: it['productId']?.toString(),
        productName: '${it['previewName'] ?? ''}',
        productImage: it['previewImage']?.toString(),
        orderNumber: it['orderNumber']?.toString(),
        orderStatus: it['status']?.toString(),
      );

  List<Map<String, dynamic>> _variants(Map<String, dynamic> product) =>
      (product['variants'] is List ? product['variants'] as List : const []).whereType<Map>().map((v) => Map<String, dynamic>.from(v)).where((v) => v['status'] == 'active').toList();

  @override
  Widget build(BuildContext context) {
    final product = _variantFor;
    final title = product != null ? 'Choose a variant' : (widget.active ? 'Choose an order' : (widget.orders ? 'Choose an order item' : 'Choose a product'));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: BColors.border, borderRadius: BorderRadius.circular(2))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(children: [
              if (product != null)
                IconButton(onPressed: () => setState(() => _variantFor = null), icon: const Icon(Icons.arrow_back_rounded))
              else
                const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BColors.ink))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          if (!widget.orders && product == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: 'Search shop products',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  filled: true,
                  fillColor: BColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ),
          Expanded(child: _body(product)),
          if (widget.active && _items.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 12),
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _orderPick(_items[_selected])),
                style: FilledButton.styleFrom(backgroundColor: BColors.brand, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Ask about this order', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _body(Map<String, dynamic>? product) {
    if (product != null) {
      final variants = _variants(product);
      if (variants.isEmpty) return const EmptyState(icon: Icons.inventory_2_outlined, title: 'No variants available', message: 'This product has no variants in stock right now.');
      return ListView(padding: const EdgeInsets.all(12), children: [
        for (final v in variants)
          ListTile(
            enabled: (v['stock'] as num? ?? 0) > 0,
            title: Text(v['optionValues'] is Map ? (v['optionValues'] as Map).values.join(' / ') : '${v['sku'] ?? 'Variant'}'),
            subtitle: Text((v['stock'] as num? ?? 0) > 0 ? peso(v['price'] as num? ?? 0) : 'Out of stock'),
            onTap: () => Navigator.pop(
              context,
              ChatPick(productId: '${product['id']}', variantId: '${v['id']}', productName: '${product['name']}', productImage: product['image']?.toString(), productPrice: (product['price'] as num?)?.toDouble()),
            ),
          ),
      ]);
    }
    if (_error != null && _items.isEmpty) return ErrorState(message: _error!, onRetry: _load);
    if (_loading && _items.isEmpty) return const Center(child: CircularProgressIndicator(color: BColors.brand));
    if (_items.isEmpty) {
      return EmptyState(
        icon: widget.orders ? Icons.receipt_long_outlined : Icons.search_off_rounded,
        title: widget.active ? 'No active orders' : (widget.orders ? 'No orders with this shop yet' : 'No products found'),
        message: widget.active ? 'Delivered orders are not listed here.' : (widget.orders ? 'Order questions need an order to refer to.' : 'Try a different search.'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: _items.length + (_page < _lastPage ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1, color: BColors.divider),
      itemBuilder: (_, i) {
        if (i == _items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: BColors.brand))
                  : TextButton(onPressed: () => _load(more: true), child: const Text('Show more')),
            ),
          );
        }
        final it = _items[i];
        if (widget.active) {
          final on = i == _selected;
          return ListTile(
            selected: on,
            selectedTileColor: BColors.brandSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 56, height: 44, child: NetImage(it['previewImage']?.toString(), fallbackIcon: Icons.inventory_2_outlined))),
            title: Row(children: [
              Flexible(child: Text('${it['previewName'] ?? 'Order'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
              if (i == 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: BColors.brand, borderRadius: BorderRadius.circular(10)),
                  child: const Text('Most recent', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ],
            ]),
            subtitle: Text('Order #${it['orderNumber']} · ${it['status'] ?? ''}', style: BText.tiny),
            trailing: Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: on ? BColors.brand : BColors.faint),
            onTap: () => setState(() => _selected = i),
          );
        }
        final image = (widget.orders ? it['previewImage'] : it['image'])?.toString();
        final name = '${(widget.orders ? it['previewName'] : it['name']) ?? ''}';
        final price = widget.orders ? it['total'] : it['price'];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          leading: ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 48, height: 48, child: NetImage(image))),
          title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(widget.orders ? 'Order #${it['orderNumber']} · ${it['status'] ?? ''}' : (price is num ? peso(price) : ''), style: BText.tiny),
          trailing: const Icon(Icons.chevron_right_rounded, color: BColors.faint),
          onTap: () {
            if (widget.orders) {
              Navigator.pop(context, ChatPick(orderId: '${it['orderId']}', productId: it['productId']?.toString(), productName: name, productImage: image, orderNumber: it['orderNumber']?.toString(), orderStatus: it['status']?.toString()));
            } else if (it['hasVariants'] == true) {
              setState(() => _variantFor = it);
            } else {
              Navigator.pop(context, ChatPick(productId: '${it['id']}', productName: name, productImage: image, productPrice: (it['price'] as num?)?.toDouble()));
            }
          },
        );
      },
    );
  }
}
