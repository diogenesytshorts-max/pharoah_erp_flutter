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

  // Computed totals for the summary footer
  double get grandTotal => items.fold(0, (sum, item) => sum + item.total);
  double get totalGst => items.fold(0, (sum, item) => sum + (item.cgst + item.sgst));
  double get totalTaxable => items.fold(0, (sum, item) => sum + (item.total - (item.cgst + item.sgst)));

  @override
  void initState() {
    super.initState();
    // Agar modify mode hai toh purane items list mein load kardo
    if (widget.existingItems != null) {
      items = List.from(widget.existingItems!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

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
            Text("${widget.billNo} | ${widget.mode} | FY: ${ph.currentFY}", style: const TextStyle(fontSize: 10)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: "Save and Print",
            onPressed: items.isEmpty ? null : () => _saveAndPrint(ph),
          ),
          if (!widget.isReadOnly)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
              // --- 1. SEARCH BAR (Hidden in Read-Only or while entering item) ---
              if (selectedMed == null && !widget.isReadOnly)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey[100],
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: "Search Medicine Name...",
                      prefixIcon: const Icon(Icons.search, color: Colors.blue),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (val) => setState(() => search = val),
                  ),
                ),

              // --- 2. DYNAMIC ITEM ENTRY FORM ---
              if (selectedMed != null)
                ItemEntryForm(
                  med: selectedMed!,
                  srNo: editingIndex ?? items.length + 1,
                  existingItem: editingIndex != null ? items[editingIndex!] : null,
                  onAdd: (newItem) {
                    setState(() {
                      if (editingIndex != null) {
                        items[editingIndex!] = newItem;
                      } else {
                        items.add(newItem);
                        ph.addToLocalInventory(selectedMed!);
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

              // --- 3. BILLING ITEMS LIST ---
              Expanded(
                child: Container(
                  color: Colors.grey[50],
                  child: items.isEmpty 
                    ? const Center(child: Text("No items added. Start searching above.", style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
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
                                Text("Qty: ${item.qty.toInt()} | B: ${item.batch} | E: ${item.exp} | GST: ${item.gstRate}%"),
                                Text("MRP: ${item.mrp} | Rate: ${item.rate} | Disc: ${item.discountPercent}% + ₹${item.discountRupees}", 
                                  style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("₹${item.total.toStringAsFixed(2)}", 
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
                                if (!widget.isReadOnly) ...[
                                  const SizedBox(width: 10),
                                  // --- COPY BUTTON ---
                                  IconButton(
                                    icon: const Icon(Icons.copy, color: Colors.orange, size: 20),
                                    onPressed: () => setState(() {
                                      selectedMed = ph.medicines.firstWhere((m) => m.id == item.medicineID);
                                      editingIndex = null; // As a fresh entry
                                    }),
                                  ),
                                  // --- DELETE BUTTON ---
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    onPressed: () => setState(() => items.removeAt(index)),
                                  ),
                                ]
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
              ),

              // --- 4. SUMMARY FOOTER (Professional ERP Look) ---
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
                        _summaryLabelValue("Taxable Value", "₹${totalTaxable.toStringAsFixed(2)}"),
                        _summaryLabelValue("Total GST", "₹${totalGst.toStringAsFixed(2)}"),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("TOTAL ITEMS: ${items.length}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const Text("Authorized Billing System", style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                          decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green)),
                          child: Text("GRAND TOTAL: ₹${grandTotal.toStringAsFixed(2)}", 
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // --- 5. SEARCH SUGGESTIONS DROP-DOWN OVERLAY ---
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

  Widget _summaryLabelValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _saveAndClose(PharoahManager ph) async {
    if (widget.modifySaleId != null) ph.deleteBill(widget.modifySaleId!);
    ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: grandTotal, mode: widget.mode);
    if (widget.modifySaleId == null) await SaleBillNumber.increment();
    if (mounted) Navigator.pop(context);
  }

  void _saveAndPrint(PharoahManager ph) async {
    final sale = Sale(id: DateTime.now().toString(), billNo: widget.billNo, date: widget.billDate, partyName: widget.party.name, items: items, totalAmount: grandTotal, paymentMode: widget.mode);
    if (!widget.isReadOnly) {
      if (widget.modifySaleId != null) ph.deleteBill(widget.modifySaleId!);
      ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: grandTotal, mode: widget.mode);
      if (widget.modifySaleId == null) await SaleBillNumber.increment();
    }
    await PdfService.generateInvoice(sale, widget.party);
    if (!widget.isReadOnly && mounted) Navigator.pop(context);
  }
}

// =====================================================================
// --- THE CALCULATION ENGINE: ITEM ENTRY FORM ---
// =====================================================================
class ItemEntryForm extends StatefulWidget {
  final Medicine med;
  final int srNo;
  final BillItem? existingItem;
  final Function(BillItem) onAdd;
  final VoidCallback onCancel;

  const ItemEntryForm({super.key, required this.med, required this.srNo, this.existingItem, required this.onAdd, required this.onCancel});

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
  final rCD = TextEditingController(text: "0.0"); // Rate C Discount %
  final nDP = TextEditingController(text: "0.0"); // Normal Discount %
  final nDR = TextEditingController(text: "0.0"); // Normal Discount ₹
  String rT = "A";

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      bC.text = widget.existingItem!.batch;
      eC.text = widget.existingItem!.exp;
      gC.text = widget.existingItem!.gstRate.toString();
      mC.text = widget.existingItem!.mrp.toString();
      rC.text = widget.existingItem!.rate.toString();
      qC.text = widget.existingItem!.qty.toString();
      nDP.text = widget.existingItem!.discountPercent.toString();
      nDR.text = widget.existingItem!.discountRupees.toString();
    } else {
      mC.text = widget.med.mrp.toString();
      gC.text = widget.med.gst.toString();
      rC.text = widget.med.rateA.toString();
      qC.text = "1";
    }

    // --- SMART MM/YY FORMATTER & VALIDATOR ---
    eC.addListener(() {
      String t = eC.text.replaceAll("/", "");
      if (t.length >= 2) {
        int month = int.tryParse(t.substring(0, 2)) ?? 1;
        if (month > 12) t = "12${t.substring(2)}";
        if (month == 0) t = "01${t.substring(2)}";
        String formatted = "${t.substring(0, 2)}/${t.substring(2)}";
        if (eC.text != formatted) {
          eC.text = formatted;
          eC.selection = TextSelection.fromPosition(TextPosition(offset: eC.text.length));
        }
      }
    });
  }

  // --- RATE C FORMULA: (MRP / (1 + GST/100)) - (Rate C Disc %) ---
  void _calculateRateC() {
    double mrp = double.tryParse(mC.text) ?? 0;
    double gst = double.tryParse(gC.text) ?? 0;
    double rCDisc = double.tryParse(rCD.text) ?? 0;

    double baseTaxable = (mrp / (1 + (gst / 100)));
    double finalRate = baseTaxable - (baseTaxable * (rCDisc / 100));
    rC.text = finalRate.toStringAsFixed(2);
  }

  void _handleRateSwitch() {
    if (rT == "A") {
      rC.text = widget.med.rateA.toString();
    } else if (rT == "B") {
      rC.text = widget.med.rateB.toString();
    } else {
      _calculateRateC();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final history = ph.batchHistory[widget.med.id] ?? [];

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.blue.withOpacity(0.3), width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(5)),
                child: Text("${widget.srNo}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.med.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue))),
              IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: widget.onCancel)
            ],
          ),
          
          // --- BATCH HISTORY CHIPS ---
          if (history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: history.map((b) => Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ActionChip(
                      backgroundColor: Colors.blue[50],
                      label: Text("${b.batch} (${b.exp})", style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        setState(() {
                          bC.text = b.batch; eC.text = b.exp; mC.text = b.mrp.toString(); rC.text = b.rate.toString();
                        });
                      },
                    ),
                  )).toList(),
                ),
              ),
            ),

          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _entryField(bC, "Batch No", icon: Icons.tag)),
              const SizedBox(width: 8),
              Expanded(child: _entryField(eC, "Exp (MM/YY)", icon: Icons.calendar_today, type: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _entryField(gC, "GST %", icon: Icons.percent, type: TextInputType.number, onChange: (v) { if(rT == 'C') _calculateRateC(); })),
            ],
          ),
          
          const SizedBox(height: 15),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'A', label: Text('Rate A')),
              ButtonSegment(value: 'B', label: Text('Rate B')),
              ButtonSegment(value: 'C', label: Text('Rate C (Formula)')),
            ],
            selected: {rT},
            onSelectionChanged: (val) {
              setState(() => rT = val.first);
              _handleRateSwitch();
            },
          ),

          const SizedBox(height: 15),
          Row(
            children: [
              if (rT == 'C')
                Expanded(child: _entryField(rCD, "RC Disc%", labelColor: Colors.purple, type: TextInputType.number, onChange: (v) => _calculateRateC())),
              Expanded(child: _entryField(mC, "MRP", type: TextInputType.number, onChange: (v) { if(rT == 'C') _calculateRateC(); })),
              Expanded(child: _entryField(rC, "Net Rate", type: TextInputType.number, isEnabled: rT != 'C', labelColor: Colors.blue)),
              Expanded(child: _entryField(qC, "Quantity", type: TextInputType.number)),
            ],
          ),
          
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _entryField(nDP, "Discount %", type: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: _entryField(nDR, "Cash Discount ₹", type: TextInputType.number)),
            ],
          ),

          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            onPressed: () {
              double r = double.tryParse(rC.text) ?? 0;
              double q = double.tryParse(qC.text) ?? 0;
              double dp = double.tryParse(nDP.text) ?? 0;
              double dr = double.tryParse(nDR.text) ?? 0;
              double g = double.tryParse(gC.text) ?? 0;

              // Full Professional Calculation
              double gross = r * q;
              double taxable = gross - (gross * (dp / 100)) - dr;
              double gstAmt = taxable * (g / 100);

              widget.onAdd(BillItem(
                id: DateTime.now().toString(),
                srNo: widget.srNo,
                medicineID: widget.med.id,
                name: widget.med.name,
                packing: widget.med.packing,
                batch: bC.text.toUpperCase(),
                exp: eC.text,
                hsn: widget.med.hsnCode,
                mrp: double.tryParse(mC.text) ?? 0,
                qty: q,
                rate: r,
                discountPercent: dp,
                discountRupees: dr,
                gstRate: g,
                cgst: gstAmt / 2,
                sgst: gstAmt / 2,
                total: taxable + gstAmt
              ));
            },
            child: const Text("ADD TO BILL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
    );
  }

  Widget _entryField(TextEditingController ctrl, String label, {IconData? icon, TextInputType type = TextInputType.text, Function(String)? onChange, bool isEnabled = true, Color? labelColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        enabled: isEnabled,
        onChanged: onChange,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 10, color: labelColor ?? Colors.grey[600]),
          prefixIcon: icon != null ? Icon(icon, size: 14) : null,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
      ),
    );
  }
}
