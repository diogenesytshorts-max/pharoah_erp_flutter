import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'sale_bill_number.dart';
import 'pdf/sale_invoice_pdf.dart'; 
import 'package:intl/intl.dart';

// --- AUTO SLASH FORMATTER (MM/YY) ---
class ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (newValue.selection.baseOffset < oldValue.selection.baseOffset) return newValue;
    if (text.length == 2 && !text.contains('/')) {
      return TextEditingValue(
        text: '$text/',
        selection: TextSelection.collapsed(offset: 3),
      );
    }
    return newValue;
  }
}

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

  @override State<BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends State<BillingView> {
  List<BillItem> items = [];
  String search = "";
  Medicine? selectedMed;
  int? editingIndex; 

  double get grandTotal => items.fold(0, (sum, item) => sum + item.total);

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
            Text("${widget.billNo} | ${widget.mode}", style: const TextStyle(fontSize: 10)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded), 
            onPressed: items.isEmpty ? null : () => _printBill(),
          ),
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
              // --- 1. SEARCH BAR ---
              if (selectedMed == null && !widget.isReadOnly)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey.shade100,
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: "Search Medicine...",
                      prefixIcon: const Icon(Icons.search, color: Colors.blue),
                      filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) => setState(() => search = val),
                  ),
                ),

              // --- 2. ITEM ENTRY FORM ---
              if (selectedMed != null)
                ItemEntryForm(
                  med: selectedMed!,
                  partyState: widget.party.state,
                  shopState: ph.companyState,
                  priceLevel: widget.party.priceLevel, // Party ka default rate pass kiya
                  srNo: editingIndex != null ? (editingIndex! + 1) : items.length + 1,
                  existingItem: editingIndex != null ? items[editingIndex!] : null,
                  batchHistory: ph.batchHistory[selectedMed!.id] ?? [],
                  onAdd: (newItem) {
                    ph.saveBatchCentrally(newItem.medicineID, BatchInfo(
                      batch: newItem.batch, exp: newItem.exp, packing: newItem.packing, mrp: newItem.mrp, rate: newItem.rate,
                    ));
                    setState(() {
                      if (editingIndex != null) items[editingIndex!] = newItem;
                      else items.add(newItem);
                      selectedMed = null; editingIndex = null; search = "";
                    });
                  },
                  onCancel: () => setState(() { selectedMed = null; editingIndex = null; }),
                ),

              // --- 3. ADDED ITEMS LIST ---
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Qty: ${item.qty} + ${item.freeQty} | Batch: ${item.batch} | Exp: ${item.exp}"),
                      trailing: Text("₹${item.total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      onTap: widget.isReadOnly ? null : () => setState(() {
                        selectedMed = ph.medicines.firstWhere((m) => m.id == item.medicineID);
                        editingIndex = index;
                      }),
                    );
                  },
                ),
              ),

              // --- 4. FOOTER TOTAL ---
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.blue.shade50, border: Border(top: BorderSide(color: Colors.blue.shade200))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("GRAND TOTAL", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    Text("₹${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.blue)),
                  ],
                ),
              ),
            ],
          ),

          // --- 5. SEARCH RESULTS ---
          if (search.isNotEmpty && selectedMed == null)
            Positioned(
              top: 70, left: 15, right: 15,
              child: Material(
                elevation: 15,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView(
                    shrinkWrap: true,
                    children: ph.medicines
                        .where((m) => m.name.toLowerCase().contains(search.toLowerCase()))
                        .map((m) => ListTile(
                          leading: const Icon(Icons.medication, color: Colors.blue),
                          title: Text(m.name),
                          subtitle: Text("Stock: ${m.stock} | MRP: ${m.mrp}"),
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Sale Saved!"), backgroundColor: Colors.green));
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _printBill() async {
    final sale = Sale(
      id: widget.modifySaleId ?? DateTime.now().toString(),
      billNo: widget.billNo,
      date: widget.billDate,
      partyName: widget.party.name,
      partyGstin: widget.party.gst,
      partyState: widget.party.state,
      items: items,
      totalAmount: grandTotal,
      paymentMode: widget.mode,
      invoiceType: widget.party.isB2B ? "B2B" : "B2C",
    );
    await SaleInvoicePdf.generate(sale, widget.party);
  }
}

// --- ITEM ENTRY FORM COMPONENT ---
class ItemEntryForm extends StatefulWidget {
  final Medicine med; final String partyState, shopState, priceLevel; final int srNo;
  final BillItem? existingItem; final List<BatchInfo> batchHistory;
  final Function(BillItem) onAdd; final VoidCallback onCancel;

  const ItemEntryForm({super.key, required this.med, required this.partyState, required this.shopState, required this.priceLevel, required this.srNo, this.existingItem, required this.batchHistory, required this.onAdd, required this.onCancel});

  @override State<ItemEntryForm> createState() => _ItemEntryFormState();
}

class _ItemEntryFormState extends State<ItemEntryForm> {
  final bC = TextEditingController(); // Batch Controller
  final eC = TextEditingController();
  final gC = TextEditingController(); 
  final mC = TextEditingController();
  final rC = TextEditingController(); 
  final qC = TextEditingController(text: "1");
  final fC = TextEditingController(text: "0");
  String rT = "A";

  @override
  void initState() {
    super.initState();
    mC.text = widget.med.mrp.toString(); 
    gC.text = widget.med.gst.toString();
    rT = widget.priceLevel; // Party ka default rate (A, B, or C)
    
    _updateRateField(); // Rate set karein based on Price Level

    if (widget.existingItem != null) {
      bC.text = widget.existingItem!.batch; 
      eC.text = widget.existingItem!.exp;
      rC.text = widget.existingItem!.rate.toString();
      gC.text = widget.existingItem!.gstRate.toString();
      qC.text = widget.existingItem!.qty.toString();
      fC.text = widget.existingItem!.freeQty.toString();
    }
  }

  void _updateRateField() {
    if (rT == 'A') rC.text = widget.med.rateA.toString();
    else if (rT == 'B') rC.text = widget.med.rateB.toString();
    else rC.text = widget.med.rateC.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.blue.shade50,
      child: Column(
        children: [
          Row(children: [
            Expanded(child: Text("${widget.srNo}. ${widget.med.name}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue))),
            IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: widget.onCancel)
          ]),
          if (widget.batchHistory.isNotEmpty) 
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: widget.batchHistory.map((b) => ActionChip(
                  label: Text("${b.batch} (${b.exp})"),
                  onPressed: () => setState(() { bC.text = b.batch; eC.text = b.exp; mC.text = b.mrp.toString(); rC.text = b.rate.toString(); }),
                )).toList(),
              ),
            ),
          const SizedBox(height: 10),
          Row(children: [
            // --- FIXED BATCH FIELD: Alphanumeric Support ---
            Expanded(child: TextField(
              controller: bC,
              keyboardType: TextInputType.text, // Har tarah ke characters allow honge
              textCapitalization: TextCapitalization.none, // "hbvgf67i" ko capital nahi karega
              decoration: const InputDecoration(labelText: "Batch No", border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)),
            )),
            const SizedBox(width: 5),
            Expanded(child: _field(eC, "Exp (MM/YY)", fmt: [ExpiryDateFormatter()])), 
            const SizedBox(width: 5),
            Expanded(child: _field(gC, "GST%")),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field(mC, "MRP")), const SizedBox(width: 5),
            Expanded(child: _field(rC, "Rate")), const SizedBox(width: 5),
            Expanded(child: _field(qC, "Qty", isNum: true)), const SizedBox(width: 5),
            Expanded(child: _field(fC, "Free", isNum: true)),
          ]),
          const SizedBox(height: 15),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blue.shade700),
            onPressed: () {
              double r = double.tryParse(rC.text) ?? 0;
              double q = double.tryParse(qC.text) ?? 0;
              double g = double.tryParse(gC.text) ?? 0;
              double taxableVal = r * q;
              double gstAmt = taxableVal * (g / 100);
              double cgst = 0, sgst = 0, igst = 0; 
              if (widget.partyState == widget.shopState) { cgst = gstAmt/2; sgst = gstAmt/2; } else { igst = gstAmt; }
              
              widget.onAdd(BillItem(
                id: DateTime.now().toString(), srNo: widget.srNo, medicineID: widget.med.id, 
                name: widget.med.name, packing: widget.med.packing, batch: bC.text, // Bina capitalization ke
                exp: eC.text, hsn: widget.med.hsnCode, mrp: double.tryParse(mC.text) ?? 0, 
                qty: q, freeQty: double.tryParse(fC.text) ?? 0, rate: r, gstRate: g, 
                cgst: cgst, sgst: sgst, igst: igst, total: taxableVal + gstAmt
              ));
            },
            child: const Text("ADD TO BILL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String l, {List<TextInputFormatter>? fmt, bool en = true, bool isNum = false}) {
    return TextField(
      controller: c, 
      enabled: en, 
      inputFormatters: fmt, 
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: l, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.all(8)), 
    );
  }
}
