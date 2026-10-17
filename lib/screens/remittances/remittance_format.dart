import 'package:flutter/services.dart';

String remittanceMoney(dynamic value) {
  final cents = remittanceCents(value);
  final amount = cents.abs();
  final whole = (amount ~/ 100)
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  return '${cents < 0 ? '−' : ''}₱$whole.${(amount % 100).toString().padLeft(2, '0')}';
}

int remittanceCents(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

String remittanceLabel(dynamic value) {
  final text = '${value ?? ''}'.replaceAll('_', ' ');
  return text.isEmpty
      ? 'Pending'
      : '${text[0].toUpperCase()}${text.substring(1)}';
}

String remittanceName(dynamic value) {
  if (value is! Map) return '';
  final business = '${value['company_name'] ?? value['business_name'] ?? ''}';
  return business.isNotEmpty
      ? business
      : '${value['first_name'] ?? ''} ${value['last_name'] ?? ''}'.trim();
}

String remittanceOrder(Map<String, dynamic> row) =>
    '${row['order_number'] ?? (row['order'] is Map ? row['order']['order_number'] : null) ?? row['reference'] ?? 'Payment'}';

int? parseRemittancePesos(String input) {
  final text = input.trim();
  if (!RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(text)) return null;
  final parts = text.split('.');
  return int.parse(parts.first) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
}

/// GCash transaction numbers: 13 digits shown as "0000 000 000000".
String remittanceReferenceDigits(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return digits.length > 13 ? digits.substring(0, 13) : digits;
}

class TransactionNumberFormatter extends TextInputFormatter {
  const TransactionNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final d = remittanceReferenceDigits(newValue.text);
    final parts = [
      d.substring(0, d.length.clamp(0, 4)),
      if (d.length > 4) d.substring(4, d.length.clamp(4, 7)),
      if (d.length > 7) d.substring(7),
    ];
    final text = parts.join(' ');
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
