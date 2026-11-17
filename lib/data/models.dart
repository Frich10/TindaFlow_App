int _seq = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch}${_seq++}';

DateTime _dt(dynamic v) {
  if (v is DateTime) return v;
  return DateTime.parse(v.toString());
}
double _num(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

int _int(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

/// Safely reads a String field. Returns [fallback] when the value is null or
/// the wrong type.
String _str(dynamic v, [String fallback = '']) {
  if (v is String) return v;
  if (v == null) return fallback;
  return fallback;
}

/// Safely reads a bool field.
bool _bool(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true';
  return fallback;
}

/// Recursively normalizes a value so map keys become Strings.
/// Scalars are preserved as-is (only the keys are stringified).
dynamic _asStringMap(dynamic v) {
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), _asStringMap(val)));
  }
  if (v is List) {
    return v.map((e) => _asStringMap(e)).toList();
  }
  return v;
}

/// Normalizes an `items` field into a list of maps.
/// Data may be stored as objects keyed "0","1",... and a corrupted/partial
/// entry can be a scalar; skip anything that is not a map.
List<Map<String, dynamic>> _itemList(dynamic v) {
  if (v is List) {
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(_asStringMap(e) as Map)).toList();
  }
  if (v is Map) {
    return v.values.whereType<Map>().map((e) => Map<String, dynamic>.from(_asStringMap(e) as Map)).toList();
  }
  return const [];
}

const kCashIn = 'Cash In';
const kCashOut = 'Cash Out';
const kLowStock = 15;
const kProductCategories = ['Canned Goods', 'Coffee', 'Chips', 'Candy', 'Drinks', 'Noodles', 'Snacks', 'Others'];
const kExpenseCategories = ['Supplies', 'Utilities', 'Transportation', 'Groceries'];
const kBusinessTypes = ['Sari-Sari Store', 'Merchandise', 'Food Stall', 'Others'];

class Product {
  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.cost,
    required this.price,
    required this.stock,
    this.photo,
  });
  String id;
  String name;
  String category;
  double cost;
  double price;
  int stock;
  String? photo; // base64

  Product copy() => Product(
      id: id, name: name, category: category, cost: cost, price: price, stock: stock, photo: photo);

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'category': category, 'cost': cost,
        'price': price, 'stock': stock, 'photo': photo,
      };
  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: _str(j['id']),
        name: _str(j['name']),
        category: _str(j['category']),
        cost: _num(j['cost']),
        price: _num(j['price']),
        stock: _int(j['stock']),
        photo: j['photo'] is String ? j['photo'] as String : null,
      );
}

class StockMove {
  StockMove({required this.productId, required this.date, required this.delta, required this.reason});
  String productId;
  DateTime date;
  int delta;
  String reason;
  Map<String, dynamic> toJson() =>
      {'productId': productId, 'date': date.toIso8601String(), 'delta': delta, 'reason': reason};
  factory StockMove.fromJson(Map<String, dynamic> j) => StockMove(
      productId: _str(j['productId']),
      date: _dt(j['date']),
      delta: _int(j['delta']),
      reason: _str(j['reason']));
}

class SaleItem {
  SaleItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.cost,
    required this.qty,
  });
  String productId;
  String name;
  double price;
  double cost;
  int qty;
  Map<String, dynamic> toJson() =>
      {'productId': productId, 'name': name, 'price': price, 'cost': cost, 'qty': qty};
  factory SaleItem.fromJson(Map<String, dynamic> j) => SaleItem(
      productId: _str(j['productId']),
      name: _str(j['name']),
      price: _num(j['price']),
      cost: _num(j['cost']),
      qty: _int(j['qty']));
}

class Sale {
  Sale({
    required this.id,
    required this.date,
    required this.items,
    required this.method,
    required this.total,
    required this.received,
  });
  String id;
  DateTime date;
  List<SaleItem> items;
  String method; // Cash | Gcash
  double total;
  double received;
  int get itemCount => items.fold(0, (s, i) => s + i.qty);
  double get profit => items.fold(0.0, (s, i) => s + (i.price - i.cost) * i.qty);
  Map<String, dynamic> toJson() => {
        'id': id, 'date': date.toIso8601String(), 'method': method, 'total': total,
        'received': received, 'items': items.map((e) => e.toJson()).toList(),
      };
  factory Sale.fromJson(Map<String, dynamic> j) => Sale(
        id: _str(j['id']),
        date: _dt(j['date']),
        method: _str(j['method']),
        total: _num(j['total']),
        received: _num(j['received']),
        items: _itemList(j['items']).map(SaleItem.fromJson).toList(),
      );
}

class GcashTx {
  GcashTx({
    required this.id,
    required this.name,
    required this.phone,
    required this.amount,
    required this.fee,
    required this.type,
    required this.date,
    required this.ref,
  });
  String id;
  String name;
  String phone;
  double amount;
  double fee;
  String type; // Cash In | Cash Out
  DateTime date;
  String ref;
  bool get isIn => type == kCashIn;
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'phone': phone, 'amount': amount, 'fee': fee,
        'type': type, 'date': date.toIso8601String(), 'ref': ref,
      };
  factory GcashTx.fromJson(Map<String, dynamic> j) => GcashTx(
        id: _str(j['id']),
        name: _str(j['name']),
        phone: _str(j['phone']),
        amount: _num(j['amount']),
        fee: _num(j['fee']),
        type: _str(j['type']),
        date: _dt(j['date']),
        ref: _str(j['ref']),
      );
}

class Expense {
  Expense({
    required this.id,
    required this.name,
    required this.category,
    required this.amount,
    required this.method,
    required this.date,
    this.notes = '',
  });
  String id;
  String name;
  String category;
  double amount;
  String method; // Cash | Gcash
  DateTime date;
  String notes;
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'category': category, 'amount': amount,
        'method': method, 'date': date.toIso8601String(), 'notes': notes,
      };
  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: _str(j['id']),
        name: _str(j['name']),
        category: _str(j['category']),
        amount: _num(j['amount']),
        method: _str(j['method']),
        date: _dt(j['date']),
        notes: _str(j['notes']),
      );
}

class DebtItem {
  DebtItem({required this.name, required this.qty, required this.price});
  String name;
  int qty;
  double price;
  double get total => qty * price;
  Map<String, dynamic> toJson() => {'name': name, 'qty': qty, 'price': price};
  factory DebtItem.fromJson(Map<String, dynamic> j) =>
      DebtItem(name: _str(j['name']), qty: _int(j['qty']), price: _num(j['price']));
}

class Debt {
  Debt({
    required this.id,
    required this.customer,
    required this.phone,
    required this.items,
    required this.debtDate,
    required this.dueDate,
    this.paid = false,
  });
  String id;
  String customer;
  String phone;
  List<DebtItem> items;
  DateTime debtDate;
  DateTime dueDate;
  bool paid;
  double get total => items.fold(0.0, (s, i) => s + i.total);
  Map<String, dynamic> toJson() => {
        'id': id, 'customer': customer, 'phone': phone, 'paid': paid,
        'debtDate': debtDate.toIso8601String(), 'dueDate': dueDate.toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
      };
  factory Debt.fromJson(Map<String, dynamic> j) => Debt(
        id: _str(j['id']),
        customer: _str(j['customer']),
        phone: _str(j['phone']),
        paid: _bool(j['paid']),
        debtDate: _dt(j['debtDate']),
        dueDate: _dt(j['dueDate']),
        items: _itemList(j['items']).map(DebtItem.fromJson).toList(),
      );
}

class BusinessProfile {
  BusinessProfile({
    this.ownerName = '',
    this.storeName = '',
    this.businessType = 'Sari-Sari Store',
    this.phone = '',
    this.address = '',
    this.city = '',
    this.province = '',
    this.postalCode = '',
    this.tinNumber = '',
    this.photo,
    this.qr,
  });
  String ownerName = '';
  String storeName = '';
  String businessType = 'Sari-Sari Store';
  String phone = '';
  String address = '';
  String city = '';
  String province = '';
  String postalCode = '';
  String tinNumber = '';
  String? photo;
  String? qr;
  Map<String, dynamic> toJson() => {
        'ownerName': ownerName, 'storeName': storeName, 'businessType': businessType,
        'phone': phone, 'address': address, 'city': city, 'province': province, 'postalCode': postalCode, 'tinNumber': tinNumber,
        'photo': photo, 'qr': qr,
      };
  factory BusinessProfile.fromJson(Map<String, dynamic> j) => BusinessProfile(
        ownerName: _str(j['ownerName']),
        storeName: _str(j['storeName']),
        businessType: j['businessType'] is String ? j['businessType'] as String : 'Sari-Sari Store',
        phone: _str(j['phone']),
        address: _str(j['address']),
        city: _str(j['city']),
        province: _str(j['province']),
        postalCode: _str(j['postalCode']),
        tinNumber: _str(j['tinNumber']),
        photo: j['photo'] is String ? j['photo'] as String : null,
        qr: j['qr'] is String ? j['qr'] as String : null,
      );
}

class Account {
  Account({required this.fullName, required this.username, required this.email, required this.passHash, this.dateOfBirth, this.gender});
  String fullName;
  String username;
  String email;
  String passHash;
  String? dateOfBirth;
  String? gender;
  Map<String, dynamic> toJson() =>
      {'fullName': fullName, 'username': username, 'email': email, 'passHash': passHash, 'dateOfBirth': dateOfBirth, 'gender': gender};
  factory Account.fromJson(Map<String, dynamic> j) => Account(
      fullName: _str(j['fullName']),
      username: _str(j['username']),
      email: _str(j['email']),
      passHash: _str(j['passHash']),
      dateOfBirth: j['dateOfBirth'] is String ? j['dateOfBirth'] as String : null,
      gender: j['gender'] is String ? j['gender'] as String : null);
}
