// file: lib/page/order_status_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/page/history_page.dart';
import 'package:delivery_project/page/home.dart';
import 'package:delivery_project/page/index.dart';
import 'package:delivery_project/page/send_package_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
// import 'package:dio/dio.dart'; // ไม่ต้องใช้แล้ว

// Constants
const Color _primaryColor = Color(0xFFC70808);
const Color _backgroundColor = Color(0xFFFDE9E9);

class OrderStatusPage extends StatefulWidget {
  final String? orderId;
  final String uid;
  final int role;

  const OrderStatusPage({
    super.key,
    this.orderId,
    required this.uid,
    required this.role,
  });

  @override
  State<OrderStatusPage> createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends State<OrderStatusPage> {
  final MapController _mapController = MapController();
  String? _selectedOrderId;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('th', null);
    _selectedOrderId = widget.orderId;
  }

  @override
  Widget build(BuildContext context) {
    bool isDetailPage =
        _selectedOrderId != null && _selectedOrderId!.isNotEmpty;

    return WillPopScope(
      onWillPop: () async {
        if (isDetailPage) {
          setState(() {
            _selectedOrderId = null;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          title: Text(isDetailPage ? 'ติดตามสถานะการจัดส่ง' : 'รายการส่งของ',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: _primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: isDetailPage
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _selectedOrderId = null;
                    });
                  },
                )
              : null,
          automaticallyImplyLeading: false,
        ),
        body: isDetailPage
            ? _buildOrderDetailView(_selectedOrderId!)
            : _buildOrderListView(),
        bottomNavigationBar: _buildBottomNavigationBar(context),
      ),
    );
  }

  Widget _buildOrderDetailView(String orderId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .snapshots(),
      builder: (context, orderSnapshot) {
        if (orderSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
          return const Center(child: Text('ไม่พบข้อมูลออเดอร์'));
        }

        final orderData = orderSnapshot.data!.data() as Map<String, dynamic>;

        LatLng? riderPosition;
        if (orderData.containsKey('riderLocation') &&
            orderData['riderLocation'] is GeoPoint) {
          final geoPoint = orderData['riderLocation'] as GeoPoint;
          riderPosition = LatLng(geoPoint.latitude, geoPoint.longitude);
        }

        return _buildContent(orderData, riderPosition);
      },
    );
  }

  Widget _buildContent(Map<String, dynamic> orderData, LatLng? riderPosition) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMapSection(orderData, riderPosition),
          const SizedBox(height: 20),
          _buildCurrentStatusHeader(orderData),
          _buildStatusTimeline(orderData['statusHistory'] ?? []),
          _buildEvidenceImage(orderData),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ✅✅✅ ส่วนที่แก้ไข: นำ PolylineLayer ออก ✅✅✅
  Widget _buildMapSection(
      Map<String, dynamic> orderData, LatLng? riderPosition) {
    final GeoPoint pickupPoint =
        orderData['pickupAddress']['gps'] ?? const GeoPoint(0, 0);
    final LatLng pickupLatLng =
        LatLng(pickupPoint.latitude, pickupPoint.longitude);
    final GeoPoint deliveryPoint =
        orderData['deliveryAddress']['gps'] ?? const GeoPoint(0, 0);
    final LatLng deliveryLatLng =
        LatLng(deliveryPoint.latitude, deliveryPoint.longitude);

    final currentStatus = orderData['currentStatus'];

    LatLng targetLatLng;
    IconData targetIcon;
    Color targetColor;

    if (currentStatus == 'accepted' || currentStatus == 'picked_up') {
      targetLatLng = pickupLatLng;
      targetIcon = Icons.store;
      targetColor = Colors.orange;
    } else {
      targetLatLng = deliveryLatLng;
      targetIcon = Icons.location_on;
      targetColor = Colors.red;
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      margin: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 8)
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: riderPosition ?? targetLatLng,
            initialZoom: 15.0,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=cb153d15cb4e41f59e25cfda6468f1a0',
              userAgentPackageName: 'com.example.app',
            ),
            // PolylineLayer ถูกลบออกจากส่วนนี้แล้ว
            MarkerLayer(
              markers: [
                if (riderPosition != null)
                  Marker(
                    point: riderPosition,
                    width: 80,
                    height: 80,
                    child: const Icon(Icons.two_wheeler,
                        color: Colors.blue, size: 40),
                  ),
                Marker(
                  point: targetLatLng,
                  width: 80,
                  height: 80,
                  child: Icon(targetIcon, color: targetColor, size: 40),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ... (โค้ดส่วนที่เหลือทั้งหมดเหมือนเดิม) ...

  Widget _buildEvidenceImage(Map<String, dynamic> orderData) {
    final statusHistory = orderData['statusHistory'] as List<dynamic>? ?? [];
    final imagesToShow = statusHistory.where((history) {
      final imgUrl = history['imgOfStatus'] as String?;
      return imgUrl != null && imgUrl.isNotEmpty;
    }).toList();
    if (imagesToShow.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('รูปภาพหลักฐาน',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...imagesToShow.map((history) {
            final status = history['status'] as String? ?? '';
            final imageUrl = history['imgOfStatus'] as String;
            return Card(
              margin: const EdgeInsets.only(bottom: 15),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.network(
                    imageUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(
                            height: 200,
                            child: Center(child: Icon(Icons.error))),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(_translateStatusToImageTitle(status),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
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

  // (โค้ดส่วนอื่นๆ ที่ไม่ได้แก้ไข)
  Widget _buildOrderListView() {
    return Column(
      children: [
        _buildActionCard(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'รายการทั้งหมด',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(child: _buildOrderList()),
      ],
    );
  }

  Widget _buildActionCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 5)
        ],
      ),
      child: Column(
        children: [
          const Text('ต้องการส่งของใช่ไหม?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: () => Get.to(
                () => SendPackagePage(uid: widget.uid, role: widget.role)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
            ),
            child: const Text('กดที่นี่เพื่อส่งของ'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: widget.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('คุณยังไม่มีรายการส่งของ'));
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = (data['createdAt'] as Timestamp?)?.toDate();
            final formattedDate = timestamp != null
                ? DateFormat('dd MMM yy', 'th').format(timestamp)
                : '';

            return Card(
              margin: const EdgeInsets.only(bottom: 15),
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined,
                    color: _primaryColor),
                title: Text(data['orderDetails'] ?? 'ไม่มีรายละเอียด',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    'วันที่: $formattedDate - สถานะ: ${_translateStatus(data['currentStatus'])}'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  setState(() {
                    _selectedOrderId = doc.id;
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCurrentStatusHeader(Map<String, dynamic> orderData) {
    final status = orderData['currentStatus'] ?? 'pending';
    final orderDetails = orderData['orderDetails'] ?? 'ไม่มีรายละเอียด';
    final deliveryAddress =
        orderData['deliveryAddress'] as Map<String, dynamic>? ?? {};
    final receiverName = deliveryAddress['receiverName'] ?? 'ไม่มีข้อมูล';
    final receiverPhone = deliveryAddress['receiverPhone'] ?? '-';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(orderDetails,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('สถานะปัจจุบัน: ',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
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
                      color: _getStatusColor(status)),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          const Text('ข้อมูลผู้รับ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text('ชื่อ: $receiverName'),
          Text('เบอร์โทร: $receiverPhone'),
          const Divider(height: 20),
          const Text('ประวัติการจัดส่ง',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(List<dynamic> statusHistory) {
    if (statusHistory.isEmpty) {
      return const Center(child: Text('ไม่มีประวัติสถานะ'));
    }
    statusHistory.sort((a, b) =>
        (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));
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
                    Container(height: 40, width: 2, color: Colors.grey.shade300)
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
                    Text(formattedTime,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _primaryColor,
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
          if (index == 0) {
            Get.offAll(() => HomeScreen(uid: widget.uid, role: widget.role));
          } else if (index == 1) {
            Get.to(() => HistoryPage(uid: widget.uid, role: widget.role));
          } else if (index == 2) {
            Get.offAll(() => const SpeedDerApp());
          }
        },
      ),
    );
  }
}
