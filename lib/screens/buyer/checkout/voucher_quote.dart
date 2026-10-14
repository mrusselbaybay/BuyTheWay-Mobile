/// Checkout voucher quote from `POST /buyer/vouchers/quote`: the vouchers
/// that could apply to each seller order (discount + shipping) and to the
/// whole cart (BuyTheWay / platform), each valued by the server, plus the
/// server's best pick. Same contract the web checkout uses.
class VoucherOption {
  const VoucherOption({
    required this.id,
    required this.type,
    required this.scope,
    required this.label,
    required this.stackable,
    required this.amount,
    required this.applicable,
    this.reason,
    this.minSpend = 0,
    this.maxDiscount,
    this.discountType = 'fixed',
    this.discountValue,
    this.expiresAt,
    this.remaining,
    this.runningLow = false,
    this.categories = const [],
  });

  final String id;
  final String type; // discount | shipping
  final String scope; // shop | product | platform | category
  final String label;
  final bool stackable;
  final double amount; // what it takes off this order right now
  final bool applicable;
  final String? reason; // why it doesn't apply, e.g. "Spend ₱50.00 more"
  final double minSpend;
  final double? maxDiscount;
  final String discountType;
  final double? discountValue;
  final DateTime? expiresAt;
  final int? remaining;
  final bool runningLow;
  final List<String> categories;

  bool get isShipping => type == 'shipping';

  /// "Min. spend ₱500 · Up to ₱100 off · Can't combine".
  String get conditions => [
        minSpend > 0 ? 'Min. spend ₱${minSpend.toStringAsFixed(minSpend == minSpend.roundToDouble() ? 0 : 2)}' : 'No minimum spend',
        if (discountType == 'percentage' && maxDiscount != null && !isShipping) 'Up to ₱${maxDiscount!.toStringAsFixed(maxDiscount == maxDiscount!.roundToDouble() ? 0 : 2)} off',
        if (!stackable) 'Can\'t combine',
      ].join(' · ');

  factory VoucherOption.fromJson(Map<String, dynamic> j) {
    double? d(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
    return VoucherOption(
      id: '${j['id']}',
      type: '${j['type'] ?? 'discount'}',
      scope: '${j['scope'] ?? 'shop'}',
      label: '${j['label'] ?? 'Voucher'}',
      stackable: j['stackable'] != false,
      amount: d(j['amount']) ?? 0,
      applicable: j['applicable'] == true,
      reason: j['reason'] == null ? null : '${j['reason']}',
      minSpend: d(j['minSpend']) ?? 0,
      maxDiscount: d(j['maxDiscount']),
      discountType: '${j['discountType'] ?? 'fixed'}',
      discountValue: d(j['discountValue']),
      expiresAt: j['expiresAt'] == null ? null : DateTime.tryParse('${j['expiresAt']}'),
      remaining: j['remaining'] is num ? (j['remaining'] as num).toInt() : null,
      runningLow: j['runningLow'] == true,
      categories: j['categories'] is List ? (j['categories'] as List).map((e) => '$e').toList() : const [],
    );
  }
}

/// Options for one slot pair (discount + shipping) and the server's best pick.
class VoucherOffer {
  const VoucherOffer({this.discount = const [], this.shipping = const [], this.bestDiscountId, this.bestShippingId, this.exclusive = false});

  final List<VoucherOption> discount;
  final List<VoucherOption> shipping;
  final String? bestDiscountId;
  final String? bestShippingId;

  /// Platform only: a non-stackable platform voucher beats keeping shop vouchers.
  final bool exclusive;

  int get count => discount.length + shipping.length;

  List<VoucherOption> slot(String name) => name == 'shipping' ? shipping : discount;

  VoucherOption? find(String slotName, String? id) => id == null ? null : slot(slotName).where((o) => o.id == id).firstOrNull;

  factory VoucherOffer.fromJson(Map<String, dynamic> j) {
    List<VoucherOption> options(dynamic v) => v is List ? v.whereType<Map>().map((m) => VoucherOption.fromJson(Map<String, dynamic>.from(m))).toList() : const [];
    final best = j['best'] is Map ? Map<String, dynamic>.from(j['best'] as Map) : const <String, dynamic>{};
    return VoucherOffer(
      discount: options(j['discount']),
      shipping: options(j['shipping']),
      bestDiscountId: best['discountId'] == null ? null : '${best['discountId']}',
      bestShippingId: best['shippingId'] == null ? null : '${best['shippingId']}',
      exclusive: best['exclusive'] == true,
    );
  }
}

class VoucherQuote {
  const VoucherQuote({this.sellers = const {}, this.platform});

  /// Seller id → that shop's offers.
  final Map<String, VoucherOffer> sellers;
  final VoucherOffer? platform;

  static const empty = VoucherQuote();

  factory VoucherQuote.fromJson(Map<String, dynamic> j) {
    // PHP encodes an empty map as [], so accept both shapes.
    final raw = j['sellers'];
    final sellers = <String, VoucherOffer>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map) sellers['$k'] = VoucherOffer.fromJson(Map<String, dynamic>.from(v));
      });
    }
    return VoucherQuote(sellers: sellers, platform: j['platform'] is Map ? VoucherOffer.fromJson(Map<String, dynamic>.from(j['platform'] as Map)) : null);
  }
}
