import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../widgets/common.dart';

// ───────────────────────── Debt overview ─────────────────────────

class DebtTab extends StatefulWidget {
  const DebtTab({super.key});
  @override
  State<DebtTab> createState() => _DebtTabState();
}

class _DebtTabState extends State<DebtTab> {
  String _q = '';
  int _f = 0;

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      if (!store.isPremium) {
        return const BluePage(
          title: 'Debt',
          child: PremiumLockedView(
            feature: 'Customer credit tracking',
            description: 'Record customer utang, due dates and payments with the Premium Plan. You need to subscribe first to access this.',
          ),
        );
      }
      final paid = store.debts.where((d) => d.paid).length;
      final unpaid = store.debts.length - paid;
      final list = store.debts.where((d) {
        if (_f == 1 && d.paid) return false;
        if (_f == 2 && !d.paid) return false;
        return d.customer.toLowerCase().contains(_q.toLowerCase());
      }).toList();
      return BluePage(
        title: 'Debt',
        actions: [HeaderIcon(Icons.notifications, badge: store.hasAlerts, onTap: () => showAlerts(context))],
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(children: [
              Expanded(child: _Count('$paid', 'Customer Paid', kGreen, kGreenTint)),
              const SizedBox(width: 12),
              Expanded(child: _Count('$unpaid', 'Customer Unpaid', kRed, kRedTint)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SearchBox(hint: 'Search customer...', onChanged: (v) => setState(() => _q = v)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: SegmentTabs(options: const ['All', 'Unpaid', 'Paid'], selected: _f, onChanged: (v) => setState(() => _f = v)),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(Icons.people_outline, 'No customer debts found.')
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final d = list[i];
                      return GestureDetector(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DebtDetailScreen(debtId: d.id))),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: cardDeco(border: const Color(0xFFD5E4F7)),
                          child: Row(children: [
                            InitialAvatar(d.customer, size: 34),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(d.customer, style: ts(11, w: FontWeight.w700)),
                                Text(peso(d.total, decimals: true), style: ts(13, w: FontWeight.w700, c: kBlue)),
                                Row(children: [
                                  const Icon(Icons.calendar_month, size: 10, color: kBlue),
                                  const SizedBox(width: 3),
                                  Text(fmtDateLong(d.debtDate), style: ts(8, c: kMuted)),
                                ]),
                              ]),
                            ),
                            d.paid ? const StatusChip('Paid') : const StatusChip('Unpaid', color: kRed, bg: kRedTint),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right, size: 18, color: kBlue),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: AppButton('Add Debt', color: kGreen, icon: Icons.add, height: 42,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DebtFormScreen()))),
          ),
        ]),
      );
    });
  }
}

class _Count extends StatelessWidget {
  const _Count(this.value, this.label, this.color, this.bg);
  final String value;
  final String label;
  final Color color;
  final Color bg;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: cardDeco(color: bg, border: color.withValues(alpha: 0.4)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(value, style: ts(24, w: FontWeight.w700, c: color)),
        Text(label, style: ts(9, c: color)),
      ]),
    );
  }
}

// ───────────────────────── Debt details ─────────────────────────

class DebtDetailScreen extends StatelessWidget {
  const DebtDetailScreen({super.key, required this.debtId});
  final String debtId;

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final d = store.debtById(debtId);
      if (d == null) {
        return const BluePage(back: true, title: 'Debt Details', child: EmptyState(Icons.people_outline, 'This debt no longer exists.'));
      }
      Widget cell(String t, {bool bold = false, TextAlign a = TextAlign.left}) =>
          Text(t, textAlign: a, style: ts(9, w: bold ? FontWeight.w700 : FontWeight.w500));
      return BluePage(
        back: true,
        title: 'Debt Details',
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: cardDeco(border: const Color(0xFFD5E4F7)),
                  child: Column(children: [
                    Row(children: [
                      InitialAvatar(d.customer, size: 40),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(d.customer, style: ts(12, w: FontWeight.w700, c: kBlue)),
                          Text(d.phone, style: ts(10, c: kBlueDark)),
                        ]),
                      ),
                      d.paid ? const StatusChip('Paid') : const StatusChip('Unpaid', color: kRed, bg: kRedTint),
                    ]),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: cardDeco(color: kBlueTint),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Total Debt Balance', style: ts(9, w: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(peso(d.total, decimals: true), style: ts(18, w: FontWeight.w700, c: kBlue)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: cardDeco(border: const Color(0xFFD5E4F7)),
                  child: Column(children: [
                    Row(children: [
                      const Icon(Icons.shopping_cart_outlined, size: 14, color: kBlue),
                      const SizedBox(width: 6),
                      Expanded(flex: 5, child: cell('Items Owed', bold: true)),
                      Expanded(flex: 1, child: cell('Qty', bold: true)),
                      Expanded(flex: 2, child: cell('Price', bold: true, a: TextAlign.right)),
                      Expanded(flex: 2, child: cell('Total', bold: true, a: TextAlign.right)),
                    ]),
                    const Divider(height: 16),
                    for (final i in d.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          const SizedBox(width: 20),
                          Expanded(flex: 5, child: cell(i.name)),
                          Expanded(flex: 1, child: cell('×${i.qty}')),
                          Expanded(flex: 2, child: cell(peso(i.price, decimals: true), a: TextAlign.right)),
                          Expanded(flex: 2, child: cell(peso(i.total, decimals: true), a: TextAlign.right)),
                        ]),
                      ),
                  ]),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: cardDeco(border: const Color(0xFFD5E4F7)),
                  child: Row(children: [
                    Expanded(child: _DateInfo('Debt Date', d.debtDate)),
                    Container(width: 1, height: 30, color: const Color(0xFFE3ECF7)),
                    const SizedBox(width: 12),
                    Expanded(child: _DateInfo('Due Date', d.dueDate)),
                  ]),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AppButton('Edit Debt', outlined: true, height: 42,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DebtFormScreen(debt: d)))),
                const SizedBox(height: 8),
                AppButton(d.paid ? 'Mark as Unpaid' : 'Paid', height: 42, onPressed: () {
                  store.setDebtPaid(d.id, !d.paid);
                  snack(context, d.paid ? 'Marked as paid' : 'Marked as unpaid');
                }),
              ]),
            ),
          ),
        ]),
      );
    });
  }
}

class _DateInfo extends StatelessWidget {
  const _DateInfo(this.label, this.date);
  final String label;
  final DateTime date;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Icon(Icons.calendar_month, size: 16, color: kBlue),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: ts(9, c: kMuted)),
        Text(fmtDateLong(date), style: ts(10, w: FontWeight.w700)),
      ]),
    ]);
  }
}

// ───────────────────────── Add / edit debt ─────────────────────────

class DebtFormScreen extends StatefulWidget {
  const DebtFormScreen({super.key, this.debt});
  final Debt? debt;
  @override
  State<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends State<DebtFormScreen> {
  final _key = GlobalKey<FormState>();
  late final _customer = TextEditingController(text: widget.debt?.customer ?? '');
  late final _phone = TextEditingController(text: widget.debt?.phone ?? '');
  final _search = TextEditingController();
  late final _debtDateC = TextEditingController(text: widget.debt == null ? '' : fmtDate(widget.debt!.debtDate));
  late final _dueDateC = TextEditingController(text: widget.debt == null ? '' : fmtDate(widget.debt!.dueDate));
  late final List<DebtItem> _items = widget.debt == null
      ? []
      : widget.debt!.items.map((i) => DebtItem(name: i.name, qty: i.qty, price: i.price)).toList();
  DateTime? _debtDate;
  DateTime? _dueDate;
  bool _paid = false;
  String _q = '';

  @override
  void initState() {
    super.initState();
    final d = widget.debt;
    _debtDate = d?.debtDate ?? DateTime.now();
    _dueDate = d?.dueDate;
    _paid = d?.paid ?? false;
    if (d == null) _debtDateC.text = fmtDate(_debtDate!);
  }

  @override
  void dispose() {
    _customer.dispose();
    _phone.dispose();
    _search.dispose();
    _debtDateC.dispose();
    _dueDateC.dispose();
    super.dispose();
  }

  double get _total => _items.fold(0.0, (s, i) => s + i.total);

  void _addProduct(Product p) {
    final i = _items.indexWhere((x) => x.name == p.name);
    setState(() {
      if (i >= 0) {
        _items[i].qty++;
      } else {
        _items.add(DebtItem(name: p.name, qty: 1, price: p.price));
      }
      _q = '';
      _search.clear();
    });
  }

  Future<void> _pickDebtDate() async {
    final d = await pickDate(context, _debtDate);
    if (d != null) {
      setState(() {
      _debtDate = d;
      _debtDateC.text = fmtDate(d);
      });
    }
  }

  Future<void> _pickDue() async {
    final d = await pickDate(context, _dueDate ?? _debtDate);
    if (d != null) {
      setState(() {
      _dueDate = d;
      _dueDateC.text = fmtDate(d);
      });
    }
  }

  void _save() {
    if (!_key.currentState!.validate()) return;
    if (_items.isEmpty) {
      snack(context, 'Add at least one product.');
      return;
    }
    if (_dueDate!.isBefore(dayStart(_debtDate!))) {
      snack(context, 'Due date cannot be before the debt date.');
      return;
    }
    final old = widget.debt;
    final d = Debt(
      id: old?.id ?? newId(),
      customer: _customer.text.trim(),
      phone: _phone.text.trim(),
      items: _items,
      debtDate: _debtDate!,
      dueDate: _dueDate!,
      paid: _paid,
    );
    if (old == null) {
      store.addDebt(d);
    } else {
      store.updateDebt(d);
    }
    snack(context, old == null ? 'Debt added' : 'Debt updated');
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await confirmDelete(context, message: 'Are you sure you want to delete this debt? This action cannot be undone.');
    if (!ok || !mounted) return;
    store.deleteDebt(widget.debt!.id);
    snack(context, 'Debt deleted');
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.debt != null;
    final matches = _q.isEmpty
        ? <Product>[]
        : store.products.where((p) => p.name.toLowerCase().contains(_q.toLowerCase())).take(5).toList();
    Widget th(String t, {TextAlign a = TextAlign.left}) => Text(t, textAlign: a, style: ts(9, w: FontWeight.w700));
    return BluePage(
      back: true,
      title: editing ? 'Edit Debt' : 'Add Debt',
      actions: [if (editing) HeaderIcon(Icons.delete_outline, onTap: _delete)],
      child: FormBody(
        formKey: _key,
        button: AppButton('Save', onPressed: _save),
        children: [
          AppField(label: 'Customer', controller: _customer, hint: 'Customer name', icon: Icons.person_outline),
          AppField(label: 'Phone Number', controller: _phone, hint: 'Phone Number', icon: Icons.phone_outlined, keyboard: TextInputType.phone, validator: phoneError),
          fieldLabel('Products', true),
          const SizedBox(height: 6),
          TextField(
            controller: _search,
            style: ts(12),
            onChanged: (v) => setState(() => _q = v),
            decoration: fieldDeco(hint: 'Search product...', icon: Icons.search),
          ),
          if (_q.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: cardDeco(border: const Color(0xFFD5E4F7)),
              child: matches.isEmpty
                  ? Padding(padding: const EdgeInsets.all(12), child: Text('No matching product in Stocks.', style: ts(10, c: kMuted)))
                  : Column(children: [
                      for (final p in matches)
                        ListTile(
                          dense: true,
                          leading: ProductThumb(p, size: 30),
                          title: Text(p.name, style: ts(11, w: FontWeight.w600)),
                          trailing: Text(peso(p.price, decimals: true), style: ts(11, w: FontWeight.w700, c: kBlue)),
                          onTap: () => _addProduct(p),
                        ),
                    ]),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: cardDeco(border: const Color(0xFFD5E4F7)),
            child: Column(children: [
              Row(children: [
                Expanded(flex: 5, child: th('Items')),
                Expanded(flex: 4, child: th('Qty', a: TextAlign.center)),
                Expanded(flex: 2, child: th('Price', a: TextAlign.right)),
                Expanded(flex: 2, child: th('Total', a: TextAlign.right)),
                const SizedBox(width: 24),
              ]),
              const Divider(height: 14),
              if (_items.isEmpty)
                Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Search and tap a product to add it.', style: ts(10, c: kMuted))),
              for (var n = 0; n < _items.length; n++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(flex: 5, child: Text(_items[n].name, style: ts(9), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Expanded(
                      flex: 4,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        GestureDetector(
                          onTap: () => setState(() {
                            if (_items[n].qty > 1) _items[n].qty--;
                          }),
                          child: const Icon(Icons.remove_circle_outline, size: 16, color: kBlue),
                        ),
                        SizedBox(width: 22, child: Text('${_items[n].qty}', textAlign: TextAlign.center, style: ts(9, w: FontWeight.w700))),
                        GestureDetector(
                          onTap: () => setState(() => _items[n].qty++),
                          child: const Icon(Icons.add_circle_outline, size: 16, color: kBlue),
                        ),
                      ]),
                    ),
                    Expanded(flex: 2, child: Text(peso(_items[n].price), textAlign: TextAlign.right, style: ts(9))),
                    Expanded(flex: 2, child: Text(peso(_items[n].total), textAlign: TextAlign.right, style: ts(9))),
                    SizedBox(
                      width: 24,
                      child: GestureDetector(
                        onTap: () => setState(() => _items.removeAt(n)),
                        child: const Icon(Icons.delete_outline, size: 16, color: kRed),
                      ),
                    ),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: cardDeco(color: kBlueTint),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total Debt Amount', style: ts(10, w: FontWeight.w600)),
              Text(peso(_total, decimals: true), style: ts(18, w: FontWeight.w700, c: kBlue)),
            ]),
          ),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: AppField(label: 'Debt Date', controller: _debtDateC, hint: 'Date', icon: Icons.calendar_month_outlined, readOnly: true, onTap: _pickDebtDate),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppField(label: 'Due Date', controller: _dueDateC, hint: 'Date', icon: Icons.calendar_month_outlined, readOnly: true, onTap: _pickDue),
            ),
          ]),
          Row(children: [
            Expanded(child: AppButton('Unpaid', height: 36, outlined: _paid, onPressed: () => setState(() => _paid = false))),
            const SizedBox(width: 10),
            Expanded(child: AppButton('Paid', height: 36, outlined: !_paid, onPressed: () => setState(() => _paid = true))),
          ]),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}