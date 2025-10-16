// file: models/address_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AddressModel {
  final String detail;
  final GeoPoint gps;

  AddressModel({
    required this.detail,
    required this.gps,
  });

  // แปลงจาก Map ที่อยู่ใน Order document
  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      detail: map['detail'] ?? 'ไม่มีข้อมูลที่อยู่',
      gps: map['gps'] ?? const GeoPoint(0, 0),
    );
  }

  // แปลงกลับเป็น Map เพื่อบันทึก
  Map<String, dynamic> toMap() {
    return {
      'detail': detail,
      'gps': gps,
    };
  }
}
