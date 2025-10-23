import 'dart:async';
import 'dart:developer';
import 'dart:math' show cos, sqrt, asin, pi, atan2, sin;

import 'package:cloud_firestore/cloud_firestore.dart';
// Note: Flutter Map and Geolocator are not used in this specific file,
// but their imports are kept for potential future use.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:geolocator/geolocator.dart'; 
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:rxdart/rxdart.dart' as RxDart;


// ------------------------------------------------------------------
// ** MOCK/Placeholder Models and Pages (Required by imports) **
// ------------------------------------------------------------------

// Placeholder for external files
class Package {}
class UserModel {}
class SpeedDerApp extends StatelessWidget { const SpeedDerApp({super.key}); @override Widget build(BuildContext context) => const Text('App Index'); }
class EditProfilePage extends StatelessWidget { final String uid; final int role; const EditProfilePage({super.key, required this.uid, required this.role}); @override Widget build(BuildContext context) => const Text('Edit Profile'); }
class PackageDeliveryPage extends StatelessWidget { final Package package; final String uid; final int role; const PackageDeliveryPage({super.key, required this.package, required this.uid, required this.role}); @override Widget build(BuildContext context) => const Text('Delivery Page'); }
class PackageDetailScreen extends StatelessWidget { final dynamic order; final dynamic riderController; const PackageDetailScreen({super.key, required this.order, required this.riderController}); @override Widget build(BuildContext context) => const Text('Package Detail'); }


// Mock AddressModel
class AddressModel {
  final String detail;
  final GeoPoint? gps;
  AddressModel({required this.detail, this.gps});

  factory AddressModel.fromMap(Map<String, dynamic> data) {
    return AddressModel(
      detail: data['detail'] ?? '',
      gps: data['gps'] as GeoPoint?,
    );
  }
}

// Mock OrderModel (Must match fields used by RiderHomeController)
class OrderModel {
  final String id;
  final String customerId;
  final String orderDetails;
  final String? orderPicture; // Used in _buildPackageCard
  final String currentStatus;
  final AddressModel pickupAddress;
  final AddressModel deliveryAddress;

  OrderModel({
    required this.id,
    required this.customerId,
    required this.orderDetails,
    this.orderPicture,
    required this.currentStatus,
    required this.pickupAddress,
    required this.deliveryAddress,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) throw Exception("Document data is null.");

    return OrderModel(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      orderDetails: data['orderDetails'] ?? '',
      orderPicture: data['orderPicture'] as String?,
      currentStatus: data['currentStatus'] ?? 'pending',
      pickupAddress: AddressModel.fromMap(data['pickupAddress'] ?? {}),
      deliveryAddress: AddressModel.fromMap(data['deliveryAddress'] ?? {}),
    );
  }
}


// ------------------------------------------------------------------
// Controller: RiderHomeController
// ------------------------------------------------------------------

class RiderHomeController extends GetxController {
  final String uid;
  final int role;
  RiderHomeController({required this.uid, required this.role});

  final Rx<UserModel?> rider = Rx(null);
  final db = FirebaseFirestore.instance;

  final Rx<GeoPoint?> riderCurrentLocation = Rx(null);
  // แก้ไข: ใช้ MAX_DISTANCE_METERS จากโค้ดที่ผู้ใช้ให้มา (20.0)
  static const double MAX_DISTANCE_METERS = 20.0;

  @override
  void onInit() {
    super.onInit();
    _startLocationTracking();
    _checkAndNavigateToActiveOrder();
    // จำลองการ bindStream ของ Rider
    rider.bindStream(
      db
          .collection('users')
          .doc(uid)
          .snapshots()
          .map((doc) => doc.exists ? UserModel() : null), // ใช้ UserModel Placeholder
    );
  }

  void _startLocationTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Get.snackbar(
          'แจ้งเตือน GPS', 'กรุณาเปิดบริการระบุตำแหน่ง (GPS) เพื่อรับงาน');
      return;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        Get.snackbar(
            'ข้อจำกัด', 'ไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง. กรุณาตั้งค่าในแอป.');
        return;
      }
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    // ใช้ Geolocator จริง
    Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position position) {
      riderCurrentLocation.value =
          GeoPoint(position.latitude, position.longitude);
      log('GPS Location Updated: ${position.latitude}, ${position.longitude}');
    }, onError: (e) {
      log('Error getting location: $e');
      Get.snackbar('ข้อผิดพลาด', 'ไม่สามารถติดตามตำแหน่ง GPS ได้: $e');
    });
  }

  double _calculateDistanceMeters(GeoPoint riderLoc, GeoPoint pickupLoc) {
    const double R = 6371000;

    final double lat1 = riderLoc.latitude;
    final double lon1 = riderLoc.longitude;
    final double lat2 = pickupLoc.latitude;
    final double lon2 = pickupLoc.longitude;

    final double dLat = (lat2 - lat1) * (pi / 180.0);
    final double dLon = (lon2 - lon1) * (pi / 180.0);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) *
            cos(lat2 * (pi / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  Future<void> _checkAndNavigateToActiveOrder() async {
    try {
      final querySnapshot = await db
          .collection('orders')
          .where('riderId', isEqualTo: uid)
          .where('currentStatus',
              whereIn: ['accepted', 'picked_up', 'in_transit'])
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final activeOrderDoc = querySnapshot.docs.first;
        final orderModel = OrderModel.fromFirestore(activeOrderDoc);

        log('Rider has an active order: ${orderModel.id}. Navigating...');

        final package = Package(); // ใช้ Placeholder
        // แทนที่การสร้าง Package ด้วยข้อมูลจริงที่จำเป็น
        // เนื่องจากไม่มีโครงสร้าง PackageModel ที่แน่ชัดในโค้ด
        // จึงต้องใช้ Placeholder
        
        Get.offAll(() => PackageDeliveryPage(
              package: package,
              uid: uid,
              role: role,
            ));
      } else {
        log('Rider has no active orders. Showing pending list.');
      }
    } catch (e) {
      log('Error checking for active order: $e');
    }
  }

  // ใช้ RxDart.switchMap เพื่อเปลี่ยน Stream เมื่อ riderCurrentLocation เปลี่ยน
  Stream<List<OrderModel>> getPendingOrdersStream() {
    return riderCurrentLocation.stream.switchMap((riderLoc) {
      if (riderLoc == null) {
        log('Rider location is not available, returning empty list.');
        return Stream.value([]);
      }

      return db
          .collection('orders')
          .where('currentStatus', isEqualTo: 'pending')
          .snapshots()
          .map((snapshot) {
        final allPendingOrders =
            snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
        final filteredOrders = allPendingOrders.where((order) {
          final GeoPoint? pickupGps = order.pickupAddress.gps;
          if (pickupGps == null) {
            log('Order ${order.id} skipped: Pickup GPS is missing.');
            return false;
          }

          final distance = _calculateDistanceMeters(riderLoc, pickupGps);
          if (distance <= MAX_DISTANCE_METERS) {
            log('Order ${order.id} is ${distance.toStringAsFixed(2)}m away - ACCEPTED');
            return true;
          } else {
            log('Order ${order.id} is ${distance.toStringAsFixed(2)}m away - REJECTED (Max: $MAX_DISTANCE_METERS m)');
            return false;
          }
        }).toList();

        return filteredOrders;
      });
    });
  }

  // **ฟังก์ชันรับงาน พร้อมระบบป้องกันการรับงานพร้อมกันด้วย Transaction**
  Future<void> acceptOrder(OrderModel order) async {
    Get.dialog(const Center(child: CircularProgressIndicator(color: Color(0xFFC70808))),
        barrierDismissible: false);
    try {
      final orderRef = db.collection('orders').doc(order.id);

      // ใช้ Transaction เพื่อให้แน่ใจว่าการอ่าน (สถานะ) และการเขียน (riderId) เป็น Atomic
      await db.runTransaction((transaction) async {
        final freshSnapshot = await transaction.get(orderRef);
        final freshOrder = OrderModel.fromFirestore(freshSnapshot);

        // 1. ตรวจสอบสถานะอีกครั้ง: ถ้าสถานะไม่ใช่ 'pending' แสดงว่ามีคนรับไปแล้ว
        if (freshOrder.currentStatus != 'pending') {
          throw Exception(
              'Order is no longer pending. Status: ${freshOrder.currentStatus}');
        }

        // 2. ถ้าสถานะยังเป็น 'pending' ให้อัปเดตสถานะและ riderId
        transaction.update(orderRef, {
          'riderId': uid,
          'currentStatus': 'accepted',
          'statusHistory': FieldValue.arrayUnion([
            {'status': 'accepted', 'timestamp': Timestamp.now()}
          ]),
        });
      });

      Get.back(); // ปิด loading dialog

      Get.snackbar('รับงานสำเร็จ', 'งาน #${order.id.substring(0, 8)} ถูกรับเรียบร้อยแล้ว!', 
        backgroundColor: Colors.green, colorText: Colors.white);

      // นำทางไปยังหน้าส่งของและลบหน้า Home ออกจาก Stack
      final package = Package(); // ใช้ Placeholder
      // ต้องสร้าง Package object ให้ครบตามที่ PackageDeliveryPage ต้องการ
      // (ถ้ามี PackageModel จริง ต้องดึงข้อมูลมาสร้างตรงนี้)
      
      Get.offAll(() => PackageDeliveryPage( 
            package: package,
            uid: uid,
            role: role,
          ));
    } catch (e) {
      Get.back(); // ปิด loading dialog
      log('Error accepting order: $e');

      // แสดงข้อความตามชนิดของ Error
      if (e.toString().contains('Order is no longer pending')) {
        Get.snackbar('ไม่สำเร็จ', 'งานนี้ถูกรับไปแล้วโดยไรเดอร์ท่านอื่น กรุณาเลือกงานใหม่',
            backgroundColor: Colors.red.shade100, colorText: Colors.red);
      } else {
        Get.snackbar('เกิดข้อผิดพลาด', 'ไม่สามารถรับงานนี้ได้: $e',
            backgroundColor: Colors.red.shade100, colorText: Colors.red);
      }
    }
  }
}

// ------------------------------------------------------------------
// View: RiderHomeScreen
// ------------------------------------------------------------------
class RiderHomeScreen extends StatelessWidget {
  final String uid;
  final int role;
  const RiderHomeScreen({super.key, required this.uid, required this.role});

  @override
  Widget build(BuildContext context) {
    // ต้อง Get.put() ก่อนใช้ Obx
    final controller = Get.put(RiderHomeController(uid: uid, role: role));
    const primaryColor = Color(0xFFC70808);

    return Scaffold(
      backgroundColor: const Color(0xFFFDE9E9),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, controller),
            _buildContentHeader(),
            Expanded(
              child: _buildPackageList(controller),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context, primaryColor),
    );
  }

  Widget _buildHeader(BuildContext context, RiderHomeController controller) {
    return Obx(() {
      final riderData = controller.rider.value;
      String riderName = riderData?.fullname ?? 'ไรเดอร์';
      String profileImageUrl = riderData?.profile ??
          'https://cdn-icons-png.flaticon.com/512/1144/1144760.png';

      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFFC70808),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(50),
            bottomRight: Radius.circular(50),
          ),
        ),
        padding:
            const EdgeInsets.only(left: 20, right: 20, top: 40, bottom: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'สวัสดีคุณ $riderName',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            GestureDetector(
              onTap: () => _showProfileOptions(context, uid, role),
              child: CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(profileImageUrl),
                backgroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildContentHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      margin: const EdgeInsets.only(top: 20, left: 20, right: 20),
      decoration: BoxDecoration(
        color: Colors.grey[600],
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Colors.black12, offset: Offset(0, 2), blurRadius: 4),
        ],
      ),
      child: const Text('รายการงานที่อยู่ในรัศมี',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPackageList(RiderHomeController controller) {
    return Obx(() {
      final hasLocation = controller.riderCurrentLocation.value != null;
      const primaryColor = Color(0xFFC70808);

      if (!hasLocation) {
        return Center(
            child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 30, 
                height: 30, 
                child: CircularProgressIndicator(strokeWidth: 3, color: primaryColor)), 
              const SizedBox(height: 15),
              Text(
                'กำลังระบุตำแหน่ง GPS',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey[800], fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text('(โปรดรอสักครู่และตรวจสอบว่า GPS ทำงานอยู่)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            ],
          ),
        ));
      }

      return StreamBuilder<List<OrderModel>>(
        stream: controller.getPendingOrdersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('กำลังโหลดรายการงาน...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                  '✅ ตำแหน่งยืนยันแล้ว:\nไม่มีงานที่อยู่ในรัศมี ${RiderHomeController.MAX_DISTANCE_METERS} เมตรให้รับในขณะนี้',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[700], fontWeight: FontWeight.bold)),
            ));
          }

          final orders = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _buildPackageCard(context, order, controller);
            },
          );
        },
      );
    });
  }

  Widget _buildPackageCard(
      BuildContext context, OrderModel order, RiderHomeController controller) {
    
    const acceptColor = Color(0xFF38B000); // สีเขียวสำหรับปุ่มรับงาน

    return InkWell(
      // ** เมื่อแตะที่ Card จะนำไปยังหน้า PackageDetailScreen **
      onTap: () {
        Get.to(() => PackageDetailScreen(order: order, riderController: controller));
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 15),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  image: order.orderPicture != null
                      ? DecorationImage(
                          image: NetworkImage(order.orderPicture!),
                          fit: BoxFit.cover)
                      : null,
                ),
                child: order.orderPicture == null
                    ? const Icon(Icons.inventory_2_outlined,
                        size: 40, color: Colors.black54)
                    : null,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.orderDetails,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFFC70808)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    _buildPackageDetailRow(
                        Icons.store, 'ต้นทาง: ${order.pickupAddress.detail}'),
                    _buildPackageDetailRow(Icons.location_on,
                        'ปลายทาง: ${order.deliveryAddress.detail}'),
                  ],
                ),
              ),
              // ** ปุ่มรับงาน **
              TextButton(
                onPressed: () => controller.acceptOrder(order),
                style: TextButton.styleFrom(
                  backgroundColor: acceptColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('รับงาน',
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackageDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 5),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: primaryColor,
        boxShadow: const [
          BoxShadow(color: Colors.black12, offset: Offset(0, -2), blurRadius: 5)
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
              icon: Icon(Icons.logout), label: 'ออกจากระบบ'),
        ],
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            Get.offAll(() => const SpeedDerApp());
          }
        },
      ),
    );
  }

  void _showProfileOptions(BuildContext context, String uid, int role) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20), topRight: Radius.circular(20)),
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
                    color: Colors.grey),
              ),
              _buildOptionButton(
                  context, 'แก้ไขข้อมูลส่วนตัว', Icons.person_outline, () {
                Get.to(() => EditProfilePage(uid: uid, role: role));
              }),
              _buildOptionButton(context, 'ออกจากระบบ', Icons.logout, () {
                Get.offAll(() => const SpeedDerApp());
              }),
              const SizedBox(height: 20),
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
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
