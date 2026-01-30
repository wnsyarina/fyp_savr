import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

import 'package:flutter/widgets.dart';

class RestaurantModel {
  final String merchantId;
  final String name;
  final String description;
  final String address;
  final String phone;
  final List<String> cuisineTypes;
  final double rating;
  final int totalReviews;
  final String deliveryTime;
  final String? logoBase64;
  final String? coverImageBase64;
  final GeoPoint location;
  final bool isActive;
  final bool isVerified;
  final String verificationStatus;
  final List<String> searchKeywords;
  final Map<String, String> openingHours;
  final bool isOpen;
  final Map<String, dynamic>? documents;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? verifiedBy;
  final String? verifiedByName;
  final DateTime? verifiedAt;
  final String? adminNotes;

  RestaurantModel({
    required this.merchantId,
    required this.name,
    required this.description,
    required this.address,
    required this.phone,
    required this.cuisineTypes,
    required this.rating,
    required this.totalReviews,
    required this.deliveryTime,
    this.logoBase64,
    this.coverImageBase64,
    required this.location,
    required this.isActive,
    required this.isVerified,
    required this.verificationStatus,
    required this.searchKeywords,
    required this.openingHours,
    required this.isOpen,
    this.documents,
    required this.createdAt,
    required this.updatedAt,
    this.verifiedBy,
    this.verifiedByName,
    this.verifiedAt,
    this.adminNotes,
  });

  factory RestaurantModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    Map<String, dynamic>? documents;
    if (data['documents'] != null) {
      documents = Map<String, dynamic>.from(data['documents']);
    }

    Map<String, String> openingHours = {};
    if (data['openingHours'] != null) {
      openingHours = Map<String, String>.from(data['openingHours']);
    }

    return RestaurantModel(
      merchantId: data['merchantId'] ?? doc.id,
      name: data['name'] ?? 'Unknown Restaurant',
      description: data['description'] ?? '',
      address: data['address'] ?? '',
      phone: data['phone'] ?? '',
      cuisineTypes: List<String>.from(data['cuisineTypes'] ?? []),
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalReviews: data['totalReviews'] ?? 0,
      deliveryTime: data['deliveryTime'] ?? '20-30 min',
      logoBase64: data['logoBase64'],
      coverImageBase64: data['coverImageBase64'],
      location: data['location'] ?? const GeoPoint(0, 0),
      isActive: data['isActive'] ?? false,
      isVerified: data['isVerified'] ?? false,
      verificationStatus: data['verificationStatus'] ?? 'pending',
      searchKeywords: List<String>.from(data['searchKeywords'] ?? []),
      openingHours: openingHours,
      isOpen: data['isOpen'] ?? false,
      documents: documents,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      verifiedBy: data['verifiedBy'],
      verifiedByName: data['verifiedByName'],
      verifiedAt: data['verifiedAt'] != null ? (data['verifiedAt'] as Timestamp).toDate() : null,
      adminNotes: data['adminNotes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'merchantId': merchantId,
      'name': name,
      'description': description,
      'address': address,
      'phone': phone,
      'cuisineTypes': cuisineTypes,
      'rating': rating,
      'totalReviews': totalReviews,
      'deliveryTime': deliveryTime,
      'logoBase64': logoBase64,
      'coverImageBase64': coverImageBase64,
      'location': location,
      'isActive': isActive,
      'isVerified': isVerified,
      'verificationStatus': verificationStatus,
      'searchKeywords': searchKeywords,
      'openingHours': openingHours,
      'isOpen': isOpen,
      'documents': documents,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'verifiedBy': verifiedBy,
      'verifiedByName': verifiedByName,
      'verifiedAt': verifiedAt,
      'adminNotes': adminNotes,
    };
  }

  // helper methods
  bool get isPendingVerification => verificationStatus == 'pending';
  bool get isApproved => verificationStatus == 'approved';
  bool get isRejected => verificationStatus == 'rejected';

  Image? get logoImage {
    if (logoBase64 != null && logoBase64!.isNotEmpty) {
      return Image.memory(
        base64Decode(logoBase64!),
        fit: BoxFit.cover,
      );
    }
    return null;
  }

  Image? get coverImage {
    if (coverImageBase64 != null && coverImageBase64!.isNotEmpty) {
      return Image.memory(
        base64Decode(coverImageBase64!),
        fit: BoxFit.cover,
      );
    }
    return null;
  }

  Map<String, dynamic>? get documentUrls {
    if (documents != null && documents!['documents'] != null) {
      return Map<String, dynamic>.from(documents!['documents']);
    }
    return null;
  }

  String? get businessRegistrationUrl => documentUrls?['businessRegistration'];
  String? get ownerIdUrl => documentUrls?['ownerId'];
  String? get healthPermitUrl => documentUrls?['healthPermit'];
  String? get restaurantPhotoUrl => documentUrls?['restaurantPhoto'];

  double get latitude => location.latitude;
  double get longitude => location.longitude;

  String get formattedRating => rating.toStringAsFixed(1);
  String get reviewCountText => '$totalReviews ${totalReviews == 1 ? 'review' : 'reviews'}';

  RestaurantModel copyWith({
    String? name,
    String? description,
    String? address,
    String? phone,
    List<String>? cuisineTypes,
    double? rating,
    int? totalReviews,
    String? deliveryTime,
    String? logoBase64,
    String? coverImageBase64,
    GeoPoint? location,
    bool? isActive,
    bool? isVerified,
    String? verificationStatus,
    List<String>? searchKeywords,
    Map<String, String>? openingHours,
    bool? isOpen,
    Map<String, dynamic>? documents,
    DateTime? updatedAt,
    String? adminNotes,
  }) {
    return RestaurantModel(
      merchantId: merchantId,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      cuisineTypes: cuisineTypes ?? this.cuisineTypes,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      logoBase64: logoBase64 ?? this.logoBase64,
      coverImageBase64: coverImageBase64 ?? this.coverImageBase64,
      location: location ?? this.location,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      openingHours: openingHours ?? this.openingHours,
      isOpen: isOpen ?? this.isOpen,
      documents: documents ?? this.documents,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      verifiedBy: verifiedBy,
      verifiedByName: verifiedByName,
      verifiedAt: verifiedAt,
      adminNotes: adminNotes ?? this.adminNotes,
    );
  }

  @override
  String toString() {
    return 'RestaurantModel{name: $name, merchantId: $merchantId, rating: $rating, isActive: $isActive}';
  }
}