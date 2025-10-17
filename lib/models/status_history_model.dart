// file: lib/models/status_history_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class StatusHistoryModel {
  final String status;
  final Timestamp timestamp;
  final String? imgOfStatus; // << แก้ไข: เปลี่ยนจาก imageUrl เป็น imgOfStatus

  StatusHistoryModel({
    required this.status,
    required this.timestamp,
    this.imgOfStatus, // << แก้ไข: เปลี่ยนใน constructor
  });

  // แปลงจาก Map ที่อยู่ใน Firestore
  factory StatusHistoryModel.fromMap(Map<String, dynamic> map) {
    return StatusHistoryModel(
      status: map['status'] ?? 'unknown',
      timestamp: map['timestamp'] ?? Timestamp.now(),
      imgOfStatus:
          map['imgOfStatus'], // << แก้ไข: ดึงข้อมูลจาก field ที่ถูกต้อง
    );
  }

  // แปลงกลับเป็น Map เพื่อบันทึก
  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'timestamp': timestamp,
      'imgOfStatus': imgOfStatus, // << แก้ไข: ใช้ชื่อ field ที่ถูกต้องตอนบันทึก
    };
  }
}
