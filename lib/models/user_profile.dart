import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String? name;
  final int? age;
  final String? gender;
  final double? weight;
  final String? favoriteStyle;
  final String? profileImageUrl;
  final int totalSessions;
  final double totalDistance;
  final int totalHours;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // ✅ Pro User Fields
  final bool isPro;
  final DateTime? proExpiryDate;
  final String? subscriptionType; // 'monthly', 'yearly', 'lifetime'
  final String? paymentMethod;

  UserProfile({
    this.name,
    this.age,
    this.gender,
    this.weight,
    this.favoriteStyle,
    this.profileImageUrl,
    this.totalSessions = 0,
    this.totalDistance = 0.0,
    this.totalHours = 0,
    this.createdAt,
    this.updatedAt,
    this.isPro = false,
    this.proExpiryDate,
    this.subscriptionType,
    this.paymentMethod,
  });

  // ✅ Check if pro is active
  bool get isProActive {
    if (!isPro) return false;
    if (subscriptionType == 'lifetime') return true;
    if (proExpiryDate == null) return false;
    return proExpiryDate!.isAfter(DateTime.now());
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'gender': gender,
      'weight': weight,
      'favoriteStyle': favoriteStyle,
      'profileImageUrl': profileImageUrl,
      'totalSessions': totalSessions,
      'totalDistance': totalDistance,
      'totalHours': totalHours,
      'createdAt': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'isPro': isPro,
      'proExpiryDate': proExpiryDate?.toIso8601String(),
      'subscriptionType': subscriptionType,
      'paymentMethod': paymentMethod,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'],
      age: map['age'],
      gender: map['gender'],
      weight: map['weight']?.toDouble(),
      favoriteStyle: map['favoriteStyle'],
      profileImageUrl: map['profileImageUrl'],
      totalSessions: map['totalSessions'] ?? 0,
      totalDistance: map['totalDistance']?.toDouble() ?? 0.0,
      totalHours: map['totalHours'] ?? 0,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
      isPro: map['isPro'] ?? false,
      proExpiryDate: map['proExpiryDate'] != null ? DateTime.parse(map['proExpiryDate']) : null,
      subscriptionType: map['subscriptionType'],
      paymentMethod: map['paymentMethod'],
    );
  }

  UserProfile copyWith({
    String? name,
    int? age,
    String? gender,
    double? weight,
    String? favoriteStyle,
    String? profileImageUrl,
    int? totalSessions,
    double? totalDistance,
    int? totalHours,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPro,
    DateTime? proExpiryDate,
    String? subscriptionType,
    String? paymentMethod,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      weight: weight ?? this.weight,
      favoriteStyle: favoriteStyle ?? this.favoriteStyle,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      totalSessions: totalSessions ?? this.totalSessions,
      totalDistance: totalDistance ?? this.totalDistance,
      totalHours: totalHours ?? this.totalHours,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPro: isPro ?? this.isPro,
      proExpiryDate: proExpiryDate ?? this.proExpiryDate,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}