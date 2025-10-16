// file: user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String phone;
  final String profileUrl; // เปลี่ยนชื่อให้ชัดเจนว่าเป็น URL
  final String fullname;

  // ที่อยู่ของลูกค้า
  final String? defaultAddress;
  final GeoPoint? defaultGPS;
  final String? secondAddress;
  final GeoPoint? secondGPS;

  UserModel({
    required this.uid,
    required this.phone,
    required this.profileUrl,
    required this.fullname,
    this.defaultAddress,
    this.defaultGPS,
    this.secondAddress,
    this.secondGPS,
  });

  // แปลงจาก Firestore Document เป็น Object
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] ?? '',
      phone: data['phone'] ?? '',
      profileUrl: data['profileUrl'] ?? '',
      fullname: data['fullname'] ?? '',
      defaultAddress: data['defaultAddress'],
      defaultGPS: data['defaultGPS'],
      secondAddress: data['secondAddress'],
      secondGPS: data['secondGPS'],
    );
  }

  // แปลงจาก Object เป็น Map เพื่อบันทึกลง Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phone': phone,
      'profileUrl': profileUrl,
      'fullname': fullname,
      'defaultAddress': defaultAddress,
      'defaultGPS': defaultGPS,
      'secondAddress': secondAddress,
      'secondGPS': secondGPS,
    };
  }
}
