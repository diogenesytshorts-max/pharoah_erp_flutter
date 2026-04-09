import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'sale_bill_number.dart';
import 'billing_view.dart';

class SaleEntryView extends StatefulWidget {
  final Sale? existingSale;
  final bool isReadOnly;
  const SaleEntryView({super.key, this.existingSale, this.isReadOnly = false});

  @override
  State<SaleEntryView> createState() => _SaleEntryViewState();
}

class _SaleEntryViewState extends State<SaleEntryView> {
  String bN = ""; 
  DateTime bD = DateTime.now(); 
  String pM = "CASH"; 
  Party? sP; 
  String sPT = "";
  DateTime fD = DateTime(2025, 4, 1); 
  DateTime lD = DateTime(2026, 3, 31);
  final bNoC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFY();
    if (widget.existingSale != null) { 
      bN = widget.existingSale!.billNo; 
      bD = widget.existingSale!.date; 
      pM = widget.existingSale!.paymentMode; 
      bNoC.text = bN; 
    } else { 
      _loadNum(); 
    }
  }

  _loadFY() async {
    final p = await SharedPreferences.getInstance();
    String fy = p.getString('fy') ?? "2025-26";
    try {
      int sY = int.parse(fy.split('-')[0]); 
      if (sY < 2000) sY += 2000;
      setState(() { 
        fD = DateTime(sY, 4, 1); 
        lD = DateTime(sY + 1, 3, 31); 
        if (bD.isBefore(fD) || bD.isAfter(lD)) bD = fD; 
      });
    } catch (e) {
      debugPrint("FY Load Error: $e");
    }
  }

  _loadNum() async { 
    bN = await SaleBillNumber.getNextNumber(); 
    setState(() { bNoC.text = bN; }); 
  }

  void _validate(PharoahManager ph) {
    if (sP == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a party first")));
      return;
    }

    if (widget.isReadOnly) { 
      _go(); 
      return; 
    }

    bool isNew = widget.existingSale == null;

    // 1. Duplicate Bill Check
    if (isNew || bNoC.text != widget.existingSale!.billNo) {
      bool exists = ph.sales.any((s) => s.billNo == bNoC.text && s.id != widget.existingSale?.id);
      if (exists) {
        final partyName = ph.sales.firstWhere((s) => s.billNo == bNoC.text).partyName;
        showDialog(
          context: context, 
          builder: (c) => AlertDialog(
            title: const Text("Duplicate Bill!"), 
            content: Text("Bill ${bNoC.text} already issued to $partyName."), 
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))]
          )
        );
        return;
      }
    }

    // 2. Bill Series Change Check
    if (isNew && bNoC.text != bN) {
      showDialog(
        context: context, 
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: const Text("Change Series?"), 
          content: Text("You changed the Bill No from $bN to ${bNoC.text}.\n\nDo you want to start future bills from this new number?"), 
          actions: [
            TextButton(
              onPressed: () { 
                Navigator.pop(c); // Pehle dialog band karo
                _go();           // Phir aage badho
              }, 
              child: const Text("ONLY THIS BILL")
            ),
            TextButton(
              onPressed: () async { 
                Navigator.pop(c); // Pehle dialog band karo
                await SaleBillNumber.updateSeriesFromFull(bNoC.text); 
                _go();           // Phir aage badho
              }, 
              child: const Text("YES, CHANGE SERIES")
            )
          ]
        )
      );
    } else { 
      _go(); 
    }
  }

  void _go() {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (c) => BillingView(
          party: sP!, 
          billNo: bNoC.text, 
          billDate: bD, 
          mode: pM, 
          existingItems: widget.existingSale?.items, 
          modifySaleId: widget.existingSale?.id, 
          isReadOnly: widget.isReadOnly
        )
      )
    );
  }

  @override 
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // Agar modify mode hai toh party auto-select karein
    if (widget.existingSale != null && sP == null) { 
      sP = ph.parties.firstWhere((p) => p.name == widget.existingSale!.partyName, orElse: () => ph.parties[0]); 
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isReadOnly ? "View Bill" : (widget.existingSale == null ? "New Sale" : "Modify Sale")),
        backgroundColor: widget.isReadOnly ? Colors.purple : Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(15), 
            color: widget.isReadOnly ? Colors.grey[200] : Colors.blue[50], 
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: bNoC, 
                        enabled: !widget.isReadOnly, 
                        decoration: const InputDecoration(
                          labelText: "BILL NO",
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white
                        )
                      )
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: widget.isReadOnly ? null : () async { 
                          DateTime? p = await showDatePicker(
                            context: context, 
                            initialDate: bD, 
                            firstDate: fD, 
                            lastDate: lD
                          ); 
                          if (p != null) setState(() => bD = p); 
                        }, 
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.white
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end, 
                            children: [
                              const Text("DATE", style: TextStyle(fontSize: 10)), 
                              Text(DateFormat('dd/MM/yyyy').format(bD), style: const TextStyle(fontWeight: FontWeight.bold))
                            ]
                          )
                        )
                      )
                    )
                  ],
                ),
                const SizedBox(height: 15),
                AbsorbPointer(
                  absorbing: widget.isReadOnly, 
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'CASH', label: Text('CASH')), 
                      ButtonSegment(value: 'CREDIT', label: Text('CREDIT'))
                    ], 
                    selected: {pM}, 
                    onSelectionChanged: (v) => setState(() => pM = v.first)
                  )
                )
              ],
            ),
          ),

          // Party Selection Section
          if (sP != null) 
            Card(
              margin: const EdgeInsets.all(15),
              child: ListTile(
                leading: const Icon(Icons.person, color: Colors.blue, size: 30), 
                title: Text(sP!.name, style: const TextStyle(fontWeight: FontWeight.bold)), 
                subtitle: Text("${sP!.city} | ${sP!.phone}"), 
                trailing: widget.isReadOnly || widget.existingSale != null 
                  ? const Icon(Icons.lock, color: Colors.grey) 
                  : IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => sP = null))
              ),
            )
          else 
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(15), 
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: "Search Party...",
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder()
                      ), 
                      onChanged: (v) => setState(() => sPT = v)
                    )
                  ),
                  Expanded(
                    child: ListView(
                      children: ph.parties
                          .where((p) => p.name.toLowerCase().contains(sPT.toLowerCase()))
                          .map((p) => ListTile(
                                leading: const Icon(Icons.person_outline),
                                title: Text(p.name), 
                                subtitle: Text(p.city),
                                onTap: () => setState(() => sP = p)
                              ))
                          .toList()
                    ),
                  )
                ],
              )
            ),

          // Bottom Button
          if (sP != null) 
            Padding(
              padding: const EdgeInsets.all(20), 
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55), 
                  backgroundColor: widget.isReadOnly ? Colors.purple : Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ), 
                onPressed: () => _validate(ph), 
                child: Text(
                  widget.isReadOnly ? "VIEW ITEMS" : "PROCEED TO BILLING", 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                )
              ),
            )
        ],
      ),
    );
  }
}
