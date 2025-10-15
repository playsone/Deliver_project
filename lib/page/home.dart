import 'dart:developer'; // สำหรับ log()
import 'package:delivery_project/page/history_page.dart';
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

// ** 🚀 เพิ่ม Import สำหรับหน้าใหม่ทั้งหมด **
import 'package:delivery_project/page/rider_info_page.dart'; // ข้อมูลไรเดอร์
import 'package:delivery_project/page/package_pickup_page.dart'; // พัสดุที่ต้องรับ
import 'package:delivery_project/page/order_status_page.dart'; // สถานะสินค้า
import 'package:delivery_project/page/send_package_page.dart'; // ส่งสินค้า

class HomeScreen extends StatefulWidget {
  final String uid;
  final int role;
  const HomeScreen({super.key, required this.uid, required this.role});

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
        const Marker(
          point: LatLng(16.4858, 102.8222),
          width: 40,
          height: 40,
          child: Tooltip(
            message: 'หอพักอาณาจักรฟ้า',
            child: Icon(
              Icons.pin_drop,
              color: Color(0xFFC70808),
              size: 40.0,
            ),
          ),
        ),
        // Marker สำหรับไรเดอร์ (ตัวอย่าง)
        const Marker(
          point: LatLng(16.4900, 102.8180),
          width: 40,
          height: 40,
          child: Tooltip(
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

  // ------------------------------------------------------------------
  // Header Section
  // ------------------------------------------------------------------

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

  // ------------------------------------------------------------------
  // Icon Buttons Section (แก้ไขการนำทาง)
  // ------------------------------------------------------------------

  Widget _buildIconButtons() {
    final VoidCallback goToPickup = () => Get.to(() => PackagePickupPage(
          role: widget.role,
          uid: widget.uid,
        ));
    final VoidCallback goToRiderInfo = () => Get.to(() => RiderInfoPage(
          role: widget.role,
          uid: widget.uid,
        ));
    final VoidCallback goToStatus = () => Get.to(() => OrderStatusPage(
          role: widget.role,
          uid: widget.uid,
          orderId: '',
        ));
    final VoidCallback goToSend = () => Get.to(() => SendPackagePage(
          role: widget.role,
          uid: widget.uid,
        ));

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
                goToPickup,
              ),
              _buildFeatureButton(
                'ข้อมูลไรเดอร์',
                'assets/images/rider_icon.png',
                goToRiderInfo,
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
                goToStatus,
              ),
              _buildFeatureButton(
                'ส่งสินค้า',
                'assets/images/send_icon.png',
                goToSend,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// สร้างปุ่มคุณสมบัติ (Feature Button)
  Widget _buildFeatureButton(
      String text, String imagePath, VoidCallback onTap) {
    return Expanded(
      child: Card(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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

  // ------------------------------------------------------------------
  // Map Section
  // ------------------------------------------------------------------

  Widget _buildMapSection(BuildContext context) {
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
              color: Colors.green,
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
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: _initialCenter,
                  initialZoom: _initialZoom,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                  onTap: (tapPosition, point) {
                    log("Map tapped at: $point");
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=cb153d15cb4e41f59e25cfda6468f1a0',
                    userAgentPackageName: "com.example.delivery_project",
                  ),
                  MarkerLayer(markers: allMarkers),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Bottom Navigation Bar
  // ------------------------------------------------------------------

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
          if (index == 0) {
            Get.to(() => HomeScreen(
                  uid: widget.uid,
                  role: widget.role,
                ));
          } else if (index == 1) {
            Get.to(() => HistoryPage(
                  uid: widget.uid,
                  role: widget.role,
                ));
          } else if (index == 2) {
            Get.offAll(() => const SpeedDerApp()); // Log out
          }
        },
      ),
    );
  }

  // ------------------------------------------------------------------
  // Profile Options Modal
  // ------------------------------------------------------------------

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
                  Get.to(() => EditProfilePage(
                        role: widget.role,
                        uid: widget.uid,
                      ));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionButton(
      BuildContext context, String title, IconData icon, VoidCallback onTap) {
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

/*
//------------------------------------------------------------------
// Custom Clipper for Header Wave (ไม่ได้ใช้งานในโค้ดนี้)
//------------------------------------------------------------------
class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
*/
