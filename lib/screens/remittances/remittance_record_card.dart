import 'package:flutter/material.dart';
import '../driver/driver_theme.dart';
import 'remittance_format.dart';

class RemittanceRecordCard extends StatelessWidget {
  const RemittanceRecordCard(
      {super.key,
      required this.row,
      required this.tab,
      required this.seller,
      required this.onAction,
      this.selected = false,
      this.onSelect});
  final Map<String, dynamic> row;
  final String tab;
  final bool seller;
  final bool selected;
  final ValueChanged<bool?>? onSelect;
  final void Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    final status = '${row['status'] ?? 'pending'}';
    final amount = tab == 'obligations'
        ? remittanceCents(row['amount_cents']) -
            remittanceCents(row['paid_cents'])
        : tab == 'statements'
            ? remittanceCents(row['obligations_sum_amount_cents']) -
                remittanceCents(row['obligations_sum_paid_cents'])
            : remittanceCents(
                row[tab == 'payouts' ? 'net_cents' : 'amount_cents']);
    final counterparty = tab == 'collections'
        ? '${row['seller_name'] ?? 'Seller'}'
        : tab == 'cod'
            ? remittanceName(row[seller ? 'courier' : 'seller'])
            : remittanceName(row['company']);
    final statusColor = ['verified', 'paid', 'completed'].contains(status)
        ? DriverColors.success
        : ['rejected', 'disputed', 'overdue'].contains(status)
            ? DriverColors.error
            : DriverColors.warning;
    final statusText = status == 'awaiting_verification' &&
            !seller &&
            ['collections', 'cod'].contains(tab)
        ? 'Awaiting seller confirmation'
        : remittanceLabel(status);
    final statusSurface = statusColor == DriverColors.success
        ? DriverColors.successSurface
        : statusColor == DriverColors.error
            ? DriverColors.errorSurface
            : DriverColors.warningSurface;
    final title = tab == 'statements'
        ? '${row['period_start']} – ${row['period_end']}'
        : remittanceOrder(row);
    final subtitle = [
      if (counterparty.isNotEmpty) counterparty,
      if (row['kind'] != null || row['task_type'] != null)
        remittanceLabel(row['kind'] ?? row['task_type']),
    ].join(' · ');
    final canRemit = !seller &&
        tab == 'collections' &&
        remittanceCents(row['remaining_cents']) > 0 &&
        ['pending', 'rejected'].contains(status);
    final details = <(IconData, String)>[
      if (row['deadline'] != null)
        (Icons.event_rounded, 'Due ${row['deadline']}'.split('T').first),
      if (tab == 'collections' && remittanceCents(row['remaining_cents']) > 0)
        (
          Icons.hourglass_bottom_rounded,
          'Not yet confirmed: ${remittanceMoney(row['remaining_cents'])}'
        ),
      if (row['review_note'] != null && '${row['review_note']}'.isNotEmpty)
        (Icons.sticky_note_2_outlined, '${row['review_note']}'),
      if (tab == 'earnings')
        (
          Icons.info_outline_rounded,
          'Paid by logistics from the 80% rider pool.'
        ),
      if (tab == 'disputes' && '${row['reason'] ?? ''}'.isNotEmpty)
        (Icons.report_gmailerrorred_rounded, '${row['reason']}'),
    ];
    final reviewing = seller &&
        row['can_verify'] == true &&
        (status == 'awaiting_verification' ||
            (tab == 'cod' && status == 'disputed'));
    final secondary = <Widget>[
      if (row['proof_url'] != null)
        _link(Icons.image_outlined, 'View proof', () => onAction('proof')),
      if (reviewing) ...[
        _link(Icons.close_rounded, 'Reject', () => onAction('reject'),
            color: DriverColors.error),
        if (tab == 'cod' && status == 'awaiting_verification')
          _link(Icons.flag_outlined, 'Dispute', () => onAction('codDispute'),
              color: DriverColors.error),
      ],
      if (seller && tab == 'obligations' && status != 'disputed')
        _link(Icons.flag_outlined, 'Dispute charge',
            () => onAction('dispute'),
            color: DriverColors.error),
      if (tab == 'statements')
        _link(Icons.list_alt_outlined, 'View orders',
            () => onAction('statement')),
      if (['cod', 'payments', 'obligations', 'statements'].contains(tab))
        _link(Icons.history_rounded, 'History', () => onAction('history')),
      if (tab == 'collections' && row['submission_id'] != null)
        _link(Icons.history_rounded, 'Receipt history',
            () => onAction('receiptHistory')),
    ];
    final primaryButton = canRemit
        ? FilledButton.icon(
            onPressed: () => onAction('cod'),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Remit to seller'))
        : reviewing
            ? FilledButton.icon(
                onPressed: () => onAction('verify'),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Confirm receipt'))
            : seller &&
                    tab == 'obligations' &&
                    status != 'disputed' &&
                    amount > 0 &&
                    row['recipient_key'] != 'unassigned'
                ? FilledButton.icon(
                    onPressed: () => onAction('payment'),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Remit'))
                : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? DriverColors.primary : DriverColors.border,
              width: selected ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (onSelect != null)
            Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Checkbox(
                    value: selected,
                    onChanged: onSelect,
                    semanticLabel: 'Select ${remittanceOrder(row)}'))
          else
            Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                    color: DriverColors.primarySurface,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(_tabIcon, size: 20, color: DriverColors.primary)),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: DriverColors.textPrimary)),
                if (subtitle.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DriverText.caption.copyWith(fontSize: 12.5))),
              ])),
          const SizedBox(width: 8),
          Text(remittanceMoney(amount),
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: DriverColors.textPrimary)),
        ]),
        const SizedBox(height: 12),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: statusSurface, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Flexible(
                  child: Text(statusText,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700))),
            ])),
        if (row['reference'] != null || details.isNotEmpty) ...[
          const SizedBox(height: 10),
          if (row['reference'] != null)
            _detail(Icons.tag_rounded, 'Ref ${row['reference']}',
                selectable: true),
          for (final d in details) _detail(d.$1, d.$2),
        ],
        if (primaryButton != null || secondary.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(height: 1, color: DriverColors.border),
          const SizedBox(height: 8),
          if (primaryButton != null)
            SizedBox(width: double.infinity, child: primaryButton),
          if (secondary.isNotEmpty)
            Wrap(spacing: 4, runSpacing: 0, children: secondary),
        ],
      ]),
    );
  }

  IconData get _tabIcon => switch (tab) {
        'collections' => Icons.payments_rounded,
        'cod' => Icons.receipt_long_rounded,
        'earnings' => Icons.savings_rounded,
        'payouts' => Icons.account_balance_rounded,
        'gcash' => Icons.qr_code_2_rounded,
        'statements' => Icons.description_rounded,
        'disputes' => Icons.flag_rounded,
        _ => Icons.receipt_rounded,
      };

  static Widget _detail(IconData icon, String text, {bool selectable = false}) {
    const style = TextStyle(
        fontSize: 12.5, color: DriverColors.textSecondary, height: 1.35);
    return Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 14, color: DriverColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
              child: selectable
                  ? SelectableText(text, style: style)
                  : Text(text, style: style)),
        ]));
  }

  static Widget _link(IconData icon, String label, VoidCallback onTap,
          {Color color = DriverColors.primary}) =>
      TextButton.icon(
          onPressed: onTap,
          style: TextButton.styleFrom(
              foregroundColor: color,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          icon: Icon(icon, size: 17),
          label: Text(label));
}
