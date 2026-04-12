import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'pdf_service.dart';

class SaleSummaryView extends StatefulWidget {
  const SaleSummaryView({super.key});
  @override State<SaleSummaryView> createState() => _SaleSummaryViewState();
}

class _SaleSummaryViewState extends State<SaleSummaryView> {
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();
  Party? selectedParty;

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ph = Provider.of<PharoahManager>(context, listen: false);
      setState(() { fromDate = ph.fyStartDate; toDate = DateTime.now(); });
    });
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // Filter Logic
    List<Sale> filteredSales = ph.sales.where((s) {
      bool dateMatch = s.date.isAfter(fromDate.subtract(const Duration(days: 1))) && s.date.isBefore(toDate.add(const Duration(days: 1)));
      bool partyMatch = selectedParty == null || s.partyName == selectedParty!.name;
      return s.status == "Active" && dateMatch && partyMatch;
    }).toList();

    double totalTaxable = 0; double totalTax = 0; double netTotal = 0;
    for(var s in filteredSales) {
      double sTax = 0; for(var it in s.items) sTax += (it.cgst + it.sgst + it.igst);
      totalTax += sTax; totalTaxable += (s.totalAmount - sTax); netTotal += s.totalAmount;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Sales Register / Summary"), backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.print), onPressed: filteredSales.isEmpty ? null : () => PdfService.generateSaleSummaryPdf(filteredSales, fromDate, toDate, selectedParty))
        ],
      ),
      body: Column(children: [
        // Filters
        Container(
          padding: const EdgeInsets.all(15), color: Colors.white,
          child: Column(children: [
            Row(children: [
              Expanded(child: _datePicker("FROM DATE", fromDate, (d) => setState(()=> fromDate = d))), const SizedBox(width: 10),
              Expanded(child: _datePicker("TO DATE", toDate, (d) => setState(()=> toDate = d))),
            ]),
            const SizedBox(height: 10),
            DropdownButtonFormField<Party?>(
              decoration: const InputDecoration(labelText: "Filter by Party", border: OutlineInputBorder(), isDense: true),
              value: selectedParty,
              items: [
                const DropdownMenuItem(value: null, child: Text("All Parties")),
                ...ph.parties.map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
              ],
              onChanged: (v) => setState(() => selectedParty = v),
            )
          ]),
        ),
        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(10), itemCount: filteredSales.length,
            itemBuilder: (c, i) {
              final s = filteredSales[i];
              double sTax = 0; for(var it in s.items) sTax += (it.cgst + it.sgst + it.igst);
              return Card(child: ListTile(
                title: Text(s.partyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text("Inv: ${s.billNo} | ${DateFormat('dd/MM/yy').format(s.date)}\nTaxable: ₹${(s.totalAmount-sTax).toStringAsFixed(2)} | GST: ₹${sTax.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11)),
                trailing: Text("₹${s.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              ));
            },
          )
        ),
        // Footer Summary
        Container(
          padding: const EdgeInsets.all(15), color: Colors.blue.shade900,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _botCol("TAXABLE", totalTaxable), _botCol("TOTAL GST", totalTax), _botCol("NET TOTAL", netTotal, isNet: true),
          ]),
        )
      ]),
    );
  }

  Widget _datePicker(String label, DateTime date, Function(DateTime) onPick) {
    return InkWell(
      onTap: () async { DateTime? p = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100)); if(p!=null) onPick(p); },
      child: InputDecorator(decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true), child: Text(DateFormat('dd/MM/yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.bold))),
    );
  }

  Widget _botCol(String l, double v, {bool isNet = false}) {
    return Column(children: [Text(l, style: const TextStyle(color: Colors.white70, fontSize: 10)), Text("₹${v.toStringAsFixed(2)}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isNet ? 18 : 14))]);
  }
}
