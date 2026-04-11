import 'dart:convert';

// 1. Batch Info Model: Product ki batch history track karne ke liye
class BatchInfo {
  String batch, exp, packing;
  double mrp, rate;
  BatchInfo({required this.batch, required this.exp, required this.packing, required this.mrp, required this.rate});

  Map<String, dynamic> toMap() => {'batch': batch, 'exp': exp, 'packing': packing, 'mrp': mrp, 'rate': rate};
  factory BatchInfo.fromMap(Map<String, dynamic> map) => BatchInfo(
    batch: map['batch'] ?? "",
    exp: map['exp'] ?? "",
    packing: map['packing'] ?? "",
    mrp: (map['mrp'] ?? 0).toDouble(),
    rate: (map['rate'] ?? 0).toDouble(),
  );
}

// 2. Audit Log Model: System actions record karne ke liye
class LogEntry {
  String id, action, details;
  DateTime time;
  LogEntry({required this.id, required this.action, required this.details, required this.time});

  Map<String, dynamic> toMap() => {'id': id, 'action': action, 'details': details, 'time': time.toIso8601String()};
  factory LogEntry.fromMap(Map<String, dynamic> map) => LogEntry(
    id: map['id'],
    action: map['action'],
    details: map['details'],
    time: DateTime.parse(map['time']),
  );
}

// 3. Product / Medicine Master Model
class Medicine {
  String id, name, packing, manufacturer, hsnCode;
  double gst, mrp, purRate, rateA, rateB, rateC;
  int stock;

  Medicine({
    required this.id, required this.name, required this.packing,
    this.manufacturer = "N/A", this.hsnCode = "N/A", this.gst = 12.0,
    required this.mrp, this.purRate = 0.0, required this.rateA,
    required this.rateB, required this.rateC, this.stock = 0
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'packing': packing, 'manufacturer': manufacturer,
    'hsnCode': hsnCode, 'gst': gst, 'mrp': mrp, 'purRate': purRate,
    'rateA': rateA, 'rateB': rateB, 'rateC': rateC, 'stock': stock
  };

  factory Medicine.fromMap(Map<String, dynamic> map) => Medicine(
    id: map['id'] ?? "",
    name: map['name'] ?? "",
    packing: map['packing'] ?? "",
    manufacturer: map['manufacturer'] ?? "N/A",
    hsnCode: map['hsnCode'] ?? "N/A",
    gst: (map['gst'] ?? 12).toDouble(),
    mrp: (map['mrp'] ?? 0).toDouble(),
    purRate: (map['purRate'] ?? 0).toDouble(),
    rateA: (map['rateA'] ?? 0).toDouble(),
    rateB: (map['rateB'] ?? 0).toDouble(),
    rateC: (map['rateC'] ?? 0).toDouble(),
    stock: map['stock'] ?? 0,
  );
}

// 4. Party Master Model
class Party {
  String id, name, address, city, state, phone, gst;
  Party({
    required this.id, required this.name, this.address = "", this.city = "",
    this.state = "Rajasthan", this.phone = "", this.gst = "N/A"
  });

  bool get isB2B => gst != "N/A" && gst.trim().length >= 15;

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'address': address, 'city': city, 'state': state,
    'phone': phone, 'gst': gst
  };

  factory Party.fromMap(Map<String, dynamic> map) => Party(
    id: map['id'] ?? "",
    name: map['name'] ?? "",
    address: map['address'] ?? "",
    city: map['city'] ?? "",
    state: map['state'] ?? "Rajasthan",
    phone: map['phone'] ?? "",
    gst: map['gst'] ?? "N/A"
  );
}

// 5. Bill Item Model: Individual items in Sale Invoice
class BillItem {
  String id, medicineID, name, packing, batch, exp, hsn;
  int srNo;
  double mrp, qty, rate, gstRate, cgst, sgst, igst, total, discountRupees;

  BillItem({
    required this.id, required this.srNo, required this.medicineID, required this.name,
    required this.packing, required this.batch, required this.exp, required this.hsn,
    required this.mrp, required this.qty, required this.rate, required this.gstRate,
    this.cgst = 0, this.sgst = 0, this.igst = 0, required this.total, this.discountRupees = 0
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'srNo': srNo, 'medicineID': medicineID, 'name': name, 'packing': packing,
    'batch': batch, 'exp': exp, 'hsn': hsn, 'mrp': mrp, 'qty': qty, 'rate': rate,
    'gstRate': gstRate, 'cgst': cgst, 'sgst': sgst, 'igst': igst, 'total': total,
    'discountRupees': discountRupees
  };

  factory BillItem.fromMap(Map<String, dynamic> map) => BillItem(
    id: map['id'] ?? "",
    srNo: map['srNo'] ?? 0,
    medicineID: map['medicineID'] ?? "",
    name: map['name'] ?? "",
    packing: map['packing'] ?? "",
    batch: map['batch'] ?? "",
    exp: map['exp'] ?? "",
    hsn: map['hsn'] ?? "",
    mrp: (map['mrp'] ?? 0).toDouble(),
    qty: (map['qty'] ?? 0).toDouble(),
    rate: (map['rate'] ?? 0).toDouble(),
    gstRate: (map['gstRate'] ?? 0).toDouble(),
    cgst: (map['cgst'] ?? 0).toDouble(),
    sgst: (map['sgst'] ?? 0).toDouble(),
    igst: (map['igst'] ?? 0).toDouble(),
    total: (map['total'] ?? 0).toDouble(),
    discountRupees: (map['discountRupees'] ?? 0).toDouble(),
  );
}

// 6. Sale (Invoice) Model - Full GSTR Compliance
class Sale {
  String id, billNo, partyName, partyGstin, partyState, status, invoiceType, paymentMode;
  DateTime date;
  List<BillItem> items;
  double totalAmount;

  Sale({
    required this.id, required this.billNo, required this.date, required this.partyName,
    required this.partyGstin, required this.partyState, required this.items,
    required this.totalAmount, required this.paymentMode, this.status = "Active",
    this.invoiceType = "B2C"
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'billNo': billNo, 'date': date.toIso8601String(), 'partyName': partyName,
    'partyGstin': partyGstin, 'partyState': partyState, 'paymentMode': paymentMode,
    'totalAmount': totalAmount, 'status': status, 'invoiceType': invoiceType,
    'items': items.map((i) => i.toMap()).toList()
  };

  factory Sale.fromMap(Map<String, dynamic> map) => Sale(
    id: map['id'],
    billNo: map['billNo'],
    date: DateTime.parse(map['date']),
    partyName: map['partyName'],
    partyGstin: map['partyGstin'] ?? "N/A",
    partyState: map['partyState'] ?? "Rajasthan",
    paymentMode: map['paymentMode'] ?? "CASH",
    totalAmount: (map['totalAmount'] ?? 0).toDouble(),
    status: map['status'] ?? "Active",
    invoiceType: map['invoiceType'] ?? "B2C",
    items: (map['items'] as List).map((i) => BillItem.fromMap(i)).toList(),
  );
}

// 7. Purchase Item Model
class PurchaseItem {
  String id, medicineID, name, packing, batch, exp, hsn;
  int srNo;
  double mrp, qty, freeQty, purchaseRate, gstRate, total, rateA, rateB, rateC;

  PurchaseItem({
    required this.id, required this.srNo, required this.medicineID, required this.name,
    required this.packing, required this.batch, required this.exp, required this.hsn,
    required this.mrp, required this.qty, this.freeQty = 0, required this.purchaseRate,
    required this.gstRate, required this.total, this.rateA = 0, this.rateB = 0, this.rateC = 0
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'srNo': srNo, 'medicineID': medicineID, 'name': name, 'packing': packing,
    'batch': batch, 'exp': exp, 'hsn': hsn, 'mrp': mrp, 'qty': qty, 'freeQty': freeQty,
    'purchaseRate': purchaseRate, 'gstRate': gstRate, 'total': total,
    'rateA': rateA, 'rateB': rateB, 'rateC': rateC
  };

  factory PurchaseItem.fromMap(Map<String, dynamic> map) => PurchaseItem(
    id: map['id'], srNo: map['srNo'], medicineID: map['medicineID'], name: map['name'],
    packing: map['packing'], batch: map['batch'], exp: map['exp'], hsn: map['hsn'] ?? "",
    mrp: (map['mrp'] ?? 0).toDouble(), qty: (map['qty'] ?? 0).toDouble(),
    freeQty: (map['freeQty'] ?? 0).toDouble(), purchaseRate: (map['purchaseRate'] ?? 0).toDouble(),
    gstRate: (map['gstRate'] ?? 0).toDouble(), total: (map['total'] ?? 0).toDouble(),
    rateA: (map['rateA'] ?? 0).toDouble(), rateB: (map['rateB'] ?? 0).toDouble(),
    rateC: (map['rateC'] ?? 0).toDouble(),
  );
}

// 8. Purchase (Stock In) Model
class Purchase {
  String id, internalNo, billNo, distributorName, paymentMode, gstStatus;
  DateTime date;
  List<PurchaseItem> items;
  double totalAmount;

  Purchase({
    required this.id, required this.internalNo, required this.billNo, required this.date,
    required this.distributorName, required this.items, required this.totalAmount,
    required this.paymentMode, this.gstStatus = "Pending"
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'internalNo': internalNo, 'billNo': billNo, 'date': date.toIso8601String(),
    'distributorName': distributorName, 'paymentMode': paymentMode,
    'totalAmount': totalAmount, 'gstStatus': gstStatus,
    'items': items.map((i) => i.toMap()).toList()
  };

  factory Purchase.fromMap(Map<String, dynamic> map) => Purchase(
    id: map['id'], internalNo: map['internalNo'] ?? "", billNo: map['billNo'],
    distributorName: map['distributorName'], paymentMode: map['paymentMode'],
    gstStatus: map['gstStatus'] ?? "Pending", date: DateTime.parse(map['date']),
    totalAmount: (map['totalAmount'] ?? 0).toDouble(),
    items: (map['items'] as List).map((i) => PurchaseItem.fromMap(i)).toList(),
  );
}
