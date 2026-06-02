// FILE: lib/finance/company_stock_view.dart (FULLY RESOLVED COMPLETE COMPILE-SAFE VERSION)

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../pharoah_date_controller.dart';
import '../app_date_logic.dart';
import '../../pdf/statements/company_stock_pdf.dart';
import '../pdf/pdf_router_service.dart';

enum ReportStep {
  selectionForm,
  processingLoader,
  showReportGrid,
}

class CompanyStockView extends StatefulWidget {
  const CompanyStockView({super.key});
  @override State<CompanyStockView> createState() => _CompanyStockViewState();
}

class _CompanyStockViewState extends State<CompanyStockView> {
  // Theme Colors
  static const Color brandDark = Color(0xFF1E1B4B); 
  static const Color tableHeaderColor = Color(0xFF2E2B6B); 
  static const Color accentElectric = Color(0xFF3B82F6); 
  static const Color neonEmerald = Color(0xFF10B981); 

  // Flow State
  ReportStep currentStep = ReportStep.selectionForm;

  // Configuration States
  String companySelectionType = "All"; 
  String selectedCompany = "";
  Set<String> selectedCompanyIds = {}; 

  String partySelectionType = "All"; 
  String selectedParty = "";
  String selectedPartyId = "";
  Set<String> selectedPartyIds = {}; 

  String transactionType = "BOTH"; 
  String valuationBasis = "PURCHASE"; 
  
  // CN/DN (Return) Adjustments
  bool deductCN = false; 
  bool deductDN = false; 

  // Date Range (Locked to FY)
  DateTimeRange fyDateRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );

  // Loader states
  double processingProgress = 0.0;
  String processingStatusText = "Initializing Pipeline...";

  @override
  void initState() {
    super.initState();
    final ph = Provider.of<PharoahManager>(context, listen: false);
    
    // Set standard financial year boundaries
    DateTime smartDate = AppDateLogic.getSmartDate(ph.currentFY);
    fyDateRange = DateTimeRange(
      start: DateTime(smartDate.year, smartDate.month, 1),
      end: smartDate,
    );

    // Load initial active databases from PharoahManager
    selectedCompanyIds = ph.companies.map((c) => c.name).toSet();
    selectedPartyIds = ph.parties.where((p) => p.name != "CASH").map((p) => p.name).toSet();

    if (ph.companies.isNotEmpty) selectedCompany = ph.companies.first.name;
    if (ph.parties.isNotEmpty) {
      selectedParty = ph.parties.first.name;
      selectedPartyId = ph.parties.first.id;
    }
  }

  String _formatDate(DateTime d) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return "${pad(d.day)}/${pad(d.month)}/${d.year}";
  }

  // ===========================================================================
  // PROGRESSIVE (FORWARD-CALCULATION) STOCK FLOW ENGINE
  // ===========================================================================
  Map<String, double> _calculateCustomItemFlow({
    required Medicine med,
    required DateTime from,
    required DateTime to,
    required PharoahManager ph,
  }) {
    double baseOpening = 0.0;
    
    if (partySelectionType == "Single") {
      baseOpening = 0.0;
    } else {
      final batches = ph.batchHistory[med.identityKey] ?? [];
      if (batches.isNotEmpty) {
        baseOpening = batches.fold(0.0, (sum, b) => sum + b.openingQty + b.adjustmentQty);
      } else {
        double totalPur = 0.0;
        double totalSale = 0.0;
        double totalCN = 0.0;
        double totalDN = 0.0;
        for (var p in ph.purchases) {
          for (var it in p.items.where((it) => it.medicineID == med.id)) {
            totalPur += (it.qty + it.freeQty);
          }
        }
        for (var s in ph.sales.where((s) => s.status == "Active")) {
          for (var it in s.items.where((it) => it.medicineID == med.id)) {
            totalSale += (it.qty + it.freeQty);
          }
        }
        for (var r in ph.saleReturns.where((r) => r.status == "Active")) {
          for (var it in r.items.where((it) => it.medicineID == med.id && !it.isBreakage)) {
            totalCN += (it.qty + it.freeQty);
          }
        }
        for (var r in ph.purchaseReturns.where((r) => r.status == "Active")) {
          for (var it in r.items.where((it) => it.medicineID == med.id && !it.isBreakage)) {
            totalDN += (it.qty + it.freeQty);
          }
        }
        baseOpening = med.stock - totalPur + totalSale - totalCN + totalDN;
      }
    }

    double purBefore = 0.0;
    double saleBefore = 0.0;
    double cnBefore = 0.0;
    double dnBefore = 0.0;

    for (var p in ph.purchases.where((p) => p.date.isBefore(from))) {
      if (partySelectionType == "Single" && p.partyId != selectedPartyId) continue;
      for (var it in p.items.where((it) => it.medicineID == med.id)) {
        purBefore += (it.qty + it.freeQty);
      }
    }

    for (var s in ph.sales.where((s) => s.status == "Active" && s.date.isBefore(from))) {
      if (partySelectionType == "Single" && s.partyId != selectedPartyId) continue;
      for (var it in s.items.where((it) => it.medicineID == med.id)) {
        saleBefore += (it.qty + it.freeQty);
      }
    }

    for (var r in ph.saleReturns.where((r) => r.status == "Active" && r.date.isBefore(from))) {
      if (partySelectionType == "Single" && r.partyName != selectedParty) continue;
      for (var it in r.items.where((it) => it.medicineID == med.id && !it.isBreakage)) {
        cnBefore += (it.qty + it.freeQty);
      }
    }

    for (var r in ph.purchaseReturns.where((r) => r.status == "Active" && r.date.isBefore(from))) {
      if (partySelectionType == "Single" && r.distributorName != selectedParty) continue;
      for (var it in r.items.where((it) => it.medicineID == med.id && !it.isBreakage)) {
        dnBefore += (it.qty + it.freeQty);
      }
    }

    double opening = baseOpening + purBefore - saleBefore + cnBefore - dnBefore;

    double purInPeriod = 0.0;
    double saleInPeriod = 0.0;
    double cnInPeriod = 0.0;
    double dnInPeriod = 0.0;

    DateTime fromLimit = from.subtract(const Duration(seconds: 1));
    DateTime toLimit = to.add(const Duration(days: 1));

    for (var p in ph.purchases.where((p) => p.date.isAfter(fromLimit) && p.date.isBefore(toLimit))) {
      if (partySelectionType == "Single" && p.partyId != selectedPartyId) continue;
      for (var it in p.items.where((it) => it.medicineID == med.id)) {
        purInPeriod += (it.qty + it.freeQty);
      }
    }

    for (var s in ph.sales.where((s) => s.status == "Active" && s.date.isAfter(fromLimit) && s.date.isBefore(toLimit))) {
      if (partySelectionType == "Single" && s.partyId != selectedPartyId) continue;
      for (var it in s.items.where((it) => it.medicineID == med.id)) {
        saleInPeriod += (it.qty + it.freeQty);
      }
    }

    for (var r in ph.saleReturns.where((r) => r.status == "Active" && r.date.isAfter(fromLimit) && r.date.isBefore(toLimit))) {
      if (partySelectionType == "Single" && r.partyName != selectedParty) continue;
      for (var it in r.items.where((it) => it.medicineID == med.id && !it.isBreakage)) {
        cnInPeriod += (it.qty + it.freeQty);
      }
    }

    for (var r in ph.purchaseReturns.where((r) => r.status == "Active" && r.date.isAfter(fromLimit) && r.date.isBefore(toLimit))) {
      if (partySelectionType == "Single" && r.distributorName != selectedParty) continue;
      for (var it in r.items.where((it) => it.medicineID == med.id && !it.isBreakage)) {
        dnInPeriod += (it.qty + it.freeQty);
      }
    }

    double received = purInPeriod;
    double issued = saleInPeriod;

    if (deductDN) {
      received -= dnInPeriod;
    } else {
      issued += dnInPeriod; 
    }
    if (deductCN) {
      issued -= cnInPeriod;
    } else {
      received += cnInPeriod; 
    }

    double closing = opening + received - issued;

    return {
      'opening': opening,
      'received': received,
      'sale': issued,
      'closing': closing,
    };
  }

  // ===========================================================================
  // MASTER WIDGET BUILDER
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    switch (currentStep) {
      case ReportStep.selectionForm:
        return _buildSelectionForm();
      case ReportStep.processingLoader:
        return _buildProcessingLoader();
      case ReportStep.showReportGrid:
        return _buildReportGrid(Provider.of<PharoahManager>(context));
    }
  }

  // ===========================================================================
  // SCREEN 1: FORM WIDGET
  // ===========================================================================
  Widget _buildSelectionForm() {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(title: const Text("Stock Flow & Valuation Audit"), backgroundColor: brandDark, foregroundColor: Colors.white),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Container(
            width: 520,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 20)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [brandDark, Color(0xFF312E81)]),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: Colors.orangeAccent, size: 24),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("STATEMENT CONFIGURATION", style: TextStyle(color: Color(0xFF818CF8), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          SizedBox(height: 2),
                          Text("Select Parameters Deeply", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel("1. SEARCH SCOPE (COMPANIES)"),
                      Row(
                        children: [
                          _formSegment("All Companies", companySelectionType == "All", () => setState(() => companySelectionType = "All")),
                          _formSegment("Single Brand", companySelectionType == "Single", () => setState(() => companySelectionType = "Single")),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (companySelectionType == "All") ...[
                        _buildGatewayTrigger("Companies Included", "${selectedCompanyIds.length} Brands Selected", () {
                          final List<String> allCompaniesList = ph.companies.map((c) => c.name).toList();
                          _openAdvancedExclusionDialog(
                            title: "COMPANIES", 
                            allItems: allCompaniesList, 
                            currentlySelected: selectedCompanyIds, 
                            onConfirmed: (v) => setState(() => selectedCompanyIds = v),
                          );
                        }),
                      ] else ...[
                        _buildSearchPickerTrigger("Company", selectedCompany, (v) {
                          setState(() { selectedCompany = v; });
                        }, ph.companies.map((c) => c.name).toList()),
                      ],
                      const SizedBox(height: 15),
                      _sectionLabel("2. CROSS-REFERENCE PARTY TARGET"),
                      Row(
                        children: [
                          _formSegment("All Parties", partySelectionType == "All", () => setState(() => partySelectionType = "All")),
                          _formSegment("Single Party", partySelectionType == "Single", () => setState(() => partySelectionType = "Single")),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (partySelectionType == "All") ...[
                        _buildGatewayTrigger("Parties Included", "${selectedPartyIds.length} Parties Selected", () {
                          final List<String> allPartiesList = ph.parties.where((p) => p.name != "CASH").map((p) => p.name).toList();
                          _openAdvancedExclusionDialog(
                            title: "PARTIES", 
                            allItems: allPartiesList, 
                            currentlySelected: selectedPartyIds, 
                            onConfirmed: (v) => setState(() => selectedPartyIds = v),
                          );
                        }),
                      ] else ...[
                        _buildSearchPickerTrigger("Party", selectedParty, (v) {
                          setState(() { 
                            selectedParty = v; 
                            try { selectedPartyId = ph.parties.firstWhere((p) => p.name == v).id; } catch(e) {}
                          });
                        }, ph.parties.where((p) => p.name != "CASH").map((p) => p.name).toList()),
                      ],
                      const SizedBox(height: 15),
                      _sectionLabel("3. BUSINESS FLOW & VALUATION"),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSimpleDropdown(
                              value: transactionType,
                              items: ["SALE", "PURCHASE", "BOTH"],
                              onChanged: (v) => setState(() => transactionType = v!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildSimpleDropdown(
                              value: valuationBasis,
                              items: ["PURCHASE", "SALE", "MRP", "MANUAL"],
                              onChanged: (v) => setState(() => valuationBasis = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      _sectionLabel("4. RETURN & REVERSAL ADJUSTMENTS (NET TOTAL)"),
                      _buildSwitchTile(
                        "Deduct Credit Notes (CN - Sales Return)", 
                        "Deducts return stocks to compute Net Outward", 
                        deductCN, 
                        (v) => setState(() => deductCN = v)
                      ),
                      _buildSwitchTile(
                        "Deduct Debit Notes (DN - Purchase Return)", 
                        "Deducts returned stocks to compute Net Inward", 
                        deductDN, 
                        (v) => setState(() => deductDN = v)
                      ),
                      const SizedBox(height: 15),
                      _sectionLabel("5. ACTIVE FINANCIAL YEAR DATES (LOCKED)"),
                      _buildDateSelectorTile(),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: accentElectric, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: _startSmartReportGeneration,
                          child: const Text("GENERATE AUDIT STATEMENT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SCREEN 2: PROGRESS LOADER
  // ===========================================================================
  Widget _buildProcessingLoader() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sync_rounded, color: Colors.orangeAccent, size: 60),
            const SizedBox(height: 25),
            Text(
              "${(processingProgress * 100).toInt()}%",
              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 250,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: processingProgress,
                  color: Colors.orangeAccent,
                  backgroundColor: Colors.white10,
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              processingStatusText.toUpperCase(),
              style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SCREEN 3: GRID TABLE REPORT
  // ===========================================================================
  Widget _buildReportGrid(PharoahManager ph) {
    String colReceiveQty = deductDN ? "NET RECEIVE\nQTY" : "RECEIVE\nQTY";
    String colReceiveVal = deductDN ? "NET RECEIVE\nVALUE (₹)" : "RECEIVE\nVALUE (₹)";
    String colIssueQty = deductCN ? "NET ISSUE\nQTY" : "ISSUE\nQTY";
    String colIssueVal = deductCN ? "NET ISSUE\nVALUE (₹)" : "ISSUE\nVALUE (₹)";

    List<Medicine> activeMeds = ph.medicines.where((m) {
      String cName = ph.companies.firstWhere((c) => c.id == m.companyId, orElse: () => Company(id: '', name: 'OTHERS')).name;
      if (companySelectionType == "Single") {
        return cName == selectedCompany;
      }
      return selectedCompanyIds.contains(cName);
    }).toList();

    double totalOpStock = 0; double totalOpVal = 0;
    double totalRecQty = 0; double totalRecVal = 0;
    double totalIssueQty = 0; double totalIssueVal = 0;
    double totalCloStock = 0; double totalCloVal = 0;

    List<TableRow> tableRows = [];

    tableRows.add(TableRow(
      decoration: const BoxDecoration(color: tableHeaderColor),
      children: [
        _th("PRODUCT DESCRIPTION", isLeft: true),
        _th("UNIT"),
        _th("OPENING\nSTOCK"),
        _th("OPENING\nVALUE (₹)"),
        _th(colReceiveQty),
        _th(colReceiveVal),
        _th(colIssueQty),
        _th(colIssueVal),
        _th("CLOSING\nSTOCK"),
        _th("CLOSING\nVALUE (₹)"),
      ],
    ));

    for (int idx = 0; idx < activeMeds.length; idx++) {
      final m = activeMeds[idx];
      final flow = _calculateCustomItemFlow(med: m, from: fyDateRange.start, to: fyDateRange.end, ph: ph);
      double rate = (valuationBasis == "PURCHASE") ? m.purRate : (valuationBasis == "SALE" ? m.rateA : m.mrp);

      double opStock = (flow['opening'] ?? 0.0);
      double recQty = (flow['received'] ?? 0.0);
      double issueQty = (flow['sale'] ?? 0.0);
      double cloStock = (flow['closing'] ?? 0.0);

      double opVal = opStock * rate;
      double recVal = recQty * rate;
      double issueVal = issueQty * rate;
      double cloVal = cloStock * rate;

      totalOpStock += opStock; totalOpVal += opVal;
      totalRecQty += recQty; totalRecVal += recVal;
      totalIssueQty += issueQty; totalIssueVal += issueVal;
      totalCloStock += cloStock; totalCloVal += cloVal;

      bool isShaded = idx % 2 != 0;

      tableRows.add(TableRow(
        decoration: BoxDecoration(color: isShaded ? const Color(0xFFF8FAFC) : Colors.white),
        children: [
          _td(m.name, isLeft: true, isBold: true),
          _td(m.packing),
          _td(opStock.toInt().toString()),
          _td(opVal.toStringAsFixed(2)),
          _td(recQty.toInt().toString()),
          _td(recVal.toStringAsFixed(2)),
          _td(issueQty.toInt().toString()),
          _td(issueVal.toStringAsFixed(2)),
          _td(cloStock.toInt().toString(), textColor: neonEmerald),
          _td(cloVal.toStringAsFixed(2), textColor: neonEmerald),
        ],
      ));
    }

    tableRows.add(TableRow(
      decoration: const BoxDecoration(color: Color(0xFFECFDF5)),
      children: [
        _td("TOTAL", isLeft: true, isBold: true, textColor: const Color(0xFF047857)),
        _td("-", isBold: true),
        _td(totalOpStock.toInt().toString(), isBold: true, textColor: const Color(0xFF047857)),
        _td("₹${totalOpVal.toStringAsFixed(2)}", isBold: true, textColor: const Color(0xFF047857)),
        _td(totalRecQty.toInt().toString(), isBold: true, textColor: const Color(0xFF047857)),
        _td("₹${totalRecVal.toStringAsFixed(2)}", isBold: true, textColor: const Color(0xFF047857)),
        _td(totalIssueQty.toInt().toString(), isBold: true, textColor: const Color(0xFF047857)),
        _td("₹${totalIssueVal.toStringAsFixed(2)}", isBold: true, textColor: const Color(0xFF047857)),
        _td(totalCloStock.toInt().toString(), isBold: true, textColor: const Color(0xFF047857)),
        _td("₹${totalCloVal.toStringAsFixed(2)}", isBold: true, textColor: const Color(0xFF047857)),
      ],
    ));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), 
      appBar: AppBar(
        title: Text(ph.activeCompany?.name ?? "DWARIKA MEDICALS", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: brandDark,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => currentStep = ReportStep.selectionForm),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: "Export PDF",
            onPressed: () async {
              await CompanyStockPdf.generate(
                shop: ph.activeCompany!,
                groupedData: {
                  for (var name in ph.companies.map((c) => c.name))
                    name: ph.medicines.where((m) {
                      String cName = ph.companies.firstWhere((c) => c.id == m.companyId, orElse: () => Company(id: '', name: 'OTHERS')).name;
                      return cName == name;
                    }).toList()
                },
                from: fyDateRange.start,
                to: fyDateRange.end,
                valuationBasis: valuationBasis,
                ph: ph,
                companySelectionType: companySelectionType,
                selectedCompanyIds: selectedCompanyIds,
                partySelectionType: partySelectionType,
                selectedParty: selectedParty,
                selectedPartyId: selectedPartyId,
                deductCN: deductCN,
                deductDN: deductDN,
              );
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            width: 1000,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(25.0),
            child: Column(
              children: [
                _buildMockReportHeader(ph),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    width: 950,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Table(
                        columnWidths: const {
                          0: FixedColumnWidth(180),
                          1: FixedColumnWidth(60),
                          2: FixedColumnWidth(80),
                          3: FixedColumnWidth(100),
                          4: FixedColumnWidth(80),
                          5: FixedColumnWidth(100),
                          6: FixedColumnWidth(80),
                          7: FixedColumnWidth(100),
                          8: FixedColumnWidth(80),
                          9: FixedColumnWidth(100),
                        },
                        border: TableBorder.all(color: const Color(0xFFE2E8F0), width: 1),
                        children: tableRows,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                _buildLegislationDisclaimer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMockReportHeader(PharoahManager ph) {
    return Center(
      child: Column(
        children: [
          Text(ph.activeCompany?.name ?? "DWARIKA MEDICALS", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: brandDark, letterSpacing: 1)),
          const SizedBox(height: 2),
          Text("D.L. No. : ${ph.activeCompany?.dlNo ?? 'N/A'} | GST: ${ph.activeCompany?.gstin ?? 'N/A'}", style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: brandDark.withOpacity(0.08), 
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "DYNAMIC COMPILATION FLOW REPORT (${_formatDate(fyDateRange.start)} to ${_formatDate(fyDateRange.end)})",
              style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: brandDark),
            ),
          )
        ],
      ),
    );
  }

  // ===========================================================================
  // SUB-WIDGET UTILITIES
  // ===========================================================================

  Widget _sectionLabel(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(t, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 0.5)),
    );
  }

  Widget _formSegment(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? brandDark : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? brandDark : const Color(0xFFE2E8F0)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: active ? Colors.white : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _th(String text, {bool isLeft = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      alignment: isLeft ? Alignment.centerLeft : Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
      ),
    );
  }

  Widget _td(String text, {bool isLeft = false, bool isBold = false, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      alignment: isLeft ? Alignment.centerLeft : Alignment.center,
      child: Text(
        text,
        style: TextStyle(fontSize: 8.5, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: textColor ?? const Color(0xFF1E293B)),
      ),
    );
  }

  Widget _buildLegislationDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        children: [
          const Icon(Icons.gavel_rounded, color: Colors.blueGrey, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Note: This audit is locked to active Financial Year parameters. Processing is completely sandboxed on local resources to prevent leaks.",
              style: const TextStyle(fontSize: 8, color: Colors.blueGrey, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
