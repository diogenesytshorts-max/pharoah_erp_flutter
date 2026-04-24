// FILE: lib/gateway/company_registry_model.dart

import 'dart:convert';

class CompanyProfile {
  // --- Core Identity ---
  final String id;           // Unique Locked ID (e.g. PH-C-821405)
  final String name;         // Shop Name
  final String businessType; // WHOLESALE or RETAIL
  final DateTime createdAt;

  // --- Detailed Profile (Merged from SetupView) ---
  final String address;
  final String state;
  final String gstin;
  final String dlNo;
  final String phone;
  final String email;

  // --- Security & Access ---
  final String adminUser;    // Admin Username
  final String password;     // Admin/Company Password
  
  // --- System Context ---
  final List<String> fYears; // Financial Years List (e.g. ["2025-26"])

  CompanyProfile({
    required this.id,
    required this.name,
    required this.businessType,
    required this.createdAt,
    this.address = "",
    this.state = "Rajasthan",
    this.gstin = "N/A",
    this.dlNo = "N/A",
    this.phone = "",
    this.email = "",
    this.adminUser = "admin",
    required this.password,
    this.fYears = const [],
  });

  // Data ko JSON file mein save karne ke liye (Map mein badalna)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'businessType': businessType,
      'createdAt': createdAt.toIso8601String(),
      'address': address,
      'state': state,
      'gstin': gstin,
      'dlNo': dlNo,
      'phone': phone,
      'email': email,
      'adminUser': adminUser,
      'password': password,
      'fYears': fYears,
    };
  }

  // Saved JSON file se data wapas nikalne ke liye
  factory CompanyProfile.fromMap(Map<String, dynamic> map) {
    return CompanyProfile(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      businessType: map['businessType'] ?? 'WHOLESALE',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      address: map['address'] ?? '',
      state: map['state'] ?? 'Rajasthan',
      gstin: map['gstin'] ?? 'N/A',
      dlNo: map['dlNo'] ?? 'N/A',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      adminUser: map['adminUser'] ?? 'admin',
      password: map['password'] ?? '',
      fYears: List<String>.from(map['fYears'] ?? []),
    );
  }
}
