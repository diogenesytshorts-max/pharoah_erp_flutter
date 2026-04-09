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

  // --- GETTERS FOR REAL-TIME TOTALS ---
  double get grandTotal => items.fold(0, (sum, item) => sum + item.total);
  double get totalTaxable => items.fold(0, (sum, item) => sum + (item.total - (item.cgst + item.sgst + item.igst)));
  double get totalGstAmt => items.fold(0, (sum, item) => sum + (item.cgst + item.sgst + item.igst));

  @override
  void initState() {
    super.initState();
    // Load existing items if in modify mode
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
        backgroundColor: widget.isReadOnly ? Colors.purple : Colors.blue.shade700,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.party.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              "${widget.billNo} | ${widget.mode} | ${isB2B ? "B2B (TAX)" : "B2C (RETAIL)"}", 
              style: const TextStyle(fontSize: 10, letterSpacing: 0.5)
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded), 
            onPressed: items.isEmpty ? null : () => _saveAndPrint(ph)
          ),
          if (!widget.isReadOnly)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: items.isEmpty ? null : () => _saveAndClose(ph),
                style: TextButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2)),
                child: const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // --- 1. SEARCH BAR ---
              if (selectedMed == null && !widget.isReadOnly)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey.shade100,
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: "Search Medicine / Product Name...",
                      prefixIcon: const Icon(Icons.search, color: Colors.blue),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (val) => setState(() => search = val),
                  ),
                ),

              // --- 2. ITEM ENTRY FORM (RESTORED WITH ALL RATES) ---
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
                  onCancel: () => setState(() {
                    selectedMed = null;
                    editingIndex = null;
                  }),
                ),

              // --- 3. ITEMS LIST ---
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Qty: ${item.qty.toInt()} | Batch: ${item.batch} | Exp: ${item.exp}"),
                          Text(
                            "Rate: ₹${item.rate} | Taxable: ₹${(item.total - (item.cgst + item.sgst + item.igst)).toStringAsFixed(2)}",
                            style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("₹${item.total.toStringAsFixed(2)}", 
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
                          if (!widget.isReadOnly)
                            IconButton(
                              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
                              onPressed: () => setState(() => items.removeAt(index)),
                            ),
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

              // --- 4. PROFESSIONAL SUMMARY FOOTER ---
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _footerStat("TAXABLE", "₹${totalTaxable.toStringAsFixed(2)}"),
                        _footerStat("TOTAL GST", "₹${totalGstAmt.toStringAsFixed(2)}"),
                        _footerStat("ITEMS", "${items.length}"),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("GRAND TOTAL", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          Text("₹${grandTotal.toStringAsFixed(2)}", 
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.green)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // --- 5. SEARCH OVERLAY ---
          if (search.isNotEmpty && selectedMed == null)
            Positioned(
              top: 70, left: 15, right: 15,
              child: Material(
                elevation: 15,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: ListView(
                    shrinkWrap: true,
                    children: ph.medicines
                        .where((m) => m.name.toLowerCase().contains(search.toLowerCase()))
                        .map((m) => ListTile(
                              leading: const Icon(Icons.medication_liquid, color: Colors.blue),
                              title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("Pack: ${m.packing} | Stock: ${m.stock} | MRP: ${m.mrp}"),
                              onTap: () => setState(() {
                                selectedMed = m;
                                search = "";
                              }),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _footerStat(String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
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

// =====================================================================
// --- ITEM ENTRY FORM (THE CALCULATION ENGINE) ---
// =====================================================================
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

  // --- RATE C FORMULA: (MRP / (1 + GST/100)) - (Rate C Disc %) ---
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
      padding: const EdgeInsets.all(15), 
      decoration: BoxDecoration(color: Colors.blue.shade50, border: Border(bottom: BorderSide(color: Colors.blue.shade200, width: 2))),
      child: Column(
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.blue.shade700, borderRadius: BorderRadius.circular(5)),
              child: Text("${widget.srNo}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.med.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.blue))),
            IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: widget.onCancel)
          ]),
          const SizedBox(height: 10),
          // Row 1: Batch, Exp, GST
          Row(children: [
            Expanded(child: _field(bC, "Batch No")),
            const SizedBox(width: 5),
            Expanded(child: _field(eC, "Exp (MM/YY)")),
            const SizedBox(width: 5),
            Expanded(child: _field(gC, "GST %", onChange: (v) { if(rT=="C") _calculateRateC(); })),
          ]),
          const SizedBox(height: 12),
          // Row 2: Rate Switcher
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'A', label: Text('Rate A')),
              ButtonSegment(value: 'B', label: Text('Rate B')),
              ButtonSegment(value: 'C', label: Text('Rate C (Formula)')),
            ],
            selected: {rT},
            onSelectionChanged: (val) => _handleRateSwitch(val.first),
          ),
          const SizedBox(height: 12),
          // Row 3: MRP, RC Disc, Rate, Qty
          Row(children: [
            Expanded(child: _field(mC, "MRP", onChange: (v) { if(rT=="C") _calculateRateC(); })),
            if (rT == "C") ...[
              const SizedBox(width: 5),
              Expanded(child: _field(rCD, "RC Disc %", onChange: (v) => _calculateRateC())),
            ],
            const SizedBox(width: 5),
            Expanded(child: _field(rC, "Net Rate", isEnabled: rT != "C")),
            const SizedBox(width: 5),
            Expanded(child: _field(qC, "Quantity")),
          ]),
          // Row 4: Extra Discounts
          Row(children: [
            Expanded(child: _field(dpC, "Cash Disc %")),
            const SizedBox(width: 5),
            Expanded(child: _field(drC, "Cash Disc ₹")),
          ]),
          const SizedBox(height: 15),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50), 
              backgroundColor: Colors.blue.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
            ),
            onPressed: () {
              double r = double.tryParse(rC.text) ?? 0; double q = double.tryParse(qC.text) ?? 0;
              double dp = double.tryParse(dpC.text) ?? 0; double dr = double.tryParse(drC.text) ?? 0;
              double g = double.tryParse(gC.text) ?? 0;

              double gross = r * q;
              double taxable = gross - (gross * dp / 100) - dr;
              double gstAmt = taxable * (g / 100);
              
              // --- STATE-BASED GST LOGIC (IGST vs CGST/SGST) ---
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
            child: const Text("ADD TO BILL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
          )
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String l, {Function(String)? onChange, bool isEnabled = true}) {
    return TextField(
      controller: c, enabled: isEnabled, onChanged: onChange,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      decoration: InputDecoration(
        labelText: l, 
        labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ), 
      keyboardType: TextInputType.text
    );
  }
}
