import 'package:flutter/material.dart';
import 'package:stour/util/places.dart';
import 'package:stour/widgets/timeline_day.dart';
import 'package:google_fonts/google_fonts.dart';


// ignore: must_be_immutable
class ViewSavedTour extends StatefulWidget {
  SavedTourClass savedTour;
  ViewSavedTour({required this.savedTour, super.key});
  @override
  State<ViewSavedTour> createState() => _ViewSavedTourState();
}

class _ViewSavedTourState extends State<ViewSavedTour> {
  void updateResultList(List<Place> newList, int idx) {
    setState(() {
      widget.savedTour.addedPlaces[idx] = newList;
    });
  }

  @override
  Widget build(BuildContext context) {
    double totalMoney = 0;
    for (int i = 0; i < widget.savedTour.addedPlaces.length; i++) {
      for (int j = 0; j < widget.savedTour.addedPlaces[i].length; j++) {
        totalMoney += widget.savedTour.addedPlaces[i][j].price;
      }
    }

    return Scaffold(
      backgroundColor:  Colors.white,

      appBar: AppBar(
        backgroundColor:  Colors.white,
        title: Text(
          widget.savedTour.name,
          style: const TextStyle(
            color: Color.fromARGB(255, 35, 52, 10),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: Color.fromARGB(255, 35, 52, 10)), // Change the color here
          onPressed: () {
            Navigator.pop(context);
          },
        ),

      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              width: double.maxFinite,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                elevation: 3.0,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Tổng Quan',
                        style: GoogleFonts.roboto(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: const Color(0x80FFD166),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Số ngày: ${widget.savedTour.addedPlaces.length}',
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                color: const Color(0xFF3B6332),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0x80FFD166),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Số tiền ước tính: ${totalMoney.toStringAsFixed(0)}₫',
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                color: const Color(0xFF3B6332),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),

                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.savedTour.addedPlaces.length,
              itemBuilder: (ctx, idx) {
                return Expanded(
                    child: TimelineDay(widget.savedTour.addedPlaces[idx],
                        idx + 1, updateResultList));
              },
            ),
          ),
        ],
      ),
    );
  }
}

