import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stour/util/const.dart';
import 'package:stour/util/places.dart';
import 'package:flutter/services.dart';
import 'package:stour/screens/review_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import '../assets/icons/review_svg.dart';
class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.placeToDisplay});
  final Place placeToDisplay;

  @override
  State<DetailScreen> createState() {
    return _DetailScreenState();
  }
}

class _DetailScreenState extends State<DetailScreen> {
  bool hasLiked = false;
  Color buttonColor = Colors.black;
  Icon initialFavIcon = const Icon(Icons.favorite_border, size: 30);

  Future<void> _openGoogleMaps(String destinationAddress) async {
    try {
      // Get the user's current location
      Position position = await Geolocator.getCurrentPosition();
      double currentLatitude = position.latitude;
      double currentLongitude = position.longitude;

      // Build the Google Maps URL
      String googleMapsUrl =
          'https://www.google.com/maps/dir/?api=1&origin=$currentLatitude,$currentLongitude&destination=${Uri.encodeComponent(destinationAddress)}&travelmode=driving';

      // Launch the URL
      final Uri url = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not open Google Maps.';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 25),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                Text(
                  'CHI TIẾT',
                  style: GoogleFonts.poppins(
                      color: Constants.lightPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 20),
                ),
                IconButton(
                  onPressed: () {
                    return setState(
                      () {
                        hasLiked = !hasLiked;
                        buttonColor = (hasLiked)
                            ? const Color(0xFF3B6332)
                            : Color(0xFF3B6332);
                        initialFavIcon = (hasLiked)
                            ? const Icon(Icons.favorite, size: 30)
                            : const Icon(Icons.favorite_border, size: 30);
                      },
                    );
                  },
                  icon: initialFavIcon,
                  color: buttonColor,
                ),
              ],
            ),
            const SizedBox(height: 15),
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.network(
                widget.placeToDisplay.img,
                width: double.maxFinite,
              ),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.only(left: 10),
              alignment: Alignment.centerLeft,
              child: Text(
                widget.placeToDisplay.name,
                style: TextStyle(
                  fontFamily: 'Montserrat', // Sử dụng font Montserrat
                  fontSize: 22,
                  fontWeight: FontWeight.w700, // Đặt trọng số font
                  color: Color(0xFF3B6332),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_pin,
                    color: Color(0xFF60B0D1),
                    size: 25,
                  ),
                  const SizedBox(width: 5),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _openGoogleMaps(widget.placeToDisplay.address);
                  },
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      widget.placeToDisplay.address,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Color(0xFF60B0D1),
                         ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 20,
                              color:Color(0xFFFFD166)
                          ),
                          const SizedBox(width: 5),
                          Text(
                              '${widget.placeToDisplay.price.toStringAsFixed(0)}₫',
                              style: const TextStyle(fontSize: 20, color:Color(0xFFFFD166)))
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            CupertinoIcons.time,
                            size: 18,
                          ),
                          const SizedBox(width: 5),
                          Text(
                              '${widget.placeToDisplay.openTime.toStringAsFixed(0)}h - ${widget.placeToDisplay.closeTime.toStringAsFixed(0)}h',
                              style: const TextStyle(fontSize: 16))
                        ],
                      )
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:  Color.fromARGB(128, 255, 209, 102),  // Màu nền
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReviewScreen(
                              locationID: widget.placeToDisplay.id),
                        ),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.string(
                          reviewSVG,  // Icon SVG
                          width: 24,
                          height: 24,
                          color: Color(0xFF3B6332),  // Màu icon
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Xem đánh giá ',
                          style: TextStyle(
                            fontFamily: 'Montserrat',  // Font Montserrat
                            fontSize: 15,
                            fontWeight: FontWeight.w500,  // Độ đậm của chữ
                            color: Color(0xFF3B6332),  // Màu chữ
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Text(
                    widget.placeToDisplay.history,
                    style: TextStyle(
                      fontFamily: 'Montserrat', // Sử dụng font Montserrat
                      fontSize: 18,
                    ),                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
