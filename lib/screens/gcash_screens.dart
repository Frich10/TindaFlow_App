import 'dart:math';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/gcash_receipt_reader.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../data/web_download.dart'
    if (dart.library.html) '../data/web_download_web.dart';
import '../widgets/common.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Gcash records â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class GcashScreen extends StatefulWidget {
  const GcashScreen({super.key});
  @override
  State<GcashScreen> createState() => _GcashScreenState();
}

class _GcashScreenState extends State<GcashScreen> {
  String _q = '';
  int _tab = 0;

  Future<void> _editOpening() async {
    final c = TextEditingController(text: store.gcashOpening.toStringAsFixed(0));
    await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: Text('Starting GCash balance', style: ts(15, w: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('The wallet balance before your first recorded transaction. Cash-outs add to it, cash-ins subtract from it.', style: ts(10, c: kMuted)),
          const SizedBox(height: 12),
          TextField(
            controller: c,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: moneyFormatters,
            decoration: fieldDeco(prefixText: '₱'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, parseMoney(c.text)), child: const Text('Save')),
          ],
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final list = store.gcash.where((g) {
        if (_tab == 1 && !g.isIn) return false;
        if (_tab == 2 && g.isIn) return false;
        final q = _q.toLowerCase();
        return q.isEmpty || g.name.toLowerCase().contains(q) || g.ref.toLowerCase().contains(q);
      }).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return BluePage(
        back: true,
        title: 'Gcash Records',
        actions: [HeaderIcon(Icons.description_outlined, onTap: () => Navigator.of(context).push(AppPageRoute(builder: (_) => const GcashReportScreen())))],
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: GestureDetector(
              onTap: _editOpening,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: cardDeco(color: kBlue, r: 12),
                child: Row(children: [
                  
                Image.asset(
                  'assets/images/gcash_logo1.png',
                  width: 54,
                  height: 44,
                  fit: BoxFit.contain,
                ),

                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Gcash Balance', style: ts(10, w: FontWeight.w600, c: Colors.white)),
                      Text(peso(store.gcashBalance), style: ts(20, w: FontWeight.w700, c: Colors.white)),
                    ]),
                  ),
                  const Icon(Icons.account_balance_wallet, color: Colors.white, size: 30),
                ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(children: [
              Expanded(child: SearchBox(onChanged: (v) => setState(() => _q = v))),
              const SizedBox(width: 10),
              CircleAdd(size: 34, onTap: () => Navigator.of(context).push(AppPageRoute(builder: (_) => const GcashFormScreen()))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: SegmentTabs(options: const ['All', 'Cash In', 'Cash Out'], selected: _tab, onChanged: (v) => setState(() => _tab = v)),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(Icons.account_balance_wallet_outlined, 'No GCash records yet.\nTap + to record one.')
                : Refreshable(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final g = list[i];
                        final c = g.isIn ? kRed : kGreen;
                        return InkWell(
                          onTap: () => Navigator.of(context).push(AppPageRoute(builder: (_) => GcashDetailScreen(txId: g.id))),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE3ECF7)))),
                            child: Row(children: [
                              CircleIcon(g.isIn ? Icons.arrow_downward : Icons.arrow_upward, color: c, size: 30),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(g.name, style: ts(11, w: FontWeight.w700)),
                                  Text(fmtDateTime(g.date), style: ts(8, c: kMuted)),
                                  Text('Ref: ${g.ref}', style: ts(8, c: kMuted)),
                                ]),
                              ),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text('${g.isIn ? '-' : '+'} ${peso(g.amount)}', style: ts(12, w: FontWeight.w700, c: c)),
                                const SizedBox(height: 3),
                                StatusChip(g.type, color: c, bg: g.isIn ? kRedTint : kGreenTint),
                              ]),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ]),
      );
    });
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Transaction details â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class GcashDetailScreen extends StatelessWidget {
  const GcashDetailScreen({super.key, required this.txId});
  final String txId;

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final g = store.gcashById(txId);
      if (g == null) {
        return const BluePage(back: true, title: 'Transaction Details', child: EmptyState(Icons.receipt_long, 'This transaction no longer exists.'));
      }
      final c = g.isIn ? kRed : kGreen;
      return BluePage(
        back: true,
        title: 'Transaction Details',
        actions: [
          HeaderIcon(Icons.edit, onTap: () => Navigator.of(context).push(AppPageRoute(builder: (_) => GcashFormScreen(tx: g)))),
          HeaderIcon(Icons.delete_outline, onTap: () async {
            final ok = await confirmDelete(context);
            if (ok && context.mounted) {
              store.deleteGcash(g.id);
              snack(context, 'Transaction deleted');
              Navigator.of(context).pop();
            }
          }),
        ],
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: cardDeco(shadow: true, r: 12),
              child: Row(children: [
                CircleIcon(g.isIn ? Icons.arrow_downward : Icons.arrow_upward, color: c, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    StatusChip(g.type, color: c, bg: g.isIn ? kRedTint : kGreenTint),
                    const SizedBox(height: 4),
                    Text(peso(g.amount), style: ts(18, w: FontWeight.w700, c: kBlue)),
                  ]),
                ),
                const StatusChip('Completed ✓'),
              ]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: cardDeco(r: 12),
              child: Column(children: [
                InfoRow(Icons.person, 'Customer Name', g.name),
                InfoRow(Icons.smartphone, 'Mobile Number', g.phone),
                InfoRow(Icons.payments_outlined, 'Amount', peso(g.amount, decimals: false)),
                InfoRow(Icons.balance, 'Charge / Fee', peso(g.fee)),
                InfoRow(Icons.calendar_month, 'Date', fmtDate(g.date)),
                InfoRow(Icons.access_time, 'Time', fmtTime(g.date)),
                InfoRow(Icons.confirmation_number_outlined, 'Reference Number', g.ref, last: true),
              ]),
            ),
          ],
        ),
      );
    });
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Record / edit â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class GcashFormScreen extends StatefulWidget {
  const GcashFormScreen({super.key, this.tx});
  final GcashTx? tx;
  @override
  State<GcashFormScreen> createState() => _GcashFormScreenState();
}

class _GcashFormScreenState extends State<GcashFormScreen> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.tx?.name ?? '');
  late final _phone = TextEditingController(text: widget.tx?.phone ?? '');
  late final _amount = TextEditingController(text: widget.tx == null ? '' : _n(widget.tx!.amount));
  late final _fee = TextEditingController(text: widget.tx == null ? '' : _n(widget.tx!.fee));
  late final _ref = TextEditingController(text: widget.tx?.ref ?? '');
  final _dateC = TextEditingController();
  final _timeC = TextEditingController();
  String? _type;
  late DateTime _date;
  late TimeOfDay _time;

  static String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    _type = widget.tx?.type;
    _date = widget.tx?.date ?? DateTime.now();
    _time = TimeOfDay.fromDateTime(_date);
    _dateC.text = fmtDate(_date);
    _timeC.text = fmtTimeOfDay(_time);
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _amount, _fee, _ref, _dateC, _timeC]) {
      c.dispose();
    }
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
    final old = widget.tx;
    final t = GcashTx(
      id: old?.id ?? newId(),
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      amount: parseMoney(_amount.text),
      fee: parseMoney(_fee.text),
      type: _type!,
      date: combine(_date, _time),
      ref: _ref.text.trim(),
    );
    if (old == null) {
      store.addGcash(t);
    } else {
      store.updateGcash(t);
    }
    snack(context, old == null ? 'Transaction recorded' : 'Transaction updated');
    Navigator.of(context).pop();
  }

  bool _scanning = false;

  Future<void> _scanReceipt() async {
    if (_scanning) return;
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Upload from gallery'),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (src == null || !mounted) return;
    XFile? x;
    try {
      x = await ImagePicker().pickImage(
        source: src,
        maxWidth: 2400,
        maxHeight: 4000,
        imageQuality: 95,
      );
    } catch (_) {
      if (mounted) snack(context, 'Unable to open the ${src == ImageSource.camera ? 'camera' : 'gallery'} on this device.');
      return;
    }
    if (x == null || !mounted) return;

    setState(() => _scanning = true);
    GcashScanResult? result;
    String? error;
    try {
      final bytes = await x.readAsBytes();
      result = await GcashReceiptReader.scan(path: x.path, bytes: bytes);
      // Reject anything that is not a GCash / e-wallet receipt. Check the raw
      // OCR text, not just the parsed fields: a photo with no readable text at
      // all must be rejected too.
      final rawText = result.text;
      if (rawText.trim().length < 20) {
        error = 'This does not look like a receipt, or it is too blurry to read. Please try a clearer photo.';
        result = null;
      } else if (!GcashReceiptReader.isGcashReceipt(rawText)) {
        error = 'This is not a receipt, please upload a gcash receipt';
        result = null;
      }
    } catch (_) {
      error = 'Could not read the receipt. Please try a clearer photo, or type the details manually.';
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
    if (!mounted || result == null) {
      if (mounted && error != null) snack(context, error);
      return;
    }
    _applyScan(result);
  }

  void _applyScan(GcashScanResult r) {
    final missed = <String>[];
    setState(() {
      if (r.amount != null && r.amount! > 0) _amount.text = _n(r.amount!);
      if (r.fee != null && r.fee! > 0) _fee.text = _n(r.fee!);
      // Gcash Type is intentionally NOT set from the scan — the user must pick
      // it manually so a misread receipt can't silently choose the wrong type.
      if (r.reference != null) {
        final d = r.reference!.replaceAll(RegExp(r'\D'), '');
        final t = d.length > 13 ? d.substring(0, 13) : d;
        final b = StringBuffer();
        for (var i = 0; i < t.length; i++) {
          if (i == 4 || i == 7) b.write(' ');
          b.write(t[i]);
        }
        _ref.text = b.toString();
      }
      if (r.date != null) {
        _date = r.date!;
        _dateC.text = fmtDate(_date);
      }
      if (r.hour != null && r.minute != null) {
        _time = TimeOfDay(hour: r.hour!, minute: r.minute!);
        _timeC.text = fmtTimeOfDay(_time);
      }
      if (r.name != null && r.name!.trim().isNotEmpty) {
        _name.text = r.name!.trim();
      } else {
        missed.add('Customer Name');
      }
      if (r.phone != null && r.phone!.trim().isNotEmpty) {
        _phone.text = r.phone!.trim();
      } else {
        missed.add('Mobile Number');
      }
    });
    if (missed.isEmpty) {
      snack(context, 'Receipt scanned. Review the details before saving.');
    } else {
      snack(
        context,
        'Scanned, but ${missed.join(' and ')} could not be read (the receipt may be blurry). Please enter ${missed.length == 1 ? 'it' : 'them'} manually.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.tx != null;
    return BluePage(
      back: true,
      title: editing ? 'Edit Transaction' : 'Record Gcash Transaction',
      actions: editing
          ? const []
          : [
              HeaderIcon(
                _scanning ? Icons.hourglass_empty : Icons.document_scanner_outlined,
                onTap: _scanning ? null : _scanReceipt,
              ),
            ],
      child: FormBody(
        formKey: _key,
        button: AppButton('Save', onPressed: _save),
        children: [
          AppField(label: 'Name', controller: _name, hint: 'Customer name', icon: Icons.person),
          AppField(label: 'Phone Number', controller: _phone, hint: 'Phone Number', icon: Icons.phone_outlined, keyboard: TextInputType.phone, formatters: gcashPhoneFormatters, validator: phoneError),
          AppField(label: 'Amount', controller: _amount, hint: 'Amount', prefixText: '₱', keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: moneyFormatters, validator: moneyError),
          AppField(label: 'Charge / Fee', controller: _fee, hint: 'Charge / Fee', prefixText: '₱', keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: moneyFormatters, validator: (v) => moneyError(v, allowZero: true)),
          AppDropdown(label: 'Gcash Type', hint: 'Gcash Type', items: const [kCashIn, kCashOut], value: _type, onChanged: (v) => setState(() => _type = v)),
          fieldLabel('Date', true),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: AppField(label: 'Date', showLabel: false, controller: _dateC, hint: 'Date', icon: Icons.calendar_month_outlined, readOnly: true, onTap: _pickDate)),
            const SizedBox(width: 10),
            Expanded(child: AppField(label: 'Time', showLabel: false, controller: _timeC, hint: 'Time', icon: Icons.access_time, readOnly: true, onTap: _pickTime)),
          ]),
          AppField(label: 'Reference Number', controller: _ref, hint: 'Reference Number', keyboard: TextInputType.number, formatters: refFormatters),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Cash flow report â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

enum _Period { today, week, month, year }

class GcashReportScreen extends StatefulWidget {
  const GcashReportScreen({super.key});
  @override
  State<GcashReportScreen> createState() => _GcashReportScreenState();
}

class _GcashReportScreenState extends State<GcashReportScreen> {
  _Period _p = _Period.today;
  static const _labels = ['Today', 'This Week', 'This Month', 'This Year'];

  DateTime get _start {
    final now = DateTime.now();
    switch (_p) {
      case _Period.today:
        return dayStart(now);
      case _Period.week:
        return dayStart(now).subtract(const Duration(days: 6));
      case _Period.month:
        return DateTime(now.year, now.month, 1);
      case _Period.year:
        return DateTime(now.year, 1, 1);
    }
  }

  bool _inRange(DateTime d) => !d.isBefore(_start) && !d.isAfter(DateTime.now().add(const Duration(days: 1)));

  List<String> get _xLabels {
    switch (_p) {
      case _Period.today:
        return ['12a', '4a', '8a', '12p', '4p', '8p'];
      case _Period.week:
        const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final s = _start;
        return List.generate(7, (i) => w[s.add(Duration(days: i)).weekday - 1]);
      case _Period.month:
        return ['1-5', '6-10', '11-15', '16-20', '21-25', '26+'];
      case _Period.year:
        return List.generate(12, (i) => fmtMonth(i + 1));
    }
  }

  int _bucket(DateTime d) {
    switch (_p) {
      case _Period.today:
        return min(5, d.hour ~/ 4);
      case _Period.week:
        return dayStart(d).difference(_start).inDays.clamp(0, 6).toInt();
      case _Period.month:
        return min(5, (d.day - 1) ~/ 5);
      case _Period.year:
        return d.month - 1;
    }
  }

  bool _downloading = false;

  pw.Widget _pdfSummaryRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
          pw.Spacer(),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ]),
      );

  /// Builds a PDF of the current period's GCash transactions and opens the
  /// share sheet so the user can save/download it.
  Future<void> _downloadPdf(List<GcashTx> txs, double totalIn, double totalOut, double fees) async {
    if (_downloading) return;
    if (txs.isEmpty) {
      snack(context, 'No transactions to export for this period.');
      return;
    }
    setState(() => _downloading = true);
    try {
      // Load a Unicode font so the peso sign (₱) renders in the PDF.
      final regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
      );
      final bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
      );
      final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
      final periodLabel = _labels[_p.index];
      final generated = DateTime.now();

      final dataRows = txs.toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      pw.TextStyle base(double size, {bool bold = false, PdfColor? color}) =>
          pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : null, color: color);

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          header: (context) => context.pageNumber == 1
              ? pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('TindaFlow - GCash Cash Flow Report',
                      style: base(18, bold: true)),
                  pw.SizedBox(height: 4),
                  pw.Text('Period: $periodLabel',
                      style: base(11, color: PdfColors.grey700)),
                  pw.Text('Generated: ${fmtDateLong(generated)} ${fmtTime(generated)}',
                      style: base(10, color: PdfColors.grey600)),
                  pw.SizedBox(height: 10),
                ])
              : pw.SizedBox(),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                style: base(9, color: PdfColors.grey)),
          ),
          build: (context) => [
            // Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                _pdfSummaryRow('Total Cash In', peso(totalIn)),
                _pdfSummaryRow('Total Cash Out', peso(totalOut)),
                _pdfSummaryRow('Total Charges / Fees', peso(fees)),
              ]),
            ),
            pw.SizedBox(height: 14),
            pw.Text('Transactions', style: base(13, bold: true)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: const ['Date', 'Time', 'Name', 'Type', 'Amount', 'Fee', 'Reference'],
              data: [
                for (final t in dataRows)
                  [
                    fmtDate(t.date),
                    fmtTime(t.date),
                    t.name,
                    t.isIn ? 'Cash In' : 'Cash Out',
                    peso(t.amount, decimals: true),
                    peso(t.fee, decimals: true),
                    t.ref,
                  ],
              ],
              headerStyle: base(9, bold: true),
              cellStyle: base(8),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerLeft,
              },
              cellHeight: 16,
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      if (kIsWeb) {
        // Web: trigger a browser download via an anchor element.
        await _downloadOnWeb(bytes, 'gcash_report_${periodLabel.replaceAll(' ', '_')}.pdf');
        if (mounted) snack(context, 'PDF downloaded.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/gcash_report_${periodLabel.replaceAll(' ', '_')}.pdf');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'GCash Cash Flow Report - $periodLabel'),
      );
    } catch (e) {
      if (mounted) snack(context, 'Could not create PDF: $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final txs = store.gcash.where((g) => _inRange(g.date)).toList();
      final n = _xLabels.length;
      final ins = List<double>.filled(n, 0);
      final outs = List<double>.filled(n, 0);
      var totalIn = 0.0, totalOut = 0.0, fees = 0.0;
      for (final g in txs) {
        final b = _bucket(g.date);
        if (g.isIn) {
          ins[b] += g.amount;
          totalIn += g.amount;
        } else {
          outs[b] += g.amount;
          totalOut += g.amount;
        }
        fees += g.fee;
      }
      return BluePage(
        back: true,
        title: 'Cash Flow Report',
        actions: [
          HeaderIcon(
            _downloading ? Icons.hourglass_empty : Icons.download_outlined,
            onTap: _downloading ? null : () => _downloadPdf(txs, totalIn, totalOut, fees),
          ),
        ],
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Row(children: [
              for (var i = 0; i < _Period.values.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _p = _Period.values[i]),
                      child: Container(
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _p == _Period.values[i] ? kBlue : const Color(0xFFDDF5EA),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(_labels[i],
                            style: ts(9, w: FontWeight.w600, c: _p == _Period.values[i] ? Colors.white : kBlue)),
                      ),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Total(Icons.arrow_downward, 'Total Cash In', peso(totalIn), kRed, kRedTint)),
              const SizedBox(width: 10),
              Expanded(child: _Total(Icons.arrow_upward, 'Total Cash Out', peso(totalOut), kGreen, kGreenTint)),
            ]),
            const SizedBox(height: 10),
            _Total(Icons.arrow_upward, 'Total Charges / Fees', peso(fees), kBlue, kBlueTint, wide: true),
            const SizedBox(height: 14),
            Text('Transaction Report', style: ts(11, w: FontWeight.w700, c: kBlue)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              decoration: cardDeco(r: 10),
              child: Column(children: [
                Row(children: [
                  const _Dot(kRed),
                  const SizedBox(width: 4),
                  Text('Cash In', style: ts(8)),
                  const SizedBox(width: 10),
                  const _Dot(kGreen),
                  const SizedBox(width: 4),
                  Text('Cash Out', style: ts(8)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: kGreenTint, borderRadius: BorderRadius.circular(6)),
                    child: Text(_labels[_p.index], style: ts(8, w: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 10),
                SizedBox(
                  height: 190,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _BarPainter(_xLabels, ins, outs),
                  ),
                ),
              ]),
            ),
          ],
        ),
      );
    });
  }

  /// Triggers a browser download on Flutter web.
  Future<void> _downloadOnWeb(Uint8List bytes, String filename) async {
    await downloadBytesOnWeb(bytes, filename);
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _Total extends StatelessWidget {
  const _Total(this.icon, this.label, this.value, this.color, this.bg, {this.wide = false});
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;
  final bool wide;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(10),
      decoration: cardDeco(color: bg, border: color.withValues(alpha: 0.5)),
      child: Row(children: [
        CircleIcon(icon, color: color, size: 26),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: ts(9, w: FontWeight.w600, c: color)),
            Text(value, style: ts(15, w: FontWeight.w700, c: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.labels, this.a, this.b);
  final List<String> labels;
  final List<double> a; // cash in
  final List<double> b; // cash out

  double _niceMax(double m) {
    if (m <= 0) return 100;
    final e = pow(10, (log(m) / ln10).floor()).toDouble();
    final f = m / e;
    final nf = f <= 1 ? 1.0 : (f <= 2 ? 2.0 : (f <= 4 ? 4.0 : (f <= 8 ? 8.0 : 10.0)));
    return nf * e;
  }

  void _text(Canvas canvas, String s, Offset at, {TextAlign align = TextAlign.right, double w = 40}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: 8, color: kMuted)),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: w, maxWidth: w);
    tp.paint(canvas, at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 44.0, bottom = 18.0;
    final plotW = size.width - left;
    final plotH = size.height - bottom;
    final top = [...a, ...b, 0.0].reduce(max);
    final maxV = _niceMax(top);
    final grid = Paint()
      ..color = const Color(0xFFE3ECF7)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = plotH - plotH * i / 4;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), grid);
      _text(canvas, peso(maxV * i / 4), Offset(0, y - 5), w: left - 6);
    }
    final n = labels.length;
    final slot = plotW / n;
    final barW = min(10.0, slot * 0.32);
    final pa = Paint()..color = kRed;
    final pb = Paint()..color = kGreen;
    for (var i = 0; i < n; i++) {
      final cx = left + slot * i + slot / 2;
      final ha = plotH * (a[i] / maxV);
      final hb = plotH * (b[i] / maxV);
      canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTWH(cx - barW - 1, plotH - ha, barW, ha), topLeft: const Radius.circular(2), topRight: const Radius.circular(2)), pa);
      canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTWH(cx + 1, plotH - hb, barW, hb), topLeft: const Radius.circular(2), topRight: const Radius.circular(2)), pb);
      _text(canvas, labels[i], Offset(cx - slot / 2, plotH + 4), align: TextAlign.center, w: slot);
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => true;
}
