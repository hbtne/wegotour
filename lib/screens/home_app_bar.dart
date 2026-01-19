import "package:flutter/material.dart";
import "package:flutter_svg/svg.dart";
import "package:stour/widgets/search_card.dart";
import 'package:stour/screens/coupon_screen.dart';

import "../assets/icons/search_svg.dart";
import "../assets/icons/voucher_svg.dart";

class HomeAppBar extends StatelessWidget {
  const HomeAppBar({super.key});
  @override
  Widget build(BuildContext context) {
    Widget buildSearchBar(BuildContext context) {
      return Container(
          margin: const EdgeInsets.fromLTRB(10, 5, 10, 0), child: SearchCard());
    }
    final Color primary = const Color(0xFF4A5C3B);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (BuildContext context) {
                    return const CouponScreen();
                  },
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              child:
                SvgPicture.string(
                  voucherSVG,
              ),
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    appBar: AppBar(
                      leading: IconButton(
                        icon: Icon(Icons.arrow_back, color: primary),
                        onPressed: () => Navigator.pop(context),
                      ),
                      centerTitle: true,
                      title: Text(
                        'TÌM KIẾM',
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    body: buildSearchBar(context),
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              child: SvgPicture.string(searchSVG),
            ),
          ),

        ],
      ),
    );
  }
}
