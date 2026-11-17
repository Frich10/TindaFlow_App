import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import '../core/theme.dart';
import 'models.dart';

/// Free plan limits.
const int kFreeProductLimit = 30;
const int kFreeHistoryDays = 7;

/// Outcome of a login attempt, so the UI can show an accurate message.
enum LoginResult {
  /// Logged in successfully.
  success,

  /// The server (or local cache) rejected the password for a real account.
  wrongPassword,

  /// No account exists for that email — it must be registered first.
  noAccount,

  /// Login failed for a reason that is not the credentials (offline, error).
  failed,
}

/// One row in "Recent Transactions".
class Activity {
  const Activity({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.positive,
    required this.icon,
    required this.color,
    required this.date,
  });
  final String title;
  final String subtitle;
  final double amount;
  final bool positive;
  final IconData icon;
  final Color color;
  final DateTime date;
}

/// Single source of truth for the whole app. Persists to SharedPreferences.

Map<String, dynamic> _toStringDynamicMap(Map<Object?, Object?> map) {
  return map.map((k, v) => MapEntry(k.toString(), v));
}

class AppStore extends ChangeNotifier {
  SharedPreferences? _prefs;

  /// Selected bottom-nav tab (0 Home, 1 Sales, 2 Stocks, 3 Debt, 4 Profile).
  final ValueNotifier<int> tab = ValueNotifier<int>(0);

  Account? account;
  bool loggedIn = false;
  bool onboardingSeen = false;
  bool skipItemDeleteConfirm = false;

  /// Salted SHA-256 hash of the 6-digit MPIN. Null when no MPIN is set.
  /// Stored locally only (device security).
  String? mpinHash;
  /// Runtime flag: true once the user has entered the correct MPIN this session.
  /// Not persisted — reset to false on every cold start.
  bool appUnlocked = false;

  BusinessProfile profile = BusinessProfile();
  double gcashOpening = 0;
  String plan = 'Free';
  DateTime? subscriptionStart;
  DateTime? subscriptionEnd;
  DateTime? lastAlertViewed;
  String? lastAlertHash;

  List<Product> products = [];
  List<StockMove> moves = [];
  List<Sale> sales = [];
  List<GcashTx> gcash = [];
  List<Expense> expenses = [];
  List<Debt> debts = [];
  final List<SaleItem> cart = [];

  /// Extra product categories the user created via the "Others" option.
  List<String> customCategories = [];

  bool get hasAccount => account != null;

  /// True when an MPIN has been set by the user.
  bool get hasMpin => mpinHash != null && mpinHash!.isNotEmpty;

  /// True while the Premium plan is active. Free users only get the basic features.
  bool get isPremium => plan == 'Premium';

  /// Free plan only sees sales in Recent Transactions; Premium sees everything.
  List<Activity> get visibleActivities =>
      isPremium ? activities : activities.where((a) => a.title == 'Sale').toList();

  // ───────────────────────── persistence ─────────────────────────
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    onboardingSeen = p.getBool('onboarding') ?? false;
    loggedIn = p.getBool('session') ?? false;
    final acc = p.getString('account');
    if (acc != null) {
      try {
        account = Account.fromJson(jsonDecode(acc) as Map<String, dynamic>);
      } catch (_) {
        account = null;
      }
    }
    // MPIN is per-account: load it only after we know the account email.
    mpinHash = _loadMpinHash();
    final raw = p.getString('data');
    if (raw != null) {
      try {
        _decode(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {/* corrupt data -> start clean */}
    }
    if (account == null) loggedIn = false;
  }

  List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
      ((v as List?) ?? []).whereType<Map>().map((e) => f(_toStringDynamicMap(e as Map<Object?, Object?>))).toList();

  void _decode(Map<String, dynamic> j) {
    profile = BusinessProfile.fromJson((j['profile'] as Map<String, dynamic>?) ?? {});
    gcashOpening = ((j['gcashOpening'] as num?) ?? 0).toDouble();
    plan = (j['plan'] as String?) ?? 'Free';
    subscriptionStart = j['subscriptionStart'] == null ? null : DateTime.parse(j['subscriptionStart'] as String);
    subscriptionEnd = j['subscriptionEnd'] == null ? null : DateTime.parse(j['subscriptionEnd'] as String);
    lastAlertViewed = j['lastAlertViewed'] == null ? null : DateTime.parse(j['lastAlertViewed'] as String);
    lastAlertHash = j['lastAlertHash'] as String?;
    products = _list(j['products'], Product.fromJson);
    moves = _list(j['moves'], StockMove.fromJson);
    sales = _list(j['sales'], Sale.fromJson);
    gcash = _list(j['gcash'], GcashTx.fromJson);
    expenses = _list(j['expenses'], Expense.fromJson);
    debts = _list(j['debts'], Debt.fromJson);
    customCategories = ((j['customCategories'] as List?) ?? [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }



  void _persist() {
    final p = _prefs;
    if (p == null) return;
    String encoded(bool includePhotos) => jsonEncode({
          'profile': profile.toJson(),
          'gcashOpening': gcashOpening,
          'plan': plan,
          'subscriptionStart': subscriptionStart?.toIso8601String(),
          'subscriptionEnd': subscriptionEnd?.toIso8601String(),
          'lastAlertViewed': lastAlertViewed?.toIso8601String(),
          'lastAlertHash': lastAlertHash,
          'products': products.map((e) {
            final j = e.toJson();
            if (!includePhotos) j['photo'] = null;
            return j;
          }).toList(),
          'moves': moves.map((e) => e.toJson()).toList(),
          'sales': sales.map((e) => e.toJson()).toList(),
          'gcash': gcash.map((e) => e.toJson()).toList(),
          'expenses': expenses.map((e) => e.toJson()).toList(),
          'debts': debts.map((e) => e.toJson()).toList(),
          'customCategories': customCategories,
        });
    try {
      p.setString('data', encoded(true));
    } catch (e) {
      // Storage is full (common on web where the whole blob must fit in a few MB).
      // Retry without base64 product photos.
      debugPrint('[AppStore] persist full failed, retrying without photos: $e');
      try {
        p.setString('data', encoded(false));
      } catch (e2) {
        debugPrint('[AppStore] persist failed: $e2');
      }
    }
  }

  void _commit() {
    _persist();
    notifyListeners();
  }

  /// Call after mutating fields of [profile] directly.
  void saveProfile() => _commit();

  /// Refreshes state from local storage.
  Future<void> refresh() async {
    notifyListeners();
  }

  // ───────────────────────── auth ─────────────────────────
  String _hash(String pw) => sha256.convert(utf8.encode('tindaflow::$pw')).toString();

  Future<void> setOnboardingSeen() async {
    onboardingSeen = true;
    await _prefs?.setBool('onboarding', true);
  }

  /// Creates a new account. Returns false when the email is already registered
  /// locally, so the caller can show a duplicate-email error.
  Future<bool> signUp({
    required String fullName,
    required String username,
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();

    // Local-only: reject if this device already holds that account.
    if (account != null && account!.email == normalized) {
      return false;
    }

    account = Account(
      fullName: fullName.trim(),
      username: username.trim(),
      email: normalized,
      passHash: _hash(password),
    );
    final first = fullName.trim().split(' ').first;
    profile = BusinessProfile(ownerName: fullName.trim(), storeName: "$first's Sari-sari Store");
    products = [];
    moves = [];
    sales = [];
    gcash = [];
    expenses = [];
    debts = [];
    cart.clear();
    gcashOpening = 0.0;
    plan = 'Free';
    loggedIn = true;
    tab.value = 0;
    appUnlocked = false;
    mpinHash = _loadMpinHash();
    await _prefs?.setString('account', jsonEncode(account!.toJson()));
    await _prefs?.setBool('session', true);
    _commit();
    return true;
  }

  bool login({String? username, required String email, required String password, required bool remember}) {
    final a = account;
    if (a == null) return false;
    final ok = a.email == email.trim().toLowerCase() &&
        a.passHash == _hash(password);
    if (!ok) return false;
    loggedIn = true;
    tab.value = 0;
    appUnlocked = false;
    mpinHash = _loadMpinHash();
    _prefs?.setBool('session', remember);
    notifyListeners();
    return true;
  }

  /// Authenticates against the locally stored account.
  ///
  /// Returns a [LoginResult] describing the outcome so the UI can show an
  /// accurate message ("no account" vs "wrong password").
  Future<LoginResult> loginAsync({
    String? username,
    required String email,
    required String password,
    required bool remember,
  }) async {
    final normalized = email.trim().toLowerCase();
    final a = account;
    if (a == null || a.email != normalized) return LoginResult.noAccount;
    if (a.passHash != _hash(password)) return LoginResult.wrongPassword;
    login(email: normalized, password: password, remember: remember);
    return LoginResult.success;
  }

  void logout() {
    loggedIn = false;
    appUnlocked = false;
    cart.clear();
    tab.value = 0;
    _prefs?.setBool('session', false);
    notifyListeners();
  }

  /// Permanently deletes this account and wipes the local session.
  Future<bool> deleteAccount() async {
    final a = account;
    if (a == null) return false;
    account = null;
    loggedIn = false;
    appUnlocked = false;
    cart.clear();
    tab.value = 0;
    await _prefs?.remove('account');
    await _prefs?.setBool('session', false);
    notifyListeners();
    return true;
  }

  // ───────────────────────── MPIN (app lock) ─────────────────────────
  /// Validates that [pin] is exactly 6 digits. Returns an error message or null.
  String? mpinError(String pin) {
    if (pin.isEmpty) return 'Please enter a 6-digit MPIN';
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) return 'MPIN must be exactly 6 digits';
    return null;
  }

  /// Per-account SharedPreferences key for the MPIN hash. Each account has its
  /// own MPIN, so switching accounts never inherits another account's PIN.
  String? _mpinKey() {
    final email = account?.email;
    if (email == null || email.trim().isEmpty) return null;
    final safe = email.trim().toLowerCase().replaceAll(RegExp(r'[.#$\[\]/]'), '_');
    return 'mpin_$safe';
  }

  String? _loadMpinHash() {
    final k = _mpinKey();
    if (k == null) return null;
    return _prefs?.getString(k);
  }

  /// Sets (or replaces) the MPIN for the current account. Returns true on success.
  bool setMpin(String pin) {
    final err = mpinError(pin);
    if (err != null) return false;
    final k = _mpinKey();
    if (k == null) return false;
    mpinHash = _hash(pin);
    appUnlocked = true;
    _prefs?.setString(k, mpinHash!);
    _persist();
    notifyListeners();
    return true;
  }

  /// Removes the MPIN for the current account (disables the app lock).
  void removeMpin() {
    final k = _mpinKey();
    if (k != null) _prefs?.remove(k);
    mpinHash = null;
    _persist();
    notifyListeners();
  }

  /// Verifies [pin] against the current account's stored MPIN hash.
  bool verifyMpin(String pin) {
    if (!hasMpin) return false;
    return mpinHash == _hash(pin);
  }

  /// Marks the app as unlocked for this session (call after correct MPIN entry).
  void unlockApp() {
    appUnlocked = true;
    notifyListeners();
  }

  bool changePassword(String current, String next) {
    final a = account;
    if (a == null || a.passHash != _hash(current)) return false;
    a.passHash = _hash(next);
    _prefs?.setString('account', jsonEncode(a.toJson()));
    return true;
  }

  bool resetPassword(String email, String next) {
    final a = account;
    if (a == null || a.email != email.trim().toLowerCase()) return false;
    a.passHash = _hash(next);
    _prefs?.setString('account', jsonEncode(a.toJson()));
    return true;
  }

  Future<bool> resetPasswordAsync(String email, String next) async {
    final a = account;
    if (a != null && a.email == email.trim().toLowerCase()) {
      a.passHash = _hash(next);
      await _prefs?.setString('account', jsonEncode(a.toJson()));
      return true;
    }
    return false;
  }

  void updateEmail(String nextEmail) {
    final a = account;
    if (a == null) return;
    a.email = nextEmail.trim().toLowerCase();
    _prefs?.setString('account', jsonEncode(a.toJson()));
    notifyListeners();
  }

  Future<void> clearAllData() async {
    products = [];
    moves = [];
    sales = [];
    gcash = [];
    expenses = [];
    debts = [];
    cart.clear();
    gcashOpening = 0.0;
    _commit();
  }

  // ───────────────────────── products / stock ─────────────────────────
  Product? productById(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Built-in categories plus any custom ones the user added.
  /// "Others" is always kept at the end so custom categories appear before it.
  List<String> get allCategories {
    const others = 'Others';
    final seen = <String>{};
    final out = <String>[];
    void add(String c) {
      if (c.trim().isEmpty) return;
      if (c == others) return;
      if (seen.add(c.toLowerCase())) out.add(c);
    }

    for (final c in kProductCategories) {
      add(c);
    }
    for (final c in customCategories) {
      add(c);
    }
    out.add(others);
    return out;
  }

  /// Remembers a newly typed category so it shows up in the dropdown next time.
  void addCategory(String category) {
    final c = category.trim();
    if (c.isEmpty) return;
    if (kProductCategories.contains(c)) return;
    if (customCategories.any((e) => e.toLowerCase() == c.toLowerCase())) return;
    customCategories.add(c);
    _commit();
  }

  void _move(String id, int delta, String reason) {
    moves.add(StockMove(productId: id, date: DateTime.now(), delta: delta, reason: reason));
    if (moves.length > 600) moves.removeRange(0, moves.length - 600);
  }

  void addProduct(Product p) {
    products.add(p);
    if (p.stock > 0) _move(p.id, p.stock, 'Stock In');
    _commit();
  }

  void updateProduct(Product p) {
    final i = products.indexWhere((x) => x.id == p.id);
    if (i < 0) return;
    final diff = p.stock - products[i].stock;
    products[i] = p;
    if (diff != 0) _move(p.id, diff, diff > 0 ? 'Stock In' : 'Adjusted');
    _commit();
  }

  void restock(String id, int qty) {
    final p = productById(id);
    if (p == null || qty <= 0) return;
    p.stock += qty;
    _move(id, qty, 'Stock In');
    _commit();
  }

  void deleteProduct(String id) {
    products.removeWhere((p) => p.id == id);
    cart.removeWhere((c) => c.productId == id);
    moves.removeWhere((m) => m.productId == id);
    _commit();
  }

  List<StockMove> movesFor(String id) {
    final l = moves.where((m) => m.productId == id).toList();
    l.sort((a, b) => b.date.compareTo(a.date));
    return l;
  }

  List<Product> get lowStockProducts => products.where((p) => p.stock <= kLowStock).toList();

  // ───────────────────────── cart & sales ─────────────────────────
  int get cartCount => cart.fold(0, (s, i) => s + i.qty);
  double get cartTotal => cart.fold(0.0, (s, i) => s + i.price * i.qty);

  /// Returns an error message, or null when added.
  String? addToCart(Product p) {
    final i = cart.indexWhere((c) => c.productId == p.id);
    if (i >= 0) {
      if (cart[i].qty >= p.stock) return 'Only ${p.stock} in stock';
      cart[i].qty++;
    } else {
      if (p.stock <= 0) return '${p.name} is out of stock';
      cart.add(SaleItem(productId: p.id, name: p.name, price: p.price, cost: p.cost, qty: 1));
    }
    notifyListeners();
    return null;
  }

  /// Returns an error message, or null when OK.
  String? setCartQty(SaleItem item, int qty) {
    if (qty < 1) return null;
    final p = productById(item.productId);
    if (p != null && qty > p.stock) return 'Only ${p.stock} in stock';
    item.qty = qty;
    notifyListeners();
    return null;
  }

  void removeFromCart(SaleItem item) {
    cart.remove(item);
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    notifyListeners();
  }

  Sale completeSale({required String method, required double received}) {
    final items = List<SaleItem>.of(cart);
    final total = cartTotal;
    for (final c in items) {
      final p = productById(c.productId);
      if (p != null) {
        p.stock = max(0, p.stock - c.qty);
        _move(p.id, -c.qty, 'Sale');
      }
    }
    final sale = Sale(
      id: newId(),
      date: DateTime.now(),
      items: items,
      method: method,
      total: total,
      received: received,
    );
    sales.insert(0, sale);
    cart.clear();
    _commit();
    return sale;
  }

  void deleteSale(String id) {
    final i = sales.indexWhere((s) => s.id == id);
    if (i < 0) return;
    for (final it in sales[i].items) {
      final p = productById(it.productId);
      if (p != null) {
        p.stock += it.qty;
        _move(p.id, it.qty, 'Stock In');
      }
    }
    sales.removeAt(i);
    _commit();
  }

  // ───────────────────────── gcash ─────────────────────────
  void addGcash(GcashTx t) {
    gcash.insert(0, t);
    _commit();
  }

  void updateGcash(GcashTx t) {
    final i = gcash.indexWhere((x) => x.id == t.id);
    if (i >= 0) gcash[i] = t;
    _commit();
  }

  void deleteGcash(String id) {
    gcash.removeWhere((x) => x.id == id);
    _commit();
  }

  void setGcashOpening(double v) {
    gcashOpening = v;
    _commit();
  }

  /// Cash-out adds to the GCash wallet, cash-in takes from it.
  /// GCash sales add to it, GCash-paid expenses take from it.
  double get gcashBalance {
    var b = gcashOpening;
    for (final g in gcash) {
      b += g.isIn ? -g.amount : g.amount;
    }
    for (final s in sales) {
      if (s.method == 'Gcash') b += s.total;
    }
    for (final e in expenses) {
      if (e.method == 'Gcash') b -= e.amount;
    }
    return b;
  }

  GcashTx? gcashById(String id) {
    for (final g in gcash) {
      if (g.id == id) return g;
    }
    return null;
  }

  // ───────────────────────── expenses ─────────────────────────
  void addExpense(Expense e) {
    expenses.insert(0, e);
    _commit();
  }

  void updateExpense(Expense e) {
    final i = expenses.indexWhere((x) => x.id == e.id);
    if (i >= 0) expenses[i] = e;
    _commit();
  }

  void deleteExpense(String id) {
    expenses.removeWhere((x) => x.id == id);
    _commit();
  }

  Expense? expenseById(String id) {
    for (final e in expenses) {
      if (e.id == id) return e;
    }
    return null;
  }

  // ───────────────────────── debts ─────────────────────────
  void addDebt(Debt d) {
    debts.insert(0, d);
    _commit();
  }

  void updateDebt(Debt d) {
    final i = debts.indexWhere((x) => x.id == d.id);
    if (i >= 0) debts[i] = d;
    _commit();
  }

  void deleteDebt(String id) {
    debts.removeWhere((x) => x.id == id);
    _commit();
  }

  void setDebtPaid(String id, bool paid) {
    for (final d in debts) {
      if (d.id == id) d.paid = paid;
    }
    _commit();
  }

  Debt? debtById(String id) {
    for (final d in debts) {
      if (d.id == id) return d;
    }
    return null;
  }

  List<Debt> get dueDebts {
    final limit = DateTime.now().add(const Duration(days: 3));
    return debts.where((d) => !d.paid && d.dueDate.isBefore(limit)).toList();
  }

  String _computeAlertHash() {
    final lowIds = lowStockProducts.map((p) => p.id).toList()..sort();
    final dueIds = dueDebts.map((d) => d.id).toList()..sort();
    return '${lowIds.join(',')}|${dueIds.join(',')}';
  }

  bool get hasAlerts {
    final low = lowStockProducts;
    final due = dueDebts;
    if (low.isEmpty && due.isEmpty) return false;
    final currentHash = _computeAlertHash();
    return lastAlertHash != currentHash;
  }

  void markAlertsViewed() {
    lastAlertViewed = DateTime.now();
    lastAlertHash = _computeAlertHash();
    _commit();
  }

  void setPlan(String p) {
    if (p == 'Premium' && plan != 'Premium') {
      final now = DateTime.now();
      subscriptionStart = now;
      subscriptionEnd = now.add(const Duration(days: 30));
    }
    plan = p;
    _commit();
  }

  // ───────────────────────── dashboard numbers ─────────────────────────
  double get totalSales => sales.fold(0.0, (s, e) => s + e.total);
  double get totalExpenses => expenses.fold(0.0, (s, e) => s + e.amount);
  double get gcashFees => gcash.fold(0.0, (s, e) => s + e.fee);

  /// Estimated profit = sales margin + GCash fees − expenses.
  double get totalProfit => sales.fold(0.0, (s, e) => s + e.profit) + gcashFees - totalExpenses;

  List<Activity> get activities {
    final out = <Activity>[];
    for (final s in sales) {
      out.add(Activity(
          title: 'Sale', subtitle: fmtDateTime(s.date), amount: s.total, positive: true,
          icon: Icons.shopping_cart, color: kGreen, date: s.date));
    }
    for (final g in gcash) {
      out.add(Activity(
          title: g.type, subtitle: fmtDateTime(g.date), amount: g.amount, positive: !g.isIn,
          icon: Icons.account_balance_wallet, color: kBlue, date: g.date));
    }
    for (final d in debts) {
      out.add(Activity(
          title: 'Debt', subtitle: fmtDateTime(d.debtDate), amount: d.total, positive: false,
          icon: Icons.people_alt, color: kRed, date: d.debtDate));
    }
    for (final e in expenses) {
      out.add(Activity(
          title: 'Expense', subtitle: fmtDateTime(e.date), amount: e.amount, positive: false,
          icon: Icons.receipt_long, color: kOrange, date: e.date));
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }
}

final AppStore store = AppStore();