import 'dart:async'; // สำหรับ Completer

import 'package:delivery_project/page/index.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/get_navigation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // สำหรับ Google Maps
import 'package:delivery_project/page/edit_profile.dart';
// End Mock Pages

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 1. ตัวแปรสำหรับ Google Maps
  final Completer<GoogleMapController> _controller = Completer();

  // พิกัดเริ่มต้น: หอพักอาณาจักรฟ้า (ตัวอย่างพิกัด)
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(16.4858, 102.8222),
    zoom: 14.0,
  );

  // จุดปักหมุด
  final Set<Marker> _markers = {
    // Marker สำหรับจุดหมายปลายทาง (หอพักอาณาจักรฟ้า)
    const Marker(
      markerId: MarkerId('destination'),
      position: LatLng(16.4858, 102.8222),
      infoWindow: InfoWindow(title: 'หอพักอาณาจักรฟ้า'),
      icon: BitmapDescriptor.defaultMarker,
    ),
    // Marker สำหรับไรเดอร์ (ตัวอย่าง)
    const Marker(
      markerId: MarkerId('rider'),
      position: LatLng(16.4900, 102.8180),
      infoWindow: InfoWindow(title: 'ไรเดอร์กำลังมา'),
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDE9E9), // สีพื้นหลังตามรูป
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              _buildIconButtons(),
              const SizedBox(height: 20),
              _buildMapSection(context), // วิดเจ็ต Google Map จริง
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  //------------------------------------------------------------------
  // Header Section
  //------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    return Stack(
      children: [
        // Background Wave/ClipPath
        ClipPath(
          clipper: HeaderClipper(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.3,
            decoration: const BoxDecoration(color: Color(0xFFC70808)),
          ),
        ),
        // Content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'สวัสดีคุณ\nพ่อครูกรัน',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showProfileOptions(context),
                    child: const CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white,
                      // ใช้ NetworkImage สำหรับรูปโปรไฟล์ (ต้องมี URL จริง)
                      backgroundImage: NetworkImage(
                        'https://picsum.photos/200',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildLocationBar(),
            ],
          ),
        ),
      ],
    );
  }

  /// สร้างแถบที่อยู่
  Widget _buildLocationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text(
            'หอพักอาณาจักรฟ้า',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  //------------------------------------------------------------------
  // Icon Buttons Section (ปรับจากโค้ดเดิมให้สวยขึ้น)
  //------------------------------------------------------------------

  Widget _buildIconButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFeatureButton(
                'พัสดุที่ต้องรับ',
                'assets/images/package_icon.png',
              ),
              _buildFeatureButton(
                'ข้อมูลไรเดอร์',
                'assets/images/rider_icon.png',
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFeatureButton(
                'สถานะสินค้า',
                'assets/images/status_icon.png',
              ),
              _buildFeatureButton('ส่งสินค้า', 'assets/images/send_icon.png'),
            ],
          ),
        ],
      ),
    );
  }

  /// สร้างปุ่มคุณสมบัติ (ใช้รูปภาพจำลองแทน IconData เพื่อให้ตรงกับรูป)
  Widget _buildFeatureButton(String text, String imagePath) {
    return Expanded(
      child: Card(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: InkWell(
          onTap: () {
            // TODO: ใส่ action เมื่อกดปุ่ม
          },
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ใช้ Icon แทน Image.asset ถ้าไม่มีรูปภาพจริงใน assets
                const Icon(
                  Icons.delivery_dining,
                  size: 40,
                  color: Color(0xFFC70808),
                ),
                const SizedBox(height: 5),
                Text(
                  text,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //------------------------------------------------------------------
  // Map Section (Google Maps Real)
  //------------------------------------------------------------------

  Widget _buildMapSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ติดตามสถานะการจัดส่ง',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            height: MediaQuery.of(context).size.height * 0.45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: GoogleMap(
                mapType: MapType.normal,
                initialCameraPosition: _initialCameraPosition,
                markers: _markers,
                // สามารถเพิ่มเส้นทาง Polylines เพื่อแสดงเส้นทางได้
                // polylines: _polylines,
                onMapCreated: (GoogleMapController controller) {
                  _controller.complete(controller);
                },
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  //------------------------------------------------------------------
  // Bottom Navigation Bar
  //------------------------------------------------------------------

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFC70808),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, -2),
            blurRadius: 5,
          ),
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
        currentIndex: 0,
        onTap: (index) {
          if (index == 2) {
            Get.offAll(() => const SpeedDerApp());
          }
          // TODO: เพิ่มการนำทางสำหรับรายการอื่น ๆ
        },
      ),
    );
  }

  //------------------------------------------------------------------
  // Profile Options Modal
  //------------------------------------------------------------------

  void _showProfileOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Divider(
                  indent: 150,
                  endIndent: 150,
                  thickness: 4,
                  color: Colors.grey,
                ),
              ),
              _buildOptionButton(
                context,
                'แก้ไขข้อมูลส่วนตัว',
                Icons.person_outline,
                () {
                  Get.to(() => const EditProfilePage());
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 24, color: const Color(0xFFC70808)),
            const SizedBox(width: 15),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

//------------------------------------------------------------------
// Custom Clipper for Header Wave
//------------------------------------------------------------------
class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 50,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
