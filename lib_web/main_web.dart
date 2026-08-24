// FILE: lib_web/main_web.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:pharoah_erp/models.dart';
import 'package:pharoah_erp/demo_data.dart';
import 'pharoah_web_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => PharoahWebManager(),
      child: const PharoahWebERPApp(),
    ),
  );
}

class PharoahWebERPApp extends StatelessWidget {
  const PharoahWebERPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pharoah ERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1),
          brightness: Brightness.dark,
        ),
      ),
      home: const WebControlShell(),
    );
  }
}

class WebControlShell extends StatefulWidget {
  const WebControlShell({super.key});
  @override
  State<WebControlShell> createState() => _WebControlShellState();
}

class _WebControlShellState extends State<WebControlShell> {
  Party? selectedSaleParty;
  String selectedSaleSeries = "INV-", selectedSaleMode = "CASH";
  DateTime selectedSaleDate = DateTime.now();
  List<BillItem> saleCart = [];
  double extraSaleDiscount = 0.0;

  Party? selectedPurDistributor;
  final purBillNoC = TextEditingController();
  DateTime purBillDate = DateTime.now(), purEntryDate = DateTime.now();
  String purMode = "CREDIT";
  List<PurchaseItem> purCart = [];

  String vouchType = "RECEIPT";
  Party? vouchParty;
  final vouchAmountC = TextEditingController();
  String vouchMode = "Cash", vouchLedger = "Cash in Hand";

  final mProdNameC = TextEditingController(), mProdPackC = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahWebManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ph.activeCompany?.name ?? "DWARIKA MEDICALS",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
            ),
            Row(
              children: [
                Text("ID: ${ph.activeCompany?.id ?? 'PH-C-101'}", style: const TextStyle(fontSize: 10, color: Colors.white70)),
                const SizedBox(width: 8),
                Text("FY: ${ph.currentFY}", style: const TextStyle(fontSize: 10, color: Colors.white70)),
                const SizedBox(width: 8),
                Text("MODE: ${ph.activeCompany?.businessType ?? 'WHOLESALE'}", style: const TextStyle(fontSize: 8, color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: [
          InkWell(
            onTap: () => _showDriveDialog(context, ph),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
              child: Text(ph.syncStatus, style: const TextStyle(fontSize: 11, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            ),
          ),
          IconButton(icon: const Icon(Icons.cloud_sync, color: Colors.cyanAccent), onPressed: () => ph.pullFromGoogleDrive()),
          if (ph.activeModule != "DASHBOARD")
            IconButton(icon: const Icon(Icons.dashboard, color: Colors.white), onPressed: () => ph.updateModule("DASHBOARD")),
        ],
      ),
      body: _buildView(ph),
    );
  }

  Widget _buildView(PharoahWebManager ph) {
    switch (ph.activeModule) {
      case "SALE_STEP1": return _buildSaleStep1(ph);
      case "SALE_STEP2": return _buildSaleStep2(ph);
      case "PURCHASES": return _buildPurchasesView(ph);
      case "SALE_REG": return _buildSaleRegister(ph);
      case "PUR_REG": return _buildPurchaseRegister(ph);
      case "STOCK": return _buildStockView(ph);
      case "ACCOUNTS": return _buildVouchersView(ph);
      case "DAYBOOK": return _buildDaybookView(ph);
      case "LEDGERS": return _buildLedgersView(ph);
      case "MASTERS": return _buildMastersView(ph);
      default: return _buildDashboard(ph);
    }
  }

  Widget _buildDashboard(PharoahWebManager ph) {
    final now = DateTime.now();
    double sTotal = ph.sales.where((s)=>s.status=="Active" && s.date.day==now.day).fold(0.0, (sum, s)=>sum+s.totalAmount);
    double pTotal = ph.purchases.where((p)=>p.date.day==now.day).fold(0.0, (sum, p)=>sum+p.totalAmount);
    double stockVal = ph.medicines.fold(0.0, (sum, m)=>sum+(m.stock>0 ? m.stock*m.purRate : 0.0));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _kpiCard("TODAY SALE", "₹${sTotal.toStringAsFixed(0)}", Colors.greenAccent, Icons.trending_up)),
              const SizedBox(width: 12),
              Expanded(child: _kpiCard("TODAY PURCHASE", "₹${pTotal.toStringAsFixed(0)}", Colors.orangeAccent, Icons.shopping_cart)),
            ],
          ),
          const SizedBox(height: 12),
          _kpiCard("ESTIMATED STOCK VALUE", "₹${stockVal.toStringAsFixed(0)}", Colors.indigoAccent, Icons.inventory_2),
          const SizedBox(height: 25),
          const Text("QUICK TRANSACTIONS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _btn("NEW SALE", Icons.add_shopping_cart, const Color(0xFF1D4ED8), () { selectedSaleParty = null; saleCart.clear(); ph.updateModule("SALE_STEP1"); })),
              const SizedBox(width: 12),
              Expanded(child: _btn("PURCHASE", Icons.downloading, const Color(0xFFC2410C), () { selectedPurDistributor = null; purCart.clear(); ph.updateModule("PURCHASES"); })),
            ],
          ),
          const SizedBox(height: 25),
          const Text("ALL BUSINESS MODULES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.95,
            children: [
              _modTile("Billing", Icons.receipt_long, Colors.blue, () => ph.updateModule("SALE_STEP1")),
              _modTile("Purchases", Icons.shopping_bag, Colors.orange, () => ph.updateModule("PURCHASES")),
              _modTile("Sale Reg", Icons.description, Colors.blueAccent, () => ph.updateModule("SALE_REG")),
              _modTile("Pur Reg", Icons.history, Colors.brown, () => ph.updateModule("PUR_REG")),
              _modTile("Live Stock", Icons.inventory, Colors.purple, () => ph.updateModule("STOCK")),
              _modTile("Vouchers", Icons.account_balance_wallet, Colors.indigo, () => ph.updateModule("ACCOUNTS")),
              _modTile("Daybook", Icons.event_note, Colors.blueGrey, () => ph.updateModule("DAYBOOK")),
              _modTile("Ledgers", Icons.people, Colors.green, () => ph.updateModule("LEDGERS")),
              _modTile("Masters", Icons.stars, Colors.deepOrange, () => ph.updateModule("MASTERS")),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String t, String v, Color c, IconData i) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: c.withOpacity(0.3))),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(i, color: c, size: 20), Text(t, style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 8),
        Text(v, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c)),
      ],
    ),
  );

  Widget _btn(String t, IconData i, Color c, VoidCallback tap) => InkWell(
    onTap: tap,
    child: Container(
      height: 75,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, color: Colors.white), const SizedBox(width: 8), Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))]),
    ),
  );

  Widget _modTile(String t, IconData i, Color c, VoidCallback tap) => InkWell(
    onTap: tap,
    child: Container(
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: c.withOpacity(0.15), shape: BoxShape.circle), child: Icon(i, color: c, size: 22)),
          const SizedBox(height: 6),
          Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    ),
  );

  Widget _buildSaleStep1(PharoahWebManager ph) {
    String billNo = ph.getNextNumber('SALE'), q = "";
    return StatefulBuilder(builder: (context, setS) {
      final list = ph.parties.where((p)=>p.name.toLowerCase().contains(q.toLowerCase())).toList();
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("TAX INVOICE (STEP 1)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.cyanAccent)), OutlinedButton(onPressed: ()=>ph.updateModule("DASHBOARD"), child: const Text("CANCEL"))]),
            const Divider(height: 25),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(value: selectedSaleSeries, decoration: const InputDecoration(labelText: "Series"), items: ["INV-", "RET-", "WHOLE-"].map((s)=>DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v)=>setS(()=>selectedSaleSeries=v!))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: TextEditingController(text: billNo), readOnly: true, decoration: const InputDecoration(labelText: "Bill No"))),
              const SizedBox(width: 10),
              Expanded(child: DropdownButtonFormField<String>(value: selectedSaleMode, decoration: const InputDecoration(labelText: "Mode"), items: ["CASH", "CREDIT"].map((m)=>DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v)=>setS(()=>selectedSaleMode=v!))),
            ]),
            const SizedBox(height: 15),
            TextField(decoration: const InputDecoration(hintText: "Search Party Name...", prefixIcon: Icon(Icons.search)), onChanged: (v)=>setS(()=>q=v)),
            const SizedBox(height: 10),
            if (selectedSaleParty != null) Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Selected: ${selectedSaleParty!.name}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), TextButton(onPressed: ()=>setS(()=>selectedSaleParty=null), child: const Text("CHANGE", style: TextStyle(color: Colors.redAccent)))])),
            SizedBox(height: 200, child: ListView.builder(itemCount: list.length, itemBuilder: (c, i)=>ListTile(title: Text(list[i].name), subtitle: Text("City: ${list[i].city}"), onTap: ()=>setS(()=>selectedSaleParty=list[i])))),
            const SizedBox(height: 15),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, padding: const EdgeInsets.all(14)), onPressed: (){ selectedSaleParty ??= (ph.parties.isNotEmpty ? ph.parties.first : DemoData.getDemoParty()); ph.updateModule("SALE_STEP2"); }, child: const Text("PROCEED TO BILLING (STEP 2)")),
          ]),
        ),
      );
    });
  }

  Widget _buildSaleStep2(PharoahWebManager ph) {
    double itemTotal = saleCart.fold(0.0, (s, i)=>s+i.total);
    double grandTotal = (itemTotal - extraSaleDiscount).roundToDouble();
    double roundOff = grandTotal - (itemTotal - extraSaleDiscount);

    return StatefulBuilder(builder: (context, setS) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("INVOICE: ${ph.getNextNumber('SALE')} | Party: ${selectedSaleParty?.name ?? 'CASH'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.cyanAccent)),
              Row(children: [OutlinedButton(onPressed: ()=>ph.updateModule("SALE_STEP1"), child: const Text("← STEP 1")), const SizedBox(width: 8), ElevatedButton(onPressed: ()=>_openItemModal(context, ph, (it)=>setS(()=>saleCart.add(it))), child: const Text("+ ADD ITEM"))]),
            ]),
            const Divider(height: 25),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('S.N')), DataColumn(label: Text('NAME')), DataColumn(label: Text('QTY')), DataColumn(label: Text('RATE')), DataColumn(label: Text('TOTAL')), DataColumn(label: Text('DEL'))], rows: saleCart.asMap().entries.map((e)=>DataRow(cells: [DataCell(Text("${e.key+1}")), DataCell(Text(e.value.name)), DataCell(Text("${e.value.qty.toInt()}")), DataCell(Text("₹${e.value.rate.toStringAsFixed(2)}")), DataCell(Text("₹${e.value.total.toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent))), DataCell(IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16), onPressed: ()=>setS(()=>saleCart.removeAt(e.key))))])).toList())),
            const Divider(height: 30),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              SizedBox(width: 180, child: TextField(decoration: const InputDecoration(labelText: "Extra Discount (-)"), keyboardType: TextInputType.number, onChanged: (v)=>setS(()=>extraSaleDiscount=double.tryParse(v)??0.0))),
              Text("NET TOTAL: ₹${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.greenAccent)),
            ]),
            const SizedBox(height: 20),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, padding: const EdgeInsets.all(14)), onPressed: saleCart.isEmpty ? null : () async { await ph.finalizeSale(billNo: ph.getNextNumber('SALE'), date: selectedSaleDate, party: selectedSaleParty ?? (ph.parties.isNotEmpty ? ph.parties.first : DemoData.getDemoParty()), items: saleCart, total: grandTotal, mode: selectedSaleMode, extraDiscount: extraSaleDiscount, roundOff: roundOff); ph.updateModule("DASHBOARD"); }, child: const Text("SAVE INVOICE")),
          ]),
        ),
      );
    });
  }

  void _openItemModal(BuildContext context, PharoahWebManager ph, Function(BillItem) onAdd) {
    if (ph.medicines.isEmpty) return;
    Medicine med = ph.medicines.first;
    double rate = med.rateA;
    final qtyC = TextEditingController(text: "1");

    showDialog(context: context, builder: (c)=>StatefulBuilder(builder: (context, setM) {
      double q = double.tryParse(qtyC.text) ?? 1;
      double tot = q * rate * (1 + med.gst / 100);
      return AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text("Add ${med.name}", style: const TextStyle(color: Colors.white, fontSize: 14)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<Medicine>(value: med, decoration: const InputDecoration(labelText: "Product"), items: ph.medicines.map((m)=>DropdownMenuItem(value: m, child: Text(m.name))).toList(), onChanged: (m){ if(m!=null) setM((){ med = m; rate = m.rateA; }); }),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: TextField(decoration: const InputDecoration(labelText: "Rate ₹"), controller: TextEditingController(text: rate.toStringAsFixed(2)), onChanged: (v)=>setM(()=>rate=double.tryParse(v)??rate))), const SizedBox(width: 8), Expanded(child: TextField(decoration: const InputDecoration(labelText: "Qty"), controller: qtyC, onChanged: (_)=>setM(() {})))]),
          const SizedBox(height: 10),
          Text("Total: ₹${tot.toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("CANCEL")), ElevatedButton(onPressed: (){ onAdd(BillItem(id: "ITEM_${DateTime.now().millisecondsSinceEpoch}", srNo: 1, medicineID: med.id, name: med.name, packing: med.packing, batch: "DL-101", exp: "12/28", hsn: med.hsnCode, mrp: med.mrp, qty: q, rate: rate, gstRate: med.gst, total: tot)); Navigator.pop(c); }, child: const Text("ADD"))],
      );
    }));
  }

  Widget _buildPurchasesView(PharoahWebManager ph) {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("PURCHASE INWARD", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orangeAccent)), OutlinedButton(onPressed: ()=>ph.updateModule("DASHBOARD"), child: const Text("← DASHBOARD"))]),
      const Divider(height: 25),
      TextField(controller: purBillNoC, decoration: const InputDecoration(labelText: "Supplier Bill No *")),
      const SizedBox(height: 15),
      ElevatedButton(onPressed: () async {
        if (purBillNoC.text.isEmpty) return;
        final m = ph.medicines.isNotEmpty ? ph.medicines.first : DemoData.getMedicines().first;
        await ph.finalizePurchase(internalNo: ph.getNextNumber('PURCHASE'), billNo: purBillNoC.text, date: purBillDate, entryDate: purEntryDate, party: selectedPurDistributor ?? (ph.parties.isNotEmpty ? ph.parties.first : DemoData.getDemoParty()), items: [PurchaseItem(id: "P_${DateTime.now().millisecondsSinceEpoch}", srNo: 1, medicineID: m.id, name: m.name, packing: m.packing, batch: "B-101", exp: "12/28", hsn: "3004", mrp: m.mrp, qty: 10, purchaseRate: m.purRate, gstRate: 12, total: 10 * m.purRate * 1.12)], total: 10 * m.purRate * 1.12, mode: purMode);
        ph.updateModule("DASHBOARD");
      }, child: const Text("RECORD PURCHASE")),
    ])));
  }

  Widget _buildSaleRegister(PharoahWebManager ph) {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("SALES REGISTER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), OutlinedButton(onPressed: ()=>ph.updateModule("DASHBOARD"), child: const Text("← DASHBOARD"))]),
      const Divider(height: 25),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('DATE')), DataColumn(label: Text('BILL NO')), DataColumn(label: Text('PARTY')), DataColumn(label: Text('TOTAL (₹)'))], rows: ph.sales.map((s)=>DataRow(cells: [DataCell(Text(DateFormat('dd/MM/yy').format(s.date))), DataCell(Text(s.billNo)), DataCell(Text(s.partyName)), DataCell(Text("₹${s.totalAmount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent)))])).toList())),
    ])));
  }

  Widget _buildPurchaseRegister(PharoahWebManager ph) {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("PURCHASE REGISTER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), OutlinedButton(onPressed: ()=>ph.updateModule("DASHBOARD"), child: const Text("← DASHBOARD"))]),
      const Divider(height: 25),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('DATE')), DataColumn(label: Text('PUR NO')), DataColumn(label: Text('SUPPLIER')), DataColumn(label: Text('TOTAL (₹)'))], rows: ph.purchases.map((p)=>DataRow(cells: [DataCell(Text(DateFormat('dd/MM/yy').format(p.date))), DataCell(Text(p.internalNo)), DataCell(Text(p.distributorName)), DataCell(Text("₹${p.totalAmount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.orangeAccent)))])).toList())),
    ])));
  }

  Widget _buildStockView(PharoahWebManager ph) {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("LIVE STOCK MASTER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), OutlinedButton(onPressed: ()=>ph.updateModule("DASHBOARD"), child: const Text("← DASHBOARD"))]),
      const Divider(height: 25),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('CODE')), DataColumn(label: Text('NAME')), DataColumn(label: Text('PUR. RATE')), DataColumn(label: Text('STOCK'))], rows: ph.medicines.map((m)=>DataRow(cells: [DataCell(Text(m.systemId)), DataCell(Text(m.name)), DataCell(Text("₹${m.purRate.toStringAsFixed(2)}")), DataCell(Text("${m.stock.toInt()}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)))])).toList())),
    ])));
  }

  Widget _buildVouchersView(PharoahWebManager ph) {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("ACCOUNTS & VOUCHER ENTRY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), OutlinedButton(onPressed: ()=>ph.updateModule("DASHBOARD"), child: const Text("← DASHBOARD"))]),
      const Divider(height: 25),
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(value: vouchType, decoration: const InputDecoration(labelText: "Type"), items: ["RECEIPT", "PAYMENT"].map((t)=>DropdownMenuItem(value: t, child: Text(t))).toList(), onChanged: (v)=>setState(()=>vouchType=v!))),
        const SizedBox(width: 10),
        Expanded(child: TextField(controller: vouchAmountC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Amount ₹"))),
      ]),
      const SizedBox(height: 15),
      ElevatedButton(onPressed: () async {
        double a = double.tryParse(vouchAmountC.text) ?? 0; if (a<=0) return;
        await ph.finalizeVoucher(type: vouchType, voucherNo: ph.getNextNumber(vouchType), date: DateTime.now(), party: vouchParty ?? (ph.parties.isNotEmpty ? ph.parties.first : DemoData.getDemoParty()), amount: a, mode: vouchMode, internalLedger: vouchLedger);
        vouchAmountC.text = ""; ph.updateModule("DASHBOARD");
      }, child: const Text("RECORD VOUCHER")),
    ])));
  }

  Widget _buildDaybookView(PharoahWebManager ph) {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("DAILY DAYBOOK REGISTER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), OutlinedButton(onPressed: ()=>ph.updateModule("DASHBOARD"), child: const Text("← DASHBOARD"))]),
      const Divider(height: 25),
      Text("Total Sales: ${ph.sales.length} | Total Purchases: ${ph.purchases.length}"),
    ])));
  }

  Widget _buildLedgersView(PharoahWebManager ph) {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("PARTY LEDGERS & BALANCES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), OutlinedButton(onPressed: ()=>ph.updateModule("DASHBOARD"), child: const Text("← DASHBOARD"))]),
      const Divider(height: 25),
      ...ph.parties.map((p)=>ListTile(title: Text(p.name), subtitle: Text("City: ${p.city}"), trailing: Text("₹${p.opBal.toStringAsFixed(2)}", style: const TextStyle(color: Colors.cyanAccent)))),
    ])));
  }

  Widget _buildMastersView(PharoahWebManager ph) {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("REGISTER NEW PRODUCT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), OutlinedButton(onPressed: ()=>ph.updateModule("DASHBOARD"), child: const Text("← DASHBOARD"))]),
      const Divider(height: 25),
      TextField(controller: mProdNameC, decoration: const InputDecoration(labelText: "Product Name")),
      const SizedBox(height: 15),
      ElevatedButton(onPressed: () async {
        if (mProdNameC.text.isEmpty) return;
        final sysId = "PH-${10001 + ph.medicines.length}";
        ph.medicines.add(Medicine(id: sysId, systemId: sysId, name: mProdNameC.text.toUpperCase(), packing: "15 TAB", mrp: 50.0, purRate: 38.0, rateA: 45.0, stock: 100));
        await ph.save(); mProdNameC.text = ""; ph.updateModule("DASHBOARD");
      }, child: const Text("SAVE PRODUCT")),
    ])));
  }

  void _showDriveDialog(BuildContext context, PharoahWebManager ph) {
    final urlC = TextEditingController(text: ph.driveWebhookUrl);
    final emailC = TextEditingController(text: ph.driveUserEmail);
    showDialog(context: context, builder: (c)=>AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text("Google Drive 2-Way Sync", style: TextStyle(color: Colors.white, fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: emailC, decoration: const InputDecoration(labelText: "Gmail ID")), const SizedBox(height: 10), TextField(controller: urlC, decoration: const InputDecoration(labelText: "Webhook URL"))]),
      actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("CANCEL")), ElevatedButton(onPressed: () async { await ph.saveDriveSettings(urlC.text, emailC.text); Navigator.pop(c); }, child: const Text("SAVE & SYNC"))],
    ));
  }
}
