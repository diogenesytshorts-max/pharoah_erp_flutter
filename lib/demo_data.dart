import 'models.dart';

class DemoData {
  static List<Medicine> getMedicines() {
    List<String> names = ["DOLO 650 MG", "PAN 40 MG", "CALPOL 500", "LIMCEE 500", "AZITHRAL 500"];
    return List.generate(names.length, (index) => Medicine(
      id: "demo_$index", name: names[index], packing: "10 TAB", mrp: 50.0 + index, rateA: 40.0 + index, rateB: 38.0 + index, rateC: 35.0 + index, stock: 100
    ));
  }

  static Party getDemoParty() {
    return Party(
      id: "demo_party_1", name: "DEMO PHARMA DISTRIBUTORS", address: "61, UNIVERSITY ROAD", city: "UDAIPUR", gst: "08FSBPM0623R1ZC"
    );
  }
}
