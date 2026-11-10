import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/firebase_sync.dart';
import '../data/store.dart';
import '../data/subscription_service.dart';
import '../widgets/common.dart';
import 'debt_screens.dart';
import 'expense_screens.dart';
import 'gcash_screens.dart';
import 'profile_screens.dart';
import 'sales_screens.dart';
import 'stock_screens.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  @override
  void initState() {
    super.initState();
    subscription.ensureLoaded(); // ends an expired Premium plan as soon as the app opens
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: store.tab,
      builder: (context, index, _) => Scaffold(
        body: IndexedStack(
          index: index,
          children: const [HomeTab(), SalesTab(), StocksTab(), DebtTab(), ProfileTab()],
        ),
        bottomNavigationBar: _NavBar(index: index, onTap: (v) {
          if (v == 3 && !requirePremium(context, 'Customer credit tracking (Debt)')) return;
          store.tab.value = v;
        }),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const items = <(IconData, String)>[
      (Icons.home_filled, 'Home'),
      (Icons.bar_chart_rounded, 'Sales'),
      (Icons.inventory_2, 'Stocks'),
      (Icons.people_alt, 'Debt'),
      (Icons.person, 'Profile'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(items[i].$1, size: 22, color: i == index ? kBlue : const Color(0xFF3B5A8C)),
                    const SizedBox(height: 3),
                    Text(items[i].$2,
                        style: ts(9.5, w: FontWeight.w600, c: i == index ? kBlue : const Color(0xFF3B5A8C))),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── Home ─────────────────────────

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final first = store.profile.ownerName.trim().isEmpty ? 'there' : store.profile.ownerName.trim().split(' ').first;
      final prem = store.isPremium;
      final recent = store.visibleActivities.take(6).toList();
      return BluePage(
        header: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 6, 14),
          child: Row(children: [
            
        Builder(
          builder: (context) {
            final photo = store.profile.photo;

            if (photo != null && photo.isNotEmpty) {
              return ClipOval(
                child: Image.memory(
                  decodeImg(photo),
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              );
            }

            return Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 22,
              ),
            );
          },
        ),

            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hello, $first', style: ts(13, w: FontWeight.w600, c: Colors.white)),
                Text('Good day! Keep it up!', style: ts(9.5, c: Colors.white70)),
              ]),
            ),
            HeaderIcon(Icons.notifications, badge: store.hasAlerts, onTap: () => showAlerts(context)),
          ]),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            Row(children: [
              Expanded(child: _Summary(Icons.shopping_cart, 'Total Sales', peso(store.totalSales), kGreen, kGreenTint)),
              const SizedBox(width: 10),
              Expanded(child: _lockable(context, !prem, 'Estimated profit calculation', _Summary(Icons.attach_money, 'Total Profit', peso(store.totalProfit.abs()), kPurple, kPurpleTint, locked: !prem))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _lockable(context, !prem, 'Income & expense tracking', _Summary(Icons.receipt_long, 'Total Expenses', peso(store.totalExpenses), kOrange, kOrangeTint, locked: !prem))),
              const SizedBox(width: 10),
              Expanded(child: _lockable(context, !prem, 'GCash cash-in / cash-out recording', _Summary(null, 'Gcash Balance', peso(store.gcashBalance), kBlue, kBlueTint, locked: !prem))),
            ]),
            const SizedBox(height: 16),
            Text('Quick Actions', style: ts(12, w: FontWeight.w700, c: kBlue)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _Quick(Icons.shopping_cart, 'New Sale', kGreen, () => store.tab.value = 1)),
              const SizedBox(width: 10),
              Expanded(child: _Quick(null, 'Gcash', kBlue, () {
                if (requirePremium(context, 'GCash cash-in / cash-out recording')) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GcashScreen()));
                }
              }, locked: !prem)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _Quick(Icons.receipt_long, 'Expense', kOrange, () {
                if (requirePremium(context, 'Income & expense tracking')) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExpensesScreen()));
                }
              }, locked: !prem)),
              const SizedBox(width: 10),
              Expanded(child: _Quick(Icons.people_alt, 'Debts', kRed, () {
                if (requirePremium(context, 'Customer credit tracking (Debt)')) store.tab.value = 3;
              }, locked: !prem)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Text('Recent Transactions', style: ts(12, w: FontWeight.w700, c: kBlue)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AllActivityScreen())),
                child: Text('View All', style: ts(10, w: FontWeight.w700, c: kBlue)),
              ),
            ]),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: cardDeco(border: const Color(0xFFE3ECF7)),
              child: recent.isEmpty
                  ? const EmptyState(Icons.receipt_long, 'No transactions yet.\nRecord a sale to get started.')
                  : Column(children: [for (final a in recent) ActivityTile(a)]),
            ),
          ],
        ),
      );
    });
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.icon, this.label, this.value, this.color, this.bg, {this.locked = false});
  final bool locked;
  final IconData? icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: cardDeco(color: bg, border: color.withValues(alpha: 0.45)),
      child: Row(children: [
        
      icon == null
          ? Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: Color(0xFF1468F5),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
                child: Image.asset(
                  'assets/images/gcash_logo.png',
                  width: 16,
                  height: 16,
                  fit: BoxFit.contain,
                ),
              ),
            )
          : CircleIcon(icon!, color: color, size: 26),

        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: ts(9, w: FontWeight.w600, c: color)),
            locked
                ? Row(children: [
                    Icon(Icons.lock, size: 12, color: color),
                    const SizedBox(width: 4),
                    Text('Premium', style: ts(12, w: FontWeight.w700, c: color)),
                  ])
                : Text(value, style: ts(15, w: FontWeight.w700, c: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}

/// Makes a card tappable (opens the Premium modal) while it is locked.
Widget _lockable(BuildContext context, bool locked, String feature, Widget child) =>
    locked ? GestureDetector(onTap: () => requirePremium(context, feature), child: child) : child;

class _Quick extends StatelessWidget {
  const _Quick(this.icon, this.label, this.color, this.onTap, {this.locked = false});
  final bool locked;
  final IconData? icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (label == 'Expense')
                Image.asset(
                  'assets/images/expense_icon.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                )
              else if (icon == null)
                ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    'assets/images/gcash_logo.png',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                  ),
                )
              else
                Icon(icon, color: Colors.white, size: 20),

              const SizedBox(width: 8),
              Text(
                label,
                style: ts(12, w: FontWeight.w700, c: Colors.white),
              ),
              if (locked) ...[
                const SizedBox(width: 6),
                const Icon(Icons.lock, size: 13, color: Colors.white70),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AllActivityScreen extends StatelessWidget {
  const AllActivityScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final all = store.visibleActivities;
      return BluePage(
        back: true,
        title: 'Recent Transactions',
        child: all.isEmpty
            ? const EmptyState(Icons.receipt_long, 'No transactions yet.')
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: cardDeco(border: const Color(0xFFE3ECF7)),
                    child: Column(children: [for (final a in all) ActivityTile(a)]),
                  ),
                ],
              ),
      );
    });
  }
}