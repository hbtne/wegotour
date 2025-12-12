import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  final cloudinary = CloudinaryPublic(
    'dibmnb2rp', // Cloudinary cloud name
    '515184799815318', // API key
  );

  Future<List<String>> uploadImages(List<String> imagePaths) async {
    List<String> imageUrls = [];

    for (var path in imagePaths) {
      try {
        final response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            path,
            resourceType: CloudinaryResourceType.Image,
            folder: "posts",
            context: {
              "api_secret": "AXObUwGmqzWn89Ixb_z4QGU4jKo"
            },

          ),
          uploadPreset: 'Default',
        );
        imageUrls.add(response.secureUrl);
      } catch (e) {
        print('Error uploading image to Cloudinary: $e');
      }
    }

    return imageUrls;
  }
}