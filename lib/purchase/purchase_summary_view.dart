import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../pdf/purchase_report_pdf.dart'; 
import 'purchase_entry_view.dart'; 

class PurchaseSummaryView extends StatefulWidget {
  const PurchaseSummaryView({super.key});
  @override State<PurchaseSummaryView> createState() => _PurchaseSummaryViewState();
}

class _PurchaseSummaryViewState extends State<PurchaseSummaryView> {
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  Party? selectedSupplier;
  String supplierSearchText = "";

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ph = Provider.of<PharoahManager>(context, listen: false);
      setState(() { fromDate = ph.fyStartDate; toDate = DateTime.now(); });
    });
  }

  void _showSupplierSearch(List<Party> allParties) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Select Supplier"),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(hintText: "Search Supplier...", prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => supplierSearchText = v),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(title: const Text("ALL SUPPLIERS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)), onTap: () { setState(() => selectedSupplier = null); Navigator.pop(c); }),
                    ...allParties.where((p) => p.name.toLowerCase().contains(supplierSearchText.toLowerCase())).map((p) => ListTile(
                      title: Text(p.name),
                      subtitle: Text(p.city),
                      onTap: () { setState(() => selectedSupplier = p); Navigator.pop(c); },
                    ))
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // Filter Logic (Based on Supplier Bill Date)
    List<Purchase> filteredPur = ph.purchases.where((p) {
      bool dateMatch = p.date.isAfter(fromDate.subtract(const Duration(days: 1))) && p.date.isBefore(toDate.add(const Duration(days: 1)));
      bool partyMatch = selectedSupplier == null || p.distributorName == selectedSupplier!.name;
      return dateMatch && partyMatch;
    }).toList().reversed.toList();

    double totalTaxable = 0; double totalTax = 0; double netTotal = 0;
    for(var p in filteredPur) {
      double pTaxable = p.items.fold(0, (sum, it) => sum + (it.purchaseRate * it.qty));
      totalTaxable += pTaxable; totalTax += (p.totalAmount - pTaxable); netTotal += p.totalAmount;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Purchase Register"), backgroundColor: Colors.deepOrange.shade900, foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: filteredPur.isEmpty ? null : () => PurchaseReportPdf.generate(filteredPur, fromDate, toDate, selectedSupplier))
        ],
      ),
      body: Column(children: [
        // --- FILTERS ---
        Container(
          padding: const EdgeInsets.all(12), color: Colors.white,
          child: Column(children: [
            Row(children: [
              Expanded(child: _dateTile("FROM", fromDate, (d) => setState(()=> fromDate = d))),
              const SizedBox(width: 10),
              Expanded(child: _dateTile("TO", toDate, (d) => setState(()=> toDate = d))),
            ]),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _showSupplierSearch(ph.parties),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: Colors.orange.shade100), borderRadius: BorderRadius.circular(8), color: Colors.orange.shade50),
                child: Row(children: [
                  const Icon(Icons.store, color: Colors.orange), const SizedBox(width: 10),
                  Text(selectedSupplier?.name ?? "TAP TO SEARCH SUPPLIER / DISTRIBUTOR", style: TextStyle(fontWeight: FontWeight.bold, color: selectedSupplier == null ? Colors.blueGrey : Colors.orange.shade900)),
                  const Spacer(), const Icon(Icons.arrow_drop_down)
                ]),
              ),
            )
          ]),
        ),
        
        // --- LIST WITH DUAL DATES ---
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(10), itemCount: filteredPur.length,
            itemBuilder: (c, i) {
              final p = filteredPur[i];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  title: Text(p.distributorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text("Bill No: ${p.billNo}", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 12, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text("Bill: ${DateFormat('dd/MM/yy').format(p.date)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 15),
                          const Icon(Icons.computer, size: 12, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text("Entry: ${DateFormat('dd/MM/yy').format(p.entryDate)}", style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                        ],
                      ),
                      Text("Mode: ${p.paymentMode}", style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  trailing: Text("₹${p.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseEntryView(existingPurchase: p))),
                ),
              );
            },
          )
        ),
        
        // --- SUMMARY FOOTER ---
        Container(
          padding: const EdgeInsets.all(15), color: Colors.deepOrange.shade900,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _botCol("TAXABLE", totalTaxable), _botCol("TOTAL ITC", totalTax), _botCol("NET TOTAL", netTotal, isNet: true),
          ]),
        )
      ]),
    );
  }

  Widget _dateTile(String l, DateTime d, Function(DateTime) onPick) {
    return InkWell(
      onTap: () async { DateTime? p = await showDatePicker(context: context, initialDate: d, firstDate: DateTime(2020), lastDate: DateTime(2100)); if(p!=null) onPick(p); },
      child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(5)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 8, color: Colors.grey)), Text(DateFormat('dd/MM/yyyy').format(d), style: const TextStyle(fontWeight: FontWeight.bold))])),
    );
  }

  Widget _botCol(String l, double v, {bool isNet = false}) {
    return Column(children: [Text(l, style: const TextStyle(color: Colors.white70, fontSize: 10)), Text("₹${v.toStringAsFixed(2)}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isNet ? 18 : 14))]);
  }
}
