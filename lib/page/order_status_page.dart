// order_status_page.dart

import 'package:delivery_project/page/history_page.dart';
import 'package:delivery_project/page/home.dart';
import 'package:delivery_project/page/index.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

// Constants (ประกาศซ้ำเพื่อความสะดวกในการแยกไฟล์)
const Color _primaryColor = Color(0xFFC70808);
const Color _backgroundColor = Color(0xFFFDE9E9);
const Color _accentColor = Color(0xFF0D47A1);

class OrderStatusPage extends StatefulWidget {
  final String? orderId;
  final String uid;
  final int role; // 1 = Sender (ผู้ส่ง), 2 = Recipient (ผู้รับ), 3 = Rider

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

  // สถานะสำหรับเก็บข้อมูลผู้ใช้งานที่เกี่ยวข้อง
  Map<String, dynamic>? _senderData;
  Map<String, dynamic>? _recipientData;
  Map<String, dynamic>? _riderData;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('th', null);
    _selectedOrderId = widget.orderId;
  }

  @override
  void dispose() {
    super.dispose();
  }

  // NEW: Helper สำหรับดึงข้อมูลผู้ส่ง
  Future<void> _fetchSenderData(String senderId) async {
    if (senderId.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(senderId)
        .get();
    if (mounted) {
      setState(() {
        _senderData = doc.data();
      });
    }
  }

  // NEW: Helper สำหรับดึงข้อมูลผู้รับ (จาก Order Data)
  void _setRecipientDataFromOrder(Map<String, dynamic> orderData) {
    if (mounted) {
      setState(() {
        _recipientData = {
          'fullname':
              orderData['deliveryAddress']?['receiverName'] ?? 'ไม่ระบุ',
          'phone': orderData['deliveryAddress']?['receiverPhone'] ?? '-',
        };
      });
    }
  }

  // NEW: Helper สำหรับดึงข้อมูลไรเดอร์
  Future<void> _fetchRiderData(String? riderId) async {
    if (riderId == null || riderId.isEmpty) return;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(riderId).get();
    if (mounted) {
      setState(() {
        _riderData = doc.data();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDetailPage =
        _selectedOrderId != null && _selectedOrderId!.isNotEmpty;

    String appBarTitle;
    if (isDetailPage) {
      if (widget.role == 1) {
        // Sender
        appBarTitle = 'ติดตามการส่งของ (บทบาทผู้ส่ง)';
      } else if (widget.role == 2) {
        // Recipient
        appBarTitle = 'ติดตามพัสดุรับเข้า (บทบาทผู้รับ)';
      } else {
        appBarTitle = 'ติดตามสถานะการจัดส่ง';
      }
    } else {
      appBarTitle = 'รายการส่งของ/รับของ'; // กรณีเปิดหน้านี้โดยไม่มี orderId
    }

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
          title: Text(appBarTitle, style: const TextStyle(color: Colors.white)),
          backgroundColor: _primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: isDetailPage
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    // กลับไปหน้า PackagePickupPage
                    Get.back();
                  },
                )
              : null,
          automaticallyImplyLeading: !isDetailPage,
        ),
        body: isDetailPage
            ? _buildOrderDetailView(_selectedOrderId!)
            : Center(
                child: Text('กรุณาเลือกรายการจากหน้าหลัก',
                    style: TextStyle(color: Colors.grey.shade700))),
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
        final riderId = orderData['riderId'] as String?;
        final senderId = orderData['customerId'] as String;

        // Trigger fetching related user data
        if (_senderData == null) _fetchSenderData(senderId);
        if (_recipientData == null) _setRecipientDataFromOrder(orderData);
        if (riderId != null && _riderData == null) _fetchRiderData(riderId);

        LatLng? riderPosition;
        if (orderData.containsKey('currentLocation') &&
            orderData['currentLocation'] is GeoPoint) {
          final geoPoint = orderData['currentLocation'] as GeoPoint;
          riderPosition = LatLng(geoPoint.latitude, geoPoint.longitude);
        }

        // Wait until essential data is loaded before building content
        if (_senderData == null || _recipientData == null) {
          return const Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text('กำลังโหลดข้อมูลผู้ส่งและผู้รับ...')
            ],
          ));
        }

        return _buildContent(orderData, riderPosition);
      },
    );
  }

  Widget _buildContent(Map<String, dynamic> orderData, LatLng? riderPosition) {
    // ตรวจสอบบทบาทเพื่อกำหนดข้อมูลที่แสดง
    final bool isSender = widget.role == 1;

    // ข้อมูลหลักที่ผู้ใช้ต้องการดู
    final Map<String, dynamic>? primaryUserInfo =
        isSender ? _recipientData : _senderData;
    final String primaryUserRoleTitle = isSender ? 'ผู้รับ' : 'ผู้ส่ง';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMapSection(orderData, riderPosition),
          const SizedBox(height: 20),
          _buildCurrentStatusHeader(
              orderData, primaryUserInfo, primaryUserRoleTitle),
          _buildStatusTimeline(orderData['statusHistory'] ?? []),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMapSection(
      Map<String, dynamic> orderData, LatLng? riderPosition) {
    final deliveryAddress =
        orderData['deliveryAddress'] as Map<String, dynamic>? ?? {};
    final deliveryGps = deliveryAddress['gps'] as GeoPoint?;
    final LatLng? deliveryLatLng = deliveryGps != null
        ? LatLng(deliveryGps.latitude, deliveryGps.longitude)
        : null;

    final pickupAddress =
        orderData['pickupAddress'] as Map<String, dynamic>? ?? {};
    final pickupGps = pickupAddress['gps'] as GeoPoint?;
    final LatLng? pickupLatLng = pickupGps != null
        ? LatLng(pickupGps.latitude, pickupGps.longitude)
        : null;

    final initialCenter = riderPosition ??
        deliveryLatLng ??
        pickupLatLng ??
        const LatLng(16.24, 103.25);

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
            initialCenter: initialCenter,
            initialZoom: 14.0,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=cb153d15cb4e41f59e25cfda6468f1a0',
              userAgentPackageName: 'com.example.app',
            ),
            MarkerLayer(
              markers: [
                if (pickupLatLng != null)
                  Marker(
                    point: pickupLatLng,
                    width: 80,
                    height: 80,
                    child: const Tooltip(
                      message: 'จุดรับพัสดุ',
                      child:
                          Icon(Icons.location_on, color: Colors.blue, size: 40),
                    ),
                  ),
                if (riderPosition != null)
                  Marker(
                    point: riderPosition,
                    width: 80,
                    height: 80,
                    child: const Icon(Icons.two_wheeler,
                        color: Colors.purple, size: 40),
                  ),
                if (deliveryLatLng != null)
                  Marker(
                    point: deliveryLatLng,
                    width: 80,
                    height: 80,
                    child: const Tooltip(
                      message: 'จุดหมายปลายทาง',
                      child: Icon(Icons.flag, color: Colors.red, size: 40),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatusHeader(Map<String, dynamic> orderData,
      Map<String, dynamic>? primaryUserInfo, String primaryUserRoleTitle) {
    final status = orderData['currentStatus'] ?? 'pending';
    final orderDetails =
        orderData['orderDetails'].toString().trim() ?? 'ไม่มีรายละเอียด';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(orderDetails,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Divider(height: 20),
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

          // ข้อมูลผู้รับ/ผู้ส่ง ที่เราต้องการดู (ตามบทบาท)
          _buildRelatedUserInfoSection(primaryUserInfo, primaryUserRoleTitle),

          // ข้อมูลไรเดอร์
          if (orderData['riderId'] != null &&
              orderData['riderId'].isNotEmpty) ...[
            const Divider(height: 20),
            _buildRiderInfoSection(_riderData),
          ],

          const Divider(height: 20),
          const Text('ประวัติการจัดส่ง',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Widget แสดงข้อมูลผู้ส่งหรือผู้รับ
  Widget _buildRelatedUserInfoSection(
      Map<String, dynamic>? userData, String title) {
    final name = userData?['fullname'] ?? 'กำลังโหลด...';
    final phone = userData?['phone'] ?? '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ข้อมูล$title',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text('ชื่อ: $name'),
        Text('เบอร์โทร: $phone'),
      ],
    );
  }

  Widget _buildRiderInfoSection(Map<String, dynamic>? riderData) {
    final riderName = riderData?['fullname'] ?? 'กำลังโหลด...';
    final riderPhone = riderData?['phone'] ?? '-';
    final vehicleNo = riderData?['vehicle_no'] ?? '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ข้อมูลไรเดอร์',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text('ชื่อ: $riderName'),
        Text('เบอร์โทร: $riderPhone'),
        Text('ทะเบียนรถ: $vehicleNo'),
      ],
    );
  }

  Widget _buildStatusTimeline(List<dynamic> statusHistory) {
    if (statusHistory.isEmpty) {
      return const Center(child: Text('ไม่มีประวัติสถานะ'));
    }
    // Sort: Newest first
    statusHistory.sort((a, b) =>
        (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: statusHistory.length,
      itemBuilder: (context, index) {
        final history = statusHistory[index] as Map<String, dynamic>;
        final status = history['status'] as String;
        final timestamp = (history['timestamp'] as Timestamp?)?.toDate();
        final imageUrl = history['imgOfStatus'] as String?;
        final formattedTime = timestamp != null
            ? DateFormat('dd MMM yyyy, HH:mm', 'th').format(timestamp)
            : 'ไม่มีข้อมูลเวลา';
        bool isFirst = index == 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(
                    isFirst
                        ? Icons.radio_button_checked
                        : Icons.circle_outlined,
                    color: isFirst ? _getStatusColor(status) : Colors.grey,
                    size: 20,
                  ),
                  if (index != statusHistory.length - 1)
                    Container(
                        height: (imageUrl != null &&
                                imageUrl.isNotEmpty &&
                                imageUrl != 'received by recipient')
                            ? 120
                            : 40,
                        width: 2,
                        color: Colors.grey.shade300)
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
                    if (imageUrl != null &&
                        imageUrl.isNotEmpty &&
                        imageUrl != 'received by recipient')
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: GestureDetector(
                          onTap: () => _showFullScreenImage(context, imageUrl),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.network(
                              imageUrl,
                              height: 100,
                              width: 100,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                return progress == null
                                    ? child
                                    : const SizedBox(
                                        height: 100,
                                        width: 100,
                                        child: Center(
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2)));
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.error,
                                    color: Colors.red);
                              },
                            ),
                          ),
                        ),
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

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.8,
              maxScale: 4,
              child: Image.network(imageUrl),
            ),
          ),
        );
      },
    );
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

// Helper functions (ใช้ร่วมกับ OrderStatusPage)
String _translateStatus(String status) {
  switch (status) {
    case 'pending':
      return 'รอไรเดอร์รับงาน';
    case 'assigned':
    case 'accepted':
      return 'ไรเดอร์รับงานแล้ว';
    case 'picked_up':
      return 'รับพัสดุแล้ว';
    case 'in_transit':
      return 'กำลังนำส่ง';
    case 'delivered':
      return 'จัดส่งสำเร็จ';
    case 'completed':
      return 'ผู้รับยืนยันแล้ว ✔️';
    default:
      return status;
  }
}

Color _getStatusColor(String status) {
  switch (status) {
    case 'pending':
      return Colors.blueGrey;
    case 'assigned':
    case 'accepted':
      return Colors.orange;
    case 'picked_up':
    case 'in_transit':
      return Colors.amber.shade800;
    case 'delivered':
    case 'completed':
      return Colors.green;
    default:
      return Colors.grey;
  }
}
