import 'dart:convert';

class BatchInfo {
  String batch, exp, packing;
  double mrp, rate;
  BatchInfo({required this.batch, required this.exp, required this.packing, required this.mrp, required this.rate});
  Map<String, dynamic> toMap() => {'batch': batch, 'exp': exp, 'packing': packing, 'mrp': mrp, 'rate': rate};
  factory BatchInfo.fromMap(Map<String, dynamic> map) => BatchInfo(batch: map['batch'], exp: map['exp'], packing: map['packing'], mrp: map['mrp'].toDouble(), rate: map['rate'].toDouble());
}

class Medicine {
  String id, name, packing, manufacturer, composition, hsnCode;
  double gst, mrp, rateA, rateB, rateC;
  int stock;
  Medicine({required this.id, required this.name, required this.packing, this.manufacturer = "N/A", this.composition = "N/A", this.hsnCode = "N/A", this.gst = 12.0, required this.mrp, required this.rateA, required this.rateB, required this.rateC, this.stock = 0});
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'packing': packing, 'manufacturer': manufacturer, 'composition': composition, 'hsnCode': hsnCode, 'gst': gst, 'mrp': mrp, 'rateA': rateA, 'rateB': rateB, 'rateC': rateC, 'stock': stock};
  factory Medicine.fromMap(Map<String, dynamic> map) => Medicine(id: map['id'], name: map['name'], packing: map['packing'], manufacturer: map['manufacturer'], composition: map['composition'], hsnCode: map['hsnCode'], gst: map['gst'].toDouble(), mrp: map['mrp'].toDouble(), rateA: map['rateA'].toDouble(), rateB: map['rateB'].toDouble(), rateC: map['rateC'].toDouble(), stock: map['stock']);
}

class Party {
  String id, name, address, city, route, phone, email, dl, gst, rateType;
  double openingBalance;
  Party({required this.id, required this.name, this.address = "", this.city = "", this.route = "", this.phone = "", this.email = "", this.dl = "N/A", this.gst = "N/A", this.rateType = "A", this.openingBalance = 0.0});
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'address': address, 'city': city, 'route': route, 'phone': phone, 'email': email, 'dl': dl, 'gst': gst, 'rateType': rateType, 'openingBalance': openingBalance};
  factory Party.fromMap(Map<String, dynamic> map) => Party(id: map['id'], name: map['name'], address: map['address'], city: map['city'], route: map['route'], phone: map['phone'], email: map['email'] ?? "", dl: map['dl'], gst: map['gst'], rateType: map['rateType'], openingBalance: map['openingBalance'].toDouble());
}

class BillItem {
  String id, medicineID, name, packing, batch, exp, hsn;
  int srNo;
  double mrp, qty, rate, discount, gstRate, cgst, sgst, total;
  BillItem({required this.id, required this.srNo, required this.medicineID, required this.name, required this.packing, required this.batch, required this.exp, required this.hsn, required this.mrp, required this.qty, required this.rate, required this.discount, required this.gstRate, required this.cgst, required this.sgst, required this.total});
  Map<String, dynamic> toMap() => {'id': id, 'srNo': srNo, 'medicineID': medicineID, 'name': name, 'packing': packing, 'batch': batch, 'exp': exp, 'hsn': hsn, 'mrp': mrp, 'qty': qty, 'rate': rate, 'discount': discount, 'gstRate': gstRate, 'cgst': cgst, 'sgst': sgst, 'total': total};
}

class Sale {
  String id, billNo, partyName, paymentMode;
  DateTime date;
  List<BillItem> items;
  double totalAmount;
  Sale({required this.id, required this.billNo, required this.date, required this.partyName, required this.items, required this.totalAmount, required this.paymentMode});
}
