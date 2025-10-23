import 'dart:async';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/models/package_model.dart';
import 'package:delivery_project/models/user_model.dart';
import 'package:delivery_project/models/userinfo_model.dart';
import 'package:delivery_project/page/history_page.dart';
import 'package:delivery_project/page/home.dart';
import 'package:delivery_project/page/index.dart';
import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

const Color _primaryColor = Color(0xFFC70808);
const Color _backgroundColor = Color(0xFFFDE9E9);
const Color _accentColor = Color(0xFF0D47A1);

class PackagePickupController extends GetxController {
  final String uid;
  final RxString userPhone = ''.obs;
  final TextEditingController searchController = TextEditingController();
  final RxString searchText = ''.obs;
  final RxBool isSearching = false.obs;
  UserModel? sender;

  PackagePickupController(this.uid);

  @override
  void onInit() {
    _fetchUserPhone();
    super.onInit();
    initializeDateFormatting('th', null);
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  Future<void> _fetchUserPhone() async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        userPhone.value = doc.data()?['phone'] ?? '';
      }
    } catch (e) {
      print('Error fetching user phone: $e');
    }
  }

  Future<void> performSearch() async {
    isSearching.value = true;
    await Future.delayed(const Duration(milliseconds: 100));
    searchText.value = searchController.text.trim();
    isSearching.value = false;
  }

  Stream<QuerySnapshot> getRecipientPackagesStream() {
    if (userPhone.value.isEmpty) {
      return Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('orders')
        .where('deliveryAddress.receiverPhone', isEqualTo: userPhone.value)
        .snapshots();
  }

  Future<UserInfo> getUserInfo(String? userId, String defaultName) async {
    if (userId == null || userId.isEmpty) return UserInfo(defaultName, '-');
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        return UserInfo(doc.data()?['fullname'] ?? defaultName,
            doc.data()?['phone'] ?? '-');
      }
      return UserInfo(defaultName, '-');
    } catch (e) {
      return UserInfo(defaultName, '-');
    }
  }
}

class PackagePickupPage extends StatefulWidget {
  final String uid;
  final int role;
  const PackagePickupPage({super.key, required this.uid, required this.role});

  @override
  State<PackagePickupPage> createState() => _PackagePickupPageState();
}

class _PackagePickupPageState extends State<PackagePickupPage> {
  String? _selectedPackageId;
  late final PackagePickupController _controller;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _controller = Get.put(PackagePickupController(widget.uid));
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
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDetailPage = _selectedPackageId != null;

    return WillPopScope(
      onWillPop: () async {
        if (isDetailPage) {
          setState(() {
            _selectedPackageId = null;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: isDetailPage
            ? _buildPackageDetailView(_selectedPackageId!)
            : _buildPackageListView(),
        bottomNavigationBar: _buildBottomNavigationBar(context),
      ),
    );
  }

  Widget _buildPackageListView() {
    return CustomScrollView(
      slivers: [
        _buildListHeader(),
        SliverPadding(
          padding: const EdgeInsets.all(20.0),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                _buildSearchBar(_controller),
                const SizedBox(height: 20),
                Obx(() {
                  if (_controller.userPhone.value.isEmpty ||
                      _controller.isSearching.value) {
                    return const Center(
                        child: Padding(
                      padding: EdgeInsets.only(top: 50),
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: _primaryColor),
                          SizedBox(height: 10),
                          Text('กำลังโหลดข้อมูล...')
                        ],
                      ),
                    ));
                  }
                  return _buildPackagesListStream(_controller);
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPackageDetailView(String packageId) {
    return Column(
      children: [
        AppBar(
          title: const Text('ติดตามสถานะการจัดส่ง',
              style: TextStyle(color: Colors.white)),
          backgroundColor: _primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _selectedPackageId = null;
              });
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .doc(packageId)
                .snapshots(),
            builder: (context, orderSnapshot) {
              if (orderSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
                return const Center(child: Text('ไม่พบข้อมูลออเดอร์'));
              }

              final orderData =
                  orderSnapshot.data!.data() as Map<String, dynamic>;
              final riderId = orderData['riderId'] as String?;
              final customerId = orderData['customerId'] as String?;

              LatLng? riderPosition;
              if (orderData.containsKey('currentLocation') &&
                  orderData['currentLocation'] is GeoPoint) {
                final geoPoint = orderData['currentLocation'] as GeoPoint;
                riderPosition = LatLng(geoPoint.latitude, geoPoint.longitude);
              }

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(customerId)
                    .snapshots(),
                builder: (context, senderSnapshot) {
                  final senderData =
                      senderSnapshot.data?.data() as Map<String, dynamic>?;

                  if (riderId == null || riderId.isEmpty) {
                    return _buildDetailContent(
                        orderData, senderData, null, riderPosition);
                  }

                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(riderId)
                        .snapshots(),
                    builder: (context, riderSnapshot) {
                      final riderData =
                          riderSnapshot.data?.data() as Map<String, dynamic>?;
                      return _buildDetailContent(
                          orderData, senderData, riderData, riderPosition);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPackagesListStream(PackagePickupController controller) {
    return StreamBuilder<QuerySnapshot>(
      stream: controller.getRecipientPackagesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _primaryColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 50.0),
              child: Text(
                '📦 ไม่มีรายการพัสดุที่กำลังถูกส่งถึงคุณในขณะนี้',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }

        final allPackages = snapshot.data!.docs
            .map((doc) => PackageModel.fromFirestore(doc))
            .toList();
        final filterText = controller.searchText.value.toLowerCase();

        if (filterText.isNotEmpty) {
          return FutureBuilder<List<PackageModel>>(
            future: _fetchNamesAndFilter(controller, allPackages, filterText),
            builder: (context, filterSnapshot) {
              if (filterSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.orange));
              }
              final filteredPackages = filterSnapshot.data ?? [];
              return _buildFilteredPackageList(controller, filteredPackages);
            },
          );
        }

        allPackages.sort((a, b) {
          int statusCompare = _statusOrder(a.currentStatus)
              .compareTo(_statusOrder(b.currentStatus));
          if (statusCompare != 0) return statusCompare;
          return 0;
        });

        return Column(
          children: allPackages.map((package) {
            return FutureBuilder<Map<String, String>>(
              future:
                  _fetchNames(controller, package.customerId, package.riderId),
              builder: (context, nameSnapshot) {
                return _buildPackageItemFromFuture(
                    package, nameSnapshot, controller);
              },
            );
          }).toList(),
        );
      },
    );
  }

  int _statusOrder(String status) {
    switch (status) {
      case 'delivered':
        return 0;
      case 'in_transit':
        return 1;
      case 'picked_up':
        return 2;
      case 'accepted':
        return 3;
      case 'pending':
        return 4;
      default:
        return 5;
    }
  }

  Widget _buildDetailContent(
      Map<String, dynamic> orderData,
      Map<String, dynamic>? senderData,
      Map<String, dynamic>? riderData,
      LatLng? riderPosition) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMapSection(orderData, riderPosition),
          const SizedBox(height: 20),
          _buildCurrentStatusHeader(orderData, senderData, riderData),
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
            initialCenter:
                riderPosition ?? deliveryLatLng ?? const LatLng(16.24, 103.25),
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
                if (riderPosition != null)
                  Marker(
                    point: riderPosition,
                    width: 80,
                    height: 80,
                    child: const Icon(Icons.two_wheeler,
                        color: Colors.blue, size: 40),
                  ),
                if (deliveryLatLng != null)
                  Marker(
                    point: deliveryLatLng,
                    width: 80,
                    height: 80,
                    child: Tooltip(
                      message:
                          '${deliveryAddress['receiverName'] ?? "Error!!!"} ',
                      child: const Icon(Icons.pin_drop_outlined,
                          color: Colors.red, size: 40),
                    ),
                  ),
                if (pickupLatLng != null)
                  Marker(
                    point: pickupLatLng,
                    width: 80,
                    height: 80,
                    child: const Tooltip(
                      message: 'คนส่ง',
                      child: Icon(Icons.gamepad_sharp,
                          color: Colors.red, size: 40),
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
      Map<String, dynamic>? senderData, Map<String, dynamic>? riderData) {
    final status = orderData['currentStatus'] ?? 'pending';
    final orderDetails =
        orderData['orderDetails']?.toString().trim() ?? 'ไม่มีรายละเอียด';

    final senderName = senderData?['fullname'] ?? 'ไม่มีข้อมูล';
    final senderPhone = senderData?['phone'] ?? '-';

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
          const Text('ข้อมูลผู้ส่ง',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text('ชื่อ: $senderName'),
          Text('เบอร์โทร: $senderPhone'),
          if (riderData != null) ...[
            const Divider(height: 20),
            _buildRiderInfoSection(riderData),
          ],
          const Divider(height: 20),
          const Text('ประวัติการจัดส่ง',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRiderInfoSection(Map<String, dynamic> riderData) {
    final riderName = riderData['fullname'] ?? 'ไม่มีข้อมูล';
    final riderPhone = riderData['phone'] ?? '-';
    final vehicleNo = riderData['vehicle_no'] ?? '-';

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
                        height: (imageUrl != null && imageUrl.isNotEmpty)
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
              panEnabled: false,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(imageUrl),
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, String>> _fetchNames(PackagePickupController controller,
      String customerId, String? riderId) async {
    final senderInfo = await controller.getUserInfo(customerId, 'ผู้ส่ง');
    final riderInfo = riderId != null
        ? await controller.getUserInfo(riderId, 'ไรเดอร์')
        : UserInfo('ยังไม่มีไรเดอร์', '-');
    return {
      'sender': '${senderInfo.name}|${senderInfo.phone}',
      'rider': '${riderInfo.name}|${riderInfo.phone}',
    };
  }

  Future<List<PackageModel>> _fetchNamesAndFilter(
      PackagePickupController controller,
      List<PackageModel> allPackages,
      String filterText) async {
    final filteredList = <PackageModel>[];
    for (var package in allPackages) {
      final senderInfo =
          await controller.getUserInfo(package.customerId, 'ผู้ส่ง');
      final riderInfo = package.riderId != null
          ? await controller.getUserInfo(package.riderId, 'ไรเดอร์')
          : UserInfo('ยังไม่มีไรเดอร์', '-');
      bool matches = false;
      if (package.id.toLowerCase().contains(filterText)) matches = true;
      if (senderInfo.name.toLowerCase().contains(filterText) ||
          senderInfo.phone.contains(filterText)) matches = true;
      if (riderInfo.name.toLowerCase().contains(filterText) ||
          riderInfo.phone.contains(filterText)) matches = true;
      if (package.orderDetails.toLowerCase().contains(filterText))
        matches = true;

      if (matches) {
        package.senderInfo = senderInfo;
        package.riderInfo = riderInfo;
        filteredList.add(package);
      }
    }
    return filteredList;
  }

  Widget _buildFilteredPackageList(
      PackagePickupController controller, List<PackageModel> filteredPackages) {
    if (filteredPackages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 50.0),
          child: Text(
            'ไม่พบรายการพัสดุที่ตรงกับคำค้นหา',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }
    return Column(
      children: filteredPackages.map((package) {
        final senderInfo = package.senderInfo!;
        final riderInfo = package.riderInfo!;
        return _buildPackageItem(
          package: package,
          senderName: senderInfo.name,
          senderPhone: senderInfo.phone,
          riderName: riderInfo.name,
          riderPhone: riderInfo.phone,
          onTap: () {
            setState(() {
              _selectedPackageId = package.id;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildPackageItemFromFuture(
    PackageModel package,
    AsyncSnapshot<Map<String, String>> nameSnapshot,
    PackagePickupController controller,
  ) {
    if (nameSnapshot.connectionState == ConnectionState.waiting) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: LinearProgressIndicator()));
    }

    String senderInfo = nameSnapshot.data?['sender'] ?? 'กำลังโหลด...';
    String riderInfo = nameSnapshot.data?['rider'] ?? 'กำลังโหลด...';
    final senderParts = senderInfo.split('|');
    final riderParts = riderInfo.split('|');

    return _buildPackageItem(
      package: package,
      senderName: senderParts[0],
      senderPhone: senderParts.length > 1 ? senderParts[1] : '-',
      riderName: riderParts[0],
      riderPhone: riderParts.length > 1 ? riderParts[1] : '-',
      onTap: () {
        setState(() {
          _selectedPackageId = package.id;
        });
      },
    );
  }

  Widget _buildPackageItem({
    required PackageModel package,
    required String senderName,
    required String senderPhone,
    required String riderName,
    required String riderPhone,
    required VoidCallback onTap,
  }) {
    final statusText = _translateStatus(package.currentStatus);
    final statusColor = _getStatusColor(package.currentStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'พัสดุ: ${package.orderDetails}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const Divider(height: 15, thickness: 1),
              _buildDetailRow(Icons.person, 'ผู้ส่ง:', senderName, senderPhone),
              _buildDetailRow(Icons.two_wheeler_outlined, 'ไรเดอร์:', riderName,
                  riderPhone),
              _buildDetailRow(Icons.qr_code, 'รหัสพัสดุ:', package.id, null),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      IconData icon, String title, String name, String? phone) {
    String detailText = phone != null && phone != '-'
        ? '$name (Tel: $phone)'
        : (name.isEmpty || name == 'ไม่ระบุรายละเอียดสินค้า'
            ? 'ไม่ระบุ'
            : name);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: _accentColor),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300, width: 0.5),
              ),
              child: Text(detailText,
                  style: const TextStyle(fontSize: 14, color: Colors.black87)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    return SliverAppBar(
      floating: false,
      pinned: true,
      backgroundColor: _primaryColor,
      flexibleSpace: const FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(left: 40),
        centerTitle: false,
        title: Padding(
          padding: EdgeInsets.only(left: 20, bottom: 15),
          child: Text(
            'พัสดุที่ต้องรับ',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Get.back(),
      ),
    );
  }

  Widget _buildSearchBar(PackagePickupController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller.searchController,
        decoration: InputDecoration(
          hintText: 'ค้นหาด้วยชื่อ/เบอร์โทร หรือ รหัสพัสดุ',
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search, color: _primaryColor),
          suffixIcon: IconButton(
            icon: const Icon(Icons.send, color: _primaryColor),
            onPressed: controller.performSearch,
          ),
        ),
        onSubmitted: (_) => controller.performSearch(),
      ),
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

class HeaderClipper extends CustomClipper<ui.Path> {
  @override
  ui.Path getClip(Size size) {
    double h = size.height;
    double w = size.width;
    ui.Path path = ui.Path();

    path.lineTo(0, h * 0.85);
    path.quadraticBezierTo(w * 0.15, h * 0.95, w * 0.45, h * 0.85);
    path.quadraticBezierTo(w * 0.65, h * 0.75, w, h * 0.8);
    path.lineTo(w, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<ui.Path> oldClipper) => false;
}
