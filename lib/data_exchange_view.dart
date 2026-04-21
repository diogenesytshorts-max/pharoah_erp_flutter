import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'csv_mapping_view.dart'; // Naya View hum agle step me denge
import 'export_selector_view.dart';

class DataExchangeView extends StatefulWidget {
  const DataExchangeView({super.key});

  @override
  State<DataExchangeView> createState() => _DataExchangeViewState();
}

class _DataExchangeViewState extends State<DataExchangeView> {
  bool isLoading = false;

  // --- FILE PICKER LOGIC ---
  Future<void> _pickAndProcessFile(String type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => isLoading = true);
      
      try {
        final input = File(result.files.single.path!).openRead();
        final fields = await input
            .transform(utf8.decoder)
            .transform(const CsvToListConverter())
            .toList();

        if (fields.isEmpty) throw "File is empty";

        if (mounted) {
          // File pick hone ke baad seedha Mapping Screen par le jana
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (c) => CsvMappingView(
                csvData: fields,
                importType: type,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error reading file: $e"), backgroundColor: Colors.red),
          );
        }
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Data Hub & CSV Sync"),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoCard(),
                const SizedBox(height: 25),
                
                const Text("IMPORT DATA (STOCK-IN)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 10),
                _actionTile(
                  "Import Purchase Bills", 
                  "Distributor ki CSV file se stock charhayein", 
                  Icons.download_for_offline_rounded, 
                  Colors.orange.shade800,
                  () => _pickAndProcessFile("PURCHASE")
                ),

                const SizedBox(height: 25),

                const Text("EXPORT DATA", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 10),
                _actionTile(
                  "Export Sales Data", 
                  "Apne sale bills ko CSV me download karein", 
                  Icons.upload_file_rounded, 
                  Colors.blue.shade800,
                  () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ExportSelectorView(exportType: "SALE")))
                ),
                const SizedBox(height: 10),
                _actionTile(
                  "Export Purchase Data", 
                  "Kharidari ka poora data excel me lein", 
                  Icons.inventory_2_rounded, 
                  Colors.brown,
                  () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ExportSelectorView(exportType: "PURCHASE")))
                ),
              ],
            ),
          ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome, color: Colors.teal, size: 40),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Smart CSV Import", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("Ab aap kisi bhi format ki file ko map karke import kar sakte hain.", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _actionTile(String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.black12)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }
}
