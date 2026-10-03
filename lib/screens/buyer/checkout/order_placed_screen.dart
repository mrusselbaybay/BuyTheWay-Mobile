import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../buyer_models.dart';
import '../buyer_shell.dart';
import '../buyer_theme.dart';

class OrderPlacedScreen extends StatelessWidget {
  const OrderPlacedScreen({super.key, required this.references, required this.total, required this.paymentMethod});

  final List<String> references;
  final double total;
  final String paymentMethod;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    Widget check = Container(
      width: 84,
      height: 84,
      decoration: const BoxDecoration(color: BColors.successSurface, shape: BoxShape.circle),
      child: const Icon(Icons.check_rounded, color: BColors.success, size: 48),
    );
    if (!reduceMotion) check = check.animate().scale(begin: const Offset(0.6, 0.6), duration: 320.ms, curve: Curves.easeOutBack);

    return Scaffold(
      backgroundColor: BColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            check,
            const SizedBox(height: 20),
            const Text('Order placed!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: BColors.ink)),
            const SizedBox(height: 8),
            Text(
              references.length > 1
                  ? '${references.length} orders were created — one per shop.'
                  : references.isNotEmpty
                      ? 'Order ${references.first}'
                      : 'Your order is on its way to the seller.',
              textAlign: TextAlign.center,
              style: BText.body,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: BColors.background, borderRadius: BorderRadius.circular(BRadius.md)),
              child: Column(children: [
                Row(children: [
                  const Expanded(child: Text('Total', style: BText.small)),
                  Text(peso(total), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: BColors.cta)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Expanded(child: Text('Payment', style: BText.small)),
                  Text(paymentLabel(paymentMethod), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                ]),
                if (paymentMethod == 'cod') ...[
                  const SizedBox(height: 10),
                  const Text('Please prepare the exact amount when your parcel arrives.', style: BText.tiny, textAlign: TextAlign.center),
                ],
              ]),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: BButtons.brand(height: 48),
                onPressed: () => BuyerShell.goTo(context, 1),
                child: const Text('View My Orders'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: BButtons.outline(height: 48),
                onPressed: () => BuyerShell.goTo(context, 0),
                child: const Text('Continue Shopping'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
