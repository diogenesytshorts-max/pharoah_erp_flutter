import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pharoah_manager.dart';
import 'dashboard_view.dart';
import 'setup_view.dart';
import 'login_view.dart';

void main() async {
  // Ensure Flutter engine is initialized before running app
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => PharoahManager(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isSetupDone = false;
  bool isLoggedIn = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  // Check if company setup is completed and handle app startup flow
  Future<void> _checkInitialState() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check 'isSetupDone' flag from persistent storage
    setState(() {
      isSetupDone = prefs.getBool('isSetupDone') ?? false;
      isLoading = false;
    });
  }

  // Callback to handle successful login
  void _onLoginSuccess() {
    setState(() {
      isLoggedIn = true;
    });
  }

  // Callback to handle logout
  void _onLogout() {
    setState(() {
      isLoggedIn = false;
    });
  }

  // Callback to handle setup completion
  void _onSetupComplete() {
    setState(() {
      isSetupDone = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show splash/loading while checking storage
    if (isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      key: UniqueKey(), // Forces fresh build on state change
      title: 'Pharoah ERP',
      debugShowCheckedModeBanner: false,
      
      // Professional Blue Theme Configuration
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1),
          primary: const Color(0xFF0D47A1),
          secondary: Colors.blueAccent,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      // --- CORE NAVIGATION LOGIC ---
      // 1. If Setup not done -> Show SetupView
      // 2. If Setup done but not Logged In -> Show LoginView
      // 3. If Setup done and Logged In -> Show DashboardView
      home: !isSetupDone 
          ? SetupView(onComplete: _onSetupComplete)
          : (!isLoggedIn 
              ? LoginView(onLogin: _onLoginSuccess) 
              : DashboardView(onLogout: _onLogout)),
    );
  }
}
