// ============================================================================
// BuyTheWay Auth Screen — Solid Redesign
// ----------------------------------------------------------------------------
// A flat, no-gradient login/signup experience built on the `solid_ui.dart`
// kit: a plain surface, filled inputs, and a single solid accent color.
// Runs as two portals (see AuthPortal): buyer (default) and partner
// (courier/logistics, via "Ship with us"). Only buyer and courier are
// reachable signup roles on mobile (see _isMobileAllowedRole) — the seller/driver/logistics wizard bodies further
// below are unreachable from this screen's own role picker and were left
// exactly as they were.
//
// Business logic (validation, API calls, state machine for the multi-step
// wizards) is unchanged from the original implementation — only the
// presentation layer was rebuilt.
// ============================================================================

import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/brand_logo.dart';
import '../../widgets/common.dart';
import '../../widgets/solid_ui.dart';
import '../../widgets/password_strength_meter.dart';
import '../../services/api_service.dart';

// Constants

/// Island group the account's address belongs to. Not a PSGC region — the
/// backend stores this verbatim in `addresses.region_name` and validates
/// it as `in:Luzon,Visayas,Mindanao` (AuthController::registerUser), which
/// is exactly the three-option <select> the web wizard renders.
const List<String> kRegionOptions = ['Luzon', 'Visayas', 'Mindanao'];

/// Accepted values for the "ID Type" dropdown that sits next to every
/// valid-ID upload. Must stay in sync with AuthController::ID_TYPES and
/// app.js's ID_TYPES — anything else is rejected by the Rule::in() check.
const List<String> kIdTypeOptions = [
  'Passport',
  "Driver's License",
  'PRC ID',
  'UMID',
  'SSS ID',
  'National ID',
  'Student ID',
  'Philippine Postal ID',
];

const List<String> kLineOfBusinessOptions = [
  'Pet Supplies',
  'Kids and Baby',
  'Electronics and Gadgets',
  'House and Garden',
  "Woman's Apparel",
  "Men's Apparel",
  'Sports and Outdoors',
  'Health and Beauty',
];

/// Which audience the auth screen serves. The app opens on [buyer]; couriers
/// and logistics partners reach [partner] through the "Ship with us" link.
enum AuthPortal { buyer, partner }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.portal = AuthPortal.buyer});

  final AuthPortal portal;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // API Service
  final ApiService _api = ApiService();
  String? _authToken;

  // ---------------- Top-level UI state ----------------
  String mode = 'login'; // login | signup | forgot | reset
  String signupStep = 'role';
  String? selectedRole;
  bool isLogisticsSignup = false;
  bool showPassword = false;
  bool rememberMe = false;
  bool isSubmitting = false;
  bool isSendingCode = false;
  bool isVerifyingCode = false;
  bool isVerifying = false;
  String errorMsg = '';
  String successMsg = '';
  Map<String, String>? loggedInUser;

  int resetStep = 1;
  final Map<String, String> validationErrors = {};

  // ---------------- Login / shared credentials ----------------
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  // ---------------- Forgot / reset password ----------------
  final forgotEmail = TextEditingController();
  final resetEmailCtrl = TextEditingController();
  final resetCode = TextEditingController();
  final newPassword = TextEditingController();
  final newConfirmPassword = TextEditingController();

  // ---------------- Signup email verification ----------------
  final signupVerifyCode = TextEditingController();

  // ---------------- Personal (buyer/seller/courier) ----------------
  final lastName = TextEditingController();
  final firstName = TextEditingController();
  final middleInitial = TextEditingController();
  String sex = '';
  DateTime? birthday;
  final contactNo = TextEditingController();

  // ---------------- Address (shared by personal + driver) ----------------
  /// Island group — see [kRegionOptions]. Submitted as `region`.
  String region = '';
  String? provinceCode;
  String? municipalityCode;
  String? barangayCode;
  String? municipalityName;
  String? barangay;
  final street = TextEditingController();
  final houseNo = TextEditingController();

  // ---------------- PSGC Address Data ----------------
  List<dynamic> _provinces = [];
  List<dynamic> _municipalities = [];
  List<dynamic> _barangays = [];
  List<dynamic> _companyProvinces = [];
  List<dynamic> _companyMunicipalities = [];
  List<dynamic> _companyBarangays = [];

  bool _loadingProvinces = false;
  bool _loadingMunicipalities = false;
  bool _loadingBarangays = false;
  bool _loadingCompanyProvinces = false;
  bool _loadingCompanyMunicipalities = false;
  bool _loadingCompanyBarangays = false;
  String _addressError = '';

  // ---------------- Documents ----------------
  /// Which kind of government ID the primary ID upload actually is. One
  /// per wizard, matching AuthController::PRIMARY_ID_DOC_TYPE: it labels
  /// the buyer/seller `valid_id`, the courier `drivers_license`, the
  /// driver `valid_id`, and the logistics owner's `valid_id`.
  String idType = '';
  String driverIdType = '';
  String ownerIdType = '';

  // ---------------- Seller ----------------
  final businessName = TextEditingController();
  String lineOfBusiness = '';
  bool idFileUploaded = false;
  bool businessPermitUploaded = false;

  // ---------------- Courier ----------------
  String vehicle = '';
  final plateNumber = TextEditingController();
  bool orcrUploaded = false;
  bool licenseUploaded = false;

  // ---------------- Logistics company ----------------
  final companyName = TextEditingController();
  final companyEmail = TextEditingController();
  String companyRegion = '';
  final companyContactNo = TextEditingController();
  final companyTIN = TextEditingController();
  final companySECReg = TextEditingController();
  String? companyProvinceCode;
  String? companyMunicipalityCode;
  String? companyBarangayCode;
  String? companyMunicipalityName;
  String? companyBarangay;

  // ---------------- File Uploads ----------------
  String? _idFileName;
  String? _businessPermitFileName;
  String? _orcrFileName;
  String? _licenseFileName;
  String? _ownerIdFileName;
  String? _businessPermitFileFileName;
  String? _mayorPermitFileName;
  String? _dtiRegFileName;
  String? _driverIdFileName;
  String? _driverLicenseFileName;
  String? _driverOrcrFileName;

  Uint8List? _idFileBytes;
  Uint8List? _businessPermitBytes;
  Uint8List? _orcrBytes;
  Uint8List? _licenseBytes;
  Uint8List? _ownerIdBytes;
  Uint8List? _businessPermitFileBytes;
  Uint8List? _mayorPermitBytes;
  Uint8List? _dtiRegBytes;
  Uint8List? _driverIdBytes;
  Uint8List? _driverLicenseBytes;
  Uint8List? _driverOrcrBytes;

  final companyStreet = TextEditingController();
  final companyHouseNo = TextEditingController();

  // ---------------- Logistics owner ----------------
  final ownerLastName = TextEditingController();
  final ownerFirstName = TextEditingController();
  final ownerMiddleInitial = TextEditingController();
  String ownerSex = '';
  DateTime? ownerBirthday;
  bool ownerIdUploaded = false;
  bool businessPermitFileUploaded = false;
  bool mayorPermitUploaded = false;
  bool dtiRegUploaded = false;

  // ---------------- Driver ----------------
  final driverFirstName = TextEditingController();
  final driverLastName = TextEditingController();
  final driverMiddleInitial = TextEditingController();
  String driverSex = '';
  DateTime? driverBirthday;
  final driverContactNo = TextEditingController();
  final driverEmail = TextEditingController();
  final driverPassword = TextEditingController();
  final driverConfirmPassword = TextEditingController();
  bool driverIdUploaded = false;
  bool driverLicenseUploaded = false;
  String driverVehicle = '';
  final driverPlateNumber = TextEditingController();
  bool driverOrcrUploaded = false;
  final driverLicenseNumber = TextEditingController();

  // ---------------- Static config ----------------
  // Mobile app is limited to buyer and courier. Seller, driver and logistics
  // accounts are web-only — see _isMobileAllowedRole and the login guard.
  bool get _isPartnerPortal => widget.portal == AuthPortal.partner;

  /// Signup roles offered by the current portal.
  List<Map<String, dynamic>> get roles => _allRoles
      .where((r) => _isPartnerPortal ? r['id'] != 'buyer' : r['id'] == 'buyer')
      .toList();

  static const List<Map<String, dynamic>> _allRoles = [
    {
      'id': 'buyer',
      'label': 'Buyer',
      'desc': 'Shop from verified local sellers',
      'icon': Icons.shopping_bag_outlined
    },
    {
      'id': 'courier',
      'label': 'Courier',
      'desc': 'Deliver & earn on your schedule',
      'icon': Icons.local_shipping_outlined
    },
  ];

  /// Roles allowed to sign in on the mobile app. `logistics` (company
  /// owner) and `logistics_admin` (staff account managing the company)
  /// both reach the Logistics mobile app (Dashboard/Inventory/Settings
  /// only — see LogisticsShell), not the signup wizard above, which still
  /// only offers buyer/courier. Every other account type (seller, driver,
  /// admin, …) must use the web browser.
  static bool _isMobileAllowedRole(String role) =>
      role == 'buyer' ||
      role == 'courier' ||
      role == 'logistics' ||
      role == 'logistics_admin';

  /// Error to show when [role] signs in through the wrong portal, or null
  /// when the role belongs here.
  String? _portalRoleError(String role) {
    if (!_isMobileAllowedRole(role)) return _webOnlyRoleMessage;
    final isBuyer = role == 'buyer';
    if (_isPartnerPortal && isBuyer) {
      return 'This is a buyer account. Please log in through the buyer portal.';
    }
    if (!_isPartnerPortal && !isBuyer) {
      return 'Courier and logistics accounts log in through "Ship with us" below.';
    }
    return null;
  }

  static const String _webOnlyRoleMessage =
      'This account type is only accessible through a web browser. '
      'Only buyer, courier and logistics accounts can use the mobile app.';

  final List<String> steps = const [
    'Personal',
    'Verify Email',
    'Address',
    'Security',
    'Documents'
  ];
  final List<String> logisticsSteps = const [
    'Company Info',
    'Verify Email',
    'Owner Details',
    'Address',
    'Security',
    'Documents'
  ];
  final List<String> driverSteps = const [
    'Personal',
    'Verify Email',
    'Address',
    'Security',
    'Documents'
  ];

  final List<String> stepKeys = const [
    'personal',
    'verifyEmail',
    'address',
    'security',
    'documents'
  ];
  final List<String> driverStepKeys = const [
    'driverPersonal',
    'driverVerifyEmail',
    'driverAddress',
    'driverSecurity',
    'driverDocuments'
  ];
  final List<String> logisticsStepKeys = const [
    'company',
    'companyVerifyEmail',
    'owner',
    'address',
    'security',
    'documents'
  ];

  List<TextEditingController> get _allControllers => [
        email,
        password,
        confirmPassword,
        forgotEmail,
        resetEmailCtrl,
        resetCode,
        newPassword,
        newConfirmPassword,
        signupVerifyCode,
        lastName,
        firstName,
        middleInitial,
        contactNo,
        street,
        houseNo,
        businessName,
        plateNumber,
        companyName,
        companyEmail,
        companyContactNo,
        companyTIN,
        companySECReg,
        companyStreet,
        companyHouseNo,
        ownerLastName,
        ownerFirstName,
        ownerMiddleInitial,
        driverFirstName,
        driverLastName,
        driverMiddleInitial,
        driverContactNo,
        driverEmail,
        driverPassword,
        driverConfirmPassword,
        driverPlateNumber,
        driverLicenseNumber,
      ];

  @override
  void dispose() {
    for (final c in _allControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ==================== File Picker ====================

  late final Map<String, void Function(String name, Uint8List bytes)>
      _uploadSetters = {
    'idFile': (n, b) => setState(() {
          idFileUploaded = true;
          _idFileName = n;
          _idFileBytes = b;
        }),
    'businessPermit': (n, b) => setState(() {
          businessPermitUploaded = true;
          _businessPermitFileName = n;
          _businessPermitBytes = b;
        }),
    'orcrFile': (n, b) => setState(() {
          orcrUploaded = true;
          _orcrFileName = n;
          _orcrBytes = b;
        }),
    'licenseFile': (n, b) => setState(() {
          licenseUploaded = true;
          _licenseFileName = n;
          _licenseBytes = b;
        }),
    'ownerIdFile': (n, b) => setState(() {
          ownerIdUploaded = true;
          _ownerIdFileName = n;
          _ownerIdBytes = b;
        }),
    'businessPermitFile': (n, b) => setState(() {
          businessPermitFileUploaded = true;
          _businessPermitFileFileName = n;
          _businessPermitFileBytes = b;
        }),
    'mayorPermitFile': (n, b) => setState(() {
          mayorPermitUploaded = true;
          _mayorPermitFileName = n;
          _mayorPermitBytes = b;
        }),
    'dtiRegFile': (n, b) => setState(() {
          dtiRegUploaded = true;
          _dtiRegFileName = n;
          _dtiRegBytes = b;
        }),
    'driverIdFile': (n, b) => setState(() {
          driverIdUploaded = true;
          _driverIdFileName = n;
          _driverIdBytes = b;
        }),
    'driverLicenseFile': (n, b) => setState(() {
          driverLicenseUploaded = true;
          _driverLicenseFileName = n;
          _driverLicenseBytes = b;
        }),
    'driverOrcrFile': (n, b) => setState(() {
          driverOrcrUploaded = true;
          _driverOrcrFileName = n;
          _driverOrcrBytes = b;
        }),
  };

  Future<void> _pickFile(String fieldName) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    // Mirrors the server rule (`max:10240` KB on every document in
    // AuthController::registerUser) so an oversized file is rejected here
    // with a clear message instead of as a 422 after a long upload.
    if (file.bytes!.lengthInBytes > 10 * 1024 * 1024) {
      setState(() => errorMsg = 'That file is larger than 10MB. Please upload a smaller one.');
      return;
    }
    _uploadSetters[fieldName]?.call(file.name, file.bytes!);
  }

  // ==================== Token Management ====================

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    setState(() => _authToken = token);
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    setState(() => _authToken = null);
  }

  // ==================== PSGC Address API Methods ====================

  Future<void> _loadProvinces() async {
    setState(() => _loadingProvinces = true);
    try {
      final provinces = await _api.getProvinces();
      setState(() {
        _provinces = provinces;
        _companyProvinces = provinces;
        _loadingProvinces = false;
        _loadingCompanyProvinces = false;
        _addressError = '';
      });
    } catch (e) {
      setState(() {
        _loadingProvinces = false;
        _loadingCompanyProvinces = false;
        _addressError = 'Failed to load provinces: ${e.toString()}';
      });
    }
  }

  Future<void> _loadMunicipalities(String provinceCode) async {
    setState(() => _loadingMunicipalities = true);
    try {
      final municipalities =
          await _api.getMunicipalities(provinceCode: provinceCode);
      setState(() {
        _municipalities = municipalities;
        _loadingMunicipalities = false;
      });
    } catch (e) {
      setState(() {
        _loadingMunicipalities = false;
        _addressError = 'Failed to load municipalities: ${e.toString()}';
      });
    }
  }

  Future<void> _loadBarangays(String municipalityCode) async {
    setState(() => _loadingBarangays = true);
    try {
      final barangays =
          await _api.getBarangays(municipalityCode: municipalityCode);
      setState(() {
        _barangays = barangays;
        _loadingBarangays = false;
      });
    } catch (e) {
      setState(() {
        _loadingBarangays = false;
        _addressError = 'Failed to load barangays: ${e.toString()}';
      });
    }
  }

  Future<void> _loadCompanyMunicipalities(String provinceCode) async {
    setState(() => _loadingCompanyMunicipalities = true);
    try {
      final municipalities =
          await _api.getMunicipalities(provinceCode: provinceCode);
      setState(() {
        _companyMunicipalities = municipalities;
        _loadingCompanyMunicipalities = false;
      });
    } catch (e) {
      setState(() {
        _loadingCompanyMunicipalities = false;
        _addressError = 'Failed to load municipalities: ${e.toString()}';
      });
    }
  }

  Future<void> _loadCompanyBarangays(String municipalityCode) async {
    setState(() => _loadingCompanyBarangays = true);
    try {
      final barangays =
          await _api.getBarangays(municipalityCode: municipalityCode);
      setState(() {
        _companyBarangays = barangays;
        _loadingCompanyBarangays = false;
      });
    } catch (e) {
      setState(() {
        _loadingCompanyBarangays = false;
        _addressError = 'Failed to load barangays: ${e.toString()}';
      });
    }
  }

  // ==================== Computed ====================

  List<String> get _activeStepKeys {
    if (isLogisticsSignup) return logisticsStepKeys;
    if (selectedRole == 'driver') return driverStepKeys;
    return stepKeys;
  }

  List<String> get _activeStepLabels {
    if (isLogisticsSignup) return logisticsSteps;
    if (selectedRole == 'driver') return driverSteps;
    return steps;
  }

  int get currentStepIndex {
    if (isLogisticsSignup) {
      const map = {
        'company': 0,
        'companyVerifyEmail': 1,
        'owner': 2,
        'address': 3,
        'security': 4,
        'documents': 5
      };
      return map[signupStep] ?? -1;
    } else if (selectedRole == 'driver') {
      const map = {
        'driverPersonal': 0,
        'driverVerifyEmail': 1,
        'driverAddress': 2,
        'driverSecurity': 3,
        'driverDocuments': 4
      };
      return map[signupStep] ?? -1;
    } else {
      const map = {
        'personal': 0,
        'verifyEmail': 1,
        'address': 2,
        'security': 3,
        'documents': 4
      };
      return map[signupStep] ?? -1;
    }
  }

  // ==================== Validation helpers ====================

  bool _validateName(String v) => RegExp(r'^[A-Za-z\s\-]+$').hasMatch(v);
  bool _validateMI(String v) => v.isEmpty || RegExp(r'^[A-Za-z]$').hasMatch(v);
  bool _validateEmail(String v) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);
  bool _validateContact(String v) => RegExp(r'^09\d{9}$').hasMatch(v);
  bool _validatePasswordLen(String v) => v.length >= 8;

  bool _validatePersonalFields({
    required TextEditingController first,
    required TextEditingController last,
    required TextEditingController mi,
    required TextEditingController emailCtrl,
    required TextEditingController contact,
    required DateTime? birthdayVal,
    required String sexVal,
    required String pFirst,
    required String pLast,
    required String pMi,
    required String pEmail,
    required String pContact,
    required String pBirthday,
  }) {
    bool ok = true;

    if (first.text.trim().isEmpty) {
      validationErrors[pFirst] = 'First name is required';
      ok = false;
    } else if (!_validateName(first.text.trim())) {
      validationErrors[pFirst] = 'Only letters allowed';
      ok = false;
    } else {
      validationErrors[pFirst] = '';
    }

    if (last.text.trim().isEmpty) {
      validationErrors[pLast] = 'Last name is required';
      ok = false;
    } else if (!_validateName(last.text.trim())) {
      validationErrors[pLast] = 'Only letters allowed';
      ok = false;
    } else {
      validationErrors[pLast] = '';
    }

    if (mi.text.isNotEmpty && !_validateMI(mi.text)) {
      validationErrors[pMi] = 'Only 1 letter allowed';
      ok = false;
    } else {
      validationErrors[pMi] = '';
    }

    if (emailCtrl.text.trim().isEmpty) {
      validationErrors[pEmail] = 'Email is required';
      ok = false;
    } else if (!_validateEmail(emailCtrl.text.trim())) {
      validationErrors[pEmail] = 'Invalid email format';
      ok = false;
    } else {
      validationErrors[pEmail] = '';
    }

    if (contact.text.trim().isEmpty) {
      validationErrors[pContact] = 'Contact number is required';
      ok = false;
    } else if (!_validateContact(contact.text.trim())) {
      validationErrors[pContact] = 'Must start with 09 and be 11 digits';
      ok = false;
    } else {
      validationErrors[pContact] = '';
    }

    if (birthdayVal == null) {
      validationErrors[pBirthday] = 'Birthday is required';
      ok = false;
    } else {
      validationErrors[pBirthday] = '';
    }

    if (sexVal.isEmpty) {
      errorMsg = 'Please select your sex';
      ok = false;
    }

    return ok;
  }

  bool _validateSecurityFields(TextEditingController pw,
      TextEditingController cpw, String pPw, String pCpw) {
    bool ok = true;
    if (pw.text.isEmpty) {
      validationErrors[pPw] = 'Password is required';
      ok = false;
    } else if (!_validatePasswordLen(pw.text)) {
      validationErrors[pPw] = 'Min 8 characters';
      ok = false;
    } else {
      validationErrors[pPw] = '';
    }

    if (cpw.text.isEmpty) {
      validationErrors[pCpw] = 'Please confirm password';
      ok = false;
    } else if (pw.text != cpw.text) {
      validationErrors[pCpw] = 'Passwords do not match';
      ok = false;
    } else {
      validationErrors[pCpw] = '';
    }

    return ok;
  }

  /// Mirrors app.js's validateAddressFields() — region included, since the
  /// backend stores it on the address row alongside the PSGC selections.
  /// [regionVal] is null for the address forms that don't collect one
  /// (the logistics company address asks for its region a step earlier).
  bool _validateAddressFields(String? province, String? municipality,
      String? barangayVal, TextEditingController streetCtrl,
      {String? regionVal}) {
    if ((regionVal != null && regionVal.isEmpty) ||
        province == null ||
        municipality == null ||
        barangayVal == null ||
        streetCtrl.text.trim().isEmpty) {
      errorMsg = 'Please fill in all address fields.';
      return false;
    }
    return true;
  }

  bool _validateDocuments() {
    if (selectedRole == 'buyer' && (!idFileUploaded || idType.isEmpty)) {
      errorMsg = 'Please select an ID type and upload an ID.';
      return false;
    }
    if (selectedRole == 'seller') {
      if (!idFileUploaded ||
          idType.isEmpty ||
          !businessPermitUploaded ||
          businessName.text.trim().isEmpty ||
          lineOfBusiness.isEmpty) {
        errorMsg = 'Please fill in all seller documents and business info.';
        return false;
      }
    }
    if (selectedRole == 'courier') {
      if (vehicle.isEmpty ||
          plateNumber.text.trim().isEmpty ||
          !orcrUploaded ||
          !licenseUploaded ||
          idType.isEmpty) {
        errorMsg = 'Please fill in all courier documents and vehicle info.';
        return false;
      }
    }
    if (selectedRole == 'driver') {
      if (driverVehicle.isEmpty ||
          driverPlateNumber.text.trim().isEmpty ||
          !driverOrcrUploaded ||
          !driverLicenseUploaded ||
          !driverIdUploaded ||
          driverIdType.isEmpty) {
        errorMsg = 'Please fill in all driver documents and vehicle info.';
        return false;
      }
    }
    return true;
  }

  bool _validateCompany() {
    if (companyName.text.trim().isEmpty ||
        companyContactNo.text.trim().isEmpty ||
        companyEmail.text.trim().isEmpty ||
        companyTIN.text.trim().isEmpty ||
        companyRegion.isEmpty) {
      errorMsg = 'Please fill in all required company fields.';
      return false;
    }
    if (!_validateEmail(companyEmail.text.trim())) {
      errorMsg = 'Invalid company email format.';
      return false;
    }
    if (!_validateContact(companyContactNo.text.trim())) {
      errorMsg = 'Contact number must start with 09 and be 11 digits.';
      return false;
    }
    return true;
  }

  bool _validateOwner() {
    if (ownerLastName.text.trim().isEmpty ||
        ownerFirstName.text.trim().isEmpty ||
        ownerSex.isEmpty ||
        ownerBirthday == null) {
      errorMsg = 'Please fill in all required owner details.';
      return false;
    }
    if (!_validateName(ownerFirstName.text.trim()) ||
        !_validateName(ownerLastName.text.trim())) {
      errorMsg = 'Names should only contain letters.';
      return false;
    }
    return true;
  }

  bool _validateLogisticsDocuments() {
    if (!ownerIdUploaded ||
        ownerIdType.isEmpty ||
        !businessPermitFileUploaded ||
        !mayorPermitUploaded ||
        !dtiRegUploaded) {
      errorMsg = 'Please upload all required documents.';
      return false;
    }
    return true;
  }

  // ==================== API Calls ====================

  Future<void> _sendVerificationCode(String email) async {
    setState(() => isSendingCode = true);

    try {
      final response = await _api.sendSignupCode(email);
      setState(() {
        isSendingCode = false;
        signupVerifyCode.clear();
        successMsg =
            response['message'] ?? 'Verification code sent to your email.';
      });
    } on ApiException catch (e) {
      setState(() {
        isSendingCode = false;
        errorMsg = e.message;
      });
    } catch (e) {
      setState(() {
        isSendingCode = false;
        errorMsg = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<bool> _verifyCode(String email, String code) async {
    setState(() => isVerifyingCode = true);

    try {
      final response = await _api.verifySignupCode(email, code);
      setState(() {
        isVerifyingCode = false;
        successMsg = response['message'] ?? 'Email verified successfully!';
      });
      return true;
    } on ApiException catch (e) {
      setState(() {
        isVerifyingCode = false;
        errorMsg = e.message;
      });
      return false;
    } catch (e) {
      setState(() {
        isVerifyingCode = false;
        errorMsg = e.toString().replaceAll('Exception: ', '');
      });
      return false;
    }
  }

  String get _activeSignupEmail {
    if (isLogisticsSignup) return companyEmail.text.trim();
    if (selectedRole == 'driver') return driverEmail.text.trim();
    return email.text.trim();
  }

  Future<void> _sendVerificationCodeStub() async {
    await _sendVerificationCode(_activeSignupEmail);
  }

  Future<bool> _verifyCodeStub() async {
    return _verifyCode(_activeSignupEmail, signupVerifyCode.text.trim());
  }

  // ==================== Authentication Methods ====================

  /// Web OAuth client ID from BuyTheWay - Web's .env (GOOGLE_CLIENT_ID) —
  /// this is the same client Supabase's Google provider already trusts, so
  /// it doubles as the `serverClientId` the native SDK needs to mint an
  /// id_token Supabase can verify.
  static const String _googleServerClientId =
      '968790382765-ueq74oaa6njkt297sqvgfn831g2vmnbs.apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static bool _googleSignInInitialized = false;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    await _googleSignIn.initialize(serverClientId: _googleServerClientId);
    _googleSignInInitialized = true;
  }

  Future<void> _handleGoogleAuth() async {
    setState(() {
      errorMsg = '';
      successMsg = '';
      isSubmitting = true;
    });

    try {
      await _ensureGoogleSignInInitialized();
      final googleUser = await _googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;

      if (idToken == null) {
        setState(() {
          errorMsg = 'Google sign-in failed. Please try again.';
          isSubmitting = false;
        });
        return;
      }

      final response = await _api.loginWithGoogle(idToken);

      if (!response.containsKey('access_token')) {
        setState(() {
          errorMsg = response['message'] ?? 'Google sign-in failed.';
          isSubmitting = false;
        });
        return;
      }

      final token = response['access_token'];
      await _saveToken(token);

      final userData = response['user'] ?? {};
      final userMetadata = userData['user_metadata'] ?? {};
      final String? role = userMetadata['role'] ?? userData['role'];
      final String status = userMetadata['status'] ?? 'pending';

      if (role == null) {
        // First-time Google sign-in: Supabase created the auth account but
        // there's no profile/role yet (mobile doesn't have the web app's
        // role-selection onboarding wizard), so send them there instead of
        // dropping them into the app with a made-up role.
        await _clearToken();
        setState(() {
          errorMsg =
              'Please finish creating your account on the BuyTheWay website, then sign in with Google here.';
          isSubmitting = false;
        });
        return;
      }

      if (status == 'rejected') {
        setState(() {
          errorMsg =
              'Your account registration was rejected. Please contact support.';
          isSubmitting = false;
        });
        return;
      }

      final portalError = _portalRoleError(role);
      if (portalError != null) {
        await _clearToken();
        setState(() {
          errorMsg = portalError;
          isSubmitting = false;
        });
        return;
      }

      final String firstName = userMetadata['first_name'] ?? '';
      final String lastName = userMetadata['last_name'] ?? '';
      final String name = '$firstName $lastName'.trim();

      setState(() {
        loggedInUser = {
          'email': userData['email'] ?? '',
          'role': role,
          'name': name,
          'status': status,
        };
        isSubmitting = false;
      });

      _handleRoleBasedNavigation(role);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        setState(() => isSubmitting = false);
        return;
      }
      setState(() {
        errorMsg = 'Google sign-in failed. Please try again.';
        isSubmitting = false;
      });
    } on ApiException catch (e) {
      setState(() {
        errorMsg = e.errors != null ? e.errors!.values.join('\n') : e.message;
        isSubmitting = false;
      });
    } catch (e) {
      setState(() {
        errorMsg = e.toString().replaceAll('Exception: ', '');
        isSubmitting = false;
      });
    }
  }

  Future<void> handleLogin() async {
    setState(() {
      errorMsg = '';
      successMsg = '';
      isSubmitting = true;
    });

    if (email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() {
        errorMsg = 'Email and password are required.';
        isSubmitting = false;
      });
      return;
    }

    try {
      final response = await _api.login(email.text.trim(), password.text);

      if (response.containsKey('access_token')) {
        final token = response['access_token'];
        await _saveToken(token);

        final userData = response['user'] ?? {};
        final userMetadata = userData['user_metadata'] ?? {};

        final String role = userMetadata['role'] ?? userData['role'] ?? 'buyer';
        String status = userMetadata['status'] ?? 'pending';

        final String firstName = userMetadata['first_name'] ?? '';
        final String lastName = userMetadata['last_name'] ?? '';
        final String name = '$firstName $lastName'.trim();

        if (status == 'rejected') {
          setState(() {
            errorMsg =
                'Your account registration was rejected. Please contact support.';
            isSubmitting = false;
          });
          return;
        }

        final portalError = _portalRoleError(role);
        if (portalError != null) {
          await _clearToken();
          setState(() {
            errorMsg = portalError;
            isSubmitting = false;
          });
          return;
        }

        setState(() {
          loggedInUser = {
            'email': userData['email'] ?? email.text.trim(),
            'role': role,
            'name': name,
            'status': status,
          };
          isSubmitting = false;
        });

        _handleRoleBasedNavigation(role);
      } else if (response.containsKey('token')) {
        await _saveToken(response['token']);
        final String role = response['user']['role'] ?? 'buyer';

        final portalError = _portalRoleError(role);
        if (portalError != null) {
          await _clearToken();
          setState(() {
            errorMsg = portalError;
            isSubmitting = false;
          });
          return;
        }

        setState(() {
          loggedInUser = {
            'email': email.text.trim(),
            'role': role,
            'name': response['user']['name'] ?? '',
          };
          isSubmitting = false;
        });

        _handleRoleBasedNavigation(role);
      } else {
        setState(() {
          errorMsg = response['message'] ?? 'Login failed';
          isSubmitting = false;
        });
      }
    } on ApiException catch (e) {
      setState(() {
        errorMsg = e.errors != null ? e.errors!.values.join('\n') : e.message;
        isSubmitting = false;
      });
    } catch (e) {
      setState(() {
        errorMsg = e.toString().replaceAll('Exception: ', '');
        isSubmitting = false;
      });
    }
  }

  void _handleRoleBasedNavigation(String role) {
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isPartnerPortal) {
        // Drop the buyer portal sitting under this one so back can't return to it.
        final dest = role == 'logistics' || role == 'logistics_admin'
            ? '/logistics_dashboard'
            : '/driver_dashboard';
        Navigator.pushNamedAndRemoveUntil(context, dest, (_) => false);
      } else if (role == 'logistics' || role == 'logistics_admin') {
        Navigator.pushReplacementNamed(context, '/logistics_dashboard');
      } else if (role == 'driver' || role == 'courier') {
        // Courier and driver share the driver app's UI (DriverShell) — see
        // driver_shell.dart. DriverShell itself loads the real profile via
        // GET /api/driver/profile, which accepts either role.
        Navigator.pushReplacementNamed(context, '/driver_dashboard');
      } else if (role == 'seller') {
        Navigator.pushReplacementNamed(context, '/seller_dashboard');
      } else if (role == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin_dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  Future<void> submitRegistration() async {
    setState(() {
      errorMsg = '';
      successMsg = '';
      isSubmitting = true;
    });

    bool ok;
    if (isLogisticsSignup) {
      ok = _validateLogisticsDocuments();
    } else if (selectedRole == 'driver') {
      ok = _validatePersonalFields(
            first: driverFirstName,
            last: driverLastName,
            mi: driverMiddleInitial,
            emailCtrl: driverEmail,
            contact: driverContactNo,
            birthdayVal: driverBirthday,
            sexVal: driverSex,
            pFirst: 'driverFirstName',
            pLast: 'driverLastName',
            pMi: 'driverMiddleInitial',
            pEmail: 'driverEmail',
            pContact: 'driverContactNo',
            pBirthday: 'driverBirthday',
          ) &&
          _validateSecurityFields(driverPassword, driverConfirmPassword,
              'driverPassword', 'driverConfirmPassword') &&
          _validateDocuments();
    } else {
      ok = _validateDocuments();
    }

    if (!ok) {
      setState(() => isSubmitting = false);
      return;
    }

    try {
      final response = await _api.submitSignupRegistration(
        fields: _buildUserRegistrationData(),
        documents: _buildRegistrationDocuments(),
        logistics: isLogisticsSignup,
      );

      setState(() {
        isSubmitting = false;
        successMsg =
            response['message'] ?? 'Registration submitted successfully!';
        signupStep = 'complete';
      });
    } on ApiException catch (e) {
      setState(() {
        isSubmitting = false;
        errorMsg = e.message;
        if (e.errors != null) {
          e.errors!.forEach((key, value) {
            validationErrors[key] = value.toString();
          });
        }
      });
    } catch (e) {
      setState(() {
        isSubmitting = false;
        errorMsg = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  /// The shared personal + address half of a buyer/seller/courier
  /// registration. Field names are the ones AuthController::registerUser
  /// validates — `contact_no` not `contact_number`, `house_no` not
  /// `house_number`, and `province_name`/`municipality_name` alongside the
  /// codes (the backend writes both onto the address row). The address is
  /// only sent when the PSGC chain is complete, matching app.js: the
  /// controller skips the address insert unless code+code+barangay are all
  /// present.
  Map<String, String> _personalAddressData() {
    final data = <String, String>{
      'first_name': firstName.text.trim(),
      'last_name': lastName.text.trim(),
      'middle_initial': middleInitial.text.trim(),
      'sex': sex,
      'contact_no': contactNo.text.trim(),
      'birthday': _isoDate(birthday),
    };

    if (provinceCode != null && municipalityCode != null && barangay != null) {
      data.addAll({
        'region': region,
        'province_code': provinceCode!,
        'province_name': _nameForCode(_provinces, provinceCode) ?? '',
        'municipality_code': municipalityCode!,
        'municipality_name': municipalityName ?? '',
        'barangay': barangay!,
        'street': street.text.trim(),
        'house_no': houseNo.text.trim(),
      });
    }

    return data;
  }

  /// `YYYY-MM-DD` — what Laravel's `date` rule and the Postgres `date`
  /// column both want. A full ISO-8601 timestamp round-trips fine too, but
  /// this keeps the stored birthday free of a spurious midnight-local time.
  String _isoDate(DateTime? value) {
    if (value == null) return '';
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  /// Text fields for the multipart registration POST. Mirrors app.js's
  /// submitUserRegistration()/submitLogisticsRegistration() exactly —
  /// empty values are dropped by [ApiService.submitSignupRegistration]
  /// rather than sent as blanks.
  Map<String, String> _buildUserRegistrationData() {
    if (isLogisticsSignup) {
      final data = <String, String>{
        'company_email': companyEmail.text.trim().toLowerCase(),
        'password': password.text,
        'company_name': companyName.text.trim(),
        'company_contact_no': companyContactNo.text.trim(),
        'company_tin': companyTIN.text.trim(),
        'company_sec_registration': companySECReg.text.trim(),
        'company_region': companyRegion,
        'owner_first_name': ownerFirstName.text.trim(),
        'owner_last_name': ownerLastName.text.trim(),
        'owner_middle_initial': ownerMiddleInitial.text.trim(),
        'owner_sex': ownerSex,
        'owner_birthday': _isoDate(ownerBirthday),
        'owner_id_type': ownerIdType,
      };

      if (companyProvinceCode != null) {
        data.addAll({
          'company_province_code': companyProvinceCode!,
          'company_province_name':
              _nameForCode(_companyProvinces, companyProvinceCode) ?? '',
          'company_municipality_code': companyMunicipalityCode ?? '',
          'company_municipality_name': companyMunicipalityName ?? '',
          'company_barangay': companyBarangay ?? '',
          'company_street': companyStreet.text.trim(),
          'company_house_no': companyHouseNo.text.trim(),
        });
      }

      return data;
    }

    if (selectedRole == 'driver') {
      final data = <String, String>{
        'email': driverEmail.text.trim().toLowerCase(),
        'password': driverPassword.text,
        'role': 'driver',
        'first_name': driverFirstName.text.trim(),
        'last_name': driverLastName.text.trim(),
        'middle_initial': driverMiddleInitial.text.trim(),
        'sex': driverSex,
        'contact_no': driverContactNo.text.trim(),
        'birthday': _isoDate(driverBirthday),
        'driver_vehicle': driverVehicle,
        'driver_plate_number': driverPlateNumber.text.trim(),
        'driver_license_number': driverLicenseNumber.text.trim(),
        'id_type': driverIdType,
      };

      if (provinceCode != null &&
          municipalityCode != null &&
          barangay != null) {
        data.addAll({
          'region': region,
          'province_code': provinceCode!,
          'province_name': _nameForCode(_provinces, provinceCode) ?? '',
          'municipality_code': municipalityCode!,
          'municipality_name': municipalityName ?? '',
          'barangay': barangay!,
          'street': street.text.trim(),
          'house_no': houseNo.text.trim(),
        });
      }

      return data;
    }

    final data = <String, String>{
      'email': email.text.trim().toLowerCase(),
      'password': password.text,
      'role': selectedRole ?? 'buyer',
      ..._personalAddressData(),
      'id_type': idType,
    };

    if (selectedRole == 'seller') {
      data['business_name'] = businessName.text.trim();
      data['line_of_business'] = lineOfBusiness;
    } else if (selectedRole == 'courier') {
      data['vehicle'] = vehicle;
      data['plate_number'] = plateNumber.text.trim();
    }

    return data;
  }

  /// The uploaded documents for the current wizard, under the exact
  /// multipart field names AuthController::fileMapForRole() (or
  /// registerLogistics()) reads them back out of.
  List<SignupUpload> _buildRegistrationDocuments() {
    SignupUpload? upload(String field, String? name, Uint8List? bytes) {
      if (name == null || bytes == null) return null;
      return SignupUpload(field: field, fileName: name, bytes: bytes);
    }

    final List<SignupUpload?> candidates;

    if (isLogisticsSignup) {
      candidates = [
        upload('owner_id_file', _ownerIdFileName, _ownerIdBytes),
        upload('business_permit_file', _businessPermitFileFileName,
            _businessPermitFileBytes),
        upload('mayor_permit_file', _mayorPermitFileName, _mayorPermitBytes),
        upload('dti_reg_file', _dtiRegFileName, _dtiRegBytes),
      ];
    } else if (selectedRole == 'driver') {
      candidates = [
        upload('id_file', _driverIdFileName, _driverIdBytes),
        upload('license_file', _driverLicenseFileName, _driverLicenseBytes),
        upload('orcr_file', _driverOrcrFileName, _driverOrcrBytes),
      ];
    } else {
      candidates = [
        upload('id_file', _idFileName, _idFileBytes),
        upload('business_permit', _businessPermitFileName,
            _businessPermitBytes),
        upload('orcr_file', _orcrFileName, _orcrBytes),
        upload('license_file', _licenseFileName, _licenseBytes),
      ];
    }

    return candidates.whereType<SignupUpload>().toList();
  }

  Future<void> handleSendResetCode() async {
    setState(() {
      errorMsg = '';
      successMsg = '';
      isSubmitting = true;
    });

    if (forgotEmail.text.trim().isEmpty) {
      setState(() {
        errorMsg = 'Please enter your email address.';
        isSubmitting = false;
      });
      return;
    }

    try {
      final response =
          await _api.sendPasswordResetCode(forgotEmail.text.trim());

      setState(() {
        isSubmitting = false;
        resetEmailCtrl.text = forgotEmail.text.trim();
        forgotEmail.clear();
        resetStep = 2;
        successMsg =
            response['message'] ?? 'Verification code sent to your email.';
      });
    } on ApiException catch (e) {
      setState(() {
        isSubmitting = false;
        errorMsg = e.message;
      });
    } catch (e) {
      setState(() {
        isSubmitting = false;
        errorMsg = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> handleVerifyResetCode() async {
    setState(() {
      errorMsg = '';
      successMsg = '';
    });

    if (resetCode.text.trim().length != 6) {
      setState(() => errorMsg = 'Please enter the 6-digit verification code.');
      return;
    }

    setState(() => isVerifying = true);

    try {
      final response = await _api.verifyPasswordResetCode(
        resetEmailCtrl.text.trim(),
        resetCode.text.trim(),
      );
      setState(() {
        isVerifying = false;
        resetStep = 3;
        successMsg = response['message'] ??
            'Code verified! Please enter your new password.';
      });
    } catch (e) {
      setState(() {
        isVerifying = false;
        errorMsg = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> handleResetPassword() async {
    setState(() {
      errorMsg = '';
      successMsg = '';
      isSubmitting = true;
    });

    if (newPassword.text.length < 8) {
      setState(() {
        errorMsg = 'Password must be at least 8 characters.';
        isSubmitting = false;
      });
      return;
    }

    if (newPassword.text != newConfirmPassword.text) {
      setState(() {
        errorMsg = 'Passwords do not match.';
        isSubmitting = false;
      });
      return;
    }

    try {
      final response = await _api.resetPassword(
        resetEmailCtrl.text.trim(),
        resetCode.text.trim(),
        newPassword.text,
        newConfirmPassword.text,
      );

      setState(() {
        isSubmitting = false;
        resetCode.clear();
        newPassword.clear();
        newConfirmPassword.clear();
        resetEmailCtrl.clear();
        resetStep = 1;
        mode = 'login';
        successMsg = response['message'] ?? 'Password reset successfully!';
      });
    } catch (e) {
      setState(() {
        isSubmitting = false;
        errorMsg = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> handleResendResetCode() async {
    setState(() {
      errorMsg = '';
      successMsg = '';
    });

    if (resetEmailCtrl.text.isEmpty) {
      setState(() {
        errorMsg = 'Email address not found. Please start over.';
        resetStep = 1;
      });
      return;
    }

    try {
      final response =
          await _api.resendPasswordResetCode(resetEmailCtrl.text.trim());
      setState(() => successMsg =
          response['message'] ?? 'New verification code sent to your email.');
    } catch (e) {
      setState(() => errorMsg = e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> logout() async {
    if (_authToken != null) {
      try {
        await _api.logout(_authToken!);
      } catch (e) {
        // Continue with logout even if API fails
      }
    }
    await _clearToken();
    setState(() {
      loggedInUser = null;
      errorMsg = '';
      successMsg = '';
    });
  }

  // ==================== Check Auth Status ====================

  Future<void> checkAuthStatus() async {
    final token = await _getToken();
    if (token == null) return;

    try {
      // GET /api/auth/user returns the raw Supabase user object (unlike
      // login's {access_token, user: {...}} shape) — role/status/name live
      // under user_metadata, same place the fresh-login handler reads them
      // from. The previous 'role': response['role'] here was reading a key
      // that doesn't exist on that shape, so it silently fell back to
      // 'buyer' for every restored session.
      final response = await _api.getUser(token);
      final userMetadata = (response['user_metadata'] as Map?) ?? {};
      final String role = (userMetadata['role'] ?? response['role'] ?? 'buyer').toString();
      final String status = (userMetadata['status'] ?? 'approved').toString();
      final String firstName = (userMetadata['first_name'] ?? '').toString();
      final String lastName = (userMetadata['last_name'] ?? '').toString();
      final String name = '$firstName $lastName'.trim();

      if (status == 'rejected') {
        await _clearToken();
        return;
      }

      // Web-only account types (seller, driver, logistics, admin) must not
      // resume a session on mobile — drop the token and stay on the auth
      // screen with a warning.
      if (!_isMobileAllowedRole(role)) {
        await _clearToken();
        setState(() => errorMsg = _webOnlyRoleMessage);
        return;
      }

      setState(() {
        loggedInUser = {
          'email': response['email'] ?? '',
          'role': role,
          'name': name,
          'status': status,
        };
        _authToken = token;
      });

      // Continue straight into the app instead of stranding an
      // already-valid session on the static "You're in!" screen. Every
      // mobile-allowed role has a registered route (see main.dart).
      _handleRoleBasedNavigation(role);
    } on ApiException catch (e) {
      // 401/419 = the token itself was rejected (expired/revoked/invalid) —
      // that's a real "you're logged out". Anything else (5xx, a malformed
      // response, ...) is the server having a bad moment, not proof the
      // session is invalid, so the token is kept and login is left in place
      // for the next attempt (e.g. pull-to-refresh) instead of forcing a
      // fresh sign-in.
      if (e.statusCode == 401 || e.statusCode == 419) {
        await _clearToken();
      } else {
        setState(() => errorMsg = e.message);
      }
    } catch (e) {
      // Network/timeout/parse errors — most commonly hit right after
      // reopening the app with a slow or momentarily-offline connection.
      // Closing the app must never log the user out, so the saved token is
      // left alone here; checkAuthStatus() will simply be retried the next
      // time the auth screen builds.
    }
  }

  @override
  void initState() {
    super.initState();
    checkAuthStatus();
    _loadProvinces();
  }

  // ==================== Navigation ====================

  String? _nameForCode(List<dynamic> list, String? code) {
    if (code == null) return null;
    for (final item in list) {
      if (item['code']?.toString() == code) return item['name']?.toString();
    }
    return null;
  }

  void onProvinceChanged(String? val) {
    setState(() {
      provinceCode = val;
      municipalityCode = null;
      municipalityName = null;
      barangayCode = null;
      barangay = null;
      _municipalities = [];
      _barangays = [];
    });
    if (val != null) _loadMunicipalities(val);
  }

  void onMunicipalityChanged(String? val) {
    setState(() {
      municipalityCode = val;
      barangayCode = null;
      barangay = null;
      _barangays = [];
      municipalityName = _nameForCode(_municipalities, val);
    });
    if (val != null) _loadBarangays(val);
  }

  void onBarangayChanged(String? val) {
    setState(() {
      barangayCode = val;
      barangay = _nameForCode(_barangays, val);
    });
  }

  void onCompanyProvinceChanged(String? val) {
    setState(() {
      companyProvinceCode = val;
      companyMunicipalityCode = null;
      companyMunicipalityName = null;
      companyBarangayCode = null;
      companyBarangay = null;
      _companyMunicipalities = [];
      _companyBarangays = [];
    });
    if (val != null) _loadCompanyMunicipalities(val);
  }

  void onCompanyMunicipalityChanged(String? val) {
    setState(() {
      companyMunicipalityCode = val;
      companyBarangayCode = null;
      companyBarangay = null;
      _companyBarangays = [];
      companyMunicipalityName = _nameForCode(_companyMunicipalities, val);
    });
    if (val != null) _loadCompanyBarangays(val);
  }

  void onCompanyBarangayChanged(String? val) {
    setState(() {
      companyBarangayCode = val;
      companyBarangay = _nameForCode(_companyBarangays, val);
    });
  }

  Future<void> goToStep(String step) async {
    if (selectedRole == 'driver') {
      if (step == 'driverVerifyEmail' && signupStep == 'driverPersonal') {
        final ok = _validatePersonalFields(
          first: driverFirstName,
          last: driverLastName,
          mi: driverMiddleInitial,
          emailCtrl: driverEmail,
          contact: driverContactNo,
          birthdayVal: driverBirthday,
          sexVal: driverSex,
          pFirst: 'driverFirstName',
          pLast: 'driverLastName',
          pMi: 'driverMiddleInitial',
          pEmail: 'driverEmail',
          pContact: 'driverContactNo',
          pBirthday: 'driverBirthday',
        );
        if (!ok) {
          setState(() {});
          return;
        }
        setState(() {
          signupStep = step;
          errorMsg = '';
          successMsg = '';
        });
        await _sendVerificationCodeStub();
        return;
      }
      if (step == 'driverAddress' && signupStep == 'driverVerifyEmail') {
        final ok = await _verifyCodeStub();
        if (!ok) return;
        setState(() {
          signupStep = step;
          errorMsg = '';
          successMsg = '';
        });
        return;
      }
      if (step == 'driverSecurity' && signupStep == 'driverAddress') {
        if (!_validateAddressFields(
            provinceCode, municipalityName, barangay, street,
            regionVal: region)) {
          setState(() {});
          return;
        }
      }
      if (step == 'driverDocuments' && signupStep == 'driverSecurity') {
        if (!_validateSecurityFields(driverPassword, driverConfirmPassword,
            'driverPassword', 'driverConfirmPassword')) {
          setState(() {});
          return;
        }
      }
    } else if (!isLogisticsSignup) {
      if (step == 'verifyEmail' && signupStep == 'personal') {
        final ok = _validatePersonalFields(
          first: firstName,
          last: lastName,
          mi: middleInitial,
          emailCtrl: email,
          contact: contactNo,
          birthdayVal: birthday,
          sexVal: sex,
          pFirst: 'firstName',
          pLast: 'lastName',
          pMi: 'middleInitial',
          pEmail: 'email',
          pContact: 'contactNo',
          pBirthday: 'birthday',
        );
        if (!ok) {
          setState(() {});
          return;
        }
        setState(() {
          signupStep = step;
          errorMsg = '';
          successMsg = '';
        });
        await _sendVerificationCodeStub();
        return;
      }
      if (step == 'address' && signupStep == 'verifyEmail') {
        final ok = await _verifyCodeStub();
        if (!ok) return;
        setState(() {
          signupStep = step;
          errorMsg = '';
          successMsg = '';
        });
        return;
      }
      if (step == 'security' && signupStep == 'address') {
        if (!_validateAddressFields(
            provinceCode, municipalityName, barangay, street,
            regionVal: region)) {
          setState(() {});
          return;
        }
      }
      if (step == 'documents' && signupStep == 'security') {
        if (!_validateSecurityFields(
            password, confirmPassword, 'password', 'confirmPassword')) {
          setState(() {});
          return;
        }
      }
    } else {
      if (step == 'companyVerifyEmail' && signupStep == 'company') {
        if (!_validateCompany()) {
          setState(() {});
          return;
        }
        setState(() {
          signupStep = step;
          errorMsg = '';
          successMsg = '';
        });
        await _sendVerificationCodeStub();
        return;
      }
      if (step == 'owner' && signupStep == 'companyVerifyEmail') {
        final ok = await _verifyCodeStub();
        if (!ok) return;
        setState(() {
          signupStep = step;
          errorMsg = '';
          successMsg = '';
        });
        return;
      }
      if (step == 'address' && signupStep == 'owner') {
        if (!_validateOwner()) {
          setState(() {});
          return;
        }
      }
      if (step == 'security' && signupStep == 'address') {
        if (!_validateAddressFields(companyProvinceCode,
            companyMunicipalityName, companyBarangay, companyStreet)) {
          setState(() {});
          return;
        }
      }
      if (step == 'documents' && signupStep == 'security') {
        if (!_validateSecurityFields(
            password, confirmPassword, 'password', 'confirmPassword')) {
          setState(() {});
          return;
        }
      }
    }

    setState(() {
      signupStep = step;
      errorMsg = '';
      successMsg = '';
    });
  }

  void _handleBackNavigation() {
    if (mode == 'forgot' || mode == 'reset') {
      if (resetStep > 1) {
        setState(() {
          resetStep -= 1;
          errorMsg = '';
          successMsg = '';
        });
      } else {
        switchMode('login');
      }
      return;
    }

    if (mode == 'signup') {
      if (signupStep == 'role' || signupStep == 'complete') {
        switchMode('login');
        return;
      }
      final idx = currentStepIndex;
      if (idx <= 0) {
        setState(() {
          isLogisticsSignup = false;
          selectedRole = null;
          signupStep = 'role';
          errorMsg = '';
          successMsg = '';
        });
      } else {
        goToStep(_activeStepKeys[idx - 1]);
      }
    }
  }

  void switchMode(String next) {
    setState(() {
      mode = next;
      signupStep = 'role';
      selectedRole = null;
      isLogisticsSignup = false;
      errorMsg = '';
      successMsg = '';
      resetStep = 1;
      isSubmitting = false;

      for (final c in _allControllers) {
        c.clear();
      }
      validationErrors.clear();

      provinceCode = null;
      municipalityCode = null;
      municipalityName = null;
      barangayCode = null;
      barangay = null;
      companyProvinceCode = null;
      companyMunicipalityCode = null;
      companyMunicipalityName = null;
      companyBarangayCode = null;
      companyBarangay = null;

      sex = '';
      ownerSex = '';
      driverSex = '';
      vehicle = '';
      driverVehicle = '';
      lineOfBusiness = '';
      region = '';
      companyRegion = '';
      idType = '';
      driverIdType = '';
      ownerIdType = '';

      birthday = null;
      ownerBirthday = null;
      driverBirthday = null;

      idFileUploaded = false;
      businessPermitUploaded = false;
      orcrUploaded = false;
      licenseUploaded = false;
      ownerIdUploaded = false;
      businessPermitFileUploaded = false;
      mayorPermitUploaded = false;
      dtiRegUploaded = false;
      driverIdUploaded = false;
      driverLicenseUploaded = false;
      driverOrcrUploaded = false;
    });
  }


  void selectRole(String role) {
    setState(() {
      selectedRole = role;
      errorMsg = '';
      successMsg = '';
      validationErrors.clear();
      signupStep = role == 'driver' ? 'driverPersonal' : 'personal';
    });
  }

  // ==================== Build ====================
  // Mobile-first: a single scrollable glass column on phones. On wider
  // viewports (tablet/desktop) the same content centers inside a
  // fixed-width glass shell, rather than stretching edge-to-edge — the
  // aurora backdrop fills the rest so the shell always reads as a card
  // floating in space.

  bool get _showAppBarBack {
    if (loggedInUser != null) return false;
    if (mode == 'login') return false;
    if (mode == 'signup' &&
        (signupStep == 'role' || signupStep == 'complete')) {
      return false;
    }
    return true;
  }

  String _appBarTitle() {
    if (mode == 'forgot' || mode == 'reset') return 'Reset Password';
    if (mode == 'signup') {
      final idx = currentStepIndex;
      if (idx < 0 || idx >= _activeStepLabels.length) return 'Sign Up';
      return _activeStepLabels[idx];
    }
    return '';
  }

  PreferredSizeWidget? _buildAppBar() {
    if (!_showAppBarBack) return null;
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.slate800),
        onPressed: _handleBackNavigation,
        tooltip: 'Back',
      ),
      title: Text(_appBarTitle(),
          style: const TextStyle(color: AppColors.slate900, fontSize: 16, fontWeight: FontWeight.w700)),
      centerTitle: true,
    );
  }

  Widget? _buildBottomActionBar() {
    if (loggedInUser != null || mode != 'signup') return null;
    if (signupStep == 'role' || signupStep == 'complete') return null;

    final keys = _activeStepKeys;
    final idx = currentStepIndex;
    if (idx < 0) return null;
    final isLast = idx == keys.length - 1;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.slate200)),
        ),
        child: SolidButton(
          label: isLast ? (isSubmitting ? 'Submitting...' : 'Submit') : 'Continue',
          icon: isLast ? null : Icons.arrow_forward_rounded,
          onPressed: isSubmitting ? null : () => isLast ? submitRegistration() : goToStep(keys[idx + 1]),
          loading: isLast && isSubmitting,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAppBar = _showAppBarBack;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        appBar: _buildAppBar(),
        bottomNavigationBar: _buildBottomActionBar(),
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 640;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isWide ? 440 : double.infinity),
                  child: _buildScreen(hasAppBar),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildScreen(bool hasAppBar) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24, hasAppBar ? 20 : 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!hasAppBar) _buildHeader(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero)
                    .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey('$mode-$signupStep'),
              child: _buildRightContent(),
            ),
          ),
        ],
      ),
    );
  }

  /// Brand lockup, page heading and the Log in / Sign up switch. Only
  /// shown on the two root screens (login, role picker) — wizard steps use
  /// the app bar's title instead so the heading never fights the step
  /// context for attention.
  Widget _buildHeader() {
    final isLogin = mode == 'login';
    final String title;
    final String subtitle;
    if (_isPartnerPortal) {
      title = isLogin ? 'Partner log in' : 'Ship with us';
      subtitle = isLogin
          ? 'For couriers and logistics companies.'
          : 'Deliver with BuyTheWay and earn on your schedule.';
    } else {
      title = isLogin ? 'Welcome back' : 'Join BuyTheWay';
      subtitle = isLogin
          ? 'Log in to pick up where you left off.'
          : 'Create your account and start shopping.';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Row(children: [
            const BagLogo(size: 40),
            const SizedBox(width: 8),
            const BrandWordmark(fontSize: 22),
            if (_isPartnerPortal) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: BrandColors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.local_shipping_outlined, size: 14, color: BrandColors.blueDark),
                  SizedBox(width: 5),
                  Text('Partner',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: BrandColors.blueDark)),
                ]),
              ),
            ],
          ]),
          const SizedBox(height: 32),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            layoutBuilder: (current, previous) =>
                Stack(alignment: Alignment.topLeft, children: [...previous, if (current != null) current]),
            child: Column(
              key: ValueKey(isLogin),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontFamily: kBrandFont,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        fontVariations: [FontVariation('wght', 900)],
                        color: AppColors.slate900,
                        letterSpacing: -0.4,
                        height: 1.15)),
                const SizedBox(height: 6),
                Text(subtitle,
                    style: const TextStyle(fontSize: 14.5, color: AppColors.slate500, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SolidSegmented(
            labels: const ['Log in', 'Sign up'],
            index: isLogin ? 0 : 1,
            onChanged: (i) => switchMode(i == 0 ? 'login' : 'signup'),
          ),
        ],
      ),
    );
  }

  Widget _buildRightContent() {
    if (loggedInUser != null) return _buildLoggedIn();
    switch (mode) {
      case 'login':
        return _buildLoginForm();
      case 'forgot':
      case 'reset':
        return _buildResetWizard();
      case 'signup':
      default:
        return _buildSignupFlow();
    }
  }

  // ---------------- Login ----------------

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SolidField(
            label: 'Email Address',
            controller: email,
            required: true,
            hint: 'juan@email.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email]),
        const SizedBox(height: 14),
        SolidField(
          label: 'Password',
          controller: password,
          required: true,
          hint: 'Enter your password',
          icon: Icons.lock_outline_rounded,
          obscure: !showPassword,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!isSubmitting) handleLogin();
          },
          suffix: IconButton(
            icon: Icon(showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 19, color: AppColors.slate400),
            onPressed: () => setState(() => showPassword = !showPassword),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () => setState(() => rememberMe = !rememberMe),
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: rememberMe,
                      activeColor: BrandColors.blue,
                      onChanged: (v) => setState(() => rememberMe = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('Remember me',
                      style: TextStyle(fontSize: 13, color: AppColors.slate600)),
                ],
              ),
            ),
            TextButton(
              onPressed: () => switchMode('forgot'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              child: const Text('Forgot password?',
                  style: TextStyle(color: BrandColors.blueDark, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ],
        ),
        SolidBanner(error: errorMsg, success: successMsg),
        const SizedBox(height: 18),
        SolidButton(
          label: isSubmitting ? 'Signing in...' : 'Log In',
          onPressed: isSubmitting ? null : handleLogin,
          loading: isSubmitting,
        ),
        const SizedBox(height: 18),
        const OrDivider(),
        const SizedBox(height: 18),
        GoogleButton(onPressed: isSubmitting ? null : _handleGoogleAuth),
        _buildPortalSwitch(),
      ],
    );
  }

  /// Footer link between the buyer and partner portals.
  Widget _buildPortalSwitch() {
    final prompt = _isPartnerPortal ? 'Shopping instead?' : 'Courier or logistics company?';
    final action = _isPartnerPortal ? 'Go to buyer portal' : 'Ship with us';
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(prompt, style: const TextStyle(fontSize: 13.5, color: AppColors.slate500)),
            TextButton.icon(
              onPressed: isSubmitting ? null : _switchPortal,
              iconAlignment: IconAlignment.end,
              icon: Icon(
                  _isPartnerPortal ? Icons.shopping_bag_outlined : Icons.local_shipping_outlined,
                  size: 17),
              label: Text(action,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              style: TextButton.styleFrom(
                foregroundColor: BrandColors.blueDark,
                minimumSize: const Size(44, 44),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _switchPortal() {
    final nav = Navigator.of(context);
    // The partner portal is pushed over the buyer portal, so going back is a pop.
    if (_isPartnerPortal && nav.canPop()) {
      nav.pop();
      return;
    }
    final target = _isPartnerPortal ? AuthPortal.buyer : AuthPortal.partner;
    final route = PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => AuthScreen(portal: target),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    );
    _isPartnerPortal ? nav.pushReplacement(route) : nav.push(route);
  }

  // ---------------- Forgot / reset password wizard ----------------

  Widget _buildResetWizard() {
    const labels = ['Email', 'Verify code', 'New password'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SolidProgress(total: 3, currentIndex: resetStep - 1, stepLabel: labels[resetStep - 1]),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(
            resetStep == 1
                ? 'Enter your email to receive a verification code.'
                : (resetStep == 2
                    ? 'Enter the 6-digit code sent to your email.'
                    : 'Create a new password for your account.'),
            style: const TextStyle(color: AppColors.slate600, fontSize: 14, height: 1.4),
          ),
        ),
        const SizedBox(height: 10),
        if (resetStep == 1) _resetStep1(),
        if (resetStep == 2) _resetStep2(),
        if (resetStep == 3) _resetStep3(),
      ],
    );
  }

  Widget _resetStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SolidField(
            label: 'Email Address',
            controller: forgotEmail,
            required: true,
            hint: 'juan@email.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) {
              if (!isSubmitting) handleSendResetCode();
            }),
        SolidBanner(error: errorMsg, success: successMsg),
        const SizedBox(height: 16),
        SolidButton(
          label: isSubmitting ? 'Sending...' : 'Send Verification Code',
          onPressed: isSubmitting ? null : handleSendResetCode,
          loading: isSubmitting,
        ),
      ],
    );
  }

  Widget _resetStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SolidField(
            label: 'Verification Code',
            controller: resetCode,
            required: true,
            hint: '6-digit code',
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            maxLength: 6),
        const SizedBox(height: 4),
        const Text('Check your email for the code. Expires in 15 minutes.',
            style: TextStyle(color: AppColors.slate500, fontSize: 12)),
        SolidBanner(error: errorMsg, success: successMsg),
        const SizedBox(height: 16),
        SolidButton(
          label: isVerifying ? 'Verifying...' : 'Verify Code',
          onPressed: isVerifying ? null : handleVerifyResetCode,
          loading: isVerifying,
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: handleResendResetCode,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              child: const Text('Resend code',
                  style: TextStyle(color: BrandColors.blueDark, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            TextButton(
              onPressed: () => setState(() {
                resetStep = 1;
                errorMsg = '';
                successMsg = '';
              }),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              child: const Text('Change email',
                  style: TextStyle(color: BrandColors.blueDark, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _resetStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SolidField(
          label: 'New Password',
          controller: newPassword,
          required: true,
          hint: 'Min 8 characters',
          icon: Icons.lock_outline_rounded,
          obscure: !showPassword,
          suffix: IconButton(
            icon: Icon(showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 19, color: AppColors.slate400),
            onPressed: () => setState(() => showPassword = !showPassword),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: newPassword,
          builder: (context, value, _) => PasswordStrengthMeter(password: value.text),
        ),
        const SizedBox(height: 12),
        SolidField(
            label: 'Confirm New Password',
            controller: newConfirmPassword,
            required: true,
            hint: 'Re-enter password',
            icon: Icons.lock_outline_rounded,
            obscure: !showPassword),
        SolidBanner(error: errorMsg, success: successMsg),
        const SizedBox(height: 16),
        SolidButton(
          label: isSubmitting ? 'Resetting...' : 'Reset Password',
          onPressed: isSubmitting ? null : handleResetPassword,
          loading: isSubmitting,
        ),
      ],
    );
  }

  // ---------------- Signup flow ----------------

  Widget _buildSignupFlow() => _buildSignupBody();

  Widget _buildSignupBody() {
    if (signupStep == 'complete') return _buildComplete();
    if (signupStep == 'role' && !isLogisticsSignup) {
      return _buildRoleSelection();
    }
    if (isLogisticsSignup) return _buildLogisticsWizard();
    if (selectedRole == 'driver') return _buildDriverWizard();
    return _buildRegularWizard();
  }

  Widget _buildRoleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...roles.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SolidChoiceCard(
                icon: r['icon'] as IconData,
                label: r['label'] as String,
                description: r['desc'] as String,
                selected: selectedRole == r['id'],
                onTap: () => selectRole(r['id'] as String),
              ),
            )),
        const SizedBox(height: 6),
        Text(
          _isPartnerPortal
              ? 'Logistics company and driver accounts are created through a web browser.'
              : 'Seller accounts are only available through a web browser.',
          style: const TextStyle(color: AppColors.slate500, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 22),
        const OrDivider(),
        const SizedBox(height: 18),
        GoogleButton(onPressed: _handleGoogleAuth, label: 'Sign up with Google'),
        _buildPortalSwitch(),
      ],
    );
  }

  Widget _wizardHeader({required String kicker}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Text(kicker,
          style: const TextStyle(color: AppColors.slate500, fontSize: 13.5, height: 1.4)),
    );
  }

  // ---------------- Regular wizard (buyer/seller/courier) ----------------

  Widget _buildRegularWizard() {
    final idx = currentStepIndex;
    final safeIdx = idx < 0 ? 0 : idx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SolidProgress(total: steps.length, currentIndex: safeIdx, stepLabel: steps[safeIdx]),
        _wizardHeader(kicker: 'Registering as ${selectedRole ?? ''}'),
        _regularStepBody(),
      ],
    );
  }

  Widget _regularStepBody() {
    switch (signupStep) {
      case 'personal':
        return _personalFields();
      case 'verifyEmail':
        return _verifyEmailFields(email.text);
      case 'address':
        return _addressFields(isCompany: false);
      case 'security':
        return _securityFields(
            password, confirmPassword, 'password', 'confirmPassword');
      case 'documents':
        return _documentsFields();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _personalFields() {
    return Column(
      children: [
        SolidField(
            label: 'Last Name',
            controller: lastName,
            required: true,
            hint: 'Dela Cruz',
            icon: Icons.badge_outlined,
            textCapitalization: TextCapitalization.words,
            error: validationErrors['lastName']),
        const SizedBox(height: 12),
        SolidField(
            label: 'First Name',
            controller: firstName,
            required: true,
            hint: 'Juan',
            icon: Icons.badge_outlined,
            textCapitalization: TextCapitalization.words,
            error: validationErrors['firstName']),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 2,
            child: SolidField(
                label: 'M.I.',
                controller: middleInitial,
                hint: 'B',
                maxLength: 1,
                textCapitalization: TextCapitalization.characters,
                error: validationErrors['middleInitial']),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: SolidDropdown(
                label: 'Sex',
                required: true,
                value: sex.isEmpty ? null : sex,
                items: const ['Male', 'Female'],
                icon: Icons.wc_rounded,
                onChanged: (v) => setState(() => sex = v ?? '')),
          ),
        ]),
        const SizedBox(height: 12),
        SolidDateField(
            label: 'Birthday',
            required: true,
            value: birthday,
            onChanged: (d) => setState(() => birthday = d),
            error: validationErrors['birthday']),
        const SizedBox(height: 20),
        const SectionDivider(label: 'Contact details'),
        const SizedBox(height: 14),
        SolidField(
            label: 'Contact No.',
            controller: contactNo,
            required: true,
            hint: '09XXXXXXXXX',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            maxLength: 11,
            error: validationErrors['contactNo']),
        const SizedBox(height: 12),
        SolidField(
            label: 'Email',
            controller: email,
            required: true,
            hint: 'juan@email.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            error: validationErrors['email']),
      ],
    );
  }

  Widget _verifyEmailFields(String targetEmail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(Icons.mark_email_read_outlined, size: 20, color: BrandColors.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(TextSpan(
                  style: const TextStyle(color: AppColors.slate600, fontSize: 13, height: 1.4),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit code to '),
                    TextSpan(
                        text: targetEmail.isEmpty ? '—' : targetEmail,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.slate800)),
                    const TextSpan(text: '.'),
                  ])),
            ),
          ]),
        ),
        if (successMsg.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(successMsg, style: const TextStyle(color: AppColors.successGreen, fontSize: 12))),
        const SizedBox(height: 16),
        SolidField(
            label: 'Verification Code',
            controller: signupVerifyCode,
            required: true,
            hint: '6-digit code',
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            maxLength: 6),
        const SizedBox(height: 4),
        const Text('Code expires in 15 minutes.',
            style: TextStyle(color: AppColors.slate500, fontSize: 12)),
        const SizedBox(height: 8),
        TextButton(
          onPressed: isSendingCode ? null : _sendVerificationCodeStub,
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
          child: const Text('Resend code',
              style: TextStyle(color: BrandColors.blueDark, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        if (errorMsg.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(errorMsg, style: const TextStyle(color: AppColors.errorRed, fontSize: 12))),
      ],
    );
  }

  Widget _addressFields({required bool isCompany}) {
    final pCode = isCompany ? companyProvinceCode : provinceCode;
    final mCode = isCompany ? companyMunicipalityCode : municipalityCode;
    final bCode = isCompany ? companyBarangayCode : barangayCode;
    final streetCtrl = isCompany ? companyStreet : street;
    final houseCtrl = isCompany ? companyHouseNo : houseNo;

    final provinces = isCompany ? _companyProvinces : _provinces;
    final municipalities = isCompany ? _companyMunicipalities : _municipalities;
    final barangays = isCompany ? _companyBarangays : _barangays;
    final loadingProvinces =
        isCompany ? _loadingCompanyProvinces : _loadingProvinces;
    final loadingMunicipalities =
        isCompany ? _loadingCompanyMunicipalities : _loadingMunicipalities;
    final loadingBarangays =
        isCompany ? _loadingCompanyBarangays : _loadingBarangays;

    return Column(
      children: [
        // Island group. Asked before the PSGC chain because it's what the
        // backend files the address under (addresses.region_name) and how
        // logistics coverage is matched. The company address skips it —
        // the logistics wizard collects its region on the Company step.
        if (!isCompany) ...[
          SolidDropdown(
            label: 'Region',
            required: true,
            value: region.isEmpty ? null : region,
            items: kRegionOptions,
            hint: 'Select Region',
            icon: Icons.public_rounded,
            onChanged: (v) => setState(() => region = v ?? ''),
          ),
          const SizedBox(height: 12),
        ],
        SolidDropdown(
          label: 'Province',
          required: true,
          value: pCode,
          items: provinces.map((p) => p['code']?.toString() ?? '').toList(),
          displayItems: provinces.map((p) => p['name']?.toString() ?? '').toList(),
          hint: loadingProvinces ? 'Loading provinces...' : 'Select province',
          enabled: !loadingProvinces,
          icon: Icons.location_on_outlined,
          onChanged: (v) => isCompany ? onCompanyProvinceChanged(v) : onProvinceChanged(v),
        ),
        const SizedBox(height: 12),
        SolidDropdown(
          label: 'Municipality / City',
          required: true,
          value: mCode,
          items: municipalities.map((m) => m['code']?.toString() ?? '').toList(),
          displayItems: municipalities.map((m) => m['name']?.toString() ?? '').toList(),
          hint: loadingMunicipalities
              ? 'Loading...'
              : (pCode != null ? 'Select municipality/city' : 'Select a province first'),
          enabled: pCode != null && !loadingMunicipalities,
          onChanged: (v) =>
              isCompany ? onCompanyMunicipalityChanged(v) : onMunicipalityChanged(v),
        ),
        const SizedBox(height: 12),
        SolidDropdown(
          label: 'Barangay',
          required: true,
          value: bCode,
          items: barangays.map((b) => b['code']?.toString() ?? '').toList(),
          displayItems: barangays.map((b) => b['name']?.toString() ?? '').toList(),
          hint: loadingBarangays
              ? 'Loading...'
              : (mCode != null ? 'Select barangay' : 'Select a municipality/city first'),
          enabled: mCode != null && !loadingBarangays,
          onChanged: (v) => isCompany ? onCompanyBarangayChanged(v) : onBarangayChanged(v),
        ),
        const SizedBox(height: 20),
        const SectionDivider(label: 'Street address'),
        const SizedBox(height: 14),
        SolidField(
            label: 'Street',
            controller: streetCtrl,
            required: true,
            hint: 'Street name',
            icon: Icons.signpost_outlined),
        const SizedBox(height: 12),
        SolidField(
            label: 'House / Unit #',
            controller: houseCtrl,
            hint: '123, Unit B',
            icon: Icons.home_outlined),
        if (_addressError.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_addressError, style: const TextStyle(color: AppColors.errorRed, fontSize: 12))),
        if (errorMsg.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(errorMsg, style: const TextStyle(color: AppColors.errorRed, fontSize: 12))),
      ],
    );
  }

  Widget _securityFields(TextEditingController pw, TextEditingController cpw,
      String keyPw, String keyCpw) {
    return Column(
      children: [
        SolidField(
          label: 'Password',
          controller: pw,
          required: true,
          hint: 'Min 8 characters',
          icon: Icons.lock_outline_rounded,
          obscure: !showPassword,
          error: validationErrors[keyPw],
          suffix: IconButton(
            icon: Icon(showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 19, color: AppColors.slate400),
            onPressed: () => setState(() => showPassword = !showPassword),
          ),
        ),
        // Advisory only — the blocking rule is still "at least 8
        // characters", the same one app.js and Laravel enforce. Rebuilds
        // off the controller directly so typing doesn't setState the
        // whole wizard on every keystroke.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: pw,
          builder: (context, value, _) => PasswordStrengthMeter(password: value.text),
        ),
        const SizedBox(height: 12),
        SolidField(
            label: 'Confirm Password',
            controller: cpw,
            required: true,
            hint: 'Re-enter password',
            icon: Icons.lock_outline_rounded,
            obscure: !showPassword,
            error: validationErrors[keyCpw]),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => setState(() => showPassword = !showPassword),
          borderRadius: BorderRadius.circular(6),
          child: Row(children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                  value: showPassword,
                  activeColor: BrandColors.blue,
                  onChanged: (v) => setState(() => showPassword = v ?? false)),
            ),
            const SizedBox(width: 6),
            const Text('Show passwords', style: TextStyle(fontSize: 13, color: AppColors.slate600)),
          ]),
        ),
      ],
    );
  }

  /// The "ID Type" dropdown that pairs with a valid-ID upload. Every
  /// wizard shows exactly one (see [idType]).
  Widget _idTypeDropdown(String value, ValueChanged<String> onChanged) {
    return SolidDropdown(
      label: 'ID Type',
      required: true,
      value: value.isEmpty ? null : value,
      items: kIdTypeOptions,
      hint: 'Select the ID you are uploading',
      icon: Icons.badge_outlined,
      onChanged: (v) => onChanged(v ?? ''),
    );
  }

  Widget _documentsFields() {
    final children = <Widget>[];
    if (selectedRole == 'buyer') {
      children.addAll([
        _idTypeDropdown(idType, (v) => setState(() => idType = v)),
        const SizedBox(height: 12),
        SolidUploadRow(
            label: 'Upload ID',
            required: true,
            uploaded: idFileUploaded,
            fileName: _idFileName,
            onTap: () => _pickFile('idFile')),
      ]);
    } else if (selectedRole == 'seller') {
      children.addAll([
        SolidField(
            label: 'Business Name',
            controller: businessName,
            required: true,
            hint: 'My Store',
            icon: Icons.storefront_outlined),
        const SizedBox(height: 12),
        SolidDropdown(
          label: 'Line of Business',
          required: true,
          value: lineOfBusiness.isEmpty ? null : lineOfBusiness,
          items: kLineOfBusinessOptions,
          hint: 'Select Line of Business',
          icon: Icons.category_outlined,
          onChanged: (v) => setState(() => lineOfBusiness = v ?? ''),
        ),
        const SizedBox(height: 20),
        const SectionDivider(label: 'Verification documents'),
        const SizedBox(height: 14),
        _idTypeDropdown(idType, (v) => setState(() => idType = v)),
        const SizedBox(height: 12),
        SolidUploadRow(
            label: 'Upload ID',
            required: true,
            uploaded: idFileUploaded,
            fileName: _idFileName,
            onTap: () => _pickFile('idFile')),
        const SizedBox(height: 10),
        SolidUploadRow(
            label: 'Upload Business Permit',
            required: true,
            uploaded: businessPermitUploaded,
            fileName: _businessPermitFileName,
            onTap: () => _pickFile('businessPermit')),
      ]);
    } else if (selectedRole == 'courier') {
      children.addAll([
        SolidDropdown(
          label: 'Vehicle',
          required: true,
          value: vehicle.isEmpty ? null : vehicle,
          items: const ['Motorcycle', 'Car', 'Van', 'Bicycle'],
          icon: Icons.two_wheeler_outlined,
          onChanged: (v) => setState(() => vehicle = v ?? ''),
        ),
        const SizedBox(height: 12),
        SolidField(
            label: 'Plate Number',
            controller: plateNumber,
            required: true,
            hint: 'ABC-1234',
            icon: Icons.pin_outlined,
            textCapitalization: TextCapitalization.characters),
        const SizedBox(height: 20),
        const SectionDivider(label: 'Verification documents'),
        const SizedBox(height: 14),
        SolidUploadRow(
            label: 'Upload OR/CR',
            required: true,
            uploaded: orcrUploaded,
            fileName: _orcrFileName,
            onTap: () => _pickFile('orcrFile')),
        const SizedBox(height: 10),
        // For a courier the ID-type dropdown describes the license upload
        // below it rather than a separate valid ID — that's the
        // `drivers_license` doc_type in AuthController::PRIMARY_ID_DOC_TYPE.
        _idTypeDropdown(idType, (v) => setState(() => idType = v)),
        const SizedBox(height: 12),
        SolidUploadRow(
            label: "Upload ID / Driver's License",
            required: true,
            uploaded: licenseUploaded,
            fileName: _licenseFileName,
            onTap: () => _pickFile('licenseFile')),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...children,
        SolidBanner(error: errorMsg, success: successMsg),
      ],
    );
  }

  // ---------------- Driver wizard ----------------

  Widget _buildDriverWizard() {
    final idx = currentStepIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepIndicator(total: driverSteps.length, currentIndex: idx),
        const SizedBox(height: 14),
        _wizardHeader(kicker: 'Driver Registration'),
        _driverStepBody(),
      ],
    );
  }

  Widget _driverStepBody() {
    switch (signupStep) {
      case 'driverPersonal':
        return _driverPersonalFields();
      case 'driverVerifyEmail':
        return _verifyEmailFields(driverEmail.text);
      case 'driverAddress':
        return _addressFields(isCompany: false);
      case 'driverSecurity':
        return _securityFields(driverPassword, driverConfirmPassword,
            'driverPassword', 'driverConfirmPassword');
      case 'driverDocuments':
        return _driverDocumentsFields();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _driverPersonalFields() {
    return Column(
      children: [
        LabeledField(
            label: 'Last Name',
            controller: driverLastName,
            required: true,
            hint: 'Dela Cruz',
            error: validationErrors['driverLastName']),
        const SizedBox(height: 12),
        LabeledField(
            label: 'First Name',
            controller: driverFirstName,
            required: true,
            hint: 'Juan',
            error: validationErrors['driverFirstName']),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            flex: 2,
            child: LabeledField(
                label: 'M.I.',
                controller: driverMiddleInitial,
                hint: 'B',
                maxLength: 1,
                error: validationErrors['driverMiddleInitial']),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: LabeledDropdown(
                label: 'Sex',
                required: true,
                value: driverSex.isEmpty ? null : driverSex,
                items: const ['Male', 'Female'],
                onChanged: (v) => setState(() => driverSex = v ?? '')),
          ),
        ]),
        const SizedBox(height: 12),
        LabeledDateField(
            label: 'Birthday',
            required: true,
            value: driverBirthday,
            onChanged: (d) => setState(() => driverBirthday = d),
            error: validationErrors['driverBirthday']),
        const SizedBox(height: 12),
        LabeledField(
            label: 'Contact No.',
            controller: driverContactNo,
            required: true,
            hint: '09XXXXXXXXX',
            keyboardType: TextInputType.phone,
            maxLength: 11,
            error: validationErrors['driverContactNo']),
        const SizedBox(height: 12),
        LabeledField(
            label: 'Email',
            controller: driverEmail,
            required: true,
            hint: 'driver@email.com',
            keyboardType: TextInputType.emailAddress,
            error: validationErrors['driverEmail']),
      ],
    );
  }

  Widget _driverDocumentsFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledDropdown(
          label: 'Vehicle Type',
          required: true,
          value: driverVehicle.isEmpty ? null : driverVehicle,
          items: const ['Motorcycle', 'Car', 'Van', 'Truck'],
          onChanged: (v) => setState(() => driverVehicle = v ?? ''),
        ),
        const SizedBox(height: 12),
        LabeledField(
            label: 'Plate Number',
            controller: driverPlateNumber,
            required: true,
            hint: 'ABC-1234'),
        const SizedBox(height: 12),
        LabeledField(
            label: 'License Number',
            controller: driverLicenseNumber,
            hint: "Driver's License #"),
        const SizedBox(height: 12),
        _idTypeDropdown(driverIdType, (v) => setState(() => driverIdType = v)),
        const SizedBox(height: 12),
        UploadTile(
            label: 'Upload Valid ID',
            required: true,
            uploaded: driverIdUploaded,
            fileName: _driverIdFileName,
            onTap: () => _pickFile('driverIdFile')),
        const SizedBox(height: 12),
        UploadTile(
            label: "Upload Driver's License",
            required: true,
            uploaded: driverLicenseUploaded,
            fileName: _driverLicenseFileName,
            onTap: () => _pickFile('driverLicenseFile')),
        const SizedBox(height: 12),
        UploadTile(
            label: 'Upload OR/CR',
            required: true,
            uploaded: driverOrcrUploaded,
            fileName: _driverOrcrFileName,
            onTap: () => _pickFile('driverOrcrFile')),
        if (errorMsg.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(errorMsg,
                  style: const TextStyle(
                      color: AppColors.errorRed, fontSize: 12))),
      ],
    );
  }

  // ---------------- Logistics wizard ----------------

  Widget _buildLogisticsWizard() {
    final idx = currentStepIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepIndicator(total: logisticsSteps.length, currentIndex: idx),
        const SizedBox(height: 14),
        _wizardHeader(kicker: 'Logistics Company Registration'),
        _logisticsStepBody(),
      ],
    );
  }

  Widget _logisticsStepBody() {
    switch (signupStep) {
      case 'company':
        return _companyFields();
      case 'companyVerifyEmail':
        return _verifyEmailFields(companyEmail.text);
      case 'owner':
        return _ownerFields();
      case 'address':
        return _addressFields(isCompany: true);
      case 'security':
        return _securityFields(
            password, confirmPassword, 'password', 'confirmPassword');
      case 'documents':
        return _logisticsDocumentsFields();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _companyFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledField(
            label: 'Company Name',
            controller: companyName,
            required: true,
            hint: 'ABC Logistics Inc.'),
        const SizedBox(height: 12),
        LabeledField(
            label: 'Company Email',
            controller: companyEmail,
            required: true,
            hint: 'info@abclogistics.com',
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 12),
        LabeledDropdown(
          label: 'Region',
          required: true,
          value: companyRegion.isEmpty ? null : companyRegion,
          items: const ['Luzon', 'Visayas', 'Mindanao'],
          hint: 'Select Region',
          onChanged: (v) => setState(() => companyRegion = v ?? ''),
        ),
        const SizedBox(height: 12),
        LabeledField(
            label: 'Contact No.',
            controller: companyContactNo,
            required: true,
            hint: '09XXXXXXXXX',
            keyboardType: TextInputType.phone,
            maxLength: 11),
        const SizedBox(height: 12),
        LabeledField(
            label: 'TIN',
            controller: companyTIN,
            required: true,
            hint: '123-456-789-000'),
        const SizedBox(height: 12),
        LabeledField(
            label: 'SEC Registration #',
            controller: companySECReg,
            hint: 'SEC Reg. No. (if applicable)'),
        if (errorMsg.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(errorMsg,
                  style: const TextStyle(
                      color: AppColors.errorRed, fontSize: 12))),
      ],
    );
  }

  Widget _ownerFields() {
    return Column(
      children: [
        LabeledField(
            label: 'Owner Last Name',
            controller: ownerLastName,
            required: true,
            hint: 'Dela Cruz'),
        const SizedBox(height: 12),
        LabeledField(
            label: 'Owner First Name',
            controller: ownerFirstName,
            required: true,
            hint: 'Juan'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            flex: 2,
            child: LabeledField(
                label: 'M.I.',
                controller: ownerMiddleInitial,
                hint: 'B',
                maxLength: 1),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: LabeledDropdown(
                label: 'Sex',
                required: true,
                value: ownerSex.isEmpty ? null : ownerSex,
                items: const ['Male', 'Female'],
                onChanged: (v) => setState(() => ownerSex = v ?? '')),
          ),
        ]),
        const SizedBox(height: 12),
        LabeledDateField(
            label: 'Birthday',
            required: true,
            value: ownerBirthday,
            onChanged: (d) => setState(() => ownerBirthday = d)),
        if (errorMsg.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(errorMsg,
                  style: const TextStyle(
                      color: AppColors.errorRed, fontSize: 12))),
      ],
    );
  }

  Widget _logisticsDocumentsFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _idTypeDropdown(ownerIdType, (v) => setState(() => ownerIdType = v)),
        const SizedBox(height: 12),
        UploadTile(
            label: "Owner's Valid ID",
            required: true,
            uploaded: ownerIdUploaded,
            fileName: _ownerIdFileName,
            onTap: () => _pickFile('ownerIdFile')),
        const SizedBox(height: 12),
        UploadTile(
            label: 'Business Permit',
            required: true,
            uploaded: businessPermitFileUploaded,
            fileName: _businessPermitFileFileName,
            onTap: () => _pickFile('businessPermitFile')),
        const SizedBox(height: 12),
        UploadTile(
            label: "Mayor's Permit",
            required: true,
            uploaded: mayorPermitUploaded,
            fileName: _mayorPermitFileName,
            onTap: () => _pickFile('mayorPermitFile')),
        const SizedBox(height: 12),
        UploadTile(
            label: 'DTI / SEC Registration',
            required: true,
            uploaded: dtiRegUploaded,
            fileName: _dtiRegFileName,
            onTap: () => _pickFile('dtiRegFile')),
        if (errorMsg.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(errorMsg,
                  style: const TextStyle(
                      color: AppColors.errorRed, fontSize: 12))),
        if (successMsg.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(successMsg,
                  style: const TextStyle(
                      color: AppColors.successGreen, fontSize: 12))),
      ],
    );
  }

  // ---------------- Complete / logged in ----------------

  Widget _buildComplete() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.successGreen, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 38),
        ),
        const SizedBox(height: 20),
        const Text('Registration submitted!',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.slate900)),
        const SizedBox(height: 8),
        const Text(
          "Please wait for the administrator's approval, which will be sent to your email.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.slate500, fontSize: 13.5, height: 1.4),
        ),
        const SizedBox(height: 26),
        SolidButton(label: 'Go to Login', onPressed: () => switchMode('login')),
      ],
    );
  }

  Widget _buildLoggedIn() {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text("You're in!",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.slate900)),
        const SizedBox(height: 8),
        Text('Logged in as ${loggedInUser?['email'] ?? ''} (${loggedInUser?['role'] ?? ''})',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.slate500, fontSize: 14)),
        const SizedBox(height: 22),
        SolidOutlineButton(label: 'Log out', onPressed: logout),
      ],
    );
  }
}
