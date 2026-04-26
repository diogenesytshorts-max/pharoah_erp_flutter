import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'pdf/sale_report_pdf.dart'; 
import 'pdf/sale_invoice_pdf.dart'; // Naya Import: Invoice ke liye
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
    
    // Filter Logic: Sirf active bills aur search query ke hisab se
    List<Sale> filteredSales = ph.sales.reversed.where((s) {
      bool dateMatch = s.date.isAfter(fromDate.subtract(const Duration(days: 1))) && s.date.isBefore(toDate.add(const Duration(days: 1)));
      bool searchMatch = s.billNo.toLowerCase().contains(searchQuery.toLowerCase()) || s.partyName.toLowerCase().contains(searchQuery.toLowerCase());
      return s.status == "Active" && dateMatch && searchMatch;
    }).toList();

    // Bottom totals calculation
    double totalTaxable = 0; double totalTax = 0; double netTotal = 0;
    for(var s in filteredSales) {
      double sTax = s.items.fold(0.0, (sum, it) => sum + (it.cgst + it.sgst + it.igst));
      totalTax += sTax; totalTaxable += (s.totalAmount - sTax); netTotal += s.totalAmount;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Sales Register / History"), 
        backgroundColor: Colors.blue.shade900, 
        foregroundColor: Colors.white,
        actions: [
          // AppBar wala icon poori list ki report generate karega
          IconButton(
            icon: const Icon(Icons.picture_as_pdf), 
            tooltip: "Export Sales Register",
            onPressed: filteredSales.isEmpty ? null : () => SaleReportPdf.generate(filteredSales, fromDate, toDate, null)
          )
        ],
      ),
      body: Column(children: [
        // Filter Header Section
        Container(
          padding: const EdgeInsets.all(12), color: Colors.white,
          child: Column(children: [
            Row(children: [
              Expanded(child: _dateTile("FROM", fromDate, (d) => setState(()=> fromDate = d))),
              const SizedBox(width: 10),
              Expanded(child: _dateTile("TO", toDate, (d) => setState(()=> toDate = d))),
            ]),
            Padding(padding: const EdgeInsets.only(top: 10), child: TextField(
              decoration: const InputDecoration(
                hintText: "Search Bill No or Party...", 
                prefixIcon: Icon(Icons.search), 
                border: OutlineInputBorder(),
                isDense: true
              ),
              onChanged: (v) => setState(() => searchQuery = v)
            ))
          ]),
        ),
        
        // Sales List
        Expanded(
          child: filteredSales.isEmpty 
          ? const Center(child: Text("No records found for selected period."))
          : ListView.builder(
            padding: const EdgeInsets.all(10), itemCount: filteredSales.length,
            itemBuilder: (c, i) {
              final s = filteredSales[i];
              // Party details nikalna taaki Invoice par address/GST sahi aaye
              final p = ph.parties.firstWhere(
                (x) => x.name == s.partyName, 
                orElse: () => Party(id: "", name: s.partyName, address: "N/A", gst: s.partyGstin)
              );

              return Card(
                elevation: 2, margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  title: Text(s.partyName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Bill: ${s.billNo} | Date: ${DateFormat('dd/MM/yy').format(s.date)}\nTotal: ₹${s.totalAmount.toStringAsFixed(2)}"),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    // ROW PRINT BUTTON: Yeh ab asli Sale Invoice PDF generate karega
                    IconButton(
                      icon: const Icon(Icons.print, color: Colors.blueGrey), 
                      tooltip: "Print Bill",
                      onPressed: () => SaleInvoicePdf.generate(s, p)
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue), 
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SaleEntryView(existingSale: s)))
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red), 
                      onPressed: () => _confirmDelete(context, ph, s.id)
                    ),
                  ]),
                ),
              );
            },
          )
        ),
        
        // Bottom Summary Bar
        Container(
          padding: const EdgeInsets.all(15), color: Colors.blue.shade900,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _botCol("TAXABLE", totalTaxable), 
            _botCol("TOTAL GST", totalTax), 
            _botCol("NET TOTAL", netTotal, isNet: true),
          ]),
        )
      ]),
    );
  }

  Widget _dateTile(String l, DateTime d, Function(DateTime) onPick) {
    return InkWell(
      onTap: () async { DateTime? p = await showDatePicker(context: context, initialDate: d, firstDate: DateTime(2020), lastDate: DateTime(2100)); if(p!=null) onPick(p); },
      child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(5)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)), Text(DateFormat('dd/MM/yyyy').format(d), style: const TextStyle(fontWeight: FontWeight.bold))])),
    );
  }

  Widget _botCol(String l, double v, {bool isNet = false}) {
    return Column(children: [Text(l, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)), Text("₹${v.toStringAsFixed(2)}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isNet ? 16 : 12))]);
  }

  void _confirmDelete(BuildContext context, PharoahManager ph, String id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Bill?"),
        content: const Text("Kya aap is bill को permanent delete करना चाहते हैं? इससे स्टॉक वापस जुड़ जाएगा।"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () { ph.deleteBill(id); Navigator.pop(c); }, 
            child: const Text("YES, DELETE", style: TextStyle(color: Colors.white))
          )
        ],
      ),
    );
  }
}
