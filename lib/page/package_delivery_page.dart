// file: lib/page/package_delivery_page.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/models/package_model.dart';
import 'package:delivery_project/page/home_rider.dart';
import 'package:delivery_project/page/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'dart:developer';

// Enum เพื่อจัดการสถานะการจัดส่ง
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
  const PackageDeliveryPage(
      {super.key,
      required this.package,
      required this.uid,
      required this.role});

  @override
  State<PackageDeliveryPage> createState() => _PackageDeliveryPageState();
}

class _PackageDeliveryPageState extends State<PackageDeliveryPage> {
  final Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // เริ่มส่งตำแหน่งเมื่อหน้านี้ถูกเปิด
    _startSendingLocation();
  }

  @override
  void dispose() {
    // หยุดการส่งตำแหน่งเมื่อออกจากหน้านี้
    _locationSubscription?.cancel();
    super.dispose();
  }

  // --- ⭐️ แก้ไข: ฟังก์ชันสำหรับเริ่มติดตามและส่งตำแหน่งของไรเดอร์ ---
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

    _location.changeSettings(
        interval: 10000,
        distanceFilter: 10); // อัปเดตทุก 10 วินาที หรือ 10 เมตร

    _locationSubscription =
        _location.onLocationChanged.listen((currentLocation) {
      if (currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        // --- ⭐️ แก้ไข: อัปเดตตำแหน่งไปที่ collection 'orders' ---
        FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.package.id) // <-- ใช้ ID ของออเดอร์ปัจจุบัน
            .update({
          'currentLocation': // <-- ใช้ field 'currentLocation'
              GeoPoint(currentLocation.latitude!, currentLocation.longitude!),
        }).then((_) {
          log('✅ Real-time location updated to order: ${widget.package.id}');
        }).catchError((error) {
          log('❌ Error updating real-time location: $error');
        });
      }
    });
  }

  Future<void> _captureAndUploadStatusImage({
    required String statusToUpdate,
    bool isFinal = false,
  }) async {
    final picker = ImagePicker();
    try {
      final pickedFile =
          await picker.pickImage(source: ImageSource.camera, maxWidth: 1024);
      if (pickedFile == null) return;

      Get.dialog(const Center(child: CircularProgressIndicator()),
          barrierDismissible: false);

      final cloudinary =
          CloudinaryPublic('dnutmbomv', 'delivery888', cache: false);
      final response =
          await cloudinary.uploadFile(CloudinaryFile.fromFile(pickedFile.path));
      final imageUrl = response.secureUrl;

      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.package.id);

      // ใช้ Transaction เพื่อความปลอดภัยของข้อมูล
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // ดึงข้อมูลล่าสุดก่อนอัปเดต
        final snapshot = await transaction.get(orderRef);
        if (!snapshot.exists) {
          throw Exception("Document does not exist!");
        }

        // สร้าง statusHistory entry ใหม่พร้อมรูปภาพ
        final newHistoryEntry = {
          'status': statusToUpdate,
          'timestamp': Timestamp.now(),
          'imgOfStatus': imageUrl, // เพิ่ม URL ของรูปภาพ
        };

        // ใช้ FieldValue.arrayUnion เพื่อเพิ่ม entry ใหม่เข้าไปใน array
        transaction.update(orderRef, {
          'currentStatus': statusToUpdate,
          'statusHistory': FieldValue.arrayUnion([newHistoryEntry]),
        });
      });

      Get.back();
      Get.snackbar('สำเร็จ', 'อัปเดตสถานะเรียบร้อยแล้ว');

      if (isFinal) {
        await Future.delayed(const Duration(seconds: 1));
        Get.offAll(() => RiderHomeScreen(uid: widget.uid, role: widget.role));
        Get.snackbar('เสร็จสิ้น', 'ดำเนินการจัดส่งเสร็จสมบูรณ์!');
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar('เกิดข้อผิดพลาด', 'ไม่สามารถอัปเดตสถานะได้: $e');
    }
  }

  DeliveryStatus _mapStatusToEnum(String status) {
    switch (status) {
      case 'accepted':
        return DeliveryStatus.accepted;
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

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFC70808);

    return WillPopScope(
      onWillPop: () async => false, // ป้องกันการกด back โดยไม่ได้ตั้งใจ
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('ขั้นตอนการจัดส่ง'),
          backgroundColor: primaryColor,
          elevation: 0,
          automaticallyImplyLeading: false, // เอาปุ่ม back ออก
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

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final currentDbStatus = data['currentStatus'] ?? 'accepted';
            final deliveryStatusEnum = _mapStatusToEnum(currentDbStatus);

            return Column(
              children: [
                _buildStatusTracker(primaryColor, deliveryStatusEnum),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      children: [
                        _buildMapSection(data),
                        const SizedBox(height: 20),
                        _buildActionSection(deliveryStatusEnum),
                        const SizedBox(height: 20),
                        _buildEvidenceImage(data),
                        const SizedBox(height: 20),
                        _buildDeliveryInfoSection(data),
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

  // --- ⭐️ แก้ไข: Widget แสดงแผนที่ (อ่าน currentLocation จาก order) ---
  Widget _buildMapSection(Map<String, dynamic> orderData) {
    final currentStatus =
        _mapStatusToEnum(orderData['currentStatus'] ?? 'accepted');

    // ดึงพิกัดของผู้ส่งและผู้รับ
    final GeoPoint pickupPoint =
        orderData['pickupAddress']['gps'] ?? const GeoPoint(0, 0);
    final LatLng pickupLatLng =
        LatLng(pickupPoint.latitude, pickupPoint.longitude);

    final GeoPoint deliveryPoint =
        orderData['deliveryAddress']['gps'] ?? const GeoPoint(0, 0);
    final LatLng deliveryLatLng =
        LatLng(deliveryPoint.latitude, deliveryPoint.longitude);

    // ตรรกะ: เลือกเป้าหมายตามสถานะ
    LatLng targetLatLng;
    IconData targetIcon;
    Color targetColor;

    if (currentStatus == DeliveryStatus.accepted ||
        currentStatus == DeliveryStatus.pickedUp) {
      targetLatLng = pickupLatLng;
      targetIcon = Icons.store;
      targetColor = Colors.orange;
    } else {
      targetLatLng = deliveryLatLng;
      targetIcon = Icons.location_on;
      targetColor = Colors.red;
    }

    // ดึงตำแหน่ง Real-time ของ Rider จาก order document
    LatLng riderLatLng = targetLatLng; // ค่าเริ่มต้น
    if (orderData.containsKey('currentLocation') &&
        orderData['currentLocation'] is GeoPoint) {
      final geoPoint = orderData['currentLocation'] as GeoPoint;
      riderLatLng = LatLng(geoPoint.latitude, geoPoint.longitude);
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
                // หมุดเป้าหมาย
                Marker(
                  point: targetLatLng,
                  width: 80,
                  height: 80,
                  child: Icon(targetIcon, color: targetColor, size: 40),
                ),
                // หมุดตำแหน่งของไรเดอร์
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

  // ... (โค้ดส่วนที่เหลือทั้งหมดเหมือนเดิม) ...
  Widget _buildStatusTracker(Color primaryColor, DeliveryStatus currentStatus) {
    final List<Map<String, dynamic>> steps = [
      {'icon': Icons.check_circle_outline, 'label': 'รับงาน'},
      {'icon': Icons.inventory_2, 'label': 'รับของ'},
      {'icon': Icons.local_shipping, 'label': 'จัดส่ง'},
      {'icon': Icons.task_alt, 'label': 'สำเร็จ'},
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(steps.length, (index) {
          bool isActive = currentStatus.index >= index;
          return Column(
            children: [
              Icon(
                steps[index]['icon'] as IconData,
                color: isActive ? Colors.white : Colors.white54,
                size: 30,
              ),
              const SizedBox(height: 4),
              Text(
                steps[index]['label'],
                style: TextStyle(
                    color: isActive ? Colors.white : Colors.white54,
                    fontSize: 12),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildActionSection(DeliveryStatus currentStatus) {
    if (currentStatus == DeliveryStatus.delivered) {
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
    String buttonText;
    VoidCallback onPressed;
    IconData? icon;
    switch (currentStatus) {
      case DeliveryStatus.accepted:
        buttonText = 'ถ่ายรูปยืนยันการรับของ';
        icon = Icons.camera_alt;
        onPressed = () => _captureAndUploadStatusImage(
              statusToUpdate: 'picked_up',
            );
        break;
      case DeliveryStatus.pickedUp:
        buttonText = 'ถ่ายรูปเพื่อเริ่มนำส่ง';
        icon = Icons.local_shipping;
        onPressed = () => _captureAndUploadStatusImage(
              statusToUpdate: 'in_transit',
            );
        break;
      case DeliveryStatus.inTransit:
        buttonText = 'ถ่ายรูปยืนยันการส่งสำเร็จ';
        icon = Icons.photo_camera;
        onPressed = () => _captureAndUploadStatusImage(
              statusToUpdate: 'delivered',
              isFinal: true,
            );
        break;
      default:
        buttonText = '...';
        icon = Icons.error;
        onPressed = () {};
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(
          buttonText,
          style: const TextStyle(
              fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC70808),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildEvidenceImage(Map<String, dynamic> orderData) {
    final statusHistory = orderData['statusHistory'] as List<dynamic>? ?? [];

    final imagesToShow = statusHistory.where((history) {
      final imgUrl = history['imgOfStatus'] as String?;
      return imgUrl != null && imgUrl.isNotEmpty;
    }).toList();

    if (imagesToShow.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: imagesToShow.map((history) {
        final status = history['status'] as String? ?? '';
        final imageUrl = history['imgOfStatus'] as String;
        return _buildImageCard(_translateStatusToImageTitle(status), imageUrl);
      }).toList(),
    );
  }

  String _translateStatusToImageTitle(String status) {
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

  Widget _buildImageCard(String title, String imageUrl) {
    return _buildInfoBox(title: title, children: [
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
          errorBuilder: (context, error, stackTrace) {
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
    ]);
  }

  Widget _buildDeliveryInfoSection(Map<String, dynamic> orderData) {
    final pickupAddress =
        orderData['pickupAddress'] as Map<String, dynamic>? ?? {};
    final deliveryAddress =
        orderData['deliveryAddress'] as Map<String, dynamic>? ?? {};
    final customerId = orderData['customerId'] as String?;

    return _buildInfoBox(
      title: 'ข้อมูลการจัดส่ง',
      children: [
        _buildInfoRow(
          icon: Icons.storefront,
          label: 'รับจาก',
          value: pickupAddress['detail'] ?? 'N/A',
        ),
        if (customerId != null)
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(customerId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Center(child: LinearProgressIndicator()),
                );
              }
              final senderData =
                  snapshot.data?.data() as Map<String, dynamic>? ?? {};
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    icon: Icons.person,
                    label: 'ผู้ส่ง',
                    value: senderData['fullname'] ?? 'ไม่มีข้อมูล',
                  ),
                  _buildInfoRow(
                    icon: Icons.phone,
                    label: 'เบอร์ติดต่อ (ผู้ส่ง)',
                    value: senderData['phone'] ?? 'ไม่มีข้อมูล',
                  ),
                ],
              );
            },
          )
        else
          _buildInfoRow(
              icon: Icons.person, label: 'ผู้ส่ง', value: 'ไม่มีข้อมูล'),
        const Divider(height: 20),
        _buildInfoRow(
          icon: Icons.location_on,
          label: 'ส่งที่',
          value: deliveryAddress['detail'] ?? 'N/A',
        ),
        _buildInfoRow(
          icon: Icons.person_pin,
          label: 'ผู้รับ',
          value: deliveryAddress['receiverName'] ?? 'N/A',
        ),
        _buildInfoRow(
          icon: Icons.phone_android,
          label: 'เบอร์ติดต่อ (ผู้รับ)',
          value: deliveryAddress['receiverPhone'] ?? 'N/A',
        ),
        const Divider(height: 20),
        _buildInfoRow(
          icon: Icons.inventory_2_outlined,
          label: 'รายละเอียดสินค้า',
          value: orderData['orderDetails'] ?? 'N/A',
        ),
      ],
    );
  }

  Widget _buildInfoBox(
      {required String title, required List<Widget> children}) {
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
          Text(
            title,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      {required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFFC70808)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
