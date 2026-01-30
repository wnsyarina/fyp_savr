import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role;
  final DateTime createdAt;
  final bool isEmailVerified;
  final Map<String, dynamic>? preferences;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
    required this.isEmailVerified,
    this.preferences,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: data['role'] ?? 'customer',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isEmailVerified: data['isEmailVerified'] ?? false,
      preferences: data['preferences'] ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'createdAt': createdAt,
      'isEmailVerified': isEmailVerified,
      'preferences': preferences ?? {},
    };
  }

  bool get isSuperAdmin => role == 'super_admin';
  bool get isAdmin => role == 'admin' || isSuperAdmin;
  bool get isMerchant => role == 'merchant';
  bool get isCustomer => role == 'customer';
}