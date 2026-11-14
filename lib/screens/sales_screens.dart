import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../widgets/common.dart';
import 'profile_screens.dart' show GcashQrImage;

// ───────────────────────── Sales tab ─────────────────────────

class SalesTab extends StatefulWidget {
  const SalesTab({super.key});
  @override
  State<SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<SalesTab> {
  String _q = '';
  String _cat = 'All';

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final list = store.products
          .where((p) => (_cat == 'All' || p.category == _cat) && p.name.toLowerCase().contains(_q.toLowerCase()))
          .toList();
      return BluePage(
        title: 'Sales',
        actions: [
          HeaderIcon(Icons.history, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SalesHistoryScreen()))),
          HeaderIcon(Icons.shopping_cart_outlined,
              badge: store.cart.isNotEmpty,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewSaleScreen()))),
        ],
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: SearchBox(onChanged: (v) => setState(() => _q = v)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 6),
            child: ChipsRow(
              options: [
                'All',
                ...store.products
                    .map((p) => p.category)
                    .where((c) => c.trim().isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort(),
              ],
              selected: _cat,
              onChanged: (v) => setState(() => _cat = v),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? EmptyState(Icons.inventory_2_outlined,
                    store.products.isEmpty ? 'No products yet.\nAdd some in the Stocks tab.' : 'No matching products.')
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final p = list[i];
                      return ProductRow(
                        product: p,
                        onAdd: p.stock <= 0
                            ? null
                            : () {
                                final err = store.addToCart(p);
                                snack(context, err ?? 'Added ${p.name} to the sale');
                              },
                      );
                    },
                  ),
          ),
        ]),
      );
    });
  }
}

// ───────────────────────── New sale (cart) ─────────────────────────

class NewSaleScreen extends StatelessWidget {
  const NewSaleScreen({super.key});

  Future<void> _removeItem(BuildContext context, SaleItem it) async {
    if (store.skipItemDeleteConfirm) {
      store.removeFromCart(it);
      return;
    }
    var dontAsk = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setSt) => Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Delete', style: ts(13, w: FontWeight.w700)),
              const Divider(height: 18),
              Text('Are you sure you want to delete this item?', style: ts(11), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Row(children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(value: dontAsk, onChanged: (v) => setSt(() => dontAsk = v ?? false)),
                ),
                const SizedBox(width: 6),
                Text("Don't show this message again", style: ts(10)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(c, false), child: Text('CANCEL', style: ts(10, w: FontWeight.w700)))),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kRed),
                    onPressed: () => Navigator.pop(c, true),
                    child: Text('DELETE', style: ts(10, w: FontWeight.w700, c: Colors.white)),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
    if (ok == true) {
      if (dontAsk) store.skipItemDeleteConfirm = true;
      store.removeFromCart(it);
    }
  }

  Future<void> _clear(BuildContext context) async {
    final ok = await confirmDelete(context, message: 'Are you sure you want to clear this sale? This action cannot be undone.');
    if (ok) store.clearCart();
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final cart = store.cart;
      return BluePage(
        back: true,
        title: 'New Sale',
        actions: [HeaderIcon(Icons.delete_outline, onTap: cart.isEmpty ? null : () => _clear(context))],
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              children: [
                for (final it in cart)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE3ECF7)))),
                    child: Row(children: [
                      ProductThumb(store.productById(it.productId), size: 38),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(it.name, style: ts(12, w: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(peso(it.price, decimals: true), style: ts(11, w: FontWeight.w700, c: kBlue)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        GestureDetector(
                          onTap: () => _removeItem(context, it),
                          child: const Icon(Icons.delete_outline, size: 16, color: kRed),
                        ),
                        const SizedBox(height: 4),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          _Step(Icons.remove, () => store.setCartQty(it, it.qty - 1)),
                          SizedBox(width: 26, child: Text('${it.qty}', textAlign: TextAlign.center, style: ts(11, w: FontWeight.w700))),
                          _Step(Icons.add, () {
                            final err = store.setCartQty(it, it.qty + 1);
                            if (err != null) snack(context, err);
                          }),
                        ]),
                      ]),
                    ]),
                  ),
                const SizedBox(height: 12),
                Material(
                  color: kBlueTint,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      store.tab.value = 1;
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    child: SizedBox(
                      height: 38,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.add, size: 16, color: kBlue),
                        const SizedBox(width: 6),
                        Text('Add More Products', style: ts(11, w: FontWeight.w600, c: kBlue)),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(children: [
              Text('Items (${store.cartCount})', style: ts(11, w: FontWeight.w500)),
              const Spacer(),
              Text(peso(store.cartTotal, decimals: true), style: ts(11, w: FontWeight.w600)),
            ]),
          ),
          const Divider(height: 18, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text('Total Amount', style: ts(14, w: FontWeight.w700)),
              const Spacer(),
              Text(peso(store.cartTotal, decimals: true), style: ts(16, w: FontWeight.w700, c: kBlue)),
            ]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(children: [
                Expanded(
                  child: AppButton('Cash', color: kGreen, height: 42, icon: Icons.paid,
                      onPressed: cart.isEmpty ? null : () => _pay(context, 'Cash')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton('Gcash', height: 42, leading: const GIcon(size: 20, light: true),
                      onPressed: cart.isEmpty
                          ? null
                          : () {
                              if (requirePremium(context, 'GCash payments')) _pay(context, 'Gcash');
                            }),
                ),
              ]),
            ),
          ),
        ]),
      );
    });
  }

  void _pay(BuildContext context, String method) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentScreen(initialMethod: method)));
  }
}

class _Step extends StatelessWidget {
  const _Step(this.icon, this.onTap);
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: kFieldBorder),
        ),
        child: Icon(icon, size: 14, color: kBlue),
      ),
    );
  }
}

// ───────────────────────── Payment ─────────────────────────

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.initialMethod});
  final String initialMethod;
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late String _method = widget.initialMethod;
  final _received = TextEditingController();
  late final double _total = store.cartTotal;
  Sale? _done;

  @override
  void initState() {
    super.initState();
    _received.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _received.dispose();
    super.dispose();
  }

  double get _rec => parseMoney(_received.text);

  void _confirm() {
    if (store.cart.isEmpty) return;
    if (_method == 'Cash' && _rec < _total) {
      snack(context, 'Amount received is less than the total.');
      return;
    }
    final sale = store.completeSale(method: _method, received: _method == 'Cash' ? _rec : _total);
    setState(() => _done = sale);
  }

  void _finish(bool newSale) {
    store.tab.value = newSale ? 1 : 0;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final done = _done;
    return PopScope(
      canPop: done == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(false);
      },
      child: BluePage(
        back: true,
        title: 'Select Payment Method',
        onBack: done == null ? null : () => _finish(false),
        child: done != null ? _completed(done) : (_method == 'Cash' ? _cash() : _gcash()),
      ),
    );
  }

  Widget _toggle() {
    Widget btn(String m) {
      final sel = _method == m;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (m == 'Gcash' && !requirePremium(context, 'GCash payments')) return;
            setState(() => _method = m);
          },
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? kBlue : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBlue),
            ),
            child: Text(m, style: ts(12, w: FontWeight.w600, c: sel ? Colors.white : kBlue)),
          ),
        ),
      );
    }

    return Row(children: [btn('Cash'), const SizedBox(width: 10), btn('Gcash')]);
  }

  Widget _totalCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: cardDeco(border: const Color(0xFFD5E4F7)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Total Amount', style: ts(10, w: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(peso(_total, decimals: true), style: ts(20, w: FontWeight.w700, c: kBlue)),
        ]),
      );

  Widget _cash() {
    final change = _rec >= _total ? _rec - _total : 0.0;
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _toggle(),
            const SizedBox(height: 14),
            _totalCard(),
            const SizedBox(height: 16),
            fieldLabel('Amount Received', false),
            const SizedBox(height: 6),
            TextField(
              controller: _received,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: moneyFormatters,
              style: ts(13, w: FontWeight.w600),
              decoration: fieldDeco(hint: '0.00', prefixText: '₱'),
            ),
            const SizedBox(height: 10),
            Row(children: [
              for (final v in [50, 100, 200, 500])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _received.text = '$v',
                      child: Container(
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: kGreenTint, borderRadius: BorderRadius.circular(8)),
                        child: Text('₱$v', style: ts(11, w: FontWeight.w600, c: kBlue)),
                      ),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 22),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Text('Change', style: ts(12, w: FontWeight.w700)),
                const Spacer(),
                Text(peso(change, decimals: true), style: ts(14, w: FontWeight.w700, c: kBlue)),
              ]),
            ),
          ]),
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: AppButton('Confirm Payment', onPressed: _rec >= _total && _total > 0 ? _confirm : null),
        ),
      ),
    ]);
  }

  Widget _gcash() {
    final qr = store.profile.qr;
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(children: [
            _toggle(),
            const SizedBox(height: 14),
            _totalCard(),
            const SizedBox(height: 16),
            Text('Scan this QR Code to Pay', style: ts(11, w: FontWeight.w700, c: kBlue)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: cardDeco(border: const Color(0xFFD5E4F7)),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const GIcon(size: 20),
                  const SizedBox(width: 6),
                  Text('Gcash', style: ts(14, w: FontWeight.w700, c: kBlue)),
                ]),
                const SizedBox(height: 10),
                GcashQrImage(qr, size: 170),
                const SizedBox(height: 10),
                Text(store.profile.ownerName.isEmpty ? store.profile.storeName : store.profile.ownerName,
                    style: ts(12, w: FontWeight.w600, c: kBlue)),
                Text(store.profile.phone, style: ts(11, w: FontWeight.w500, c: kBlue)),
              ]),
            ),
            const SizedBox(height: 10),
            Text(qr == null
                    ? 'Add your GCash QR in Profile > Gcash QR Code.'
                    : 'After payment, tap the button below.',
                style: ts(9, c: kMuted)),
          ]),
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: AppButton('Done', onPressed: _total > 0 ? _confirm : null),
        ),
      ),
    ]);
  }

  Widget _completed(Sale s) {
    Widget row(String l, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [Text(l, style: ts(10)), const Spacer(), Text(v, style: ts(10, w: FontWeight.w600))]),
        );
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 36, 16, 8),
          child: Column(children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 46),
            ),
            const SizedBox(height: 14),
            Text('Sale Completed!', style: ts(18, w: FontWeight.w600, c: kBlue)),
            const SizedBox(height: 2),
            Text(peso(s.total, decimals: true), style: ts(18, w: FontWeight.w700, c: kBlue)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: const BoxDecoration(
                border: Border.symmetric(horizontal: BorderSide(color: Color(0xFFE3ECF7))),
              ),
              child: Column(children: [
                row('Date', fmtDateLong(s.date)),
                row('Time', fmtTime(s.date)),
                row('Items', '${s.itemCount}'),
                row('Payment', s.method),
                if (s.method == 'Cash' && s.received > s.total) row('Change', peso(s.received - s.total, decimals: true)),
              ]),
            ),
          ]),
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AppButton('New Sale', outlined: true, height: 40, onPressed: () => _finish(true)),
            const SizedBox(height: 8),
            AppButton('Done', height: 40, onPressed: () => _finish(false)),
          ]),
        ),
      ),
    ]);
  }
}

// ───────────────────────── Sales history ─────────────────────────

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});
  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  String _q = '';
  String _filter = 'All';
  bool _deleteMode = false;

  bool _inRange(DateTime d) {
    final now = DateTime.now();
    final today = dayStart(now);
    switch (_filter) {
      case 'Today':
        return sameDay(d, now);
      case 'Yesterday':
        return sameDay(d, today.subtract(const Duration(days: 1)));
      case 'Weekly':
        return !d.isBefore(today.subtract(const Duration(days: 6)));
      case 'Monthly':
        return d.year == now.year && d.month == now.month;
      default:
        return true;
    }
  }

  Future<void> _delete(Sale s) async {
    final ok = await confirmDelete(context, message: 'Are you sure you want to delete this transaction? Stock will be restored.');
    if (ok) store.deleteSale(s.id);
  }

  void _details(Sale s) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(fmtDateTime(s.date), style: ts(12, w: FontWeight.w700)),
              const Spacer(),
              StatusChip(s.method),
            ]),
            const Divider(height: 22),
            for (final i in s.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text('${i.qty} × ${i.name}', style: ts(11))),
                  Text(peso(i.price * i.qty, decimals: true), style: ts(11, w: FontWeight.w600)),
                ]),
              ),
            const Divider(height: 22),
            Row(children: [
              Text('Total', style: ts(12, w: FontWeight.w700)),
              const Spacer(),
              Text(peso(s.total, decimals: true), style: ts(14, w: FontWeight.w700, c: kBlue)),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final list = store.sales
          .where((s) =>
              _inRange(s.date) &&
              (store.isPremium || !s.date.isBefore(dayStart(DateTime.now()).subtract(const Duration(days: kFreeHistoryDays - 1)))) &&
              (_q.isEmpty || s.items.any((i) => i.name.toLowerCase().contains(_q.toLowerCase()))))
          .toList();
      return BluePage(
        back: true,
        title: 'Sales History',
        actions: [
          HeaderIcon(_deleteMode ? Icons.close : Icons.delete_outline, onTap: () => setState(() => _deleteMode = !_deleteMode)),
        ],
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: SearchBox(onChanged: (v) => setState(() => _q = v)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 6),
            child: ChipsRow(
                options: const ['All', 'Today', 'Yesterday', 'Weekly', 'Monthly'],
                selected: _filter,
                onChanged: (v) {
                  if (v == 'Monthly' && !requirePremium(context, 'Monthly business summary')) return;
                  setState(() => _filter = v);
                }),
          ),
          if (!store.isPremium) const _HistoryLimitBanner(),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(Icons.receipt_long, 'No sales found.')
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final s = list[i];
                      return InkWell(
                        onTap: () => _details(s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE3ECF7)))),
                          child: Row(children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(color: kBlueTint, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.calendar_month, size: 18, color: kBlue),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(fmtDateLong(s.date), style: ts(11, w: FontWeight.w600)),
                                Text(peso(s.total, decimals: true), style: ts(11, w: FontWeight.w600, c: kBlue)),
                              ]),
                            ),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(fmtTime(s.date), style: ts(10, w: FontWeight.w600)),
                              const SizedBox(height: 3),
                              StatusChip(s.method),
                            ]),
                            if (_deleteMode) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _delete(s),
                                child: const Icon(Icons.delete_outline, color: kRed, size: 20),
                              ),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      );
    });
  }
}

class _HistoryLimitBanner extends StatelessWidget {
  const _HistoryLimitBanner();
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => requirePremium(context, 'Full sales history',
          detail: 'The Free plan shows only the last $kFreeHistoryDays days of sales. Subscribe to Premium to see your full sales history.'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        padding: const EdgeInsets.all(10),
        decoration: cardDeco(color: kBlueTint, r: 10),
        child: Row(children: [
          const Icon(Icons.lock_outline, size: 16, color: kBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Free plan shows the last $kFreeHistoryDays days of sales. Tap to unlock full history.',
                style: ts(9.5, c: kBlue, h: 1.4)),
          ),
        ]),
      ),
    );
  }
}