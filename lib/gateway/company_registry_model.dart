import 'dart:convert';

class CompanyProfile {
  final String id;           // Unique Locked ID (e.g. PH-C-821405)
  final String name;         // Shop Name
  final String businessType; // WHOLESALE or RETAIL
  final String password;     // Security Password
  final List<String> fYears; // Financial Years List (e.g. ["2025-26"])
  final DateTime createdAt;

  CompanyProfile({
    required this.id,
    required this.name,
    required this.businessType,
    required this.password,
    this.fYears = const [],
    required this.createdAt,
  });

  // Data ko file mein save karne ke liye (Map mein badalna)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'businessType': businessType,
      'password': password,
      'fYears': fYears,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Saved file se data wapas nikalne ke liye
  factory CompanyProfile.fromMap(Map<String, dynamic> map) {
    return CompanyProfile(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      businessType: map['businessType'] ?? 'WHOLESALE',
      password: map['password'] ?? '',
      fYears: List<String>.from(map['fYears'] ?? []),
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
