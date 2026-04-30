// FILE: lib/purchase/purchase_billing_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../product_master.dart'; 
import '../batch_sync_engine.dart'; // NAYA IMPORT
import '../expiry_master.dart';    // NAYA IMPORT
import 'package:intl/intl.dart';

class PurchaseBillingView extends StatefulWidget {
  final Party distributor;
  final String internalNo, distBillNo, mode;
  final DateTime billDate, entryDate;
  final List<PurchaseItem>? existingItems;
  final String? modifyPurchaseId;
  final bool isReadOnly; 

  const PurchaseBillingView({
    super.key,
    required this.distributor,
    required this.internalNo,
    required this.distBillNo,
    required this.billDate,
    required this.entryDate,
    required this.mode,
    this.existingItems,
    this.modifyPurchaseId,
    this.isReadOnly = false,
  });

  @override
  State<PurchaseBillingView> createState() => _PurchaseBillingViewState();
}

class _PurchaseBillingViewState extends State<PurchaseBillingView> {
  List<PurchaseItem> items = [];
  double get totalAmt => items.fold(0, (sum, it) => sum + it.total);

  @override
  void initState() {
    super.initState();
    if (widget.existingItems != null) items = List.from(widget.existingItems!);
  }

  void _recalculateSR() {
    setState(() {
      for (int i = 0; i < items.length; i++) {
        items[i] = items[i].copyWith(srNo: i + 1);
      }
    });
  }

  void _showItemSearchSheet(PharoahManager ph, {PurchaseItem? itemToEdit}) {
    if (widget.isReadOnly) return; 

    String localSearch = "";
    Medicine? selectedMed;
    if (itemToEdit != null) {
      selectedMed = ph.medicines.firstWhere((m) => m.id == itemToEdit.medicineID);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final filteredMeds = ph.medicines
              .where((m) => m.name.toLowerCase().contains(localSearch.toLowerCase()))
              .toList();

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 10),
                    height: 5, width: 50,
                    decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
                  ),
                  if (selectedMed == null) ...[
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: "Search Product for Inward...",
                                prefixIcon: const Icon(Icons.search, color: Colors.orange),
                                filled: true, fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onChanged: (v) => setSheetState(() => localSearch = v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filled(
                            onPressed: () async {
                              final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => const ProductMasterView(isSelectionMode: true)));
                              if (result != null && result is Medicine) { setSheetState(() => selectedMed = result); }
                            },
                            icon: const Icon(Icons.library_add_rounded),
                            style: IconButton.styleFrom(backgroundColor: Colors.orange.shade900),
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredMeds.length,
                        itemBuilder: (c, i) => ListTile(
                          leading: const Icon(Icons.inventory_2, color: Colors.orange),
                          title: Text(filteredMeds[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Pack: ${filteredMeds[i].packing} | Stock: ${filteredMeds[i].stock}"),
                          onTap: () => setSheetState(() => selectedMed = filteredMeds[i]),
                        ),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: SingleChildScrollView(
                        child: PurchaseItemEntryCard(
                          med: selectedMed!,
                          srNo: itemToEdit != null ? itemToEdit.srNo : items.length + 1,
                          existingItem: itemToEdit,
                          onAdd: (newItem) {
                            setState(() {
                              if (itemToEdit != null) {
                                int idx = items.indexWhere((it) => it.id == itemToEdit.id);
                                items[idx] = newItem; 
                              } else {
                                items.add(newItem); 
                              }
                            });
                            Navigator.pop(context);
                          },
                          onCancel: () => itemToEdit != null ? Navigator.pop(context) : setSheetState(() => selectedMed = null),
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        backgroundColor: widget.isReadOnly ? Colors.purple.shade700 : Colors.orange.shade800,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.distributor.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Text(widget.isReadOnly ? "PURCHASE VIEW" : "Bill: ${widget.distBillNo} | ID: ${widget.internalNo}", style: const TextStyle(fontSize: 10))
        ]),
        actions: [
          if (!widget.isReadOnly) 
            TextButton(
              onPressed: items.isEmpty ? null : () => _handleSave(ph),
              child: const Text("FINISH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
        ],
      ),
      body: Column(children: [
        _buildHeader(),
        _buildSearchBarTrigger(ph),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text("No items added yet"))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  itemCount: items.length,
                  itemBuilder: (c, i) => _buildItemCard(items[i], i, ph),
                ),
        ),
        _buildFooter(),
      ]),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.all(15), margin: const EdgeInsets.fromLTRB(10, 10, 10, 5),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(widget.distributor.name, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
      Text(DateFormat('dd/MM/yyyy').format(widget.billDate), style: const TextStyle(fontWeight: FontWeight.bold)),
    ]),
  );

  Widget _buildSearchBarTrigger(PharoahManager ph) {
    if (widget.isReadOnly) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: InkWell(
        onTap: () => _showItemSearchSheet(ph),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade300, width: 1.5)),
          child: Row(children: [
              Icon(Icons.search, color: Colors.orange.shade700),
              const SizedBox(width: 10),
              Text("Tap here to search inward stock...", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              const Spacer(),
              Icon(Icons.add_circle, color: Colors.orange.shade700),
          ]),
        ),
      ),
    );
  }

  Widget _buildItemCard(PurchaseItem it, int index, PharoahManager ph) {
    final card = Card(
      elevation: 2, margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
            // NAYA: Purchase mein bhi source dikhana hai
            if (it.hsn.contains('PCH-')) // Purchase mein hum HSN ya kisi field mein temporary ref rakhte hain
               Text("Ref: ${it.hsn}", style: const TextStyle(fontSize: 9, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
          ],
        ),
        subtitle: Text("Batch: ${it.batch} | Qty: ${it.qty.toInt()} | Pur.Rate: ₹${it.purchaseRate.toStringAsFixed(2)}"),
        trailing: Text("₹${it.total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
        onTap: widget.isReadOnly ? null : () => _showItemSearchSheet(ph, itemToEdit: it),
      ),
    );
    if (widget.isReadOnly) return card;
    return Dismissible(
      key: Key(it.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      onDismissed: (direction) { setState(() { items.removeAt(index); }); _recalculateSR(); },
      child: card,
    );
  }

  Widget _buildFooter() => Container(
    padding: const EdgeInsets.all(15),
    color: widget.isReadOnly ? Colors.purple.shade50 : Colors.orange.shade100,
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text("TOTAL ITEMS: ${items.length}", style: const TextStyle(fontWeight: FontWeight.bold)),
      Text("NET TOTAL: ₹${totalAmt.toStringAsFixed(2)}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.isReadOnly ? Colors.purple.shade900 : Colors.deepOrange.shade900))
    ]),
  );

  void _handleSave(PharoahManager ph) {
    if (widget.modifyPurchaseId != null) ph.deletePurchase(widget.modifyPurchaseId!);
    ph.finalizePurchase(internalNo: widget.internalNo, billNo: widget.distBillNo, date: widget.billDate, entryDate: widget.entryDate, party: widget.distributor, items: items, total: totalAmt, mode: widget.mode);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

// =============================================================================
// PURCHASE ITEM ENTRY CARD (SYNC INTEGRATED)
// =============================================================================
class PurchaseItemEntryCard extends StatefulWidget {
  final Medicine med;
  final int srNo;
  final PurchaseItem? existingItem;
  final Function(PurchaseItem) onAdd;
  final VoidCallback onCancel;

  const PurchaseItemEntryCard({
    super.key,
    required this.med,
    required this.srNo,
    this.existingItem,
    required this.onAdd,
    required this.onCancel,
  });

  @override
  State<PurchaseItemEntryCard> createState() => _PurchaseItemEntryCardState();
}

class _PurchaseItemEntryCardState extends State<PurchaseItemEntryCard> {
  final batchC = TextEditingController();
  final expC = TextEditingController();
  final gstC = TextEditingController();
  final mrpC = TextEditingController();
  final purRateC = TextEditingController();
  final qtyC = TextEditingController(text: "1");
  final freeC = TextEditingController(text: "0");
  final rateAC = TextEditingController();
  final rateBC = TextEditingController();
  final rateCC = TextEditingController();
  final discC = TextEditingController(text: "0");
  bool showDisc = false;

  @override
  void initState() {
    super.initState();
    _setupInitialData();
  }

  void _setupInitialData() {
    if (widget.existingItem != null) {
      final i = widget.existingItem!;
      batchC.text = i.batch;
      expC.text = i.exp;
      gstC.text = i.gstRate.toString();
      mrpC.text = i.mrp.toString();
      purRateC.text = i.purchaseRate.toString();
      qtyC.text = i.qty.toString();
      freeC.text = i.freeQty.toString();
      rateAC.text = i.rateA.toString();
      rateBC.text = i.rateB.toString();
      rateCC.text = i.rateC.toString();
    } else {
      gstC.text = widget.med.gst.toString();
      mrpC.text = widget.med.mrp.toString();
      purRateC.text = widget.med.purRate.toString();
      rateAC.text = widget.med.rateA.toString();
      rateBC.text = widget.med.rateB.toString();
      _calcRateC();
    }
  }

  void _formatExpiry(String val) {
    String text = val.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length >= 2 && !val.contains('/')) { text = '${text.substring(0, 2)}/${text.substring(2)}'; }
    if (text.length > 5) text = text.substring(0, 5);
    if (expC.text != text) { expC.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)); }
    setState(() {});
  }

  void _calcRateC() {
    double mrp = double.tryParse(mrpC.text) ?? 0.0;
    double gst = double.tryParse(gstC.text) ?? 0.0;
    double disc = double.tryParse(discC.text) ?? 0.0;
    double baseTaxable = (mrp / (1 + (gst / 100)));
    double finalRate = baseTaxable - (baseTaxable * (disc / 100));
    rateCC.text = finalRate.toStringAsFixed(2);
    setState(() {});
  }

  double _calcTotal() {
    double pr = double.tryParse(purRateC.text) ?? 0;
    double qt = double.tryParse(qtyC.text) ?? 0;
    double gst = double.tryParse(gstC.text) ?? 0;
    return (pr * qt) * (1 + gst / 100);
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // NAYA: Suggesions from Master Registry
    final matchingBatches = BatchSyncEngine.getFilteredBatches(
      ph: ph, 
      productKey: widget.med.identityKey,
      hideExpired: false // Purchase mein expired bhi dikhao
    ).where((b) => b.batch.toLowerCase().contains(batchC.text.toLowerCase())).toList();

    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("${widget.srNo}. ${widget.med.name}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), IconButton(icon: const Icon(Icons.cancel, color: Colors.grey), onPressed: widget.onCancel)]),
          Row(children: [Expanded(child: _buildInput("BATCH", batchC, onChanged: (v) => setState(() {}))), const SizedBox(width: 8), Expanded(child: _buildInput("EXP (MM/YY)", expC, onChanged: _formatExpiry, isNum: true)), const SizedBox(width: 8), Expanded(child: _buildInput("GST %", gstC, isNum: true, onChanged: (v) { _calcRateC(); setState((){}); }))]),
          
          if (matchingBatches.isNotEmpty && widget.existingItem == null)
            Container(height: 45, margin: const EdgeInsets.symmetric(vertical: 5), child: ListView(scrollDirection: Axis.horizontal, children: matchingBatches.map((b) => Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(backgroundColor: Colors.orange.withOpacity(0.1), label: Text("${b.batch} (Exp: ${b.exp})", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepOrange)), onPressed: () { setState(() { batchC.text = b.batch; expC.text = b.exp; mrpC.text = b.mrp.toString(); purRateC.text = b.rate.toString(); _calcRateC(); }); }))).toList())),
          
          const Divider(),
          Row(children: [Expanded(child: _buildInput("MRP", mrpC, isNum: true, onChanged: (v) { _calcRateC(); setState((){}); })), const SizedBox(width: 8), Expanded(child: _buildInput("PUR. RATE", purRateC, isNum: true, onChanged: (v) => setState((){}))), const SizedBox(width: 8), Expanded(child: _buildInput("QTY", qtyC, isNum: true, onChanged: (v) => setState((){}))), const SizedBox(width: 8), Expanded(child: _buildInput("FREE", freeC, isNum: true))]),
          const SizedBox(height: 15),
          const Text("FUTURE SALE RATES", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
          Row(children: [Expanded(child: _buildInput("RATE A", rateAC, isNum: true)), const SizedBox(width: 8), Expanded(child: _buildInput("RATE B", rateBC, isNum: true)), const SizedBox(width: 8), Expanded(child: GestureDetector(onTap: () => setState(() => showDisc = !showDisc), child: _buildInput("RATE C", rateCC, isReadOnly: true, color: Colors.purple)))]),
          if (showDisc) Padding(padding: const EdgeInsets.only(top: 10), child: _buildInput("DISC % FOR RATE C", discC, isNum: true, color: Colors.purple, onChanged: (v) => _calcRateC())),
          const SizedBox(height: 15),
          SizedBox(width: double.infinity, height: 45, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white), onPressed: qtyC.text.isEmpty || qtyC.text == "0" ? null : () {
            // NAYA: Sync to Registry
            BatchSyncEngine.registerBatchActivity(ph: ph, productKey: widget.med.identityKey, batchNo: batchC.text, exp: expC.text, packing: widget.med.packing, mrp: double.tryParse(mrpC.text) ?? 0, rate: double.tryParse(purRateC.text) ?? 0);
            
            double pr = double.tryParse(purRateC.text) ?? 0; double qt = double.tryParse(qtyC.text) ?? 0; double gst = double.tryParse(gstC.text) ?? 0;
            widget.onAdd(PurchaseItem(id: widget.existingItem?.id ?? DateTime.now().toString(), srNo: widget.srNo, medicineID: widget.med.id, name: widget.med.name, packing: widget.med.packing, batch: batchC.text.toUpperCase(), exp: expC.text, hsn: widget.med.hsnCode, mrp: double.tryParse(mrpC.text) ?? 0, qty: qt, freeQty: double.tryParse(freeC.text) ?? 0, purchaseRate: pr, gstRate: gst, total: (pr * qt) * (1 + gst / 100), rateA: double.tryParse(rateAC.text) ?? 0, rateB: double.tryParse(rateBC.text) ?? 0, rateC: double.tryParse(rateCC.text) ?? 0));
          }, child: Text(widget.existingItem != null ? "UPDATE ITEM" : "ADD TO STOCK", style: const TextStyle(fontWeight: FontWeight.bold))))
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, {bool isNum = false, Function(String)? onChanged, bool isReadOnly = false, Color? color}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color ?? Colors.black54)), const SizedBox(height: 2), TextField(controller: ctrl, readOnly: isReadOnly, keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, onChanged: onChanged, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color), decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)), filled: isReadOnly, fillColor: isReadOnly ? Colors.grey.shade200 : Colors.white))]);
  }
}
