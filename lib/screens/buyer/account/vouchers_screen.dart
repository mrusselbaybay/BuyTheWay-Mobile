import 'package:flutter/material.dart';

import '../buyer_models.dart';
import '../buyer_store.dart';
import '../buyer_theme.dart';
import '../product/product_detail_screen.dart';
import '../widgets/buyer_widgets.dart';

/// Claimed voucher wallet, split Available / Used / Expired.
class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  final store = BuyerStore.instance;
  List<Coupon>? wallet;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => error = null);
    try {
      final list = await store.api.couponWallet();
      if (mounted) setState(() => wallet = list);
    } catch (e) {
      if (mounted) setState(() => error = store.handleError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    const tabs = ['Available', 'Used', 'Expired'];
    bool inTab(Coupon c, String tab) => switch (tab) {
          'Used' => c.status == 'used',
          'Expired' => c.status == 'expired',
          _ => c.status != 'used' && c.status != 'expired',
        };

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: BColors.background,
        appBar: AppBar(
          backgroundColor: BColors.surface,
          surfaceTintColor: BColors.surface,
          foregroundColor: BColors.ink,
          title: const Text('My Vouchers', style: BText.title),
          bottom: TabBar(
            labelColor: BColors.brand,
            unselectedLabelColor: BColors.muted,
            indicatorColor: BColors.brand,
            tabs: [for (final t in tabs) Tab(text: t)],
          ),
        ),
        body: wallet == null
            ? (error != null ? ErrorState(message: error!, onRetry: _load) : const Center(child: CircularProgressIndicator(color: BColors.brand)))
            : TabBarView(
                children: [
                  for (final tab in tabs)
                    Builder(builder: (context) {
                      final list = wallet!.where((c) => inTab(c, tab)).toList();
                      return RefreshIndicator(
                        color: BColors.brand,
                        onRefresh: _load,
                        child: list.isEmpty
                            ? ListView(children: [
                                SizedBox(
                                  height: 380,
                                  child: EmptyState(
                                    icon: Icons.confirmation_number_outlined,
                                    title: tab == 'Available' ? 'No vouchers yet' : 'Nothing here',
                                    message: tab == 'Available' ? 'Claim vouchers on product pages — they apply automatically at checkout.' : null,
                                  ),
                                ),
                              ])
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: list.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (_, i) => _VoucherCard(coupon: list[i], active: tab == 'Available'),
                              ),
                      );
                    }),
                ],
              ),
      ),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({required this.coupon, required this.active});

  final Coupon coupon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final accent = active ? BColors.cta : BColors.faint;
    return Material(
      color: BColors.surface,
      borderRadius: BorderRadius.circular(BRadius.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: active && coupon.productId != null
            ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: coupon.productId!)))
            : null,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              width: 88,
              color: active ? BColors.ctaSurface : BColors.divider,
              alignment: Alignment.center,
              child: Icon(Icons.confirmation_number, color: accent, size: 30),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(coupon.label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: active ? BColors.ink : BColors.muted)),
                  if (coupon.productName != null) ...[
                    const SizedBox(height: 2),
                    Text('For ${coupon.productName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: BText.small),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    coupon.expiresAt != null ? (active ? 'Valid till ${formatDate(coupon.expiresAt)}' : 'Ended ${formatDate(coupon.expiresAt)}') : '',
                    style: TextStyle(fontSize: 11.5, color: active && coupon.runningLow ? BColors.cta : BColors.muted),
                  ),
                ]),
              ),
            ),
            if (active)
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Center(child: Text('Use', style: TextStyle(color: BColors.cta, fontWeight: FontWeight.w700))),
              ),
          ]),
        ),
      ),
    );
  }
}
