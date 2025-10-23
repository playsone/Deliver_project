import 'dart:developer';
import 'dart:math' show cos, sqrt, asin, pi, atan2, sin;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/models/order_model.dart';
import 'package:delivery_project/models/package_model.dart';
import 'package:delivery_project/page/home_rider.dart'; // Import RiderHomeController
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

// ------------------------------------------------------------------
// Page สำหรับแสดงรายละเอียดงานที่ 'pending' ก่อนการรับงาน
// ------------------------------------------------------------------
class PackageDetailScreen extends StatelessWidget {
  // รับ OrderModel เข้ามาโดยตรงเพื่อให้มีข้อมูลผู้รับ/ผู้ส่งครบถ้วน
  final OrderModel order;
  final RiderHomeController riderController;

  const PackageDetailScreen({
    super.key,
    required this.order,
    required this.riderController,
  });

  // สร้าง MapController เพื่อควบคุมแผนที่
  static final MapController _mapController = MapController();
  static const primaryColor = Color(0xFFC70808);

  // ฟังก์ชันสำหรับคำนวณระยะทาง (Haversine Formula) - คัดลอกจาก RiderHomeController
  double _calculateDistanceMeters(GeoPoint loc1, GeoPoint loc2) {
    const double R = 6371000; // meters
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
    final GeoPoint? deliveryGps = order.deliveryAddress.gps;
    final LatLng deliveryLatLng = deliveryGps != null
        ? LatLng(deliveryGps.latitude, deliveryGps.longitude)
        : const LatLng(0, 0); // ตำแหน่งผู้รับ

    // คำนวณระยะทางจากไรเดอร์ถึงจุดรับสินค้า
    final GeoPoint? riderLoc = riderController.riderCurrentLocation.value;
    final double distance =
        (riderLoc != null && order.pickupAddress.gps != null)
            ? _calculateDistanceMeters(riderLoc, order.pickupAddress.gps!)
            : 9999.0;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title:
            const Text('รายละเอียดงาน', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            // 1. ส่วนแผนที่ (แสดงตำแหน่งผู้รับ)
            _buildMapSection(deliveryLatLng),
            const SizedBox(height: 20),

            // 2. ข้อมูลสินค้า
            _buildPackageDetailsCard(order),
            const SizedBox(height: 20),

            // 3. ข้อมูลผู้รับและผู้ส่ง
            _buildDeliveryInfoSection(order),
            const SizedBox(height: 20),

            // 4. ปุ่มรับงาน (ดึงจาก Controller ของหน้า Home)
            _buildAcceptButton(context, distance),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection(LatLng targetLatLng) {
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
              initialCenter: targetLatLng,
              initialZoom: 15.0,
              onMapReady: () {
                // Zoom ไปยังจุดเป้าหมาย (ผู้รับ)
                if (targetLatLng.latitude != 0 && targetLatLng.longitude != 0) {
                  _mapController.move(targetLatLng, 15.0);
                }
              }),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=cb153d15cb4e41f59e25cfda6468f1a0',
              userAgentPackageName: 'com.example.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: targetLatLng,
                  width: 80,
                  height: 80,
                  child: const Icon(Icons.location_on,
                      color: primaryColor, size: 40),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageDetailsCard(OrderModel order) {
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
          const Text('ข้อมูลสินค้า',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(height: 20),
          _infoRow(
            icon: Icons.inventory_2_outlined,
            label: 'รายละเอียดสินค้า',
            value: order.orderDetails,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDeliveryInfoSection(OrderModel order) {
    final delivery = order.deliveryAddress;

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
          const Text('ข้อมูลผู้รับและผู้ส่ง',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(height: 20),

          // ข้อมูลผู้ส่ง (ต้องดึงจาก Firestore โดยใช้ customerId)
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(order
                    .customerId) // 👈 แก้ไข: ใช้ customerId เพื่อดึงข้อมูลผู้ส่ง
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: Text('กำลังโหลดผู้ส่ง...'));
              }
              final userData = snap.data!.data() as Map<String, dynamic>? ?? {};
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(
                    icon: Icons.storefront,
                    label: 'รับจาก',
                    value: order.pickupAddress.detail,
                  ),
                  const SizedBox(height: 8),
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
          ),

          const Divider(height: 20),

          // ข้อมูลผู้รับ
          _infoRow(
            icon: Icons.location_on,
            label: 'ส่งที่',
            value: delivery.detail,
          ),
          const SizedBox(height: 8),
          _infoRow(
            icon: Icons.person_pin,
            label: 'ผู้รับ',
            value: delivery.recipientName ?? 'N/A',
          ),
          const SizedBox(height: 8),
          _infoRow(
            icon: Icons.phone_android,
            label: 'เบอร์ติดต่อ (ผู้รับ)',
            value: delivery.recipientPhone ?? 'N/A',
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

  Widget _buildAcceptButton(BuildContext context, double distance) {
    // ตรวจสอบว่าไรเดอร์อยู่ใกล้จุดรับงานพอที่จะกดรับงานได้หรือไม่
    final bool canAccept = distance <= RiderHomeController.MAX_DISTANCE_METERS;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
        label: Text(
          canAccept
              ? 'รับงานนี้'
              : 'ระยะทางเกิน (ห่าง ${distance.toStringAsFixed(2)} ม.)',
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
        onPressed: canAccept
            ? () {
                // เรียกฟังก์ชัน acceptOrder เมื่อกดปุ่ม
                riderController.acceptOrder(order);
                // อาจจะต้องมีการนำทางกลับหน้า Home หรือไปยังหน้าติดตามสถานะ
                // ตัวอย่าง: Navigator.pop(context);
              }
            : null, // ปิดปุ่มถ้าไกลเกินไป
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          // เปลี่ยนสีเมื่อปิดปุ่ม
          disabledBackgroundColor: Colors.grey,
        ),
      ),
    );
  }
}
