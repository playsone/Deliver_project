import 'dart:developer'; // สำหรับ log()
import 'package:delivery_project/page/history_page.dart';
import 'package:delivery_project/page/order_status_page.dart';
import 'package:delivery_project/page/send_package_page.dart';
import 'package:flutter/foundation.dart'; // สำหรับ kIsWeb
import 'package:delivery_project/page/index.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/get_navigation.dart';

// สำหรับ Flutter Map และ LatLong2
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// สำหรับ GPS
import 'package:geolocator/geolocator.dart';
import 'package:delivery_project/page/edit_profile.dart';

// **เพิ่ม Import สำหรับหน้าใหม่ (สมมติว่าคุณได้สร้างไฟล์เหล่านี้แล้ว)**
// import 'package:delivery_project/page/order_status_page.dart';
// import 'package:delivery_project/page/send_package_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 1. ตัวแปรสำหรับ Flutter Maps
  final MapController mapController = MapController();

  // พิกัดเริ่มต้น
  static final LatLng _initialCenter = LatLng(16.4858, 102.8222);
  static const double _initialZoom = 14.0;

  // 2. จุดปักหมุด
  List<Marker> get _fixedMarkers => [
        // Marker สำหรับจุดหมายปลายทาง (หอพักอาณาจักรฟ้า)
        Marker(
          point: LatLng(16.4858, 102.8222),
          width: 40,
          height: 40,
          child: const Tooltip(
            message: 'หอพักอาณาจักรฟ้า',
            child: Icon(
              Icons.pin_drop,
              color: Color(0xFFC70808),
              size: 40.0,
            ),
          ),
        ),
        // Marker สำหรับไรเดอร์ (ตัวอย่าง)
        Marker(
          point: LatLng(16.4900, 102.8180),
          width: 40,
          height: 40,
          child: const Tooltip(
            message: 'ไรเดอร์กำลังมา',
            child: Icon(
              Icons.two_wheeler,
              color: Colors.blue,
              size: 40.0,
            ),
          ),
        ),
      ];

  // 3. ตัวแปรสำหรับตำแหน่ง GPS ปัจจุบัน
  LatLng? currentPos;

  // 4. ฟังก์ชันดึงตำแหน่ง GPS
  Future<void> _getCurrentLocation() async {
    try {
      if (kIsWeb) {
        // บน Web
        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          currentPos = LatLng(pos.latitude, pos.longitude);
        });
        mapController.move(currentPos!, 16);
        log("Web Location: ${pos.latitude}, ${pos.longitude}");
      } else {
        // Mobile (รวมถึงการขออนุญาต)
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location services are disabled.')),
            );
          }
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Location permissions are denied')),
              );
            }
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permissions are permanently denied.'),
              ),
            );
          }
          return;
        }

        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          currentPos = LatLng(pos.latitude, pos.longitude);
        });
        // เลื่อนแผนที่ไปตำแหน่งปัจจุบัน
        mapController.move(currentPos!, 16);
        log("Mobile Location: ${pos.latitude}, ${pos.longitude}");
      }
    } catch (e) {
      log("Error getting location: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error getting location: $e")));
      }
    }
  }

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
              // วิดเจ็ตแผนที่ Flutter Map
              _buildMapSection(context),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      // เพิ่มปุ่ม Floating Action Button เพื่อดึงตำแหน่ง GPS
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFC70808),
        onPressed: _getCurrentLocation,
        tooltip: 'ค้นหาตำแหน่งปัจจุบัน',
        child: const Icon(Icons.gps_fixed, color: Colors.white),
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
  // Icon Buttons Section
  //------------------------------------------------------------------

  Widget _buildIconButtons() {
    // สมมติว่ามีการ Import OrderStatusPage และ SendPackagePage แล้ว
    // ถ้ายังไม่มี ให้เปลี่ยน Get.to() เป็น log() หรือสร้างหน้าจำลอง

    // ตัวอย่างการใช้ Get.to() สำหรับหน้าใหม่ (ต้องสร้างไฟล์ Page ก่อน)

    final VoidCallback goToStatus = () => Get.to(() => const OrderStatusPage());
    final VoidCallback goToSend = () => Get.to(() => const SendPackagePage());

    // ใช้ log() แทน จนกว่าจะสร้างหน้า OrderStatusPage/SendPackagePage จริง
    // final VoidCallback goToStatus = () => log('Navigate to OrderStatusPage');
    // final VoidCallback goToSend = () => log('Navigate to SendPackagePage');

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
                () {
                  // TODO: action พัสดุที่ต้องรับ
                },
              ),
              _buildFeatureButton(
                'ข้อมูลไรเดอร์',
                'assets/images/rider_icon.png',
                () {
                  // TODO: action ข้อมูลไรเดอร์
                },
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
                goToStatus, // ใช้ action สำหรับดูสถานะสินค้า
              ),
              _buildFeatureButton(
                'ส่งสินค้า',
                'assets/images/send_icon.png',
                goToSend, // ใช้ action สำหรับส่งสินค้า
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// สร้างปุ่มคุณสมบัติ (ปรับปรุงให้รับ onTap)
  Widget _buildFeatureButton(
    String text,
    String imagePath,
    VoidCallback onTap, // <--- เพิ่ม VoidCallback สำหรับ Action
  ) {
    return Expanded(
      child: Card(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: InkWell(
          onTap: onTap, // <--- ใช้ onTap ที่นี่
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
  // Map Section (ใช้ Flutter Map แทน Google Maps)
  //------------------------------------------------------------------

  Widget _buildMapSection(BuildContext context) {
    // รวม Marker ทั้งหมด: Marker ตำแหน่งคงที่ + Marker ตำแหน่งปัจจุบัน (ถ้ามี)
    List<Marker> allMarkers = [
      ..._fixedMarkers,
      if (currentPos != null)
        Marker(
          point: currentPos!,
          width: 40,
          height: 40,
          child: const Tooltip(
            message: 'ตำแหน่งปัจจุบัน',
            child: Icon(
              Icons.my_location,
              color: Colors.green, // ใช้สีเขียวสำหรับตำแหน่งปัจจุบัน
              size: 40,
            ),
          ),
        ),
    ];

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
              // 5. เปลี่ยนมาใช้ FlutterMap
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: _initialCenter, // พิกัดเริ่มต้น
                  initialZoom: _initialZoom, // ซูมเริ่มต้น
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                  onTap: (tapPosition, point) {
                    log("Map tapped at: $point");
                  },
                ),
                children: [
                  // 6. ใช้ TileLayer สำหรับโหลดแผนที่
                  TileLayer(
                    urlTemplate:
                        'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=cb153d15cb4e41f59e25cfda6468f1a0',
                    userAgentPackageName: "com.example.delivery_project",
                  ),
                  // 7. ใช้ MarkerLayer สำหรับแสดงหมุด
                  MarkerLayer(markers: allMarkers),
                ],
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
        currentIndex: 0, // หน้าแรกถูกเลือกอยู่
        onTap: (index) {
          if (index == 0) {
            // อยู่หน้า Home อยู่แล้ว ไม่ต้องทำอะไร
          } else if (index == 1) {
            // 🚀 นำทางไปหน้าประวัติการส่งสินค้า
            Get.to(() => const HistoryPage());
          } else if (index == 2) {
            Get.offAll(() => const SpeedDerApp()); // Log out
          }
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
// Custom Clipper for Header Wave (ไม่ได้ใช้งานในโค้ดที่ให้มา แต่เพื่อความสมบูรณ์)
//-----------------------------------------------------------------
/*
class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    // ... โค้ดสำหรับวาดคลื่น ...
    return Path();
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
*/
