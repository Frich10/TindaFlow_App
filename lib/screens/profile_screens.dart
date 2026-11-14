import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../widgets/common.dart';
import 'about_screens.dart';
import 'auth_screens.dart';
import 'subscription_screens.dart';

// ───────────────────────── Profile tab ─────────────────────────

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Log out?', style: ts(15, w: FontWeight.w700)),
        content: Text('You will need to log in again to use TindaFlow.', style: ts(11)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    store.logout();
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
  }

  void _go(BuildContext context, Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final p = store.profile;
      final name = p.ownerName.isEmpty ? 'Store Owner' : p.ownerName;
      return BluePage(
        header: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 8, 26),
          child: Row(children: [
            Stack(children: [
            Builder(
              builder: (context) {
                final photo = store.profile.photo;

                if (photo != null && photo.isNotEmpty) {
                  return ClipOval(
                    child: Image.memory(
                      decodeImg(photo),
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  );
                }

                return Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 35,
                  ),
                );
              },
            ),
            
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: kGreen, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                ),
              ),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: ts(15, w: FontWeight.w700, c: Colors.white)),
                Text('${p.businessType} Owner', style: ts(10, c: Colors.white70)),
              ]),
            ),
            HeaderIcon(Icons.edit, onTap: () => _go(context, const ProfileFormScreen(mode: ProfileMode.account))),
          ]),
        ),
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              children: [
                _Tile(Icons.badge_outlined, 'Business Information', () => _go(context, const ProfileFormScreen(mode: ProfileMode.business))),
                _Tile(Icons.settings_outlined, 'Account Settings', () => _go(context, const ProfileFormScreen(mode: ProfileMode.account))),
                _Tile(Icons.qr_code_scanner, 'Gcash QR Code', () => _go(context, const GcashQrScreen())),
                _Tile(Icons.monetization_on_outlined, 'Subscription', () => _go(context, const SubscriptionScreen())),
                _Tile(Icons.info_outline, 'About TindaFlow', () => _go(context, const AboutScreen())),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: _Tile(Icons.logout, 'Logout', () => _logout(context)),
            ),
          ),
        ]),
      );
    });
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.title, this.onTap);
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: cardDeco(color: Colors.transparent, border: const Color(0xFFD5E4F7)),
            child: Row(children: [
              Icon(icon, size: 20, color: kBlueDark),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: ts(11, w: FontWeight.w600)),
              ),
              const Icon(Icons.chevron_right, size: 18, color: kBlueDark),
            ]),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Edit profile / business info / account ─────────────────────────

enum ProfileMode { edit, business, account }

class ProfileFormScreen extends StatefulWidget {
  const ProfileFormScreen({super.key, required this.mode});
  final ProfileMode mode;
  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _key = GlobalKey<FormState>();
  final _owner = TextEditingController(text: store.profile.ownerName);
  final _store = TextEditingController(text: store.profile.storeName);
  final _phone = TextEditingController(text: store.profile.phone);
  final _addr = TextEditingController(text: store.profile.address);
  final _city = TextEditingController(text: store.profile.city);
  final _province = TextEditingController(text: store.profile.province);
  final _postalCode = TextEditingController(text: store.profile.postalCode);
  final _tin = TextEditingController(text: store.profile.tinNumber);
  final _email = TextEditingController(text: store.account?.email ?? '');
  final _dob = TextEditingController(text: store.account?.dateOfBirth ?? '');
  final _gender = TextEditingController(text: store.account?.gender ?? '');
  final _customBusinessType = TextEditingController();
  late String _type = kBusinessTypes.contains(store.profile.businessType) ? store.profile.businessType : kBusinessTypes.first;

  @override
  void dispose() {
    for (final c in [_owner, _store, _phone, _addr, _city, _province, _postalCode, _tin, _email, _dob, _gender, _customBusinessType]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_key.currentState!.validate()) return;
    final p = store.profile;
    p.storeName = _store.text.trim();
    p.businessType = _type == 'Others' ? _customBusinessType.text.trim() : _type;
    p.phone = _phone.text.trim();
    p.address = _addr.text.trim();
    p.city = _city.text.trim();
    p.province = _province.text.trim();
    p.postalCode = _postalCode.text.trim();
    p.tinNumber = _tin.text.trim();
    if (widget.mode != ProfileMode.account) {
      p.ownerName = _owner.text.trim();
    } else {
      store.updateEmail(_email.text);
      if (store.account != null) {
        store.account!.dateOfBirth = _dob.text.trim().isEmpty ? null : _dob.text.trim();
        store.account!.gender = _gender.text.trim().isEmpty ? null : _gender.text.trim();
      }
    }
    store.saveProfile();
    snack(context, 'Saved');
    Navigator.of(context).pop();
  }

  Future<void> _clearData() async {
    final ok = await confirmDelete(context,
        title: 'Reset all data to zero?',
        message: 'This removes every product, sale, debt, expense and GCash record both locally and in Firebase. Your account stays.');
    if (ok && mounted) {
      await store.clearAllData();
      if (mounted) snack(context, 'All business data reset to zero');
    }
  }

  Future<void> _changePhoto() async {
    final b = await pickImageBase64(context, maxWidth: 400);
    if (b != null) {
      store.profile.photo = b;
      store.saveProfile();
      setState(() {});
    }
  }

  Future<void> _pickDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      controller.text = picked.toIso8601String().split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mode;
    final title = switch (m) {
      ProfileMode.edit => 'Edit Profile',
      ProfileMode.business => 'Business Information',
      ProfileMode.account => 'Account Settings',
    };
    final typeDropdown = AppDropdown(
      label: 'Type of Business',
      items: kBusinessTypes,
      value: _type,
      onChanged: (v) => setState(() => _type = v ?? _type),
      bottomGap: 6,
    );
    final phone = AppField(label: 'Phone Number', controller: _phone, hint: '09XXXXXXXXX', icon: null, keyboard: TextInputType.phone, validator: phoneError, bottomGap: 6);
    final addr = AppField(label: 'Business Address', controller: _addr, hint: 'Store address', icon: Icons.location_on, maxLines: 2, bottomGap: 6);
    final city = AppField(label: 'City / Municipality', controller: _city, hint: 'City / Municipality', icon: Icons.location_city, bottomGap: 6);
    final province = AppField(label: 'Province', controller: _province, hint: 'Province', icon: Icons.map, bottomGap: 6);
    final postalCode = AppField(label: 'Postal Code', controller: _postalCode, hint: 'Postal Code', icon: Icons.mark_email_unread_outlined, keyboard: TextInputType.number, bottomGap: 6);
    final tin = AppField(label: 'TIN Number (Optional)', controller: _tin, hint: 'Tax Identification Number', icon: Icons.receipt_long, required: false, bottomGap: 6);
    final dob = AppField(
      label: 'Date of Birth',
      controller: _dob,
      hint: 'YYYY-MM-DD',
      icon: Icons.cake_outlined,
      readOnly: true,
      onTap: () => _pickDate(context, _dob),
      bottomGap: 6,
    );
    final genderDropdown = AppDropdown(
      label: 'Gender',
      items: ['Male', 'Female', 'Other', 'Prefer not to say'],
      value: _gender.text.isEmpty ? null : _gender.text,
      onChanged: (v) => setState(() => _gender.text = v ?? ''),
      bottomGap: 6,
    );

    final List<Widget> fields;
    switch (m) {
case ProfileMode.edit:
        fields = [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: cardDeco(color: kGreenTint, r: 10),
            child: Row(children: [
              Builder(
                builder: (context) {
                  final photo = store.profile.photo;
                  if (photo != null && photo.isNotEmpty) {
                    return ClipOval(
                      child: Image.memory(
                        decodeImg(photo),
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    );
                  }
                  return Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kBlue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 23),
                  );
                },
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(store.profile.storeName, style: ts(12, w: FontWeight.w700, c: kBlue)),
                Text('Manage your business details', style: ts(9, c: kBlueDark)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          AppField(label: 'Business Owner Name', controller: _owner, hint: 'Owner name', bottomGap: 6),
          AppField(label: 'Store Name', controller: _store, hint: 'Store name', bottomGap: 6),
          typeDropdown,
          if (_type == 'Others')
            AppField(label: 'Specify Business Type', controller: _customBusinessType, hint: 'Enter business type', icon: Icons.business, bottomGap: 6),
          phone,
          addr,
        ];
      case ProfileMode.business:
        fields = [
          // Business Details Section
          Center(child: Container(
            width: 54, height: 54,
            decoration: cardDeco(color: kBlueTint, r: 14),
            child: const Icon(Icons.storefront_rounded, color: kBlue, size: 32),
          )),
          const SizedBox(height: 14),
          Text('Business Details', style: ts(13, w: FontWeight.w700, c: kBlue)),
          const SizedBox(height: 10),
          AppField(label: 'Store Name', controller: _store, hint: 'Store name', bottomGap: 6),
          typeDropdown,
          if (_type == 'Others')
            AppField(label: 'Specify Business Type', controller: _customBusinessType, hint: 'Enter business type', icon: Icons.business, bottomGap: 6),
          AppField(label: 'Business Owner', controller: _owner, hint: 'Owner name', bottomGap: 6),
          tin,
          const SizedBox(height: 8),
          // Business Location Section
          Text('Business Location', style: ts(13, w: FontWeight.w700, c: kBlue)),
          const SizedBox(height: 10),
          addr,
          city,
          province,
          postalCode,
        ];
      case ProfileMode.account:
        fields = [
          Center(
            child: Column(children: [
              Builder(
                builder: (context) {
                  final photo = store.profile.photo;
                  if (photo != null && photo.isNotEmpty) {
                    return ClipOval(
                      child: Image.memory(
                        decodeImg(photo),
                        width: 54,
                        height: 54,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    );
                  }
                  return Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCEBFF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Color(0xFF1468F5),
                      size: 40,
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _changePhoto,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: kBlueTint, borderRadius: BorderRadius.circular(12)),
                  child: Text('Change Photo', style: ts(9, w: FontWeight.w600, c: kBlue)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          // Account Profile Section
          Text('Account Profile', style: ts(13, w: FontWeight.w700, c: kBlue)),
          const SizedBox(height: 8),
          AppField(label: 'Full Name', controller: _owner, hint: 'Full name', bottomGap: 6),
          AppField(label: 'Username', controller: TextEditingController(text: store.account?.username ?? ''), hint: 'Username', readOnly: true, bottomGap: 6),
          dob,
          genderDropdown,
          const SizedBox(height: 6),
          // Contact Information Section
          Text('Contact Information', style: ts(13, w: FontWeight.w700, c: kBlue)),
          const SizedBox(height: 10),
          phone,
          AppField(label: 'Email Address', controller: _email, hint: 'Email Address', keyboard: TextInputType.emailAddress, validator: emailError, bottomGap: 6),
          const SizedBox(height: 8),
          // Account Security Section
          Text('Account Security', style: ts(13, w: FontWeight.w700, c: kBlue)),
          const SizedBox(height: 8),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: cardDeco(color: Colors.transparent, border: kFieldBorder),
                child: Row(children: [
                  const Icon(Icons.lock_outline, size: 18, color: kText),
                  const SizedBox(width: 10),
                  Text('Change Password', style: ts(11, w: FontWeight.w600)),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 18, color: kBlue),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Reset Business Data Section
          Text('Reset Business Data', style: ts(13, w: FontWeight.w700, c: kRed)),
          const SizedBox(height: 10),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _clearData,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: cardDeco(color: Colors.transparent, border: kRed.withValues(alpha: 0.5)),
                child: Row(children: [
                  const Icon(Icons.delete_sweep_outlined, size: 18, color: kRed),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Clear All Data', style: ts(11, w: FontWeight.w600, c: kRed)),
                      Text('Start fresh with an empty store', style: ts(8.5, c: kMuted)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ];
     }

    return BluePage(
      back: true,
      title: title,
      child: FormBody(formKey: _key, button: AppButton('Save', onPressed: _save), children: fields),
    );
  }
}

// ───────────────────────── Gcash QR ─────────────────────────

class GcashQrImage extends StatelessWidget {
  const GcashQrImage(this.qr, {super.key, this.size = 180});
  final String? qr;
  final double size;
  @override
  Widget build(BuildContext context) {
    if (qr != null) {
      return Image.memory(decodeImg(qr!), width: size, height: size, fit: BoxFit.contain, gaplessPlayback: true);
    }
    return Container(
      width: size,
      height: size,
      decoration: cardDeco(color: kBlueTint, r: 10),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.qr_code_2, size: size * 0.42, color: kBlue.withValues(alpha: 0.5)),
        const SizedBox(height: 6),
        Text('No QR code yet', style: ts(10, c: kMuted)),
      ]),
    );
  }
}

class GcashQrScreen extends StatelessWidget {
  const GcashQrScreen({super.key});

  Future<void> _upload(BuildContext context) async {
    final b = await pickImageBase64(context, maxWidth: 900);
    if (b != null) {
      store.profile.qr = b;
      store.saveProfile();
    }
  }

  Future<void> _downloadQr(BuildContext context) async {
    final qr = store.profile.qr;
    if (qr == null || qr.isEmpty) {
      snack(context, 'No QR code to download.');
      return;
    }
    if (kIsWeb) {
      snack(context, 'Download not available on web. Use right-click → Save image.');
      return;
    }
    final bytes = base64Decode(qr);
    final result = await ImageGallerySaverPlus.saveImage(Uint8List.fromList(bytes), name: 'tindaflow_gcash_qr');
    if (!context.mounted) return;
    if (result['isSuccess'] == true) {
      snack(context, 'QR code saved to gallery.');
    } else {
      snack(context, 'Failed to save QR code.');
    }
  }

  Future<void> _shareQr(BuildContext context) async {
    final qr = store.profile.qr;
    if (qr == null || qr.isEmpty) {
      snack(context, 'No QR code to share.');
      return;
    }
    if (kIsWeb) {
      snack(context, 'Sharing not available on web. Use right-click → Copy image.');
      return;
    }
    final bytes = base64Decode(qr);
    final tempFile = await _writeTempFile(bytes, 'gcash_qr.png');
    if (!context.mounted) return;
    await SharePlus.instance.share(ShareParams(files: [XFile(tempFile.path)], text: 'My GCash QR Code - ${store.profile.storeName}'));
  }

  Future<File> _writeTempFile(Uint8List bytes, String name) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final p = store.profile;
      return BluePage(
        back: true,
        title: 'GCash QR Code',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: cardDeco(color: kBlueTint),
              child: Row(children: [
                const GIcon(size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('GCash QR Code', style: ts(12, w: FontWeight.w700, c: kBlue)),
                    Text('Receive payments easily from your customers', style: ts(9, c: kBlueDark)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: cardDeco(border: const Color(0xFFE3ECF7)),
              child: Column(children: [
                Center(child: GcashQrImage(p.qr, size: 190)),
                const SizedBox(height: 12),
                Text(p.storeName, style: ts(13, w: FontWeight.w600, c: kBlue)),
                Text(p.phone, style: ts(12, w: FontWeight.w600, c: kBlue)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _Mini(Icons.download, 'Download\nQR Code', () => _downloadQr(context))),
                  const SizedBox(width: 10),
                  Expanded(child: _Mini(Icons.share, 'Share QR\nCode', () => _shareQr(context))),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            AppButton(p.qr == null ? 'Upload QR Code' : 'Update QR Code', icon: Icons.edit_outlined, onPressed: () => _upload(context)),
            if (p.qr != null) ...[
              const SizedBox(height: 10),
              AppButton('Remove QR Code', color: kRed, icon: Icons.delete_outline, onPressed: () async {
                final ok = await confirmDelete(context, title: 'Remove QR Code?', message: 'Customers will no longer see a QR code when paying by Gcash.');
                if (ok) {
                  store.profile.qr = null;
                  store.saveProfile();
                }
              }),
            ],
          ],
        ),
      );
    });
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.icon, this.text, this.onTap);
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: kBlueTint,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: kBlue),
            const SizedBox(width: 6),
            Text(text, style: ts(9, w: FontWeight.w600, c: kBlue)),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── Change password ─────────────────────────

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _key = GlobalKey<FormState>();
  final _cur = TextEditingController();
  final _new = TextEditingController();
  final _conf = TextEditingController();
  bool _h1 = true, _h2 = true, _h3 = true;

  @override
  void initState() {
    super.initState();
    _new.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _cur.dispose();
    _new.dispose();
    _conf.dispose();
    super.dispose();
  }

  void _save() {
    if (!_key.currentState!.validate()) return;
    if (!store.changePassword(_cur.text, _new.text)) {
      snack(context, 'Current password is incorrect.');
      return;
    }
    snack(context, 'Password updated');
    Navigator.of(context).pop();
  }

  Widget _eye(bool hidden, VoidCallback t) =>
      IconButton(icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: kBlue), onPressed: t);

  Widget _rule(String t, bool ok) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(Icons.check_circle, size: 15, color: ok ? kGreen : const Color(0xFFC5CFDD)),
          const SizedBox(width: 8),
          Text(t, style: ts(10)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final n = _new.text;
    return BluePage(
      back: true,
      title: 'Change Password',
      child: FormBody(
        formKey: _key,
        button: AppButton('Update Password', onPressed: _save),
        children: [
          Center(
            child: Column(children: [
              Container(
                width: 56, height: 56,
                decoration: const BoxDecoration(color: kBlueTint, shape: BoxShape.circle),
                child: const Icon(Icons.lock, color: kBlue, size: 28),
              ),
              const SizedBox(height: 8),
              Text('Update Password', style: ts(15, w: FontWeight.w700, c: kBlue)),
              const SizedBox(height: 4),
              Text('Make sure your new password is strong\nand easy for you to remember.', textAlign: TextAlign.center, style: ts(9.5, c: kBlueDark)),
              const SizedBox(height: 18),
            ]),
          ),
          AppField(label: 'Current Password', controller: _cur, hint: 'Enter current password...', obscure: _h1, suffix: _eye(_h1, () => setState(() => _h1 = !_h1))),
          AppField(label: 'New Password', controller: _new, hint: 'Enter new password...', obscure: _h2, validator: passwordError, suffix: _eye(_h2, () => setState(() => _h2 = !_h2))),
          AppField(
            label: 'Confirm New Password', controller: _conf, hint: 'Confirm new password...', obscure: _h3,
            validator: (v) => v != _new.text ? 'Passwords do not match' : null,
            suffix: _eye(_h3, () => setState(() => _h3 = !_h3)),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: cardDeco(color: kBlueTint),
            child: Column(children: [
              _rule('At least 8 characters', n.length >= 8),
              _rule('Includes a number', RegExp(r'[0-9]').hasMatch(n)),
              _rule('Includes a capital letter', RegExp(r'[A-Z]').hasMatch(n)),
            ]),
          ),
        ],
      ),
    );
  }
}
