import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:delivery_project/models/order_model.dart';
import 'package:delivery_project/models/userinfo_model.dart';

class Package {
  final String id;
  final String title;
  final String location;
  final String destination;
  final String? imageUrl;

  Package({
    required this.id,
    required this.title,
    required this.location,
    required this.destination,
    this.imageUrl,
  });
}

class PackageModel {
  final String id;
  final String source;
  final String destination;
  final String currentStatus;
  final String customerId;
  final String? riderId;
  final String orderDetails;
  final String? deliveredImageUrl;
  UserInfo? senderInfo;
  UserInfo? riderInfo;

  PackageModel({
    required this.id,
    required this.source,
    required this.destination,
    required this.currentStatus,
    required this.customerId,
    this.riderId,
    required this.orderDetails,
    this.deliveredImageUrl,
    this.senderInfo,
    this.riderInfo,
  });

  factory PackageModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String sourceDetail = data['pickupAddress']?['detail'] ?? 'ไม่ระบุต้นทาง';
    String destinationDetail =
        data['deliveryAddress']?['detail'] ?? 'ไม่ระบุปลายทาง';

    String? deliveredImgUrl;
    if (data['currentStatus'] == 'delivered') {
      deliveredImgUrl = data['deliveredImageUrl'];

      if (deliveredImgUrl == null && data['statusHistory'] is List) {
        final deliveredEntry = (data['statusHistory'] as List).firstWhereOrNull(
            (h) =>
                h['status'] == 'delivered' &&
                h['imgOfStatus']?.isNotEmpty == true);
        deliveredImgUrl = deliveredEntry?['imgOfStatus'];
      }
    }

    return PackageModel(
      id: doc.id,
      source: 'จาก: $sourceDetail',
      destination: 'ไปที่: $destinationDetail',
      currentStatus: data['currentStatus'] ?? 'unknown',
      customerId: data['customerId'] ?? '',
      riderId: data['riderId'],
      orderDetails: data['orderDetails'] ?? 'ไม่ระบุรายละเอียดสินค้า',
      deliveredImageUrl: deliveredImgUrl,
    );
  }

  factory PackageModel.fromOrderModel(OrderModel order) {
    String? deliveredImgUrl;
    if (order.currentStatus == 'delivered') {
      final deliveredEntry = order.statusHistory.firstWhereOrNull(
          (h) => h.status == 'delivered' && h.imgOfStatus?.isNotEmpty == true);
      deliveredImgUrl = deliveredEntry?.imgOfStatus;
    }

    return PackageModel(
      id: order.id,
      source: 'จาก: ${order.pickupAddress.detail}',
      destination: 'ไปที่: ${order.deliveryAddress.detail}',
      currentStatus: order.currentStatus,
      customerId: order.customerId,
      riderId: order.riderId,
      orderDetails: order.orderDetails,
      deliveredImageUrl: deliveredImgUrl,
    );
  }
}