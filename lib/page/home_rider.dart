import 'dart:async';
import 'dart:developer';
import 'dart:math' show cos, sqrt, asin, pi, atan2, sin;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/models/order_model.dart';
import 'package:delivery_project/models/package_model.dart';
import 'package:delivery_project/models/user_model.dart';
import 'package:delivery_project/page/index.dart';
import 'package:delivery_project/page/package_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:delivery_project/page/edit_profile.dart';
import 'package:delivery_project/page/package_delivery_page.dart';

class RiderHomeController extends GetxController {
  final String uid;
  final int role;
  RiderHomeController({required this.uid, required this.role});

  final Rx<UserModel?> rider = Rx(null);
  final db = FirebaseFirestore.instance;

  final Rx<GeoPoint?> riderCurrentLocation = Rx(null);
  StreamSubscription<Position>? _positionStreamSubscription;
  @override
  void onInit() {
    super.onInit();
    _checkAndNavigateToActiveOrder();

    _startLocationTracking();

    rider.bindStream(
      db
          .collection('users')
          .doc(uid)
          .snapshots()
          .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null),
    );
  }

  @override
  void onClose() {
    _positionStreamSubscription?.cancel();
    super.onClose();
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
      distanceFilter: 5,
    );
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
            (Position position) {
      riderCurrentLocation.value =
          GeoPoint(position.latitude, position.longitude);
    }, onError: (e) {
      log('Error getting location stream: $e');
      Get.snackbar('ข้อผิดพลาด', 'ไม่สามารถติดตามตำแหน่ง GPS ได้: $e');
    });
  }

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

  Stream<List<OrderModel>> getPendingOrdersStream() {
    return db
        .collection('orders')
        .where('currentStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
    }).timeout(
      const Duration(seconds: 30),
      onTimeout: (sink) {
        sink.addError(
            TimeoutException('ไม่สามารถโหลดข้อมูลได้ใน 30 วินาที (Timeout)'));
      },
    );
  }

  void navigateToOrderDetails(OrderModel order) {
    if (riderCurrentLocation.value == null) {
      Get.snackbar('ข้อผิดพลาด', 'ยังไม่สามารถระบุตำแหน่งของคุณได้');
      return;
    }

    Get.to(() => PackageDetailScreen(
          order: order,
          riderController: this,
        ));
  }

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
      Get.back();
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

  Widget _buildPackageList(RiderHomeController controller) {
    return Obx(() {
      final riderLoc = controller.riderCurrentLocation.value;

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

      return StreamBuilder<List<OrderModel>>(
        stream: controller.getPendingOrdersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                    ),
                    SizedBox(height: 15),
                    Text(
                      'กำลังค้นหางาน...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

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
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('ลองใหม่'),
                      onPressed: () {
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

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'ยังไม่มีงานเข้ามาในขณะนี้',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
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
          if (index == 2) {
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
