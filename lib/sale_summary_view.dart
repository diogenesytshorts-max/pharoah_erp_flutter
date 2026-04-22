import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'pdf/sale_report_pdf.dart'; 
import 'sale_entry_view.dart';

class SaleSummaryView extends StatefulWidget {
  const SaleSummaryView({super.key});
  @override State<SaleSummaryView> createState() => _SaleSummaryViewState();
}

class _SaleSummaryViewState extends State<SaleSummaryView> {
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // Filter Logic
    List<Sale> filteredSales = ph.sales.reversed.where((s) {
      bool dateMatch = s.date.isAfter(fromDate.subtract(const Duration(days: 1))) && s.date.isBefore(toDate.add(const Duration(days: 1)));
      bool searchMatch = s.billNo.toLowerCase().contains(searchQuery.toLowerCase()) || s.partyName.toLowerCase().contains(searchQuery.toLowerCase());
      return s.status == "Active" && dateMatch && searchMatch;
    }).toList();

    double totalTaxable = 0; double totalTax = 0; double netTotal = 0;
    for(var s in filteredSales) {
      double sTax = s.items.fold(0.0, (sum, it) => sum + (it.cgst + it.sgst + it.igst));
      totalTax += sTax; totalTaxable += (s.totalAmount - sTax); netTotal += s.totalAmount;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Sales Register"), backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: filteredSales.isEmpty ? null : () => SaleReportPdf.generate(filteredSales, fromDate, toDate, null))
        ],
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.all(12), color: Colors.white,
          child: Column(children: [
            Row(children: [
              Expanded(child: _dateTile("FROM", fromDate, (d) => setState(()=> fromDate = d))),
              const SizedBox(width: 10),
              Expanded(child: _dateTile("TO", toDate, (d) => setState(()=> toDate = d))),
            ]),
            Padding(padding: const EdgeInsets.only(top: 10), child: TextField(
              decoration: const InputDecoration(hintText: "Search Bill/Party...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
              onChanged: (v) => setState(() => searchQuery = v)
            ))
          ]),
        ),
        
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(10), itemCount: filteredSales.length,
            itemBuilder: (c, i) {
              final s = filteredSales[i];
              final p = ph.parties.firstWhere((x) => x.name == s.partyName, orElse: () => Party(id: "", name: s.partyName));
              return Card(
                elevation: 2, margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(s.partyName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Bill: ${s.billNo} | ${DateFormat('dd/MM/yy').format(s.date)}"),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.print, color: Colors.blueGrey), onPressed: () => SaleReportPdf.generate([s], s.date, s.date, p)),
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SaleEntryView(existingSale: s)))),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => ph.deleteBill(s.id)),
                  ]),
                ),
              );
            },
          )
        ),
        
        Container(
          padding: const EdgeInsets.all(15), color: Colors.blue.shade900,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _botCol("TAXABLE", totalTaxable), _botCol("TOTAL GST", totalTax), _botCol("NET TOTAL", netTotal, isNet: true),
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
    return Column(children: [Text(l, style: const TextStyle(color: Colors.white70, fontSize: 10)), Text("₹${v.toStringAsFixed(2)}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isNet ? 16 : 12))]);
  }
}
