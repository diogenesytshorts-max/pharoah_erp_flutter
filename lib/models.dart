import 'dart:convert';

// 1. Batch Info Model
class BatchInfo {
  String batch, exp, packing;
  double mrp, rate;

  BatchInfo({
    required this.batch,
    required this.exp,
    required this.packing,
    required this.mrp,
    required this.rate,
  });

  Map<String, dynamic> toMap() => {
    'batch': batch, 'exp': exp, 'packing': packing, 'mrp': mrp, 'rate': rate,
  };

  factory BatchInfo.fromMap(Map<String, dynamic> map) => BatchInfo(
    batch: map['batch'], exp: map['exp'], packing: map['packing'],
    mrp: map['mrp'].toDouble(), rate: map['rate'].toDouble(),
  );
}

// 2. Medicine Model
class Medicine {
  String id, name, packing, manufacturer, composition, hsnCode;
  double gst, mrp, rateA, rateB, rateC;
  int stock;
  List<BatchInfo> knownBatches;

  Medicine({
    required this.id, required this.name, required this.packing,
    this.manufacturer = "N/A", this.composition = "N/A", this.hsnCode = "N/A",
    this.gst = 12.0, required this.mrp, required this.rateA, required this.rateB,
    required this.rateC, this.stock = 0, this.knownBatches = const [],
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'packing': packing, 'manufacturer': manufacturer,
    'composition': composition, 'hsnCode': hsnCode, 'gst': gst, 'mrp': mrp,
    'rateA': rateA, 'rateB': rateB, 'rateC': rateC, 'stock': stock,
    'knownBatches': knownBatches.map((x) => x.toMap()).toList(),
  };

  factory Medicine.fromMap(Map<String, dynamic> map) => Medicine(
    id: map['id'], name: map['name'], packing: map['packing'],
    manufacturer: map['manufacturer'], composition: map['composition'],
    hsnCode: map['hsnCode'], gst: map['gst'].toDouble(), mrp: map['mrp'].toDouble(),
    rateA: map['rateA'].toDouble(), rateB: map['rateB'].toDouble(),
    rateC: map['rateC'].toDouble(), stock: map['stock'],
    knownBatches: List<BatchInfo>.from(map['knownBatches']?.map((x) => BatchInfo.fromMap(x)) ?? []),
  );
}

// 3. Party Model
class Party {
  String id, name, contactPerson, address, city, state, pincode, route, phone, email, dl, gst;
  double openingBalance, creditLimit;
  int creditDays;
  String defaultRateType, partyType;

  Party({
    required this.id, required this.name, this.contactPerson = "", this.address = "",
    this.city = "", this.state = "", this.pincode = "", this.route = "",
    this.phone = "", this.email = "", this.dl = "N/A", this.gst = "N/A",
    this.openingBalance = 0.0, this.creditLimit = 0.0, this.creditDays = 0,
    this.defaultRateType = "A", this.partyType = "Debtor",
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'contactPerson': contactPerson, 'address': address,
    'city': city, 'state': state, 'pincode': pincode, 'route': route,
    'phone': phone, 'email': email, 'dl': dl, 'gst': gst,
    'openingBalance': openingBalance, 'creditLimit': creditLimit,
    'creditDays': creditDays, 'defaultRateType': defaultRateType, 'partyType': partyType,
  };

  factory Party.fromMap(Map<String, dynamic> map) => Party(
    id: map['id'], name: map['name'], contactPerson: map['contactPerson'],
    address: map['address'], city: map['city'], state: map['state'],
    pincode: map['pincode'], route: map['route'], phone: map['phone'],
    email: map['email'], dl: map['dl'], gst: map['gst'],
    openingBalance: map['openingBalance'].toDouble(), creditLimit: map['creditLimit'].toDouble(),
    creditDays: map['creditDays'], defaultRateType: map['defaultRateType'], partyType: map['partyType'],
  );
}

// 4. Bill Item
class BillItem {
  String id;
  int srNo;
  String medicineID, name, packing, batch, exp, hsn;
  double mrp, qty, rate, discount, gstRate, cgst, sgst, total;

  BillItem({
    required this.id, required this.srNo, required this.medicineID,
    required this.name, required this.packing, required this.batch,
    required this.exp, required this.hsn, required this.mrp, required this.qty,
    required this.rate, required this.discount, required this.gstRate,
    required this.cgst, required this.sgst, required this.total,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'srNo': srNo, 'medicineID': medicineID, 'name': name,
    'packing': packing, 'batch': batch, 'exp': exp, 'hsn': hsn, 'mrp': mrp,
    'qty': qty, 'rate': rate, 'discount': discount, 'gstRate': gstRate,
    'cgst': cgst, 'sgst': sgst, 'total': total,
  };
}

// 5. Sale Model
class Sale {
  String id, billNo;
  DateTime date;
  String partyName;
  List<BillItem> items;
  double totalAmount;
  String paymentMode;

  Sale({
    required this.id, required this.billNo, required this.date,
    required this.partyName, required this.items, required this.totalAmount,
    required this.paymentMode,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'billNo': billNo, 'date': date.toIso8601String(),
    'partyName': partyName, 'items': items.map((x) => x.toMap()).toList(),
    'totalAmount': totalAmount, 'paymentMode': paymentMode,
  };
}
