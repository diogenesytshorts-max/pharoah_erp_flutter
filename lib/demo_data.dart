// FILE: lib/demo_data.dart (Replacement Code)

import 'models.dart';

class DemoData {
  static List<Medicine> getMedicines() {
    return [
      Medicine(
        id: "demo_1",
        systemId: "PH-D-10001", // 'D' for Demo to avoid overlap
        name: "DOLO 650 MG",
        packing: "15 TAB",
        companyId: "MICRO LABS",
        mrp: 30.91,
        purRate: 25.40,
        rateA: 28.50,
        rateB: 27.00,
        rateC: 26.50,
        stock: 0.0,
        gst: 12.0,
        hsnCode: "3004",
        isScheduleH1: false,
        isNarcotic: false,
      ),
      Medicine(
        id: "demo_2",
        systemId: "PH-D-10002",
        name: "PAN 40 MG",
        packing: "10 TAB",
        companyId: "ALKEM LABORATORIES",
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
        systemId: "PH-D-10003",
        name: "AZITHRAL 500",
        packing: "5 TAB",
        companyId: "ALEMBIC PHARMA",
        mrp: 115.00,
        purRate: 88.00,
        rateA: 105.00,
        rateB: 100.00,
        rateC: 98.00,
        stock: 0.0,
        gst: 12.0,
        hsnCode: "3004",
        isScheduleH1: true, // Test ke liye H1 On kiya hai
      ),
      Medicine(
        id: "demo_4",
        systemId: "PH-D-10004",
        name: "FORTWIN INJECTION",
        packing: "1 ML",
        companyId: "SANOFI INDIA",
        mrp: 15.50,
        purRate: 10.00,
        rateA: 14.50,
        rateB: 14.00,
        rateC: 13.50,
        stock: 0.0,
        gst: 12.0,
        hsnCode: "3004",
        isNarcotic: true, // Test ke liye Narcotic On kiya hai
      ),
      Medicine(
        id: "demo_5",
        systemId: "PH-D-10005",
        name: "LIMCEE 500",
        packing: "15 TAB",
        companyId: "ABBOTT INDIA",
        mrp: 25.00,
        purRate: 18.00,
        rateA: 23.00,
        rateB: 22.00,
        rateC: 20.00,
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
