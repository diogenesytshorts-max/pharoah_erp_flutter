import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'sale_bill_number.dart';
import 'pdf_service.dart';

class BillingView extends StatefulWidget {
  final Party party;
  final String billNo;
  final DateTime billDate;
  final String mode;
  final List<BillItem>? existingItems;
  final String? modifySaleId;
  final bool isReadOnly;

  const BillingView({
    super.key,
    required this.party,
    required this.billNo,
    required this.billDate,
    required this.mode,
    this.existingItems,
    this.modifySaleId,
    this.isReadOnly = false,
  });

  @override
  State<BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends State<BillingView> {
  List<BillItem> items = [];
  String search = "";
  Medicine? selectedMed;
  int? editingIndex;

  // Computed Totals
  double get grandTotal => items.fold(0, (sum, item) => sum + item.total);
  double get totalTaxable => items.fold(0, (sum, item) => sum + (item.total - (item.cgst + item.sgst + item.igst)));
  double get totalGstAmt => items.fold(0, (sum, item) => sum + (item.cgst + item.sgst + item.igst));

  @override
  void initState() {
    super.initState();
    if (widget.existingItems != null) {
      items = List.from(widget.existingItems!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    bool isB2B = widget.party.isB2B;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 2,
        backgroundColor: widget.isReadOnly ? Colors.purple : Colors.blue,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.party.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text("${widget.billNo} | ${widget.mode} | TYPE: ${isB2B ? "B2B (Tax)" : "B2C (Retail)"}", style: const TextStyle(fontSize: 10)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.print), onPressed: items.isEmpty ? null : () => _saveAndPrint(ph)),
          if (!widget.isReadOnly)
            TextButton(
              onPressed: items.isEmpty ? null : () => _saveAndClose(ph),
              child: const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search Bar
              if (selectedMed == null && !widget.isReadOnly)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey[100],
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: "Search Product...",
                      prefixIcon: const Icon(Icons.search, color: Colors.blue),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) => setState(() => search = val),
                  ),
                ),

              // Dynamic Item Entry Form
              if (selectedMed != null)
                ItemEntryForm(
                  med: selectedMed!,
                  partyState: widget.party.state,
                  shopState: ph.companyState,
                  srNo: editingIndex ?? items.length + 1,
                  existingItem: editingIndex != null ? items[editingIndex!] : null,
                  onAdd: (newItem) {
                    setState(() {
                      if (editingIndex != null) {
                        items[editingIndex!] = newItem;
                      } else {
                        items.add(newItem);
                      }
                      selectedMed = null;
                      editingIndex = null;
                      search = "";
                    });
                  },
                  onCancel: () => setState(() { selectedMed = null; editingIndex = null; }),
                ),

              // Items List
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Qty: ${item.qty.toInt()} | Batch: ${item.batch} | Rate: ₹${item.rate}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("₹${item.total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          if (!widget.isReadOnly)
                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => setState(() => items.removeAt(index))),
                        ],
                      ),
                      onTap: widget.isReadOnly ? null : () => setState(() {
                        selectedMed = ph.medicines.firstWhere((m) => m.id == item.medicineID);
                        editingIndex = index;
                      }),
                    );
                  },
                ),
              ),

              // Professional Footer
              Container(
                padding: const EdgeInsets.all(15),
                decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("TAXABLE: ₹${totalTaxable.toStringAsFixed(2)}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text("GST AMT: ₹${totalGstAmt.toStringAsFixed(2)}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ]),
                    Text("TOTAL: ₹${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
            ],
          ),

          // Search Suggestions Overlay
          if (search.isNotEmpty && selectedMed == null)
            Positioned(
              top: 70, left: 15, right: 15,
              child: Material(
                elevation: 10,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView(
                    shrinkWrap: true,
                    children: ph.medicines.where((m) => m.name.toLowerCase().contains(search.toLowerCase()))
                        .map((m) => ListTile(
                              leading: const Icon(Icons.medication),
                              title: Text(m.name),
                              subtitle: Text("Pack: ${m.packing} | Stock: ${m.stock}"),
                              onTap: () => setState(() { selectedMed = m; search = ""; }),
                            )).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _saveAndClose(PharoahManager ph) async {
    if (widget.modifySaleId != null) ph.deleteBill(widget.modifySaleId!);
    ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: grandTotal, mode: widget.mode);
    if (widget.modifySaleId == null) await SaleBillNumber.incrementIfNecessary(widget.billNo);
    if (mounted) Navigator.pop(context);
  }

  void _saveAndPrint(PharoahManager ph) async {
    final sale = Sale(id: DateTime.now().toString(), billNo: widget.billNo, date: widget.billDate, partyName: widget.party.name, items: items, totalAmount: grandTotal, paymentMode: widget.mode);
    if (!widget.isReadOnly) {
      if (widget.modifySaleId != null) ph.deleteBill(widget.modifySaleId!);
      ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: grandTotal, mode: widget.mode);
      if (widget.modifySaleId == null) await SaleBillNumber.incrementIfNecessary(widget.billNo);
    }
    await PdfService.generateInvoice(sale, widget.party);
    if (!widget.isReadOnly && mounted) Navigator.pop(context);
  }
}

class ItemEntryForm extends StatefulWidget {
  final Medicine med; 
  final String partyState; 
  final String shopState;
  final int srNo; 
  final BillItem? existingItem; 
  final Function(BillItem) onAdd; 
  final VoidCallback onCancel;

  const ItemEntryForm({super.key, required this.med, required this.partyState, required this.shopState, required this.srNo, this.existingItem, required this.onAdd, required this.onCancel});

  @override
  State<ItemEntryForm> createState() => _ItemEntryFormState();
}

class _ItemEntryFormState extends State<ItemEntryForm> {
  final bC = TextEditingController(); 
  final eC = TextEditingController(); 
  final gC = TextEditingController();
  final mC = TextEditingController(); 
  final rC = TextEditingController(); 
  final qC = TextEditingController();
  final dpC = TextEditingController(text: "0"); 
  final drC = TextEditingController(text: "0");
  final rCD = TextEditingController(text: "0"); // Rate C Discount %
  String rT = "A";

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      bC.text = widget.existingItem!.batch; eC.text = widget.existingItem!.exp;
      gC.text = widget.existingItem!.gstRate.toString(); mC.text = widget.existingItem!.mrp.toString();
      rC.text = widget.existingItem!.rate.toString(); qC.text = widget.existingItem!.qty.toString();
      dpC.text = widget.existingItem!.discountPercent.toString(); drC.text = widget.existingItem!.discountRupees.toString();
    } else {
      mC.text = widget.med.mrp.toString(); gC.text = widget.med.gst.toString();
      rC.text = widget.med.rateA.toString(); qC.text = "1";
    }
  }

  // --- RATE C FORMULA ENGINE ---
  void _calculateRateC() {
    double mrp = double.tryParse(mC.text) ?? 0;
    double gst = double.tryParse(gC.text) ?? 0;
    double disc = double.tryParse(rCD.text) ?? 0;
    double baseTaxable = mrp / (1 + (gst / 100));
    double finalRateC = baseTaxable - (baseTaxable * (disc / 100));
    rC.text = finalRateC.toStringAsFixed(2);
  }

  void _handleRateSwitch(String val) {
    setState(() {
      rT = val;
      if (rT == "A") rC.text = widget.med.rateA.toString();
      else if (rT == "B") rC.text = widget.med.rateB.toString();
      else if (rT == "C") _calculateRateC();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15), color: Colors.blue[50],
      child: Column(
        children: [
          Row(children: [
            Text("${widget.srNo}. ${widget.med.name}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(), IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: widget.onCancel)
          ]),
          Row(children: [
            Expanded(child: _f(bC, "Batch")),
            const SizedBox(width: 5),
            Expanded(child: _f(eC, "Exp")),
            const SizedBox(width: 5),
            Expanded(child: _f(gC, "GST %", onChange: (v) { if(rT=="C") _calculateRateC(); })),
          ]),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'A', label: Text('Rate A')),
              ButtonSegment(value: 'B', label: Text('Rate B')),
              ButtonSegment(value: 'C', label: Text('Rate C (Formula)')),
            ],
            selected: {rT},
            onSelectionChanged: (val) => _handleRateSwitch(val.first),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _f(mC, "MRP", onChange: (v) { if(rT=="C") _calculateRateC(); })),
            if (rT == "C") ...[
              const SizedBox(width: 5),
              Expanded(child: _f(rCD, "RC Disc %", onChange: (v) => _calculateRateC())),
            ],
            const SizedBox(width: 5),
            Expanded(child: _f(rC, "Net Rate", isEnabled: rT != "C")),
            const SizedBox(width: 5),
            Expanded(child: _f(qC, "Qty")),
          ]),
          Row(children: [
            Expanded(child: _f(dpC, "Disc %")),
            const SizedBox(width: 5),
            Expanded(child: _f(drC, "Disc ₹")),
          ]),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45), backgroundColor: Colors.blue),
            onPressed: () {
              double r = double.tryParse(rC.text) ?? 0; double q = double.tryParse(qC.text) ?? 0;
              double dp = double.tryParse(dpC.text) ?? 0; double dr = double.tryParse(drC.text) ?? 0;
              double g = double.tryParse(gC.text) ?? 0;

              double taxable = (r * q) - ((r * q) * dp / 100) - dr;
              double gstAmt = taxable * (g / 100);
              
              // --- IGST vs CGST/SGST LOGIC ---
              double cgst = 0, sgst = 0, igst = 0;
              if (widget.partyState.trim().toLowerCase() == widget.shopState.trim().toLowerCase()) {
                cgst = gstAmt / 2; sgst = gstAmt / 2;
              } else {
                igst = gstAmt;
              }

              widget.onAdd(BillItem(
                id: DateTime.now().toString(), srNo: widget.srNo, medicineID: widget.med.id, 
                name: widget.med.name, packing: widget.med.packing, batch: bC.text.toUpperCase(), 
                exp: eC.text, hsn: widget.med.hsnCode, mrp: double.tryParse(mC.text) ?? 0, 
                qty: q, rate: r, discountPercent: dp, discountRupees: dr, gstRate: g, 
                cgst: cgst, sgst: sgst, igst: igst, total: taxable + gstAmt
              ));
            }, 
            child: const Text("ADD TO BILL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          )
        ],
      ),
    );
  }

  Widget _f(TextEditingController c, String l, {Function(String)? onChange, bool isEnabled = true}) {
    return TextField(
      controller: c, enabled: isEnabled, onChanged: onChange,
      decoration: InputDecoration(labelText: l, labelStyle: const TextStyle(fontSize: 10)), 
      keyboardType: TextInputType.text
    );
  }
}
