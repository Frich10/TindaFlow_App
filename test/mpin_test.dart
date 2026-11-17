import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('no MPIN by default', () async {
    final s = await freshStore();
    expect(s.hasMpin, isFalse);
    expect(s.verifyMpin('123456'), isFalse);
  });

  test('setMpin stores a hash and verifyMpin accepts the right PIN', () async {
    final s = await freshStore();
    expect(s.setMpin('135790'), isTrue);
    expect(s.hasMpin, isTrue);
    expect(s.appUnlocked, isTrue);
    expect(s.verifyMpin('135790'), isTrue);
    expect(s.verifyMpin('000000'), isFalse);
  });

  test('setMpin rejects non 6-digit PINs', () async {
    final s = await freshStore();
    expect(s.setMpin('12345'), isFalse);
    expect(s.setMpin('1234567'), isFalse);
    expect(s.setMpin('abcdef'), isFalse);
    expect(s.hasMpin, isFalse);
  });

  test('MPIN persists across reload (stored in prefs data)', () async {
    SharedPreferences.setMockInitialValues({});
    final s1 = AppStore();
    await s1.load();
    await s1.signUp(fullName: 'Nena', username: 'nena', email: 'nena@mail.com', password: 'Secret123');
    s1.clearAllData();
    s1.setMpin('246810');
    s1.logout();

    // Reload from the same prefs instance.
    final s2 = AppStore();
    await s2.load();
    expect(s2.hasMpin, isTrue);
    expect(s2.verifyMpin('246810'), isTrue);
    expect(s2.verifyMpin('111111'), isFalse);
    // appUnlocked is runtime-only, reset on cold start.
    expect(s2.appUnlocked, isFalse);
  });

  test('removeMpin disables the lock', () async {
    final s = await freshStore();
    s.setMpin('112233');
    expect(s.hasMpin, isTrue);
    s.removeMpin();
    expect(s.hasMpin, isFalse);
    expect(s.verifyMpin('112233'), isFalse);
  });

  test('logout resets the runtime unlock flag', () async {
    final s = await freshStore();
    s.setMpin('998877');
    expect(s.appUnlocked, isTrue);
    s.logout();
    expect(s.appUnlocked, isFalse);
    expect(s.hasMpin, isTrue);
  });

  test('each account has its own MPIN (switching accounts does not inherit)', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppStore();
    await s.load();

    // Account A sets an MPIN.
    await s.signUp(fullName: 'Nena', username: 'nena', email: 'nena@mail.com', password: 'Secret123');
    s.clearAllData();
    expect(s.setMpin('111111'), isTrue);
    expect(s.verifyMpin('111111'), isTrue);
    s.logout();

    // Switch to account B: it must have NO MPIN of its own.
    await s.signUp(fullName: 'Rosa', username: 'rosa', email: 'rosa@mail.com', password: 'Secret456');
    s.clearAllData();
    expect(s.hasMpin, isFalse, reason: 'Account B should not inherit A MPIN');
    expect(s.verifyMpin('111111'), isFalse);
    expect(s.setMpin('222222'), isTrue);
    expect(s.verifyMpin('222222'), isTrue);
    expect(s.verifyMpin('111111'), isFalse);
    s.logout();

    // The two accounts stored different hashes under different keys.
    final prefs = await SharedPreferences.getInstance();
    final aHash = prefs.getString('mpin_nena@mail_com');
    final bHash = prefs.getString('mpin_rosa@mail_com');
    expect(aHash, isNotNull);
    expect(bHash, isNotNull);
    expect(aHash == bHash, isFalse, reason: 'Each account must have a distinct MPIN hash');
  });
}