import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final int role;
  final String phone;
  final String profile;
  final String fullname;

  // For role 0 (User)
  final String? defaultAddress;
  final GeoPoint? defaultGPS;
  final String? secondAddress;
  final GeoPoint? secondGPS;

  // For role 1 (Rider)
  final String? vehicleNo;
  final String? vehiclePicture;
  final GeoPoint? gps;

  UserModel({
    required this.uid,
    required this.role,
    required this.phone,
    required this.profile,
    required this.fullname,
    this.defaultAddress,
    this.defaultGPS,
    this.secondAddress,
    this.secondGPS,
    this.vehicleNo,
    this.vehiclePicture,
    this.gps,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] ?? '',
      role: data['role'] ?? 0,
      phone: data['phone'] ?? '',
      profile: data['profile'] ?? '',
      fullname: data['fullname'] ?? '',
      defaultAddress: data['defaultAddress'],
      defaultGPS: data['defaultGPS'],
      secondAddress: data['secondAddress'],
      secondGPS: data['secondGPS'],
      // ❗️ FIXED: แก้ไข Key ให้ตรงกับใน Firestore
      vehicleNo: data['vehicle_no'],
      vehiclePicture: data['vehicle_picture'],
      gps: data['gps'],
    );
  }
}
