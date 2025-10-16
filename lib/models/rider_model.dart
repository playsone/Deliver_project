// file: rider_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class RiderModel {
  final String uid;
  final String phone;
  final String profileUrl;
  final String fullname;
  final bool isOnline; // เพิ่มสถานะออนไลน์

  // ข้อมูลยานพาหนะ
  final String vehicleNo;
  final String vehiclePictureUrl;

  // ตำแหน่งล่าสุดของไรเดอร์
  final GeoPoint? currentLocation;

  RiderModel({
    required this.uid,
    required this.phone,
    required this.profileUrl,
    required this.fullname,
    required this.isOnline,
    required this.vehicleNo,
    required this.vehiclePictureUrl,
    this.currentLocation,
  });

  // แปลงจาก Firestore Document เป็น Object
  factory RiderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RiderModel(
      uid: data['uid'] ?? '',
      phone: data['phone'] ?? '',
      profileUrl: data['profileUrl'] ?? '',
      fullname: data['fullname'] ?? '',
      isOnline: data['isOnline'] ?? false,
      vehicleNo: data['vehicleNo'] ?? '',
      vehiclePictureUrl: data['vehiclePictureUrl'] ?? '',
      currentLocation: data['currentLocation'],
    );
  }

  // แปลงจาก Object เป็น Map เพื่อบันทึกลง Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phone': phone,
      'profileUrl': profileUrl,
      'fullname': fullname,
      'isOnline': isOnline,
      'vehicleNo': vehicleNo,
      'vehiclePictureUrl': vehiclePictureUrl,
      'currentLocation': currentLocation,
    };
  }
}
