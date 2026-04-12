import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'pdf/sale_report_pdf.dart'; // Naya Report PDF import
import 'sale_entry_view.dart'; // Navigation ke liye

class SaleSummaryView extends StatefulWidget {
  const SaleSummaryView({super.key});
  @override State<SaleSummaryView> createState() => _SaleSummaryViewState();
}

class _SaleSummaryViewState extends State<SaleSummaryView> {
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  Party? selectedParty;
  String partySearchText = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ph = Provider.of<PharoahManager>(context, listen: false);
      setState(() { fromDate = ph.fyStartDate; toDate = DateTime.now(); });
    });
  }

  // --- SEARCHABLE PARTY DIALOG ---
  void _showPartySearch(List<Party> allParties) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Select Party"),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(hintText: "Search Name...", prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => partySearchText = v),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(title: const Text("ALL PARTIES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)), onTap: () { setState(() => selectedParty = null); Navigator.pop(c); }),
                    ...allParties.where((p) => p.name.toLowerCase().contains(partySearchText.toLowerCase())).map((p) => ListTile(
                      title: Text(p.name),
                      subtitle: Text(p.city),
                      onTap: () { setState(() => selectedParty = p); Navigator.pop(c); },
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

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // Filter Logic
    List<Sale> filteredSales = ph.sales.where((s) {
      bool dateMatch = s.date.isAfter(fromDate.subtract(const Duration(days: 1))) && s.date.isBefore(toDate.add(const Duration(days: 1)));
      bool partyMatch = selectedParty == null || s.partyName == selectedParty!.name;
      return s.status == "Active" && dateMatch && partyMatch;
    }).toList().reversed.toList();

    double totalTaxable = 0; double totalTax = 0; double netTotal = 0;
    double cashSum = 0; double creditSum = 0;

    for(var s in filteredSales) {
      double sTax = s.items.fold(0, (sum, it) => sum + (it.cgst + it.sgst + it.igst));
      totalTax += sTax; totalTaxable += (s.totalAmount - sTax); netTotal += s.totalAmount;
      if (s.paymentMode == "CASH") cashSum += s.totalAmount; else creditSum += s.totalAmount;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Sales Register"), backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: filteredSales.isEmpty ? null : () => SaleReportPdf.generate(filteredSales, fromDate, toDate, selectedParty))
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
              onTap: () => _showPartySearch(ph.parties),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: Colors.blue.shade100), borderRadius: BorderRadius.circular(8), color: Colors.blue.shade50),
                child: Row(children: [
                  const Icon(Icons.person_search, color: Colors.blue), const SizedBox(width: 10),
                  Text(selectedParty?.name ?? "TAP TO SEARCH PARTY / CUSTOMER", style: TextStyle(fontWeight: FontWeight.bold, color: selectedParty == null ? Colors.blueGrey : Colors.blue.shade900)),
                  const Spacer(), const Icon(Icons.arrow_drop_down)
                ]),
              ),
            )
          ]),
        ),
        
        // --- LIST ---
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(10), itemCount: filteredSales.length,
            itemBuilder: (c, i) {
              final s = filteredSales[i];
              return Card(
                child: ListTile(
                  title: Text(s.partyName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Bill: ${s.billNo} | ${DateFormat('dd/MM/yy').format(s.date)}\nMode: ${s.paymentMode}"),
                  trailing: Text("₹${s.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                  // CLICK KARNE PAR SEEDHA MODIFY SCREEN (SaleEntryView)
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SaleEntryView(existingSale: s))),
                ),
              );
            },
          )
        ),
        
        // --- DETAILED FOOTER ---
        Container(
          padding: const EdgeInsets.all(15), color: Colors.blue.shade900,
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _botCol("CASH SALE", cashSum), _botCol("CREDIT SALE", creditSum), _botCol("NET TOTAL", netTotal, isNet: true),
            ]),
            const Divider(color: Colors.white24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _botCol("TAXABLE", totalTaxable), _botCol("TOTAL GST", totalTax), _botCol("BILLS", filteredSales.length.toDouble(), isInt: true),
            ]),
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

  Widget _botCol(String l, double v, {bool isNet = false, bool isInt = false}) {
    return Column(children: [Text(l, style: const TextStyle(color: Colors.white70, fontSize: 9)), Text(isInt ? v.toInt().toString() : "₹${v.toStringAsFixed(2)}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isNet ? 16 : 12))]);
  }
}
