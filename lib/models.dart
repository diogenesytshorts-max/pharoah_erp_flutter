import 'dart:convert';

class BatchInfo {
  String batch, exp, packing;
  double mrp, rate;
  BatchInfo({required this.batch, required this.exp, required this.packing, required this.mrp, required this.rate});
  Map<String, dynamic> toMap() => {'batch': batch, 'exp': exp, 'packing': packing, 'mrp': mrp, 'rate': rate};
  factory BatchInfo.fromMap(Map<String, dynamic> map) => BatchInfo(batch: map['batch']??"", exp: map['exp']??"", packing: map['packing']??"", mrp: (map['mrp']??0).toDouble(), rate: (map['rate']??0).toDouble());
}

class LogEntry {
  String id, action, details;
  DateTime time;
  LogEntry({required this.id, required this.action, required this.details, required this.time});
  Map<String, dynamic> toMap() => {'id': id, 'action': action, 'details': details, 'time': time.toIso8601String()};
  factory LogEntry.fromMap(Map<String, dynamic> map) => LogEntry(id: map['id'], action: map['action'], details: map['details'], time: DateTime.parse(map['time']));
}

class Medicine {
  String id, name, packing, manufacturer, hsnCode;
  double gst, mrp, purRate, rateA, rateB, rateC; // purRate add kiya
  int stock;
  Medicine({
    required this.id, 
    required this.name, 
    required this.packing, 
    this.manufacturer = "N/A", 
    this.hsnCode = "N/A", 
    this.gst = 12.0, 
    required this.mrp, 
    this.purRate = 0.0, // Default 0
    required this.rateA, 
    required this.rateB, 
    required this.rateC, 
    this.stock = 0
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'packing': packing, 'manufacturer': manufacturer, 
    'hsnCode': hsnCode, 'gst': gst, 'mrp': mrp, 'purRate': purRate, 
    'rateA': rateA, 'rateB': rateB, 'rateC': rateC, 'stock': stock
  };

  factory Medicine.fromMap(Map<String, dynamic> map) => Medicine(
    id: map['id']??"", 
    name: map['name']??"", 
    packing: map['packing']??"", 
    manufacturer: map['manufacturer']??"N/A", 
    hsnCode: map['hsnCode']??"N/A", 
    gst: (map['gst']??12).toDouble(), 
    mrp: (map['mrp']??0).toDouble(), 
    purRate: (map['purRate']??0).toDouble(), // Load purRate
    rateA: (map['rateA']??0).toDouble(), 
    rateB: (map['rateB']??0).toDouble(), 
    rateC: (map['rateC']??0).toDouble(), 
    stock: map['stock']??0
  );
}

class Party {
  String id, name, address, city, route, phone, email, dl, gst, rateType;
  double openingBalance, specialDiscount;
  Party({required this.id, required this.name, this.address = "", this.city = "", this.route = "", this.phone = "", this.email = "", this.dl = "N/A", this.gst = "N/A", this.rateType = "A", this.openingBalance = 0.0, this.specialDiscount = 0.0});
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'address': address, 'city': city, 'route': route, 'phone': phone, 'email': email, 'dl': dl, 'gst': gst, 'rateType': rateType, 'openingBalance': openingBalance, 'specialDiscount': specialDiscount};
  factory Party.fromMap(Map<String, dynamic> map) => Party(id: map['id']??"", name: map['name']??"", address: map['address']??"", city: map['city']??"", route: map['route']??"", phone: map['phone']??"", email: map['email']??"", dl: map['dl']??"N/A", gst: map['gst']??"N/A", rateType: map['rateType']??"A", openingBalance: (map['openingBalance']??0.0).toDouble(), specialDiscount: (map['specialDiscount']??0.0).toDouble());
}

class BillItem {
  String id, medicineID, name, packing, batch, exp, hsn;
  int srNo;
  double mrp, qty, rate, discountPercent, discountRupees, gstRate, cgst, sgst, total;
  BillItem({required this.id, required this.srNo, required this.medicineID, required this.name, required this.packing, required this.batch, required this.exp, required this.hsn, required this.mrp, required this.qty, required this.rate, this.discountPercent = 0.0, this.discountRupees = 0.0, required this.gstRate, required this.cgst, required this.sgst, required this.total});
  Map<String, dynamic> toMap() => {'id': id, 'srNo': srNo, 'medicineID': medicineID, 'name': name, 'packing': packing, 'batch': batch, 'exp': exp, 'hsn': hsn, 'mrp': mrp, 'qty': qty, 'rate': rate, 'discountPercent': discountPercent, 'discountRupees': discountRupees, 'gstRate': gstRate, 'cgst': cgst, 'sgst': sgst, 'total': total};
  factory BillItem.fromMap(Map<String, dynamic> map) => BillItem(id: map['id']??"", srNo: map['srNo']??0, medicineID: map['medicineID']??"", name: map['name']??"", packing: map['packing']??"", batch: map['batch']??"", exp: map['exp']??"", hsn: map['hsn']??"", mrp: (map['mrp']??0).toDouble(), qty: (map['qty']??0).toDouble(), rate: (map['rate']??0).toDouble(), discountPercent: (map['discountPercent']??0).toDouble(), discountRupees: (map['discountRupees']??0).toDouble(), gstRate: (map['gstRate']??0).toDouble(), cgst: (map['cgst']??0).toDouble(), sgst: (map['sgst']??0).toDouble(), total: (map['total']??0).toDouble());
}

class Sale {
  String id, billNo, partyName, paymentMode, status;
  DateTime date;
  List<BillItem> items;
  double totalAmount;
  Sale({required this.id, required this.billNo, required this.date, required this.partyName, required this.items, required this.totalAmount, required this.paymentMode, this.status = "Active"});
  Map<String, dynamic> toMap() => {'id': id, 'billNo': billNo, 'date': date.toIso8601String(), 'partyName': partyName, 'paymentMode': paymentMode, 'totalAmount': totalAmount, 'status': status, 'items': items.map((i) => i.toMap()).toList()};
}

class PurchaseItem {
  String id, medicineID, name, packing, batch, exp, hsn;
  int srNo;
  double mrp, qty, freeQty, purchaseRate, gstRate, total, rateA, rateB, rateC;
  PurchaseItem({required this.id, required this.srNo, required this.medicineID, required this.name, required this.packing, required this.batch, required this.exp, required this.hsn, required this.mrp, required this.qty, this.freeQty = 0, required this.purchaseRate, required this.gstRate, required this.total, this.rateA = 0, this.rateB = 0, this.rateC = 0});
  Map<String, dynamic> toMap() => {'id': id, 'srNo': srNo, 'medicineID': medicineID, 'name': name, 'packing': packing, 'batch': batch, 'exp': exp, 'hsn': hsn, 'mrp': mrp, 'qty': qty, 'freeQty': freeQty, 'purchaseRate': purchaseRate, 'gstRate': gstRate, 'total': total, 'rateA': rateA, 'rateB': rateB, 'rateC': rateC};
  factory PurchaseItem.fromMap(Map<String, dynamic> map) => PurchaseItem(id: map['id'], srNo: map['srNo'], medicineID: map['medicineID'], name: map['name'], packing: map['packing'], batch: map['batch'], exp: map['exp'], hsn: map['hsn']??"", mrp: (map['mrp']??0).toDouble(), qty: (map['qty']??0).toDouble(), freeQty: (map['freeQty']??0).toDouble(), purchaseRate: (map['purchaseRate']??0).toDouble(), gstRate: (map['gstRate']??0).toDouble(), total: (map['total']??0).toDouble(), rateA: (map['rateA']??0).toDouble(), rateB: (map['rateB']??0).toDouble(), rateC: (map['rateC']??0).toDouble());
}

class Purchase {
  String id, internalNo, billNo, distributorName, paymentMode;
  DateTime date;
  List<PurchaseItem> items;
  double totalAmount;
  Purchase({required this.id, required this.internalNo, required this.billNo, required this.date, required this.distributorName, required this.items, required this.totalAmount, required this.paymentMode});
  Map<String, dynamic> toMap() => {'id': id, 'internalNo': internalNo, 'billNo': billNo, 'date': date.toIso8601String(), 'distributorName': distributorName, 'paymentMode': paymentMode, 'totalAmount': totalAmount, 'items': items.map((i) => i.toMap()).toList()};
  factory Purchase.fromMap(Map<String, dynamic> map) => Purchase(id: map['id'], internalNo: map['internalNo']??"", billNo: map['billNo'], distributorName: map['distributorName'], paymentMode: map['paymentMode'], date: DateTime.parse(map['date']), totalAmount: (map['totalAmount']??0).toDouble(), items: (map['items'] as List).map((i) => PurchaseItem.fromMap(i)).toList());
}
