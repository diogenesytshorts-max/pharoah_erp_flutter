// FILE: lib/pdf/pdf_master_service.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../gateway/company_registry_model.dart';

class PdfMasterService {
  
  // --- 1. GLOBAL SHOP HEADER (Change here once, updates everywhere) ---
  static pw.Widget buildShopHeader(CompanyProfile shop, String docTitle, String billNo, DateTime date, {String? internalNo}) {
    return pw.Row(
      children: [
        // LEFT: Shop Identity
        _headerBox(width: 280, child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.Text(shop.address, style: const pw.TextStyle(fontSize: 8)),
            pw.Text("Phone: ${shop.phone} | GSTIN: ${shop.gstin}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            if (shop.dlNo != "N/A") pw.Text("D.L.No.: ${shop.dlNo}", style: const pw.TextStyle(fontSize: 7.5)),
          ],
        )),

        // CENTER: Document Info
        _headerBox(width: 170, child: pw.Column(
          children: [
            pw.Text(docTitle.toUpperCase(), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.Divider(thickness: 0.5),
            pw.Text("No: $billNo", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
            if (internalNo != null) pw.Text("ID: $internalNo", style: const pw.TextStyle(fontSize: 7.5)),
            pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(date)}", style: pw.TextStyle(fontSize: 8.5)),
          ],
        )),
      ],
    );
  }

  // --- 2. COMMON UI HELPERS ---
  static pw.Widget _headerBox({required double width, required pw.Widget child}) {
    return pw.Container(
      width: width, 
      height: 80, 
      padding: const pw.EdgeInsets.all(4), 
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), 
      child: child
    );
  }

  static pw.Widget tableHeaderCol(String text, double width, {pw.Alignment align = pw.Alignment.center}) {
    return pw.Container(
      width: width, height: 18, alignment: align, 
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5), color: PdfColors.grey100), 
      child: pw.Text(text, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))
    );
  }

  static pw.Widget tableCell(String text, double width, {pw.Alignment align = pw.Alignment.center}) {
    return pw.Container(
      width: width, 
      padding: const pw.EdgeInsets.symmetric(vertical: 2), 
      alignment: align, 
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 7.5))
    );
  }

  // --- 3. LOGIC HELPERS ---
  static String numberToWords(int amount) {
    if (amount == 0) return "ZERO";
    var units = ["", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE", "TEN", "ELEVEN", "TWELVE", "THIRTEEN", "FOURTEEN", "FIFTEEN", "SIXTEEN", "SEVENTEEN", "EIGHTEEN", "NINETEEN"];
    var tens = ["", "", "TWENTY", "THIRTY", "FORTY", "FIFTY", "SIXTY", "SEVENTY", "EIGHTY", "NINETY"];
    if (amount < 20) return units[amount];
    if (amount < 100) return tens[(amount / 10).floor()] + (amount % 10 != 0 ? " " + units[amount % 10] : "");
    if (amount < 1000) return units[(amount / 100).floor()] + " HUNDRED" + (amount % 100 != 0 ? " AND " + numberToWords(amount % 100) : "");
    if (amount < 100000) return numberToWords((amount / 1000).floor()) + " THOUSAND" + (amount % 1000 != 0 ? " " + numberToWords(amount % 1000) : "");
    if (amount < 10000000) return numberToWords((amount / 100000).floor()) + " LAKH" + (amount % 100000 != 0 ? " " + numberToWords(amount % 100000) : "");
    return amount.toString();
  }
}
