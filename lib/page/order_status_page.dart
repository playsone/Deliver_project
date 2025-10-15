// order_status_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:delivery_project/page/home.dart'; // สมมติว่ามี home.dart

// Constants สำหรับ Map
const Color _primaryColor = Color(0xFFC70808);
const Color _backgroundColor = Color(0xFFFDE9E9);

class OrderStatusPage extends StatefulWidget {
  const OrderStatusPage({super.key, required String orderId});

  @override
  State<OrderStatusPage> createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends State<OrderStatusPage> {
  // Map Controller
  final MapController mapController = MapController();

  // พิกัดตัวอย่างสำหรับแสดงเส้นทาง (อิงจาก home.dart)
  static final LatLng _initialCenter = LatLng(16.4858, 102.8222);
  static const double _initialZoom = 14.0;

  // รายการหมุด (อิงจาก home.dart และเพิ่มเติมสำหรับเส้นทาง)
  List<Marker> get _routeMarkers => [
        // จุดหมายปลายทาง (หอพักอาณาจักรฟ้า)
        Marker(
          point: LatLng(16.4858, 102.8222),
          width: 40,
          height: 40,
          child: const Icon(Icons.location_pin, color: _primaryColor, size: 40),
        ),
        // ไรเดอร์/ตำแหน่งปัจจุบันของสินค้า
        Marker(
          point: LatLng(16.4900, 102.8180),
          width: 40,
          height: 40,
          child: const Icon(Icons.two_wheeler, color: Colors.blue, size: 40),
        ),
      ];

  // พิกัดตัวอย่างสำหรับวาด Polyline (จำลองเส้นทาง)
  final List<LatLng> _routePoints = [
    LatLng(16.4900, 102.8180), // จุดเริ่มต้น (ไรเดอร์)
    LatLng(16.4910, 102.8195),
    LatLng(16.4870, 102.8210),
    LatLng(16.4858, 102.8222), // จุดสิ้นสุด
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title:
            const Text('ดูสถานะสินค้า', style: TextStyle(color: Colors.white)),
        backgroundColor: _primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ส่วนรายการที่ต้องส่ง
            _buildOrderListHeader(),
            // ส่วนแผนที่
            _buildMapSection(context),
            // รายการสถานะสินค้าแต่ละชิ้น
            const SizedBox(height: 10),
            _buildProductStatusItem(
                'แอมป์กีต้าร์ (Order: 0814***)', 'กำลังจัดส่ง'),
            _buildProductStatusItem(
                'น้ำหอม (Order: 0814***)', 'พัสดุเตรียมจัดส่ง'),
            _buildProductStatusItem(
                'เบคอนรมควัน (Order: 0814***)', 'สินค้าถึงปลายทาง'),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  // ส่วนหัวข้อ "รายการที่ต้องส่ง" และแถบ Search
  Widget _buildOrderListHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'รายการที่ต้องส่ง',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const TextField(
              decoration: InputDecoration(
                hintText: 'ค้นหารายการ...',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: _primaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ส่วนแสดงแผนที่
  Widget _buildMapSection(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.45,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 8),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: _initialZoom,
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.all),
          ),
          children: [
            // Tile Layer (แผนที่พื้นฐาน)
            TileLayer(
              urlTemplate:
                  'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=cb153d15cb4e41f59e25cfda6468f1a0',
              userAgentPackageName: "com.example.delivery_project",
            ),
            // Polyline Layer (เส้นทาง)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _routePoints,
                  strokeWidth: 5.0,
                  color: Colors.blue, // สีเส้นทาง
                ),
              ],
            ),
            // Marker Layer (หมุด)
            MarkerLayer(markers: _routeMarkers),
          ],
        ),
      ),
    );
  }

  // Widget สำหรับรายการสถานะสินค้าแต่ละชิ้น
  Widget _buildProductStatusItem(String title, String status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10, left: 20, right: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 5),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory,
              color: Colors.grey, size: 40), // แทนรูปภาพสินค้า
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  'สถานะ: $status',
                  style: TextStyle(
                    color:
                        status == 'กำลังจัดส่ง' ? Colors.orange : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Bottom Navigation Bar (อ้างอิงจาก home.dart)
  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _primaryColor,
        boxShadow: [
          BoxShadow(
              color: Colors.black12, offset: Offset(0, -2), blurRadius: 5),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'หน้าแรก'),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'ประวัติการส่งสินค้า',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: 'ออกจากระบบ',
          ),
        ],
        currentIndex: 0, // ควรเปลี่ยนเมื่อมีการนำทางจริง
        onTap: (index) {
          // ใช้ Get.back() หรือ Get.to(() => const HomeScreen()) เพื่อกลับหน้าหลัก
        },
      ),
    );
  }
}
