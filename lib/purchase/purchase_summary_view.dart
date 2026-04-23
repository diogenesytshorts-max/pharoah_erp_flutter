import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../pdf/purchase_pdf.dart';
import '../pdf/purchase_report_pdf.dart'; 
import 'purchase_entry_view.dart'; 
import '../app_date_logic.dart'; // NAYA
import '../pharoah_date_controller.dart'; // NAYA

class PurchaseSummaryView extends StatefulWidget {
  const PurchaseSummaryView({super.key});
  @override State<PurchaseSummaryView> createState() => _PurchaseSummaryViewState();
}

class _PurchaseSummaryViewState extends State<PurchaseSummaryView> {
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  String searchQuery = "";
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final ph = Provider.of<PharoahManager>(context, listen: false);
      toDate = AppDateLogic.getSmartDate(ph.currentFY);
      DateTime thirtyDaysAgo = toDate.subtract(const Duration(days: 30));
      DateTime fyStart = AppDateLogic.getFYStart(ph.currentFY);
      fromDate = thirtyDaysAgo.isBefore(fyStart) ? fyStart : thirtyDaysAgo;
      _isInit = true;
    }
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    List<Purchase> filteredPur = ph.purchases.reversed.where((p) {
      bool dateMatch = p.date.isAfter(fromDate.subtract(const Duration(seconds: 1))) && 
                       p.date.isBefore(toDate.add(const Duration(seconds: 1)));
      bool searchMatch = p.distributorName.toLowerCase().contains(searchQuery.toLowerCase()) || 
                         p.billNo.toLowerCase().contains(searchQuery.toLowerCase());
      return dateMatch && searchMatch;
    }).toList();

    double totalTaxable = 0; double totalTax = 0; double netTotal = 0;
    for(var p in filteredPur) {
      double pTaxable = p.items.fold(0, (sum, it) => sum + (it.purchaseRate * it.qty));
      totalTaxable += pTaxable; totalTax += (p.totalAmount - pTaxable); netTotal += p.totalAmount;
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Purchase Register"), backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white, actions: [
        IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: filteredPur.isEmpty ? null : () => PurchaseReportPdf.generate(filteredPur, fromDate, toDate, null))
      ]),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.all(12), color: Colors.white,
          child: Column(children: [
            Row(children: [
              Expanded(child: _dateTile("FROM", fromDate, (d) => setState(()=> fromDate = d), ph.currentFY)),
              const SizedBox(width: 10),
              Expanded(child: _dateTile("TO", toDate, (d) => setState(()=> toDate = d), ph.currentFY)),
            ]),
            Padding(padding: const EdgeInsets.only(top: 10), child: TextField(decoration: const InputDecoration(hintText: "Search Supplier/Bill...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: (v) => setState(() => searchQuery = v)))
          ]),
        ),
        
        Expanded(
          child: filteredPur.isEmpty 
          ? const Center(child: Text("No records found."))
          : ListView.builder(
            padding: const EdgeInsets.all(10), itemCount: filteredPur.length,
            itemBuilder: (c, i) {
              final p = filteredPur[i];
              final supplier = ph.parties.firstWhere((pt) => pt.name == p.distributorName, orElse: () => Party(id: "", name: p.distributorName));
              return Card(
                elevation: 2, margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(p.distributorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Bill: ${p.billNo} | ${AppDateLogic.format(p.date)}"),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.print, color: Colors.blueGrey), onPressed: () => PurchasePdf.generate(p, supplier)),
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseEntryView(existingPurchase: p)))),
                  ]),
                ),
              );
            },
          )
        ),
        
        Container(
          padding: const EdgeInsets.all(15), color: Colors.deepOrange.shade900,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _botCol("TAXABLE", totalTaxable), _botCol("TOTAL ITC", totalTax), _botCol("NET TOTAL", netTotal, isNet: true),
          ]),
        )
      ]),
    );
  }

  Widget _dateTile(String l, DateTime d, Function(DateTime) onPick, String fy) {
    return InkWell(
      onTap: () async { 
        DateTime? p = await PharoahDateController.pickDate(context: context, currentFY: fy, initialDate: d); 
        if(p!=null) onPick(p); 
      },
      child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(5)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)), Text(DateFormat('dd/MM/yyyy').format(d), style: const TextStyle(fontWeight: FontWeight.bold))])),
    );
  }

  Widget _botCol(String l, double v, {bool isNet = false}) {
    return Column(children: [Text(l, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)), Text("₹${v.toStringAsFixed(2)}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isNet ? 16 : 12))]);
  }
}
