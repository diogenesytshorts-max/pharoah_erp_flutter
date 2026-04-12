import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../pdf_service.dart';

class PurchaseSummaryView extends StatefulWidget {
  const PurchaseSummaryView({super.key});
  @override State<PurchaseSummaryView> createState() => _PurchaseSummaryViewState();
}

class _PurchaseSummaryViewState extends State<PurchaseSummaryView> {
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();
  Party? selectedSupplier;

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ph = Provider.of<PharoahManager>(context, listen: false);
      setState(() { fromDate = ph.fyStartDate; toDate = DateTime.now(); });
    });
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    List<Purchase> filteredPur = ph.purchases.where((p) {
      bool dateMatch = p.date.isAfter(fromDate.subtract(const Duration(days: 1))) && p.date.isBefore(toDate.add(const Duration(days: 1)));
      bool partyMatch = selectedSupplier == null || p.distributorName == selectedSupplier!.name;
      return dateMatch && partyMatch;
    }).toList();

    double totalTaxable = 0; double totalTax = 0; double netTotal = 0;
    for(var p in filteredPur) {
      double pTaxable = 0; for(var it in p.items) pTaxable += (it.purchaseRate * it.qty);
      totalTaxable += pTaxable; totalTax += (p.totalAmount - pTaxable); netTotal += p.totalAmount;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Purchase Register / Summary"), backgroundColor: Colors.deepOrange.shade900, foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.print), onPressed: filteredPur.isEmpty ? null : () {
            // Placeholder - We will connect the PDF service here later
          })
        ],
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.all(15), color: Colors.white,
          child: Column(children: [
            Row(children: [
              Expanded(child: _datePicker("FROM DATE", fromDate, (d) => setState(()=> fromDate = d))), const SizedBox(width: 10),
              Expanded(child: _datePicker("TO DATE", toDate, (d) => setState(()=> toDate = d))),
            ]),
            const SizedBox(height: 10),
            DropdownButtonFormField<Party?>(
              decoration: const InputDecoration(labelText: "Filter by Supplier", border: OutlineInputBorder(), isDense: true),
              value: selectedSupplier,
              items: [
                const DropdownMenuItem(value: null, child: Text("All Suppliers")),
                ...ph.parties.map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
              ],
              onChanged: (v) => setState(() => selectedSupplier = v),
            )
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(10), itemCount: filteredPur.length,
            itemBuilder: (c, i) {
              final p = filteredPur[i];
              double pTaxable = 0; for(var it in p.items) pTaxable += (it.purchaseRate * it.qty);
              return Card(child: ListTile(
                title: Text(p.distributorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text("Bill: ${p.billNo} | ${DateFormat('dd/MM/yy').format(p.date)}\nTaxable: ₹${pTaxable.toStringAsFixed(2)} | GST: ₹${(p.totalAmount-pTaxable).toStringAsFixed(2)}", style: const TextStyle(fontSize: 11)),
                trailing: Text("₹${p.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              ));
            },
          )
        ),
        Container(
          padding: const EdgeInsets.all(15), color: Colors.deepOrange.shade900,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _botCol("TAXABLE", totalTaxable), _botCol("TOTAL GST (ITC)", totalTax), _botCol("NET TOTAL", netTotal, isNet: true),
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
