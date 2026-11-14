import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/store.dart';
import '../data/subscription_service.dart';
import '../widgets/common.dart';
import 'auth_screens.dart' show AssetOrFallback;

const _freeBenefits = [
  'Basic sales recording', 'Limited sales record', 'Basic product listing',
  'Basic income tracking', 'Basic stock tracking', 'Basic daily summary'
];
const _premiumBenefits = [
  'Daily sales recording', 'Product and stock management', 'Income & expense tracking',
  'Estimated profit calculation', 'Customer credit tracking', 'Gcash cash-in / cash-out recording',
  'Payment transaction records', 'Monthly business summary'
];

Widget _benefit(String t, {Color c = kGreen}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.check_circle, size: 12, color: c),
        const SizedBox(width: 5),
        Expanded(child: Text(t, style: ts(8.5, h: 1.3))),
      ]),
    );

class _Payer {
  const _Payer(this.name, this.phone, this.email);
  final String name;
  final String phone;
  final String email;
}

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _ref = TextEditingController();
  XFile? _file;
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    subscription.ensureLoaded();
    _ref.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ref.dispose();
    super.dispose();
  }

  Future<void> _chooseSource() async {
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
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (src != null) await _pick(src);
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 85);
      if (x == null) return;
      final b = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _file = x;
        _bytes = b;
      });
    } catch (_) {
      if (mounted) snack(context, 'Unable to open the ${src == ImageSource.camera ? 'camera' : 'gallery'} on this device.');
    }
  }

  Future<void> _submit() async {
    final f = _file, b = _bytes;
    if (f == null || b == null) return;
    await subscription.verifyReceipt(path: f.path, bytes: b, reference: _ref.text);
  }

  Future<void> _start() async {
    final data = await showModalBottomSheet<_Payer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => const _PayerSheet(),
    );
    if (data == null || !mounted) return;
    await subscription.startPayment(fullName: data.name, phone: data.phone, email: data.email);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, subscription]),
      builder: (context, _) {
        final r = subscription.request;
        final Widget body;
        if (!subscription.loaded) {
          body = const Center(child: CircularProgressIndicator());
        } else if (subscription.verifying) {
          body = _verifying();
        } else if (r != null && r.status == PayStatus.active && !r.seen) {
          body = _success(r);
        } else if (store.plan == 'Premium') {
          body = _active(r);
        } else if (r != null && r.status == PayStatus.pending) {
          body = _upload(r);
        } else if (r != null && r.status == PayStatus.failed) {
          body = _failed(r);
        } else {
          body = _plans(r);
        }
        return BluePage(back: true, title: 'Subscription', child: body);
      },
    );
  }

  // ─────────────── Free plan / upgrade ───────────────
  Widget _plans(PaymentRequest? r) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (r != null && r.status == PayStatus.expired && r.expiresAt != null) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: cardDeco(color: kRedTint, border: kRed.withValues(alpha: 0.4), r: 12),
          child: Row(children: [
            const Icon(Icons.event_busy, color: kRed, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Your Premium plan expired on ${fmtDateLong(r.expiresAt!)}. Upgrade to renew.',
                  style: ts(10, w: FontWeight.w600, c: kRed, h: 1.5)),
            ),
          ]),
        ),
        const SizedBox(height: 12),
      ],
      Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDeco(color: kBlue, r: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const CircleAvatar(radius: 16, backgroundColor: Color(0x33FFFFFF), child: Icon(Icons.check, color: Colors.white, size: 18)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Current Plan', style: ts(9, c: Colors.white70)),
              Text('Free', style: ts(17, w: FontWeight.w700, c: Colors.white)),
            ]),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Text('Active', style: ts(9, w: FontWeight.w600, c: kBlue)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('Perfect for small businesses getting started.', style: ts(9, c: Colors.white)),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: cardDeco(border: const Color(0xFFE3ECF7)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Plan Benefits', style: ts(10, w: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(children: [for (final t in _freeBenefits.take(3)) _benefit(t)])),
            Expanded(child: Column(children: [for (final t in _freeBenefits.skip(3)) _benefit(t)])),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: cardDeco(border: const Color(0xFFE3ECF7)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Upgrade Your Plan', style: ts(10, w: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: cardDeco(color: kGreenTint, border: kGreen.withValues(alpha: 0.4), r: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: kBlueDark, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.workspace_premium, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Premium Plan', style: ts(13, w: FontWeight.w700, c: kBlue)),
                  Text('₱ 39 / Month', style: ts(10, w: FontWeight.w600, c: kBlue)),
                ]),
              ]),
              const SizedBox(height: 8),
              for (final t in _premiumBenefits) _benefit(t),
              const SizedBox(height: 10),
              Center(
                child: SizedBox(
                  width: 180,
                  child: AppButton('Upgrade Plan', height: 34, icon: Icons.workspace_premium, onPressed: _start),
                ),
              ),
            ]),
          ),
        ]),
      ),
    ]);
  }

  // ─────────────── Checking the receipt ───────────────
  Widget _verifying() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 54, height: 54, child: CircularProgressIndicator(strokeWidth: 4, color: kBlue)),
          const SizedBox(height: 20),
          Text('Checking your receipt…', style: ts(15, w: FontWeight.w700, c: kBlue)),
          const SizedBox(height: 6),
          Text('We are reading your receipt and checking the reference number. This can take a few seconds.',
              textAlign: TextAlign.center, style: ts(10, c: kMuted, h: 1.5)),
        ]),
      ),
    );
  }

  // ─────────────── Pay with QR, then upload the receipt ───────────────
  Widget _upload(PaymentRequest r) {
    final refReady = ReceiptValidator.digitsOf(_ref.text).length == 13;
    const steps = [
      'Open GCash, tap Pay QR and scan the code below. The amount is already set to ₱39.00.',
      'After paying, upload your GCash receipt or take a picture of your receipt.',
      'Type the Reference Number exactly as shown on the receipt (0000 000 000000).',
      'Tap Confirm Payment. We check that the receipt is a clear GCash receipt and the reference is correct.',
    ];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDeco(color: kBlueTint, border: kBlue.withValues(alpha: 0.35), r: 12),
        child: Row(children: [
          const Icon(Icons.qr_code_scanner, color: kBlue, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pay ₱39.00 then upload your receipt', style: ts(13, w: FontWeight.w700, c: kBlue)),
              Text('Premium unlocks after your receipt is checked.', style: ts(9.5, c: kBlueDark, h: 1.5)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDeco(border: const Color(0xFFD5E4F7)),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const GIcon(size: 20),
            const SizedBox(width: 6),
            Text('Scan to pay with GCash', style: ts(11, w: FontWeight.w700, c: kBlue)),
          ]),
          const SizedBox(height: 4),
          Text(peso(PaymentConfig.amount, decimals: true), style: ts(20, w: FontWeight.w700, c: kBlue)),
          const SizedBox(height: 10),
          AssetOrFallback(
            PaymentConfig.qrAsset,
            width: 200,
            height: 200,
            fallback: Container(
              width: 200,
              height: 200,
              decoration: cardDeco(color: kBlueTint, r: 10),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.qr_code_2, size: 80, color: kBlue.withValues(alpha: 0.5)),
                const SizedBox(height: 6),
                Text('Add assets/images/gcash_qr.png', style: ts(9, c: kMuted)),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Text(PaymentConfig.accountName, style: ts(12, w: FontWeight.w600, c: kBlue)),
          if (PaymentConfig.accountNumber.isNotEmpty) Text(PaymentConfig.accountNumber, style: ts(11, w: FontWeight.w500, c: kBlue)),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDeco(border: const Color(0xFFE3ECF7)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Payment Instructions', style: ts(11, w: FontWeight.w700)),
          const SizedBox(height: 8),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: kBlue, shape: BoxShape.circle),
                  child: Text('${i + 1}', style: ts(9, w: FontWeight.w700, c: Colors.white)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(steps[i], style: ts(10, h: 1.5))),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDeco(border: const Color(0xFFE3ECF7)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Upload Receipt', style: ts(11, w: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Upload your GCash receipt or take a picture of your receipt. The whole receipt must be visible, clear and readable, with the Reference Number shown.',
              style: ts(9, c: kMuted, h: 1.5)),
          const SizedBox(height: 10),
          if (_bytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(_bytes!, height: 220, width: double.infinity, fit: BoxFit.contain, gaplessPlayback: true),
            ),
            const SizedBox(height: 10),
          ],
          AppButton(_bytes == null ? 'Upload Receipt' : 'Replace Receipt',
              outlined: true, height: 40, icon: Icons.upload_file, onPressed: _chooseSource),
          const SizedBox(height: 14),
          AppField(
            label: 'Reference Number',
            controller: _ref,
            hint: '0000 000 000000',
            icon: Icons.confirmation_number_outlined,
            keyboard: TextInputType.number,
            formatters: [_RefFormatter()],
            validator: (_) => null,
            bottomGap: 4,
          ),
          Text('Enter the 13-digit reference exactly as shown on the GCash receipt.', style: ts(9, c: kMuted)),
        ]),
      ),
      const SizedBox(height: 14),
      AppButton('Confirm Payment', icon: Icons.verified_outlined, onPressed: (_bytes != null && refReady) ? _submit : null),
      if (_bytes == null || !refReady)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Center(child: Text('Upload your receipt and enter the reference number to continue.', style: ts(9, c: kMuted))),
        ),
      const SizedBox(height: 6),
      TextButton(
        onPressed: () async {
          final ok = await confirmDelete(context,
              title: 'Cancel this payment?',
              message: 'Your details and receipt for this request will be discarded.');
          if (ok) {
            setState(() {
              _file = null;
              _bytes = null;
              _ref.clear();
            });
            await subscription.reset();
          }
        },
        child: Text('Cancel payment', style: ts(11, w: FontWeight.w600, c: kRed)),
      ),
    ]);
  }

  // ─────────────── Payment failed ───────────────
  Widget _failed(PaymentRequest r) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      const SizedBox(height: 24),
      Center(
        child: Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle),
          child: const Icon(Icons.close, color: Colors.white, size: 46),
        ),
      ),
      const SizedBox(height: 14),
      Center(child: Text('Payment Failed', style: ts(18, w: FontWeight.w700, c: kRed))),
      const SizedBox(height: 10),
      Text(r.message ?? 'We could not verify your receipt.', textAlign: TextAlign.center, style: ts(11, h: 1.6)),
      const SizedBox(height: 6),
      Text('Premium was not activated.', textAlign: TextAlign.center, style: ts(10, c: kMuted)),
      const SizedBox(height: 24),
      AppButton('Try Again', onPressed: subscription.retry),
      const SizedBox(height: 8),
      AppButton('Cancel', outlined: true, onPressed: () async {
        setState(() {
          _file = null;
          _bytes = null;
          _ref.clear();
        });
        await subscription.reset();
      }),
    ]);
  }

  // ─────────────── Success ───────────────
  Widget _success(PaymentRequest r) {
    Widget row(String l, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [Text(l, style: ts(10)), const Spacer(), Text(v, style: ts(10, w: FontWeight.w600))]),
        );
    final when = r.startedAt ?? DateTime.now();
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
            Text('Payment Successful!', style: ts(18, w: FontWeight.w600, c: kBlue)),
            const SizedBox(height: 2),
            Text(peso(r.amount, decimals: true), style: ts(18, w: FontWeight.w700, c: kBlue)),
            const SizedBox(height: 4),
            Text('Premium Plan is now active', style: ts(11, w: FontWeight.w600, c: kGreen)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: const BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: Color(0xFFE3ECF7)))),
              child: Column(children: [
                row('Plan', 'Premium'),
                if (r.reference != null) row('Reference No.', formatRef(r.reference!)),
                row('Date', fmtDateLong(when)),
                row('Time', fmtTime(when)),
                row('Valid until', r.expiresAt == null ? '-' : fmtDateLong(r.expiresAt!)),
                row('Paid by', r.fullName),
              ]),
            ),
          ]),
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: AppButton('Done', height: 40, onPressed: subscription.markSeen),
        ),
      ),
    ]);
  }

  // ─────────────── Premium active ───────────────
  Widget _active(PaymentRequest? r) {
    final start = r?.startedAt ?? store.subscriptionStart ?? DateTime.now().subtract(const Duration(days: 30));
    final end = r?.expiresAt ?? store.subscriptionEnd ?? DateTime.now().add(const Duration(days: 30));
    final daysLeft = (end.difference(DateTime.now()).inHours / 24).ceil().clamp(0, 9999);
    Widget dateRow(IconData icon, String label, String value, {bool last = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFE3ECF7)))),
          child: Row(children: [
            Icon(icon, size: 16, color: kBlue),
            const SizedBox(width: 10),
            Text(label, style: ts(10)),
            const Spacer(),
            Text(value, style: ts(10.5, w: FontWeight.w700)),
          ]),
        );
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDeco(color: kBlue, r: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const CircleAvatar(radius: 16, backgroundColor: Color(0x33FFFFFF), child: Icon(Icons.workspace_premium, color: Colors.white, size: 18)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Current Plan', style: ts(9, c: Colors.white70)),
              Text('Premium', style: ts(17, w: FontWeight.w700, c: Colors.white)),
            ]),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Text('Active', style: ts(9, w: FontWeight.w600, c: kBlue)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('All premium features are unlocked.', style: ts(9, c: Colors.white)),
        ]),
      ),
      const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: cardDeco(border: const Color(0xFFD5E4F7)),
          child: Column(children: [
            dateRow(Icons.event_available, 'Start Date', fmtDateLong(start)),
            dateRow(Icons.event_busy, 'Expiry Date', fmtDateLong(end)),
            dateRow(Icons.hourglass_bottom, 'Days Remaining', '$daysLeft ${daysLeft == 1 ? 'day' : 'days'}', last: true),
          ]),
        ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: cardDeco(color: kGreenTint, border: kGreen.withValues(alpha: 0.4), r: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your Premium Benefits', style: ts(11, w: FontWeight.w700, c: kBlue)),
          const SizedBox(height: 6),
          for (final t in _premiumBenefits) _benefit(t),
        ]),
      ),
    ]);
  }
}

// ─────────────── Payer details modal ───────────────
class _PayerSheet extends StatefulWidget {
  const _PayerSheet();
  @override
  State<_PayerSheet> createState() => _PayerSheetState();
}

class _PayerSheetState extends State<_PayerSheet> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController(text: store.profile.ownerName);
  final _phone = TextEditingController(text: store.profile.phone);
  final _email = TextEditingController(text: store.account?.email ?? '');

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_key.currentState!.validate()) return;
    Navigator.pop(context, _Payer(_name.text.trim(), _phone.text.trim(), _email.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _key,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: kBlueDark, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.workspace_premium, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Premium Plan', style: ts(14, w: FontWeight.w700, c: kBlue)),
                  Text('₱39 / month • Pay via GCash', style: ts(10, c: kMuted)),
                ]),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20)),
            ]),
            const SizedBox(height: 14),
            AppField(label: 'Full Name', controller: _name, hint: 'Full name', icon: Icons.person_outline),
            AppField(label: 'Phone Number', controller: _phone, hint: 'Phone Number', icon: Icons.phone_outlined, keyboard: TextInputType.phone, validator: phoneError),
            AppField(label: 'Email Address', controller: _email, hint: 'Email Address', icon: Icons.mail_outline, keyboard: TextInputType.emailAddress, validator: emailError),
            AppButton('Proceed to Payment', onPressed: _submit),
            const SizedBox(height: 8),
            Center(
              child: Text('You will see the GCash QR code on the next screen.', style: ts(9, c: kMuted)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Formats the reference number as 0000 000 000000 while typing.
class _RefFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final d = newValue.text.replaceAll(RegExp(r'\D'), '');
    final t = d.length > 13 ? d.substring(0, 13) : d;
    final b = StringBuffer();
    for (var i = 0; i < t.length; i++) {
      if (i == 4 || i == 7) b.write(' ');
      b.write(t[i]);
    }
    final out = b.toString();
    return TextEditingValue(text: out, selection: TextSelection.collapsed(offset: out.length));
  }
}