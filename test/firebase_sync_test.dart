import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tindaflow_app/data/firebase_sync.dart';
import 'package:tindaflow_app/data/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('safeUserKey sanitizes invalid Firebase RTDB characters', () {
    expect(
      FirebaseSyncService.safeUserKey(r'My.Store#1$User[Test]@Gmail.Com'),
      'my_store_1_user_test_@gmail_com',
    );
  });

  test('AppStore applies remote Firebase data correctly', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppStore();
    await s.load();

    final testData = <String, dynamic>{
      'plan': 'Premium',
      'gcashOpening': 2500.0,
      'profile': {
        'ownerName': 'Rosa Santos',
        'storeName': "Rosa's Mini Mart",
        'businessType': 'Sari-Sari Store',
        'phone': '09171234567',
        'address': 'Barangay 1',
      },
      'products': {
        'p1': {
          'id': 'p1',
          'name': 'Coke 1.5L',
          'category': 'Drinks',
          'cost': 55.0,
          'price': 70.0,
          'stock': 24,
        },
      },
      'sales': {
        's1': {
          'id': 's1',
          'date': DateTime.now().toIso8601String(),
          'method': 'Cash',
          'total': 140.0,
          'received': 150.0,
          'items': [
            {'productId': 'p1', 'name': 'Coke 1.5L', 'price': 70.0, 'cost': 55.0, 'qty': 2}
          ],
        },
      },
    };

    s.applyRemoteData(testData);

    expect(s.plan, 'Premium');
    expect(s.isPremium, isTrue);
    expect(s.gcashOpening, 2500.0);
    expect(s.profile.storeName, "Rosa's Mini Mart");
    expect(s.products.length, 1);
    expect(s.products.first.name, 'Coke 1.5L');
    expect(s.sales.length, 1);
    expect(s.sales.first.total, 140.0);
  });
}
