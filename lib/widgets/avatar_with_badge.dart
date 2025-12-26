import 'package:flutter/material.dart';

class AvatarWithBadge extends StatelessWidget {
  final String? avatarUrl;
  final String? badgeUrl;
  final double size;
  final double badgeSize;

  const AvatarWithBadge({
    super.key,
    this.avatarUrl,
    this.badgeUrl,
    this.size = 80,
    this.badgeSize = 26,
  });

  bool get _hasAvatar =>
      avatarUrl != null && avatarUrl!.trim().isNotEmpty;

  bool get _hasBadge =>
      badgeUrl != null && badgeUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        /// AVATAR
        ClipOval(
          child: _hasAvatar
              ? Image.network(
                  avatarUrl!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.person, size: size),
                )
              : Icon(Icons.person, size: size),
        ),

        /// BADGE
        if (_hasBadge)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.amber,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: Image.network(
                  badgeUrl!,
                  width: badgeSize,
                  height: badgeSize,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.emoji_events,
                    size: badgeSize,
                    color: Colors.amber,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
