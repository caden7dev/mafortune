import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String initial;
  final double size;

  const UserAvatar({
    super.key,
    this.photoUrl,
    required this.initial,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipOval(
        child: hasPhoto
            ? CachedNetworkImage(
                imageUrl: photoUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                // ✅ Apparition immédiate, pas de fondu tardif
                fadeInDuration: Duration.zero,
fadeOutDuration: Duration.zero,
placeholder: (_, __) => const SizedBox.shrink(),
errorWidget: (_, __, ___) => _initial(),
              )
            : _initial(),
      ),
    );
  }

  Widget _initial() {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.4,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}