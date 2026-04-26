// FILE: lib/administration/system_user_model.dart (Replace Full)

import 'dart:convert';

class SystemUser {
  String id, name, username, password;
  
  // --- PERMISSIONS ---
  bool canDeleteBill;
  bool canEditBill;         // NAYA
  bool canViewPurchaseRate; 
  bool canViewFinance;      
  bool canExportData;       

  SystemUser({
    required this.id, required this.name, required this.username, required this.password,
    this.canDeleteBill = false,
    this.canEditBill = false,         // DEFAULT OFF
    this.canViewPurchaseRate = false,
    this.canViewFinance = false,
    this.canExportData = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id, 'name': name, 'username': username, 'password': password,
      'canDeleteBill': canDeleteBill, 'canEditBill': canEditBill,
      'canViewPurchaseRate': canViewPurchaseRate, 'canViewFinance': canViewFinance,
      'canExportData': canExportData,
    };
  }

  factory SystemUser.fromMap(Map<String, dynamic> map) {
    return SystemUser(
      id: map['id'] ?? '', name: map['name'] ?? '', username: map['username'] ?? '', password: map['password'] ?? '',
      canDeleteBill: map['canDeleteBill'] ?? false,
      canEditBill: map['canEditBill'] ?? false,
      canViewPurchaseRate: map['canViewPurchaseRate'] ?? false,
      canViewFinance: map['canViewFinance'] ?? false,
      canExportData: map['canExportData'] ?? false,
    );
  }
}
