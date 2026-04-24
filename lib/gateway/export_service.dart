import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../pharoah_manager.dart';
import 'company_registry_model.dart';

class ExportService {
  final PharoahManager ph;
  ExportService(this.ph);

  // ===========================================================================
  // 1. EXPORT FULL COMPANY (SAB KUCH EK FILE MEIN)
  // ===========================================================================
  Future<void> exportEntireCompany(CompanyProfile comp) async {
    try {
      final root = await getApplicationDocumentsDirectory();
      final companyPath = '${root.path}/Pharoah_Data/${comp.id}';
      final companyDir = Directory(companyPath);

      if (!await companyDir.exists()) return;

      Map<String, dynamic> exportBundle = {
        "profile": comp.toMap(),
        "data": {} // Isme saare FY folders ka data aayega
      };

      // Har Financial Year folder ko scan karna
      List<FileSystemEntity> typeFolders = companyDir.listSync();
      for (var typeFolder in typeFolders) {
        if (typeFolder is Directory) {
          String typeName = typeFolder.path.split('/').last; // WHOLESALE
          exportBundle["data"][typeName] = {};

          List<FileSystemEntity> fyFolders = typeFolder.listSync();
          for (var fyFolder in fyFolders) {
            if (fyFolder is Directory) {
              String fyName = fyFolder.path.split('/').last; // 2025-26
              exportBundle["data"][typeName][fyName] = {};

              // Saari JSON files read karna
              List<FileSystemEntity> files = fyFolder.listSync();
              for (var file in files) {
                if (file is File && file.path.endsWith('.json')) {
                  String fileName = file.path.split('/').last.replaceAll('.json', '');
                  exportBundle["data"][typeName][fyName][fileName] = jsonDecode(await file.readAsString());
                }
              }
            }
          }
        }
      }

      // File mein save karke share karna
      final tempDir = await getTemporaryDirectory();
      final exportFile = File('${tempDir.path}/${comp.name.replaceAll(' ', '_')}_Backup.pharoah');
      await exportFile.writeAsString(jsonEncode(exportBundle));

      await Share.shareXFiles([XFile(exportFile.path)], subject: '${comp.name} Full Export');
    } catch (e) {
      print("Export Error: $e");
    }
  }

  // ===========================================================================
  // 2. IMPORT COMPANY (WAPAS LAANA)
  // ===========================================================================
  Future<bool> importCompany() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result == null) return false;

      File file = File(result.files.single.path!);
      Map<String, dynamic> bundle = jsonDecode(await file.readAsString());

      CompanyProfile importedProfile = CompanyProfile.fromMap(bundle['profile']);
      Map<String, dynamic> allData = bundle['data'];

      final root = await getApplicationDocumentsDirectory();

      // Folder structure dobara banana
      for (var type in allData.keys) {
        for (var fy in allData[type].keys) {
          final path = '${root.path}/Pharoah_Data/${importedProfile.id}/$type/$fy';
          await Directory(path).create(recursive: true);

          Map<String, dynamic> files = allData[type][fy];
          for (var fileName in files.keys) {
            final f = File('$path/$fileName.json');
            await f.writeAsString(jsonEncode(files[fileName]));
          }
        }
      }

      // Registry mein update karna
      if (!ph.companiesRegistry.any((c) => c.id == importedProfile.id)) {
        ph.companiesRegistry.add(importedProfile);
        await ph.saveRegistry();
      }
      return true;
    } catch (e) {
      print("Import Error: $e");
      return false;
    }
  }
}
