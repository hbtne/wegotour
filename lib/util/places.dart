import 'package:cloud_firestore/cloud_firestore.dart';

class Place {
  String id;
  final String name;
  final String address;
  final String rating;
  final String img;
  final num price;
  final String history;
  final num duration;
  final num openTime;
  final num closeTime;
  final String district;
  final String city;
  final int? checkinCount;
  final int? reviewCount;
  final int? checkinCountMonth;
  final int? reviewCountMonth;
  final String? ratingMonth;
  final int? checkinCountYear;
  final int? reviewCountYear;
  final String? ratingYear;
  bool isAccepted; // Thêm trường isAccepted

  Place({
    required this.id,
    required this.name,
    required this.address,
    required this.rating,
    required this.img,
    required this.price,
    required this.history,
    required this.duration,
    required this.district,
    required this.city,
    required this.openTime,
    required this.closeTime,
     this.checkinCount,
     this.reviewCount,
     this.checkinCountMonth,
     this.reviewCountMonth,
     this.ratingMonth,
     this.checkinCountYear,
     this.reviewCountYear,
     this.ratingYear,
    required this.isAccepted,
  });
  factory Place.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Place(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      rating: data['rating']?.toString() ?? '0.0',
      img: data['image'] ?? '', // Lưu ý: field trong Firestore là 'image' nha
      price: data['price'] ?? 0,
      history: data['history'] ?? '',
      duration: data['duration'] ?? 0,
      district: data['district'] ?? '',
      city: data['city'] ?? '',
      openTime: data['opentime'] ?? 0,
      closeTime: data['closetime'] ?? 0,
      checkinCount: data['checkinCount'] ?? 10,
      reviewCount: data['reviewCount'] ?? 25,
      checkinCountMonth: data['checkinCountMonth'] ?? 10,
      reviewCountMonth: data['reviewCountMonth'] ?? 25,
      ratingMonth: data['ratingMonth'] ?? "5",
      checkinCountYear: data['checkinCountYear'] ?? 10,
      reviewCountYear: data['reviewCountYear'] ?? 25,
      ratingYear: data['ratingYear'] ?? "4.9",
      isAccepted: data['isAccepted'] ?? false, // Thêm trường isAccepted
    );
  }
}
class SavedTourClass {
  final List<List<Place>> addedPlaces;
  String name;
  final DateTime timeSaved;
  final String id; // Thêm id
  final DateTime departureDate ;
  final DateTime returnDate ;
  bool completed;

  SavedTourClass({
    required this.addedPlaces,
    required this.name,
    required this.timeSaved,
    required this.id,
    required this.departureDate,
    required this.returnDate,
    this.completed = false,

  });

  factory SavedTourClass.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    List<dynamic> flatPlaces = data['addedPlaces'] ?? [];

    // Nhóm lại theo dayIndex
    Map<int, List<Place>> groupedByDay = {};

    for (var placeData in flatPlaces) {
      int dayIndex = placeData['dayIndex'] ?? 1;
      Place place = Place(
        id: placeData['id'] ?? '',
        name: placeData['name'] ?? '',
        address: placeData['address'] ?? '',
        rating: placeData['rating']?.toString() ?? '0.0',
        img: placeData['img'] ?? '',
        price: placeData['price'] ?? 0,
        history: placeData['history'] ?? '',
        duration: placeData['duration'] ?? 0,
        openTime: placeData['openTime'] ?? 0,
        closeTime: placeData['closeTime'] ?? 0,
        district: placeData['district'] ?? '',
        city: placeData['city'] ?? '',
        checkinCount: data['checkinCount'] ?? 10,
        reviewCount: data['reviewCount'] ?? 25,
        checkinCountMonth: data['checkinCountMonth'] ?? 10,
        reviewCountMonth: data['reviewCountMonth'] ?? 25,
        ratingMonth: data['ratingMonth'] ?? "5",
        checkinCountYear: data['checkinCountYear'] ?? 10,
        reviewCountYear: data['reviewCountYear'] ?? 25,
        ratingYear: data['ratingYear'] ?? "4.9",
        isAccepted: placeData['isAccepted'] ?? true, // Thêm trường isAccepted
      );

      groupedByDay.putIfAbsent(dayIndex, () => []);
      groupedByDay[dayIndex]!.add(place);
    }

    // Sort theo dayIndex rồi extract value
    List<MapEntry<int, List<Place>>> sortedEntries = groupedByDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    List<List<Place>> addedPlaces = sortedEntries.map((e) => e.value).toList();

    return SavedTourClass(
      id: doc.id,
      name: data['name'] ?? '',
      timeSaved: DateTime.tryParse(data['timeSaved']) ?? DateTime.now(), // String -> DateTime
      departureDate: data['departureDate'] != null
          ? (data['departureDate'] as Timestamp).toDate()
          : DateTime.now(),
      returnDate: data['returnDate'] != null
          ? (data['returnDate'] as Timestamp).toDate()
          : DateTime.now(),
      completed: data['completed'] ?? false,
      addedPlaces: addedPlaces,

    );
  }
}



List<String> currentLocationDetail = ["Tây Ninh","Hồ Chí Minh", "Cần Thơ"];


// Địa điểm du lịch
List<Place> places = [

];

// Địa điểm ẩm thực
// Địa điểm ẩm thực
List<Place> food = [

];

// Tour đã lưu
List<SavedTourClass> savedTour = [

];