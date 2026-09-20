/// Data models for the Logistics mobile app's Inventory section — mirrors
/// `App\Http\Resources\Logistics\ParcelInventoryResource` on the Laravel
/// side (see Api\Logistics\ParcelInventoryController). Same
/// `fromApi`/mutable-field shape as driver/driver_models.dart's
/// AssignedDelivery, kept as its own small model set since the fields this
/// screen cares about (both seller AND buyer at once, the inventory scan
/// audit trail) are genuinely different from a courier's delivery card.
library;

class InventoryItem {
  final String name;
  final String? variant;
  final String? sku;
  final int quantity;
  final Map<String, dynamic>? dimensions;
  final double? weightKg;

  const InventoryItem({
    required this.name,
    this.variant,
    this.sku,
    this.quantity = 1,
    this.dimensions,
    this.weightKg,
  });

  factory InventoryItem.fromApi(Map<String, dynamic> json) {
    String? str(dynamic v) {
      final s = (v as String?)?.trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    final dims = json['dimensions'];
    return InventoryItem(
      name: str(json['name']) ?? 'Item',
      variant: str(json['variant']),
      sku: str(json['sku']),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      dimensions: dims is Map ? Map<String, dynamic>.from(dims) : null,
      weightKg: (json['weight'] as num?)?.toDouble(),
    );
  }

  String? get dimensionsLabel {
    final d = dimensions;
    if (d == null) return null;
    final l = d['length'], w = d['width'], h = d['height'];
    if (l == null || w == null || h == null) return null;
    final unit = (d['unit'] as String?)?.trim();
    String n(dynamic v) {
      final num? parsed = v is num ? v : num.tryParse('$v');
      if (parsed == null) return '$v';
      return parsed == parsed.roundToDouble() ? parsed.toInt().toString() : parsed.toString();
    }

    return '${n(l)} × ${n(w)} × ${n(h)}${unit != null && unit.isNotEmpty ? ' $unit' : ''}';
  }

  String? get weightLabel => weightKg == null ? null : '${weightKg!.toStringAsFixed(weightKg! == weightKg!.roundToDouble() ? 0 : 2)} kg';
}

/// A named party (buyer or seller) plus their address, as
/// ParcelInventoryResource's `buyer`/`seller` blocks come back.
class InventoryParty {
  final String? name;
  final String? contactNo;
  final String? shopName;
  final String? address;

  const InventoryParty({this.name, this.contactNo, this.shopName, this.address});

  factory InventoryParty.fromApi(Map<String, dynamic>? json) {
    if (json == null) return const InventoryParty();
    String? str(dynamic v) {
      final s = (v as String?)?.trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return InventoryParty(
      name: str(json['name']),
      contactNo: str(json['contact_no']),
      shopName: str(json['shop_name']),
      address: str(json['address']),
    );
  }
}

/// A named person credited on the inventory audit trail (courier who
/// picked it up, or the Logistics staff who scanned it in).
class InventoryPerson {
  final String? id;
  final String? firstName;
  final String? lastName;
  final String? contactNo;

  const InventoryPerson({this.id, this.firstName, this.lastName, this.contactNo});

  factory InventoryPerson.fromApi(Map<String, dynamic>? json) {
    if (json == null) return const InventoryPerson();
    String? str(dynamic v) {
      final s = (v as String?)?.trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return InventoryPerson(
      id: str(json['id']),
      firstName: str(json['first_name']),
      lastName: str(json['last_name']),
      contactNo: str(json['contact_no']),
    );
  }

  String? get fullName {
    final n = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    return n.isEmpty ? null : n;
  }
}

/// Which of the three "a courier just handed this company a parcel"
/// moments produced this row — mirrors
/// `App\Models\ParcelAssignment::INVENTORY_ORIGIN_*`. Only meaningful
/// while the parcel is still `forInventory`.
enum InventoryOrigin { pickup, transferDeparture, transferReceipt, unknown }

InventoryOrigin _parseOrigin(dynamic value) {
  switch (value) {
    case 'pickup':
      return InventoryOrigin.pickup;
    case 'transfer_departure':
      return InventoryOrigin.transferDeparture;
    case 'transfer_receipt':
      return InventoryOrigin.transferReceipt;
    default:
      return InventoryOrigin.unknown;
  }
}

/// The signed-in logistics account — loaded from `GET /api/auth/user`
/// (the same generic endpoint the top-level AuthScreen uses), not a
/// dedicated `/logistics/profile` endpoint, since none exists on the
/// backend. `company_name` comes from `user_metadata.company_name`,
/// stamped there at signup by AuthController::registerLogistics.
class LogisticsAccount {
  final String email;
  final String firstName;
  final String lastName;
  final String companyName;
  final String status;
  final DateTime memberSince;

  const LogisticsAccount({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.companyName,
    required this.status,
    required this.memberSince,
  });

  String get ownerName {
    final n = '$firstName $lastName'.trim();
    return n.isEmpty ? 'Logistics' : n;
  }

  factory LogisticsAccount.fromUserResponse(Map<String, dynamic> json) {
    final metadata = (json['user_metadata'] as Map?) ?? const {};
    String str(dynamic v) => (v as String?)?.trim() ?? '';

    return LogisticsAccount(
      email: str(json['email']),
      firstName: str(metadata['first_name']),
      lastName: str(metadata['last_name']),
      companyName: str(metadata['company_name']).isEmpty ? 'Logistics company' : str(metadata['company_name']),
      status: str(metadata['status']).isEmpty ? 'active' : str(metadata['status']),
      memberSince: DateTime.tryParse(str(json['created_at'])) ?? DateTime.now(),
    );
  }
}

/// One row from `GET /api/logistics/inventory`,
/// `GET /api/logistics/inventory/pending`, or
/// `GET /api/logistics/inventory/{id}`.
class InventoryParcel {
  final String id;
  final String status;
  final bool isTransfer;
  final bool isTransferReceipt;
  final InventoryOrigin origin;
  final String? trackingNumber;
  final String? orderNumber;
  final InventoryParty buyer;
  final InventoryParty seller;
  final InventoryPerson? courier;
  final List<InventoryItem> items;
  final String? transferToCompanyName;
  final String? hubName;
  final DateTime? forInventoryAt;
  final DateTime? inventoryScannedAt;
  final InventoryPerson? inventoryScannedBy;
  final String? confirmationToken;
  final bool hasConfirmationQr;

  const InventoryParcel({
    required this.id,
    required this.status,
    this.isTransfer = false,
    this.isTransferReceipt = false,
    this.origin = InventoryOrigin.unknown,
    this.trackingNumber,
    this.orderNumber,
    this.buyer = const InventoryParty(),
    this.seller = const InventoryParty(),
    this.courier,
    this.items = const [],
    this.transferToCompanyName,
    this.hubName,
    this.forInventoryAt,
    this.inventoryScannedAt,
    this.inventoryScannedBy,
    this.confirmationToken,
    this.hasConfirmationQr = false,
  });

  bool get isScanned => inventoryScannedAt != null;
  bool get isPending => status == 'for_inventory';

  factory InventoryParcel.fromApi(Map<String, dynamic> json) {
    String str(dynamic v) => (v as String?)?.trim() ?? '';
    String? strOrNull(dynamic v) {
      final s = str(v);
      return s.isEmpty ? null : s;
    }

    DateTime? parseDate(dynamic v) => (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;

    final courierJson = json['courier'];
    final scannedByJson = json['inventory_scanned_by'];
    final transferTo = json['transfer_to_company'];
    final hub = json['hub'];

    return InventoryParcel(
      id: str(json['id']),
      status: str(json['status']),
      isTransfer: json['is_transfer'] == true,
      isTransferReceipt: json['is_transfer_receipt'] == true,
      origin: _parseOrigin(json['inventory_origin']),
      trackingNumber: strOrNull(json['tracking_number']),
      orderNumber: strOrNull(json['order_number']),
      buyer: InventoryParty.fromApi(json['buyer'] is Map ? Map<String, dynamic>.from(json['buyer']) : null),
      seller: InventoryParty.fromApi(json['seller'] is Map ? Map<String, dynamic>.from(json['seller']) : null),
      courier: courierJson is Map ? InventoryPerson.fromApi(Map<String, dynamic>.from(courierJson)) : null,
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => InventoryItem.fromApi(Map<String, dynamic>.from(row)))
          .toList(),
      transferToCompanyName: transferTo is Map ? strOrNull(transferTo['company_name']) : null,
      hubName: hub is Map ? strOrNull(hub['company_name']) : null,
      forInventoryAt: parseDate(json['for_inventory_at']),
      inventoryScannedAt: parseDate(json['inventory_scanned_at']),
      inventoryScannedBy: scannedByJson is Map ? InventoryPerson.fromApi(Map<String, dynamic>.from(scannedByJson)) : null,
      confirmationToken: strOrNull(json['confirmation_token']),
      hasConfirmationQr: json['has_confirmation_qr'] == true,
    );
  }
}
