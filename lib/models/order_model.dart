// file: models/order_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/models/address_model.dart';
import 'package:delivery_project/models/status_history_model.dart';

class OrderModel {
  final String id; // Document ID จาก Firestore
  final String customerId;
  final String? riderId;
  final String orderDetails;
  final String? orderPicture;
  final String currentStatus;
  final Timestamp createdAt;
  final Timestamp? pickupDatetime;
  final Timestamp? deliveryDatetime;

  // ใช้ Model ย่อยเพื่อความชัดเจน
  final AddressModel pickupAddress;
  final AddressModel deliveryAddress;
  final List<StatusHistoryModel> statusHistory;

  OrderModel({
    required this.id,
    required this.customerId,
    this.riderId,
    required this.orderDetails,
    this.orderPicture,
    required this.currentStatus,
    required this.createdAt,
    this.pickupDatetime,
    this.deliveryDatetime,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.statusHistory,
  });

  // Factory constructor สำหรับแปลงข้อมูลจาก Firestore
  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // แปลง List ของ Map ให้เป็น List ของ StatusHistoryModel
    final historyList = (data['statusHistory'] as List<dynamic>?)
            ?.map((item) =>
                StatusHistoryModel.fromMap(item as Map<String, dynamic>))
            .toList() ??
        [];

    return OrderModel(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      riderId: data['riderId'],
      orderDetails: data['orderDetails'] ?? 'ไม่มีรายละเอียด',
      orderPicture: data['orderPicture'],
      currentStatus: data['currentStatus'] ?? 'unknown',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      pickupDatetime: data['pickup_datetime'],
      deliveryDatetime: data['delivery_datetime'],
      pickupAddress: AddressModel.fromMap(data['pickupAddress'] ?? {}),
      deliveryAddress: AddressModel.fromMap(data['deliveryAddress'] ?? {}),
      statusHistory: historyList,
    );
  }

  // Method สำหรับแปลง Object กลับเป็น Map เพื่อบันทึกลง Firestore
  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'riderId': riderId,
      'orderDetails': orderDetails,
      'orderPicture': orderPicture,
      'currentStatus': currentStatus,
      'createdAt': createdAt,
      'pickup_datetime': pickupDatetime,
      'delivery_datetime': deliveryDatetime,
      'pickupAddress': pickupAddress.toMap(),
      'deliveryAddress': deliveryAddress.toMap(),
      'statusHistory': statusHistory.map((item) => item.toMap()).toList(),
    };
  }
}
