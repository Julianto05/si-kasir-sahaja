import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/user_model.dart';
import '../../../providers/user_provider.dart';
import '../widgets/admin_drawer.dart';
import 'user_form_dialog.dart';

/// Screen for managing system user accounts and cashier permissions.
class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Kelola Pengguna'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Tambah Kasir',
            onPressed: () => UserFormDialog.show(context),
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: 'users'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => UserFormDialog.show(context),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Tambah Kasir'),
        backgroundColor: AppTheme.primary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search & Stats Bar
            Container(
              color: AppTheme.surfaceContainerLowest,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    onChanged: (val) => userProvider.setSearchQuery(val),
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau email kasir...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: userProvider.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () =>
                                  userProvider.setSearchQuery(''),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Text(
                        'Total Pengguna (${userProvider.allUsers.length})',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryContainer,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull),
                        ),
                        child: Text(
                          '${userProvider.cashiers.length} Kasir Terdaftar',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Users List
            Expanded(
              child: Consumer<UserProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    );
                  }

                  final users = provider.filteredUsers;

                  if (users.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_outline_rounded,
                              size: 48, color: AppTheme.outline),
                          const SizedBox(height: 12),
                          Text(
                            'Tidak ada pengguna ditemukan',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    );
                  }

                  final width = MediaQuery.of(context).size.width;
                  if (width >= 700) {
                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 380,
                        childAspectRatio: 2.4,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return _UserCard(user: user);
                      },
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: users.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return _UserCard(user: user);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;

  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final isAdmin = user.isAdmin;
    final dateStr = DateFormat('dd/MM/yyyy').format(user.createdAt);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: user.isActive
              ? AppTheme.outlineVariant.withValues(alpha: 0.4)
              : AppTheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: isAdmin
                ? AppTheme.primaryContainer
                : AppTheme.secondaryContainer,
            child: Text(
              (user.name.isNotEmpty ? user.name[0] : 'U').toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isAdmin
                    ? Colors.white
                    : AppTheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isAdmin
                            ? AppTheme.primary
                            : AppTheme.secondary,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        isAdmin ? 'ADMIN' : 'KASIR',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.outline,
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: user.isActive
                            ? AppTheme.secondaryContainer
                            : AppTheme.errorContainer,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        user.isActive ? 'Aktif' : 'Nonaktif',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: user.isActive
                              ? AppTheme.onSecondaryContainer
                              : AppTheme.onErrorContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Dibuat: $dateStr',
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.outline),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Toggle Active Switch (Only for Cashier, cannot disable admin)
          if (!isAdmin)
            IconButton(
              icon: Icon(
                user.isActive
                    ? Icons.toggle_on_rounded
                    : Icons.toggle_off_rounded,
                color: user.isActive ? AppTheme.secondary : AppTheme.outline,
                size: 32,
              ),
              tooltip: user.isActive
                  ? 'Nonaktifkan Akun'
                  : 'Aktifkan Akun',
              onPressed: () {
                context.read<UserProvider>().toggleUserStatus(user);
              },
            ),
        ],
      ),
    );
  }
}
