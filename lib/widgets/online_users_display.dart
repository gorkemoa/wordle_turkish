import 'package:flutter/material.dart';
import '../services/presence_service.dart';

/// 👥 Online kullanıcı sayısını gösteren minimal widget
/// 
/// Ana sayfada kullanım için optimize edilmiş
class OnlineUsersDisplay extends StatelessWidget {
  final Color? textColor;
  final Color? iconColor;
  final double? fontSize;
  final bool showIcon;

  const OnlineUsersDisplay({
    Key? key,
    this.textColor,
    this.iconColor,
    this.fontSize,
    this.showIcon = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: PresenceService.getOnlineUsersCountStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIcon) 
                Icon(
                  Icons.error_outline,
                  color: iconColor ?? Colors.red,
                  size: fontSize ?? 16,
                ),
              if (showIcon) const SizedBox(width: 4),
              Text(
                'Hata',
                style: TextStyle(
                  color: textColor ?? Colors.red,
                  fontSize: fontSize,
                ),
              ),
            ],
          );
        }

        final count = snapshot.data ?? 0;
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) 
              Icon(
                Icons.people,
                color: iconColor ?? Colors.green,
                size: fontSize ?? 16,
              ),
            if (showIcon) const SizedBox(width: 4),
            Text(
              count.toString(),
              style: TextStyle(
                color: textColor,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
  }
} 