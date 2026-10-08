import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'assign_trainer_screen.dart';
import 'create_trainer_screen.dart';
import 'user_management_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              color: AppColors.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hello, ${auth.userName ?? 'Admin'} 👋',
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      const Text('Admin Dashboard',
                          style: TextStyle(color: AppColors.red, fontSize: 13)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded,
                        color: AppColors.textSecondary),
                    onPressed: () => context.read<AuthProvider>().logout(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .snapshots(),
                builder: (_, snap) {
                  final users  = snap.data?.docs ?? [];
                  final members  = users.where((u) =>
                  (u.data() as Map)['role'] == 'member').length;
                  final trainers = users.where((u) =>
                  (u.data() as Map)['role'] == 'trainer').length;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Row(children: [
                          _StatCard(label: 'Total\nMembers',
                              value: '$members', color: AppColors.lime),
                          const SizedBox(width: 12),
                          _StatCard(label: 'Total\nTrainers',
                              value: '$trainers', color: AppColors.cyan),
                          const SizedBox(width: 12),
                          _StatCard(label: 'Total\nUsers',
                              value: '${users.length}', color: AppColors.amber),
                        ]),
                        const SizedBox(height: 28),
                        const Text('QUICK ACTIONS',
                            style: TextStyle(color: AppColors.textSecondary,
                                fontSize: 11, fontWeight: FontWeight.w700,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 10),
                        _ActionTile(
                          icon: Icons.person_add_rounded,
                          label: 'Create Trainer Account',
                          sub: 'Add a new trainer to the system',
                          color: AppColors.cyan,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const CreateTrainerScreen())),
                        ),
                        const SizedBox(height: 10),
                        _ActionTile(
                          icon: Icons.link_rounded,
                          label: 'Assign Trainer to Member',
                          sub: 'Allocate a trainer manually',
                          color: AppColors.lime,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const AssignTrainerScreen())),
                        ),
                        const SizedBox(height: 10),
                        _ActionTile(
                          icon: Icons.manage_accounts_rounded,
                          label: 'Manage Users',
                          sub: 'View and manage all accounts',
                          color: AppColors.amber,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const UserManagementScreen())),
                        ),
                        const SizedBox(height: 28),
                        const Text('RECENT USERS',
                            style: TextStyle(color: AppColors.textSecondary,
                                fontSize: 11, fontWeight: FontWeight.w700,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 10),
                        ...users.take(5).map((u) {
                          final data = u.data() as Map<String, dynamic>;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.border, width: 0.5),
                            ),
                            child: Row(children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: _roleColor(data['role'])
                                    .withOpacity(0.15),
                                child: Text(
                                  (data['name'] as String? ?? 'U')
                                      .substring(0, 1).toUpperCase(),
                                  style: TextStyle(
                                      color: _roleColor(data['role']),
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['name'] ?? 'Unknown',
                                      style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  Text(data['email'] ?? '',
                                      style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11)),
                                ],
                              )),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _roleColor(data['role'])
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  (data['role'] ?? 'member').toUpperCase(),
                                  style: TextStyle(
                                      color: _roleColor(data['role']),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5),
                                ),
                              ),
                            ]),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String? role) => switch (role) {
    'admin'   => AppColors.red,
    'trainer' => AppColors.cyan,
    _         => AppColors.lime,
  };
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3), width: 0.5),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(
              color: color, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
        ]),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   sub;
  final Color    color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label,
    required this.sub, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 3),
              Text(sub, style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
            ],
          )),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textSecondary, size: 20),
        ]),
      ),
    );
  }
}