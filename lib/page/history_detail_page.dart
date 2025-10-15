// history_detail_page.dart

import 'package:delivery_project/page/send_package_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// Constants (อ้างอิงจากธีมหลัก)
const Color _primaryColor = Color(0xFFC70808);
const Color _backgroundColor = Color(0xFFFDE9E9);

class HistoryDetailPage extends StatelessWidget {
  final String uid;
  final int role;
  const HistoryDetailPage({super.key, required this.uid, required this.role});

  // Map Setup (อ้างอิงจาก home.dart และ order_status_page.dart)
  static final LatLng _initialCenter = LatLng(16.4858, 102.8222);
  static const double _initialZoom = 14.0;

  // พิกัดตัวอย่างสำหรับวาด Polyline (จำลองเส้นทาง)
  final List<LatLng> _routePoints = const [
    LatLng(16.4900, 102.8180), // จุดเริ่มต้น (ไรเดอร์)
    LatLng(16.4880, 102.8200),
    LatLng(16.4865, 102.8215),
    LatLng(16.4858, 102.8222), // จุดสิ้นสุด
  ];

  // หมุดบนแผนที่
  List<Marker> get _mapMarkers => [
        // Marker สำหรับจุดหมายปลายทาง (หอพักอาณาจักรฟ้า)
        const Marker(
          point: LatLng(16.4858, 102.8222),
          width: 40,
          height: 40,
          child: Icon(Icons.location_pin, color: _primaryColor, size: 40),
        ),
        // Marker สำหรับไรเดอร์ (ตำแหน่งล่าสุด)
        const Marker(
          point: LatLng(16.4900, 102.8180),
          width: 40,
          height: 40,
          child: Icon(Icons.two_wheeler, color: Colors.blue, size: 40),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildHeader(),
          SliverList(
            delegate: SliverChildListDelegate(
              [
                // ส่วนรายละเอียดข้อมูลผู้ส่ง-ผู้รับ และสินค้า
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoSection(
                          'ข้อมูลผู้ส่งสินค้า',
                          'นาย ก.',
                          '0814715566',
                          'ที่อยู่: มหาวิทยาลัยขอนแก่น',
                          Icons.person),
                      const SizedBox(height: 20),
                      _buildInfoSection(
                          'ข้อมูลผู้รับสินค้า',
                          'พ่อครูกรัน',
                          '0814715566',
                          'ที่อยู่: หอพักอาณาจักรฟ้า',
                          Icons.store),
                      const SizedBox(height: 20),
                      _buildPackageDetailSection(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                // ส่วนแสดงแผนที่
                _buildMapSection(context),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  // ส่วน Header
  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      backgroundColor: _primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.zero,
        centerTitle: false,
        title: const Padding(
          padding: EdgeInsets.only(left: 20, bottom: 8),
          child: Text(
            'รายละเอียดผู้รับสินค้า',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        background: ClipPath(
          clipper: CustomClipperWidget(), // ใช้ Clipper ที่กำหนดเอง
          child: Container(
            color: _primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'สวัสดี คุณ',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      backgroundImage:
                          NetworkImage('https://picsum.photos/200'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'รายละเอียดการส่งสินค้า',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Get.back(),
      ),
    );
  }

  // ส่วนข้อมูลผู้ส่ง/ผู้รับ
  Widget _buildInfoSection(
      String title, String name, String phone, String address, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // หัวข้อ
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: _primaryColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        // รายละเอียด
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 5)
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Colors.grey), // แทนรูป Avatar
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ชื่อ: $name',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('เบอร์โทร: $phone'),
                  Text(address),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ส่วนรายละเอียดสินค้า
  Widget _buildPackageDetailSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ปุ่ม/หัวข้อ "รายละเอียดสินค้า"
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'รายละเอียดสินค้า',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // รายการสินค้า
        _buildProductItem('กระเป๋าสตางค์', 'Black Wallet', '0808***'),
        _buildProductItem('น้ำหอม', 'Blue Perfume', '0808***'),
      ],
    );
  }

  Widget _buildProductItem(String title, String detail, String orderId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory,
              size: 40, color: Colors.grey), // แทนรูปสินค้า
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(detail),
              Text('Order ID: $orderId',
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }

  // ส่วนแสดงแผนที่
  Widget _buildMapSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, offset: Offset(0, 4), blurRadius: 8),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: FlutterMap(
            mapController: MapController(),
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              interactionOptions:
                  const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=cb153d15cb4e41f59e25cfda6468f1a0',
                userAgentPackageName: "com.example.delivery_project",
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 5.0,
                    color: Colors.blue, // สีเส้นทาง
                  ),
                ],
              ),
              MarkerLayer(markers: _mapMarkers),
            ],
          ),
        ),
      ),
    );
  }

  // Bottom Navigation Bar (ย่อสำหรับ Detail Page)
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
        currentIndex: 1, // กำหนดให้ประวัติถูกเลือกอยู่
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
        onTap: (index) {
          // ในหน้ารายละเอียดนี้ ควรกด Back แทนการนำทางใน BottomBar
        },
      ),
    );
  }
}
