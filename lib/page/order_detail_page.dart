// file: lib/page/order_detail_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- Import ตาม pubspec.yaml ---
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// --- Import Model และ Controller ---
import 'package:delivery_project/models/order_model.dart';
import 'package:delivery_project/page/home_rider.dart';

class OrderDetailPage extends StatefulWidget {
  final OrderModel order;
  final GeoPoint riderLocation; // ตำแหน่งล่าสุดของ Rider

  const OrderDetailPage({
    super.key,
    required this.order,
    required this.riderLocation,
  });

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final MapController _mapController = MapController();
  final List<Marker> _markers = [];

  late LatLng riderLatLng;
  late LatLng pickupLatLng;

  @override
  void initState() {
    super.initState();

    // 1. แปลง GeoPoint เป็น LatLng (จาก latlong2)
    riderLatLng =
        LatLng(widget.riderLocation.latitude, widget.riderLocation.longitude);
    pickupLatLng = LatLng(widget.order.pickupAddress.gps.latitude,
        widget.order.pickupAddress.gps.longitude);

    // 2. สร้าง Markers (รูปแบบของ flutter_map)
    _markers.add(
      Marker(
        width: 100.0,
        height: 80.0,
        point: riderLatLng,
        child: Column(
          children: [
            Icon(Icons.person_pin_circle,
                color: Colors.blue.shade700, size: 40),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              color: Colors.white70,
              child: const Text("ตำแหน่งของคุณ",
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
    _markers.add(
      Marker(
          width: 100.0,
          height: 80.0,
          point: pickupLatLng,
          child: Column(
            children: [
              Icon(Icons.store, color: Colors.red.shade700, size: 40),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                color: Colors.white70,
                child: const Text("จุดรับสินค้า",
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
              )
            ],
          )),
    );
  }

  // ฟังก์ชันสำหรับ Zoom ให้เห็น Marker ทั้งหมด
  void _fitBounds() {
    final bounds = LatLngBounds(riderLatLng, pickupLatLng);

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(70.0), // 70 pixels padding
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ดึง Controller ที่ถูก 'put' ไว้ในหน้า Home
    final RiderHomeController homeController = Get.find<RiderHomeController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดงาน'),
        backgroundColor: const Color(0xFFC70808),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. ส่วนของแผนที่ (ใช้ FlutterMap)
          Expanded(
            flex: 3,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: pickupLatLng, // เริ่มต้นที่จุดรับของ
                initialZoom: 15,
                onMapReady: () {
                  // เมื่อ Map พร้อม, ให้ zoom ไปที่ขอบเขต
                  _fitBounds();
                },
              ),
              children: [
                // Layer ของแผนที่
                TileLayer(
                  // [API Key] ใช้ URL เดิมตามที่คุณแจ้งว่ายังไม่กังวล
                  urlTemplate:
                      'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=cb153d15cb4e41f59e25cfda6468f1a0',
                  userAgentPackageName:
                      'com.example.delivery_project', // [สำคัญ] ใส่ชื่อ package ของคุณ
                ),
                // Layer ของ Marker
                MarkerLayer(
                  markers: _markers,
                ),
              ],
            ),
          ),

          // 2. ส่วนของรายละเอียด
          Expanded(
            flex: 2, // ส่วนรายละเอียด
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('รายละเอียดผู้ส่ง (ต้นทาง)'),
                  _buildDetailRow(Icons.person,
                      widget.order.pickupAddress.recipientName ?? 'ไม่มีชื่อ'),
                  _buildDetailRow(
                      Icons.phone,
                      widget.order.pickupAddress.recipientPhone ??
                          'ไม่มีเบอร์'),
                  _buildDetailRow(
                      Icons.location_on, widget.order.pickupAddress.detail),
                  const Divider(height: 30, thickness: 1),
                  _buildSectionHeader('รายละเอียดผู้รับ (ปลายทาง)'),
                  _buildDetailRow(
                      Icons.person,
                      widget.order.deliveryAddress.recipientName ??
                          'ไม่มีชื่อ'),
                  _buildDetailRow(
                      Icons.phone,
                      widget.order.deliveryAddress.recipientPhone ??
                          'ไม่มีเบอร์'),
                  _buildDetailRow(
                      Icons.location_on, widget.order.deliveryAddress.detail),
                  const SizedBox(height: 30),

                  // 3. ปุ่มรับงาน
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38B000), // สีเขียว
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        // เรียกใช้ฟังก์ชันจาก Controller ที่ Get.find() มา
                        homeController.acceptOrder(widget.order);
                      },
                      child: const Text(
                        'ยืนยันรับงานนี้',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFFC70808),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
