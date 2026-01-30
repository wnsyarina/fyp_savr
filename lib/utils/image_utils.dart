import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ImageUtils {
  static Widget getFoodImage({
    required BuildContext context,
    String? imageUrl,
    String? imageBase64,
    double width = 80,
    double height = 80,
    BoxFit fit = BoxFit.cover,
    BorderRadiusGeometry borderRadius = BorderRadius.zero,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
        image: imageUrl != null && imageUrl.isNotEmpty
            ? DecorationImage(
          image: CachedNetworkImageProvider(imageUrl),
          fit: fit,
        )
            : imageBase64 != null && imageBase64.isNotEmpty
            ? DecorationImage(
          image: NetworkImage('data:image/jpeg;base64,$imageBase64'),
          fit: fit,
        )
            : null,
      ),
      child: (imageUrl == null || imageUrl.isEmpty) &&
          (imageBase64 == null || imageBase64.isEmpty)
          ? Icon(Icons.fastfood, color: Colors.grey, size: width / 2)
          : null,
    );
  }

  static ImageProvider getFoodImageProvider({
    String? imageUrl,
    String? imageBase64,
  }) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedNetworkImageProvider(imageUrl);
    } else if (imageBase64 != null && imageBase64.isNotEmpty) {
      return NetworkImage('data:image/jpeg;base64,$imageBase64');
    } else {
      return const AssetImage('assets/placeholder_food.png');
    }
  }
}