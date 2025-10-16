// file: lib/page/home_screen.dart

import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/models/user_model.dart';
import 'package:delivery_project/page/history_page.dart';
import 'package:flutter/foundation.dart';
import 'package:delivery_project/page/index.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// สำหรับ Flutter Map และ LatLong2
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// สำหรับ GPS
import 'package:geolocator/geolocator.dart';
import 'package:delivery_project/page/edit_profile.dart';

// Pages
import 'package:delivery_project/page/package_pickup_page.dart';
import 'package:delivery_project/page/order_status_page.dart';
import 'package:delivery_project/page/send_package_page.dart';

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
  static const LatLng _initialCenter = LatLng(16.2470, 103.2522);
  static const double _initialZoom = 14.0;

  // 2. จุดปักหมุด (ถาวร)
  List<Marker> get _fixedMarkers => [
        const Marker(
          point: LatLng(16.2427, 103.2555),
          width: 40,
          height: 40,
          child: Tooltip(
            message: 'จุดบริการ',
            child: Icon(
              Icons.pin_drop_outlined,
              color: Colors.red,
              size: 40.0,
            ),
          ),
        ),
      ];

  // 3. ตัวแปรสำหรับตำแหน่ง GPS ปัจจุบันของผู้ใช้
  LatLng? currentPos;

  // --- ตัวแปรสำหรับข้อมูลจาก Firestore ---
  UserModel? _currentUser;
  List<Marker> _orderMarkers = [];
  StreamSubscription? _ordersSubscription;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _listenToOrders();
    _getCurrentLocation(); // เรียกฟังก์ชันเพื่อค้นหาตำแหน่งเมื่อเปิดหน้า
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel(); // ยกเลิกการฟังข้อมูลเพื่อป้องกัน memory leak
    super.dispose();
  }

  // --- ฟังก์ชันดึงข้อมูลจาก Firestore ---

  /// ดึงข้อมูลผู้ใช้ที่กำลัง login อยู่
  Future<void> _fetchUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: widget.uid)
          .get();
      if (doc.docs.first.exists) {
        setState(() {
          _currentUser = UserModel.fromFirestore(doc.docs.first);
          log(_currentUser.toString());
        });
      }
    } catch (e) {
      log("Error fetching user data: $e");
      // สามารถแสดง SnackBar แจ้งเตือนได้
    }
  }

  /// ฟังข้อมูลออเดอร์แบบ Real-time จาก Firestore
  void _listenToOrders() {
    // ฟังเฉพาะออเดอร์ที่มีสถานะ 'delivering' (กำลังจัดส่ง)
    final ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: widget.uid)
        .where('currentStatus', isEqualTo: 'accepted')
        .snapshots();

    _ordersSubscription = ordersStream.listen((snapshot) {
      if (!mounted) return;
      final newMarkers = snapshot.docs
          .map((doc) {
            final data = doc.data();
            // ตรวจสอบว่ามี field 'currentLocation' และเป็นประเภท GeoPoint หรือไม่
            if (data['pickupAddress'] is! GeoPoint) return null;

            final GeoPoint position = data['pickupAddress'];
            final String orderId = doc.id;

            return Marker(
              point: LatLng(position.latitude, position.longitude),
              width: 40,
              height: 40,
              child: Tooltip(
                message: 'Order ID: $orderId',
                child: const Icon(
                  Icons.local_shipping, // ไอคอนรถส่งของ
                  color: Colors.orange,
                  size: 40.0,
                ),
              ),
            );
          })
          .whereType<Marker>()
          .toList(); // กรองค่า null ออกจาก List

      setState(() {
        _orderMarkers = newMarkers;
      });
    }, onError: (error) {
      log("Error listening to orders: $error");
    });
  }

  /// ดึงตำแหน่ง GPS ปัจจุบัน
  Future<void> _getCurrentLocation() async {
    try {
      if (kIsWeb) {
        Position pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        if (mounted) {
          setState(() {
            currentPos = LatLng(pos.latitude, pos.longitude);
          });
          mapController.move(currentPos!, 16);
        }
        log("Web Location: ${pos.latitude}, ${pos.longitude}");
      } else {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('กรุณาเปิด GPS')),
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
                const SnackBar(content: Text('การเข้าถึงตำแหน่งถูกปฏิเสธ')),
              );
            }
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'การเข้าถึงตำแหน่งถูกปฏิเสธถาวร, กรุณาไปที่การตั้งค่า')),
            );
          }
          return;
        }

        Position pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        if (mounted) {
          setState(() {
            currentPos = LatLng(pos.latitude, pos.longitude);
          });
          mapController.move(currentPos!, 16);
        }
        log("Mobile Location: ${pos.latitude}, ${pos.longitude}");
      }
    } catch (e) {
      log("Error getting location: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("เกิดข้อผิดพลาดในการดึงตำแหน่ง: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDE9E9),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              _buildMapSection(context),
              const SizedBox(height: 20),
              _buildIconButtons(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFC70808),
        onPressed: _getCurrentLocation,
        tooltip: 'ค้นหาตำแหน่งปัจจุบัน',
        child: const Icon(Icons.gps_fixed, color: Colors.white),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  // --- Header Section (แสดงข้อมูลผู้ใช้) ---
  Widget _buildHeader(BuildContext context) {
    return Stack(
      children: [
        ClipPath(
          child: Container(
            height: MediaQuery.of(context).size.height * 0.125,
            decoration: const BoxDecoration(color: Color(0xFFC70808)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'สวัสดีคุณ\n${_currentUser?.fullname ?? 'กำลังโหลด...'}',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showProfileOptions(context),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white,
                      backgroundImage: (_currentUser?.profile != null &&
                              _currentUser!.profile.isNotEmpty)
                          ? NetworkImage(_currentUser!.profile)
                          : const AssetImage('assets/image/default_avatar.png')
                              as ImageProvider, // ใส่รูป default
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Icon Buttons Section ---
  Widget _buildIconButtons() {
    goToPickup() => Get.to(() => PackagePickupPage(
          role: widget.role,
          uid: widget.uid,
        ));

    goToStatus() => Get.to(() => OrderStatusPage(
          role: widget.role,
          uid: widget.uid,
        ));
    goToSend() => Get.to(() => SendPackagePage(
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
                Icons.inventory_2,
                goToPickup,
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFeatureButton(
                'สถานะสินค้า',
                Icons.timeline,
                goToStatus,
              ),
              const SizedBox(width: 15),
              _buildFeatureButton(
                'ส่งสินค้า',
                Icons.send_rounded,
                goToSend,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureButton(String text, IconData icon, VoidCallback onTap) {
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
                Icon(
                  icon,
                  size: 40,
                  color: const Color(0xFFC70808),
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

  // --- Map Section (รวม Marker ทั้งหมด) ---
  Widget _buildMapSection(BuildContext context) {
    List<Marker> allMarkers = [
      ..._fixedMarkers, // หมุดถาวร
      ..._orderMarkers, // หมุดจาก Firestore (real-time)
      if (currentPos != null)
        Marker(
          point: currentPos!,
          width: 40,
          height: 40,
          child: const Tooltip(
            message: 'ตำแหน่งปัจจุบันของคุณ',
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
                    subdomains: const ['a', 'b', 'c'],
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

  // --- Bottom Navigation Bar ---
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
            label: 'ประวัติการส่ง',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: 'ออกจากระบบ',
          ),
        ],
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) {
            // อยู่หน้าแรกอยู่แล้ว ไม่ต้องทำอะไร หรือจะ refresh ก็ได้
          } else if (index == 1) {
            Get.to(() => HistoryPage(
                  uid: widget.uid,
                  role: widget.role,
                ));
          } else if (index == 2) {
            Get.offAll(() => const SpeedDerApp()); // กลับไปหน้าแรกของแอป
          }
        },
      ),
    );
  }

  // --- Profile Options Modal ---
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
                  Get.back(); // ปิด Modal ก่อน
                  Get.to(() => EditProfilePage(
                        role: widget.role,
                        uid: widget.uid,
                      ));
                },
              ),
              // สามารถเพิ่มปุ่มอื่นๆ ได้ที่นี่
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
