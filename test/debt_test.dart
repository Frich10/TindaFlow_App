import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tindaflow_app/data/models.dart';
import 'package:tindaflow_app/data/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('debt round-trip through Firebase keeps items/qty/price/total', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppStore();
    await s.load();

    final debt = Debt(
      id: 'd1',
      customer: 'Nena',
      phone: '0917',
      items: [DebtItem(name: 'Coke', qty: 3, price: 20.0), DebtItem(name: 'Bread', qty: 2, price: 15.0)],
      debtDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 1, 10),
    );
    expect(debt.total, 90.0);

    // Simulate Firebase round trip.
    final json = debt.toJson();
    final remote = <String, dynamic>{
      'debts': {
        'd1': json,
      },
    };
    s.applyRemoteData(remote);

    expect(s.debts.length, 1);
    final d = s.debts.first;
    expect(d.items.length, 2);
    expect(d.items.first.qty, 3);
    expect(d.items.first.price, 20.0);
    expect(d.total, 90.0);
  });

  test('marking paid keeps total', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppStore();
    await s.load();

    final debt = Debt(
      id: 'd1',
      customer: 'Nena',
      phone: '0917',
      items: [DebtItem(name: 'Coke', qty: 3, price: 20.0)],
      debtDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 1, 10),
    );
    s.addDebt(debt);
    s.setDebtPaid('d1', true);
    expect(s.debtById('d1')!.paid, isTrue);
    expect(s.debtById('d1')!.total, 60.0);
  });
}