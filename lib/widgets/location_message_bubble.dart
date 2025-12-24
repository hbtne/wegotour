import 'package:flutter/cupertino.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationMessageBubble extends StatelessWidget {
  final double lat;
  final double lng;

  const LocationMessageBubble({
    super.key,
    required this.lat,
    required this.lng,
  });

  @override
  Widget build(BuildContext context) {
    final LatLng position = LatLng(lat, lng);

    return SizedBox(
      height: 180,
      width: 250,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: position,
            zoom: 15,
          ),
          markers: {
            Marker(
              markerId: const MarkerId('current'),
              position: position,
            )
          },
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          liteModeEnabled: true, // ⚡ nhẹ cho chat
        ),
      ),
    );
  }
}
