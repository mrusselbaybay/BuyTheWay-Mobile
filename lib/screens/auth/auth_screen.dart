// ============================================================================
// NEXMART Auth Screen — Glassmorphism Redesign
// ----------------------------------------------------------------------------
// Visuals: frosted-glass cards over an animated aurora backdrop, spring-y
// step transitions, press-scale micro-interactions on every tappable
// surface, and a responsive shell that centers a fixed-width glass card on
// tablet/desktop while staying full-bleed on phones (mobile-first).
//
// Business logic (validation, API calls, state machine for the multi-step
// wizards) is unchanged from the original implementation — only the
// presentation layer was rebuilt.
// ============================================================================

import 'dart:typed_data';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/common.dart';
import '../../services/api_service.dart';

// Constants
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

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // API Service
  final ApiService _api = ApiService();
  String? _authToken;
  final bool _isLoading = false;

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
  final List<Map<String, dynamic>> roles = const [
    {
      'id': 'buyer',
      'label': 'Buyer',
      'desc': 'Shop from verified local sellers',
      'icon': Icons.shopping_bag_outlined
    },
    {
      'id': 'seller',
      'label': 'Seller',
      'desc': 'Open your store, reach customers',
      'icon': Icons.storefront_outlined
    },
    {
      'id': 'courier',
      'label': 'Courier',
      'desc': 'Deliver & earn on your schedule',
      'icon': Icons.local_shipping_outlined
    },
    {
      'id': 'driver',
      'label': 'Driver',
      'desc': 'Drive & deliver for logistics companies',
      'icon': Icons.directions_car_outlined
    },
  ];

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

  bool _validateAddressFields(String? province, String? municipality,
      String? barangayVal, TextEditingController streetCtrl) {
    if (province == null ||
        municipality == null ||
        barangayVal == null ||
        streetCtrl.text.trim().isEmpty) {
      errorMsg = 'Please fill in all address fields.';
      return false;
    }
    return true;
  }

  bool _validateDocuments() {
    if (selectedRole == 'buyer' && !idFileUploaded) {
      errorMsg = 'Please upload an ID.';
      return false;
    }
    if (selectedRole == 'seller') {
      if (!idFileUploaded ||
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
          !licenseUploaded) {
        errorMsg = 'Please fill in all courier documents and vehicle info.';
        return false;
      }
    }
    if (selectedRole == 'driver') {
      if (driverVehicle.isEmpty ||
          driverPlateNumber.text.trim().isEmpty ||
          !driverOrcrUploaded ||
          !driverLicenseUploaded ||
          !driverIdUploaded) {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (role == 'logistics' || role == 'logistics_admin') {
        Navigator.pushReplacementNamed(context, '/courier_dashboard');
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
      final userData = _buildUserRegistrationData();
      final response = await _api.register(userData);

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

  Map<String, dynamic> _personalAddressData() => {
        'first_name': firstName.text.trim(),
        'last_name': lastName.text.trim(),
        'middle_initial': middleInitial.text.trim(),
        'sex': sex,
        'birthday': birthday?.toIso8601String(),
        'contact_number': contactNo.text.trim(),
        'province_code': provinceCode,
        'municipality_code': municipalityCode,
        'barangay_code': barangayCode,
        'barangay': barangay,
        'street': street.text.trim(),
        'house_number': houseNo.text.trim(),
      };

  Map<String, dynamic> _buildUserRegistrationData() {
    final base = {
      'email': email.text.trim(),
      'password': password.text,
      'password_confirmation': confirmPassword.text,
      'role': selectedRole,
    };

    switch (selectedRole) {
      case 'buyer':
        return {
          ...base,
          ..._personalAddressData(),
          'id_uploaded': idFileUploaded,
        };

      case 'seller':
        return {
          ...base,
          ..._personalAddressData(),
          'business_name': businessName.text.trim(),
          'line_of_business': lineOfBusiness,
          'id_uploaded': idFileUploaded,
          'business_permit_uploaded': businessPermitUploaded,
        };

      case 'courier':
        return {
          ...base,
          ..._personalAddressData(),
          'vehicle': vehicle,
          'plate_number': plateNumber.text.trim(),
          'orcr_uploaded': orcrUploaded,
          'license_uploaded': licenseUploaded,
        };

      case 'driver':
        return {
          'email': driverEmail.text.trim(),
          'password': driverPassword.text,
          'password_confirmation': driverConfirmPassword.text,
          'role': 'driver',
          'first_name': driverFirstName.text.trim(),
          'last_name': driverLastName.text.trim(),
          'middle_initial': driverMiddleInitial.text.trim(),
          'sex': driverSex,
          'birthday': driverBirthday?.toIso8601String(),
          'contact_number': driverContactNo.text.trim(),
          'province_code': provinceCode,
          'municipality_code': municipalityCode,
          'barangay_code': barangayCode,
          'barangay': barangay,
          'street': street.text.trim(),
          'house_number': houseNo.text.trim(),
          'vehicle': driverVehicle,
          'plate_number': driverPlateNumber.text.trim(),
          'license_number': driverLicenseNumber.text.trim(),
          'id_uploaded': driverIdUploaded,
          'license_uploaded': driverLicenseUploaded,
          'orcr_uploaded': driverOrcrUploaded,
        };
    }

    if (isLogisticsSignup) {
      return {
        'email': companyEmail.text.trim(),
        'password': password.text,
        'password_confirmation': confirmPassword.text,
        'role': 'logistics_admin',
        'company_name': companyName.text.trim(),
        'company_email': companyEmail.text.trim(),
        'company_contact': companyContactNo.text.trim(),
        'company_tin': companyTIN.text.trim(),
        'company_sec_reg': companySECReg.text.trim(),
        'company_region': companyRegion,
        'company_province_code': companyProvinceCode,
        'company_municipality_code': companyMunicipalityCode,
        'company_barangay_code': companyBarangayCode,
        'company_barangay': companyBarangay,
        'company_street': companyStreet.text.trim(),
        'company_house_number': companyHouseNo.text.trim(),
        'owner_first_name': ownerFirstName.text.trim(),
        'owner_last_name': ownerLastName.text.trim(),
        'owner_middle_initial': ownerMiddleInitial.text.trim(),
        'owner_sex': ownerSex,
        'owner_birthday': ownerBirthday?.toIso8601String(),
        'owner_id_uploaded': ownerIdUploaded,
        'business_permit_uploaded': businessPermitFileUploaded,
        'mayor_permit_uploaded': mayorPermitUploaded,
        'dti_reg_uploaded': dtiRegUploaded,
      };
    }

    return base;
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

      setState(() {
        loggedInUser = {
          'email': response['email'] ?? '',
          'role': role,
          'name': name,
          'status': status,
        };
        _authToken = token;
      });

      // Continue straight into the dashboard instead of stranding an
      // already-valid session on the static "You're in!" screen (which has
      // no way forward except logging out and back in). Restricted to
      // roles with a registered route (see main.dart) — seller/admin don't
      // have a dashboard route yet, so auto-navigating them would crash.
      const routedRoles = {'driver', 'courier', 'logistics', 'logistics_admin'};
      if (routedRoles.contains(role)) {
        _handleRoleBasedNavigation(role);
      }
    } catch (e) {
      await _clearToken();
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
            provinceCode, municipalityName, barangay, street)) {
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
            provinceCode, municipalityName, barangay, street)) {
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
      companyRegion = '';

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

  void startLogisticsSignup() {
    setState(() {
      isLogisticsSignup = true;
      signupStep = 'company';
      errorMsg = '';
      successMsg = '';
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
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Colors.white.withOpacity(0.08),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: Colors.white),
                      onPressed: _handleBackNavigation,
                      tooltip: 'Back',
                    ),
                    Expanded(
                      child: Text(
                        _appBarTitle(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.25))),
            ),
            child: GradientButton(
              label: isLast
                  ? (isSubmitting ? 'Submitting...' : 'Submit')
                  : 'Continue',
              icon: isLast ? null : Icons.arrow_forward_rounded,
              onPressed: isSubmitting
                  ? null
                  : () =>
                      isLast ? submitRegistration() : goToStep(keys[idx + 1]),
              loading: isLast && isSubmitting,
            ),
          ),
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
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        extendBody: true,
        resizeToAvoidBottomInset: true,
        appBar: _buildAppBar(),
        bottomNavigationBar: _buildBottomActionBar(),
        body: AuroraBackground(
          child: SafeArea(
            top: !hasAppBar,
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 640;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isWide ? 440 : double.infinity,
                    ),
                    child: _buildScreen(hasAppBar),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScreen(bool hasAppBar) {
  if (hasAppBar) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
                    begin: const Offset(0.04, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: child,
          ),
        ),
        child: GlassPanel(
          key: ValueKey('$mode-$signupStep'),
          padding: const EdgeInsets.all(20),
          child: _buildRightContent(),
        ),
      ),
    );
  }

  // FIXED: Simple SingleChildScrollView with proper spacing
  return SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHero(),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: GlassPanel(
              key: ValueKey('$mode-$signupStep-root'),
              padding: const EdgeInsets.all(20),
              opacity: 0.65,
              child: _buildRightContent(),
            ),
          ),
        ),
        if (mode == 'login' || (mode == 'signup' && signupStep == 'role'))
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 24),
            child: _buildFooterLink(),
          ),
        const SizedBox(height: 8),
      ],
    ),
  );
}
  Widget _buildHero() {
    final isLogin = mode == 'login';
    final isSignupRole = mode == 'signup' && signupStep == 'role';
    final isForgot = mode == 'forgot' || mode == 'reset';

    final title = isLogin
        ? 'Log in to keep\nshopping smart'
        : isSignupRole
            ? 'Create your account\nand start selling'
            : 'Reset Password';

    final subtitle = isForgot ? "We'll help you get back in" : '';

    return Padding(
      key: ValueKey('$mode-$signupStep-hero'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GlassPanel(
                borderRadius: 10,
                padding: const EdgeInsets.all(6),
                blur: 12,
                opacity: 0.22,
                child: const Icon(Icons.storefront_rounded,
                    color: Colors.white, size: 17),
              ),
              const SizedBox(width: 9),
              const Text(
                'NEXMART',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: 120,
            height: 104,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                GlassPanel(
                  borderRadius: 28,
                  padding: EdgeInsets.zero,
                  blur: 14,
                  opacity: 0.14,
                  child: const SizedBox(width: 96, height: 96),
                ),
                Positioned(
                  top: 0,
                  right: 4,
                  child: Transform.rotate(
                    angle: 0.35,
                    child: _iconChip(Icons.sell_rounded, size: 30, iconSize: 14),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 2,
                  child: Transform.rotate(
                    angle: -0.25,
                    child: _iconChip(Icons.inventory_2_rounded,
                        size: 30, iconSize: 14),
                  ),
                ),
                const Positioned(
                  top: 2,
                  right: -8,
                  child: Icon(Icons.auto_awesome_rounded,
                      color: Colors.white60, size: 13),
                ),
                const Positioned(
                  bottom: 8,
                  left: -8,
                  child: Icon(Icons.auto_awesome_rounded,
                      color: Colors.white38, size: 11),
                ),
                _iconChip(Icons.shopping_bag_rounded,
                    size: 64, iconSize: 30, primary: true),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.15,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.8),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _iconChip(
    IconData icon, {
    required double size,
    required double iconSize,
    bool primary = false,
  }) {
    if (primary) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.teal300, AppColors.teal500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(size * 0.3),
          boxShadow: [
            BoxShadow(
              color: AppColors.teal400.withOpacity(0.5),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, size: iconSize, color: Colors.white),
      );
    }
    return GlassPanel(
      borderRadius: size * 0.3,
      padding: EdgeInsets.zero,
      blur: 10,
      opacity: 0.2,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, size: iconSize, color: Colors.white),
      ),
    );
  }

  Widget _buildFooterLink() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: mode == 'login'
          ? _linkText(
              "Don't have an account? ", 'Sign up', () => switchMode('signup'))
          : _linkText('Already have an account? ', 'Log in',
              () => switchMode('login')),
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

  // ---------------- Tabs ----------------

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Expanded(
              child: _tabButton(
                  'Log In', mode == 'login', () => switchMode('login'))),
          Expanded(
              child: _tabButton(
                  'Sign Up', mode == 'signup', () => switchMode('signup'))),
        ],
      ),
    );
  }

  Widget _tabButton(String label, bool active, VoidCallback onTap) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [AppColors.teal400, AppColors.teal600])
              : null,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: AppColors.teal500.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3))
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.slate600)),
      ),
    );
  }

  Widget _linkText(String prefix, String linkLabel, VoidCallback onTap) {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
          children: [
            TextSpan(text: prefix),
            TextSpan(
              text: linkLabel,
              style: const TextStyle(
                  color: AppColors.teal300, fontWeight: FontWeight.w800),
              recognizer: TapGestureRecognizer()..onTap = onTap,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Login ----------------

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabs(),
        const SizedBox(height: 18),
        LabeledField(
            label: 'Email Address',
            controller: email,
            required: true,
            hint: 'juan@email.com',
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 14),
        LabeledField(
          label: 'Password',
          controller: password,
          required: true,
          hint: 'Enter your password',
          obscure: !showPassword,
          suffix: IconButton(
            icon: Icon(
                showPassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 18,
                color: AppColors.slate400),
            onPressed: () => setState(() => showPassword = !showPassword),
          ),
        ),
        const SizedBox(height: 4),
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
                      activeColor: AppColors.teal500,
                      onChanged: (v) =>
                          setState(() => rememberMe = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('Remember me',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.slate600)),
                ],
              ),
            ),
            TextButton(
              onPressed: () => switchMode('forgot'),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              child: const Text('Forgot password?',
                  style: TextStyle(
                      color: AppColors.teal700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ],
        ),
        MessageBanner(error: errorMsg, success: successMsg),
        const SizedBox(height: 8),
        GradientButton(
          label: isSubmitting ? 'Signing in...' : 'Sign In',
          onPressed: isSubmitting ? null : handleLogin,
          loading: isSubmitting,
          icon: Icons.login_rounded,
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  // ---------------- Forgot / reset password wizard ----------------

  Widget _buildResetWizard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          resetStep == 1
              ? 'Enter your email to receive a verification code.'
              : (resetStep == 2
                  ? 'Enter the 6-digit code sent to your email.'
                  : 'Create a new password for your account.'),
          style: const TextStyle(color: AppColors.slate600, fontSize: 14),
        ),
        const SizedBox(height: 14),
        StepIndicator(total: 3, currentIndex: resetStep - 1),
        const SizedBox(height: 18),
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
        LabeledField(
            label: 'Email Address',
            controller: forgotEmail,
            required: true,
            hint: 'juan@email.com',
            keyboardType: TextInputType.emailAddress),
        MessageBanner(error: errorMsg, success: successMsg),
        const SizedBox(height: 10),
        GradientButton(
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
        LabeledField(
            label: 'Verification Code',
            controller: resetCode,
            required: true,
            hint: '6-digit code',
            keyboardType: TextInputType.number,
            maxLength: 6),
        const SizedBox(height: 4),
        const Text('Check your email for the code. Expires in 15 minutes.',
            style: TextStyle(color: AppColors.slate500, fontSize: 12)),
        MessageBanner(error: errorMsg, success: successMsg),
        const SizedBox(height: 10),
        GradientButton(
          label: isVerifying ? 'Verifying...' : 'Verify Code',
          onPressed: isVerifying ? null : handleVerifyResetCode,
          loading: isVerifying,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: handleResendResetCode,
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              child: const Text('Resend code',
                  style: TextStyle(
                      color: AppColors.teal700,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ),
            TextButton(
              onPressed: () => setState(() {
                resetStep = 1;
                errorMsg = '';
                successMsg = '';
              }),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              child: const Text('Change email',
                  style: TextStyle(
                      color: AppColors.teal700,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
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
        LabeledField(
          label: 'New Password',
          controller: newPassword,
          required: true,
          hint: 'Min 8 characters',
          obscure: !showPassword,
          suffix: IconButton(
            icon: Icon(
                showPassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 18,
                color: AppColors.slate400),
            onPressed: () => setState(() => showPassword = !showPassword),
          ),
        ),
        const SizedBox(height: 10),
        LabeledField(
            label: 'Confirm New Password',
            controller: newConfirmPassword,
            required: true,
            hint: 'Re-enter password',
            obscure: !showPassword),
        MessageBanner(error: errorMsg, success: successMsg),
        const SizedBox(height: 10),
        GradientButton(
          label: isSubmitting ? 'Resetting...' : 'Reset Password',
          onPressed: isSubmitting ? null : handleResetPassword,
          loading: isSubmitting,
        ),
      ],
    );
  }

  // ---------------- Signup flow ----------------

  Widget _buildSignupFlow() {
    if (signupStep != 'role' || isLogisticsSignup) {
      return _buildSignupBody();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabs(),
        const SizedBox(height: 18),
        _buildSignupBody(),
      ],
    );
  }

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
        const Text('Select your role to start your registration.',
            style: TextStyle(color: AppColors.slate600, fontSize: 14)),
        const SizedBox(height: 14),
        ...roles.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _roleCard(r),
            )),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.only(top: 14),
          decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: AppColors.slate300.withOpacity(0.6)))),
          child: _linkText('Have your own logistics company?  ', 'Sign up here',
              startLogisticsSignup),
        ),
      ],
    );
  }

  Widget _roleCard(Map<String, dynamic> r) {
    final selected = selectedRole == r['id'];
    return PressableScale(
      onTap: () => selectRole(r['id'] as String),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [
                  AppColors.teal500.withOpacity(0.14),
                  AppColors.teal400.withOpacity(0.08),
                ])
              : null,
          color: selected ? null : Colors.white.withOpacity(0.5),
          border: Border.all(
              color: selected
                  ? AppColors.teal500
                  : Colors.white.withOpacity(0.6),
              width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: AppColors.teal400.withOpacity(0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 6))
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.teal500.withOpacity(0.18)
                    : AppColors.slate100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(r['icon'] as IconData,
                  size: 20,
                  color: selected ? AppColors.teal700 : AppColors.slate400),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r['label'] as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.slate800)),
                  const SizedBox(height: 2),
                  Text(r['desc'] as String,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.slate500,
                          height: 1.3)),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: selected
                  ? const Icon(Icons.check_circle_rounded,
                      key: ValueKey('sel'), size: 20, color: AppColors.teal600)
                  : const Icon(Icons.chevron_right_rounded,
                      key: ValueKey('unsel'), size: 20, color: AppColors.slate300),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wizardHeader({required String kicker}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(kicker,
          style: const TextStyle(color: AppColors.slate500, fontSize: 13)),
    );
  }

  // ---------------- Regular wizard (buyer/seller/courier) ----------------

  Widget _buildRegularWizard() {
    final idx = currentStepIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepIndicator(total: steps.length, currentIndex: idx),
        const SizedBox(height: 14),
        _wizardHeader(kicker: 'Register as ${selectedRole ?? ''}'),
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
        LabeledField(
            label: 'Last Name',
            controller: lastName,
            required: true,
            hint: 'Dela Cruz',
            error: validationErrors['lastName']),
        const SizedBox(height: 12),
        LabeledField(
            label: 'First Name',
            controller: firstName,
            required: true,
            hint: 'Juan',
            error: validationErrors['firstName']),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            flex: 2,
            child: LabeledField(
                label: 'M.I.',
                controller: middleInitial,
                hint: 'B',
                maxLength: 1,
                error: validationErrors['middleInitial']),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: LabeledDropdown(
                label: 'Sex',
                required: true,
                value: sex.isEmpty ? null : sex,
                items: const ['Male', 'Female'],
                onChanged: (v) => setState(() => sex = v ?? '')),
          ),
        ]),
        const SizedBox(height: 12),
        LabeledDateField(
            label: 'Birthday',
            required: true,
            value: birthday,
            onChanged: (d) => setState(() => birthday = d),
            error: validationErrors['birthday']),
        const SizedBox(height: 12),
        LabeledField(
            label: 'Contact No.',
            controller: contactNo,
            required: true,
            hint: '09XXXXXXXXX',
            keyboardType: TextInputType.phone,
            maxLength: 11,
            error: validationErrors['contactNo']),
        const SizedBox(height: 12),
        LabeledField(
            label: 'Email',
            controller: email,
            required: true,
            hint: 'juan@email.com',
            keyboardType: TextInputType.emailAddress,
            error: validationErrors['email']),
      ],
    );
  }

  Widget _verifyEmailFields(String targetEmail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(TextSpan(
            style: const TextStyle(color: AppColors.slate600, fontSize: 13),
            children: [
              const TextSpan(text: 'We sent a 6-digit code to '),
              TextSpan(
                  text: targetEmail.isEmpty ? '—' : targetEmail,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.slate800)),
              const TextSpan(text: '.'),
            ])),
        if (successMsg.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(successMsg,
                  style: const TextStyle(
                      color: AppColors.successGreen, fontSize: 12))),
        const SizedBox(height: 12),
        LabeledField(
            label: 'Verification Code',
            controller: signupVerifyCode,
            required: true,
            hint: '6-digit code',
            keyboardType: TextInputType.number,
            maxLength: 6),
        const SizedBox(height: 4),
        const Text('Code expires in 15 minutes.',
            style: TextStyle(color: AppColors.slate500, fontSize: 12)),
        const SizedBox(height: 8),
        TextButton(
          onPressed: isSendingCode ? null : _sendVerificationCodeStub,
          style: TextButton.styleFrom(
              padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
          child: const Text('Resend code',
              style: TextStyle(
                  color: AppColors.teal700,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ),
        if (errorMsg.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(errorMsg,
                  style: const TextStyle(
                      color: AppColors.errorRed, fontSize: 12))),
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
        LabeledDropdown(
          label: 'Province',
          required: true,
          value: pCode,
          items: provinces.map((p) => p['code']?.toString() ?? '').toList(),
          displayItems:
              provinces.map((p) => p['name']?.toString() ?? '').toList(),
          hint: loadingProvinces ? 'Loading provinces...' : 'Select province',
          enabled: !loadingProvinces,
          onChanged: (v) =>
              isCompany ? onCompanyProvinceChanged(v) : onProvinceChanged(v),
        ),
        const SizedBox(height: 12),
        LabeledDropdown(
          label: 'Municipality / City',
          required: true,
          value: mCode,
          items:
              municipalities.map((m) => m['code']?.toString() ?? '').toList(),
          displayItems:
              municipalities.map((m) => m['name']?.toString() ?? '').toList(),
          hint: loadingMunicipalities
              ? 'Loading...'
              : (pCode != null
                  ? 'Select municipality/city'
                  : 'Select a province first'),
          enabled: pCode != null && !loadingMunicipalities,
          onChanged: (v) => isCompany
              ? onCompanyMunicipalityChanged(v)
              : onMunicipalityChanged(v),
        ),
        const SizedBox(height: 12),
        LabeledDropdown(
          label: 'Barangay',
          required: true,
          value: bCode,
          items: barangays.map((b) => b['code']?.toString() ?? '').toList(),
          displayItems:
              barangays.map((b) => b['name']?.toString() ?? '').toList(),
          hint: loadingBarangays
              ? 'Loading...'
              : (mCode != null
                  ? 'Select barangay'
                  : 'Select a municipality/city first'),
          enabled: mCode != null && !loadingBarangays,
          onChanged: (v) =>
              isCompany ? onCompanyBarangayChanged(v) : onBarangayChanged(v),
        ),
        const SizedBox(height: 12),
        LabeledField(
            label: 'Street',
            controller: streetCtrl,
            required: true,
            hint: 'Street name'),
        const SizedBox(height: 12),
        LabeledField(
            label: 'House / Unit #',
            controller: houseCtrl,
            hint: '123, Unit B'),
        if (_addressError.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_addressError,
                  style: const TextStyle(
                      color: AppColors.errorRed, fontSize: 12))),
        if (errorMsg.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(errorMsg,
                  style: const TextStyle(
                      color: AppColors.errorRed, fontSize: 12))),
      ],
    );
  }

  Widget _securityFields(TextEditingController pw, TextEditingController cpw,
      String keyPw, String keyCpw) {
    return Column(
      children: [
        LabeledField(
          label: 'Password',
          controller: pw,
          required: true,
          hint: 'Min 8 characters',
          obscure: !showPassword,
          error: validationErrors[keyPw],
          suffix: IconButton(
            icon: Icon(
                showPassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 18,
                color: AppColors.slate400),
            onPressed: () => setState(() => showPassword = !showPassword),
          ),
        ),
        const SizedBox(height: 12),
        LabeledField(
            label: 'Confirm Password',
            controller: cpw,
            required: true,
            hint: 'Re-enter password',
            obscure: !showPassword,
            error: validationErrors[keyCpw]),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => setState(() => showPassword = !showPassword),
          borderRadius: BorderRadius.circular(6),
          child: Row(children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                  value: showPassword,
                  activeColor: AppColors.teal500,
                  onChanged: (v) => setState(() => showPassword = v ?? false)),
            ),
            const SizedBox(width: 6),
            const Text('Show passwords',
                style: TextStyle(fontSize: 13, color: AppColors.slate600)),
          ]),
        ),
      ],
    );
  }

  Widget _documentsFields() {
    final children = <Widget>[];
    if (selectedRole == 'buyer') {
      children.add(UploadTile(
          label: 'Upload ID',
          required: true,
          uploaded: idFileUploaded,
          fileName: _idFileName,
          onTap: () => _pickFile('idFile')));
    } else if (selectedRole == 'seller') {
      children.addAll([
        LabeledField(
            label: 'Business Name',
            controller: businessName,
            required: true,
            hint: 'My Store'),
        const SizedBox(height: 12),
        LabeledDropdown(
          label: 'Line of Business',
          required: true,
          value: lineOfBusiness.isEmpty ? null : lineOfBusiness,
          items: kLineOfBusinessOptions,
          hint: 'Select Line of Business',
          onChanged: (v) => setState(() => lineOfBusiness = v ?? ''),
        ),
        const SizedBox(height: 12),
        UploadTile(
            label: 'Upload ID',
            required: true,
            uploaded: idFileUploaded,
            fileName: _idFileName,
            onTap: () => _pickFile('idFile')),
        const SizedBox(height: 12),
        UploadTile(
            label: 'Upload Business Permit',
            required: true,
            uploaded: businessPermitUploaded,
            fileName: _businessPermitFileName,
            onTap: () => _pickFile('businessPermit')),
      ]);
    } else if (selectedRole == 'courier') {
      children.addAll([
        LabeledDropdown(
          label: 'Vehicle',
          required: true,
          value: vehicle.isEmpty ? null : vehicle,
          items: const ['Motorcycle', 'Car', 'Van', 'Bicycle'],
          onChanged: (v) => setState(() => vehicle = v ?? ''),
        ),
        const SizedBox(height: 12),
        LabeledField(
            label: 'Plate Number',
            controller: plateNumber,
            required: true,
            hint: 'ABC-1234'),
        const SizedBox(height: 12),
        UploadTile(
            label: 'Upload OR/CR',
            required: true,
            uploaded: orcrUploaded,
            fileName: _orcrFileName,
            onTap: () => _pickFile('orcrFile')),
        const SizedBox(height: 12),
        UploadTile(
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
          width: 76,
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.successGreen, Color(0xFF059669)]),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: AppColors.successGreen.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 18),
        const Text('Registration submitted!',
            style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.slate900)),
        const SizedBox(height: 8),
        const Text(
          "Please wait for the administrator's approval, which will be sent to your email.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.slate500, fontSize: 13),
        ),
        const SizedBox(height: 22),
        GradientButton(label: 'Go to Login', onPressed: () => switchMode('login')),
      ],
    );
  }

  Widget _buildLoggedIn() {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text("You're in!",
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.slate900)),
        const SizedBox(height: 8),
        Text(
            'Logged in as ${loggedInUser?['email'] ?? ''} (${loggedInUser?['role'] ?? ''})',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.slate500, fontSize: 14)),
        const SizedBox(height: 22),
        OutlineActionButton(label: 'Log out', onPressed: logout),
      ],
    );
  }
}