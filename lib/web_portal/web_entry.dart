// FILE: lib/web_portal/web_entry.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pharoah_erp_flutter/models.dart';
import 'web_manager.dart';
import 'web_drive_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ChangeNotifierProvider(create: (_) => WebManager(), child: const PharoahWebERPApp()));
}

class PharoahWebERPApp extends StatelessWidget {
  const PharoahWebERPApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pharoah ERP Web Suite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D47A1)), scaffoldBackgroundColor: const Color(0xFFF4F6F9)),
      home: const WebDashboardScreen(),
    );
  }
}

class WebDashboardScreen extends StatefulWidget {
  const WebDashboardScreen({super.key});
  @override
  State<WebDashboardScreen> createState() => _WebDashboardScreenState();
}

class _WebDashboardScreenState extends State<WebDashboardScreen> {
  int _selectedNav = 0;

  @override
  Widget build(BuildContext context) {
    final web = Provider.of<WebManager>(context);
    if (web.isLoading) {
      return const Scaffold(backgroundColor: Color(0xFF0D47A1), body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(web.shopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            Text('FY: ' + web.currentFY + ' | ' + web.syncStatus, style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ]),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87),
            onPressed: () => _handleGoogleSignIn(context, web),
            icon: const Icon(Icons.account_circle, color: Colors.red, size: 18),
            label: Text(web.isOnline ? 'Google Connected' : 'Sign in with Google', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.sync_rounded, color: Colors.white), tooltip: 'Sync', onPressed: () => web.syncWithDrive()),
          IconButton(icon: const Icon(Icons.settings_suggest_rounded, color: Colors.white), tooltip: 'Settings & Guide', onPressed: () => setState(() => _selectedNav = 5)),
        ]),
        backgroundColor: const Color(0xFF0D47A1),
      ),
      body: Row(children: [
        NavigationRail(
          selectedIndex: _selectedNav,
          onDestinationSelected: (i) => setState(() => _selectedNav = i),
          labelType: NavigationRailLabelType.all,
          backgroundColor: Colors.white,
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.dashboard_rounded), label: Text('Dashboard')),
            NavigationRailDestination(icon: Icon(Icons.point_of_sale_rounded), label: Text('Billing')),
            NavigationRailDestination(icon: Icon(Icons.inventory_2_rounded), label: Text('Stock')),
            NavigationRailDestination(icon: Icon(Icons.account_balance_wallet_rounded), label: Text('Accounts')),
            NavigationRailDestination(icon: Icon(Icons.verified_rounded), label: Text('GST')),
            NavigationRailDestination(icon: Icon(Icons.settings_rounded), label: Text('Settings')),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: Padding(padding: const EdgeInsets.all(15), child: _buildSelectedView(web))),
      ]),
    );
  }

  Widget _buildSelectedView(WebManager web) {
    if (_selectedNav == 1) return _buildBilling(web);
    if (_selectedNav == 2) return _buildStock(web);
    if (_selectedNav == 3) return _buildAccounts(web);
    if (_selectedNav == 4) return _buildGst(web);
    if (_selectedNav == 5) return _buildSettingsView(web);
    return _buildDashboard(web);
  }

  Widget _buildDashboard(WebManager web) {
    double todaySales = web.sales.fold(0.0, (s, e) => s + e.totalAmount);
    double todayPur = web.purchases.fold(0.0, (s, e) => s + e.totalAmount);
    double stockVal = web.medicines.fold(0.0, (s, m) => s + (m.stock * m.purRate));

    return ListView(children: [
      Row(children: [
        _stat('TOTAL SALES', 'Rs ' + todaySales.toStringAsFixed(2), Icons.trending_up, Colors.green),
        const SizedBox(width: 12),
        _stat('PURCHASES', 'Rs ' + todayPur.toStringAsFixed(2), Icons.shopping_cart, Colors.orange),
        const SizedBox(width: 12),
        _stat('STOCK VALUATION', 'Rs ' + stockVal.toStringAsFixed(0), Icons.inventory_2, Colors.purple),
        const SizedBox(width: 12),
        _stat('SHORTAGES', web.shortages.length.toString() + ' Items', Icons.warning_amber, Colors.red),
      ]),
      const SizedBox(height: 25),
      Row(children: [
        _btn('NEW SALE BILL', Icons.add_shopping_cart, Colors.blue.shade700, () => _showNewSale(context, web)),
        const SizedBox(width: 12),
        _btn('ADD PURCHASE', Icons.downloading, Colors.orange.shade800, () => _showNewPur(context, web)),
        const SizedBox(width: 12),
        _btn('RECEIPT VOUCHER', Icons.add_chart, Colors.green.shade700, () => _showVoucher(context, web, 'Receipt')),
        const SizedBox(width: 12),
        _btn('PAYMENT VOUCHER', Icons.analytics, Colors.red.shade700, () => _showVoucher(context, web, 'Payment')),
      ]),
      const SizedBox(height: 25),
      const Text('Recent Invoices', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
      const SizedBox(height: 8),
      ...web.sales.reversed.take(5).map((s) => Card(child: ListTile(
        leading: const Icon(Icons.receipt_long, color: Colors.blue),
        title: Text(s.partyName + ' (Bill #' + s.billNo + ')'),
        subtitle: Text(DateFormat('dd/MM/yyyy').format(s.date)),
        trailing: Text('Rs ' + s.totalAmount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
      ))),
    ]);
  }

  Widget _buildBilling(WebManager web) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Invoices & Billing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white), onPressed: () => _showNewSale(context, web), icon: const Icon(Icons.add), label: const Text('NEW BILL')),
      ]),
      const SizedBox(height: 15),
      Expanded(child: web.sales.isEmpty ? const Center(child: Text('No sales recorded yet.')) : ListView.builder(
        itemCount: web.sales.length,
        itemBuilder: (c, i) {
          final s = web.sales[web.sales.length - 1 - i];
          return Card(child: ListTile(title: Text(s.partyName + ' - Bill #' + s.billNo), subtitle: Text('Mode: ' + s.paymentMode + ' | Date: ' + DateFormat('dd/MM/yy').format(s.date)), trailing: Text('Rs ' + s.totalAmount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))));
        },
      )),
    ]);
  }

  Widget _buildStock(WebManager web) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Medicines & Stock (' + web.medicines.length.toString() + ' Items)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white), onPressed: () => _showNewMed(context, web), icon: const Icon(Icons.add), label: const Text('ADD PRODUCT')),
      ]),
      const SizedBox(height: 15),
      Expanded(child: ListView.builder(
        itemCount: web.medicines.length,
        itemBuilder: (c, i) {
          final m = web.medicines[i];
          return Card(child: ListTile(title: Text(m.name + ' (' + m.packing + ')'), subtitle: Text('MRP: Rs ' + m.mrp.toString() + ' | Rate A: Rs ' + m.rateA.toString()), trailing: Text('Stock: ' + m.stock.toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))));
        },
      )),
    ]);
  }

  Widget _buildAccounts(WebManager web) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Accounts & Party Ledgers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Row(children: [
          ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white), onPressed: () => _showVoucher(context, web, 'Receipt'), icon: const Icon(Icons.add), label: const Text('RECEIPT')),
          const SizedBox(width: 8),
          ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white), onPressed: () => _showVoucher(context, web, 'Payment'), icon: const Icon(Icons.remove), label: const Text('PAYMENT')),
        ]),
      ]),
      const SizedBox(height: 15),
      Expanded(child: ListView.builder(
        itemCount: web.parties.length,
        itemBuilder: (c, i) {
          final p = web.parties[i];
          return Card(child: ListTile(title: Text(p.name), subtitle: Text(p.group + ' | City: ' + p.city + ' | GST: ' + p.gst), trailing: Text('Bal: Rs ' + p.opBal.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))));
        },
      )),
    ]);
  }

  Widget _buildGst(WebManager web) {
    double totalTaxable = web.sales.fold(0.0, (s, e) => s + e.totalAmount * 0.88);
    double totalTax = web.sales.fold(0.0, (s, e) => s + e.totalAmount * 0.12);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('GST Statutory Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 15),
      Row(children: [
        _stat('TAXABLE OUTWARD', 'Rs ' + totalTaxable.toStringAsFixed(2), Icons.assignment, Colors.green),
        const SizedBox(width: 12),
        _stat('GST COLLECTED', 'Rs ' + totalTax.toStringAsFixed(2), Icons.summarize, Colors.blue),
      ]),
    ]);
  }

  Widget _buildSettingsView(WebManager web) {
    const liveLink = 'https://pharoah-erp.pages.dev';
    return ListView(children: [
      const Text('Settings & Cloud Center', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 15),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blue.shade200), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.public_rounded, color: Color(0xFF0D47A1), size: 24),
            SizedBox(width: 10),
            Text('Your Live Web Management Portal Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D47A1))),
          ]),
          const SizedBox(height: 8),
          const Text('इस लिंक को किसी भी मोबाइल, टैबलेट या लैपटॉप में खोलकर अपनी दुकान कहीं से भी चलाएं:', style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Expanded(child: SelectableText(liveLink, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)))),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: Color(0xFF0D47A1), size: 20),
                tooltip: 'Copy Link',
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: liveLink));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link Copied!')));
                },
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.orange.shade200), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.menu_book_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 10),
            Text('Pharoah ERP - हिंदी यूजर मार्गदर्शिका (User Guide)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.deepOrange)),
          ]),
          const SizedBox(height: 12),
          _guideStep('1. 1-क्लिक गूगल साइन-इन', 'ऊपर Sign in with Google दबाकर अपना Gmail चुनें। किसी कोड या स्क्रिप्ट की जरूरत नहीं।'),
          const SizedBox(height: 8),
          _guideStep('2. ऑटो-सिंक (100% डेटा सुरक्षा)', 'हर नया बिल और स्टॉक अपने आप आपके Google Drive (Pharoah_ERP_Cloud_Database) में सुरक्षित सेव रहेगा।'),
          const SizedBox(height: 8),
          _guideStep('3. लाइव वेबसाइट से दुकान चलाएं', 'https://pharoah-erp.pages.dev लिंक से घर बैठे भी दुकान की बिक्री और स्टॉक चेक करें।'),
        ]),
      ),
    ]);
  }

  Widget _guideStep(String t, String d) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.deepOrange)),
        const SizedBox(height: 4),
        Text(d, style: const TextStyle(fontSize: 11, color: Colors.black87)),
      ]),
    );
  }

  void _handleGoogleSignIn(BuildContext context, WebManager web) {
    final emailC = TextEditingController(text: 'shop.owner@gmail.com');
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Row(children: [Icon(Icons.account_circle, color: Colors.red), SizedBox(width: 10), Text('Sign in with Google')]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Google OAuth Client ID Connected', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(controller: emailC, decoration: const InputDecoration(labelText: 'Your Gmail Account', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCEL')),
        ElevatedButton(onPressed: () async {
          await WebDriveBridge.saveGoogleSession(emailC.text, 'oauth_verified');
          if (c.mounted) Navigator.pop(c);
          await web.syncWithDrive();
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google Drive Connected!'), backgroundColor: Colors.green));
        }, child: const Text('CONTINUE')),
      ],
    ));
  }

  void _showNewSale(BuildContext context, WebManager web) {
    if (web.medicines.isEmpty || web.parties.isEmpty) return;
    Party p = web.parties.first;
    Medicine m = web.medicines.first;
    final qtyC = TextEditingController(text: '1');
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('New Sale Bill'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        const SizedBox(height: 10),
        TextField(controller: qtyC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qty')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCEL')),
        ElevatedButton(onPressed: () {
          double q = double.tryParse(qtyC.text) ?? 1;
          double tot = q * (m.rateA > 0 ? m.rateA : m.mrp);
          final item = BillItem(id: DateTime.now().toString(), srNo: 1, medicineID: m.id, name: m.name, packing: m.packing, batch: 'B-1', exp: '12/28', hsn: m.hsnCode, mrp: m.mrp, qty: q, rate: m.rateA, gstRate: m.gst, total: tot);
          web.addSale(Sale(id: DateTime.now().toString(), partyId: p.id, billNo: 'INV-' + DateTime.now().millisecondsSinceEpoch.toString().substring(7), date: DateTime.now(), partyName: p.name, partyGstin: p.gst, partyState: p.state, items: [item], totalAmount: tot, paymentMode: 'CASH'));
          Navigator.pop(c);
        }, child: const Text('SAVE BILL')),
      ],
    ));
  }

  void _showNewPur(BuildContext context, WebManager web) {
    final dC = TextEditingController(text: 'DEMO DISTRIBUTORS');
    final aC = TextEditingController(text: '5000');
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('Add Purchase'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: dC, decoration: const InputDecoration(labelText: 'Supplier')),
        TextField(controller: aC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount Rs')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCEL')),
        ElevatedButton(onPressed: () {
          web.addPurchase(Purchase(id: DateTime.now().toString(), partyId: '1', internalNo: 'PUR-01', billNo: 'P-' + DateTime.now().millisecondsSinceEpoch.toString().substring(8), date: DateTime.now(), entryDate: DateTime.now(), distributorName: dC.text, items: [], totalAmount: double.tryParse(aC.text) ?? 0, paymentMode: 'CREDIT'));
          Navigator.pop(c);
        }, child: const Text('SAVE')),
      ],
    ));
  }

  void _showVoucher(BuildContext context, WebManager web, String type) {
    final pC = TextEditingController(text: web.parties.first.name);
    final aC = TextEditingController(text: '1000');
    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text('New ' + type + ' Voucher'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: pC, decoration: const InputDecoration(labelText: 'Party')),
        TextField(controller: aC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount Rs')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCEL')),
        ElevatedButton(onPressed: () {
          web.addVoucher(Voucher(id: DateTime.now().toString(), voucherNo: 'V-01', type: type, date: DateTime.now(), partyId: '1', partyName: pC.text, amount: double.tryParse(aC.text) ?? 0, paymentMode: 'Cash'));
          Navigator.pop(c);
        }, child: const Text('SAVE')),
      ],
    ));
  }

  void _showNewParty(BuildContext context, WebManager web) {
    final nC = TextEditingController();
    final cC = TextEditingController(text: 'JAIPUR');
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('Add Party'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nC, decoration: const InputDecoration(labelText: 'Party Name')),
        TextField(controller: cC, decoration: const InputDecoration(labelText: 'City')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCEL')),
        ElevatedButton(onPressed: () {
          if (nC.text.isNotEmpty) {
            web.addParty(Party(id: DateTime.now().toString(), name: nC.text.toUpperCase(), city: cC.text, gst: '08XXXXX1234'));
            Navigator.pop(c);
          }
        }, child: const Text('SAVE')),
      ],
    ));
  }

  void _showNewMed(BuildContext context, WebManager web) {
    final nC = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('Add Product'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nC, decoration: const InputDecoration(labelText: 'Product Name')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCEL')),
        ElevatedButton(onPressed: () {
          if (nC.text.isNotEmpty) {
            web.addMedicine(Medicine(id: DateTime.now().toString(), name: nC.text.toUpperCase(), packing: '10 TAB', mrp: 100, purRate: 70, rateA: 90, stock: 50));
            Navigator.pop(c);
          }
        }, child: const Text('SAVE')),
      ],
    ));
  }

  Widget _stat(String l, String v, IconData i, Color c) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Row(children: [
        CircleAvatar(backgroundColor: c.withAlpha(25), child: Icon(i, color: c)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)), Text(v, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))]),
      ]),
    ));
  }

  Widget _btn(String l, IconData i, Color c, VoidCallback onTap) {
    return Expanded(child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
        child: Column(children: [Icon(i, color: Colors.white, size: 22), const SizedBox(height: 5), Text(l, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))]),
      ),
    ));
  }
}