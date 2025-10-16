// file: models/rider_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class RiderModel {
  final String uid;
  final String phone;
  final String? profileUrl; // อาจเป็นค่าว่างได้
  final String fullname;
  final bool isOnline;

  // ข้อมูลยานพาหนะ
  final String vehicleNo;
  final String? vehiclePictureUrl; // อาจเป็นค่าว่างได้

  // ตำแหน่งล่าสุดของไรเดอร์
  final GeoPoint? currentLocation;

  RiderModel({
    required this.uid,
    required this.phone,
    this.profileUrl,
    required this.fullname,
    required this.isOnline,
    required this.vehicleNo,
    this.vehiclePictureUrl,
    this.currentLocation,
  });

  // **ส่วนที่แก้ไข:** เปลี่ยนชื่อ field ให้ตรงกับ Firestore
  factory RiderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RiderModel(
      uid: data['uid'] ?? '',
      phone: data['phone'] ?? '',
      profileUrl: data['profile'], // แก้จาก profileUrl
      fullname: data['fullname'] ?? 'ไม่มีชื่อ',
      isOnline: data['isOnline'] ?? false,
      vehicleNo: data['vehicle_no'] ?? '', // แก้จาก vehicleNo
      vehiclePictureUrl: data['vehicle_picture'], // แก้จาก vehiclePictureUrl
      currentLocation: data['gps'], // แก้จาก currentLocation
    );
  }

  // แปลงจาก Object เป็น Map (ส่วนนี้มีไว้เผื่ออนาคต ไม่ต้องแก้ไข)
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phone': phone,
      'profile': profileUrl,
      'fullname': fullname,
      'isOnline': isOnline,
      'vehicle_no': vehicleNo,
      'vehicle_picture': vehiclePictureUrl,
      'gps': currentLocation,
    };
  }
}
