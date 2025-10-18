// file: lib/page/package_delivery_screen.dart

import 'dart:async';
import 'dart:developer';
import 'dart:math' show cos, sqrt, asin, pi, atan2, sin;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:delivery_project/models/package_model.dart';
import 'package:delivery_project/page/home_rider.dart';
import 'package:delivery_project/page/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

// หากต้องการ คุณสามารถแยก widget ย่อยออกเป็น part ไฟล์ได้
// part 'delivery_map_section.dart';
// part 'delivery_action_section.dart';
// part 'delivery_info_section.dart';
// part 'delivery_status_tracker.dart';
// part 'delivery_image_card.dart';

enum DeliveryStatus {
  accepted,
  pickedUp,
  inTransit,
  delivered,
}

class PackageDeliveryPage extends StatefulWidget {
  final Package package;
  final String uid;
  final int role;

  const PackageDeliveryPage({
    super.key,
    required this.package,
    required this.uid,
    required this.role,
  });

  @override
  State<PackageDeliveryPage> createState() => _PackageDeliveryScreenState();
}

class _PackageDeliveryScreenState extends State<PackageDeliveryPage> {
  final Location _location = Location();
  final MapController _mapController = MapController();
  StreamSubscription<LocationData>? _locationSubscription;

  // ⭐️ แก้ไข: เปลี่ยนชื่อตัวแปรให้สื่อถึงระยะทางที่ยอมรับได้
  static const double maxDistanceToTarget = 20.0; // 20 เมตร

  @override
  void initState() {
    super.initState();
    _startSendingLocation();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  // ================= Location Tracking =================
  void _startSendingLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    _location.changeSettings(interval: 10000, distanceFilter: 10);

    _locationSubscription =
        _location.onLocationChanged.listen((currentLocation) {
      if (currentLocation.latitude == null ||
          currentLocation.longitude == null) {
        return;
      }
      final GeoPoint gpsPoint = GeoPoint(
        currentLocation.latitude!,
        currentLocation.longitude!,
      );
      FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.package.id)
          .update({'currentLocation': gpsPoint}).then((_) {
        log('✅ Real-time location updated: ${gpsPoint.latitude}, ${gpsPoint.longitude}');
      }).catchError((err) {
        log('❌ Error updating location: $err');
      });
    });
  }

  // ================= Enum Mapping =================
  DeliveryStatus _mapStatus(String status) {
    switch (status) {
      case 'picked_up':
        return DeliveryStatus.pickedUp;
      case 'in_transit':
        return DeliveryStatus.inTransit;
      case 'delivered':
        return DeliveryStatus.delivered;
      default:
        return DeliveryStatus.accepted;
    }
  }

  // ================= Confirm Exit =================
  void _confirmExitDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการออกจากระบบ'),
        content: const Text(
            'คุณแน่ใจหรือไม่ที่จะออกจากระบบ? ระบบจะกลับมาหน้านี้โดยอัตโนมัติหากยังไม่จัดส่งเสร็จ'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () {
              _locationSubscription?.cancel();
              Get.offAll(() => const SpeedDerApp());
            },
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
  }

  // ================= Build =================
  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFC70808);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('ขั้นตอนการจัดส่ง'),
          backgroundColor: primaryColor,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .doc(widget.package.id)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final orderData = snapshot.data!.data() as Map<String, dynamic>;
            final statusString =
                orderData['currentStatus'] as String? ?? 'accepted';
            final currentStatus = _mapStatus(statusString);

            return Column(
              children: [
                _buildStatusTracker(primaryColor, currentStatus),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      children: [
                        _buildMapSection(orderData, currentStatus),
                        const SizedBox(height: 20),
                        _buildActionSection(currentStatus, orderData),
                        const SizedBox(height: 20),
                        _buildEvidenceImages(orderData),
                        const SizedBox(height: 20),
                        _buildDeliveryInfoSection(orderData),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _confirmExitDialog,
                          child: const Text('ออกจากระบบ / กลับหน้าหลัก'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ================= Image Upload & Status Update =================
  Future<void> _captureAndUploadStatusImage({
    required String statusToUpdate,
    bool isFinal = false,
  }) async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.camera, maxWidth: 1024);

    if (pickedFile == null) return;

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      final cloudinary =
          CloudinaryPublic('dnutmbomv', 'delivery888', cache: false);
      final response =
          await cloudinary.uploadFile(CloudinaryFile.fromFile(pickedFile.path));
      final imageUrl = response.secureUrl;

      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.package.id);

      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snapshot = await txn.get(orderRef);
        if (!snapshot.exists) throw Exception('Document not found');

        final newHistory = {
          'status': statusToUpdate,
          'timestamp': Timestamp.now(),
          'imgOfStatus': imageUrl,
        };
        txn.update(orderRef, {
          'currentStatus': statusToUpdate,
          'statusHistory': FieldValue.arrayUnion([newHistory]),
        });
      });

      Get.back();
      Get.snackbar('สำเร็จ', 'อัปเดตสถานะเรียบร้อยแล้ว');

      if (isFinal) {
        _locationSubscription?.cancel();
        await Future.delayed(const Duration(seconds: 1));
        Get.offAll(() => RiderHomeScreen(uid: widget.uid, role: widget.role));
        Get.snackbar('เสร็จสิ้น', 'ดำเนินการจัดส่งเสร็จสมบูรณ์!');
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar('เกิดข้อผิดพลาด', 'ไม่สามารถอัปเดตสถานะได้: $e');
    }
  }

  // ================= Widget: Status Tracker =================
  Widget _buildStatusTracker(Color baseColor, DeliveryStatus status) {
    final steps = [
      {'icon': Icons.check_circle_outline, 'label': 'รับงาน'},
      {'icon': Icons.inventory_2, 'label': 'รับของ'},
      {'icon': Icons.local_shipping, 'label': 'จัดส่ง'},
      {'icon': Icons.task_alt, 'label': 'สำเร็จ'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(steps.length, (index) {
          final isActive = status.index >= index;
          return Column(
            children: [
              Icon(
                steps[index]['icon'] as IconData,
                color: isActive ? Colors.white : Colors.white54,
                size: 30,
              ),
              const SizedBox(height: 4),
              Text(
                steps[index]['label'] as String,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ================= Widget: Map Section =================
  Widget _buildMapSection(
      Map<String, dynamic> orderData, DeliveryStatus status) {
    // ดึงพิกัดรับและส่ง
    final GeoPoint pickupGps =
        orderData['pickupAddress']?['gps'] as GeoPoint? ?? const GeoPoint(0, 0);
    final GeoPoint deliveryGps =
        orderData['deliveryAddress']?['gps'] as GeoPoint? ??
            const GeoPoint(0, 0);
    final LatLng pickupLatLng = LatLng(pickupGps.latitude, pickupGps.longitude);
    final LatLng deliveryLatLng =
        LatLng(deliveryGps.latitude, deliveryGps.longitude);

    LatLng targetLatLng;
    IconData targetIcon;
    Color targetColor;

    if (status.index < DeliveryStatus.inTransit.index) {
      targetLatLng = pickupLatLng;
      targetIcon = Icons.store;
      targetColor = Colors.orange;
    } else {
      targetLatLng = deliveryLatLng;
      targetIcon = Icons.location_on;
      targetColor = Colors.red;
    }

    LatLng riderLatLng = targetLatLng;
    if (orderData['currentLocation'] is GeoPoint) {
      final GeoPoint rp = orderData['currentLocation'] as GeoPoint;
      riderLatLng = LatLng(rp.latitude, rp.longitude);
    }

    return Container(
      height: 250,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: riderLatLng,
            initialZoom: 15.0,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=cb153d15cb4e41f59e25cfda6468f1a0',
              userAgentPackageName: 'com.example.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: targetLatLng,
                  width: 80,
                  height: 80,
                  child: Icon(targetIcon, color: targetColor, size: 40),
                ),
                Marker(
                  point: riderLatLng,
                  width: 80,
                  height: 80,
                  child: const Icon(Icons.two_wheeler,
                      color: Colors.blue, size: 40),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ⭐️ แก้ไข: ปรับปรุง Action Section ให้มีการตรวจสอบระยะทางก่อน "รับของ" และ "ส่งของ"
  Widget _buildActionSection(
      DeliveryStatus status, Map<String, dynamic> orderData) {
    if (status == DeliveryStatus.delivered) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green)),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 30),
            SizedBox(width: 10),
            Text('จัดส่งสินค้านี้เรียบร้อยแล้ว',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    // กำหนดค่าตามสถานะปัจจุบัน
    String targetStatus;
    GeoPoint? targetGps;
    String buttonText;
    bool isFinal = false;

    if (status == DeliveryStatus.accepted) {
      targetStatus = 'picked_up';
      buttonText = 'ถ่ายรูปยืนยันการรับของ';
      // จุดหมายคือจุดรับของ
      targetGps = orderData['pickupAddress']?['gps'] as GeoPoint?;
    } else if (status == DeliveryStatus.pickedUp) {
      targetStatus = 'in_transit';
      buttonText = 'ถ่ายรูปเพื่อเริ่มนำส่ง';
      // เมื่อรับของแล้ว จุดหมายต่อไปคือจุดรับของ (ยังไม่ถ่ายรูปเดินทาง)
      // อนุญาตให้ถ่ายได้เลย ไม่ต้องเช็คระยะทางซ้ำ
      targetGps = null;
    } else if (status == DeliveryStatus.inTransit) {
      targetStatus = 'delivered';
      buttonText = 'ถ่ายรูปยืนยันการส่งสำเร็จ';
      isFinal = true;
      // จุดหมายคือจุดส่งของ
      targetGps = orderData['deliveryAddress']?['gps'] as GeoPoint?;
    } else {
      return const SizedBox.shrink(); // สถานะอื่น ๆ ไม่ต้องแสดงปุ่ม
    }

    final GeoPoint? riderLoc = orderData['currentLocation'] as GeoPoint?;

    // --- 1. ตรวจสอบว่าต้องเช็คระยะทางหรือไม่ (คือขั้นตอน accepted -> picked_up หรือ inTransit -> delivered) ---
    if (riderLoc != null && targetGps != null) {
      final double distance = _calculateDistanceMeters(riderLoc, targetGps);

      if (distance > maxDistanceToTarget) {
        // แสดงปุ่มแจ้งเตือนให้เข้าใกล้จุดหมายก่อน
        final String targetName =
            status == DeliveryStatus.accepted ? 'ผู้ส่ง' : 'ผู้รับ';

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.warning, color: Colors.white),
            label: Text(
              'ต้องอยู่ใกล้${targetName} (ห่าง ${distance.toStringAsFixed(2)} ม.)',
              style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Get.snackbar(
                'แจ้งเตือน',
                'คุณต้องอยู่ภายใน ${maxDistanceToTarget.toInt()} เมตรจากจุด${targetName} (ปัจจุบันห่าง ${distance.toStringAsFixed(2)} เมตร)',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.orange,
                colorText: Colors.white,
              );
              _mapController.move(
                  LatLng(riderLoc.latitude, riderLoc.longitude), 17.0);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        );
      }
    } else if (targetGps != null && riderLoc == null) {
      // กรณีที่ต้องเช็คระยะทาง แต่ GPS ของไรเดอร์ยังไม่มา
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.sync, color: Colors.white),
          label: const Text(
            'กำลังรอข้อมูลตำแหน่ง Rider...',
            style: TextStyle(
                fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    }
    // --- 2. ถ้าผ่านการเช็คระยะทางแล้ว หรือเป็นสถานะที่ไม่ต้องเช็คระยะทาง (picked_up -> in_transit) ---

    final Color buttonColor =
        isFinal ? const Color(0xFF38B000) : const Color(0xFFC70808);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(isFinal ? Icons.photo_camera : Icons.camera_alt,
            color: Colors.white),
        label: Text(
          buttonText,
          style: const TextStyle(
              fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () => _captureAndUploadStatusImage(
          statusToUpdate: targetStatus,
          isFinal: isFinal,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ================= Helper: Distance =================
  double _calculateDistanceMeters(GeoPoint loc1, GeoPoint loc2) {
    const double R = 6371000; // meters
    final double lat1 = loc1.latitude;
    final double lon1 = loc1.longitude;
    final double lat2 = loc2.latitude;
    final double lon2 = loc2.longitude;

    final double dLat = (lat2 - lat1) * (pi / 180);
    final double dLon = (lon2 - lon1) * (pi / 180);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  // ================= Widget: Evidence Images =================
  Widget _buildEvidenceImages(Map<String, dynamic> orderData) {
    final List<dynamic> history =
        orderData['statusHistory'] as List<dynamic>? ?? [];

    final images = history.where((item) {
      final img = item['imgOfStatus'] as String?;
      return img != null && img.isNotEmpty;
    }).toList();

    if (images.isEmpty) return const SizedBox.shrink();

    return Column(
      children: images.map((item) {
        final status = item['status'] as String? ?? '';
        final imgUrl = item['imgOfStatus'] as String;
        return _imageCard(_translateStatusTitle(status), imgUrl);
      }).toList(),
    );
  }

  String _translateStatusTitle(String status) {
    switch (status) {
      case 'picked_up':
        return 'รูปภาพตอนรับของ';
      case 'in_transit':
        return 'รูปภาพตอนเริ่มนำส่ง';
      case 'delivered':
        return 'รูปภาพตอนจัดส่งสำเร็จ';
      default:
        return 'รูปภาพหลักฐาน';
    }
  }

  Widget _imageCard(String title, String imageUrl) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stack) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 50),
                        SizedBox(height: 8),
                        Text('ไม่สามารถโหลดรูปภาพได้'),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ================= Widget: Delivery Info =================
  Widget _buildDeliveryInfoSection(Map<String, dynamic> orderData) {
    final pickup = orderData['pickupAddress'] as Map<String, dynamic>? ?? {};
    final delivery =
        orderData['deliveryAddress'] as Map<String, dynamic>? ?? {};
    final customerId = orderData['customerId'] as String?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ข้อมูลการจัดส่ง',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(height: 20),
          _infoRow(
            icon: Icons.storefront,
            label: 'รับจาก',
            value: pickup['detail'] ?? 'N/A',
          ),
          const SizedBox(height: 8),
          if (customerId != null)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(customerId)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: LinearProgressIndicator()),
                  );
                }
                final userData =
                    snap.data!.data() as Map<String, dynamic>? ?? {};
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow(
                      icon: Icons.person,
                      label: 'ผู้ส่ง',
                      value: userData['fullname'] ?? 'ไม่มีข้อมูล',
                    ),
                    const SizedBox(height: 8),
                    _infoRow(
                      icon: Icons.phone,
                      label: 'เบอร์ติดต่อ (ผู้ส่ง)',
                      value: userData['phone'] ?? 'ไม่มีข้อมูล',
                    ),
                  ],
                );
              },
            )
          else
            _infoRow(icon: Icons.person, label: 'ผู้ส่ง', value: 'ไม่มีข้อมูล'),
          const SizedBox(height: 10),
          const Divider(height: 20),
          _infoRow(
            icon: Icons.location_on,
            label: 'ส่งที่',
            value: delivery['detail'] ?? 'N/A',
          ),
          const SizedBox(height: 8),
          _infoRow(
            icon: Icons.person_pin,
            label: 'ผู้รับ',
            value: delivery['receiverName'] ?? 'N/A',
          ),
          const SizedBox(height: 8),
          _infoRow(
            icon: Icons.phone_android,
            label: 'เบอร์ติดต่อ (ผู้รับ)',
            value: delivery['receiverPhone'] ?? 'N/A',
          ),
          const SizedBox(height: 10),
          const Divider(height: 20),
          _infoRow(
            icon: Icons.inventory_2_outlined,
            label: 'รายละเอียดสินค้า',
            value: orderData['orderDetails'] ?? 'N/A',
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFFC70808)),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(fontSize: 16, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }
}
