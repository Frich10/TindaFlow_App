import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../widgets/common.dart';

const _catIcon = <String, IconData>{
  'Supplies': Icons.water_drop,
  'Utilities': Icons.settings,
  'Transportation': Icons.directions_bike,
  'Groceries': Icons.shopping_basket,
};
const _catColor = <String, Color>{
  'Supplies': kBlue,
  'Utilities': kGreen,
  'Transportation': kPurple,
  'Groceries': kRed,
};
const _catBg = <String, Color>{
  'Supplies': kBlueTint,
  'Utilities': kGreenTint,
  'Transportation': kPurpleTint,
  'Groceries': kRedTint,
};

const _paymentMethods = ['Cash', 'Gcash'];

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String? _cat;

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final list = store.expenses.where((e) => _cat == null || e.category == _cat).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      final total = list.fold<double>(0, (s, e) => s + e.amount);
      return BluePage(
        back: true,
        title: 'Expenses',
        fab: FloatingActionButton(
          backgroundColor: kGreen,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExpenseFormScreen())),
          child: const Icon(Icons.add),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: cardDeco(color: kOrangeTint, r: 12),
              child: Row(children: [

              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: kOrange,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/images/expense_icon.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                ),
              ),

                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_cat == null ? 'Total Expenses' : '$_cat Expenses', style: ts(10, w: FontWeight.w600, c: kOrange)),
                  Text(peso(total), style: ts(20, w: FontWeight.w700, c: kOrange)),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final c in kExpenseCategories)
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 32 - 10) / 2,
                  child: GestureDetector(
                    onTap: () => setState(() => _cat = _cat == c ? null : c),
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: _catBg[c],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _cat == c ? _catColor[c]! : _catColor[c]!.withValues(alpha: 0.3), width: _cat == c ? 1.6 : 1),
                      ),
                      child: Row(children: [
                        Icon(_catIcon[c], size: 14, color: _catColor[c]),
                        const SizedBox(width: 8),
                        Text(c, style: ts(10, w: FontWeight.w600, c: _catColor[c]!)),
                      ]),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 14),
            Text('Recent Expenses', style: ts(12, w: FontWeight.w700, c: kBlue)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: cardDeco(border: const Color(0xFFE3ECF7)),
              child: list.isEmpty
                  ? const EmptyState(Icons.receipt_long, 'No expenses yet.\nTap + to add one.')
                  : Column(children: [
                      for (final e in list)
                        InkWell(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExpenseDetailScreen(expenseId: e.id))),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Row(children: [
                              CircleIcon(_catIcon[e.category] ?? Icons.receipt_long, color: _catColor[e.category] ?? kBlue, size: 30),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(e.name, style: ts(11, w: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(fmtDateTime(e.date), style: ts(8.5, c: kMuted)),
                                ]),
                              ),
                              Text(peso(e.amount), style: ts(12, w: FontWeight.w700, c: kRed)),
                            ]),
                          ),
                        ),
                    ]),
            ),
          ],
        ),
      );
    });
  }
}

// ───────────────────────── Expense details ─────────────────────────

class ExpenseDetailScreen extends StatelessWidget {
  const ExpenseDetailScreen({super.key, required this.expenseId});
  final String expenseId;

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final e = store.expenseById(expenseId);
      if (e == null) {
        return const BluePage(back: true, title: 'Expense Details', child: EmptyState(Icons.receipt_long, 'This expense no longer exists.'));
      }
      return BluePage(
        back: true,
        title: 'Expense Details',
        actions: [
          HeaderIcon(Icons.edit, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExpenseFormScreen(expense: e)))),
          HeaderIcon(Icons.delete_outline, onTap: () async {
            final ok = await confirmDelete(context);
            if (ok && context.mounted) {
              store.deleteExpense(e.id);
              snack(context, 'Expense deleted');
              Navigator.of(context).pop();
            }
          }),
        ],
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: cardDeco(border: const Color(0xFFD5E4F7)),
              child: Row(children: [
                CircleIcon(_catIcon[e.category] ?? Icons.receipt_long, color: _catColor[e.category] ?? kBlue, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.name, style: ts(12, w: FontWeight.w700, c: kBlue)),
                    Text(peso(e.amount, decimals: true), style: ts(13, w: FontWeight.w700)),
                  ]),
                ),
                StatusChip(e.category, color: _catColor[e.category] ?? kBlue, bg: _catBg[e.category] ?? kBlueTint),
              ]),
            ),
            const SizedBox(height: 14),
            Text('Transaction Information', style: ts(11, w: FontWeight.w700)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: cardDeco(border: const Color(0xFFD5E4F7)),
              child: Column(children: [
                _Row(Icons.calendar_month, 'Date', fmtDate(e.date)),
                _Row(Icons.access_time, 'Time', fmtTime(e.date)),
                _Row(Icons.account_balance_wallet_outlined, 'Payment Method', e.method),
                _Row(Icons.notes, 'Notes', e.notes.isEmpty ? '—' : e.notes, last: true),
              ]),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: cardDeco(color: kBlueTint),
              child: Row(children: [
                const Icon(Icons.info_outline, color: kBlue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('This expense helps you track your business costs and manage your profit more effectively.',
                      style: ts(9.5, c: kBlue, h: 1.5)),
                ),
              ]),
            ),
          ],
        ),
      );
    });
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label, this.value, {this.last = false});
  final IconData icon;
  final String label;
  final String value;
  final bool last;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFE3ECF7)))),
      child: Row(children: [
        Icon(icon, size: 16, color: kBlue),
        const SizedBox(width: 10),
        Text(label, style: ts(10)),
        const SizedBox(width: 12),
        Expanded(child: Text(value, textAlign: TextAlign.right, style: ts(10, w: FontWeight.w700))),
      ]),
    );
  }
}

// ───────────────────────── Add / edit expense ─────────────────────────

class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key, this.expense});
  final Expense? expense;
  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.expense?.name ?? '');
  late final _amount = TextEditingController(
      text: widget.expense == null ? '' : widget.expense!.amount.toStringAsFixed(widget.expense!.amount == widget.expense!.amount.roundToDouble() ? 0 : 2));
  late final _notes = TextEditingController(text: widget.expense?.notes ?? '');
  late final _dateC = TextEditingController();
  late final _timeC = TextEditingController();
  String? _category;
  String? _method;
  late DateTime _date;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _category = e?.category;
    _method = e?.method;
    _date = e?.date ?? DateTime.now();
    _time = TimeOfDay.fromDateTime(_date);
    _dateC.text = fmtDate(_date);
    _timeC.text = fmtTimeOfDay(_time);
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _notes.dispose();
    _dateC.dispose();
    _timeC.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await pickDate(context, _date);
    if (d != null) {
      setState(() {
        _date = d;
        _dateC.text = fmtDate(d);
      });
    }
  }

  Future<void> _pickTime() async {
    final t = await pickTime(context, _time);
    if (t != null) {
      setState(() {
        _time = t;
        _timeC.text = fmtTimeOfDay(t);
      });
    }
  }

  void _save() {
    if (!_key.currentState!.validate()) return;
    final old = widget.expense;
    final e = Expense(
      id: old?.id ?? newId(),
      name: _name.text.trim(),
      category: _category!,
      amount: parseMoney(_amount.text),
      method: _method!,
      date: combine(_date, _time),
      notes: _notes.text.trim(),
    );
    if (old == null) {
      store.addExpense(e);
    } else {
      store.updateExpense(e);
    }
    snack(context, old == null ? 'Expense added' : 'Expense updated');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.expense != null;
    return BluePage(
      back: true,
      title: editing ? 'Edit Expense' : 'Add Expense',
      child: FormBody(
        formKey: _key,
        button: AppButton('Save', onPressed: _save),
        children: [
          AppField(label: 'Expense Name', controller: _name, hint: 'Expense Name'),
          AppDropdown(label: 'Category', hint: 'Select Category', items: kExpenseCategories, value: _category, onChanged: (v) => setState(() => _category = v)),
          AppField(label: 'Amount', controller: _amount, hint: 'Amount', prefixText: '₱', keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: moneyFormatters, validator: moneyError),
          AppDropdown(label: 'Payment Method', hint: 'Payment Method', items: _paymentMethods, value: _method, onChanged: (v) => setState(() => _method = v)),
          fieldLabel('Date', true),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: AppField(label: 'Date', showLabel: false, controller: _dateC, hint: 'Date', icon: Icons.calendar_month_outlined, readOnly: true, onTap: _pickDate)),
            const SizedBox(width: 10),
            Expanded(child: AppField(label: 'Time', showLabel: false, controller: _timeC, hint: 'Time', icon: Icons.access_time, readOnly: true, onTap: _pickTime)),
          ]),
          AppField(label: 'Notes (Optional)', controller: _notes, hint: 'Enter notes...', required: false, maxLines: 2),
        ],
      ),
    );
  }
}
