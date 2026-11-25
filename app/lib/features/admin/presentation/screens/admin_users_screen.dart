import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/admin_notifier.dart';
import '../widgets/admin_error_state.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AdminNotifier>().loadUsers();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AdminNotifier>();
    final users = notifier.users;
    final isLoading = notifier.isUsersLoading && users.isEmpty;
    final error = notifier.usersError;

    Widget content;
    if (isLoading) {
      content = const Center(
        child: CircularProgressIndicator(color: SaloneMarketTheme.primary),
      );
    } else if (error != null && users.isEmpty) {
      content = AdminErrorState(
        title: 'Could not load users',
        error: error,
        onRetry: () => notifier.loadUsers(),
      );
    } else if (users.isEmpty) {
      content = const Center(child: Text('No registered users found'));
    } else {
      final listView = ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) => _buildUserTile(users[index]),
      );
      content = kIsWeb
          ? listView
          : RefreshIndicator(
              onRefresh: () => notifier.loadUsers(),
              child: listView,
            );
    }

    return Scaffold(
      backgroundColor: SaloneMarketTheme.background,
      appBar: AppBar(
        title: const Text('User Accounts'),
        backgroundColor: SaloneMarketTheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.loadUsers(),
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildUserTile(Map<String, dynamic> u) {
    final fullName = (u['full_name']?.toString().trim().isNotEmpty == true)
        ? u['full_name'].toString()
        : 'Unnamed User';
    final phone = u['phone']?.toString() ?? 'No phone';
    final role = (u['role']?.toString() ?? 'customer').toLowerCase();
    final created = DateTime.tryParse(u['created_at']?.toString() ?? '');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: SaloneMarketTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: SaloneMarketTheme.primary.withValues(alpha: 0.12),
            child: const Icon(Icons.person_outline,
                color: SaloneMarketTheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  'Phone: $phone${created != null ? ' • Joined ${_dateFormat.format(created)}' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          _buildRoleBadge(role),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade800;
    if (role == 'admin') {
      bg = Colors.purple.shade50;
      fg = Colors.purple.shade800;
    } else if (role == 'vendor') {
      bg = Colors.blue.shade50;
      fg = Colors.blue.shade800;
    } else {
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
