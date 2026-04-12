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
  int currentStep = 0; // 0: Bill Header, 1: Party/Supplier, 2: Products List

  // STEP 0: Header Controllers
  final billNoC = TextEditingController();
  final internalNoC = TextEditingController();
  DateTime selectedDate = DateTime.now();

  // STEP 1: Party Controllers
  final pNameC = TextEditingController();
  final pAddrC = TextEditingController();
  final pCityC = TextEditingController();
  final pStateC = TextEditingController();
  final pGstC = TextEditingController();
  final pDlC = TextEditingController();
  final pPhoneC = TextEditingController();
  final pEmailC = TextEditingController();
  bool isNewParty = false;

  // STEP 2: Items List
  List<Map<String, dynamic>> itemsToImport = [];

  @override
  void initState() {
    super.initState();
    _initializeWizard();
  }

  void _initializeWizard() {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    var firstRow = widget.csvData[1];

    // Header logic
    billNoC.text = firstRow[1].toString();
    internalNoC.text = widget.importType == "PURCHASE" ? "IMP-${firstRow[1]}" : "";
    try {
      selectedDate = DateFormat('dd/MM/yyyy').parse(firstRow[0].toString());
    } catch (e) {
      selectedDate = DateTime.now();
    }

    // Party Recognition Logic
    String extractedParty = firstRow[2].toString().toUpperCase().trim();
    Party? existing = ph.parties.where((p) => p.name.toUpperCase() == extractedParty).firstOrNull;

    if (existing == null) {
      isNewParty = true;
      pNameC.text = extractedParty;
      pGstC.text = (widget.csvData[1].length > 3) ? widget.csvData[1][3].toString() : "";
      pStateC.text = (widget.csvData[1].length > 4) ? widget.csvData[1][4].toString() : "Rajasthan";
    } else {
      isNewParty = false;
      pNameC.text = existing.name;
      pAddrC.text = existing.address;
      pGstC.text = existing.gst;
      pDlC.text = existing.dl;
      pPhoneC.text = existing.phone;
    }

    // Item Extraction (Sale vs Purchase)
    for (int i = 1; i < widget.csvData.length; i++) {
      var r = widget.csvData[i];
      if (r.length < 5) continue;

      String name = widget.importType == "SALE" ? r[5].toString() : r[4].toString();
      double rate = double.tryParse(widget.importType == "SALE" ? r[10].toString() : r[9].toString()) ?? 0;
      double qty = double.tryParse(widget.importType == "SALE" ? r[9].toString() : r[7].toString()) ?? 0;
      double gst = double.tryParse(widget.importType == "SALE" ? r[11].toString() : r[10].toString()) ?? 12;

      itemsToImport.add({
        'name': name.toUpperCase(),
        'batch': (widget.importType == "SALE" ? r[6].toString() : r[5].toString()).toUpperCase(),
        'exp': widget.importType == "SALE" ? r[7].toString() : r[6].toString(),
        'qty': qty,
        'free': widget.importType == "PURCHASE" ? (double.tryParse(r[8].toString()) ?? 0) : 0,
        'rate': rate,
        'gst': gst,
        'total': double.tryParse(widget.importType == "SALE" ? r[12].toString() : r[11].toString()) ?? (rate * qty),
        'exists': ph.medicines.any((m) => m.name.toUpperCase() == name.toUpperCase()),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("${widget.importType} IMPORT (Step ${currentStep + 1}/3)"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildCurrentStepView(),
      bottomNavigationBar: _buildNavigator(),
    );
  }

  Widget _buildCurrentStepView() {
    if (currentStep == 0) return _stepHeader();
    if (currentStep == 1) return _stepParty();
    return _stepItems();
  }

  // --- UI STEPS ---

  Widget _stepHeader() {
    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(children: [
        const Icon(Icons.receipt_long, size: 60, color: Colors.indigo),
        const SizedBox(height: 20),
        const Text("Verify Bill Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 30),
        TextField(controller: billNoC, decoration: const InputDecoration(labelText: "Invoice / Bill Number", border: OutlineInputBorder())),
        const SizedBox(height: 15),
        if (widget.importType == "PURCHASE") TextField(controller: internalNoC, decoration: const InputDecoration(labelText: "Internal ID (PUR-X)", border: OutlineInputBorder())),
        const SizedBox(height: 15),
        ListTile(
          tileColor: Colors.grey.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
          title: const Text("Transaction Date", style: TextStyle(fontSize: 12)),
          subtitle: Text(DateFormat('dd MMMM yyyy').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          trailing: const Icon(Icons.edit_calendar, color: Colors.indigo),
          onTap: () async {
            DateTime? p = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (p != null) setState(() => selectedDate = p);
          },
        )
      ]),
    );
  }

  Widget _stepParty() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: isNewParty ? Colors.orange.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Icon(isNewParty ? Icons.person_add : Icons.verified_user, color: isNewParty ? Colors.orange : Colors.green),
            const SizedBox(width: 10),
            Text(isNewParty ? "NEW PARTY: Auto-create in Master" : "EXISTS: Linked to Master Data"),
          ]),
        ),
        const SizedBox(height: 20),
        _input(pNameC, "Firm / Customer Name", enabled: isNewParty),
        _input(pAddrC, "Office Address"),
        Row(children: [Expanded(child: _input(pCityC, "City")), const SizedBox(width: 10), Expanded(child: _input(pStateC, "State"))]),
        Row(children: [Expanded(child: _input(pGstC, "GSTIN")), const SizedBox(width: 10), Expanded(child: _input(pDlC, "DL Number"))]),
        Row(children: [Expanded(child: _input(pPhoneC, "Mobile No.", isNum: true)), const SizedBox(width: 10), Expanded(child: _input(pEmailC, "Email Address"))]),
      ]),
    );
  }

  Widget _stepItems() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        color: Colors.indigo.shade900,
        child: const Row(children: [
          Expanded(flex: 3, child: Text("ITEM NAME", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
          Expanded(child: Text("BATCH", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
          Expanded(child: Text("QTY", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
          Expanded(child: Text("TOTAL", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          itemCount: itemsToImport.length,
          separatorBuilder: (c, i) => const Divider(height: 1),
          itemBuilder: (c, i) {
            var it = itemsToImport[i];
            return ListTile(
              onTap: () => _editItemPopup(i),
              dense: true,
              tileColor: it['exists'] ? Colors.white : Colors.red.shade50,
              title: Row(children: [
                Expanded(flex: 3, child: Text(it['name'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(child: Text(it['batch'], style: const TextStyle(fontSize: 9))),
                Expanded(child: Text("${it['qty']}", style: const TextStyle(fontSize: 9))),
                Expanded(child: Text("₹${it['total'].toStringAsFixed(0)}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue))),
              ]),
            );
          },
        ),
      )
    ]);
  }

  // --- FINALIZATION & SAVE ---

  void _editItemPopup(int index) {
    var it = itemsToImport[index];
    final nameC = TextEditingController(text: it['name']);
    final batchC = TextEditingController(text: it['batch']);
    final qtyC = TextEditingController(text: it['qty'].toString());
    final rateC = TextEditingController(text: it['rate'].toString());

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Edit Import Item"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameC, decoration: const InputDecoration(labelText: "Product Name")),
          TextField(controller: batchC, decoration: const InputDecoration(labelText: "Batch")),
          Row(children: [
            Expanded(child: TextField(controller: qtyC, decoration: const InputDecoration(labelText: "Qty"))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: rateC, decoration: const InputDecoration(labelText: "Rate"))),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(onPressed: () {
            setState(() {
              itemsToImport[index]['name'] = nameC.text.toUpperCase();
              itemsToImport[index]['batch'] = batchC.text.toUpperCase();
              itemsToImport[index]['qty'] = double.tryParse(qtyC.text) ?? 0;
              itemsToImport[index]['rate'] = double.tryParse(rateC.text) ?? 0;
              itemsToImport[index]['total'] = itemsToImport[index]['qty'] * itemsToImport[index]['rate'];
            });
            Navigator.pop(c);
          }, child: const Text("UPDATE")),
        ],
      ),
    );
  }

  void _finishImport() async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    
    // 1. Finalize Party
    Party targetParty;
    if (isNewParty) {
      targetParty = Party(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: pNameC.text.trim().toUpperCase(),
        address: pAddrC.text.trim(),
        city: pCityC.text.trim().toUpperCase(),
        state: pStateC.text.trim(),
        gst: pGstC.text.trim().toUpperCase(),
        dl: pDlC.text.trim().toUpperCase(),
        phone: pPhoneC.text.trim(),
        email: pEmailC.text.trim(),
      );
      ph.parties.add(targetParty);
    } else {
      targetParty = ph.parties.firstWhere((p) => p.name.toUpperCase() == pNameC.text.toUpperCase());
    }

    // 2. Finalize Items and Masters
    double grandTotal = 0;
    if (widget.importType == "SALE") {
      List<BillItem> billItems = [];
      for (var it in itemsToImport) {
        Medicine med = _getOrCreateMed(ph, it);
        billItems.add(BillItem(
          id: DateTime.now().toString(), srNo: billItems.length + 1, medicineID: med.id, name: med.name, packing: med.packing,
          batch: it['batch'], exp: it['exp'], hsn: med.hsnCode, mrp: med.mrp, qty: it['qty'], rate: it['rate'], gstRate: it['gst'], total: it['total']
        ));
        grandTotal += it['total'];
      }
      ph.finalizeSale(billNo: billNoC.text, date: selectedDate, party: targetParty, items: billItems, total: grandTotal, mode: "CREDIT");
      await SaleBillNumber.incrementIfNecessary(billNoC.text);
    } else {
      List<PurchaseItem> purItems = [];
      for (var it in itemsToImport) {
        Medicine med = _getOrCreateMed(ph, it);
        purItems.add(PurchaseItem(
          id: DateTime.now().toString(), srNo: purItems.length + 1, medicineID: med.id, name: med.name, packing: med.packing,
          batch: it['batch'], exp: it['exp'], hsn: med.hsnCode, mrp: med.mrp, qty: it['qty'], freeQty: it['free'], purchaseRate: it['rate'], gstRate: it['gst'], total: it['total']
        ));
        grandTotal += it['total'];
      }
      ph.finalizePurchase(internalNo: internalNoC.text, billNo: billNoC.text, date: selectedDate, party: targetParty, items: purItems, total: grandTotal, mode: "CREDIT");
    }

    ph.save();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Data Imported & Master Updated!"), backgroundColor: Colors.green));
  }

  Medicine _getOrCreateMed(PharoahManager ph, Map<String, dynamic> it) {
    Medicine? existing = ph.medicines.where((m) => m.name.toUpperCase() == it['name'].toUpperCase()).firstOrNull;
    if (existing == null) {
      Medicine newMed = Medicine(id: DateTime.now().toString(), name: it['name'], packing: "N/A", mrp: it['rate']*1.2, rateA: it['rate'], rateB: it['rate'], rateC: it['rate'], purRate: it['rate'], gst: it['gst']);
      ph.medicines.add(newMed);
      return newMed;
    }
    return existing;
  }

  Widget _buildNavigator() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        if (currentStep > 0) OutlinedButton(onPressed: () => setState(() => currentStep--), child: const Text("BACK")) else const SizedBox(),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: currentStep == 2 ? Colors.green : Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 40)),
          onPressed: () { if (currentStep < 2) setState(() => currentStep++); else _finishImport(); },
          child: Text(currentStep == 2 ? "FINALIZE IMPORT" : "NEXT"),
        )
      ]),
    );
  }

  Widget _input(TextEditingController c, String l, {bool enabled = true, bool isNum = false}) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: c, enabled: enabled, keyboardType: isNum ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: l, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.all(10))));
  }
}
