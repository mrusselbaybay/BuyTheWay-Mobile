import 'package:flutter/material.dart';

import '../buyer_models.dart';
import '../buyer_theme.dart';
import '../widgets/buyer_widgets.dart';

enum VariantSheetMode { addToCart, buyNow }

class VariantSelection {
  final ProductVariant? variant;
  final int quantity;

  const VariantSelection(this.variant, this.quantity);
}

/// Bottom sheet for picking options + quantity before Add to Cart / Buy
/// Now. Values that can't lead to a buyable variant (given the other
/// selections) are disabled rather than hidden, so shoppers see what
/// exists but is sold out.
Future<VariantSelection?> showVariantSheet(BuildContext context, Product product, VariantSheetMode mode) {
  return showModalBottomSheet<VariantSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: BColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(BRadius.md))),
    builder: (_) => _VariantSheet(product: product, mode: mode),
  );
}

class _VariantSheet extends StatefulWidget {
  const _VariantSheet({required this.product, required this.mode});

  final Product product;
  final VariantSheetMode mode;

  @override
  State<_VariantSheet> createState() => _VariantSheetState();
}

class _VariantSheetState extends State<_VariantSheet> {
  final Map<String, String> selected = {};
  int quantity = 1;

  Product get product => widget.product;

  @override
  void initState() {
    super.initState();
    for (final option in product.options) {
      if (option.values.length == 1) selected[option.name] = option.values.first;
    }
  }

  ProductVariant? get variant {
    if (product.options.any((o) => !selected.containsKey(o.name))) return null;
    return product.variants.where((v) => product.options.every((o) => v.optionValues[o.name] == selected[o.name])).firstOrNull;
  }

  bool _valueAvailable(String option, String value) {
    return product.variants.any((v) {
      if (!v.isBuyable || v.optionValues[option] != value) return false;
      return selected.entries.every((e) => e.key == option || v.optionValues[e.key] == e.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = variant;
    final stock = v?.stock ?? product.availableStock;
    final (low, high) = product.priceRange;
    final missing = product.options.where((o) => !selected.containsKey(o.name)).map((o) => o.name).toList();
    final canConfirm = missing.isEmpty && v != null && v.isBuyable;
    final isBuy = widget.mode == VariantSheetMode.buyNow;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(BRadius.sm),
                child: SizedBox(width: 96, height: 96, child: NetImage(v?.image ?? product.primaryImage, fallbackIcon: categoryIcon(product.category))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  v != null ? PriceText(v.price, size: 19) : PriceText(low, maxPrice: high, size: 19),
                  const SizedBox(height: 6),
                  Text(stock == null ? 'In stock' : 'Stock: $stock', style: BText.small),
                ]),
              ),
              IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: BColors.muted)),
            ]),
          ),
          const Divider(height: 1, color: BColors.divider),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              children: [
                for (final option in product.options) ...[
                  Text(option.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: option.values.map((value) {
                      final isSelected = selected[option.name] == value;
                      final available = _valueAvailable(option.name, value);
                      return ChoiceChip(
                        label: Text(value),
                        selected: isSelected,
                        showCheckmark: false,
                        onSelected: available || isSelected
                            ? (on) => setState(() {
                                  on ? selected[option.name] = value : selected.remove(option.name);
                                  quantity = 1;
                                })
                            : null,
                        backgroundColor: BColors.background,
                        selectedColor: BColors.brandSurface,
                        disabledColor: BColors.divider,
                        side: BorderSide(color: isSelected ? BColors.brand : Colors.transparent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BRadius.sm)),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          color: !available && !isSelected ? BColors.faint : (isSelected ? BColors.brand : BColors.ink),
                          decoration: !available && !isSelected ? TextDecoration.lineThrough : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                ],
                Row(children: [
                  const Expanded(child: Text('Quantity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                  QtyStepper(
                    value: quantity,
                    max: v?.stock,
                    onChanged: (q) => setState(() => quantity = q),
                  ),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canConfirm ? () => Navigator.pop(context, VariantSelection(v, quantity)) : null,
                style: isBuy ? BButtons.cta(height: 48) : BButtons.brand(height: 48),
                child: Text(missing.isNotEmpty
                    ? 'Select ${missing.join(' & ')}'
                    : (v != null && !v.isBuyable)
                        ? 'Unavailable'
                        : isBuy
                            ? 'Buy Now'
                            : 'Add to Cart'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
