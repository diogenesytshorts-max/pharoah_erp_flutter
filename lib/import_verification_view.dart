import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'package:intl/intl.dart';
import 'sale_bill_number.dart';

class ImportVerificationView extends StatefulWidget {
  final List<List<dynamic>> csvData;
  final String importType;
  final bool isOtherFormat;
  const ImportVerificationView({super.key, required this.csvData, required this.importType, this.isOtherFormat = false});

  @override State<ImportVerificationView> createState() => _ImportVerificationViewState();
}

class _ImportVerificationViewState extends State<ImportVerificationView> {
  int currentStep = 0;
  final billNoC = TextEditingController();
  final internalNoC = TextEditingController();
  DateTime selectedDate = DateTime.now();
  final pNameC = TextEditingController();
  final pGstC = TextEditingController();
  final pStateC = TextEditingController();
  bool isNewParty = false;
  List<Map<String, dynamic>> itemsToImport = [];

  @override
  void initState() {
    super.initState();
    _initializeWizard();
  }

  void _initializeWizard() {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    var firstRow = widget.csvData[1];

    // Column Mapping: 0:Date, 1:BillNo, 4:PartyName, 5:GSTIN, 8:ItemName (for Sale)
    billNoC.text = firstRow[1].toString();
    internalNoC.text = widget.importType == "PURCHASE" ? firstRow[2].toString() : "";
    try { selectedDate = DateFormat('dd/MM/yyyy').parse(firstRow[0].toString()); } catch (e) { selectedDate = DateTime.now(); }

    String extractedParty = firstRow[4].toString().toUpperCase().trim();
    Party? existing = ph.parties.where((p) => p.name.toUpperCase() == extractedParty).firstOrNull;

    if (existing == null) {
      isNewParty = true; pNameC.text = extractedParty;
      pGstC.text = firstRow[5].toString();
      pStateC.text = firstRow[6].toString();
    } else {
      isNewParty = false; pNameC.text = existing.name; pGstC.text = existing.gst;
    }

    for (int i = 1; i < widget.csvData.length; i++) {
      var r = widget.csvData[i];
      if (r.length < 10) continue;
      // Naye format ke hisab se index set kiye hain:
      int nameIdx = widget.importType == "SALE" ? 8 : 7;
      int qtyIdx = widget.importType == "SALE" ? 13 : 12;
      int rateIdx = widget.importType == "SALE" ? 14 : 14;

      itemsToImport.add({
        'name': r[nameIdx].toString().toUpperCase(),
        'batch': r[nameIdx+2].toString().toUpperCase(),
        'exp': r[nameIdx+3].toString(),
        'qty': double.tryParse(r[qtyIdx].toString()) ?? 0,
        'rate': double.tryParse(r[rateIdx].toString()) ?? 0,
        'gst': double.tryParse(r[rateIdx+2].toString().replaceAll("%", "")) ?? 12,
        'total': double.tryParse(r[rateIdx+4].toString()) ?? 0,
        'exists': ph.medicines.any((m) => m.name.toUpperCase() == r[nameIdx].toString().toUpperCase()),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Verify ${widget.importType} (Step ${currentStep + 1}/3)"), backgroundColor: Colors.indigo),
      body: currentStep == 0 ? _stepHeader() : (currentStep == 1 ? _stepParty() : _stepItems()),
      bottomNavigationBar: _buildNavigator(),
    );
  }

  Widget _stepHeader() {
    return Padding(padding: const EdgeInsets.all(25), child: Column(children: [const Icon(Icons.fact_check, size: 60, color: Colors.indigo), const SizedBox(height: 20), TextField(controller: billNoC, decoration: const InputDecoration(labelText: "Invoice No", border: OutlineInputBorder())), const SizedBox(height: 15), ListTile(tileColor: Colors.grey.shade100, title: Text("Date: ${DateFormat('dd MMMM yyyy').format(selectedDate)}"), trailing: const Icon(Icons.calendar_month), onTap: () async { DateTime? p = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (p != null) setState(() => selectedDate = p); })]));
  }

  Widget _stepParty() {
    return Padding(padding: const EdgeInsets.all(20), child: Column(children: [Text(isNewParty ? "CREATE NEW PARTY" : "PARTY RECOGNIZED", style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 20), TextField(controller: pNameC, enabled: isNewParty, decoration: const InputDecoration(labelText: "Party Name", border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: pGstC, decoration: const InputDecoration(labelText: "GSTIN", border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: pStateC, decoration: const InputDecoration(labelText: "State", border: OutlineInputBorder()))]));
  }

  Widget _stepItems() {
    return ListView.builder(itemCount: itemsToImport.length, itemBuilder: (c, i) {
      var it = itemsToImport[i];
      return ListTile(title: Text(it['name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), subtitle: Text("Qty: ${it['qty']} | Rate: ${it['rate']} | Batch: ${it['batch']}"), trailing: Icon(it['exists'] ? Icons.check_circle : Icons.add_circle, color: it['exists'] ? Colors.green : Colors.orange));
    });
  }

  Widget _buildNavigator() {
    return Container(padding: const EdgeInsets.all(15), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [if (currentStep > 0) OutlinedButton(onPressed: () => setState(() => currentStep--), child: const Text("BACK")), ElevatedButton(onPressed: () { if (currentStep < 2) setState(() => currentStep++); else _finishImport(); }, child: Text(currentStep == 2 ? "FINALIZE" : "NEXT"))]));
  }

  void _finishImport() async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    Party targetParty;
    if (isNewParty) {
      targetParty = Party(id: DateTime.now().toString(), name: pNameC.text.toUpperCase(), state: pStateC.text, gst: pGstC.text.toUpperCase());
      ph.parties.add(targetParty);
    } else {
      targetParty = ph.parties.firstWhere((p) => p.name.toUpperCase() == pNameC.text.toUpperCase());
    }

    if (widget.importType == "SALE") {
      List<BillItem> bItems = itemsToImport.map((it) {
        Medicine m = _getOrCreateMed(ph, it);
        return BillItem(id: DateTime.now().toString(), srNo: 0, medicineID: m.id, name: m.name, packing: m.packing, batch: it['batch'], exp: it['exp'], hsn: "N/A", mrp: it['rate']*1.2, qty: it['qty'], rate: it['rate'], gstRate: it['gst'], total: it['total']);
      }).toList();
      ph.finalizeSale(billNo: billNoC.text, date: selectedDate, party: targetParty, items: bItems, total: bItems.fold(0, (s, i) => s + i.total), mode: "CREDIT");
    }
    ph.save(); Navigator.pop(context);
  }

  Medicine _getOrCreateMed(PharoahManager ph, Map<String, dynamic> it) {
    Medicine? existing = ph.medicines.where((m) => m.name.toUpperCase() == it['name']).firstOrNull;
    if (existing == null) {
      Medicine n = Medicine(id: DateTime.now().toString(), name: it['name'], packing: "N/A", mrp: it['rate']*1.2, rateA: it['rate'], rateB: it['rate'], rateC: it['rate'], purRate: it['rate'], gst: it['gst']);
      ph.medicines.add(n); return n;
    }
    return existing;
  }
}
