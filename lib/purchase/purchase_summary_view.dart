// FILE: lib/purchase/purchase_summary_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../pdf/pdf_router_service.dart';
import '../pdf/purchase_report_pdf.dart'; 
import 'purchase_entry_view.dart'; 
import '../app_date_logic.dart'; 
import '../pharoah_date_controller.dart'; 

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
      
      // Smart Logic: FY ke hisab se default range set karna
      toDate = AppDateLogic.getSmartDate(ph.currentFY);
      DateTime thirtyDaysAgo = toDate.subtract(const Duration(days: 30));
      DateTime fyStart = AppDateLogic.getFYStart(ph.currentFY);
      
      // From date 30 din piche hogi, lekin FY Start se pehle nahi
      fromDate = thirtyDaysAgo.isBefore(fyStart) ? fyStart : thirtyDaysAgo;
      _isInit = true;
    }
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final activeShop = ph.activeCompany;
    
    // Filter logic based on Date Range and Search
    List<Purchase> filteredPur = ph.purchases.reversed.where((p) {
      bool dateMatch = p.date.isAfter(fromDate.subtract(const Duration(days: 1))) && 
                       p.date.isBefore(toDate.add(const Duration(days: 1)));
      bool searchMatch = p.distributorName.toLowerCase().contains(searchQuery.toLowerCase()) || 
                         p.billNo.toLowerCase().contains(searchQuery.toLowerCase());
      return dateMatch && searchMatch;
    }).toList();

    // Summary Totals
    double totalTaxable = 0; double totalTax = 0; double netTotal = 0;
    for(var p in filteredPur) {
      double pTaxable = p.items.fold(0, (sum, it) => sum + (it.purchaseRate * it.qty));
      totalTaxable += pTaxable; 
      totalTax += (p.totalAmount - pTaxable); 
      netTotal += p.totalAmount;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Purchase Register"), 
        backgroundColor: Colors.orange.shade800, 
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf), 
            onPressed: (filteredPur.isEmpty || activeShop == null) 
              ? null 
              : () => PurchaseReportPdf.generate(filteredPur, fromDate, toDate, null, activeShop)
          )
        ],
      ),
      body: Column(children: [
        // --- 1. FILTER SECTION ---
        Container(
          padding: const EdgeInsets.all(12), color: Colors.white,
          child: Column(children: [
            Row(children: [
              Expanded(child: _dateTile("FROM", fromDate, (d) => setState(()=> fromDate = d), ph.currentFY)),
              const SizedBox(width: 10),
              Expanded(child: _dateTile("TO", toDate, (d) => setState(()=> toDate = d), ph.currentFY)),
            ]),
            Padding(padding: const EdgeInsets.only(top: 10), child: TextField(
              decoration: const InputDecoration(
                hintText: "Search Supplier/Bill...", 
                prefixIcon: Icon(Icons.search, color: Colors.orange), 
                border: OutlineInputBorder(), 
                isDense: true
              ), 
              onChanged: (v) => setState(() => searchQuery = v)
            ))
          ]),
        ),
        
        // --- 2. LIST SECTION ---
        Expanded(
          child: filteredPur.isEmpty 
          ? const Center(child: Text("No records found for this period."))
          : ListView.builder(
            padding: const EdgeInsets.all(10), itemCount: filteredPur.length,
            itemBuilder: (c, i) {
              final p = filteredPur[i];
              final supplier = ph.parties.firstWhere(
                (pt) => pt.name == p.distributorName, 
                orElse: () => Party(id: "", name: p.distributorName)
              );
              return Card(
                elevation: 2, margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  title: Text(p.distributorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text("Bill: ${p.billNo} | ${AppDateLogic.format(p.date)}", style: const TextStyle(fontSize: 12)),
          if (p.linkedChallanIds.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orange.shade200)),
              child: Text("MERGED", style: TextStyle(color: Colors.orange.shade900, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
      Text("Total: ₹${p.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
    ],
  ),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
  icon: const Icon(Icons.print, color: Colors.blueGrey), 
  onPressed: activeShop == null ? null : () => PdfRouterService.printPurchase(
    purchase: p, 
    supplier: supplier, 
    ph: ph
  )
),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue), 
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseEntryView(existingPurchase: p)))
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red), 
                      onPressed: () => _confirmDelete(context, ph, p.id)
                    ),
                  ]),
                ),
              );
            },
          )
        ),
        
        // --- 3. BOTTOM SUMMARY BAR ---
        Container(
          padding: const EdgeInsets.all(15), color: Colors.deepOrange.shade900,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _botCol("TAXABLE", totalTaxable), 
            _botCol("TOTAL ITC", totalTax), 
            _botCol("NET TOTAL", netTotal, isNet: true),
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
      child: Container(
        padding: const EdgeInsets.all(8), 
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(5)), 
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)), 
          Text(DateFormat('dd/MM/yyyy').format(d), style: const TextStyle(fontWeight: FontWeight.bold))
        ])
      ),
    );
  }

  Widget _botCol(String l, double v, {bool isNet = false}) {
    return Column(children: [Text(l, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)), Text("₹${v.toStringAsFixed(2)}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isNet ? 16 : 12))]);
  }

  void _confirmDelete(BuildContext context, PharoahManager ph, String id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Purchase?"),
        content: const Text("Are you sure you want to delete this purchase record? Stock will be adjusted back."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red), 
            onPressed: () { ph.deletePurchase(id); Navigator.pop(c); }, 
            child: const Text("YES, DELETE", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }
}
