import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'sale_bill_number.dart';
import 'pdf/sale_invoice_pdf.dart'; 
import 'package:intl/intl.dart';

// --- BATCH & EXPIRY FORMATTERS ---
class ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (newValue.selection.baseOffset < oldValue.selection.baseOffset) return newValue;
    if (text.length == 2 && !text.contains('/')) {
      return TextEditingValue(text: '$text/', selection: TextSelection.collapsed(offset: 3));
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
            Text("${widget.billNo} | Rate Level: ${widget.party.priceLevel}", style: const TextStyle(fontSize: 10)),
          ],
        ),
        actions: [
          if (!widget.isReadOnly)
            TextButton(
              onPressed: items.isEmpty ? null : () => _saveAndClose(ph),
              child: const Text("SAVE BILL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: Column(
        children: [
          // 1. SEARCH MEDICINE
          if (selectedMed == null && !widget.isReadOnly)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Search Product for Billing...",
                  prefixIcon: const Icon(Icons.search, color: Colors.blue),
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                onChanged: (val) => setState(() => search = val),
              ),
            ),

          // 2. ITEM ENTRY FORM (Rate C Formula Integrated)
          if (selectedMed != null)
            ItemEntryForm(
              med: selectedMed!,
              party: widget.party,
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

          // 3. ADDED ITEMS LIST
          Expanded(
            child: items.isEmpty 
              ? const Center(child: Text("Cart is empty. Search products to add.", style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Qty: ${item.qty} + ${item.freeQty} | Batch: ${item.batch} | Rate: ₹${item.rate.toStringAsFixed(2)}"),
                      trailing: Text("₹${item.total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      onTap: widget.isReadOnly ? null : () => setState(() {
                        selectedMed = ph.medicines.firstWhere((m) => m.id == item.medicineID);
                        editingIndex = index;
                      }),
                      onLongPress: () => setState(() => items.removeAt(index)),
                    );
                  },
                ),
          ),

          // 4. SEARCH RESULTS OVERLAY (SIMULATED)
          if (search.isNotEmpty && selectedMed == null)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              color: Colors.white,
              child: ListView(
                children: ph.medicines
                  .where((m) => m.name.toLowerCase().contains(search.toLowerCase()))
                  .map((m) => ListTile(
                    leading: const Icon(Icons.medication, color: Colors.blue),
                    title: Text(m.name),
                    subtitle: Text("Stock: ${m.stock} | MRP: ₹${m.mrp}"),
                    onTap: () => setState(() { selectedMed = m; search = ""; }),
                  )).toList(),
              ),
            ),

          // 5. TOTAL BAR
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.blue.shade50, border: const Border(top: BorderSide(color: Colors.blue, width: 1))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("ITEMS: ${items.length}", style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("GRAND TOTAL: ₹${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.blue)),
              ],
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
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

// --- ITEM ENTRY FORM COMPONENT ---
class ItemEntryForm extends StatefulWidget {
  final Medicine med; final Party party; final int srNo;
  final BillItem? existingItem; final List<BatchInfo> batchHistory;
  final Function(BillItem) onAdd; final VoidCallback onCancel;

  const ItemEntryForm({super.key, required this.med, required this.party, required this.srNo, this.existingItem, required this.batchHistory, required this.onAdd, required this.onCancel});

  @override State<ItemEntryForm> createState() => _ItemEntryFormState();
}

class _ItemEntryFormState extends State<ItemEntryForm> {
  final bC = TextEditingController(); 
  final eC = TextEditingController();
  final gC = TextEditingController(); 
  final mC = TextEditingController();
  final rC = TextEditingController(); 
  final qC = TextEditingController(text: "1");
  final fC = TextEditingController(text: "0");
  final rCD = TextEditingController(text: "0"); // Rate C Discount %
  String rT = "A"; // Rate Type

  @override
  void initState() {
    super.initState();
    mC.text = widget.med.mrp.toString(); 
    gC.text = widget.med.gst.toString();
    rT = widget.party.priceLevel; // Party ki default pricing
    
    _initFields();
  }

  void _initFields() {
    if (widget.existingItem != null) {
      bC.text = widget.existingItem!.batch;
      eC.text = widget.existingItem!.exp;
      qC.text = widget.existingItem!.qty.toString();
      fC.text = widget.existingItem!.freeQty.toString();
      rC.text = widget.existingItem!.rate.toString();
    } else {
      _updateRateLogic();
    }
  }

  void _updateRateLogic() {
    if (rT == 'A') rC.text = widget.med.rateA.toString();
    else if (rT == 'B') rC.text = widget.med.rateB.toString();
    else _calculateRateC();
  }

  void _calculateRateC() {
    double mrp = double.tryParse(mC.text) ?? 0;
    double gst = double.tryParse(gC.text) ?? 0;
    double disc = double.tryParse(rCD.text) ?? 0;
    // FORMULA: [MRP / (1 + GST/100)] - Disc%
    double taxableValue = mrp / (1 + (gst / 100));
    double finalRate = taxableValue - (taxableValue * disc / 100);
    rC.text = finalRate.toStringAsFixed(2);
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
          
          // RATE TYPE SELECTOR
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'A', label: Text('Rate A')),
              ButtonSegment(value: 'B', label: Text('Rate B')),
              ButtonSegment(value: 'C', label: Text('Rate C')),
            ],
            selected: {rT},
            onSelectionChanged: (v) => setState(() { rT = v.first; _updateRateLogic(); }),
          ),
          
          const SizedBox(height: 15),
          Row(children: [
            // BATCH FIELD: Alphanumeric & Normal Keyboard
            Expanded(child: TextField(
              controller: bC,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(labelText: "Batch No", border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)),
            )),
            const SizedBox(width: 5),
            Expanded(child: _field(eC, "Exp (MM/YY)", fmt: [ExpiryDateFormatter()])), 
            const SizedBox(width: 5),
            Expanded(child: _field(gC, "GST%", onCh: (v) => rT == 'C' ? _calculateRateC() : null)),
          ]),
          
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field(mC, "MRP", onCh: (v) => rT == 'C' ? _calculateRateC() : null)),
            const SizedBox(width: 5),
            if (rT == 'C') ...[
              Expanded(child: _field(rCD, "RC Disc%", onCh: (v) => _calculateRateC())),
              const SizedBox(width: 5),
            ],
            Expanded(child: _field(rC, "Rate", en: rT != 'C')),
            const SizedBox(width: 5),
            Expanded(child: _field(qC, "Qty", isNum: true)),
            const SizedBox(width: 5),
            Expanded(child: _field(fC, "Free", isNum: true)),
          ]),
          
          const SizedBox(height: 15),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blue.shade700),
            onPressed: () {
              double rate = double.tryParse(rC.text) ?? 0;
              double qty = double.tryParse(qC.text) ?? 0;
              double gstP = double.tryParse(gC.text) ?? 0;
              // Professional Calculation: (Rate * Qty) + GST
              double total = (rate * qty) * (1 + (gstP / 100));

              widget.onAdd(BillItem(
                id: DateTime.now().toString(), 
                srNo: widget.srNo, 
                medicineID: widget.med.id, 
                name: widget.med.name, 
                packing: widget.med.packing, 
                batch: bC.text, 
                exp: eC.text, 
                hsn: widget.med.hsnCode, 
                mrp: double.tryParse(mC.text) ?? 0, 
                qty: qty, 
                freeQty: double.tryParse(fC.text) ?? 0,
                rate: rate, 
                gstRate: gstP, 
                total: total,
                discountRupees: rT == 'C' ? (double.tryParse(rCD.text) ?? 0) : 0
              ));
            },
            child: const Text("ADD TO LIST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String l, {List<TextInputFormatter>? fmt, bool en = true, Function(String)? onCh, bool isNum = false}) {
    return TextField(
      controller: c, 
      enabled: en, 
      inputFormatters: fmt, 
      onChanged: onCh,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      decoration: InputDecoration(labelText: l, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.all(8)), 
    );
  }
}
