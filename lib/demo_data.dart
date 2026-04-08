import 'models.dart';

class DemoData {
  static List<Medicine> getMedicines() {
    List<String> names = [
      "DOLO 650 MG", "PAN 40 MG", "CALPOL 500", "LIMCEE 500", "AZITHRAL 500",
      "TELMA 40", "AMLOVAS 5", "GLYCOMET GP2", "PANTOCID 40", "CLAVAM 625",
      "TAXIM O 200", "MONTEK LC", "SHELCAL 500", "AZEE 500", "ARKAMIN",
      "METOSAR 25", "CANDIFORCE 200", "EVMION 400", "NEOBION", "ZIFI 200",
      "ITMAC 200", "VOGLIBOSE 0.3", "ROSUVAS 10", "ATORVA 20", "THYRONORM 50",
      "LIV 52 DS", "CYPON SYRUP", "COMBIFLAM", "SARIDON", "VICKS ACTION 500",
      "DERMIFORD", "BETNOVATE N", "CLOBETASOL", "DICLOFENAC GEL", "ORAL REHYDRATION",
      "BETADINE", "OFLOX 200", "CIPLOX 500", "NORFLOX TZ", "METROGYL 400",
      "DIGENE GEL", "GELUSIL MPS", "MUCAINE GEL", "DUFALAC SYRUP", "CREMAFFIN",
      "OKACET", "ALERID", "AVIL 25", "LEVOCET", "MONTINA L"
    ];
    
    return List.generate(names.length, (index) => Medicine(
      id: "demo_$index",
      name: names[index],
      packing: "10 TAB",
      manufacturer: "Demo Pharma",
      hsnCode: "3004",
      gst: 12.0,
      mrp: 50.0 + index,
      rateA: 40.0 + index,
      rateB: 38.0 + index,
      rateC: 35.0 + index,
      stock: 100
    ));
  }

  static Party getDemoParty() {
    return Party(
      id: "demo_party_1",
      name: "DEMO PHARMA DISTRIBUTORS",
      address: "61, ANAND NAGAR, UNIVERSITY ROAD",
      city: "UDAIPUR",
      route: "CITY MAIN ROUTE",
      phone: "9876543210",
      email: "demo@pharoah.com",
      dl: "20B-111602, 21B-111605",
      gst: "08FSBPM0623R1ZC",
      openingBalance: 5000.0,
      specialDiscount: 2.0
    );
  }
}
