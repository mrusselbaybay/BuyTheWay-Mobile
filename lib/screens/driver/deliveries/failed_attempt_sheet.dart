import 'package:flutter/material.dart';

import '../driver_theme.dart';

class FailedAttemptSheet extends StatefulWidget {
  const FailedAttemptSheet({super.key});

  @override
  State<FailedAttemptSheet> createState() => _FailedAttemptSheetState();
}

class _FailedAttemptSheetState extends State<FailedAttemptSheet> {
  static const _reasons = {
    'recipient_unavailable': 'Recipient not available',
    'incorrect_address': 'Wrong or incomplete address',
    'refused_delivery': 'Recipient refused delivery',
    'unreachable_by_phone': 'Recipient unreachable by phone',
    'business_closed': 'Business closed',
    'access_denied': 'Access denied / gated location',
    'weather_or_roads': 'Weather or road conditions',
    'package_damaged': 'Package damaged',
    'others': 'Others',
  };
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  String? _reason;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _reason != null &&
        (_reason != 'others' || _description.text.trim().isNotEmpty);
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: DriverColors.warning),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Text('Failed Delivery Attempt',
                          style: DriverText.sectionTitle)),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      tooltip: 'Cancel'),
                ]),
                const SizedBox(height: 8),
                const Text('Choose why this delivery could not be completed.',
                    style: DriverText.body),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Reason', border: OutlineInputBorder()),
                  items: _reasons.entries
                      .map((entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value, maxLines: 2)))
                      .toList(),
                  validator: (value) =>
                      value == null ? 'Select a reason.' : null,
                  onChanged: (value) => setState(() => _reason = value),
                ),
                if (_reason == 'others') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _description,
                    maxLength: 1000,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                        labelText: 'Describe what happened',
                        border: OutlineInputBorder()),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'A description is required.'
                        : null,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                    'The next attempt can start from midnight the next Philippine calendar day. Repeated failures require dispatcher approval.',
                    style: DriverText.caption),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: DriverButtonStyle.primary(DriverColors.warning),
                    onPressed: !canSubmit
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              Navigator.pop(context, (
                                _reason!,
                                _reason == 'others'
                                    ? _description.text.trim()
                                    : null
                              ));
                            }
                          },
                    icon: const Icon(Icons.check),
                    label: const Text('Confirm failed attempt'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
