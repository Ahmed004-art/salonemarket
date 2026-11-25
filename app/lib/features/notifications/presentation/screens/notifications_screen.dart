import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/notifications_notifier.dart';
import '../../data/models/notification_model.dart';

/// Screen listing customer notifications with read/unread indicators and mark-all-read.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationsNotifier>().loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<NotificationsNotifier>();
    final notifications = notifier.notifications;
    final isLoading = notifier.isLoading;

    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          if (notifier.unreadCount > 0)
            TextButton(
              onPressed: () => notifier.markAllAsRead(),
              child: Text(
                'Mark all read',
                style: GoogleFonts.dmSans(
                  color: SaloneMarketTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: isLoading && notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => notifier.loadNotifications(),
              color: SaloneMarketTheme.primary,
              child: notifications.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return _buildNotificationTile(
                          context,
                          notification,
                          notifier,
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    AppNotification notification,
    NotificationsNotifier notifier,
  ) {
    return Card(
      elevation: 0,
      color: notification.isRead
          ? SaloneMarketTheme.surface
          : Colors.blue.shade50.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: notification.isRead
              ? SaloneMarketTheme.border
              : Colors.blue.shade200,
        ),
      ),
      child: ListTile(
        onTap: () {
          if (!notification.isRead) {
            notifier.markAsRead(notification.id);
          }
        },
        leading: _buildIcon(notification.type),
        title: Text(
          notification.title,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification.body != null) ...[
              const SizedBox(height: 4),
              Text(
                notification.body!,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: SaloneMarketTheme.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              notification.timeAgo,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: SaloneMarketTheme.textSecondary,
              ),
            ),
          ],
        ),
        trailing: !notification.isRead
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: SaloneMarketTheme.primary,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildIcon(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'order_placed':
      case 'order_confirmed':
      case 'order_shipped':
      case 'order_delivered':
        icon = Icons.local_shipping_outlined;
        color = SaloneMarketTheme.primary;
        break;
      case 'payment_received':
        icon = Icons.check_circle_outline;
        color = Colors.green;
        break;
      case 'payment_failed':
        icon = Icons.error_outline;
        color = SaloneMarketTheme.error;
        break;
      case 'vendor_approved':
        icon = Icons.storefront_outlined;
        color = SaloneMarketTheme.accent;
        break;
      default:
        icon = Icons.notifications_none;
        color = SaloneMarketTheme.textSecondary;
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withOpacity(0.12),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.notifications_off_outlined,
              size: 56,
              color: SaloneMarketTheme.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No notifications yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Updates about your orders and account will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: SaloneMarketTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
