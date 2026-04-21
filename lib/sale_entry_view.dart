import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'sale_bill_number.dart';
import 'billing_view.dart';
import 'package:intl/intl.dart';

class SaleEntryView extends StatefulWidget {
  final Sale? existingSale;
  const SaleEntryView({super.key, this.existingSale});

  @override State<SaleEntryView> createState() => _SaleEntryViewState();
}

class _SaleEntryViewState extends State<SaleEntryView> {
  DateTime selectedDate = DateTime.now();
  String paymentMode = "CASH"; 
  Party? selectedParty; 
  String searchQuery = "";
  final billNoC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeEntry();
  }

  void _initializeEntry() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ph = Provider.of<PharoahManager>(context, listen: false);
      if (widget.existingSale != null) {
        setState(() {
          selectedDate = widget.existingSale!.date;
          paymentMode = widget.existingSale!.paymentMode;
          billNoC.text = widget.existingSale!.billNo;
          selectedParty = ph.parties.firstWhere((p) => p.name == widget.existingSale!.partyName, orElse: () => ph.parties[0]);
        });
      } else {
        String nextNo = await SaleBillNumber.getNextNumber(ph.sales);
        setState(() { billNoC.text = nextNo; });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text(widget.existingSale == null ? "New Sale Invoice" : "Edit Invoice"),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- HEADER: DATE & BILL NO ---
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(child: TextField(controller: billNoC, decoration: const InputDecoration(labelText: "BILL NO", border: OutlineInputBorder()))),
                const SizedBox(width: 15),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      DateTime? p = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
                      if (p != null) setState(() => selectedDate = p);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd/MM/yyyy').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                          const Icon(Icons.calendar_month, size: 18, color: Colors.blue),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- MODE & PARTY SELECTION ---
          Padding(
            padding: const EdgeInsets.all(15),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'CASH', label: Text('CASH'), icon: Icon(Icons.money)),
                ButtonSegment(value: 'CREDIT', label: Text('CREDIT'), icon: Icon(Icons.credit_card)),
              ],
              selected: {paymentMode},
              onSelectionChanged: (v) => setState(() => paymentMode = v.first),
            ),
          ),

          if (selectedParty != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Card(
                elevation: 3,
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.person, color: Colors.white)),
                  title: Text(selectedParty!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("City: ${selectedParty!.city} | Rate Level: ${selectedParty!.priceLevel}"),
                  trailing: IconButton(icon: const Icon(Icons.change_circle, color: Colors.red), onPressed: () => setState(() => selectedParty = null)),
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Search Customer Name...", 
                        prefixIcon: const Icon(Icons.search),
                        filled: true, fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)
                      ),
                      onChanged: (v) => setState(() => searchQuery = v),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: ph.parties
                        .where((p) => p.name.toLowerCase().contains(searchQuery.toLowerCase()))
                        .map((p) => ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(p.city),
                          onTap: () => setState(() => selectedParty = p),
                        )).toList(),
                    ),
                  ),
                ],
              ),
            ),

          if (selectedParty != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60),
                  backgroundColor: Colors.green.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => BillingView(
                    party: selectedParty!, 
                    billNo: billNoC.text, 
                    billDate: selectedDate, 
                    mode: paymentMode,
                    existingItems: widget.existingSale?.items,
                    modifySaleId: widget.existingSale?.id,
                  )));
                },
                child: const Text("PROCEED TO BILLING", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ),
        ],
      ),
    );
  }
}
