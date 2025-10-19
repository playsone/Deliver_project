import 'dart:async'; // ต้อง Import dart:async
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/models/package_model.dart';
import 'package:delivery_project/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math' show cos, sqrt, asin, pi, atan2, sin;
import 'package:geolocator/geolocator.dart';
import 'package:rxdart/rxdart.dart' as RxDart;
import '../models/order_model.dart';
import 'package:delivery_project/page/edit_profile.dart';
import 'package:delivery_project/page/index.dart';
import 'package:delivery_project/page/package_delivery_page.dart';

class RiderHomeController extends GetxController {
  final String uid;
  final int role;
  RiderHomeController({required this.uid, required this.role});

  final Rx<UserModel?> rider = Rx(null);
  final db = FirebaseFirestore.instance;

  final Rx<GeoPoint?> riderCurrentLocation = Rx(null);
  // **สถานะใหม่: เพื่อระบุว่าการค้นหาตำแหน่งล้มเหลวเนื่องจาก Timeout**
  final RxBool locationSearchTimedOut = false.obs;

  static const double MAX_DISTANCE_METERS = 20.0;
  // **ค่าคงที่: 10 วินาทีตามที่ร้องขอ**
  static const int LOCATION_TIMEOUT_SECONDS = 10;

  @override
  void onInit() {
    super.onInit();
    _startLocationTracking();
    _checkAndNavigateToActiveOrder();
    rider.bindStream(
      db
          .collection('users')
          .doc(uid)
          .snapshots()
          .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null),
    );
  }

  void _startLocationTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Get.snackbar(
          'แจ้งเตือน GPS', 'กรุณาเปิดบริการระบุตำแหน่ง (GPS) เพื่อรับงาน');
      // ตั้งค่า Timeout เป็น true เพื่อปลดบล็อก UI หากไม่มี GPS Service เลย
      locationSearchTimedOut.value = true;
      return;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        Get.snackbar(
            'ข้อจำกัด', 'ไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง. กรุณาตั้งค่าในแอป.');
        // ตั้งค่า Timeout เป็น true หากไม่มีสิทธิ์
        locationSearchTimedOut.value = true;
        return;
      }
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    // **ส่วนที่เพิ่ม Timeout: ใช้ Future.timeout ในการรอตำแหน่งแรก 10 วินาที**
    try {
      final Position initialPosition = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: LOCATION_TIMEOUT_SECONDS));

      // ถ้าได้ตำแหน่งก่อน Timeout
      riderCurrentLocation.value =
          GeoPoint(initialPosition.latitude, initialPosition.longitude);
      log('GPS Initial Location Set: ${initialPosition.latitude}, ${initialPosition.longitude}');

      // **เริ่มติดตามตำแหน่งต่อ**
      Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
        // อัปเดตตำแหน่งทุกครั้ง
        riderCurrentLocation.value =
            GeoPoint(position.latitude, position.longitude);
        log('GPS Location Updated: ${position.latitude}, ${position.longitude}');
      }, onError: (e) {
        log('Error getting location stream: $e');
        Get.snackbar('ข้อผิดพลาด', 'ไม่สามารถติดตามตำแหน่ง GPS ได้: $e');
      });
    } on TimeoutException {
      // **เกิด Timeout**
      log('Location search timed out after $LOCATION_TIMEOUT_SECONDS seconds.');
      locationSearchTimedOut.value = true; // ตั้งค่าสถานะ Timeout เป็นจริง
      Get.snackbar('แจ้งเตือน',
          'ไม่สามารถระบุตำแหน่ง GPS ได้ภายใน 10 วินาที. โปรดลองใหม่อีกครั้ง.',
          backgroundColor: Colors.yellow.shade100, colorText: Colors.black87);
    } catch (e) {
      // ข้อผิดพลาดอื่นๆ
      log('Error getting initial location: $e');
      locationSearchTimedOut.value = true;
      Get.snackbar('ข้อผิดพลาด', 'ไม่สามารถระบุตำแหน่ง GPS ได้: $e');
    }
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

        final package = Package(
          id: orderModel.id,
          title: orderModel.orderDetails,
          location: orderModel.pickupAddress.detail,
          destination: orderModel.deliveryAddress.detail,
          imageUrl: orderModel.orderPicture,
        );
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

  // **การแก้ไข: ใช้ Firestore Transaction เพื่อป้องกันการแย่งงาน**
  Future<void> acceptOrder(OrderModel order) async {
    Get.dialog(const Center(child: CircularProgressIndicator()),
        barrierDismissible: false);
    try {
      final orderRef = db.collection('orders').doc(order.id);

      // ใช้ Transaction เพื่อให้แน่ใจว่าการอ่านและเขียนเป็น Atomic
      await db.runTransaction((transaction) async {
        final freshSnapshot = await transaction.get(orderRef);
        final freshOrder = OrderModel.fromFirestore(freshSnapshot);

        // ตรวจสอบสถานะ: ถ้าไม่ใช่ 'pending' แสดงว่ามีคนรับไปแล้ว
        if (freshOrder.currentStatus != 'pending') {
          throw Exception(
              'Order is no longer pending. Status: ${freshOrder.currentStatus}');
        }

        // อัปเดตงาน
        transaction.update(orderRef, {
          'riderId': uid,
          'currentStatus': 'accepted',
          'statusHistory': FieldValue.arrayUnion([
            {'status': 'accepted', 'timestamp': Timestamp.now()}
          ]),
        });
      });

      Get.back(); // ปิด loading dialog

      // นำทางไปยังหน้าส่งของและลบหน้า Home ออกจาก Stack
      final package = Package(
        id: order.id,
        title: order.orderDetails,
        location: order.pickupAddress.detail,
        destination: order.deliveryAddress.detail,
        imageUrl: order.orderPicture,
      );
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
        Get.snackbar('ไม่สำเร็จ', 'งานนี้ถูกรับไปแล้วโดยไรเดอร์ท่านอื่น',
            backgroundColor: Colors.red.shade100, colorText: Colors.red);
      } else {
        Get.snackbar('เกิดข้อผิดพลาด', 'ไม่สามารถรับงานนี้ได้: $e',
            backgroundColor: Colors.red.shade100, colorText: Colors.red);
      }
    }
  }
}

// -------------------------------------------------------------------
// ส่วนของ UI (RiderHomeScreen)
// -------------------------------------------------------------------

class RiderHomeScreen extends StatelessWidget {
  final String uid;
  final int role;
  const RiderHomeScreen({super.key, required this.uid, required this.role});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(RiderHomeController(uid: uid, role: role));

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
      bottomNavigationBar: _buildBottomNavigationBar(context),
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
      child: const Text('รายการงานที่รอการจัดส่ง',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  // **ปรับปรุง: ใช้ Obx ตรวจสอบตำแหน่งก่อนเริ่ม StreamBuilder**
  Widget _buildPackageList(RiderHomeController controller) {
    return Obx(() {
      final hasLocation = controller.riderCurrentLocation.value != null;

      // 1. ถ้ายังไม่มีตำแหน่ง GPS
      if (!hasLocation) {
        return const Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 10),
            Text('กำลังค้นหาตำแหน่งของคุณเพื่อแสดงงานใกล้เคียง...'),
            SizedBox(height: 5),
            Text('(ตำแหน่งจำเป็นสำหรับงานที่อยู่ในรัศมี 20 เมตร)'),
          ],
        ));
      }

      // 2. ถ้ามีตำแหน่ง GPS แล้ว
      return StreamBuilder<List<OrderModel>>(
        stream: controller.getPendingOrdersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child:
                    Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            // ข้อความนี้จะแสดงเร็วขึ้นเมื่อได้ตำแหน่ง GPS แล้ว
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                  'ไม่มีงานที่อยู่ในรัศมี ${RiderHomeController.MAX_DISTANCE_METERS} เมตรให้รับในขณะนี้\n(กรุณารอหรือขยับตำแหน่ง)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
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
    return Card(
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
            TextButton(
              onPressed: () => controller.acceptOrder(order),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF38B000),
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

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFC70808),
        boxShadow: [
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
            // เปลี่ยนเป็น Get.offAll เพื่อออกจากระบบ
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
