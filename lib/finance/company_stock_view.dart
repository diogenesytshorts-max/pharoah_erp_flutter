// FILE: lib/finance/company_stock_view.dart (FULLY UPDATED - STABLE PROGRESSIVE METHOD)

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
  static const Color brandDark = Color(0xFF1E1B4B); 
  static const Color tableHeaderColor = Color(0xFF2E2B6B); 
  static const Color accentElectric = Color(0xFF3B82F6); 
  static const Color neonEmerald = Color(0xFF10B981); 

  ReportStep currentStep = ReportStep.selectionForm;

  String companySelectionType = "All"; 
  String selectedCompany = "";
  Set<String> selectedCompanyIds = {}; 

  String partySelectionType = "All"; 
  String selectedParty = "";
  String selectedPartyId = "";
  Set<String> selectedPartyIds = {}; 

  String transactionType = "BOTH"; 
  String valuationBasis = "PURCHASE"; 
  
  bool deductCN = false; 
  bool deductDN = false; 

  DateTimeRange fyDateRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );

  double processingProgress = 0.0;
  String processingStatusText = "Initializing Pipeline...";

  @override
  void initState() {
    super.initState();
    final ph = Provider.of<PharoahManager>(context, listen: false);
    DateTime smartDate = AppDateLogic.getSmartDate(ph.currentFY);
    fyDateRange = DateTimeRange(
      start: DateTime(smartDate.year, smartDate.month, 1),
      end: smartDate,
    );

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
  // PROGRESSIVE ENGINE: STOCK CALCULATION
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

  void _openAdvancedExclusionDialog({
    required String title,
    required List<String> allItems,
    required Set<String> currentlySelected,
    required ValueChanged<Set<String>> onConfirmed,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        String searchVal = "";
        Set<String> tempSelected = Set.from(currentlySelected);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = allItems.where((element) => element.toLowerCase().contains(searchVal.toLowerCase())).toList();
            bool isAllSelected = tempSelected.length == allItems.length;

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  width: 400,
                  height: 500,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A), 
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: accentElectric.withOpacity(0.4), width: 1.5),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("SELECT $title", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                            onPressed: () => Navigator.pop(c),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                hintText: "Search...",
                                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                                prefixIcon: const Icon(Icons.search, color: accentElectric, size: 16),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.08),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              ),
                              onChanged: (v) => setDialogState(() => searchVal = v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: () {
                              setDialogState(() {
                                if (isAllSelected) {
                                  tempSelected.clear();
                                } else {
                                  tempSelected = Set.from(allItems);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isAllSelected ? neonEmerald.withOpacity(0.15) : Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(isAllSelected ? Icons.check_box : Icons.check_box_outline_blank, size: 16, color: isAllSelected ? neonEmerald : Colors.white70),
                                  const SizedBox(width: 4),
                                  const Text("All", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 15),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text("No records match.", style: TextStyle(color: Colors.white38, fontSize: 12)))
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (c, idx) {
                                  final item = filtered[idx];
                                  bool isChecked = tempSelected.contains(item);
                                  return CheckboxListTile(
                                    activeColor: accentElectric,
                                    checkColor: Colors.white,
                                    dense: true,
                                    title: Text(item, style: TextStyle(color: isChecked ? Colors.white : Colors.white54, fontWeight: isChecked ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                                    value: isChecked,
                                    onChanged: (val) {
                                      setDialogState(() {
                                        if (val == true) {
                                          tempSelected.add(item);
                                        } else {
                                          tempSelected.remove(item);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: accentElectric, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () {
                            onConfirmed(tempSelected);
                            Navigator.pop(c);
                          },
                          child: const Text("APPLY SELECTION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openSearchableSinglePicker(String title, List<String> items, String currentSelection, ValueChanged<String> onSelected) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        String searchVal = "";
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = items.where((element) => element.toLowerCase().contains(searchVal.toLowerCase())).toList();
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  width: 400,
                  height: 500,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: accentElectric.withOpacity(0.4), width: 1.5),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("SEARCH $title", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                            onPressed: () => Navigator.pop(c),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 5),
                      TextField(
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          hintText: "Type to search...",
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                          prefixIcon: const Icon(Icons.search, color: accentElectric, size: 16),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.08),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                        onChanged: (v) => setDialogState(() => searchVal = v),
                      ),
                      const SizedBox(height: 15),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text("No records found.", style: TextStyle(color: Colors.white38, fontSize: 12)))
                            : ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (context, idx) {
                                    final item = filtered[idx];
                                    bool isSelected = item == currentSelection;
                                    return ListTile(
                                      leading: Icon(Icons.check_circle_rounded, color: isSelected ? neonEmerald : Colors.transparent, size: 18),
                                      title: Text(item, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                      onTap: () {
                                        onSelected(item);
                                        Navigator.pop(c);
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }

  Future<void> _pickDateRangeWithinFY() async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    final DateTime fyStart = AppDateLogic.getFYStart(ph.currentFY);
    final DateTime fyEnd = AppDateLogic.getFYEnd(ph.currentFY);

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: fyDateRange,
      firstDate: fyStart, 
      lastDate: fyEnd,   
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: brandDark,
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        fyDateRange = picked;
      });
    }
  }

  void _startSmartReportGeneration() {
    setState(() {
      currentStep = ReportStep.processingLoader;
      processingProgress = 0.0;
      processingStatusText = "Connecting with DB Engine...";
    });

    final List<String> phases = [
      "Scanning meds.json database...",
      "Filtering Excluded Companies list...",
      "Filtering Excluded Parties list...",
      "Analyzing Return (CN/DN) Reversals...",
      "Mapping product-batch indices...",
      "Summing Net Inflow & Net Outflow...",
      "Applying Manual Rate Valuation algorithms...",
      "Compiling Grand Totals..."
    ];

    int step = 0;
    Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (processingProgress >= 1.0) {
        timer.cancel();
        _showSuccessMiddleDialog();
      } else {
        setState(() {
          processingProgress += 0.15;
          if (processingProgress > 1.0) processingProgress = 1.0;
          
          if (step < phases.length) {
            processingStatusText = phases[step];
            step++;
          }
        });
      }
    });
  }

  void _showSuccessMiddleDialog() {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    List<String> excludedParties = ph.parties.where((p) => p.name != "CASH" && !selectedPartyIds.contains(p.name)).map((e) => e.name).toList();
    List<String> excludedCompanies = ph.companies.where((c) => !selectedCompanyIds.contains(c.name)).map((e) => e.name).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.verified_rounded, color: neonEmerald, size: 24),
              SizedBox(width: 10),
              Text("PROCESS COMPLETE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Your Statement has been processed in a safe memory container.",
                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
              const SizedBox(height: 15),
              _bulletPoint("Companies: ${companySelectionType == "All" ? "${selectedCompanyIds.length} Active" : selectedCompany}"),
              if (companySelectionType == "All" && excludedCompanies.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 14, bottom: 4),
                  child: Text("Excluded: ${excludedCompanies.join(', ')}", style: const TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              _bulletPoint("Parties: ${partySelectionType == "All" ? "${selectedPartyIds.length} Active" : selectedParty}"),
              if (partySelectionType == "All" && excludedParties.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 14, bottom: 4),
                  child: Text("Excluded: ${excludedParties.join(', ')}", style: const TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              _bulletPoint("Deductions Applied: ${deductCN ? 'CN (Sales)' : 'None'} ${deductDN ? '& DN (Purchases)' : ''}"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                setState(() {
                  currentStep = ReportStep.selectionForm;
                });
              },
              child: const Text("GO BACK", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: accentElectric, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(c);
                setState(() {
                  currentStep = ReportStep.showReportGrid;
                });
              },
              child: const Text("VIEW STATEMENT", style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: accentElectric),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

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
              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 1),
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
          Text(ph.activeCompany?.name ?? "DWARIKA MEDICALS", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: brandDark, letterSpacing: 1)),
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
              style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: brandDark),
            ),
          )
        ],
      ),
    );
  }

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
                          Text("STATEMENT CONFIGURATION", style: TextStyle(color: Color(0xFF818CF8), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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
                          child: const Text("GENERATE AUDIT STATEMENT", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
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

  Widget _buildGatewayTrigger(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: brandDark)),
              ],
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: brandDark, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchPickerTrigger(String title, String currentSelection, ValueChanged<String> onSelected, List<String> items) {
    return InkWell(
      onTap: () => _openSearchableSinglePicker(title, items, currentSelection, onSelected),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(10), color: const Color(0xFFF8FAFC)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Tap to Search...", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            Row(children: [
              Text(currentSelection, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: brandDark)),
              const SizedBox(width: 5),
              const Icon(Icons.search_rounded, color: brandDark, size: 18),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelectorTile() {
    return InkWell(
      onTap: _pickDateRangeWithinFY,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(10), color: const Color(0xFFF8FAFC)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("SELECTED CALENDAR WINDOW", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                "${_formatDate(fyDateRange.start)}  to  ${_formatDate(fyDateRange.end)}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: brandDark),
              )
            ]),
            const Icon(Icons.calendar_month_rounded, color: brandDark, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool val, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(fontSize: 8, color: Colors.grey)),
              ],
            ),
          ),
          Switch(
            value: val,
            onChanged: onChanged,
            activeColor: accentElectric,
          )
        ],
      ),
    );
  }

  Widget _buildSimpleDropdown({
    required String value,
    required List<String> items,
    required void Function(String?)? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          items: items.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

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
