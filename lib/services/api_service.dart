import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  /// Laravel API URL. Supply `--dart-define=API_BASE_URL=http://<LAN-IP>:8000/api`
  /// when testing on a physical device, or your deployed HTTPS URL in production.
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  // Dynamic base URL that works for browser and emulator development.
  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    if (kDebugMode) {
      // For web (Chrome) - use localhost
      if (kIsWeb) {
        return 'http://localhost:8000/api';
      }
      // Android emulator only. A physical Android device must use API_BASE_URL
      // with the computer's LAN address; 10.0.2.2 is not reachable from it.
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000/api';
      }
      // For iOS simulator or physical device
      if (Platform.isIOS) {
        return 'http://localhost:8000/api';
      }
      // Fallback for other platforms
      return 'http://localhost:8000/api';
    }
    // Production
    return 'https://yourdomain.com/api';
  }

  // ============================================================
  // AUTH ENDPOINTS
  // ============================================================

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw ApiException(
              message:
                  'Connection timeout. Please check your internet connection.',
              statusCode: 408,
            ),
          );
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        message:
            'Cannot connect to server. Please make sure Laravel is running.\n'
            'Run: php artisan serve',
        statusCode: 0,
      );
    } catch (e) {
      throw ApiException(
        message: 'Connection error: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(userData),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw ApiException(
              message:
                  'Connection timeout. Please check your internet connection.',
              statusCode: 408,
            ),
          );
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        message:
            'Cannot connect to server. Please make sure Laravel is running.',
        statusCode: 0,
      );
    }
  }

  /// Submits a full signup-wizard registration to
  /// `POST /api/signup/register` (AuthController::registerUser) — the same
  /// endpoint the web wizard's submitUserRegistration() posts to in
  /// resources/js/app.js.
  ///
  /// This is deliberately NOT [register] (`/auth/register`): that endpoint
  /// only creates the Supabase auth user from a JSON body. The wizard
  /// endpoint additionally writes the address row, the role-specific
  /// details row (courier_details / seller_details / driver_details) and
  /// every uploaded document, which means it has to be multipart —
  /// [fields] must use the exact snake_case names the controller
  /// validates (`contact_no`, `house_no`, `region`, `id_type`, …) and each
  /// document's [SignupUpload.field] the exact name
  /// AuthController::fileMapForRole() reads.
  Future<Map<String, dynamic>> submitSignupRegistration({
    required Map<String, String> fields,
    List<SignupUpload> documents = const [],
    bool logistics = false,
  }) async {
    final path = logistics ? '/signup/register-logistics' : '/signup/register';
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'))
      ..headers['Accept'] = 'application/json';

    fields.forEach((key, value) {
      if (value.isNotEmpty) request.fields[key] = value;
    });

    for (final document in documents) {
      request.files.add(http.MultipartFile.fromBytes(
        document.field,
        document.bytes,
        filename: document.fileName,
      ));
    }

    try {
      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw ApiException(
              message:
                  'Connection timeout. Please check your internet connection.',
              statusCode: 408,
            ),
          );
      return _handleResponse(await http.Response.fromStream(streamedResponse));
    } on SocketException {
      throw ApiException(
        message:
            'Cannot connect to server. Please make sure Laravel is running.',
        statusCode: 0,
      );
    }
  }

  Future<Map<String, dynamic>> getUser(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/user'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return _handleResponse(response);
  }

  Future<void> logout(String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/logout'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode >= 400) {
      throw Exception('Logout failed');
    }
  }

  // ============================================================
  // SIGNUP VERIFICATION
  // ============================================================

  Future<Map<String, dynamic>> sendSignupCode(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/signup/send-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> verifySignupCode(
      String email, String code) async {
    final response = await http.post(
      Uri.parse('$baseUrl/signup/verify-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> resendSignupCode(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/signup/resend-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return _handleResponse(response);
  }

  // ============================================================
  // PASSWORD RESET
  // ============================================================

  Future<Map<String, dynamic>> sendPasswordResetCode(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/password/send-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> verifyPasswordResetCode(
      String email, String code) async {
    final response = await http.post(
      Uri.parse('$baseUrl/password/verify-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> resetPassword(
    String email,
    String code,
    String password,
    String passwordConfirmation,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/password/reset'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'code': code,
        'password': password,
        'password_confirmation': passwordConfirmation,
      }),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> resendPasswordResetCode(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/password/resend-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return _handleResponse(response);
  }

  // ============================================================
  // SEND VERIFICATION CODE (Alias for sendSignupCode)
  // ============================================================

  Future<Map<String, dynamic>> sendVerificationCode(String email) async {
    return await sendSignupCode(email);
  }

  // ============================================================
  // VERIFY EMAIL (Alias for verifySignupCode)
  // ============================================================

  Future<Map<String, dynamic>> verifyEmail(String email, String code) async {
    return await verifySignupCode(email, code);
  }

  // ============================================================
  // FORGOT PASSWORD (Alias for sendPasswordResetCode)
  // ============================================================

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    return await sendPasswordResetCode(email);
  }

  // ============================================================
  // PSGC ENDPOINTS (Philippine Standard Geographic Code)
  // ============================================================

  /// Get all regions
  Future<List<dynamic>> getRegions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/psgc/regions'),
      headers: {'Content-Type': 'application/json'},
    );
    final data = _handleResponse(response);
    return data['data'] ?? [];
  }

  /// Get provinces (optionally filtered by region code)
  Future<List<dynamic>> getProvinces({String? regionCode}) async {
    final url = regionCode != null
        ? '$baseUrl/psgc/provinces?region_code=$regionCode'
        : '$baseUrl/psgc/provinces';
    final response = await http.get(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
    );
    final data = _handleResponse(response);
    return data['data'] ?? [];
  }

  /// Get cities/municipalities by province code
  Future<List<dynamic>> getMunicipalities(
      {required String provinceCode}) async {
    final response = await http.get(
      Uri.parse(
          '$baseUrl/psgc/cities-municipalities?province_code=$provinceCode'),
      headers: {'Content-Type': 'application/json'},
    );
    final data = _handleResponse(response);
    return data['data'] ?? [];
  }

  /// Get barangays by municipality code
  Future<List<dynamic>> getBarangays({required String municipalityCode}) async {
    final response = await http.get(
      Uri.parse(
          '$baseUrl/psgc/barangays?city_municipality_code=$municipalityCode'),
      headers: {'Content-Type': 'application/json'},
    );
    final data = _handleResponse(response);
    return data['data'] ?? [];
  }

  // ============================================================
  // COURIER WORK ENDPOINTS
  // ============================================================

  /// Gets logistics companies available to couriers.
  ///
  /// The Laravel API owns access to Supabase. Do not put Supabase keys or
  /// database credentials in the Flutter client.
  Future<Map<String, dynamic>> getLogisticsCompanies({
    String? region,
    String? search,
  }) async {
    final queryParameters = <String, String>{
      if (region != null && region.trim().isNotEmpty) 'region': region.trim(),
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };
    final uri = Uri.parse('$baseUrl/courier/logistics-companies').replace(
      queryParameters: queryParameters,
    );
    final response = await http.get(
      uri,
      headers: {'Accept': 'application/json'},
    );
    return _handleResponse(response);
  }

  /// Creates a courier application (with resume + driver's license +
  /// optional cover note) in Supabase through the Laravel API. For each of
  /// the two files, exactly one of its `*Bytes` (web) or `*FilePath`
  /// (mobile/desktop) must be supplied.
  Future<Map<String, dynamic>> submitCourierApplication({
    required String logisticsCompanyId,
    required String accessToken,
    required String resumeFileName,
    Uint8List? resumeBytes,
    String? resumeFilePath,
    required String licenseFileName,
    Uint8List? licenseBytes,
    String? licenseFilePath,
    String? coverNote,
  }) async {
    if (resumeBytes == null && resumeFilePath == null) {
      throw ApiException(
        message: 'Please attach your resume before applying.',
        statusCode: 422,
      );
    }
    if (licenseBytes == null && licenseFilePath == null) {
      throw ApiException(
        message: "Please attach your driver's license before applying.",
        statusCode: 422,
      );
    }

    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/courier/applications'))
          ..headers['Accept'] = 'application/json'
          ..headers['Authorization'] = 'Bearer $accessToken'
          ..fields['logistics_company_id'] = logisticsCompanyId;

    if (coverNote != null && coverNote.trim().isNotEmpty) {
      request.fields['cover_note'] = coverNote.trim();
    }

    if (resumeBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'resume',
        resumeBytes,
        filename: resumeFileName,
      ));
    } else {
      request.files.add(await http.MultipartFile.fromPath(
        'resume',
        resumeFilePath!,
        filename: resumeFileName,
      ));
    }

    if (licenseBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'license',
        licenseBytes,
        filename: licenseFileName,
      ));
    } else {
      request.files.add(await http.MultipartFile.fromPath(
        'license',
        licenseFilePath!,
        filename: licenseFileName,
      ));
    }

    try {
      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw ApiException(
              message:
                  'Connection timeout. Please check your internet connection.',
              statusCode: 408,
            ),
          );
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        message:
            'Cannot connect to server. Please make sure Laravel is running.',
        statusCode: 0,
      );
    }
  }

  /// Gets the signed-in user's applications persisted by Laravel/Supabase.
  Future<Map<String, dynamic>> getCourierApplications({
    required String accessToken,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/courier/applications'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _handleResponse(response);
  }

  /// Withdraws a pending courier application through the Laravel API.
  Future<Map<String, dynamic>> withdrawCourierApplication({
    required String applicationId,
    required String accessToken,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/courier/applications/$applicationId/withdraw'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _handleResponse(response);
  }

  /// Gets a short-lived signed URL to the resume on file for one of the
  /// signed-in courier's own applications.
  Future<Map<String, dynamic>> getCourierApplicationResume({
    required String applicationId,
    required String accessToken,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/courier/applications/$applicationId/resume'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _handleResponse(response);
  }

  /// Gets a short-lived signed URL to the driver's license on file for one
  /// of the signed-in courier's own applications.
  Future<Map<String, dynamic>> getCourierApplicationLicense({
    required String applicationId,
    required String accessToken,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/courier/applications/$applicationId/license'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _handleResponse(response);
  }

  /// Gets the signed-in courier's current employment status (whether a
  /// logistics company has taken them on, plus their vehicle/plate on file).
  Future<Map<String, dynamic>> getCourierEmploymentStatus({
    required String accessToken,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/courier/profile/employment'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _handleResponse(response);
  }

  /// Submits a resignation request (letter + optional reason) for the
  /// courier's current employer via `POST /courier/resignation-requests`.
  /// Exactly one of [letterBytes] (web) / [letterFilePath] (mobile) must be
  /// supplied.
  Future<Map<String, dynamic>> submitResignationRequest({
    required String accessToken,
    required String letterFileName,
    Uint8List? letterBytes,
    String? letterFilePath,
    String? reason,
  }) async {
    if (letterBytes == null && letterFilePath == null) {
      throw ApiException(
        message: 'Please attach your resignation letter.',
        statusCode: 422,
      );
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/courier/resignation-requests'),
    )
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $accessToken';

    if (reason != null && reason.trim().isNotEmpty) {
      request.fields['reason'] = reason.trim();
    }

    if (letterBytes != null) {
      request.files.add(http.MultipartFile.fromBytes('letter', letterBytes, filename: letterFileName));
    } else {
      request.files.add(await http.MultipartFile.fromPath('letter', letterFilePath!, filename: letterFileName));
    }

    try {
      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw ApiException(
              message: 'Connection timeout. Please check your internet connection.',
              statusCode: 408,
            ),
          );
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        message: 'Cannot connect to server. Please make sure Laravel is running.',
        statusCode: 0,
      );
    }
  }

  /// Lists the signed-in courier's resignation requests.
  Future<Map<String, dynamic>> getResignationRequests({
    required String accessToken,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/courier/resignation-requests'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $accessToken'},
    );
    return _handleResponse(response);
  }

  /// Cancels the courier's own still-pending resignation request.
  Future<Map<String, dynamic>> cancelResignationRequest({
    required String resignationRequestId,
    required String accessToken,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/courier/resignation-requests/$resignationRequestId'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $accessToken'},
    );
    return _handleResponse(response);
  }

  /// Short-lived signed URL for the courier's own resignation letter.
  Future<Map<String, dynamic>> getResignationLetterUrl({
    required String resignationRequestId,
    required String accessToken,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/courier/resignation-requests/$resignationRequestId/letter'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $accessToken'},
    );
    return _handleResponse(response);
  }

  // ============================================================
  // LOGISTICS INVENTORY ENDPOINTS
  // ============================================================
  // Backs the Logistics mobile app's Inventory tab — see
  // Api\Logistics\ParcelInventoryController on the Laravel side.

  /// Tab 1 — "Inventory": every parcel this company has ever scanned in,
  /// via `GET /api/logistics/inventory`.
  Future<Map<String, dynamic>> getInventory({
    required String accessToken,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/logistics/inventory'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $accessToken'},
    );
    return _handleResponse(response);
  }

  /// Tab 2 — "For Inventory": parcels awaiting a scan, via
  /// `GET /api/logistics/inventory/pending`.
  Future<Map<String, dynamic>> getPendingInventory({
    required String accessToken,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/logistics/inventory/pending'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $accessToken'},
    );
    return _handleResponse(response);
  }

  /// Full detail for one parcel, via
  /// `GET /api/logistics/inventory/{id}`.
  Future<Map<String, dynamic>> getInventoryDetail({
    required String parcelAssignmentId,
    required String accessToken,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/logistics/inventory/$parcelAssignmentId'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $accessToken'},
    );
    return _handleResponse(response);
  }

  /// Scans a parcel's QR code to move it from "For Inventory" into
  /// "Inventory", via `PUT /api/logistics/inventory/{id}/scan`. The
  /// backend rejects a code that doesn't match this exact parcel with a
  /// 422 — see [ApiException.message] for that case.
  Future<Map<String, dynamic>> scanInventory({
    required String parcelAssignmentId,
    required String accessToken,
    required String confirmationToken,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/logistics/inventory/$parcelAssignmentId/scan'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'confirmation_token': confirmationToken}),
    );
    return _handleResponse(response);
  }

  // ============================================================
  // DRIVER / COURIER SETTINGS ENDPOINTS
  // ============================================================

  /// Loads the signed-in driver/courier's profile + on-file address +
  /// read-only vehicle details from `GET /api/driver/profile`.
  Future<Map<String, dynamic>> getDriverProfile({
    required String accessToken,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/driver/profile'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _handleResponse(response);
  }

  /// Flips the signed-in rider's "Go online" shift flag via
  /// `PUT /api/driver/availability` — [online] true → 'available'
  /// (dispatch can assign deliveries), false → 'unavailable'. The new
  /// value is also echoed back on `GET /api/driver/profile`'s
  /// `vehicle.delivery_status`.
  Future<Map<String, dynamic>> updateDriverAvailability({
    required String accessToken,
    required bool online,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/driver/availability'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'delivery_status': online ? 'available' : 'unavailable'}),
    );
    return _handleResponse(response);
  }

  /// Saves personal info + address in one request via
  /// `PUT /api/driver/profile`.
  Future<Map<String, dynamic>> updateDriverProfile({
    required String accessToken,
    required Map<String, dynamic> data,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/driver/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  /// Uploads the rider's profile picture to
  /// `POST /api/driver/profile/avatar`, which stores it in the public
  /// Supabase `avatars` bucket and returns the new `avatar_url`. [bytes]
  /// is the already-cropped square image (see ImageCropSheet) — the
  /// server re-derives the media type from the bytes themselves, but the
  /// [fileName] extension still decides the stored object's extension, so
  /// it must match the encoding.
  Future<Map<String, dynamic>> uploadDriverAvatar({
    required String accessToken,
    required Uint8List bytes,
    String fileName = 'avatar.jpg',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/driver/profile/avatar'),
    )
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..files.add(http.MultipartFile.fromBytes(
        'avatar',
        bytes,
        filename: fileName,
      ));

    try {
      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 45),
            onTimeout: () => throw ApiException(
              message:
                  'Connection timeout. Please check your internet connection.',
              statusCode: 408,
            ),
          );
      return _handleResponse(await http.Response.fromStream(streamedResponse));
    } on SocketException {
      throw ApiException(
        message:
            'Cannot connect to server. Please make sure Laravel is running.',
        statusCode: 0,
      );
    }
  }

  /// Loads the parcels the logistics team has assigned to the signed-in
  /// rider/courier for the Deliveries tab, via `GET /api/driver/deliveries`.
  Future<Map<String, dynamic>> getDriverDeliveries({
    required String accessToken,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/driver/deliveries'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _handleResponse(response);
  }

  /// Confirms an assigned parcel has been picked up via
  /// `POST /api/driver/deliveries/{id}/pickup` — a photo of the parcel is
  /// required (exactly one of [photoBytes]/[photoFilePath] must be
  /// supplied). On success the assignment moves from "To pick up" to "To
  /// deliver" and the change is visible to the logistics side immediately,
  /// since both sides read the same parcel_assignments row.
  ///
  /// [confirmationToken] is the parcel QR value the rider scanned or
  /// decoded from an attached picture — logged server-side as a 'pickup'
  /// scan and verified against this parcel (see
  /// DriverDeliveryController::guardScannedToken).
  Future<Map<String, dynamic>> markDeliveryPickedUp({
    required String parcelAssignmentId,
    required String accessToken,
    required String photoFileName,
    Uint8List? photoBytes,
    String? photoFilePath,
    String? confirmationToken,
  }) async {
    if (photoBytes == null && photoFilePath == null) {
      throw ApiException(
        message: 'Please attach a photo of the parcel before marking this picked up.',
        statusCode: 422,
      );
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/driver/deliveries/$parcelAssignmentId/pickup'),
    )
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $accessToken';

    if (confirmationToken != null && confirmationToken.isNotEmpty) {
      request.fields['confirmation_token'] = confirmationToken;
    }

    if (photoBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'photo',
        photoBytes,
        filename: photoFileName,
      ));
    } else {
      request.files.add(await http.MultipartFile.fromPath(
        'photo',
        photoFilePath!,
        filename: photoFileName,
      ));
    }

    try {
      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw ApiException(
              message: 'Connection timeout. Please check your internet connection.',
              statusCode: 408,
            ),
          );
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        message: 'Cannot connect to server. Please make sure Laravel is running.',
        statusCode: 0,
      );
    }
  }

  /// Gets a short-lived signed URL to the pickup photo on file for one of
  /// the signed-in rider's own assignments, via
  /// `GET /api/driver/deliveries/{id}/pickup-photo`.
  Future<Map<String, dynamic>> getPickupPhoto({
    required String parcelAssignmentId,
    required String accessToken,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/driver/deliveries/$parcelAssignmentId/pickup-photo'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _handleResponse(response);
  }

  /// Marks a handed-off parcel delivered via
  /// `POST /api/driver/deliveries/{id}/deliver` — a photo of the parcel is
  /// required (exactly one of [photoBytes]/[photoFilePath] must be
  /// supplied), same proof-of-delivery requirement as the driver app's
  /// Home-tab delivery flow.
  ///
  /// [confirmationToken] is the parcel QR value the rider scanned or
  /// decoded from an attached picture — logged server-side as a 'delivery'
  /// scan and verified against this parcel (see
  /// DriverDeliveryController::guardScannedToken).
  Future<Map<String, dynamic>> markDeliveryDelivered({
    required String parcelAssignmentId,
    required String accessToken,
    required String photoFileName,
    Uint8List? photoBytes,
    String? photoFilePath,
    String? confirmationToken,
  }) async {
    if (photoBytes == null && photoFilePath == null) {
      throw ApiException(
        message: 'Please attach a photo of the parcel before marking this delivered.',
        statusCode: 422,
      );
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/driver/deliveries/$parcelAssignmentId/deliver'),
    )
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $accessToken';

    if (confirmationToken != null && confirmationToken.isNotEmpty) {
      request.fields['confirmation_token'] = confirmationToken;
    }

    if (photoBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'photo',
        photoBytes,
        filename: photoFileName,
      ));
    } else {
      request.files.add(await http.MultipartFile.fromPath(
        'photo',
        photoFilePath!,
        filename: photoFileName,
      ));
    }

    try {
      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw ApiException(
              message: 'Connection timeout. Please check your internet connection.',
              statusCode: 408,
            ),
          );
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        message: 'Cannot connect to server. Please make sure Laravel is running.',
        statusCode: 0,
      );
    }
  }

  /// Cross-region-transfer counterpart to [markDeliveryDelivered]: confirms
  /// this rider reached the target logistics company's hub instead of a
  /// buyer's doorstep, via `POST /api/driver/deliveries/{id}/confirm-transfer`
  /// (DriverDeliveryController::confirmTransfer). Same photo-gated shape.
  Future<Map<String, dynamic>> confirmParcelTransfer({
    required String parcelAssignmentId,
    required String accessToken,
    required String photoFileName,
    Uint8List? photoBytes,
    String? photoFilePath,
    String? confirmationToken,
  }) async {
    if (photoBytes == null && photoFilePath == null) {
      throw ApiException(
        message: 'Please attach a photo of the parcel before confirming the transfer.',
        statusCode: 422,
      );
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/driver/deliveries/$parcelAssignmentId/confirm-transfer'),
    )
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $accessToken';

    if (confirmationToken != null && confirmationToken.isNotEmpty) {
      request.fields['confirmation_token'] = confirmationToken;
    }

    if (photoBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'photo',
        photoBytes,
        filename: photoFileName,
      ));
    } else {
      request.files.add(await http.MultipartFile.fromPath(
        'photo',
        photoFilePath!,
        filename: photoFileName,
      ));
    }

    try {
      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw ApiException(
              message: 'Connection timeout. Please check your internet connection.',
              statusCode: 408,
            ),
          );
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        message: 'Cannot connect to server. Please make sure Laravel is running.',
        statusCode: 0,
      );
    }
  }

  /// Gets a short-lived signed URL to the delivery photo on file for one of
  /// the signed-in rider's own assignments, via
  /// `GET /api/driver/deliveries/{id}/photo`.
  Future<Map<String, dynamic>> getDeliveryPhoto({
    required String parcelAssignmentId,
    required String accessToken,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/driver/deliveries/$parcelAssignmentId/photo'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _handleResponse(response);
  }

  /// The Settings screen's "Danger Zone" self-deactivation via
  /// `DELETE /api/driver/account/deactivate`.
  Future<Map<String, dynamic>> deactivateDriverAccount({
    required String accessToken,
    required String confirmationPhrase,
    required String password,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/driver/account/deactivate'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'confirmation_phrase': confirmationPhrase,
        'password': password,
      }),
    );
    return _handleResponse(response);
  }

  // ============================================================
  // DRIVER / COURIER MESSAGING ENDPOINTS
  // ============================================================

  /// Paginated inbox — GET `/driver/messages/conversations`. [status] is
  /// one of all|unread|needs_response|resolved|archived (omit/empty for
  /// all-non-archived); [search] matches employer name or message preview.
  Future<Map<String, dynamic>> getChatConversations({
    required String accessToken,
    String? search,
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    final queryParameters = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null && status.isNotEmpty && status != 'all') 'status': status,
    };
    final uri = Uri.parse('$baseUrl/driver/messages/conversations').replace(queryParameters: queryParameters);
    final response = await http.get(uri, headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    });
    return _handleResponse(response);
  }

  /// Single conversation — also marks the employer's messages read
  /// server-side, same as opening a thread in the web inbox.
  Future<Map<String, dynamic>> getChatConversation({
    required String id,
    required String accessToken,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/driver/messages/conversations/${Uri.encodeComponent(id)}'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $accessToken'},
    );
    return _handleResponse(response);
  }

  /// Cursor-paginated messages — GET `/driver/messages/conversations/{id}/messages`.
  /// No cursor = latest [limit] messages (oldest→newest). [before] loads
  /// older history; [after] is the poll path, pulling only new messages.
  Future<Map<String, dynamic>> getChatMessages({
    required String conversationId,
    required String accessToken,
    String? before,
    String? after,
    int limit = 20,
  }) async {
    final queryParameters = <String, String>{
      'limit': '$limit',
      if (before != null && before.isNotEmpty) 'before': before,
      if (after != null && after.isNotEmpty) 'after': after,
    };
    final uri = Uri.parse('$baseUrl/driver/messages/conversations/${Uri.encodeComponent(conversationId)}/messages')
        .replace(queryParameters: queryParameters);
    final response = await http.get(uri, headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    });
    return _handleResponse(response);
  }

  /// The "Message" button next to the call icon on a delivery's Buyer/
  /// Seller contact row (assigned_delivery_detail_screen.dart) — finds or
  /// creates this rider's direct thread with that contact and returns it
  /// in the same shape [getChatConversations]/[getChatConversation] do.
  /// [contact] is 'buyer' or 'seller'.
  Future<Map<String, dynamic>> startDeliveryConversation({
    required String accessToken,
    required String parcelAssignmentId,
    required String contact,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/driver/messages/delivery-conversations'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'parcel_assignment_id': parcelAssignmentId,
        'contact': contact,
      }),
    );
    return _handleResponse(response);
  }

  /// Sends a text and/or attachment message. [attachmentIds] must already
  /// be staged via [uploadChatAttachment].
  Future<Map<String, dynamic>> sendChatMessage({
    required String conversationId,
    required String accessToken,
    String? body,
    List<String> attachmentIds = const [],
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/driver/messages/conversations/${Uri.encodeComponent(conversationId)}/messages'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
        if (attachmentIds.isNotEmpty) 'attachment_ids': attachmentIds,
      }),
    );
    return _handleResponse(response);
  }

  /// Stages one file (image/video/pdf) for a message that hasn't been sent
  /// yet — exactly one of [bytes]/[filePath] must be supplied. Returns the
  /// attachment id to pass to [sendChatMessage].
  Future<Map<String, dynamic>> uploadChatAttachment({
    required String accessToken,
    required String fileName,
    Uint8List? bytes,
    String? filePath,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/driver/messages/attachments'))
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $accessToken';

    if (bytes != null) {
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    } else {
      request.files.add(await http.MultipartFile.fromPath('file', filePath!, filename: fileName));
    }

    try {
      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 45),
            onTimeout: () => throw ApiException(
              message: 'Connection timeout. Please check your internet connection.',
              statusCode: 408,
            ),
          );
      return _handleResponse(await http.Response.fromStream(streamedResponse));
    } on SocketException {
      throw ApiException(
        message: 'Cannot connect to server. Please make sure Laravel is running.',
        statusCode: 0,
      );
    }
  }

  /// Archive / unarchive / resolve / reopen — [status] is one of
  /// open|resolved|archived (Conversation::STATUS_REQUEST_VALUES).
  Future<Map<String, dynamic>> setChatConversationStatus({
    required String conversationId,
    required String accessToken,
    required String status,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/driver/messages/conversations/${Uri.encodeComponent(conversationId)}/status'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'status': status}),
    );
    return _handleResponse(response);
  }

  /// Lightweight badge count — GET `/driver/messages/unread-count`.
  Future<Map<String, dynamic>> getChatUnreadCount({required String accessToken}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/driver/messages/unread-count'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $accessToken'},
    );
    return _handleResponse(response);
  }

  // ============================================================
  // RESPONSE HANDLER
  // ============================================================

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      Map<String, dynamic>? error;
      try {
        error = jsonDecode(response.body);
      } catch (_) {}
      throw ApiException(
        message: error?['message'] ??
            'Request failed with status ${response.statusCode}',
        statusCode: response.statusCode,
        errors: error?['errors'],
      );
    }
  }
}

/// One document collected by the signup wizard, ready to be attached to
/// [ApiService.submitSignupRegistration]'s multipart body. [field] is the
/// exact form field name the Laravel side reads — see
/// AuthController::fileMapForRole() (`id_file`, `business_permit`,
/// `orcr_file`, `license_file`) and registerLogistics() (`owner_id_file`,
/// `business_permit_file`, `mayor_permit_file`, `dti_reg_file`).
class SignupUpload {
  final String field;
  final String fileName;
  final Uint8List bytes;

  const SignupUpload({
    required this.field,
    required this.fileName,
    required this.bytes,
  });
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  ApiException({
    required this.message,
    this.statusCode,
    this.errors,
  });

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}
