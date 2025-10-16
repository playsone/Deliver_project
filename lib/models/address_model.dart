// file: lib/models/address_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class AddressModel {
  final String detail; // รายละเอียดที่อยู่ เช่น บ้านเลขที่, ถนน
  final GeoPoint gps; // พิกัด GPS
  final String? recipientName; // << เพิ่ม: ชื่อผู้รับ
  final String? recipientPhone; // << เพิ่ม: เบอร์โทรผู้รับ

  AddressModel({
    required this.detail,
    required this.gps,
    this.recipientName,
    this.recipientPhone,
  });

  // Factory constructor สำหรับแปลงข้อมูลจาก Firestore's Map
  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      detail: map['detail'] ?? 'ไม่มีข้อมูลที่อยู่',
      gps: map['gps'] ?? const GeoPoint(0, 0),
      recipientName: map['recipientName'], // << เพิ่ม
      recipientPhone: map['recipientPhone'], // << เพิ่ม
    );
  }

  // Method สำหรับแปลง Object กลับเป็น Map เพื่อบันทึกลง Firestore
  Map<String, dynamic> toMap() {
    return {
      'detail': detail,
      'gps': gps,
      'recipientName': recipientName, // << เพิ่ม
      'recipientPhone': recipientPhone, // << เพิ่ม
    };
  }
}
