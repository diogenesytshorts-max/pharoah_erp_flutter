import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Note: Abhi errors aa sakte hain kyunki baaki files nahi bani hain
// Par hum ek-ek karke sab bana lenge.

void main() {
  runApp(
    // Provider humein data manage karne mein madad karega
    MultiProvider(
      providers: [
        // ChangeNotifierProvider(create: (_) => PharoahManager()), 
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
      ),
      home: const Scaffold(
        body: Center(child: Text("Welcome to Pharoah ERP Flutter")),
      ),
    );
  }
}
