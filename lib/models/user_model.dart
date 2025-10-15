import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final int role;
  final String phone;
  final String profile;
  final String fullname;

  // สำหรับ role 0
  final String? defaultAddress;
  final double? defaultLat;
  final double? defaultLng;
  final String? secondAddress;
  final double? secondLat;
  final double? secondLng;

  // สำหรับ role 1 (Rider)
  final String? vehicleNo;
  final String? vehiclePicture;
  final double? gpsLat;
  final double? gpsLng;

  UserModel({
    required this.uid,
    required this.role,
    required this.phone,
    required this.profile,
    required this.fullname,
    this.defaultAddress,
    this.defaultLat,
    this.defaultLng,
    this.secondAddress,
    this.secondLat,
    this.secondLng,
    this.vehicleNo,
    this.vehiclePicture,
    this.gpsLat,
    this.gpsLng,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final role = data['role'] ?? 0;

    if (role == 0) {
      // User ปกติ
      final geo = data['defaultGPS'] as GeoPoint?;
      final geo2 = data['secondGPS'] as GeoPoint?;
      return UserModel(
        uid: data['uid'] ?? '',
        role: role,
        phone: data['phone'] ?? '',
        profile: data['profile'] ?? '',
        fullname: data['fullname'] ?? '',
        defaultAddress: data['defaultAddress'],
        defaultLat: geo?.latitude,
        defaultLng: geo?.longitude,
        secondAddress: data['secondAddress'],
        secondLat: geo2?.latitude,
        secondLng: geo2?.longitude,
      );
    } else if (role == 1) {
      // Rider
      final geo = data['gps'] as GeoPoint?;
      return UserModel(
        uid: data['uid'] ?? '',
        role: role,
        phone: data['phone'] ?? '',
        profile: data['profile'] ?? '',
        fullname: data['fullname'] ?? '',
        vehicleNo: data['vehicle_no'],
        vehiclePicture: data['vehicle_picture'],
        gpsLat: geo?.latitude,
        gpsLng: geo?.longitude,
      );
    } else {
      throw Exception('Unknown role: $role');
    }
  }

  Map<String, Object?> toJson() {
    final map = {
      "uid": uid,
      "role": role,
      "phone": phone,
      "profile": profile,
      "fullname": fullname,
    };

    if (role == 0) {
      map.addAll({
        "defaultAddress": defaultAddress ?? "",
        "defaultGPS": {
          "latitude": defaultLat,
          "longitude": defaultLng,
        },
        "secondAddress": secondAddress ?? "",
        "secondGPS": {
          "latitude": secondLat,
          "longitude": secondLng,
        },
      });
    } else if (role == 1) {
      map.addAll({
        "vehicle_no": vehicleNo ?? "",
        "vehicle_picture": vehiclePicture ?? "",
        "gps": {
          "latitude": gpsLat,
          "longitude": gpsLng,
        },
      });
    }

    return map;
  }
}
