import 'package:cloud_firestore/cloud_firestore.dart';

class AddressModel {
  final String detail;
  final GeoPoint gps;
  final String? recipientName;
  final String? recipientPhone;

  AddressModel({
    required this.detail,
    required this.gps,
    this.recipientName,
    this.recipientPhone,
  });
  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      detail: map['detail'] ?? 'ไม่มีข้อมูลที่อยู่',
      gps: map['gps'] ?? const GeoPoint(0, 0),
      recipientName: map['recipientName'],
      recipientPhone: map['recipientPhone'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'detail': detail,
      'gps': gps,
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
    };
  }
}
