import 'dart:async';
import 'dart:developer';
import 'dart:math' show cos, sqrt, asin, pi, atan2, sin;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/models/order_model.dart';
import 'package:delivery_project/models/user_model.dart';
import 'package:delivery_project/page/home_rider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

class PackageDetailScreen extends StatelessWidget {
  final OrderModel order;
  final RiderHomeController riderController;

  const PackageDetailScreen({
    super.key,
    required this.order,
    required this.riderController,
  });

  static final MapController _mapController = MapController();
  static const primaryColor = Color(0xFFC70808);

  double _calculateDistanceMeters(GeoPoint loc1, GeoPoint loc2) {
    const double R = 6371000;
    final double lat1 = loc1.latitude;
    final double lon1 = loc1.longitude;
    final double lat2 = loc2.latitude;
    final double lon2 = loc2.longitude;

    final double dLat = (lat2 - lat1) * (pi / 180);
    final double dLon = (lon2 - lon1) * (pi / 180);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final GeoPoint? riderLoc = riderController.riderCurrentLocation.value;
      final double distance =
          (riderLoc != null && order.pickupAddress.gps != null)
              ? _calculateDistanceMeters(riderLoc, order.pickupAddress.gps!)
              : 9999.0;

      return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('รายละเอียดงาน',
              style: TextStyle(color: Colors.white)),
          backgroundColor: primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            children: [
              _buildMapSection(),
              const SizedBox(height: 15),
              _buildPackageDetailsCard(),
              const SizedBox(height: 15),
              _buildDeliveryInfoSection(), // เอา Controller ออก
              const SizedBox(height: 15),
              _buildAcceptButton(context, true, distance),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildMapSection() {
    final GeoPoint? pickupGps = order.pickupAddress.gps;
    final GeoPoint? deliveryGps = order.deliveryAddress.gps;
    final GeoPoint? riderLoc = riderController.riderCurrentLocation.value;

    final LatLng pickupLatLng = pickupGps != null
        ? LatLng(pickupGps.latitude, pickupGps.longitude)
        : const LatLng(0, 0);

    final LatLng deliveryLatLng = deliveryGps != null
        ? LatLng(deliveryGps.latitude, deliveryGps.longitude)
        : const LatLng(0, 0);

    List<Marker> markers = [];

    if (pickupGps != null && pickupGps.latitude != 0) {
      markers.add(Marker(
        point: pickupLatLng,
        width: 80,
        height: 80,
        child: const Column(
          children: [
            Icon(Icons.storefront, color: Colors.blue, size: 40),
            Text('จุดรับ',
                style:
                    TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ],
        ),
      ));
    }
    if (deliveryGps != null) {
      markers.add(Marker(
        point: deliveryLatLng,
        width: 80,
        height: 80,
        child: const Column(
          children: [
            Icon(Icons.location_on, color: primaryColor, size: 40),
            Text('จุดส่ง',
                style: TextStyle(
                    color: primaryColor, fontWeight: FontWeight.bold)),
          ],
        ),
      ));
    }

    return Container(
      height: 250,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: pickupLatLng.latitude != 0
                ? pickupLatLng
                : const LatLng(13.7563, 100.5018),
            initialZoom: 14.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onMapReady: () {
              if (markers.length > 1) {
                var bounds = LatLngBounds.fromPoints(
                    markers.map((m) => m.point).toList());
                _mapController.fitBounds(bounds,
                    options:
                        const FitBoundsOptions(padding: EdgeInsets.all(50.0)));
              } else if (markers.isNotEmpty) {
                _mapController.move(markers.first.point, 14.0);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=cb153d15cb4e41f59e25cfda6468f1a0',
              userAgentPackageName: 'com.example.app',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageDetailsCard() {
    final bool hasImage =
        order.orderPicture != null && order.orderPicture!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  order.orderPicture!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(
                          child: Icon(Icons.image_not_supported,
                              color: Colors.grey, size: 50)),
                    );
                  },
                ),
              ),
            ),
          Text(order.orderDetails,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor)),
          const Divider(height: 20),
          _infoRow(
            icon: Icons.inventory_2_outlined,
            label: 'รายละเอียดสินค้า',
            value: order.orderDetails,
          ),
        ],
      ),
    );
  }

  // ✨✨✨ ส่วนที่แก้ไขใหม่ทั้งหมด ตามตัวอย่างของคุณ ✨✨✨
  Widget _buildDeliveryInfoSection() {
    final pickup = order.pickupAddress;
    final delivery = order.deliveryAddress;
    final customerId = order.customerId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ข้อมูลการจัดส่ง',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(height: 20),
          _infoRow(
            icon: Icons.storefront,
            label: 'รับจาก',
            value: pickup.detail,
          ),
          const SizedBox(height: 8),

          // --- ใช้ StreamBuilder ดึงข้อมูลผู้ส่ง เหมือนตัวอย่าง ---
          if (customerId.isNotEmpty)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(customerId)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: LinearProgressIndicator()),
                  );
                }
                final userData =
                    snap.data!.data() as Map<String, dynamic>? ?? {};
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow(
                      icon: Icons.person,
                      label: 'ผู้ส่ง',
                      value: userData['fullname'] ?? 'ไม่มีข้อมูล',
                    ),
                    const SizedBox(height: 8),
                    _infoRow(
                      icon: Icons.phone,
                      label: 'เบอร์ติดต่อ (ผู้ส่ง)',
                      value: userData['phone'] ?? 'ไม่มีข้อมูล',
                    ),
                  ],
                );
              },
            )
          else
            _infoRow(icon: Icons.person, label: 'ผู้ส่ง', value: 'ไม่มีข้อมูล'),

          const Divider(height: 20),

          _infoRow(
            icon: Icons.location_on,
            label: 'ส่งที่',
            value: delivery.detail,
          ),
          const SizedBox(height: 8),
          _infoRow(
            icon: Icons.person_pin,
            label: 'ผู้รับ',
            value: delivery.receiverName ?? 'N/A',
          ),
          const SizedBox(height: 8),
          _infoRow(
            icon: Icons.phone_android,
            label: 'เบอร์ติดต่อ (ผู้รับ)',
            value: delivery.receiverPhone ?? 'N/A',
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: primaryColor),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(fontSize: 16, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAcceptButton(
      BuildContext context, bool isNearEnough, double distance) {
    String buttonText;
    Color buttonColor;
    bool isEnabled;

    if (riderController.riderCurrentLocation.value == null) {
      buttonText = 'กำลังค้นหาตำแหน่ง Rider...';
      buttonColor = Colors.grey;
      isEnabled = false;
    } else if (isNearEnough) {
      buttonText = 'รับงานนี้';
      buttonColor = const Color(0xFF38B000);
      isEnabled = true;
    } else {
      buttonText =
          'ต้องอยู่ใกล้จุดรับงาน (ห่าง ${distance.toStringAsFixed(0)} ม.)';
      buttonColor = Colors.orange;
      isEnabled = false;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ElevatedButton.icon(
        icon: isNearEnough
            ? const Icon(Icons.check_circle_outline, color: Colors.white)
            : const Icon(Icons.warning_amber, color: Colors.white),
        label: Text(
          buttonText,
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
        onPressed: isEnabled
            ? () {
                Get.back();
                riderController.acceptOrder(order);
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          disabledBackgroundColor: Colors.grey,
        ),
      ),
    );
  }
}
