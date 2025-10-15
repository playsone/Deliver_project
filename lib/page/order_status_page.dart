// order_status_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/page/history_page.dart';
import 'package:delivery_project/page/home.dart';
import 'package:delivery_project/page/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart'; // เพิ่ม import สำหรับภาษาไทย
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

// Constants
const Color _primaryColor = Color(0xFFC70808);
const Color _backgroundColor = Color(0xFFFDE9E9);

class OrderStatusPage extends StatefulWidget {
  final String orderId;
  final String uid;
  final int role;

  const OrderStatusPage({
    super.key,
    required this.orderId,
    required this.uid,
    required this.role,
  });

  @override
  State<OrderStatusPage> createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends State<OrderStatusPage> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // ตั้งค่า locale สำหรับการจัดรูปแบบวันที่และเวลาเป็นภาษาไทย
    initializeDateFormatting('th', null);
  }

  @override
  Widget build(BuildContext context) {
    // **ส่วนดักบั๊ก: 1. ตรวจสอบว่าได้รับ orderId ที่ถูกต้องหรือไม่**
    if (widget.orderId.isEmpty) {
      // ถ้า orderId เป็นค่าว่าง ให้แสดงหน้าจอข้อผิดพลาดทันทีเพื่อป้องกันแอปพัง
      return Scaffold(
        appBar: AppBar(
            title: const Text('เกิดข้อผิดพลาด'),
            backgroundColor: _primaryColor),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              'ไม่สามารถโหลดข้อมูลได้ เนื่องจากไม่ได้รับ ID ของออเดอร์\nกรุณาลองกลับไปทำรายการใหม่อีกครั้ง',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('ติดตามสถานะการจัดส่ง',
            style: TextStyle(color: Colors.white)),
        backgroundColor: _primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('delivery_orders')
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, orderSnapshot) {
          if (orderSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
            return const Center(child: Text('ไม่พบข้อมูลออเดอร์'));
          }

          final orderData = orderSnapshot.data!.data() as Map<String, dynamic>;
          final riderId = orderData['riderId'] as String?;

          // **ส่วนดักบั๊ก: 2. ตรวจสอบว่า riderId ไม่ใช่ค่าว่างก่อนเรียกใช้**
          if (riderId == null || riderId.isEmpty) {
            return _buildContent(orderData, null); // ยังไม่มีไรเดอร์รับงาน
          }

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(riderId)
                .snapshots(),
            builder: (context, riderSnapshot) {
              LatLng? riderPosition;
              if (riderSnapshot.hasData && riderSnapshot.data!.exists) {
                final riderData =
                    riderSnapshot.data!.data() as Map<String, dynamic>;
                if (riderData.containsKey('gps') &&
                    riderData['gps'] is GeoPoint) {
                  final geoPoint = riderData['gps'] as GeoPoint;
                  riderPosition = LatLng(geoPoint.latitude, geoPoint.longitude);
                }
              }
              return _buildContent(orderData, riderPosition);
            },
          );
        },
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  // Widget หลักสำหรับสร้าง UI ทั้งหมด
  Widget _buildContent(Map<String, dynamic> orderData, LatLng? riderPosition) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMapSection(orderData, riderPosition),
          const SizedBox(height: 20),
          _buildCurrentStatusHeader(orderData),
          _buildStatusTimeline(orderData['statusHistory'] ?? []),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ส่วนแสดงแผนที่
  Widget _buildMapSection(
      Map<String, dynamic> orderData, LatLng? riderPosition) {
    final GeoPoint destPoint = orderData['deliveryAddress']['gps'] ??
        const GeoPoint(16.4746, 102.8247);
    final LatLng destinationLatLng =
        LatLng(destPoint.latitude, destPoint.longitude);

    final markers = <Marker>[
      Marker(
        point: destinationLatLng,
        child: const Icon(Icons.location_on, color: _primaryColor, size: 40),
      ),
    ];

    if (riderPosition != null) {
      markers.add(
        Marker(
          point: riderPosition,
          child: const Icon(Icons.two_wheeler, color: Colors.blue, size: 40),
        ),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      margin: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 8),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: riderPosition ?? destinationLatLng,
            initialZoom: 15.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }

  // ส่วนแสดงสถานะปัจจุบันและรายละเอียด
  Widget _buildCurrentStatusHeader(Map<String, dynamic> orderData) {
    final status = orderData['currentStatus'] ?? 'pending';
    final orderDetails = orderData['orderDetails'] ?? 'ไม่มีรายละเอียด';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            orderDetails,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'สถานะปัจจุบัน: ',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _translateStatus(status),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(status),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          const Text(
            'ประวัติการจัดส่ง',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ส่วนแสดงประวัติสถานะ (Timeline)
  Widget _buildStatusTimeline(List<dynamic> statusHistory) {
    if (statusHistory.isEmpty) {
      return const Center(child: Text('ไม่มีประวัติสถานะ'));
    }

    statusHistory.sort((a, b) {
      Timestamp tsA = a['timestamp'] ?? Timestamp.now();
      Timestamp tsB = b['timestamp'] ?? Timestamp.now();
      return tsB.compareTo(tsA);
    });

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: statusHistory.length,
      itemBuilder: (context, index) {
        final history = statusHistory[index];
        final status = history['status'] as String;
        final timestamp = (history['timestamp'] as Timestamp?)?.toDate();
        final formattedTime = timestamp != null
            ? DateFormat('dd MMM yyyy, HH:mm', 'th').format(timestamp)
            : 'ไม่มีข้อมูลเวลา';

        bool isFirst = index == 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Row(
            children: [
              Column(
                children: [
                  Icon(
                    isFirst
                        ? Icons.radio_button_checked
                        : Icons.circle_outlined,
                    color: isFirst ? _primaryColor : Colors.grey,
                    size: 20,
                  ),
                  if (index != statusHistory.length - 1)
                    Container(
                      height: 40,
                      width: 2,
                      color: Colors.grey.shade300,
                    )
                ],
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _translateStatus(status),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            isFirst ? FontWeight.bold : FontWeight.normal,
                        color: isFirst ? Colors.black : Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      formattedTime,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ฟังก์ชันสำหรับแปลสถานะเป็นภาษาไทย
  String _translateStatus(String status) {
    switch (status) {
      case 'pending':
        return 'รอไรเดอร์รับงาน';
      case 'accepted':
        return 'ไรเดอร์รับงานแล้ว';
      case 'picked_up':
        return 'รับพัสดุแล้ว';
      case 'in_transit':
        return 'กำลังนำส่ง';
      case 'delivered':
        return 'จัดส่งสำเร็จ';
      default:
        return status;
    }
  }

  // ฟังก์ชันสำหรับกำหนดสีตามสถานะ
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
      case 'accepted':
        return Colors.blue;
      case 'picked_up':
      case 'in_transit':
        return Colors.orange;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Bottom Navigation Bar
  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _primaryColor,
        boxShadow: [
          BoxShadow(
              color: Colors.black12, offset: Offset(0, -2), blurRadius: 5),
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
            Get.offAll(() => HomeScreen(
                  uid: widget.uid,
                  role: widget.role,
                ));
          } else if (index == 1) {
            Get.to(() => HistoryPage(
                  uid: widget.uid,
                  role: widget.role,
                ));
          } else if (index == 2) {
            Get.offAll(() => const SpeedDerApp());
          }
        },
      ),
    );
  }
}
