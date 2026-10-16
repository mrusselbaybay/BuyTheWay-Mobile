import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_service.dart';

enum RemittanceRole { courier, seller }

class RemittancePageData {
  const RemittancePageData(this.items, this.page, this.lastPage);
  final List<Map<String, dynamic>> items;
  final int page;
  final int lastPage;

  factory RemittancePageData.fromJson(Map<String, dynamic> body) {
    final data = body['data'] as Map? ?? const {};
    final items = data['items'] ?? data['data'] ?? const [];
    return RemittancePageData(
      (items as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(),
      (data['current_page'] as num?)?.toInt() ?? 1,
      (data['last_page'] as num?)?.toInt() ?? 1,
    );
  }
}

class RemittanceApiService {
  RemittanceApiService(
      {required this.accessToken, required this.role, http.Client? client})
      : _client = client ?? http.Client();
  final String accessToken;
  final RemittanceRole role;
  final http.Client _client;
  String get _base => '/${role.name}/remittances';
  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

  void close() => _client.close();

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body = {};
    try {
      final raw = jsonDecode(response.body);
      if (raw is Map) body = Map<String, dynamic>.from(raw);
    } on FormatException {/* An HTML error is handled below. */}
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        body.isNotEmpty) {
      return body;
    }
    String message =
        '${body['message'] ?? 'Could not complete the request. Please try again.'}';
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) message = '${first.first}';
    }
    if (response.statusCode == 401) {
      message = 'Your session has expired. Please sign in again.';
    }
    throw ApiException(message: message, statusCode: response.statusCode);
  }

  Future<Map<String, dynamic>> _send(String method, String path,
      {Map<String, dynamic>? body, Map<String, String>? query}) async {
    final uri =
        Uri.parse('${ApiService.baseUrl}$path').replace(queryParameters: query);
    try {
      final response = await (method == 'GET'
              ? _client.get(uri, headers: _headers)
              : _client.post(uri,
                  headers: _headers, body: jsonEncode(body ?? {})))
          .timeout(const Duration(seconds: 25));
      return _decode(response);
    } on TimeoutException {
      throw ApiException(
          message:
              'The request timed out. Refresh to check its status before submitting again.',
          statusCode: 408);
    } on http.ClientException {
      throw ApiException(
          message:
              'Could not reach the server. Check your connection and retry.',
          statusCode: 0);
    }
  }

  Future<Map<String, dynamic>> summary() async => Map<String, dynamic>.from(
      (await _send('GET', '$_base/summary'))['data'] as Map);

  Future<RemittancePageData> records(String tab,
      {int page = 1, String search = '', String status = ''}) async {
    final allowed = role == RemittanceRole.courier
        ? const ['collections', 'cod', 'earnings', 'payouts']
        : const [
            'cod',
            'gcash',
            'obligations',
            'statements',
            'payments',
            'disputes'
          ];
    if (!allowed.contains(tab)) throw ArgumentError.value(tab);
    return RemittancePageData.fromJson(
        await _send('GET', '$_base/$tab', query: {
      'page': '$page',
      if (search.isNotEmpty) 'search': search,
      if (status.isNotEmpty && tab != 'collections') 'status': status,
    }));
  }

  Future<String> uploadProof(Uint8List bytes, String filename) async {
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw ApiException(
          message: 'Choose a proof file smaller than 5 MB.', statusCode: 422);
    }
    final request = http.MultipartRequest(
        'POST', Uri.parse('${ApiService.baseUrl}$_base/proof'))
      ..headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken'
      })
      ..files.add(
          http.MultipartFile.fromBytes('proof', bytes, filename: filename));
    try {
      final response =
          await http.Response.fromStream(await _client.send(request))
              .timeout(const Duration(seconds: 45));
      return '${(_decode(response)['data'] as Map)['path']}';
    } on TimeoutException {
      throw ApiException(
          message: 'Proof upload timed out. Please try again.',
          statusCode: 408);
    } on http.ClientException {
      throw ApiException(
          message: 'Could not upload the proof. Check your connection.',
          statusCode: 0);
    }
  }

  Future<void> submitCod(
      {required String collectionId,
      required String reference,
      required String proofPath}) async {
    await _send('POST', '$_base/cod', body: {
      'collection_id': collectionId,
      'reference': reference,
      'proof_path': proofPath
    });
  }

  Future<void> review(String tab, String id, String action, String note) async {
    if (role != RemittanceRole.seller || !['cod', 'gcash'].contains(tab)) {
      throw ArgumentError('Seller receipts only.');
    }
    await _send('POST', '$_base/$tab/${Uri.encodeComponent(id)}/review',
        body: {'action': action, 'note': note});
  }

  Future<void> submitPayment(
      {required List<String> obligationIds,
      required int cents,
      required String reference,
      required String proofPath}) async {
    await _send('POST', '$_base/payments', body: {
      'obligation_ids': obligationIds,
      'amount_cents': cents,
      'reference': reference,
      'proof_path': proofPath
    });
  }

  Future<void> dispute(String id, String reason, String? evidencePath) async {
    await _send('POST', '$_base/obligations/${Uri.encodeComponent(id)}/dispute',
        body: {
          'reason': reason,
          if (evidencePath != null) 'evidence_path': evidencePath
        });
  }

  Future<Map<String, dynamic>> statement(String id, {int page = 1}) async =>
      Map<String, dynamic>.from((await _send(
          'GET', '$_base/statements/${Uri.encodeComponent(id)}',
          query: {'page': '$page'}))['data'] as Map);

  Future<RemittancePageData> history(String id, {int page = 1}) async =>
      RemittancePageData.fromJson(await _send(
          'GET', '$_base/history/${Uri.encodeComponent(id)}',
          query: {'page': '$page'}));

  Future<String> sellerSession() async =>
      '${(await _send('POST', '/account/remittance-session'))['access_token']}';
}
