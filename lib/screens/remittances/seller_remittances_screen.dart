import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/remittance_api_service.dart';
import 'remittances_screen.dart';

/// Keeps seller financial access in a separate, in-memory role session.
class SellerRemittancesScreen extends StatefulWidget {
  const SellerRemittancesScreen({super.key, required this.buyerToken});
  final String buyerToken;
  @override
  State<SellerRemittancesScreen> createState() =>
      _SellerRemittancesScreenState();
}

class _SellerRemittancesScreenState extends State<SellerRemittancesScreen> {
  String? _token;
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = RemittanceApiService(
        accessToken: widget.buyerToken, role: RemittanceRole.seller);
    try {
      final token = await api.sellerSession();
      if (!mounted) {
        unawaited(ApiService().logout(token).catchError((_) {}));
        return;
      }
      setState(() {
        _token = token;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException
              ? e.message
              : 'Could not open seller remittances. Please retry.';
          _loading = false;
        });
      }
    } finally {
      api.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_token != null) {
      return RemittancesScreen(
          accessToken: _token!,
          role: RemittanceRole.seller,
          revokeOnClose: true);
    }
    return Scaffold(
        appBar: AppBar(title: const Text('Seller remittances')),
        body: Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: _loading
                    ? const CircularProgressIndicator()
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error ?? 'Could not open remittances.',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _open, child: const Text('Retry'))
                      ]))));
  }
}
