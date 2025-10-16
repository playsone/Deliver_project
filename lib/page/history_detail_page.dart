// history_detail_page.dart

import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/page/index.dart';
import 'package:delivery_project/page/send_package_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// Constants
const Color _primaryColor = Color(0xFFC70808);
const Color _backgroundColor = Color(0xFFFDE9E9);

class HistoryDetailPage extends StatefulWidget {
  final String uid;
  final int role;
  final String orderId; // **เพิ่ม:** รับ orderId จากหน้า HistoryPage

  const HistoryDetailPage({
    super.key,
    required this.uid,
    required this.role,
    required this.orderId,
  });

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  // ใช้ Future เพื่อดึงข้อมูลเพียงครั้งเดียว
  late Future<DocumentSnapshot<Map<String, dynamic>>> _orderFuture;

  @override
  void initState() {
    super.initState();
    // เริ่มดึงข้อมูลออเดอร์เมื่อหน้านี้ถูกสร้าง
    _orderFuture = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _orderFuture,
        builder: (context, snapshot) {
          // สถานะขณะโหลด
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // หากเกิด Error
          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Center(
                child: Text('ไม่สามารถโหลดรายละเอียดออเดอร์ได้'));
          }

          // เมื่อโหลดข้อมูลสำเร็จ
          final orderData = snapshot.data!.data()!;

          return CustomScrollView(
            slivers: [
              _buildHeader(orderData),
              SliverList(
                delegate: SliverChildListDelegate(
                  [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // **ใช้ FutureBuilder ซ้อนเพื่อดึงข้อมูล Customer**
                          _buildUserDetail(
                              orderData['customerId'], 'ข้อมูลผู้ส่งสินค้า'),
                          const SizedBox(height: 20),
                          // **แสดงข้อมูลผู้รับจาก orderData โดยตรง**
                          _buildReceiverInfoSection(
                              orderData['deliveryAddress']),
                          const SizedBox(height: 20),
                          _buildPackageDetailSection(orderData),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                    _buildMapSection(context, orderData),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  // ส่วน Header
  Widget _buildHeader(Map<String, dynamic> orderData) {
    return SliverAppBar(
      expandedHeight: 150.0,
      pinned: true,
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Get.back(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 60, bottom: 12),
        title: const Text('รายละเอียดประวัติ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // **แก้ไข:** Widget สำหรับดึงและแสดงข้อมูล User (ผู้ส่ง/ไรเดอร์)
  Widget _buildUserDetail(String userId, String title) {
    final userFuture =
        FirebaseFirestore.instance.collection('users').doc(userId).get();

    return FutureBuilder<DocumentSnapshot>(
        future: userFuture,
        builder: (context, userSnapshot) {
          String name = 'กำลังโหลด...';
          String phone = '...';

          if (userSnapshot.hasData && userSnapshot.data!.exists) {
            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            name = userData['fullname'] ?? 'ไม่มีชื่อ';
            phone = userData['phone'] ?? 'ไม่มีเบอร์โทร';
          }

          return _buildInfoSection(title, name, phone, Icons.person);
        });
  }

  // **แก้ไข:** Widget สำหรับแสดงข้อมูลผู้รับจากข้อมูลออเดอร์
  Widget _buildReceiverInfoSection(Map<String, dynamic> deliveryAddress) {
    final name = deliveryAddress['receiverName'] ?? 'ไม่มีชื่อ';
    final phone = deliveryAddress['receiverPhone'] ?? 'ไม่มีเบอร์โทร';
    final address = deliveryAddress['detail'] ?? 'ไม่มีที่อยู่';

    return _buildInfoSection('ข้อมูลผู้รับสินค้า', name, phone, Icons.store,
        address: address);
  }

  // ส่วนข้อมูล
  Widget _buildInfoSection(
      String title, String name, String phone, IconData icon,
      {String? address}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: _primaryColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10)),
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 5)
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Colors.grey),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ชื่อ: $name',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('เบอร์โทร: $phone'),
                    if (address != null) Text('ที่อยู่: $address'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ส่วนรายละเอียดสินค้า
  Widget _buildPackageDetailSection(Map<String, dynamic> orderData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
            decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(10)),
            child: const Text('รายละเอียดสินค้า',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              // แสดงรูปสินค้า
              orderData['orderImageUrl'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(orderData['orderImageUrl'],
                          width: 60, height: 60, fit: BoxFit.cover))
                  : const Icon(Icons.inventory, size: 40, color: Colors.grey),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orderData['orderDetails'] ?? 'N/A',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text('Order ID: ${widget.orderId.substring(0, 8)}...',
                        style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  // ส่วนแสดงแผนที่
  Widget _buildMapSection(
      BuildContext context, Map<String, dynamic> orderData) {
    final pickupGps = orderData['pickupAddress']['gps'] as GeoPoint;
    final deliveryGps = orderData['deliveryAddress']['gps'] as GeoPoint;

    final pickupLatLng = LatLng(pickupGps.latitude, pickupGps.longitude);
    final deliveryLatLng = LatLng(deliveryGps.latitude, deliveryGps.longitude);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, offset: Offset(0, 4), blurRadius: 8)
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: FlutterMap(
            mapController: MapController(),
            options: MapOptions(
              initialCenter: deliveryLatLng,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              MarkerLayer(markers: [
                Marker(
                    point: pickupLatLng,
                    child:
                        const Icon(Icons.store, color: Colors.green, size: 40)),
                Marker(
                    point: deliveryLatLng,
                    child: const Icon(Icons.location_on,
                        color: _primaryColor, size: 40)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // Bottom Navigation Bar
  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _primaryColor,
        boxShadow: [
          BoxShadow(color: Colors.black12, offset: Offset(0, -2), blurRadius: 5)
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        currentIndex: 1, // กำหนดให้ประวัติถูกเลือกอยู่
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'หน้าแรก'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'ประวัติ'),
          BottomNavigationBarItem(
              icon: Icon(Icons.logout), label: 'ออกจากระบบ'),
        ],
        onTap: (index) {
          if (index == 0) {
            Get.offAll(
                () => SendPackagePage(uid: widget.uid, role: widget.role));
          } else if (index == 2) {
            Get.offAll(() => const SpeedDerApp());
          }
        },
      ),
    );
  }
}

// Custom Clipper for Header
class CustomClipperWidget extends CustomClipper<ui.Path> {
  // <-- Correction #1
  @override
  ui.Path getClip(Size size) {
    // <-- Correction #2
    double h = size.height;
    double w = size.width;
    ui.Path path = ui.Path(); // <-- Correction #3

    path.lineTo(0, h * 0.85);
    path.quadraticBezierTo(w * 0.15, h * 0.95, w * 0.45, h * 0.85);
    path.quadraticBezierTo(w * 0.65, h * 0.75, w, h * 0.8);
    path.lineTo(w, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<ui.Path> oldClipper) =>
      false; // <-- Correction #4
}
