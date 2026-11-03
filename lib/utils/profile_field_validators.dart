import 'package:flutter/material.dart';

/// Shared client-side rules for personal profile fields.
/// Keep these aligned with the registration rules in auth_screen.dart.
class ProfileFieldValidators {
  ProfileFieldValidators._();

  static final RegExp _personName = RegExp(r"^[A-Za-z]+(?:[ '-][A-Za-z]+)*$");
  static final RegExp _mobile = RegExp(r'^09\d{9}$');

  static String? personName(String? raw, {required String label, int maxLength = 50}) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return '$label is required.';
    if (value.length < 2 || value.length > maxLength) {
      return '$label must be 2 to $maxLength characters.';
    }
    if (!_personName.hasMatch(value)) {
      return 'Use letters, spaces, hyphens, or apostrophes only.';
    }
    return null;
  }

  static String? middleInitial(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isNotEmpty && !RegExp(r'^[A-Za-z]$').hasMatch(value)) {
      return 'Middle initial must be one letter.';
    }
    return null;
  }

  static String? philippinesMobile(String? raw, {bool required = true}) {
    final value = (raw ?? '').replaceAll(RegExp(r'[\s-]'), '').trim();
    if (value.isEmpty) return required ? 'Contact number is required.' : null;
    if (!_mobile.hasMatch(value)) return 'Use an 11-digit mobile number starting with 09.';
    return null;
  }

  static String? adultBirthday(DateTime? birthday, {bool required = true}) {
    if (birthday == null) return required ? 'Birthday is required.' : null;
    final today = DateUtils.dateOnly(DateTime.now());
    final date = DateUtils.dateOnly(birthday);
    if (date.isAfter(today)) return 'Birthday cannot be in the future.';
    final cutoff = DateTime(today.year - 18, today.month, today.day);
    if (date.isAfter(cutoff)) return 'You must be at least 18 years old.';
    return null;
  }
}
