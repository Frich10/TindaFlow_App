import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tindaflow_app/data/models.dart';
import 'package:tindaflow_app/data/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppStore> freshStore() async {
    SharedPreferences.setMockInitialValues({});
    final s = AppStore();
    await s.load();
    await s.signUp(fullName: 'Nena Dela Cruz', username: 'nena', email: 'nena@mail.com', password: 'Secret123');
    s.clearAllData();
    return s;
  }

  test('login requires matching credentials', () async {
    final s = await freshStore();
    s.logout();
    expect(s.login(username: 'nena', email: 'nena@mail.com', password: 'wrong', remember: true), isFalse);
    expect(s.login(username: 'NENA', email: 'nena@mail.com', password: 'Secret123', remember: true), isTrue);
  });

  test('loginAsync falls back to local cache without Firebase', () async {
    final s = await freshStore();
    s.logout();
    final wrong = await s.loginAsync(email: 'nena@mail.com', password: 'nope', remember: false);
    expect(wrong, LoginResult.failed);
    final ok = await s.loginAsync(email: 'NENA@mail.com', password: 'Secret123', remember: true);
    expect(ok, LoginResult.success);
    expect(s.loggedIn, isTrue);
  });

  test('deleteAccount clears the local session', () async {
    final s = await freshStore();
    expect(s.account, isNotNull);
    await s.deleteAccount();
    expect(s.account, isNull);
    expect(s.loggedIn, isFalse);
  });

  test('completing a sale reduces stock and updates totals', () async {
    final s = await freshStore();
    final p = Product(id: 'p1', name: 'Coke', category: 'Drinks', cost: 18, price: 25, stock: 10);
    s.addProduct(p);
    expect(s.addToCart(p), isNull);
    s.setCartQty(s.cart.first, 3);
    final sale = s.completeSale(method: 'Cash', received: 100);
    expect(sale.total, 75);
    expect(s.productById('p1')!.stock, 7);
    expect(s.totalSales, 75);
    expect(s.cart, isEmpty);
    s.deleteSale(sale.id);
    expect(s.productById('p1')!.stock, 10);
  });

  test('gcash balance follows cash-in / cash-out', () async {
    final s = await freshStore();
    s.setGcashOpening(1000);
    s.addGcash(GcashTx(id: 'a', name: 'A', phone: '0912', amount: 500, fee: 5, type: kCashOut, date: DateTime.now(), ref: '1'));
    s.addGcash(GcashTx(id: 'b', name: 'B', phone: '0912', amount: 200, fee: 5, type: kCashIn, date: DateTime.now(), ref: '2'));
    expect(s.gcashBalance, 1300);
    expect(s.gcashFees, 10);
  });
}
