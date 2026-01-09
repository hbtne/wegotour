// @dart=2.17
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:stour/util/const.dart';
import 'package:stour/util/places.dart';
import 'package:stour/screens/details.dart';
import 'package:stour/assets/icons/star_svg.dart';
class PlaceCard extends StatefulWidget {
  final Place place;

  const PlaceCard({
    super.key,
    required this.place,
  });

  @override
  State<PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends State<PlaceCard> {
  @override
  Widget build(BuildContext context) {
    final ratingCount = widget.place.ratingCountYear ?? 0;
    final rating = ratingCount == 0 || widget.place.ratingSumYear == 0
        ? 3.0
        : (widget.place.ratingSumYear ?? 0) / ratingCount;
    return Padding(
      padding: const EdgeInsets.only(top: 5.0, bottom: 5.0),
      child: SizedBox(
        height: MediaQuery.of(context).size.height / 2.9,
        width: MediaQuery.of(context).size.width / 1.5,

        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (BuildContext context) {
                  return DetailScreen(placeToDisplay: widget.place);
                },
              ),
            );
          },
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),

            ),
            elevation: 3.0,
            color: Constants.cardBG,
            child: Column(
              children: <Widget>[
                Stack(
                  children: <Widget>[
                    SizedBox(
                      height: MediaQuery.of(context).size.height / 3.7,
                      width: MediaQuery.of(context).size.width,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10.0),
                          topRight: Radius.circular(10.0),
                        ),
                        child: Image.network(
                          widget.place.img,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6.0,
                      right: 6.0,
                      child: Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4.0)),
                            color: Colors.transparent,

                        child: Padding(
                          padding: const EdgeInsets.all(3.0),
                          child: Row(
                            children: <Widget>[
                              Text(
                                " ${rating.toStringAsFixed(1)} ",
                                style: const TextStyle(
                                  fontSize: 12.0,
                                  color: Colors.white,
                                ),
                              ),
                                SvgPicture.string(
                                  starSVG,
                                  height: 20,
                                  width: 20,
                                ),

                            ],

                        ),
                      ),
                    ),),
                    Positioned(
                      top: 6.0,
                      left: 6.0,
                      child: Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3.0)),
                            color: Constants.timeBG,

                        child: Padding(
                          padding: const EdgeInsets.all(4.0),

                          child: Row(children: [
                            Icon(
                              Icons.access_time,
                              color: Constants.ratingBG,
                              size: 20,
                            ),
                            Text(
                              " ${widget.place.openTime.toStringAsFixed(0)}-${widget.place.closeTime.toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontSize: 12.0,
                                color: Colors.white,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsets.only(left: 15.0),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: Text(
                      widget.place.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.only(left: 15.0),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: Text(
                      widget.place.address,
                      style: const TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
