import 'package:flutter/material.dart';
import '../../pages/user_profile_page.dart';
import '../../services/app_cache_manager.dart';
import '../../utils/url_helper.dart';

/// 嵌套帖子左侧头像（可点击跳转用户主页）
class NestedPostAvatar extends StatelessWidget {
  final String avatarTemplate;
  final String username;
  final int? userId;
  static const double size = 24.0;

  static String resolveUrl(String avatarTemplate) {
    return UrlHelper.resolveUrlWithCdn(
      avatarTemplate.replaceAll('{size}', '48'),
    );
  }

  const NestedPostAvatar({
    super.key,
    required this.avatarTemplate,
    required this.username,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfilePage(username: username, uid: userId),
        ),
      ),
      child: CircleAvatar(
        radius: size / 2,
        backgroundImage: appImageProvider(
          UrlHelper.resolveUrlWithCdn(
            avatarTemplate.replaceAll('{size}', '48'),
          ),
        ),
        onBackgroundImageError: (_, _) {},
      ),
    );
  }
}
