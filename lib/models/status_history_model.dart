// file: models/status_history_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class StatusHistoryModel {
  final String status;
  final Timestamp timestamp;

  StatusHistoryModel({
    required this.status,
    required this.timestamp,
  });

  // แปลงจาก Map ที่อยู่ใน List ของ Order document
  factory StatusHistoryModel.fromMap(Map<String, dynamic> map) {
    return StatusHistoryModel(
      status: map['status'] ?? 'unknown',
      timestamp: map['timestamp'] ?? Timestamp.now(),
    );
  }

  // แปลงกลับเป็น Map เพื่อบันทึก
  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'timestamp': timestamp,
    };
  }
}
