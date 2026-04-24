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

  Future<void> exportEntireCompany(CompanyProfile comp) async {
    try {
      final root = await getApplicationDocumentsDirectory();
      final companyPath = '${root.path}/Pharoah_Data/${comp.id}';
      final companyDir = Directory(companyPath);
      if (!await companyDir.exists()) return;

      Map<String, dynamic> exportBundle = {
        "app_name": "PHAROAH_ERP",
        "profile": comp.toMap(),
        "data_payload": {}
      };

      List<FileSystemEntity> typeFolders = companyDir.listSync();
      for (var typeFolder in typeFolders) {
        if (typeFolder is Directory) {
          String typeName = typeFolder.path.split(Platform.pathSeparator).last;
          exportBundle["data_payload"][typeName] = {};
          List<FileSystemEntity> fyFolders = typeFolder.listSync();
          for (var fyFolder in fyFolders) {
            if (fyFolder is Directory) {
              String fyName = fyFolder.path.split(Platform.pathSeparator).last;
              exportBundle["data_payload"][typeName][fyName] = {};
              List<FileSystemEntity> files = fyFolder.listSync();
              for (var file in files) {
                if (file is File && file.path.endsWith('.json')) {
                  String fileName = file.path.split(Platform.pathSeparator).last.replaceAll('.json', '');
                  exportBundle["data_payload"][typeName][fyName][fileName] = jsonDecode(await file.readAsString());
                }
              }
            }
          }
        }
      }
      final tempDir = await getTemporaryDirectory();
      final exportFile = File('${tempDir.path}/${comp.name.replaceAll(' ', '_')}.pharoah');
      await exportFile.writeAsString(jsonEncode(exportBundle));
      await Share.shareXFiles([XFile(exportFile.path)], subject: 'Backup: ${comp.name}');
    } catch (e) { print("Export Error: $e"); }
  }

  Future<bool> importCompany() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result == null) return false;
      File file = File(result.files.single.path!);
      Map<String, dynamic> bundle = jsonDecode(await file.readAsString());
      if (bundle['app_name'] != "PHAROAH_ERP") return false;

      CompanyProfile profile = CompanyProfile.fromMap(bundle['profile']);
      Map<String, dynamic> payload = bundle['data_payload'];
      final root = await getApplicationDocumentsDirectory();

      for (var type in payload.keys) {
        for (var fy in payload[type].keys) {
          final target = '${root.path}/Pharoah_Data/${profile.id}/$type/$fy';
          await Directory(target).create(recursive: true);
          Map<String, dynamic> files = payload[type][fy];
          for (var name in files.keys) {
            await File('$target/$name.json').writeAsString(jsonEncode(files[name]));
          }
        }
      }
      if (!ph.companiesRegistry.any((c) => c.id == profile.id)) {
        ph.companiesRegistry.add(profile);
        await ph.saveRegistry();
      }
      return true;
    } catch (e) { return false; }
  }
}
