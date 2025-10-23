// file: lib/page/home_rider.dart

import 'dart:async'; // [สำคัญ] สำหรับ .timeout()
import 'dart:developer';
import 'dart:math' show cos, sqrt, asin, pi, atan2, sin;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
// [ลบออก] rxdart ไม่จำเป็นแล้ว
// import 'package:rxdart/rxdart.dart' as RxDart;

// Models
import '../models/order_model.dart';
// Pages
import 'package:delivery_project/page/edit_profile.dart';
import 'package:delivery_project/page/package_delivery_page.dart';
import 'package:delivery_project/page/order_detail_page.dart';

// ------------------------------------------------------------------
// Controller (ส่วนจัดการ Logic)
// [แก้ไข] เอา State ที่ซับซ้อนออก
// ------------------------------------------------------------------
class RiderHomeController extends GetxController {
  final String uid;
  final int role;
  RiderHomeController({required this.uid, required this.role});

  // --- State ---
  final Rx<UserModel?> rider = Rx(null);
  final db = FirebaseFirestore.instance;

  // --- State สำหรับ Location ---
  final Rx<GeoPoint?> riderCurrentLocation = Rx(null);
  static const double MAX_DISTANCE_METERS = 20.0;
  StreamSubscription<Position>? _positionStreamSubscription;

  // --- [ลบออก] State ที่ซับซ้อน ---
  // final RxBool isLoading = true.obs;
  // final RxBool didTimeout = false.obs;
  // final Rx<List<OrderModel>> pendingOrders = Rx(<OrderModel>[]);
  // Timer? _initialLoadTimer;
  // StreamSubscription? _ordersSubscription;
  // ---------------------------------

  @override
  void onInit() {
    super.onInit();
    // 1. ตรวจสอบงานที่ค้างอยู่ก่อน
    _checkAndNavigateToActiveOrder();

    // 2. เริ่มติดตามตำแหน่ง GPS
    _startLocationTracking();

    // 3. ฟังข้อมูล Rider
    rider.bindStream(
      db
          .collection('users')
          .doc(uid)
          .snapshots()
          .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null),
    );

    // 4. [ลบออก] ไม่ต้องโหลดข้อมูลและจับเวลาที่นี่
    // _loadInitialData();
  }

  // [ลบออก] ฟังก์ชัน _loadInitialData, _subscribeToOrders, reloadData
  // เพราะ StreamBuilder จะจัดการเอง

  @override
  void onClose() {
    // [สำคัญ] หยุดการติดตาม GPS
    _positionStreamSubscription?.cancel();
    super.onClose();
  }

  // (ฟังก์ชัน _startLocationTracking ไม่เปลี่ยนแปลง)
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
      distanceFilter: 5,
    );
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
            (Position position) {
      riderCurrentLocation.value =
          GeoPoint(position.latitude, position.longitude);
      // [แก้ไข] เราไม่ log ที่นี่แล้ว เพราะจะ log ใน StreamBuilder
    }, onError: (e) {
      log('Error getting location stream: $e');
      Get.snackbar('ข้อผิดพลาด', 'ไม่สามารถติดตามตำแหน่ง GPS ได้: $e');
    });
  }

  // (ฟังก์ชัน _calculateDistanceMeters ไม่เปลี่ยนแปลง)
  double _calculateDistanceMeters(GeoPoint loc1, GeoPoint loc2) {
    const double R = 6371000;
    final double lat1 = loc1.latitude;
    final double lon1 = loc1.longitude;
    final double lat2 = loc2.latitude;
    final double lon2 = loc2.longitude;
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

  // (ฟังก์ชัน _checkAndNavigateToActiveOrder ไม่เปลี่ยนแปลง)
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

  // --- [แก้ไข] Stream ให้รับ riderLoc เข้ามา ---
  // และเพิ่ม .timeout()
  // ---------------------------------------
  Stream<List<OrderModel>> getPendingOrdersStream(GeoPoint riderLoc) {
    // [สำคัญ] เราใช้ riderLoc ที่ส่งเข้ามาเลย ไม่ต้องใช้ .switchMap
    return db
        .collection('orders')
        .where('currentStatus', isEqualTo: 'pending')
        .snapshots() // ดึงข้อมูล Realtime
        .map((snapshot) {
      // Logic การกรองข้อมูล
      final allPendingOrders =
          snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();

      final filteredOrders = allPendingOrders.where((order) {
        final GeoPoint pickupGps = order.pickupAddress.gps;
        if (pickupGps.latitude == 0 && pickupGps.longitude == 0) {
          // log('Order ${order.id} skipped: GPS (0,0).');
          return false;
        }
        final distance = _calculateDistanceMeters(riderLoc, pickupGps);
        if (distance <= MAX_DISTANCE_METERS) {
          log('Order ${order.id} is ${distance.toStringAsFixed(2)}m away - ACCEPTED');
          return true;
        } else {
          return false;
        }
      }).toList();

      return filteredOrders;
    })
        // [สำคัญ] เพิ่มการดักจับ Timeout 5 วินาที
        // ถ้า Firestore ไม่ส่งข้อมูลแรก (เช่น query ช้า) ภายใน 5 วิ, มันจะโยน Error
        .timeout(
      const Duration(seconds: 60),
      onTimeout: (sink) {
        sink.addError(
            TimeoutException('ไม่สามารถโหลดข้อมูลได้ใน 5 วินาที (Timeout)'));
      },
    );
  }

  // (ฟังก์ชัน navigateToOrderDetails ไม่เปลี่ยนแปลง)
  void navigateToOrderDetails(OrderModel order) {
    if (riderCurrentLocation.value == null) {
      Get.snackbar('ข้อผิดพลาด', 'ยังไม่สามารถระบุตำแหน่งของคุณได้');
      return;
    }
    Get.to(() => OrderDetailPage(
          order: order,
          riderLocation: riderCurrentLocation.value!,
        ));
  }

  // (ฟังก์ชัน acceptOrder ไม่เปลี่ยนแปลง)
  Future<void> acceptOrder(OrderModel order) async {
    Get.dialog(const Center(child: CircularProgressIndicator()),
        barrierDismissible: false);
    try {
      final orderRef = db.collection('orders').doc(order.id);
      await db.runTransaction((transaction) async {
        final freshSnapshot = await transaction.get(orderRef);
        final freshOrder = OrderModel.fromFirestore(freshSnapshot);
        if (freshOrder.currentStatus != 'pending') {
          throw Exception('งานนี้ถูกรับไปแล้ว');
        }
        transaction.update(orderRef, {
          'riderId': uid,
          'currentStatus': 'accepted',
          'statusHistory': FieldValue.arrayUnion([
            {'status': 'accepted', 'timestamp': Timestamp.now()}
          ]),
        });
      });
      Get.back(); // ปิด Loading
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
      Get.back();
      log('Error accepting order: $e');
      if (e.toString().contains('งานนี้ถูกรับไปแล้ว')) {
        Get.snackbar('ไม่สำเร็จ', 'งานนี้ถูกรับไปแล้วโดยไรเดอร์ท่านอื่น',
            backgroundColor: Colors.red.shade100, colorText: Colors.red);
        Get.offAll(() => RiderHomeScreen(uid: uid, role: role));
      } else {
        Get.snackbar('เกิดข้อผิดพลาด', 'ไม่สามารถรับงานนี้ได้: $e',
            backgroundColor: Colors.red.shade100, colorText: Colors.red);
      }
    }
  }
}

// ------------------------------------------------------------------
// Rider Home Screen (ส่วน UI)
// [แก้ไข] _buildPackageList ให้ใช้ StreamBuilder
// ------------------------------------------------------------------
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
              child: _buildPackageList(controller), // [แก้ไข]
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  // (Header ไม่เปลี่ยนแปลง)
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

  // (ContentHeader ไม่เปลี่ยนแปลง)
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

  // --- [แก้ไข] Widget รายการงาน (ใช้ Obx + StreamBuilder) ---
  Widget _buildPackageList(RiderHomeController controller) {
    return Obx(() {
      final riderLoc = controller.riderCurrentLocation.value;

      // --- State 1: No GPS Location ---
      if (riderLoc == null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 15),
                Text(
                  'กำลังระบุตำแหน่ง GPS...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  '(กรุณาเปิด GPS และรอสักครู่)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      }

      // --- State 2: Has GPS, Load Stream ---
      // เมื่อมี GPS แล้ว ให้ StreamBuilder ทำงาน
      return StreamBuilder<List<OrderModel>>(
        // [สำคัญ] ส่งตำแหน่ง GPS ที่แน่นอนไปให้ Stream
        stream: controller.getPendingOrdersStream(riderLoc),
        builder: (context, snapshot) {
          // --- State 2a: Stream is Loading ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            // นี่คือหน้าใน Screenshot ของคุณ
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // [แก้ไข] ทำให้เหมือนในรูป
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'กำลังค้นหางานในระยะ ${RiderHomeController.MAX_DISTANCE_METERS} เมตร...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // --- State 2b: Stream has Error (เช่น Timeout) ---
          if (snapshot.hasError) {
            log('Error in StreamBuilder: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer_off_outlined,
                        size: 60, color: Colors.grey[700]),
                    const SizedBox(height: 15),
                    const Text(
                      'ไม่สามารถโหลดข้อมูลได้',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${snapshot.error}', // แสดง Error (เช่น Timeout)
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('ลองใหม่'),
                      onPressed: () {
                        // [แก้ไข] UI ไม่สามารถเรียก reloadData() ได้
                        // เราต้องบอกให้ GetX "Rebuild" Widget นี้
                        // วิธีที่ง่ายคือบังคับให้ GPS update (ซึ่งจะ trigger Obx)
                        // แต่ที่จริงแล้ว StreamBuilder จะลองใหม่เองถ้า State เปลี่ยน
                        // การใช้วิธี .refresh() ของ GetX จะดีที่สุด
                        // แต่เพื่อความง่าย:
                        Get.forceAppUpdate();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC70808),
                        foregroundColor: Colors.white,
                      ),
                    )
                  ],
                ),
              ),
            );
          }

          // --- State 2c: Stream has Data, but list is empty ---
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  '✅ ตำแหน่งยืนยันแล้ว:\nไม่มีงานที่อยู่ในรัศมี ${RiderHomeController.MAX_DISTANCE_METERS} เมตรในขณะนี้',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }

          // --- State 2d: Stream has Data, show list ---
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
  // ------------------------------------------

  // (PackageCard ไม่เปลี่ยนแปลง)
  Widget _buildPackageCard(
      BuildContext context, OrderModel order, RiderHomeController controller) {
    return InkWell(
      onTap: () => controller.navigateToOrderDetails(order),
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
              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // (PackageDetailRow ไม่เปลี่ยนแปลง)
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

  // (BottomNavBar ไม่เปลี่ยนแปลง)
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
              icon: Icon(Icons.history), label: 'ประวัติการส่ง'),
          BottomNavigationBarItem(
              icon: Icon(Icons.logout), label: 'ออกจากระบบ'),
        ],
        currentIndex: 0,
        onTap: (index) {
          if (index == 2) {
            Get.offAll(() => const SpeedDerApp());
          }
        },
      ),
    );
  }

  // (ProfileOptions ไม่เปลี่ยนแปลง)
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
              _buildOptionButton(context, 'เปลี่ยนรหัสผ่าน', Icons.lock_outline,
                  () {
                Navigator.pop(context);
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

  // (OptionButton ไม่เปลี่ยนแปลง)
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
