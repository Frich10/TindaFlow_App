import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/store.dart';
import '../widgets/common.dart';
import 'shell.dart';

// ───────────────────────── logo & artwork ─────────────────────────

class AssetOrFallback extends StatelessWidget {
  const AssetOrFallback(this.path, {super.key, required this.fallback, this.width, this.height});
  final String path;
  final Widget fallback;
  final double? width;
  final double? height;
  @override
  Widget build(BuildContext context) {
    return Image.asset(path, width: width, height: height, fit: BoxFit.contain, errorBuilder: (c, e, s) => fallback);
  }
}

class TindaLogo extends StatelessWidget {
  const TindaLogo({super.key, this.size = 120});
  final double size;
  @override
  Widget build(BuildContext context) {
    return AssetOrFallback(
      'assets/images/tindaflowlogo.png',
      width: size,
      height: size,
      fallback: SizedBox(
        width: size,
        height: size,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: size * 0.62,
            height: size * 0.62,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [kBlue, Color(0xFF38BDF8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Icon(Icons.storefront_rounded, color: Colors.white, size: size * 0.38),
          ),
          SizedBox(height: size * 0.06),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Tinda', style: TextStyle(color: kBlue, fontSize: size * 0.17, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic)),
              TextSpan(text: 'Flow', style: TextStyle(color: kGreen, fontSize: size * 0.17, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── splash ─────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), _go);
  }

  void _go() {
    if (!mounted) return;
    final Widget next;
    if (store.loggedIn && store.hasAccount) {
      next = const MainShell();
    } else if (store.onboardingSeen) {
      next = const LoginScreen();
    } else {
      next = const OnboardingScreen();
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Center(child: Image.asset('assets/images/tindaflowlogo.png', width: 170, height: 170)),
    );
  }
}

// ───────────────────────── onboarding ─────────────────────────

class _OB {
  const _OB(this.line1, this.line2, this.body, this.icon, this.badges);
  final String line1;
  final String line2;
  final String body;
  final IconData icon;
  final List<IconData> badges;
}

const _pages = [
  _OB('Manage Your Store', 'with Ease', 'Keep track of your sales, inventory, and daily operations - all in one app.',
      Icons.storefront_rounded, [Icons.check_circle, Icons.trending_up, Icons.inventory_2]),
  _OB('All-in-One', 'For Small Businesses',
      'From sales and stock tracking to expenses and reports, everything you need is in one place.',
      Icons.phone_iphone_rounded, [Icons.bar_chart, Icons.account_balance_wallet, Icons.receipt_long, Icons.inventory_2]),
  _OB('Grow Your Business', 'Smarter',
      'Make better decisions, increase efficiency, and achieve more with TindaFlow.',
      Icons.store_mall_directory_rounded, [Icons.trending_up, Icons.checklist, Icons.emoji_events]),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _i = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_i < _pages.length - 1) {
      _ctrl.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
      return;
    }
    await store.setOnboardingSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: _i == 0 ? Colors.transparent : kBlue, size: 20),
              onPressed: _i == 0
                  ? null
                  : () => _ctrl.previousPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _ctrl,
              itemCount: _pages.length,
              onPageChanged: (v) => setState(() => _i = v),
              itemBuilder: (_, i) {
                final p = _pages[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    AssetOrFallback('assets/images/onboarding${i + 1}.png',
                        width: 260, height: 220, fallback: _Art(p)),
                    const SizedBox(height: 28),
                    Text(p.line1, style: ts(20, w: FontWeight.w700, c: kBlue), textAlign: TextAlign.center),
                    Text(p.line2, style: ts(20, w: FontWeight.w700, c: kGreen), textAlign: TextAlign.center),
                    const SizedBox(height: 14),
                    Text(p.body, style: ts(11, c: kBlue, h: 1.6), textAlign: TextAlign.center),
                  ]),
                );
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _pages.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _i ? kBlue : kBlue.withValues(alpha: 0.2),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
            child: AppButton(_i == _pages.length - 1 ? 'Get Started' : 'Next', height: 42, onPressed: _next),
          ),
        ]),
      ),
    );
  }
}

class _Art extends StatelessWidget {
  const _Art(this.page);
  final _OB page;
  @override
  Widget build(BuildContext context) {
    const colors = [kGreen, kOrange, kRed, kBlue];
    const spots = [Alignment(-0.85, -0.7), Alignment(0.9, -0.55), Alignment(0.8, 0.75), Alignment(-0.9, 0.6)];
    return SizedBox(
      width: 260,
      height: 220,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          width: 200,
          height: 180,
          decoration: BoxDecoration(color: kBlueTint, borderRadius: BorderRadius.circular(90)),
        ),
        Container(
          width: 110,
          height: 110,
          decoration: cardDeco(r: 26, shadow: true),
          child: Icon(page.icon, size: 64, color: kBlue),
        ),
        for (var i = 0; i < page.badges.length; i++)
          Align(alignment: spots[i], child: CircleIcon(page.badges[i], color: colors[i % colors.length], size: 40)),
      ]),
    );
  }
}

// ───────────────────────── login / signup ─────────────────────────

class AuthHeader extends StatelessWidget {
  const AuthHeader(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Column(children: [
        SizedBox(
          height: 52,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    onPressed: () => Navigator.maybePop(context))
                : null,
          ),
        ),
        const Spacer(),
        Text(title, style: ts(30, w: FontWeight.w600, c: Colors.white)),
        const SizedBox(height: 24),
      ]),
    );
  }
}

void _enterApp(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainShell()), (r) => false);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _key = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _remember = true;
  bool _hide = true;
  bool _loading = false;

  @override
  void dispose() {
    _user.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _loading = true);
    final ok = await store.loginAsync(
      username: _user.text,
      email: _email.text,
      password: _pass.text,
      remember: _remember,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      snack(context, 'Incorrect username, email or password, or account not found.');
      return;
    }
    _enterApp(context);
  }

  void _forgot() {
    showDialog<void>(
      context: context,
      builder: (c) => const _ForgotPasswordDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BluePage(
      header: const AuthHeader('Login'),
      bodyColor: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
        child: Form(
          key: _key,
          child: Column(children: [
            AppField(label: 'Username', showLabel: false, controller: _user, hint: 'Username', icon: Icons.person_outline),
            AppField(label: 'Email', showLabel: false, controller: _email, hint: 'Email Address', icon: Icons.mail_outline, keyboard: TextInputType.emailAddress, validator: emailError),
            AppField(
              label: 'Password', showLabel: false, controller: _pass, hint: 'Password', icon: Icons.lock_outline,
              obscure: _hide, bottomGap: 4,
              suffix: IconButton(
                icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: kMuted),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
            Row(children: [
              Checkbox(
                value: _remember,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => setState(() => _remember = v ?? false),
              ),
              Text('Remember me?', style: ts(10, w: FontWeight.w600)),
              const Spacer(),
              GestureDetector(onTap: _forgot, child: Text('Forgot Password?', style: ts(10, w: FontWeight.w600))),
            ]),
            const SizedBox(height: 12),
            AppButton(
              _loading ? 'Logging in...' : 'Login',
              height: 42,
              onPressed: _loading ? null : _submit,
              leading: _loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(text: "Don't have an account? ", style: ts(10, w: FontWeight.w600), children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupScreen())),
                    child: Text('Create an Account', style: ts(10, w: FontWeight.w700, c: kBlue)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog();

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  int _step = 0;
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _code;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      snack(context, 'Enter your registered email.');
      return;
    }
    setState(() => _loading = true);
    _code = (1000 + Random().nextInt(9000)).toString();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _step = 1;
    });
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('OTP Code'),
        content: SelectableText(_code!, style: ts(24, w: FontWeight.w700)),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
      ),
    );
    snack(context, 'OTP sent to $email.');
  }

  void _verifyOtp() {
    if (_otpCtrl.text.trim() != _code) {
      snack(context, 'Invalid OTP code.');
      return;
    }
    setState(() => _step = 2);
  }

  Future<void> _reset() async {
    final err = passwordError(_passCtrl.text);
    if (err != null) {
      snack(context, err);
      return;
    }
    setState(() => _loading = true);
    final ok = await store.resetPasswordAsync(_emailCtrl.text, _passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pop(context);
    snack(context, ok ? 'Password updated. You can log in now.' : 'No account found with that email.');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Reset password', style: ts(15, w: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_step == 0)
          AppField(label: 'Account email', controller: _emailCtrl, hint: 'Email Address', icon: Icons.mail_outline, required: false, bottomGap: 0),
        if (_step == 1)
          AppField(label: 'OTP code', controller: _otpCtrl, hint: 'Enter OTP', icon: Icons.password, required: false, bottomGap: 0),
        if (_step == 2)
          AppField(label: 'New password', controller: _passCtrl, hint: 'At least 8 chars, number, capital', icon: Icons.lock_outline, obscure: true, required: false, bottomGap: 0),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _loading
              ? null
              : () {
                  if (_step == 0) _sendOtp();
                  else if (_step == 1) _verifyOtp();
                  else _reset();
                },
          child: Text(_loading ? 'Please wait...' : (_step == 0 ? 'Send OTP' : (_step == 1 ? 'Verify' : 'Reset'))),
        ),
      ],
    );
  }
}
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _user = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _agree = true;
  bool _hide = true;

  @override
  void dispose() {
    _name.dispose();
    _user.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    if (!_agree) {
      snack(context, 'Please agree to the terms and conditions.');
      return;
    }
    if (store.hasAccount) {
      final replace = await confirmDelete(
        context,
        title: 'Replace existing account?',
        message: 'An account already exists on this device. Creating a new one will replace it and its data.',
      );
      if (!replace) return;
    }
    await store.signUp(fullName: _name.text, username: _user.text, email: _email.text, password: _pass.text);
    if (!mounted) return;
    _enterApp(context);
  }

  @override
  Widget build(BuildContext context) {
    return BluePage(
      header: const AuthHeader('Sign up'),
      bodyColor: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
        child: Form(
          key: _key,
          child: Column(children: [
            AppField(label: 'Full name', showLabel: false, controller: _name, hint: 'Full name', icon: Icons.person_outline),
            AppField(label: 'Username', showLabel: false, controller: _user, hint: 'Username', icon: Icons.person_outline),
            AppField(label: 'Email', showLabel: false, controller: _email, hint: 'Email Address', icon: Icons.mail_outline, keyboard: TextInputType.emailAddress, validator: emailError),
            AppField(
              label: 'Password', showLabel: false, controller: _pass, hint: 'Password', icon: Icons.lock_outline,
              obscure: _hide, validator: passwordError, bottomGap: 4,
              suffix: IconButton(
                icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: kMuted),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
            Row(children: [
              Checkbox(
                value: _agree,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => setState(() => _agree = v ?? false),
              ),
              Text('I agree to the terms and conditions', style: ts(10, w: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            AppButton('Sign up', height: 42, onPressed: _submit),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(text: 'Already have an account? ', style: ts(10, w: FontWeight.w600), children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Text('Log in', style: ts(10, w: FontWeight.w700, c: kBlue)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
