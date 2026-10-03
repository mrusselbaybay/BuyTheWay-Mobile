// Card / wallet helpers mirroring the web useBuyerPayments.js, so saved
// methods look identical across web and mobile. Full card numbers and
// CVCs never leave the device — only brand, last4 and expiry are stored.

String digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

bool luhnValid(String number) {
  final digits = digitsOnly(number);
  if (digits.length < 13 || digits.length > 19) return false;
  var sum = 0;
  var alt = false;
  for (var i = digits.length - 1; i >= 0; i--) {
    var n = digits.codeUnitAt(i) - 48;
    if (alt) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    alt = !alt;
  }
  return sum % 10 == 0;
}

String detectCardBrand(String number) {
  final d = digitsOnly(number);
  if (RegExp(r'^4').hasMatch(d)) return 'Visa';
  if (RegExp(r'^(5[1-5]|222[1-9]|22[3-9]|2[3-6]|27[01]|2720)').hasMatch(d)) return 'Mastercard';
  if (RegExp(r'^3[47]').hasMatch(d)) return 'Amex';
  if (RegExp(r'^(6011|65|64[4-9])').hasMatch(d)) return 'Discover';
  if (RegExp(r'^35(2[89]|[3-8]\d)').hasMatch(d)) return 'JCB';
  return 'Card';
}

/// Parses `MM/YY` → (month, fullYear), or null when malformed.
(int, int)? parseExpiry(String input) {
  final m = RegExp(r'^(\d{2})\s*/\s*(\d{2})$').firstMatch(input.trim());
  if (m == null) return null;
  final month = int.parse(m.group(1)!);
  if (month < 1 || month > 12) return null;
  return (month, 2000 + int.parse(m.group(2)!));
}

bool expiryPassed((int, int) expiry) {
  final now = DateTime.now();
  final (month, year) = expiry;
  return year < now.year || (year == now.year && month < now.month);
}

/// `0917 •••• 4567`
String maskPhone(String number) {
  final d = digitsOnly(number);
  if (d.length < 7) return d;
  return '${d.substring(0, 4)} •••• ${d.substring(d.length - 4)}';
}

bool validPhPhone(String phone) => RegExp(r'^(09\d{9}|\+639\d{9})$').hasMatch(phone.replaceAll(RegExp(r'[\s-]'), ''));
