import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../widgets/common.dart';
import 'auth_screens.dart' show TindaLogo;

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ About TindaFlow â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  void _go(BuildContext context, Widget w) => Navigator.of(context).push(AppPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    return BluePage(
      back: true,
      title: 'About TindaFlow',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(child: TindaLogo(size: 110)),
          const SizedBox(height: 8),
          Center(child: Text('Track Better, Manage Smarter, Grow Faster.', style: ts(10, c: kBlueDark))),
          const SizedBox(height: 16),
          _AboutTile(Icons.settings_suggest_outlined, 'Features', 'What you can do with TindaFlow', () => _go(context, const FeaturesScreen())),
          _AboutTile(Icons.shield_outlined, 'Privacy Policy', 'How we protect your data', () => _go(context, const PrivacyScreen())),
          _AboutTile(Icons.description_outlined, 'Terms of Service', 'Our terms and conditions', () => _go(context, const TermsScreen())),
          _AboutTile(Icons.headset_mic_outlined, 'Contact Support', 'Get help from our team', () => _go(context, const ContactScreen())),
        ],
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile(this.icon, this.title, this.subtitle, this.onTap);
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: kCard,
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: ts(11, w: FontWeight.w600)),
                  Text(subtitle, style: ts(8.5, c: kMuted)),
                ]),
              ),
              const Icon(Icons.chevron_right, size: 18, color: kBlueDark),
            ]),
          ),
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ shared layout pieces â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _InfoPage extends StatelessWidget {
  const _InfoPage({required this.title, required this.icon, required this.heading, required this.intro, required this.children, this.footer});
  final String title;
  final IconData icon;
  final String heading;
  final String intro;
  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return BluePage(
      back: true,
      title: title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDeco(color: kBlueTint, r: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(color: kBlue, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(heading, style: ts(14, w: FontWeight.w700, c: kBlue)),
                  const SizedBox(height: 4),
                  Text(intro, style: ts(10, c: kBlueDark, h: 1.6)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          ...children,
          if (footer != null) ...[
            const SizedBox(height: 8),
            Center(child: Text(footer!, style: ts(9, c: kMuted))),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.icon, required this.title, required this.body, this.color = kBlue, this.number});
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final int? number;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(border: const Color(0xFFE3ECF7)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(number == null ? title : '$number. $title', style: ts(11.5, w: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(body, style: ts(10, c: const Color(0xFF4A6285), h: 1.6)),
          ]),
        ),
      ]),
    );
  }
}

Widget _heading(String t) => Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(t, style: ts(12, w: FontWeight.w700, c: kBlue)),
    );

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Features â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return _InfoPage(
      title: 'How It Works',
      icon: Icons.help_outline,
      heading: 'Simple steps to run your store',
      intro: 'Follow these quick guides to record and review every part of your business in TindaFlow.',
      children: [
        _heading('Stocks'),
        const _SectionCard(icon: Icons.add_box_outlined, color: kBlue, title: 'Add a product', body: 'Open Stocks, tap the add button, then enter the product name, price, cost, stock count and category. Save it and it appears in your product list.'),
        const _SectionCard(icon: Icons.edit_outlined, color: kBlue, title: 'Update stock', body: 'Tap any product to edit its details or adjust the stock count. Use the +/- buttons on the product card to quickly add or remove units.'),
        const _SectionCard(icon: Icons.low_priority, color: kRed, title: 'Watch low stock', body: 'Products at or below their low-stock threshold are highlighted in red so you know when to restock.'),

        _heading('Sales'),
        const _SectionCard(icon: Icons.point_of_sale, color: kGreen, title: 'Ring up a sale', body: 'Open Sales, tap products to add them to the cart, choose Cash or GCash, then tap Checkout. Change is computed automatically.'),
        const _SectionCard(icon: Icons.history, color: kGreen, title: 'Review history', body: 'Every completed sale is saved in Sales history with its items, total and payment method. Tap a record to see the full details.'),

        _heading('Debt (Utang)'),
        const _SectionCard(icon: Icons.person_add_alt, color: kRed, title: 'Record a debt', body: 'Open Debt, tap add, then enter the customer name, items, amount and an optional due date. Save it to track what is owed.'),
        const _SectionCard(icon: Icons.check_circle_outline, color: kRed, title: 'Mark as paid', body: 'When a customer pays, open the debt and tap Mark as Paid. The total stays the same but the status changes to Paid.'),

        _heading('Expenses'),
        const _SectionCard(icon: Icons.receipt_long, color: kOrange, title: 'Log an expense', body: 'Open Expenses, tap add, then enter the category, amount, date and an optional note. Save it to keep a record of your operating costs.'),
        const _SectionCard(icon: Icons.pie_chart_outline, color: kOrange, title: 'See where money goes', body: 'Each expense is grouped by category so you can see which costs take up the most of your budget.'),

        _heading('GCash Records'),
        const _SectionCard(icon: Icons.add_circle_outline, color: kBlue, title: 'Record a transaction', body: 'Open GCash, tap add, then choose Cash In or Cash Out, enter the amount, fee, date, time and reference number. Save it to your records.'),
        const _SectionCard(icon: Icons.document_scanner_outlined, color: kBlue, title: 'Scan a receipt', body: 'Tap the scan icon on the Record GCash screen to read a receipt photo. The amount, date, time, name and number are filled in for you to review before saving.'),
        const _SectionCard(icon: Icons.bar_chart, color: kBlue, title: 'Cash-flow report', body: 'Tap the download icon on the GCash screen to export a cash-flow report by day, week, month or year.'),

        _heading('Subscriptions'),
        const _SectionCard(icon: Icons.workspace_premium, color: kGreen, title: 'Go Premium', body: 'Open Subscription, tap Subscribe, then pay ₱39 through GCash and submit your details and receipt. Premium activates after your payment is verified.'),
        const _SectionCard(icon: Icons.verified_outlined, color: kGreen, title: 'Check your status', body: 'The Subscription screen shows whether you are on the Free or Premium plan and when your Premium access started.'),
      ],
    );
  }
}

class FeaturesScreen extends StatelessWidget {
  const FeaturesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return _InfoPage(
      title: 'Features',
      icon: Icons.settings_suggest_outlined,
      heading: 'Everything your store needs',
      intro: 'TindaFlow brings your sales, stock, credit, expenses and GCash records into one simple app.',
      children: [
        _heading('Core tools'),
        const _SectionCard(icon: Icons.shopping_cart, color: kGreen, title: 'Sales', body: 'Ring up items, accept cash or GCash, compute change automatically and review your full sales history.'),
        const _SectionCard(icon: Icons.inventory_2, color: kBlue, title: 'Stocks', body: 'Track inventory, get low-stock alerts and see the movement history of every product.'),
        const _SectionCard(icon: Icons.people_alt, color: kRed, title: 'Debt (Utang)', body: 'Record what customers owe, set due dates and mark debts as paid.'),
        const _SectionCard(icon: Icons.receipt_long, color: kOrange, title: 'Expenses', body: 'Log operating costs by category to know where your money goes.'),
        _heading('Insights'),
        const _SectionCard(icon: Icons.account_balance_wallet, color: kBlue, title: 'GCash Records', body: 'Record cash-in and cash-out with fees and view cash-flow reports by day, week, month or year.'),
        const _SectionCard(icon: Icons.insights, color: kPurple, title: 'Dashboard', body: 'See total sales, estimated profit, expenses and your GCash balance at a glance.'),
        const _SectionCard(icon: Icons.workspace_premium, color: kGreen, title: 'Premium Plan', body: 'Unlock the full toolset for ₱39 per month. Premium activates after your payment is verified.'),
      ],
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Privacy Policy â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const _InfoPage(
      title: 'Privacy Policy',
      icon: Icons.shield_outlined,
      heading: 'Your data, protected',
      intro: 'We collect only what we need to run TindaFlow and we never sell your information.',
      footer: 'Last updated: November 2026',
      children: [
        _SectionCard(icon: Icons.storage_outlined, title: 'Information we store', number: 1, body: 'Your business records — products, sales, debts, expenses and GCash entries — and the account details you provide, such as name, username and email.'),
        _SectionCard(icon: Icons.phone_android, color: kGreen, title: 'Where your data lives', number: 2, body: 'Business data is saved on your device. Passwords are stored only as a one-way hash. Removing the app or clearing its data erases your records.'),
        _SectionCard(icon: Icons.credit_card, color: kOrange, title: 'Subscription payments', number: 3, body: 'To verify a Premium payment we process your full name, phone number, email, payment reference and any receipt screenshot you upload. These are used only to confirm your payment.'),
        _SectionCard(icon: Icons.visibility_off_outlined, color: kPurple, title: 'No selling or sharing', number: 4, body: 'We do not sell your data or share it with advertisers. We share payment details only with the payment provider needed to verify your transaction.'),
        _SectionCard(icon: Icons.tune, color: kRed, title: 'Your controls', number: 5, body: 'You can edit your details in Account Settings and erase all business records at any time using Clear Sample / All Data.'),
      ],
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Terms of Service â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const _InfoPage(
      title: 'Terms of Service',
      icon: Icons.description_outlined,
      heading: 'Terms and conditions',
      intro: 'By using TindaFlow you agree to the terms below. Please read them carefully.',
      footer: 'Last updated: November 2026',
      children: [
        _SectionCard(icon: Icons.check_circle_outline, title: 'Using the app', number: 1, body: 'TindaFlow helps you record and review your business activity. You must provide accurate information and keep your login details private.'),
        _SectionCard(icon: Icons.calculate_outlined, color: kGreen, title: 'Estimates only', number: 2, body: 'Profit and balance figures are estimates based on the prices and costs you enter. They are not accounting, tax or legal advice.'),
        _SectionCard(icon: Icons.workspace_premium, color: kOrange, title: 'Premium subscription', number: 3, body: 'Premium costs ₱39 per month, paid through GCash. It is activated only after the payment has been received and verified. Unverified or failed payments do not activate Premium.'),
        _SectionCard(icon: Icons.lock_outline, color: kPurple, title: 'Your responsibility', number: 4, body: 'You are responsible for the accuracy of your records and for keeping your device secure and backed up.'),
        _SectionCard(icon: Icons.update, color: kRed, title: 'Changes to these terms', number: 5, body: 'We may update these terms as the app evolves. Continued use after an update means you accept the new terms.'),
      ],
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ Contact Support â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  Widget _contact(BuildContext context, IconData icon, String label, String value, {Color color = kBlue, bool copy = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(border: const Color(0xFFE3ECF7)),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: ts(9, c: kMuted)),
            Text(value, style: ts(11.5, w: FontWeight.w700)),
          ]),
        ),
        if (copy)
          IconButton(
            icon: const Icon(Icons.copy, size: 17, color: kBlue),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              snack(context, 'Copied');
            },
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _InfoPage(
      title: 'Contact Support',
      icon: Icons.headset_mic_outlined,
      heading: "We're here to help",
      intro: 'Questions about your account, a payment or a feature? Reach our team and we will get back to you.',
      children: [
        _heading('Get in touch'),
        _contact(context, Icons.mail_outline, 'Email', 'tindaflowofficial@gmail.com', copy: true),
        _contact(context, Icons.schedule, 'Support hours', 'Mon – Sat, 9:00 AM – 6:00 PM', color: kGreen),
        _contact(context, Icons.timer_outlined, 'Typical response time', 'Within 1 business day', color: kOrange),
        _heading('Before you contact us'),
        const _SectionCard(icon: Icons.confirmation_number_outlined, color: kBlue, title: 'Include your details', body: 'Tell us your registered email and describe what happened. For payment concerns, include your TF- reference number.'),
        const _SectionCard(icon: Icons.screenshot_outlined, color: kPurple, title: 'Add a screenshot', body: 'A screenshot of the problem or your GCash receipt helps us resolve things faster.'),
      ],
    );
  }
}
