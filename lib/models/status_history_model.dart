import 'package:cloud_firestore/cloud_firestore.dart';

class StatusHistoryModel {
  final String status;
  final Timestamp timestamp;
  final String? imgOfStatus;

  StatusHistoryModel({
    required this.status,
    required this.timestamp,
    this.imgOfStatus,
  });

  factory StatusHistoryModel.fromMap(Map<String, dynamic> map) {
    return StatusHistoryModel(
      status: map['status'] ?? 'unknown',
      timestamp: map['timestamp'] ?? Timestamp.now(),
      imgOfStatus: map['imgOfStatus'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'timestamp': timestamp,
      'imgOfStatus': imgOfStatus,
    };
  }
}
