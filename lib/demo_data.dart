import 'models.dart';

class DemoData {
  static List<Medicine> getMedicines() {
    // Demo products mapped to the new Universal ID Series
    return [
      Medicine(
        id: "demo_1",
        systemId: "PH-10001",
        name: "DOLO 650 MG",
        packing: "15 TAB",
        mrp: 30.91,
        purRate: 25.40,
        rateA: 28.50,
        rateB: 27.00,
        rateC: 26.50,
        stock: 0.0,
        gst: 12.0,
        hsnCode: "3004",
      ),
      Medicine(
        id: "demo_2",
        systemId: "PH-10002",
        name: "PAN 40 MG",
        packing: "10 TAB",
        mrp: 120.00,
        purRate: 95.00,
        rateA: 110.00,
        rateB: 105.00,
        rateC: 100.00,
        stock: 0.0,
        gst: 12.0,
        hsnCode: "3004",
      ),
      Medicine(
        id: "demo_3",
        systemId: "PH-10003",
        name: "CALPOL 500",
        packing: "15 TAB",
        mrp: 15.50,
        purRate: 12.00,
        rateA: 14.50,
        rateB: 14.00,
        rateC: 13.50,
        stock: 0.0,
        gst: 12.0,
        hsnCode: "3004",
      ),
      Medicine(
        id: "demo_4",
        systemId: "PH-10004",
        name: "LIMCEE 500",
        packing: "15 TAB",
        mrp: 25.00,
        purRate: 18.00,
        rateA: 23.00,
        rateB: 22.00,
        rateC: 20.00,
        stock: 0.0,
        gst: 12.0,
        hsnCode: "3004",
      ),
      Medicine(
        id: "demo_5",
        systemId: "PH-10005",
        name: "AZITHRAL 500",
        packing: "5 TAB",
        mrp: 115.00,
        purRate: 88.00,
        rateA: 105.00,
        rateB: 100.00,
        rateC: 98.00,
        stock: 0.0,
        gst: 12.0,
        hsnCode: "3004",
      ),
    ];
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
