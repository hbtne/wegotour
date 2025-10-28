import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stour/screens/trending.dart';
import 'package:stour/util/const.dart';
import 'package:stour/util/places.dart';
import 'package:stour/widgets/place_card.dart';
import 'package:stour/model/place.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:stour/widgets/search_card.dart';
import 'package:stour/screens/home_app_bar.dart';
import 'package:flutter/services.dart';
import 'package:stour/screens/coupon_business.dart';
import 'package:stour/screens/addPlace_screen.dart';
import 'business_feed_screen.dart';

class GoogleMapsController extends StatefulWidget {
  const GoogleMapsController({super.key});

  @override
  State<GoogleMapsController> createState() => _GoogleMapsControllerState();
}

class _GoogleMapsControllerState extends State<GoogleMapsController> {
  GoogleMapController? mapController;
  LatLng _center = const LatLng(10.870051045334415, 106.80301118465547);
  final Set<Marker> _markers = {};
  @override
  void initState() {
    super.initState();
    determinePosition().then(
          (position) {
        getUserAddress(position);
        setState(() {
          _center = LatLng(position.latitude, position.longitude);
          _markers.add(
            Marker(
              markerId: const MarkerId('user_location'),
              position: _center,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            ),
          );
          if (mapController != null) {
            mapController!.animateCamera(
              CameraUpdate.newLatLng(_center),
            );
          }
        });
      },
    ).catchError((e) {
      print('Error getting user location: $e');
    });
  }

  Future<Position> determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<List<String>> getAddressInfoFromPosition(Position position) async {
    List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
    Placemark placemark = placemarks.first;
    String country = placemark.country ?? "";
    String district = placemark.subAdministrativeArea ?? "";
    String city = placemark.administrativeArea ?? "";
    return [district, city, country];
  }

  void getUserAddress(Position src) async {
    currentLocationDetail = await getAddressInfoFromPosition(src);
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _center,
          zoom: 11.0,
        ),
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}

class MenuBusiness extends StatefulWidget {
  const MenuBusiness({super.key});
  @override
  State<MenuBusiness> createState() {
    return _MenuBusinessState();
  }

}


class _MenuBusinessState extends State<MenuBusiness> {
  late Stream<List<Place>> places;
  late Stream<List<Place>> food;

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacementNamed(context, '/signin');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }
  @override
  void initState() {
    super.initState();
    places = getAllPlaceFoodStream('stourplace1');
    food = getAllPlaceFoodStream('food');


  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
    return GestureDetector(
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus) {
          currentFocus.unfocus();
        }
      },
      child: Scaffold(
        backgroundColor: Constants.lightBG,
        appBar: const PreferredSize(
          preferredSize: Size.fromHeight(90),
          child: HomeAppBar(),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SafeArea(
            child: ListView(

              children: <Widget>[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMenuButton(
                        icon: Icons.videogame_asset,
                        label: 'Minigames',
                        onTap: () {Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) =>  CouponScreen1()),
                        );},
                      ),
                      _buildMenuButton(
                        icon: Icons.feed,
                        label: 'Feeds',
                        onTap: ()  {Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) =>  BusinessFeedScreen()),
                        );},
                      ),
                      // _buildMenuButton(
                      //   icon: Icons.calendar_today,
                      //   label: 'Thống kê',
                      //   onTap: () {},
                      // ),
                      _buildMenuButton(
                        icon: Icons.restaurant_menu,
                        label: 'Thêm địa điểm',
                        onTap: () {Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) =>  AddPlaceScreen()),
                        );},
                      ),
                    ],
                  ),
                ),
                const Text(
                  'Vị Trí Hiện Tại',
                  style: TextStyle(
                    color: Color(0xFF3B6332),
                    fontSize: 20.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                const SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: GoogleMapsController(),
                ),
                const SizedBox(height: 20.0),
                StreamBuilder<List<Place>>(
                  stream: places,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Lỗi: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Không có dữ liệu.'));
                    } else {
                      final places = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildPlaceRow('Địa Điểm Văn Hóa', places, context),
                          buildPlaceList(context, places, 'stourplace1'),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 5.0),
                StreamBuilder<List<Place>>(
                  stream: food,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Lỗi: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Không có dữ liệu.'));
                    } else {
                      final food = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildPlaceRow('Đặc Sản', food, context),
                          buildPlaceList(context, food, 'food'),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout),
                    label: const Text("Đăng xuất"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(128, 255, 209, 102),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget buildPlaceList(BuildContext context, List<Place> source, String collectionName) {
  return SizedBox(
    height: MediaQuery.of(context).size.height / 2.4,
    width: MediaQuery.of(context).size.width,
    child: ListView.builder(
      primary: false,
      shrinkWrap: true,
      scrollDirection: Axis.horizontal,
      itemCount: source.length,
      itemBuilder: (BuildContext context, int index) {
        Place place = source[index];
        return Padding(
          padding: const EdgeInsets.only(right: 10.0),
          child: GestureDetector(
            onLongPress: () {
              showModalBottomSheet(
                context: context,
                builder: (BuildContext context) {
                  return SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.edit),
                          title: const Text('Chỉnh sửa'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddPlaceScreen(
                                  placeData: {
                                    'id': place.id,
                                    'name': place.name,
                                    'address': place.address,
                                    'rating': place.rating,
                                    'image': place.img,
                                    'price': place.price,
                                    'history': place.history,
                                    'duration': place.duration,
                                    'opentime': place.openTime,
                                    'closetime': place.closeTime,
                                    'district': place.district,
                                    'city': place.city,
                                  },
                                  placeId: place.id,
                                ),
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.delete),
                          title: const Text('Xóa'),
                          onTap: () async {
                            final scaffoldContext = context;
                            Navigator.pop(context);
                            final shouldDelete = await showDialog<bool>(
                              context: scaffoldContext,
                              builder: (context) => AlertDialog(
                                title: const Text('Xác nhận'),
                                content: const Text('Bạn có chắc chắn muốn xóa địa điểm này không?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Hủy'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Xóa'),
                                  ),
                                ],
                              ),
                            );

                            if (shouldDelete == true) {
                              await FirebaseFirestore.instance
                                  .collection(collectionName)
                                  .doc(place.id)
                                  .delete();
                              if (!context.mounted) return;
                              if (scaffoldContext.mounted) {
                                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                                  const SnackBar(content: Text('Xóa thành công')),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            child: PlaceCard(place: place),
          ),
        );
      },
    ),
  );
}

Widget buildPlaceRow(String place, List<Place> source, BuildContext context) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: <Widget>[
      Text(
        place,
        style: const TextStyle(
          fontSize: 20.0,
          fontWeight: FontWeight.w800,
          color: Color(0xFF3B6332),
        ),
      ),
      TextButton(
        child: Text(
          "Xem tất cả (${source.length})",
          style: TextStyle(
            color: Constants.ratingBG,
          ),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (BuildContext context) {
                return Trending(source: source);
              },
            ),
          );
        },
      ),
    ],
  );
}

Widget _buildMenuButton({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return Column(
    children: [
      InkWell(
        onTap: onTap,
        child: CircleAvatar(
          backgroundColor: Constants.ratingBG,
          child: Icon(icon, color: Colors.white),
        ),
      ),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
    ],
  );
}

Widget buildSearchBar(BuildContext context) {
  return Container(
      margin: const EdgeInsets.fromLTRB(10, 5, 10, 0), child:  SearchCard());
}
