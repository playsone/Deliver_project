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

  factory AddressModel.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) {
      return AddressModel(
        detail: 'ไม่มีข้อมูลที่อยู่',
        gps: const GeoPoint(0, 0),
      );
    }

    GeoPoint gps = const GeoPoint(0, 0);
    final dynamic gpsData = map['gps'];

    if (gpsData is GeoPoint) {
      gps = gpsData;
    } else if (gpsData is List && gpsData.length == 2) {
      gps = GeoPoint(
        (gpsData[0] as num).toDouble(),
        (gpsData[1] as num).toDouble(),
      );
    } else if (gpsData is Map && gpsData.containsKey('latitude')) {
      gps = GeoPoint(
        (gpsData['latitude'] as num).toDouble(),
        (gpsData['longitude'] as num).toDouble(),
      );
    }

    return AddressModel(
      detail: map['detail'] ?? 'ไม่มีข้อมูลที่อยู่',
      gps: gps,
      recipientName: map['receiverName'],
      recipientPhone: map['receiverPhone'],
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
