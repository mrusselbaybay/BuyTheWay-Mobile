// ============================================================
// DRIVER APP — DATA MODELS & MOCK DATA
// ------------------------------------------------------------
// This module has no backend of its own (see the module README notes in
// the final summary). Every model here mirrors a plausible future API
// response shape so screens can be rewired to real data later without a
// rebuild — but for now every list is seeded from the mock generators
// below, exactly as requested ("hardcode this for now").
// ============================================================

enum DeliveryStage { headingToPickup, atPickup, headingToDropoff, atDropoff, completed }

enum HistoryStatus { completed, cancelled }

class DeliveryRequest {
  final String id;
  final String customerName;
  final String pickupLabel;
  final String pickupAddress;
  final String dropoffLabel;
  final String dropoffAddress;
  final double distanceKm;
  final int etaMinutes;
  final double estimatedFare;
  final int parcels;
  final double weightKg;
  final String? specialInstructions;
  final DateTime requestedAt;

  const DeliveryRequest({
    required this.id,
    required this.customerName,
    required this.pickupLabel,
    required this.pickupAddress,
    required this.dropoffLabel,
    required this.dropoffAddress,
    required this.distanceKm,
    required this.etaMinutes,
    required this.estimatedFare,
    required this.parcels,
    required this.weightKg,
    this.specialInstructions,
    required this.requestedAt,
  });
}

/// A request the driver has accepted, tracked through pickup → dropoff.
class ActiveDelivery {
  final DeliveryRequest request;
  DeliveryStage stage;
  bool pickupPhotoAttached;
  bool deliveryPhotoAttached;
  String deliveryNotes;

  ActiveDelivery({
    required this.request,
    this.stage = DeliveryStage.headingToPickup,
    this.pickupPhotoAttached = false,
    this.deliveryPhotoAttached = false,
    this.deliveryNotes = '',
  });
}

enum AssignedDeliveryStatus {
  assigned,
  pickedUp,
  delivered,
  handedOver,
  // Cross-region transfer leg states (see DriverDeliveryController's
  // docblock and App\Models\ParcelAssignment::STATUS_TO_TRANSFER) — a
  // transfer parcel never reaches pickedUp/delivered. transferAssigned is
  // "dispatched, staff hasn't handed it to me yet" (like `assigned` but
  // with no self-serve pickup action); readyToTransfer is "I have it,
  // confirm arrival at the target company's hub instead of delivering to
  // a buyer"; transferred is terminal.
  transferAssigned,
  readyToTransfer,
  transferred,
}

AssignedDeliveryStatus _parseAssignedDeliveryStatus(dynamic value) {
  switch (value) {
    case 'picked_up':
      return AssignedDeliveryStatus.pickedUp;
    case 'delivered':
      return AssignedDeliveryStatus.delivered;
    // This rider ran the pickup leg and handed the parcel back to
    // logistics — the row stays on their list purely as a record; there's
    // no scan/attach/deliver action left for them to take on it.
    case 'handed_over':
      return AssignedDeliveryStatus.handedOver;
    case 'transfer_assigned':
      return AssignedDeliveryStatus.transferAssigned;
    case 'ready_to_transfer':
      return AssignedDeliveryStatus.readyToTransfer;
    case 'transferred':
      return AssignedDeliveryStatus.transferred;
    case 'assigned':
    default:
      return AssignedDeliveryStatus.assigned;
  }
}

/// One line item on an assigned delivery's order — surfaced so the rider
/// sees what's actually in the parcel (name, shop, size/weight), matching
/// the web seller's order-details item list. [dimensions] mirrors the
/// product's `{length, width, height, unit}` map and is null when the
/// seller never filled it in; [weightKg] likewise.
class AssignedDeliveryItem {
  final String name;
  final String? variant;
  final String? sku;
  final int quantity;
  final Map<String, dynamic>? dimensions;
  final double? weightKg;

  const AssignedDeliveryItem({
    required this.name,
    this.variant,
    this.sku,
    this.quantity = 1,
    this.dimensions,
    this.weightKg,
  });

  factory AssignedDeliveryItem.fromApi(Map<String, dynamic> json) {
    String? str(dynamic v) {
      final s = (v as String?)?.trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    final dims = json['dimensions'];
    return AssignedDeliveryItem(
      name: str(json['name']) ?? 'Item',
      variant: str(json['variant']),
      sku: str(json['sku']),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      dimensions: dims is Map ? Map<String, dynamic>.from(dims) : null,
      weightKg: (json['weight'] as num?)?.toDouble(),
    );
  }

  /// "30 × 20 × 5 cm" from the dimensions map, or null when the parts
  /// needed aren't all present.
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

  /// "1.2 kg" or null.
  String? get weightLabel => weightKg == null ? null : '${weightKg!.toStringAsFixed(weightKg! == weightKg!.roundToDouble() ? 0 : 2)} kg';
}

/// A delivery the logistics team has pushed down to this driver — distinct
/// from [DeliveryRequest] (mockAvailableRequests()), which the driver pulls
/// from an open queue and accepts. These already have a driver attached by
/// dispatch, so the Deliveries screen is read-only: it's "what's been
/// assigned to me," not something to browse and claim.
///
/// Loaded for real from `GET /api/driver/deliveries`
/// (Driver\DriverDeliveryController::index on the Laravel side) — see
/// [AssignedDelivery.fromApi]. Unlike most of this module (see the
/// "hardcode this for now" note at the top of this file), Deliveries is
/// wired to the actual parcel-assignment data logistics dispatch creates.
class AssignedDelivery {
  final String id;
  final String orderNumber;
  final String? trackingNumber;
  final String customerName;
  final String? customerContactNo;
  final String? sellerName;
  final String? sellerContactNo;
  final String? sellerShopName;
  final String pickupLabel;
  final String dropoffLabel;
  final String? deliveryArea;
  final int parcels;

  /// The order's line items — what's actually inside the parcel. Empty for
  /// an order with no items on file.
  final List<AssignedDeliveryItem> items;
  final DateTime? assignedAt;
  DateTime? handedOffAt;
  DateTime? deliveredAt;
  DateTime? transferredAt;
  bool hasPickupPhoto;
  bool hasDeliveryPhoto;
  AssignedDeliveryStatus status;

  /// True for a cross-region transfer leg (seller/buyer island-group
  /// mismatch) — this parcel is being ferried to another logistics
  /// company's hub, not delivered to the buyer. See
  /// DriverDeliveryController::present's `is_transfer`.
  final bool isTransfer;

  /// The bare parcel confirmation token (see
  /// DriverDeliveryController::present's docblock) — the rider is already
  /// authorised for this parcel, so the backend echoes it so the app can
  /// check a scanned/decoded QR value against *this* delivery before ever
  /// hitting the network. Null when [hasConfirmationQr] is false.
  String? confirmationToken;

  /// Whether this order actually has a parcel QR to scan. False only for
  /// an order dispatched before `confirmation_token` existed —
  /// AssignedDeliveryDetailScreen falls back to a plain photo attach for
  /// those rather than demanding a code that was never printed.
  bool hasConfirmationQr;

  AssignedDelivery({
    required this.id,
    required this.orderNumber,
    this.trackingNumber,
    required this.customerName,
    this.customerContactNo,
    this.sellerName,
    this.sellerContactNo,
    this.sellerShopName,
    required this.pickupLabel,
    required this.dropoffLabel,
    this.deliveryArea,
    required this.parcels,
    this.items = const [],
    this.assignedAt,
    this.handedOffAt,
    this.deliveredAt,
    this.transferredAt,
    this.hasPickupPhoto = false,
    this.hasDeliveryPhoto = false,
    this.confirmationToken,
    this.hasConfirmationQr = false,
    required this.status,
    this.isTransfer = false,
  });

  /// The logistics company name lifted out of [pickupLabel] (formatted by
  /// the backend as "{company} — Sorting Hub", see
  /// DriverDeliveryController::present) — used as the real, non-fabricated
  /// stand-in for "assigned by" on the Mission Control cards: this app has
  /// no per-dispatcher identity to show the rider, but it does know which
  /// logistics company's dispatch handed the parcel down.
  String get dispatchedByLabel {
    final via = pickupLabel.split('—').first.trim();
    return via.isEmpty ? 'Logistics dispatch' : via;
  }

  /// Builds an [AssignedDelivery] from one row of
  /// `GET /api/driver/deliveries`'s `data` array (also the shape
  /// `POST .../deliver` returns for the one row it just updated).
  factory AssignedDelivery.fromApi(Map<String, dynamic> json) {
    String str(dynamic v) => (v as String?)?.trim() ?? '';

    DateTime? parseDate(dynamic v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    return AssignedDelivery(
      id: str(json['id']),
      orderNumber: str(json['order_number']).isEmpty ? 'N/A' : str(json['order_number']),
      trackingNumber: str(json['tracking_number']).isEmpty ? null : str(json['tracking_number']),
      customerName: str(json['customer_name']).isEmpty ? 'Customer' : str(json['customer_name']),
      customerContactNo: str(json['customer_contact_no']).isEmpty ? null : str(json['customer_contact_no']),
      sellerName: str(json['seller_name']).isEmpty ? null : str(json['seller_name']),
      sellerContactNo: str(json['seller_contact_no']).isEmpty ? null : str(json['seller_contact_no']),
      sellerShopName: str(json['seller_shop_name']).isEmpty ? null : str(json['seller_shop_name']),
      pickupLabel: str(json['pickup_label']).isEmpty ? 'Sorting hub' : str(json['pickup_label']),
      dropoffLabel: str(json['dropoff_label']).isEmpty ? 'Address on file' : str(json['dropoff_label']),
      deliveryArea: str(json['delivery_area']).isEmpty ? null : str(json['delivery_area']),
      parcels: (json['parcels'] as num?)?.toInt() ?? 0,
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => AssignedDeliveryItem.fromApi(Map<String, dynamic>.from(row)))
          .toList(),
      assignedAt: parseDate(json['assigned_at']),
      handedOffAt: parseDate(json['handed_off_at']),
      deliveredAt: parseDate(json['delivered_at']),
      transferredAt: parseDate(json['transferred_at']),
      hasPickupPhoto: json['has_pickup_photo'] == true,
      hasDeliveryPhoto: json['has_delivery_photo'] == true,
      confirmationToken: str(json['confirmation_token']).isEmpty ? null : str(json['confirmation_token']),
      hasConfirmationQr: json['has_confirmation_qr'] == true,
      status: _parseAssignedDeliveryStatus(json['status']),
      isTransfer: json['is_transfer'] == true,
    );
  }

  /// Copies the mutable fields from [other] onto this instance in place —
  /// used after a successful "Mark as picked up" or "Mark as Delivered"
  /// call so the same object already in DriverShell's list updates without
  /// needing to splice a fresh instance into it.
  void applyFrom(AssignedDelivery other) {
    status = other.status;
    handedOffAt = other.handedOffAt;
    deliveredAt = other.deliveredAt;
    transferredAt = other.transferredAt;
    hasPickupPhoto = other.hasPickupPhoto;
    hasDeliveryPhoto = other.hasDeliveryPhoto;
    confirmationToken = other.confirmationToken;
    hasConfirmationQr = other.hasConfirmationQr;
  }
}

class HistoryEntry {
  final String id;
  final String customerName;
  final String? customerContactNo;
  final String pickupLabel;
  final String dropoffLabel;
  final DateTime completedAt;
  final double earnings;
  final HistoryStatus status;

  /// The route's planned duration and how long it actually took — both
  /// null for an entry with no timing data on file (e.g. a cancelled run).
  /// Drives the "Archive Intelligence" accordion's ETA-vs-actual bar and
  /// the on-time/late performance dot.
  final int? etaMinutes;
  final int? actualMinutes;

  const HistoryEntry({
    required this.id,
    required this.customerName,
    this.customerContactNo,
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.completedAt,
    required this.earnings,
    required this.status,
    this.etaMinutes,
    this.actualMinutes,
  });

  /// null when there's nothing to compare (no timing data, or not a
  /// completed delivery) — callers render a neutral/"—" state in that case
  /// rather than guessing.
  bool? get wasOnTime {
    if (status != HistoryStatus.completed) return null;
    final eta = etaMinutes;
    final actual = actualMinutes;
    if (eta == null || actual == null) return null;
    return actual <= eta;
  }
}

class ChatMessage {
  final String id;
  final String text;
  final bool fromDriver;
  final DateTime sentAt;

  const ChatMessage({required this.id, required this.text, required this.fromDriver, required this.sentAt});
}

class ChatThread {
  final String id;
  final String customerName;
  final String avatarInitial;
  final List<ChatMessage> messages;
  int unreadCount;

  ChatThread({
    required this.id,
    required this.customerName,
    required this.avatarInitial,
    required this.messages,
    this.unreadCount = 0,
  });

  ChatMessage get lastMessage => messages.last;
}

class DriverAccount {
  /// The signed-in profile's UUID (public.profiles.id) — empty until the
  /// real profile has loaded.
  String id;
  String role;
  String name;
  String email;
  String phone;
  String vehicleType;
  String plateNumber;
  String driverId;
  final double rating;
  DateTime memberSince;
  String avatarInitial;

  // ---- Personal information (Settings screen — mirrors the buyer
  // account page's "Personal Information" fields) ----
  String firstName;
  String lastName;
  String middleInitial;
  String sex;
  DateTime birthday;

  // ---- Home address (Settings screen — mirrors the buyer account
  // page's "Home Address" section) ----
  /// Island group the address sits in ('Luzon' / 'Visayas' / 'Mindanao') —
  /// `addresses.region_name`. Collected at signup and editable here, same
  /// as the web wizard's Region dropdown.
  String regionName;
  String provinceCode;
  String provinceName;
  String municipalityCode;
  String municipalityName;
  String barangay;
  String street;
  String houseNo;

  // ---- Vehicle & documents (read-only — driver_details/courier_details) ----
  String licenseNumber;
  String? logisticsCompanyName;

  /// Shift availability behind the Settings screen's "Go online" toggle —
  /// 'available' or 'unavailable'. Persisted on driver_details/
  /// courier_details.delivery_status; flipped via
  /// `ApiService.updateDriverAvailability`.
  String deliveryStatus;

  // ---- Account status / bookkeeping ----
  String accountStatus;
  DateTime updatedAt;

  /// Public URL of the uploaded profile picture in Supabase's `avatars`
  /// bucket, or empty when the rider hasn't set one — the Settings screens
  /// fall back to the generic placeholder avatar in that case. Written by
  /// `POST /api/driver/profile/avatar`.
  String avatarUrl;

  bool get hasProfilePhoto => avatarUrl.isNotEmpty;

  DriverAccount({
    this.id = '',
    this.role = 'driver',
    required this.name,
    required this.email,
    required this.phone,
    required this.vehicleType,
    required this.plateNumber,
    required this.driverId,
    required this.rating,
    required this.memberSince,
    required this.avatarInitial,
    required this.firstName,
    required this.lastName,
    this.middleInitial = '',
    required this.sex,
    required this.birthday,
    this.regionName = '',
    this.provinceCode = '',
    required this.provinceName,
    this.municipalityCode = '',
    required this.municipalityName,
    required this.barangay,
    required this.street,
    this.houseNo = '',
    required this.licenseNumber,
    this.logisticsCompanyName,
    this.deliveryStatus = 'unavailable',
    this.accountStatus = 'Active',
    required this.updatedAt,
    this.avatarUrl = '',
  });

  /// Builds a [DriverAccount] from `GET /api/driver/profile`'s
  /// `{profile, address, vehicle}` response shape (see
  /// Driver\DriverProfileController::show on the Laravel side).
  factory DriverAccount.fromApi(Map<String, dynamic> json) {
    final profile = Map<String, dynamic>.from(json['profile'] as Map? ?? {});
    final addressJson = json['address'];
    final address = addressJson is Map ? Map<String, dynamic>.from(addressJson) : null;
    final vehicle = Map<String, dynamic>.from(json['vehicle'] as Map? ?? {});

    String str(dynamic v) => (v as String?)?.trim() ?? '';

    DateTime parseDate(dynamic v) {
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    final firstName = str(profile['first_name']);
    final lastName = str(profile['last_name']);
    final fullNameFromApi = str(profile['full_name']);
    final fullName = fullNameFromApi.isNotEmpty ? fullNameFromApi : '$firstName $lastName'.trim();
    final id = str(profile['id']);

    return DriverAccount(
      id: id,
      role: str(profile['role']).isEmpty ? 'driver' : str(profile['role']),
      name: fullName.isNotEmpty ? fullName : 'Driver',
      email: str(profile['email']),
      phone: str(profile['contact_no']),
      vehicleType: str(vehicle['vehicle']).isEmpty ? 'Not on file' : str(vehicle['vehicle']),
      plateNumber: str(vehicle['plate_number']).isEmpty ? 'Not on file' : str(vehicle['plate_number']),
      driverId: id.length >= 8 ? 'DRV-${id.substring(0, 8).toUpperCase()}' : (id.isEmpty ? 'N/A' : id.toUpperCase()),
      rating: 0,
      memberSince: parseDate(profile['created_at']),
      avatarInitial: firstName.isNotEmpty
          ? firstName[0].toUpperCase()
          : (lastName.isNotEmpty ? lastName[0].toUpperCase() : '?'),
      firstName: firstName,
      lastName: lastName,
      middleInitial: str(profile['middle_initial']),
      sex: str(profile['sex']),
      birthday: profile['birthday'] != null && str(profile['birthday']).isNotEmpty
          ? DateTime.tryParse(str(profile['birthday'])) ?? DateTime.utc(2000, 1, 1)
          : DateTime.utc(2000, 1, 1),
      regionName: str(address?['region_name']),
      provinceCode: str(address?['province_code']),
      provinceName: str(address?['province_name']),
      municipalityCode: str(address?['municipality_code']),
      municipalityName: str(address?['municipality_name']),
      barangay: str(address?['barangay']),
      street: str(address?['street']),
      houseNo: str(address?['house_no']),
      licenseNumber: str(vehicle['license_number']),
      logisticsCompanyName: str(vehicle['logistics_company_name']).isEmpty ? null : str(vehicle['logistics_company_name']),
      deliveryStatus: str(vehicle['delivery_status']) == 'available' ? 'available' : 'unavailable',
      accountStatus: str(profile['account_status']).isEmpty ? 'active' : str(profile['account_status']),
      updatedAt: parseDate(profile['updated_at']),
      avatarUrl: str(profile['avatar_url']),
    );
  }

  /// Copies every field from [other] onto this instance in place — used
  /// after a successful profile save so the single shared [DriverAccount]
  /// object (owned by DriverShell, passed by reference into every tab)
  /// reflects the server's response without each screen needing a fresh
  /// instance threaded back up through callbacks.
  void applyFrom(DriverAccount other) {
    id = other.id;
    role = other.role;
    name = other.name;
    email = other.email;
    phone = other.phone;
    vehicleType = other.vehicleType;
    plateNumber = other.plateNumber;
    driverId = other.driverId;
    memberSince = other.memberSince;
    avatarInitial = other.avatarInitial;
    firstName = other.firstName;
    lastName = other.lastName;
    middleInitial = other.middleInitial;
    sex = other.sex;
    birthday = other.birthday;
    regionName = other.regionName;
    provinceCode = other.provinceCode;
    provinceName = other.provinceName;
    municipalityCode = other.municipalityCode;
    municipalityName = other.municipalityName;
    barangay = other.barangay;
    street = other.street;
    houseNo = other.houseNo;
    licenseNumber = other.licenseNumber;
    logisticsCompanyName = other.logisticsCompanyName;
    deliveryStatus = other.deliveryStatus;
    accountStatus = other.accountStatus;
    updatedAt = other.updatedAt;
    avatarUrl = other.avatarUrl;
  }

  /// Whether the rider is currently on shift ("Go online" toggle is on).
  bool get isOnline => deliveryStatus == 'available';

  String get fullAddress => [
        if (houseNo.trim().isNotEmpty) houseNo.trim(),
        street,
        barangay,
        municipalityName,
        provinceName,
        regionName,
      ].where((part) => part.trim().isNotEmpty).join(', ');

  int get age {
    final now = DateTime.now();
    int years = now.year - birthday.year;
    if (now.month < birthday.month || (now.month == birthday.month && now.day < birthday.day)) {
      years -= 1;
    }
    return years;
  }
}

class EarningsBreakdownLine {
  final String label;
  final double amount;
  const EarningsBreakdownLine(this.label, this.amount);
}

class DayEarnings {
  final String label;
  final double amount;
  const DayEarnings(this.label, this.amount);
}

class WithdrawalRecord {
  final String id;
  final double amount;
  final DateTime requestedAt;
  final String destination;
  const WithdrawalRecord({required this.id, required this.amount, required this.requestedAt, required this.destination});
}

// ------------------------------------------------------------
// Mock data generators
// ------------------------------------------------------------

List<DeliveryRequest> mockAvailableRequests() => [
      DeliveryRequest(
        id: 'req-1',
        customerName: 'Maria Santos',
        pickupLabel: 'Corner Bakery',
        pickupAddress: '45 Kalayaan Ave, Diliman',
        dropoffLabel: 'Home',
        dropoffAddress: '12 Maple St, Project 6',
        distanceKm: 3.2,
        etaMinutes: 11,
        estimatedFare: 145,
        parcels: 2,
        weightKg: 1.4,
        specialInstructions: 'Leave at the guardhouse if unavailable.',
        requestedAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
      DeliveryRequest(
        id: 'req-2',
        customerName: 'Ken Uy',
        pickupLabel: 'TechHub Electronics',
        pickupAddress: '8 Timog Ave, QC',
        dropoffLabel: 'Office',
        dropoffAddress: '200 Ortigas Center, Pasig',
        distanceKm: 6.8,
        etaMinutes: 22,
        estimatedFare: 260,
        parcels: 1,
        weightKg: 3.0,
        requestedAt: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
      DeliveryRequest(
        id: 'req-3',
        customerName: 'Ana Reyes',
        pickupLabel: 'GreenLeaf Grocer',
        pickupAddress: '19 Aurora Blvd, Cubao',
        dropoffLabel: 'Condo Unit 14B',
        dropoffAddress: 'Avida Towers, Cubao',
        distanceKm: 1.9,
        etaMinutes: 7,
        estimatedFare: 95,
        parcels: 4,
        weightKg: 5.2,
        specialInstructions: 'Fragile — eggs included.',
        requestedAt: DateTime.now().subtract(const Duration(seconds: 40)),
      ),
    ];

List<HistoryEntry> mockHistory() => [
      HistoryEntry(
        id: 'h-1',
        customerName: 'Liza Cruz',
        customerContactNo: '+63 917 220 1145',
        pickupLabel: 'Corner Bakery',
        dropoffLabel: 'Sikatuna Village',
        completedAt: DateTime.now().subtract(const Duration(hours: 2)),
        earnings: 132,
        status: HistoryStatus.completed,
        etaMinutes: 25,
        actualMinutes: 22,
      ),
      HistoryEntry(
        id: 'h-2',
        customerName: 'Paolo Garcia',
        customerContactNo: '+63 918 334 8820',
        pickupLabel: 'PetCo Supplies',
        dropoffLabel: 'Loyola Heights',
        completedAt: DateTime.now().subtract(const Duration(hours: 5)),
        earnings: 178,
        status: HistoryStatus.completed,
        etaMinutes: 30,
        actualMinutes: 41,
      ),
      HistoryEntry(
        id: 'h-3',
        customerName: 'Jenny Lim',
        pickupLabel: 'Fresh Market',
        dropoffLabel: 'Teachers Village',
        completedAt: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
        earnings: 0,
        status: HistoryStatus.cancelled,
      ),
      HistoryEntry(
        id: 'h-4',
        customerName: 'Marco Villanueva',
        customerContactNo: '+63 919 552 0093',
        pickupLabel: 'TechHub Electronics',
        dropoffLabel: 'Katipunan Ave',
        completedAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
        earnings: 245,
        status: HistoryStatus.completed,
        etaMinutes: 35,
        actualMinutes: 33,
      ),
      HistoryEntry(
        id: 'h-5',
        customerName: 'Grace Tan',
        customerContactNo: '+63 920 447 6612',
        pickupLabel: 'GreenLeaf Grocer',
        dropoffLabel: 'UP Village',
        completedAt: DateTime.now().subtract(const Duration(days: 2, hours: 3)),
        earnings: 110,
        status: HistoryStatus.completed,
        etaMinutes: 20,
        actualMinutes: 19,
      ),
    ];

List<ChatThread> mockChatThreads() => [
      ChatThread(
        id: 'c-1',
        customerName: 'Maria Santos',
        avatarInitial: 'M',
        unreadCount: 1,
        messages: [
          ChatMessage(id: 'm1', text: "Hi! I'm at the guardhouse, no rush.", fromDriver: false, sentAt: DateTime.now().subtract(const Duration(minutes: 6))),
        ],
      ),
      ChatThread(
        id: 'c-2',
        customerName: 'Ken Uy',
        avatarInitial: 'K',
        messages: [
          ChatMessage(id: 'm2', text: 'On my way to pick up your package.', fromDriver: true, sentAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 10))),
          ChatMessage(id: 'm3', text: 'Great, thank you!', fromDriver: false, sentAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 8))),
        ],
      ),
    ];

DriverAccount mockDriverAccount() => DriverAccount(
      name: 'Marco Rivera',
      email: 'marco.rivera@buytheway.ph',
      phone: '+63 917 456 7890',
      vehicleType: 'Motorcycle · Honda Click 125i',
      plateNumber: 'NBC 2245',
      driverId: 'NXM-DRV-88213',
      rating: 4.87,
      memberSince: DateTime.utc(2022, 8, 1),
      avatarInitial: 'M',
      firstName: 'Marco',
      lastName: 'Rivera',
      middleInitial: 'D',
      sex: 'Male',
      birthday: DateTime.utc(1996, 4, 12),
      regionName: 'Luzon',
      provinceName: 'Metro Manila',
      municipalityName: 'Quezon City',
      barangay: 'Barangay Pinyahan',
      street: 'Maple St.',
      houseNo: '12',
      licenseNumber: 'N01-23-456789',
      accountStatus: 'Active',
      updatedAt: DateTime.now().subtract(const Duration(days: 6)),
    );

const List<EarningsBreakdownLine> todayBreakdown = [
  EarningsBreakdownLine('Base fare', 380),
  EarningsBreakdownLine('Tips', 60),
  EarningsBreakdownLine('Bonuses', 40),
];

const List<EarningsBreakdownLine> weekBreakdown = [
  EarningsBreakdownLine('Base fare', 3820),
  EarningsBreakdownLine('Tips', 615),
  EarningsBreakdownLine('Bonuses', 340),
  EarningsBreakdownLine('Adjustments', -45),
];

const List<EarningsBreakdownLine> monthBreakdown = [
  EarningsBreakdownLine('Base fare', 15420),
  EarningsBreakdownLine('Tips', 2460),
  EarningsBreakdownLine('Bonuses', 1360),
  EarningsBreakdownLine('Adjustments', -180),
];

const List<DayEarnings> weeklyEarningsChart = [
  DayEarnings('Mon', 620),
  DayEarnings('Tue', 745),
  DayEarnings('Wed', 510),
  DayEarnings('Thu', 890),
  DayEarnings('Fri', 960),
  DayEarnings('Sat', 1120),
  DayEarnings('Sun', 430),
];

List<WithdrawalRecord> mockWithdrawals() => [
      WithdrawalRecord(id: 'w-1', amount: 2500, requestedAt: DateTime.now().subtract(const Duration(days: 3)), destination: 'GCash •••• 4821'),
      WithdrawalRecord(id: 'w-2', amount: 1800, requestedAt: DateTime.now().subtract(const Duration(days: 9)), destination: 'BPI •••• 0032'),
    ];
