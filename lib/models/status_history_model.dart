// file: lib/models/status_history_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class StatusHistoryModel {
  final String status;
  final Timestamp timestamp;
  final String? imageUrl; // << เพิ่ม: ลิงก์รูปภาพสำหรับสถานะนี้ (อาจไม่มีก็ได้)

  StatusHistoryModel({
    required this.status,
    required this.timestamp,
    this.imageUrl, // << เพิ่มใน constructor
  });

  // แปลงจาก Map ที่อยู่ใน Firestore
  factory StatusHistoryModel.fromMap(Map<String, dynamic> map) {
    return StatusHistoryModel(
      status: map['status'] ?? 'unknown',
      timestamp: map['timestamp'] ?? Timestamp.now(),
      imageUrl: map['imageUrl'], // << ดึงข้อมูล imageUrl จาก Map
    );
  }

  // แปลงกลับเป็น Map เพื่อบันทึก
  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'timestamp': timestamp,
      'imageUrl': imageUrl, // << เพิ่ม imageUrl ตอนบันทึก
    };
  }
}
