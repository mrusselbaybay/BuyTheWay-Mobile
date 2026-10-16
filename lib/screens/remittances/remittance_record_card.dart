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
    final reviewing = seller &&
        row['can_verify'] == true &&
        (status == 'awaiting_verification' ||
            (tab == 'cod' && status == 'disputed'));
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? DriverColors.primary : DriverColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (onSelect != null)
            Checkbox(
                value: selected,
                onChanged: onSelect,
                semanticLabel: 'Select ${remittanceOrder(row)}'),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    tab == 'statements'
                        ? '${row['period_start']} – ${row['period_end']}'
                        : remittanceOrder(row),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                if (counterparty.isNotEmpty)
                  Text(counterparty,
                      style:
                          const TextStyle(color: DriverColors.textSecondary)),
                if (row['kind'] != null || row['task_type'] != null)
                  Text(remittanceLabel(row['kind'] ?? row['task_type']),
                      style:
                          const TextStyle(color: DriverColors.textSecondary)),
              ])),
          const SizedBox(width: 8),
          Flexible(
              child: Text(remittanceMoney(amount),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 17))),
        ]),
        const SizedBox(height: 10),
        Text(statusText,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.w700)),
        if (row['reference'] != null)
          SelectableText('Reference: ${row['reference']}'),
        if (row['deadline'] != null)
          Text('Due ${row['deadline']}'.split('T').first),
        if (row['review_note'] != null && '${row['review_note']}'.isNotEmpty)
          Text('${row['review_note']}'),
        if (tab == 'collections' && remittanceCents(row['remaining_cents']) > 0)
          Text('Not yet confirmed: ${remittanceMoney(row['remaining_cents'])}',
              style: const TextStyle(color: DriverColors.textSecondary)),
        if (tab == 'earnings')
          const Text('Paid by logistics from the 80% rider pool.',
              style: TextStyle(color: DriverColors.textSecondary)),
        if (tab == 'disputes') Text('${row['reason'] ?? ''}'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          if (row['proof_url'] != null)
            TextButton.icon(
                onPressed: () => onAction('proof'),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('View proof')),
          if (!seller &&
              tab == 'collections' &&
              remittanceCents(row['remaining_cents']) > 0 &&
              ['pending', 'rejected'].contains(status))
            FilledButton.icon(
                onPressed: () => onAction('cod'),
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('Remit to seller')),
          if (reviewing) ...[
            FilledButton(
                onPressed: () => onAction('verify'),
                child: const Text('Confirm receipt')),
            TextButton(
                onPressed: () => onAction('reject'),
                child: const Text('Reject')),
            if (tab == 'cod' && status == 'awaiting_verification')
              TextButton(
                  onPressed: () => onAction('codDispute'),
                  child: const Text('Dispute')),
          ],
          if (seller && tab == 'obligations' && status != 'disputed') ...[
            if (amount > 0 && row['recipient_key'] != 'unassigned')
              FilledButton(
                  onPressed: () => onAction('payment'),
                  child: const Text('Remit')),
            TextButton(
                onPressed: () => onAction('dispute'),
                child: const Text('Dispute charge')),
          ],
          if (tab == 'statements')
            TextButton.icon(
                onPressed: () => onAction('statement'),
                icon: const Icon(Icons.list_alt_outlined, size: 18),
                label: const Text('View orders')),
          if (['cod', 'payments', 'obligations', 'statements'].contains(tab))
            TextButton(
                onPressed: () => onAction('history'),
                child: const Text('History')),
          if (tab == 'collections' && row['submission_id'] != null)
            TextButton(
                onPressed: () => onAction('receiptHistory'),
                child: const Text('Receipt history')),
        ]),
      ]),
    );
  }
}
