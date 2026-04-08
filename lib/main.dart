import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
// Note: Dashboard wali file hum agle step mein banayenge
// Isliye abhi 'home' mein ek temporary screen rakhenge.

void main() {
  runApp(
    MultiProvider(
      providers: [
        // Yeh line manager ko initialize karti hai
        ChangeNotifierProvider(create: (_) => PharoahManager()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pharoah ERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        // Fonts ko saaf dikhane ke liye
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black87),
        ),
      ),
      home: const InitialCheckScreen(),
    );
  }
}

// Ek temporary screen jab tak Dashboard nahi banta
class InitialCheckScreen extends StatelessWidget {
  const InitialCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Data check karne ke liye manager ko access karein
    final ph = Provider.of<PharoahManager>(context);
    
    return Scaffold(
      appBar: AppBar(title: const Text("Pharoah ERP Flutter")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            Text("System Ready!", style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 10),
            Text("Parties Loaded: ${ph.parties.length}"),
            Text("Medicines Loaded: ${ph.medicines.length}"),
            const SizedBox(height: 30),
            const Text("Next Step: Creating Dashboard...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
