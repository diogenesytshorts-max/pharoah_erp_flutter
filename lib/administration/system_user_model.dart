// FILE: lib/administration/system_user_model.dart

import 'dart:convert';

class SystemUser {
  String id;
  String name;
  String username;
  String password;
  
  // --- PERMISSIONS (Toggles) ---
  bool canDeleteBill;
  bool canViewPurchaseRate; // Margin/Profit dekhna
  bool canViewFinance;      // Ledger, Outstanding, Bank dekhna
  bool canExportData;       // PDF, CSV nikalna

  SystemUser({
    required this.id,
    required this.name,
    required this.username,
    required this.password,
    this.canDeleteBill = false,
    this.canViewPurchaseRate = false,
    this.canViewFinance = false,
    this.canExportData = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'password': password,
      'canDeleteBill': canDeleteBill,
      'canViewPurchaseRate': canViewPurchaseRate,
      'canViewFinance': canViewFinance,
      'canExportData': canExportData,
    };
  }

  factory SystemUser.fromMap(Map<String, dynamic> map) {
    return SystemUser(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      username: map['username'] ?? '',
      password: map['password'] ?? '',
      canDeleteBill: map['canDeleteBill'] ?? false,
      canViewPurchaseRate: map['canViewPurchaseRate'] ?? false,
      canViewFinance: map['canViewFinance'] ?? false,
      canExportData: map['canExportData'] ?? false,
    );
  }
}
