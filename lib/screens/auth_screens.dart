import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/otp_service.dart';
import '../data/store.dart';
import '../widgets/common.dart';
import 'shell.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ logo & artwork â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ splash â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1000), _go);
  }

  void _go() {
    if (!mounted) return;
    final Widget next;
    if (store.loggedIn && store.hasAccount) {
      if (store.hasMpin && !store.appUnlocked) {
        next = const MpinLockScreen();
      } else {
        next = const MainShell(showBootLoader: true);
      }
    } else if (store.onboardingSeen) {
      next = const LoginScreen();
    } else {
      next = const OnboardingScreen();
    }
    Navigator.of(context).pushReplacement(AppPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Center(child: Image.asset('assets/images/tindaflowlogo.png', width: 170, height: 170)),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ onboarding â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
    Navigator.of(context).pushReplacement(AppPageRoute(builder: (_) => const LoginScreen()));
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

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ login / signup â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _key = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _remember = true;
  bool _hide = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _loading = true);
    final result = await store.loginAsync(
      email: _email.text,
      password: _pass.text,
      remember: _remember,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (result != LoginResult.success) {
      final message = switch (result) {
        LoginResult.noAccount =>
          'No account found for that email. Please sign up first.',
        LoginResult.wrongPassword => 'Incorrect password. Please try again.',
        _ => 'Could not sign in. Check your connection and try again.',
      };
      snack(context, message);
      return;
    }
    // Show loading animation before entering app
    await _showLoadingAndEnter();
  }

  Future<void> _showLoadingAndEnter() async {
    final overlay = Overlay.of(context);
    final navigator = Navigator.of(context);
    final entry = OverlayEntry(
      builder: (c) => Positioned.fill(
        child: Material(
          color: Colors.black54,
          child: Center(child: CircularProgressIndicator(color: kBlue, strokeWidth: 3)),
        ),
      ),
    );
    overlay.insert(entry);
    await Future.delayed(const Duration(milliseconds: 800));
    entry.remove();
    if (!mounted) return;
    navigator.pushAndRemoveUntil(AppPageRoute(builder: (_) => const MainShell()), (r) => false);
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
            AppField(label: 'Email', showLabel: false, controller: _email, hint: 'Email Address', icon: Icons.mail_outline, keyboard: TextInputType.emailAddress, validator: emailError, bottomGap: 6),
            AppField(
              label: 'Password', showLabel: false, controller: _pass, hint: 'Password', icon: Icons.lock_outline,
              obscure: _hide, validator: requiredError, bottomGap: 2,
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
            const SizedBox(height: 5),
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
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(text: "Don't have an account? ", style: ts(10, w: FontWeight.w600), children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(AppPageRoute(builder: (_) => const SignupScreen())),
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
  final _confirmCtrl = TextEditingController();
  final _passFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _loading = false;
  bool _hidePass = true;
  bool _hideConfirm = true;

  @override
  void initState() {
    super.initState();
    _passCtrl.addListener(() => setState(() {}));
    _passFocus.addListener(() => setState(() {}));
    _confirmFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  /// Full-screen loading overlay matching the Login form's indicator.
  OverlayEntry _showLoadingOverlay() {
    final entry = OverlayEntry(
      builder: (c) => const Positioned.fill(
        child: Material(
          color: Colors.black54,
          child: Center(child: CircularProgressIndicator(color: kBlue, strokeWidth: 3)),
        ),
      ),
    );
    Overlay.of(context).insert(entry);
    return entry;
  }

  Future<void> _sendOtp() async {
    final err = emailError(_emailCtrl.text);
    if (err != null) {
      snack(context, err);
      return;
    }
    // Only the locally registered account can reset password / MPIN.
    final email = _emailCtrl.text.trim().toLowerCase();
    final registered = store.account?.email == email;
    if (!mounted) return;
    if (!registered) {
      snack(context, 'This email is not registered. Please sign up first.');
      return;
    }
    setState(() => _loading = true);
    final res = await otpService.sendOtp(_emailCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!res.ok) {
      snack(context, res.message);
      return;
    }
    setState(() => _step = 1);
    snack(context, 'If that email is registered, a code has been sent.');
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.trim().length < 6) {
      snack(context, 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() => _loading = true);
    final entry = _showLoadingOverlay();
    final res = await otpService.verifyOtp(email: _emailCtrl.text, code: _otpCtrl.text);
    entry.remove();
    if (!mounted) return;
    setState(() => _loading = false);
    if (!res.ok) {
      snack(context, res.message);
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
    if (_confirmCtrl.text != _passCtrl.text) {
      snack(context, 'Passwords do not match.');
      return;
    }
    setState(() => _loading = true);
    final entry = _showLoadingOverlay();
    final res = await otpService.resetPassword(
      email: _emailCtrl.text,
      newPassword: _passCtrl.text,
    );
    entry.remove();
    if (!mounted) return;
    setState(() => _loading = false);
    if (!res.ok) {
      snack(context, res.message);
      return;
    }
    Navigator.pop(context);
    snack(context, res.message);
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Forgot password', 'Verify code', 'Create new password'];
    final labels = ['Send code', 'Verify', 'Reset password'];
    return AlertDialog(
      backgroundColor: kCard,
      title: Text(titles[_step], style: ts(15, w: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_step == 0) ...[
          Text(
            'Enter the email registered to your TindaFlow account and we will send you a 6-digit code.',
            style: ts(10, c: kMuted),
          ),
          const SizedBox(height: 8),
          AppField(label: 'Account email', controller: _emailCtrl, hint: 'Email Address', icon: Icons.mail_outline, keyboard: TextInputType.emailAddress, required: false, bottomGap: 4),
        ],
        if (_step == 1) ...[
          Text(
            'We sent a 6-digit code to ${_emailCtrl.text.trim()}. Enter it below to continue.',
            style: ts(10, c: kMuted),
          ),
          const SizedBox(height: 8),
          AppField(label: 'OTP code', controller: _otpCtrl, hint: 'Enter the 6-digit code', icon: Icons.password, keyboard: TextInputType.number, required: false, bottomGap: 4),
        ],
        if (_step == 2) ...[
          Text(
            'Code verified. Create a new password for ${_emailCtrl.text.trim()}.',
            style: ts(10, c: kMuted),
          ),
          const SizedBox(height: 8),
          AppField(
            label: 'New password',
            controller: _passCtrl,
            focusNode: _passFocus,
            hint: 'Create a strong password',
            icon: Icons.lock_outline,
            obscure: _hidePass,
            required: false,
            validator: passwordError,
            bottomGap: 6,
            suffix: IconButton(
              icon: Icon(_hidePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: kMuted),
              onPressed: () => setState(() => _hidePass = !_hidePass),
            ),
          ),
          // Rules guide: visible only while the New Password field is focused.
          // Collapses when the user moves to Confirm New Password so the dialog
          // stays short enough to fit the action buttons on mobile.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: (_passFocus.hasFocus && !_confirmFocus.hasFocus)
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: PasswordRules(_passCtrl.text),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
          AppField(
            label: 'Confirm new password',
            controller: _confirmCtrl,
            focusNode: _confirmFocus,
            hint: 'Re-enter your new password',
            icon: Icons.lock_outline,
            obscure: _hideConfirm,
            required: false,
            bottomGap: 4,
            suffix: IconButton(
              icon: Icon(_hideConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: kMuted),
              onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
            ),
          ),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _loading
              ? null
              : () {
                  if (_step == 0) {
                    _sendOtp();
                  } else if (_step == 1) {
                    _verifyOtp();
                  } else {
                    _reset();
                  }
                },
          child: Text(_loading ? 'Please wait...' : labels[_step]),
        ),
      ],
    );
  }
}
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ account created â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class AccountCreatedScreen extends StatelessWidget {
  const AccountCreatedScreen({super.key, required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    return BluePage(
      bodyColor: Colors.white,
      child: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 8),
            child: Column(children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 54),
              ),
              const SizedBox(height: 18),
              Text('Account Successfully Created!', style: ts(18, w: FontWeight.w700, c: kBlue), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Your TindaFlow account is ready. You can now log in using the email below.',
                style: ts(11, c: kMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: cardDeco(color: kBlueTint, border: kBlue.withValues(alpha: 0.25)),
                child: Column(children: [
                  Text('Registered email', style: ts(9, w: FontWeight.w600, c: kBlueDark)),
                  const SizedBox(height: 4),
                  Text(email, style: ts(13, w: FontWeight.w700, c: kBlue), textAlign: TextAlign.center),
                ]),
              ),
            ]),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: AppButton('Proceed to Login', height: 44, onPressed: () {
              Navigator.of(context).popUntil((r) => r.isFirst);
            }),
          ),
        ),
      ]),
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
  final _passFocus = FocusNode();
  bool _agree = false;
  bool _hide = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _pass.addListener(() => setState(() {}));
    _passFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _user.dispose();
    _email.dispose();
    _pass.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    // Hide the password rules guide when the user taps Sign Up.
    _passFocus.unfocus();
    if (!_key.currentState!.validate()) return;
    if (!_agree) {
      snack(context, 'Please agree to the terms and conditions.');
      return;
    }
    setState(() => _loading = true);
    final ok = await store.signUp(fullName: _name.text, username: _user.text, email: _email.text, password: _pass.text);
    if (!mounted) return;
    if (!ok) {
      setState(() => _loading = false);
      snack(context, 'This email is already registered.');
      return;
    }
    // Keep the loading indicator visible briefly before the success screen.
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pushReplacement(
      AppPageRoute(builder: (_) => AccountCreatedScreen(email: _email.text.trim())),
    );
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
            AppField(label: 'Full name', showLabel: false, controller: _name, hint: 'Full name', icon: Icons.person_outline, bottomGap: 6),
            AppField(label: 'Username', showLabel: false, controller: _user, hint: 'Username', icon: Icons.person_outline, bottomGap: 6),
            AppField(label: 'Email', showLabel: false, controller: _email, hint: 'Email Address', icon: Icons.mail_outline, keyboard: TextInputType.emailAddress, validator: emailError, bottomGap: 6),
            AppField(
              label: 'Password', showLabel: false, controller: _pass, focusNode: _passFocus, hint: 'Password', icon: Icons.lock_outline,
              obscure: _hide, validator: passwordError, bottomGap: 4,
              suffix: IconButton(
                icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: kMuted),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
            // Rules guide: visible only while the Password field is focused.
            // Collapses when the user taps another field or the Sign Up button.
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _passFocus.hasFocus
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: PasswordRules(_pass.text),
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Checkbox(
                value: _agree,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => setState(() => _agree = v ?? false),
              ),
              Text('I agree to the terms and conditions', style: ts(10, w: FontWeight.w600)),
            ]),
            const SizedBox(height: 5),
            AppButton(
              _loading ? 'Creating account...' : 'Sign up',
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
            const SizedBox(height: 6),
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

// ───────────────────────── Forgot MPIN (email + OTP) ─────────────────────────

/// Mirrors the Forgot Password flow: enter registered email -> receive a 6-digit
/// OTP by email -> verify -> create a new MPIN. On success returns `true` via
/// `Navigator.pop(context, true)` so the lock screen can unlock the app.
class _ForgotMpinDialog extends StatefulWidget {
  const _ForgotMpinDialog();
  @override
  State<_ForgotMpinDialog> createState() => _ForgotMpinDialogState();
}

class _ForgotMpinDialogState extends State<_ForgotMpinDialog> {
  int _step = 0;
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _confCtrl = TextEditingController();
  bool _loading = false;
  bool _hide = true;

  @override
  void initState() {
    super.initState();
    _pinCtrl.addListener(() => setState(() {}));
    _confCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _pinCtrl.dispose();
    _confCtrl.dispose();
    super.dispose();
  }

  OverlayEntry _showLoadingOverlay() {
    final entry = OverlayEntry(
      builder: (c) => const Positioned.fill(
        child: Material(
          color: Colors.black54,
          child: Center(child: CircularProgressIndicator(color: kBlue, strokeWidth: 3)),
        ),
      ),
    );
    Overlay.of(context).insert(entry);
    return entry;
  }

  Future<void> _sendOtp() async {
    final err = emailError(_emailCtrl.text);
    if (err != null) {
      snack(context, err);
      return;
    }
    // For MPIN reset, only the currently logged-in account's email may receive
    // a code — the MPIN belongs to that account, so a different email must not
    // be allowed to reset it.
    final email = _emailCtrl.text.trim().toLowerCase();
    final loggedInEmail = store.account?.email;
    if (loggedInEmail == null || email != loggedInEmail) {
      snack(context, 'Only the logged-in email account can send a code. Sign in with that account first.');
      return;
    }
    setState(() => _loading = true);
    final res = await otpService.sendOtp(_emailCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!res.ok) {
      snack(context, res.message);
      return;
    }
    setState(() => _step = 1);
    snack(context, 'If that email is registered, a code has been sent.');
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.trim().length < 6) {
      snack(context, 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() => _loading = true);
    final entry = _showLoadingOverlay();
    final res = await otpService.verifyOtp(email: _emailCtrl.text, code: _otpCtrl.text);
    entry.remove();
    if (!mounted) return;
    setState(() => _loading = false);
    if (!res.ok) {
      snack(context, res.message);
      return;
    }
    setState(() => _step = 2);
  }

  Future<void> _saveMpin() async {
    final pin = _pinCtrl.text;
    if (pin.length != 6) {
      snack(context, 'Enter all 6 digits');
      return;
    }
    if (pin != _confCtrl.text) {
      snack(context, 'MPINs do not match');
      return;
    }
    setState(() => _loading = true);
    final entry = _showLoadingOverlay();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final ok = store.setMpin(pin);
    if (!mounted) return;
    entry.remove();
    setState(() => _loading = false);
    if (ok) {
      // Require the user to enter the new MPIN — do not auto-unlock.
      store.appUnlocked = false;
      Navigator.pop(context, false);
      snack(context, 'MPIN reset. Enter your new MPIN to continue.');
    } else {
      snack(context, 'MPIN must be exactly 6 digits');
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Forgot MPIN', 'Verify code', 'Create new MPIN'];
    final labels = ['Send code', 'Verify', 'Save MPIN'];
    return AlertDialog(
      backgroundColor: kCard,
      title: Text(titles[_step], style: ts(15, w: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_step == 0) ...[
            Text(
              'Enter the email registered to your TindaFlow account and we will send you a 6-digit code.',
              style: ts(10, c: kMuted),
            ),
            const SizedBox(height: 8),
            AppField(label: 'Account email', controller: _emailCtrl, hint: 'Email Address', icon: Icons.mail_outline, keyboard: TextInputType.emailAddress, required: false, bottomGap: 4),
          ],
          if (_step == 1) ...[
            Text(
              'We sent a 6-digit code to ${_emailCtrl.text.trim()}. Enter it below to continue.',
              style: ts(10, c: kMuted),
            ),
            const SizedBox(height: 8),
            AppField(label: 'OTP code', controller: _otpCtrl, hint: 'Enter the 6-digit code', icon: Icons.password, keyboard: TextInputType.number, required: false, bottomGap: 4),
          ],
          if (_step == 2) ...[
            Text(
              'Code verified. Create a new 6-digit MPIN for your app lock.',
              style: ts(10, c: kMuted),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('New MPIN', style: ts(11, w: FontWeight.w600, c: kBlueDark)),
            ),
            const SizedBox(height: 6),
            PinField(controller: _pinCtrl, obscure: _hide, boxWidth: 38, boxHeight: 46),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Confirm New MPIN', style: ts(11, w: FontWeight.w600, c: kBlueDark)),
            ),
            const SizedBox(height: 6),
            PinField(controller: _confCtrl, obscure: _hide, boxWidth: 38, boxHeight: 46),
            const SizedBox(height: 8),
            if (_pinCtrl.text.length == 6 && _confCtrl.text.length == 6 && _pinCtrl.text != _confCtrl.text)
              Text('MPINs do not match', style: ts(10, w: FontWeight.w600, c: kRed)),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => setState(() => _hide = !_hide),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 16, color: kBlue),
                const SizedBox(width: 6),
                Text(_hide ? 'Show' : 'Hide', style: ts(11, w: FontWeight.w600, c: kBlue)),
              ]),
            ),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _loading
              ? null
              : () {
                  if (_step == 0) {
                    _sendOtp();
                  } else if (_step == 1) {
                    _verifyOtp();
                  } else {
                    _saveMpin();
                  }
                },
          child: Text(_loading ? 'Please wait...' : labels[_step]),
        ),
      ],
    );
  }
}

// ───────────────────────── MPIN lock (app gate) ─────────────────────────

/// Shown on every cold start when an MPIN is set. Blocks the dashboard until
/// the correct 6-digit MPIN is entered. There is no back/bypass path.
class MpinLockScreen extends StatefulWidget {
  const MpinLockScreen({super.key});
  @override
  State<MpinLockScreen> createState() => _MpinLockScreenState();
}

class _MpinLockScreenState extends State<MpinLockScreen> {
  final _pin = TextEditingController();
  bool _hide = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _pin.addListener(_onChanged);
  }

  void _onChanged() {
    if (_error && mounted) setState(() => _error = false);
  }

  @override
  void dispose() {
    _pin.removeListener(_onChanged);
    _pin.dispose();
    super.dispose();
  }

  void _verify() {
    final pin = _pin.text;
    if (pin.length != 6) {
      setState(() => _error = true);
      snack(context, 'Enter all 6 digits');
      return;
    }
    if (store.verifyMpin(pin)) {
      store.unlockApp();
      Navigator.of(context).pushReplacement(
        AppPageRoute(builder: (_) => const MainShell(showBootLoader: true)),
      );
    } else {
      setState(() => _error = true);
      _pin.clear();
      snack(context, 'Incorrect MPIN');
    }
  }

  Future<void> _forgot() async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => const _ForgotMpinDialog(),
    );
    // The dialog resets the MPIN but does not unlock. The user must now enter
    // the new MPIN on this lock screen. Clear the field and reset error state.
    if (!mounted) return;
    _pin.clear();
    setState(() => _error = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/tindaflowlogo.png', width: 96, height: 96),
                const SizedBox(height: 18),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _error ? kRedTint : kBlueTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _error ? Icons.lock_outline : Icons.lock_rounded,
                    color: _error ? kRed : kBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                Text('Enter Your MPIN', style: ts(20, w: FontWeight.w700, c: kBlue)),
                const SizedBox(height: 8),
                Text(
                  'Enter your 6-digit PIN to securely access your business dashboard.',
                  textAlign: TextAlign.center,
                  style: ts(11, c: kBlueDark, h: 1.5),
                ),
                const SizedBox(height: 28),
                PinField(
                  controller: _pin,
                  obscure: _hide,
                  activeColor: _error ? kRed : kBlue,
                  borderColor: _error ? kRed : kFieldBorder,
                  filledColor: _error ? kRedTint : kBlueTint,
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _hide = !_hide),
                      child: Row(children: [
                        Icon(
                          _hide ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 16,
                          color: kBlue,
                        ),
                        const SizedBox(width: 6),
                        Text(_hide ? 'Show' : 'Hide', style: ts(11, w: FontWeight.w600, c: kBlue)),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: AppButton('Verify', onPressed: _verify),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _forgot,
                  child: Text('Forgot MPIN?', style: ts(11, w: FontWeight.w600, c: kMuted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
