import 'dart:convert';

// 1. ROUTE / AREA MODEL
class RouteArea {
  String id, name;
  RouteArea({required this.id, required this.name});
  Map<String, dynamic> toMap() => {'id': id, 'name': name};
  factory RouteArea.fromMap(Map<String, dynamic> map) => RouteArea(id: map['id'], name: map['name']);
}

// 2. UPDATED PARTY MODEL
class Party {
  String id, name, group, phone, email, address, city, state, route, gst, dl, dlExp, pan, transport, priceLevel;
  double opBal, creditLimit;
  int creditDays;

  Party({
    required this.id, required this.name, this.group = "Sundry Debtors", this.phone = "",
    this.email = "", this.address = "", this.city = "", this.state = "Rajasthan",
    this.route = "", this.gst = "", this.dl = "", this.dlExp = "", this.pan = "",
    this.transport = "", this.priceLevel = "A", this.opBal = 0.0, this.creditLimit = 0.0,
    this.creditDays = 0,
  });

  bool get isB2B => gst.length >= 15;

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'group': group, 'phone': phone, 'email': email,
    'address': address, 'city': city, 'state': state, 'route': route, 'gst': gst,
    'dl': dl, 'dlExp': dlExp, 'pan': pan, 'transport': transport, 'priceLevel': priceLevel,
    'opBal': opBal, 'creditLimit': creditLimit, 'creditDays': creditDays,
  };

  factory Party.fromMap(Map<String, dynamic> map) => Party(
    id: map['id'], name: map['name'], group: map['group'], phone: map['phone'],
    email: map['email'] ?? "", address: map['address'] ?? "", city: map['city'] ?? "", 
    state: map['state'] ?? "Rajasthan", route: map['route'] ?? "", gst: map['gst'] ?? "", 
    dl: map['dl'] ?? "", dlExp: map['dlExp'] ?? "", pan: map['pan'] ?? "", 
    transport: map['transport'] ?? "", priceLevel: map['priceLevel'] ?? "A", 
    opBal: (map['opBal'] ?? 0.0).toDouble(), creditLimit: (map['creditLimit'] ?? 0.0).toDouble(), 
    creditDays: map['creditDays'] ?? 0,
  );
}

// ... Baki models (Medicine, Sale, Purchase, etc.) waise hi rahenge ...
class Medicine {
  String id, name, packing, manufacturer, hsnCode; 
  double gst, mrp, purRate, rateA, rateB, rateC, stock;
  Medicine({required this.id, required this.name, required this.packing, this.manufacturer = "N/A", this.hsnCode = "N/A", this.gst = 12.0, required this.mrp, this.purRate = 0.0, required this.rateA, required this.rateB, required this.rateC, this.stock = 0.0});
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'packing': packing, 'manufacturer': manufacturer, 'hsnCode': hsnCode, 'gst': gst, 'mrp': mrp, 'purRate': purRate, 'rateA': rateA, 'rateB': rateB, 'rateC': rateC, 'stock': stock};
  factory Medicine.fromMap(Map<String, dynamic> map) => Medicine(id: map['id'] ?? "", name: map['name'] ?? "", packing: map['packing'] ?? "", manufacturer: map['manufacturer'] ?? "N/A", hsnCode: map['hsnCode'] ?? "N/A", gst: (map['gst'] ?? 12).toDouble(), mrp: (map['mrp'] ?? 0).toDouble(), purRate: (map['purRate'] ?? 0).toDouble(), rateA: (map['rateA'] ?? 0).toDouble(), rateB: (map['rateB'] ?? 0).toDouble(), rateC: (map['rateC'] ?? 0).toDouble(), stock: (map['stock'] ?? 0.0).toDouble());
}

class BatchInfo {
  String batch, exp, packing; double mrp, rate;
  BatchInfo({required this.batch, required this.exp, required this.packing, required this.mrp, required this.rate});
  Map<String, dynamic> toMap() => {'batch': batch, 'exp': exp, 'packing': packing, 'mrp': mrp, 'rate': rate};
  factory BatchInfo.fromMap(Map<String, dynamic> map) => BatchInfo(batch: map['batch'] ?? "", exp: map['exp'] ?? "", packing: map['packing'] ?? "", mrp: (map['mrp'] ?? 0).toDouble(), rate: (map['rate'] ?? 0).toDouble());
}

class BillItem {
  String id, medicineID, name, packing, batch, exp, hsn; int srNo; double mrp, qty, freeQty, rate, gstRate, cgst, sgst, igst, total;
  BillItem({required this.id, required this.srNo, required this.medicineID, required this.name, required this.packing, required this.batch, required this.exp, required this.hsn, required this.mrp, required this.qty, this.freeQty = 0, required this.rate, required this.gstRate, this.cgst = 0, this.sgst = 0, this.igst = 0, required this.total});
  Map<String, dynamic> toMap() => {'id': id, 'srNo': srNo, 'medicineID': medicineID, 'name': name, 'packing': packing, 'batch': batch, 'exp': exp, 'hsn': hsn, 'mrp': mrp, 'qty': qty, 'freeQty': freeQty, 'rate': rate, 'gstRate': gstRate, 'cgst': cgst, 'sgst': sgst, 'igst': igst, 'total': total};
  factory BillItem.fromMap(Map<String, dynamic> map) => BillItem(id: map['id'] ?? "", srNo: map['srNo'] ?? 0, medicineID: map['medicineID'] ?? "", name: map['name'] ?? "", packing: map['packing'] ?? "", batch: map['batch'] ?? "", exp: map['exp'] ?? "", hsn: map['hsn'] ?? "", mrp: (map['mrp'] ?? 0).toDouble(), qty: (map['qty'] ?? 0).toDouble(), freeQty: (map['freeQty'] ?? 0).toDouble(), rate: (map['rate'] ?? 0).toDouble(), gstRate: (map['gstRate'] ?? 0).toDouble(), cgst: (map['cgst'] ?? 0).toDouble(), sgst: (map['sgst'] ?? 0).toDouble(), igst: (map['igst'] ?? 0).toDouble(), total: (map['total'] ?? 0).toDouble());
}

class Sale {
  String id, billNo, partyName, partyGstin, partyState, status, invoiceType, paymentMode; DateTime date; List<BillItem> items; double totalAmount;
  Sale({required this.id, required this.billNo, required this.date, required this.partyName, required this.partyGstin, required this.partyState, required this.items, required this.totalAmount, required this.paymentMode, this.status = "Active", this.invoiceType = "B2C"});
  Map<String, dynamic> toMap() => {'id': id, 'billNo': billNo, 'date': date.toIso8601String(), 'partyName': partyName, 'partyGstin': partyGstin, 'partyState': partyState, 'paymentMode': paymentMode, 'totalAmount': totalAmount, 'status': status, 'invoiceType': invoiceType, 'items': items.map((i) => i.toMap()).toList()};
  factory Sale.fromMap(Map<String, dynamic> map) => Sale(id: map['id'], billNo: map['billNo'], date: DateTime.parse(map['date']), partyName: map['partyName'], partyGstin: map['partyGstin'], partyState: map['partyState'] ?? "Rajasthan", paymentMode: map['paymentMode'] ?? "CASH", totalAmount: (map['totalAmount'] ?? 0.0).toDouble(), status: map['status'] ?? "Active", invoiceType: map['invoiceType'] ?? "B2C", items: (map['items'] as List).map((i) => BillItem.fromMap(i)).toList());
}

class PurchaseItem {
  String id, medicineID, name, packing, batch, exp, hsn; int srNo; double mrp, qty, freeQty, purchaseRate, gstRate, total, rateA, rateB, rateC;
  PurchaseItem({required this.id, required this.srNo, required this.medicineID, required this.name, required this.packing, required this.batch, required this.exp, required this.hsn, required this.mrp, required this.qty, this.freeQty = 0, required this.purchaseRate, required this.gstRate, required this.total, this.rateA = 0, this.rateB = 0, this.rateC = 0});
  Map<String, dynamic> toMap() => {'id': id, 'srNo': srNo, 'medicineID': medicineID, 'name': name, 'packing': packing, 'batch': batch, 'exp': exp, 'hsn': hsn, 'mrp': mrp, 'qty': qty, 'freeQty': freeQty, 'purchaseRate': purchaseRate, 'gstRate': gstRate, 'total': total, 'rateA': rateA, 'rateB': rateB, 'rateC': rateC};
  factory PurchaseItem.fromMap(Map<String, dynamic> map) => PurchaseItem(id: map['id'], srNo: map['srNo'], medicineID: map['medicineID'], name: map['name'], packing: map['packing'], batch: map['batch'], exp: map['exp'], hsn: map['hsn'] ?? "", mrp: (map['mrp'] ?? 0).toDouble(), qty: (map['qty'] ?? 0).toDouble(), freeQty: (map['freeQty'] ?? 0).toDouble(), purchaseRate: (map['purchaseRate'] ?? 0).toDouble(), gstRate: (map['gstRate'] ?? 0).toDouble(), total: (map['total'] ?? 0).toDouble(), rateA: (map['rateA'] ?? 0).toDouble(), rateB: (map['rateB'] ?? 0).toDouble(), rateC: (map['rateC'] ?? 0).toDouble());
}

class Purchase {
  String id, internalNo, billNo, distributorName, paymentMode; DateTime date; List<PurchaseItem> items; double totalAmount;
  Purchase({required this.id, required this.internalNo, required this.billNo, required this.date, required this.distributorName, required this.items, required this.totalAmount, required this.paymentMode});
  Map<String, dynamic> toMap() => {'id': id, 'internalNo': internalNo, 'billNo': billNo, 'date': date.toIso8601String(), 'distributorName': distributorName, 'paymentMode': paymentMode, 'totalAmount': totalAmount, 'items': items.map((i) => i.toMap()).toList()};
  factory Purchase.fromMap(Map<String, dynamic> map) => Purchase(id: map['id'], internalNo: map['internalNo'] ?? "", billNo: map['billNo'], distributorName: map['distributorName'], paymentMode: map['paymentMode'], date: DateTime.parse(map['date']), totalAmount: (map['totalAmount'] ?? 0.0).toDouble(), items: (map['items'] as List).map((i) => PurchaseItem.fromMap(i)).toList());
}
