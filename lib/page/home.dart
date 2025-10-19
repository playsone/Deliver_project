import 'dart:async';
import 'dart:developer';
import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/models/user_model.dart';
import 'package:delivery_project/page/history_page.dart';
import 'package:flutter/foundation.dart';
import 'package:delivery_project/page/index.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:delivery_project/page/edit_profile.dart';
import 'package:delivery_project/page/package_pickup_page.dart';
import 'package:delivery_project/page/order_status_page.dart';
import 'package:delivery_project/page/send_package_page.dart';

class HomeScreen extends StatefulWidget {
  final String uid;
  final int role;
  const HomeScreen({super.key, required this.uid, required this.role});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController mapController = MapController();
  Map<String, Marker> _markerMap = {};
  static const LatLng _initialCenter = LatLng(16.2470, 103.2522);
  static const double _initialZoom = 14.0;

  LatLng? currentPos;
  UserModel? _currentUser;
  List<Marker> _orderMarkers = [];
  StreamSubscription? _ordersSubscription;
  StreamSubscription<Position>? _positionStreamSubscription;

  List<Marker> get _fixedMarkers {
    if (_currentUser != null && _currentUser!.defaultGPS != null) {
      final userGps = _currentUser!.defaultGPS!;
      final userGps2 = _currentUser?.secondGPS;

      return [
        Marker(
          point: LatLng(userGps.latitude, userGps.longitude),
          width: 40,
          height: 40,
          child: const Tooltip(
            message: 'ที่อยู่หลักของคุณ',
            child: Icon(
              Icons.home,
              color: Colors.purple,
              size: 40.0,
            ),
          ),
        ),
        if (userGps2 != null) ...[
          Marker(
            point: LatLng(userGps2.latitude, userGps2.longitude),
            width: 40,
            height: 40,
            child: const Tooltip(
              message: 'ที่อยู่รองของคุณ',
              child: Icon(
                Icons.home_outlined,
                color: Colors.indigo,
                size: 40.0,
              ),
            ),
          ),
        ]
      ];
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _startListeningToUserLocation();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  void _startListeningToUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      log('Location services are disabled.');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('กรุณาเปิด GPS')));
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        log('Location permissions are denied.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('การเข้าถึงตำแหน่งถูกปฏิเสธ')));
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      log('Location permissions are permanently denied.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('การเข้าถึงตำแหน่งถูกปฏิเสธถาวร')));
      }
      return;
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position? position) {
      log('Position Update: $position');
      if (position != null && mounted) {
        setState(() {
          currentPos = LatLng(position.latitude, position.longitude);
        });
      }
    });
  }

  Future<void> _fetchUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _currentUser = UserModel.fromFirestore(doc);
        });
        _listenToOrders();
      }
    } catch (e) {
      log("Error fetching user data: $e");
    }
  }

  void _listenToOrders() {
    if (_currentUser == null) return;
    List<String> statusesToTrack = ['accepted', 'picked_up', 'in_transit'];

    final senderStream = FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: widget.uid)
        .where('currentStatus', whereIn: statusesToTrack)
        .snapshots();

    final riderStream = FirebaseFirestore.instance
        .collection('orders')
        .where('riderId', isEqualTo: widget.uid)
        .where('currentStatus', whereIn: statusesToTrack)
        .snapshots();

    final getDerStream = FirebaseFirestore.instance
        .collection('orders')
        .where('deliveryAddress.receiverPhone', isEqualTo: _currentUser!.phone)
        .where('currentStatus', whereIn: statusesToTrack)
        .snapshots();

    final mergedStream =
        StreamGroup.merge([senderStream, riderStream, getDerStream]);

    _ordersSubscription = mergedStream.listen((snapshot) {
      if (!mounted) return;

      log("ORDERS STREAM UPDATE: Found ${snapshot.docs.length} documents.");

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String orderId = doc.id;

        log("Processing Order ID: $orderId, Status: ${data['currentStatus']}, Has Location: ${data.containsKey('currentLocation')}");

        if (data.containsKey('currentLocation') &&
            data['currentLocation'] is GeoPoint) {
          final GeoPoint position = data['currentLocation'];
          _markerMap[orderId] = Marker(
            point: LatLng(position.latitude, position.longitude),
            width: 40,
            height: 40,
            child: Tooltip(
              message: data['customerId'] == _currentUser!.uid
                  ? "ส่งให้ ${data['deliveryAddress']['receiverName']}"
                  : "พัสดุ ${data['orderDetails']} ที่ต้องรับ",
              child: Icon(
                Icons.two_wheeler,
                color: (data['customerId'] == _currentUser!.uid)
                    ? Colors.red
                    : Colors.green,
                size: 40.0,
              ),
            ),
          );
        }
      }
      setState(() {
        _orderMarkers = _markerMap.values.toList();
      });
    }, onError: (error) {
      log("Error listening to orders: $error");
    });
  }

  void _moveCameraToCurrentLocation() {
    if (currentPos != null) {
      log('FloatingActionButton pressed. currentPos is: $currentPos');
      mapController.move(currentPos!, 16.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDE9E9),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              _buildMapSection(context),
              const SizedBox(height: 20),
              _buildIconButtons(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFC70808),
        onPressed: _moveCameraToCurrentLocation,
        tooltip: 'ค้นหาตำแหน่งปัจจุบัน',
        child: const Icon(Icons.gps_fixed, color: Colors.white),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      children: [
        ClipPath(
          child: Container(
            height: MediaQuery.of(context).size.height * 0.125,
            decoration: const BoxDecoration(color: Color(0xFFC70808)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'สวัสดีคุณ\n${_currentUser?.fullname ?? 'กำลังโหลด...'}',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              GestureDetector(
                onTap: () => _showProfileOptions(context),
                child: CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  backgroundImage: (_currentUser?.profile != null &&
                          _currentUser!.profile.isNotEmpty)
                      ? NetworkImage(_currentUser!.profile)
                      : const AssetImage('assets/image/default_avatar.png')
                          as ImageProvider,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIconButtons() {
    goToPickup() => Get.to(() => PackagePickupPage(
          role: widget.role,
          uid: widget.uid,
        ));

    goToStatus() => Get.to(() => OrderStatusPage(
          role: widget.role,
          uid: widget.uid,
        ));
    goToSend() => Get.to(() => SendPackagePage(
          role: widget.role,
          uid: widget.uid,
        ));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFeatureButton(
                'พัสดุที่ต้องรับ',
                Icons.inventory_2,
                goToPickup,
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFeatureButton(
                'สถานะสินค้า',
                Icons.timeline,
                goToStatus,
              ),
              const SizedBox(width: 15),
              _buildFeatureButton(
                'ส่งสินค้า',
                Icons.send_rounded,
                goToSend,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureButton(String text, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: Card(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 40,
                  color: const Color(0xFFC70808),
                ),
                const SizedBox(height: 5),
                Text(
                  text,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapSection(BuildContext context) {
    List<Marker> allMarkers = [
      ..._fixedMarkers,
      ..._orderMarkers,
      if (currentPos != null)
        Marker(
          point: currentPos!,
          width: 40,
          height: 40,
          child: const Tooltip(
            message: 'ตำแหน่งปัจจุบันของคุณ',
            child: Icon(
              Icons.my_location,
              color: Colors.cyanAccent,
              size: 40,
            ),
          ),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ติดตามสถานะการจัดส่ง',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            height: MediaQuery.of(context).size.height * 0.45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: _initialCenter,
                  initialZoom: _initialZoom,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                  onTap: (tapPosition, point) {
                    log("Map tapped at: $point");
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=cb153d15cb4e41f59e25cfda6468f1a0',
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  MarkerLayer(markers: allMarkers),
                ],
              ),
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
            label: 'ประวัติการส่ง',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: 'ออกจากระบบ',
          ),
        ],
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) {
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

  void _showProfileOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
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
                  color: Colors.grey,
                ),
              ),
              _buildOptionButton(
                context,
                'แก้ไขข้อมูลส่วนตัว',
                Icons.person_outline,
                () {
                  Get.back();
                  Get.to(() => EditProfilePage(
                        role: widget.role,
                        uid: widget.uid,
                      ));
                },
              ),
              _buildOptionButton(
                context,
                'ออกจากระบบ',
                Icons.person_outline,
                () {
                  Get.offAll(() => const SpeedDerApp());
                },
              ),
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
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
