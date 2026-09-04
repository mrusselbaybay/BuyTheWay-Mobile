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
