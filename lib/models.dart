import 'dart:convert';

class BatchInfo {
  String batch, exp, packing;
  double mrp, rate;
  BatchInfo({required this.batch, required this.exp, required this.packing, required this.mrp, required this.rate});
  Map<String, dynamic> toMap() => {'batch': batch, 'exp': exp, 'packing': packing, 'mrp': mrp, 'rate': rate};
  factory BatchInfo.fromMap(Map<String, dynamic> map) => BatchInfo(batch: map['batch'], exp: map['exp'], packing: map['packing'], mrp: (map['mrp']??0).toDouble(), rate: (map['rate']??0).toDouble());
}

class Medicine {
  String id, name, packing, manufacturer, composition, hsnCode;
  double gst, mrp, rateA, rateB, rateC;
  int stock;
   Medicine({required this.id, required this.name, required this.packing, this.manufacturer = "N/A", this.composition = "N/A", this.hsnCode = "N/A", this.gst = 12.0, required this.mrp, required this.rateA, required this.rateB, required this.rateC, this.stock = 0});
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'packing': packing, 'manufacturer': manufacturer, 'composition': composition, 'hsnCode': hsnCode, 'gst': gst, 'mrp': mrp, 'rateA': rateA, 'rateB': rateB, 'rateC': rateC, 'stock': stock};
  factory Medicine.fromMap(Map<String, dynamic> map) => Medicine(id: map['id'], name: map['name'], packing: map['packing'], manufacturer: map['manufacturer'], composition: map['composition'], hsnCode: map['hsnCode'], gst: (map['gst']??12).toDouble(), mrp: (map['mrp']??0).toDouble(), rateA: (map['rateA']??0).toDouble(), rateB: (map['rateB']??0).toDouble(), rateC: (map['rateC']??0).toDouble(), stock: map['stock']??0);
}

class Party {
  String id, name, address, city, route, phone, email, dl, gst, rateType;
  double openingBalance;
  Party({required this.id, required this.name, this.address = "", this.city = "", this.route = "", this.phone = "", this.email = "", this.dl = "N/A", this.gst = "N/A", this.rateType = "A", this.openingBalance = 0.0});
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'address': address, 'city': city, 'route': route, 'phone': phone, 'email': email, 'dl': dl, 'gst': gst, 'rateType': rateType, 'openingBalance': openingBalance};
  factory Party.fromMap(Map<String, dynamic> map) => Party(id: map['id'], name: map['name'], address: map['address'] ?? "", city: map['city'] ?? "", route: map['route'] ?? "", phone: map['phone'] ?? "", email: map['email'] ?? "", dl: map['dl'] ?? "N/A", gst: map['gst'] ?? "N/A", rateType: map['rateType'] ?? "A", openingBalance: (map['openingBalance'] ?? 0.0).toDouble());
}

class BillItem {
  String id, medicineID, name, packing, batch, exp, hsn;
  int srNo;
  double mrp, qty, rate, discountPercent, discountRupees, gstRate, cgst, sgst, total;
  BillItem({required this.id, required this.srNo, required this.medicineID, required this.name, required this.packing, required this.batch, required this.exp, required this.hsn, required this.mrp, required this.qty, required this.rate, this.discountPercent = 0.0, this.discountRupees = 0.0, required this.gstRate, required this.cgst, required this.sgst, required this.total});
  Map<String, dynamic> toMap() => {'id': id, 'srNo': srNo, 'medicineID': medicineID, 'name': name, 'packing': packing, 'batch': batch, 'exp': exp, 'hsn': hsn, 'mrp': mrp, 'qty': qty, 'rate': rate, 'discountPercent': discountPercent, 'discountRupees': discountRupees, 'gstRate': gstRate, 'cgst': cgst, 'sgst': sgst, 'total': total};
  factory BillItem.fromMap(Map<String, dynamic> map) => BillItem(id: map['id'], srNo: map['srNo'], medicineID: map['medicineID'], name: map['name'], packing: map['packing'], batch: map['batch'], exp: map['exp'], hsn: map['hsn'], mrp: (map['mrp']??0).toDouble(), qty: (map['qty']??0).toDouble(), rate: (map['rate']??0).toDouble(), discountPercent: (map['discountPercent']??0).toDouble(), discountRupees: (map['discountRupees']??0).toDouble(), gstRate: (map['gstRate']??0).toDouble(), cgst: (map['cgst']??0).toDouble(), sgst: (map['sgst']??0).toDouble(), total: (map['total']??0).toDouble());
}

class Sale {
  String id, billNo, partyName, paymentMode, status;
  DateTime date;
  List<BillItem> items;
  double totalAmount;
  Sale({required this.id, required this.billNo, required this.date, required this.partyName, required this.items, required this.totalAmount, required this.paymentMode, this.status = "Active"});
  Map<String, dynamic> toMap() => {'id': id, 'billNo': billNo, 'date': date.toIso8601String(), 'partyName': partyName, 'paymentMode': paymentMode, 'totalAmount': totalAmount, 'status': status, 'items': items.map((i) => i.toMap()).toList()};
}
