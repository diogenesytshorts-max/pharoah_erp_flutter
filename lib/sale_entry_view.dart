import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'sale_bill_number.dart';
import 'billing_view.dart'; // Agla step

class SaleEntryView extends StatefulWidget {
  const SaleEntryView({super.key});

  @override
  State<SaleEntryView> createState() => _SaleEntryViewState();
}

class _SaleEntryViewState extends State<SaleEntryView> {
  String billNo = "";
  DateTime billDate = DateTime.now();
  String paymentMode = "CASH";
  Party? selectedParty;
  String searchParty = "";

  @override
  void initState() {
    super.initState();
    _loadBillNo();
  }

  void _loadBillNo() async {
    String next = await SaleBillNumber.getNextNumber();
    setState(() => billNo = next);
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("New Sale Entry")),
      body: Column(
        children: [
          // --- HEADER: Bill No, Date, Mode ---
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.blue.withOpacity(0.05),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("BILL NO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          Text(billNo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          DateTime? picked = await showDatePicker(
                            context: context, initialDate: billDate,
                            firstDate: DateTime(2000), lastDate: DateTime(2100)
                          );
                          if(picked != null) setState(() => billDate = picked);
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text("DATE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            Text(DateFormat('dd/MM/yyyy').format(billDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'CASH', label: Text('CASH')),
                    ButtonSegment(value: 'CREDIT', label: Text('CREDIT')),
                  ],
                  selected: {paymentMode},
                  onSelectionChanged: (val) => setState(() => paymentMode = val.first),
                ),
              ],
            ),
          ),

          // --- PARTY SELECTION ---
          const Padding(
            padding: EdgeInsets.all(15),
            child: Align(alignment: Alignment.centerLeft, child: Text("SELECT PARTY / DISTRIBUTOR", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey))),
          ),

          if (selectedParty != null)
            ListTile(
              leading: const Icon(Icons.person, color: Colors.blue),
              title: Text(selectedParty!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(selectedParty!.phone),
              trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => selectedParty = null)),
            )
          else
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: TextField(
                      decoration: const InputDecoration(hintText: "Search Party Name...", prefixIcon: Icon(Icons.search)),
                      onChanged: (val) => setState(() => searchParty = val),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: ph.parties.length,
                      itemBuilder: (context, index) {
                        final p = ph.parties[index];
                        if (searchParty.isNotEmpty && !p.name.toLowerCase().contains(searchParty.toLowerCase())) return const SizedBox();
                        return ListTile(
                          title: Text(p.name),
                          onTap: () => setState(() => selectedParty = p),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          
          if (selectedParty != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.green),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => BillingView(
                    party: selectedParty!,
                    billNo: billNo,
                    billDate: billDate,
                    mode: paymentMode,
                  )));
                },
                child: const Text("CONTINUE TO BILLING", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}
