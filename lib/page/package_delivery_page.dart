import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/page/home_rider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

// ------------------------------------------------------------------
// Enum เพื่อจัดการสถานะการจัดส่ง
// ------------------------------------------------------------------
enum DeliveryStatus {
  accepted, // รับงานแล้ว
  pickedUp, // รับสินค้าจากต้นทางแล้ว
  inTransit, // กำลังนำส่ง
  delivered, // ถึงที่หมาย/จัดส่งสำเร็จ
}

// ------------------------------------------------------------------
// หน้าจอหลักของขั้นตอนการจัดส่ง
// ------------------------------------------------------------------
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
  String? _currentRiderId;

  @override
  void initState() {
    super.initState();
    _initializeRider();
  }

  Future<void> _initializeRider() async {
    final doc = await FirebaseFirestore.instance
        .collection('delivery_orders')
        .doc(widget.package.id)
        .get();
    if (doc.exists) {
      setState(() {
        _currentRiderId = doc.data()!['riderId'];
      });
      if (_currentRiderId != null) {
        _startSendingLocation(_currentRiderId!);
      }
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  void _startSendingLocation(String riderId) async {
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

    _locationSubscription =
        _location.onLocationChanged.listen((currentLocation) {
      if (currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        // อัปเดตตำแหน่งเป็น GeoPoint ซึ่งเป็นวิธีที่ดีที่สุด
        FirebaseFirestore.instance.collection('users').doc(riderId).update({
          'gps':
              GeoPoint(currentLocation.latitude!, currentLocation.longitude!),
        });
      }
    });
  }

  Future<void> _updateOrderStatus(String newStatus,
      {bool isFinal = false}) async {
    final orderRef = FirebaseFirestore.instance
        .collection('delivery_orders')
        .doc(widget.package.id);

    await orderRef.update({
      'currentStatus': newStatus,
      'statusHistory': FieldValue.arrayUnion([
        {'status': newStatus, 'timestamp': FieldValue.serverTimestamp()}
      ]),
    });

    if (isFinal) {
      Get.off(() => const RiderHomeScreen()); // กลับไปหน้า Home ของไรเดอร์
      Get.snackbar('เสร็จสิ้น', 'ดำเนินการจัดส่งเสร็จสมบูรณ์!');
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
      onWillPop: () async {
        final doc = await FirebaseFirestore.instance
            .collection('delivery_orders')
            .doc(widget.package.id)
            .get();
        if (doc.exists && doc.data()!['currentStatus'] != 'delivered') {
          Get.dialog(
            AlertDialog(
              title: const Text('ยังไม่สามารถย้อนกลับได้'),
              content: const Text('กรุณาดำเนินการจัดส่งสินค้าให้เสร็จสิ้นก่อน'),
              actions: [
                TextButton(
                    onPressed: () => Get.back(), child: const Text('ตกลง'))
              ],
            ),
          );
          return false;
        }
        return true;
      },
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
              .collection('delivery_orders')
              .doc(widget.package.id)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final currentDbStatus = data['currentStatus'] ?? 'accepted';
            final deliveryStatusEnum = _mapStatusToEnum(currentDbStatus);
            final riderId = data['riderId'] as String?;

            return Column(
              children: [
                _buildStatusTracker(primaryColor, deliveryStatusEnum),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      children: [
                        _buildMapSection(data, riderId),
                        const SizedBox(height: 20),
                        _buildActionSection(deliveryStatusEnum),
                        const SizedBox(height: 20),
                        if (riderId != null) _buildRiderInfoSection(riderId),
                        const SizedBox(height: 20),
                        _buildPackageInfoSection(data),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: _buildBottomNavigationBar(context),
      ),
    );
  }

  // ------------------------------------------------------------------
  // UI Components
  // ------------------------------------------------------------------

  Widget _buildStatusTracker(Color primaryColor, DeliveryStatus currentStatus) {
    final List<Map<String, dynamic>> steps = [
      {
        'icon': Icons.check_circle_outline,
        'status': DeliveryStatus.accepted,
        'label': 'รับงาน'
      },
      {
        'icon': Icons.inventory_2,
        'status': DeliveryStatus.pickedUp,
        'label': 'รับของ'
      },
      {
        'icon': Icons.local_shipping,
        'status': DeliveryStatus.inTransit,
        'label': 'จัดส่ง'
      },
      {
        'icon': Icons.task_alt,
        'status': DeliveryStatus.delivered,
        'label': 'สำเร็จ'
      },
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
        children: steps.map((step) {
          bool isActive =
              currentStatus.index >= (step['status'] as DeliveryStatus).index;
          return Column(
            children: [
              Icon(
                step['icon'] as IconData,
                color: isActive ? Colors.white : Colors.white54,
                size: 30,
              ),
              const SizedBox(height: 4),
              Text(
                step['label'],
                style: TextStyle(
                    color: isActive ? Colors.white : Colors.white54,
                    fontSize: 12),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMapSection(Map<String, dynamic> orderData, String? riderId) {
    final GeoPoint destinationPoint = orderData['deliveryAddress']['gps'] ??
        const GeoPoint(16.4746, 102.8247);
    final destinationLatLng =
        LatLng(destinationPoint.latitude, destinationPoint.longitude);

    if (riderId == null) {
      return Container(
          height: 250, child: const Center(child: Text("รอข้อมูลไรเดอร์...")));
    }

    return Container(
      height: 250,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(riderId)
              .snapshots(),
          builder: (context, riderSnapshot) {
            LatLng riderLatLng = LatLng(16.4858, 102.8222); // Default position
            if (riderSnapshot.hasData && riderSnapshot.data!.exists) {
              final riderData =
                  riderSnapshot.data!.data() as Map<String, dynamic>;

              if (riderData.containsKey('gps')) {
                if (riderData['gps'] is GeoPoint) {
                  final geoPoint = riderData['gps'] as GeoPoint;
                  riderLatLng = LatLng(geoPoint.latitude, geoPoint.longitude);
                } else if (riderData['gps'] is String) {
                  // **ส่วนที่แก้ไข:** แก้ไขการแปลง String เป็นพิกัด
                  final gpsString = riderData['gps'] as String;
                  final cleanedString =
                      gpsString.replaceAll(RegExp(r'[°NE]'), '').trim();
                  final parts = cleanedString.split(',');

                  if (parts.length == 2) {
                    final lat = double.tryParse(parts[0].trim());
                    final lng = double.tryParse(parts[1].trim());
                    if (lat != null && lng != null) {
                      riderLatLng = LatLng(lat, lng);
                    }
                  }
                }
              }
            }

            return FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: riderLatLng,
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: destinationLatLng,
                      child: const Icon(Icons.location_on,
                          color: Colors.red, size: 40),
                    ),
                    Marker(
                      point: riderLatLng,
                      child: const Icon(Icons.two_wheeler,
                          color: Colors.blue, size: 40),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
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
    String nextStatus;
    bool isFinal = false;

    switch (currentStatus) {
      case DeliveryStatus.accepted:
        buttonText = 'ยืนยันการรับสินค้า';
        nextStatus = 'picked_up';
        break;
      case DeliveryStatus.pickedUp:
        buttonText = 'เริ่มนำส่ง';
        nextStatus = 'in_transit';
        break;
      case DeliveryStatus.inTransit:
        buttonText = 'ยืนยันการจัดส่งสำเร็จ';
        nextStatus = 'delivered';
        isFinal = true;
        break;
      default:
        buttonText = '...';
        nextStatus = '';
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _updateOrderStatus(nextStatus, isFinal: isFinal),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC70808),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          buttonText,
          style: const TextStyle(
              fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildRiderInfoSection(String riderId) {
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(riderId)
            .snapshots(),
        builder: (context, snapshot) {
          String riderName = 'กำลังโหลด...';
          String riderPhone = '...';

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            riderName = data['fullname'] ?? 'ไม่มีชื่อ';
            riderPhone = data['phone'] ?? 'ไม่มีเบอร์โทร';
          }

          return _buildInfoBox(
            title: 'ข้อมูลคนขับ',
            children: [
              _buildInfoRow(
                icon: Icons.two_wheeler,
                label: 'ชื่อ',
                value: riderName,
              ),
              _buildInfoRow(
                icon: Icons.phone,
                label: 'โทร',
                value: riderPhone,
              ),
            ],
          );
        });
  }

  Widget _buildPackageInfoSection(Map<String, dynamic> orderData) {
    return _buildInfoBox(
      title: 'ข้อมูลสินค้า',
      children: [
        _buildInfoRow(
          icon: Icons.inventory_2_outlined,
          label: 'สินค้า',
          value: orderData['orderDetails'] ?? 'N/A',
        ),
        _buildInfoRow(
          icon: Icons.store,
          label: 'รับจาก',
          value: orderData['pickupAddress']['detail'] ?? 'N/A',
        ),
        _buildInfoRow(
          icon: Icons.location_on,
          label: 'ส่งที่',
          value: orderData['deliveryAddress']['detail'] ?? 'N/A',
        ),
      ],
    );
  }

  Widget _buildInfoBox(
      {required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFC70808),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 15),
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
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$label: $value',
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

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
        onTap: (index) {},
      ),
    );
  }
}
