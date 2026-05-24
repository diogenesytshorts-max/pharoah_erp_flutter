// FILE: lib/logic/history_excel_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import '../models.dart';

class HistoryExcelService {
  static Future<void> export(List<Voucher> list, String shopName) async {
    List<List<dynamic>> rows = [];

    // Header Row
    rows.add([
      "DATE", "VOUCHER NO", "PARTY NAME", "TYPE", "MODE", 
      "CHQ/REF NO", "AMOUNT", "NARRATION", "STATUS"
    ]);

    for (var v in list) {
      bool isCan = v.narration.contains("CANCELLED");
      rows.add([
        DateFormat('dd/MM/yyyy').format(v.date),
        v.voucherNo,
        v.partyName,
        v.type,
        v.paymentMode,
        v.chequeNo,
        v.amount,
        v.narration,
        isCan ? "CANCELLED" : "ACTIVE"
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    Uint8List bytes = Uint8List.fromList(utf8.encode(csvData));
    
    await FileSaver.instance.saveAs(
      name: "History_${shopName}_${DateFormat('ddMM').format(DateTime.now())}",
      bytes: bytes,
      ext: "csv",
      mimeType: MimeType.csv
    );
  }
}
