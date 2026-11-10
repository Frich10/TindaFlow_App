int _seq = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch}${_seq++}';

DateTime _dt(dynamic v) => DateTime.parse(v as String);
double _num(dynamic v) => (v as num).toDouble();

const kCashIn = 'Cash In';
const kCashOut = 'Cash Out';
const kLowStock = 15;
const kProductCategories = ['Canned Goods', 'Coffee', 'Chips', 'Candy', 'Drinks', 'Noodles', 'Snacks', 'Others'];
const kExpenseCategories = ['Supplies', 'Utilities', 'Transportation', 'Groceries'];
const kBusinessTypes = ['Sari-Sari Store', 'Merchandise', 'Bakery', 'Pharmacy', 'Food Stall', 'Other'];

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
        id: j['id'] as String,
        name: j['name'] as String,
        category: j['category'] as String,
        cost: _num(j['cost']),
        price: _num(j['price']),
        stock: (j['stock'] as num).toInt(),
        photo: j['photo'] as String?,
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
      productId: j['productId'] as String,
      date: _dt(j['date']),
      delta: (j['delta'] as num).toInt(),
      reason: j['reason'] as String);
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
      productId: j['productId'] as String,
      name: j['name'] as String,
      price: _num(j['price']),
      cost: _num(j['cost']),
      qty: (j['qty'] as num).toInt());
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
        id: j['id'] as String,
        date: _dt(j['date']),
        method: j['method'] as String,
        total: _num(j['total']),
        received: _num(j['received']),
        items: (j['items'] as List).map((e) => SaleItem.fromJson(e as Map<String, dynamic>)).toList(),
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
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String,
        amount: _num(j['amount']),
        fee: _num(j['fee']),
        type: j['type'] as String,
        date: _dt(j['date']),
        ref: j['ref'] as String,
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
        id: j['id'] as String,
        name: j['name'] as String,
        category: j['category'] as String,
        amount: _num(j['amount']),
        method: j['method'] as String,
        date: _dt(j['date']),
        notes: (j['notes'] as String?) ?? '',
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
      DebtItem(name: j['name'] as String, qty: (j['qty'] as num).toInt(), price: _num(j['price']));
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
        id: j['id'] as String,
        customer: j['customer'] as String,
        phone: j['phone'] as String,
        paid: j['paid'] as bool,
        debtDate: _dt(j['debtDate']),
        dueDate: _dt(j['dueDate']),
        items: (j['items'] as List).map((e) => DebtItem.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class BusinessProfile {
  BusinessProfile({
    this.ownerName = '',
    this.storeName = '',
    this.businessType = 'Sari-Sari Store',
    this.phone = '',
    this.address = '',
    this.photo,
    this.qr,
  });
  String ownerName;
  String storeName;
  String businessType;
  String phone;
  String address;
  String? photo; // base64
  String? qr; // base64
  Map<String, dynamic> toJson() => {
        'ownerName': ownerName, 'storeName': storeName, 'businessType': businessType,
        'phone': phone, 'address': address, 'photo': photo, 'qr': qr,
      };
  factory BusinessProfile.fromJson(Map<String, dynamic> j) => BusinessProfile(
        ownerName: (j['ownerName'] as String?) ?? '',
        storeName: (j['storeName'] as String?) ?? '',
        businessType: (j['businessType'] as String?) ?? 'Sari-Sari Store',
        phone: (j['phone'] as String?) ?? '',
        address: (j['address'] as String?) ?? '',
        photo: j['photo'] as String?,
        qr: j['qr'] as String?,
      );
}

class Account {
  Account({required this.fullName, required this.username, required this.email, required this.passHash});
  String fullName;
  String username;
  String email;
  String passHash;
  Map<String, dynamic> toJson() =>
      {'fullName': fullName, 'username': username, 'email': email, 'passHash': passHash};
  factory Account.fromJson(Map<String, dynamic> j) => Account(
      fullName: j['fullName'] as String,
      username: j['username'] as String,
      email: j['email'] as String,
      passHash: j['passHash'] as String);
}
