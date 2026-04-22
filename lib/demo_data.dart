import 'models.dart';

class DemoData {
  static List<Medicine> getMedicines() {
    // Demo products ke uniqueCode ko Name + Packing ke format mein rakha hai
    // Taaki 'identityKey' logic bina kisi error ke kaam kare.
    
    List<Map<String, dynamic>> products = [
      {"name": "DOLO 650 MG", "pack": "10 TAB", "mrp": 50.0, "pur": 40.0, "a": 42.0, "b": 41.0, "c": 40.5, "stock": 100.0},
      {"name": "PAN 40 MG", "pack": "10 TAB", "mrp": 120.0, "pur": 90.0, "a": 100.0, "b": 95.0, "c": 92.0, "stock": 50.0},
      {"name": "CALPOL 500", "pack": "15 TAB", "mrp": 30.0, "pur": 20.0, "a": 25.0, "b": 24.0, "c": 22.0, "stock": 200.0},
      {"name": "LIMCEE 500", "pack": "15 TAB", "mrp": 25.0, "pur": 15.0, "a": 20.0, "b": 19.0, "c": 18.0, "stock": 300.0},
      {"name": "AZITHRAL 500", "pack": "5 TAB", "mrp": 150.0, "pur": 110.0, "a": 130.0, "b": 125.0, "c": 120.0, "stock": 30.0},
    ];

    return products.map((p) {
      String name = p['name'];
      String pack = p['pack'];
      return Medicine(
        id: "demo_${name.replaceAll(' ', '_')}",
        uniqueCode: "$name|$pack", // Auto-generating identityKey here
        name: name,
        packing: pack,
        mrp: p['mrp'],
        purRate: p['pur'],
        rateA: p['a'],
        rateB: p['b'],
        rateC: p['c'],
        stock: p['stock'],
        gst: 12.0,
      );
    }).toList();
  }

  static Party getDemoParty() {
    return Party(
      id: "demo_party_1", 
      name: "DEMO PHARMA DISTRIBUTORS", 
      address: "61, UNIVERSITY ROAD", 
      city: "UDAIPUR", 
      gst: "08FSBPM0623R1ZC",
      group: "Sundry Creditors"
    );
  }
}
