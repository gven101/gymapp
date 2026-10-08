import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'appointments_screen.dart';
import 'member_list_screen.dart';
import 'member_list_screen.dart';
import 'create_plan_screen.dart';

class TrainerHomeScreen extends StatelessWidget {
  const TrainerHomeScreen({super.key});

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
                      Text('Hello, ${auth.userName ?? 'Trainer'} 👋',
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      const Text('Trainer Dashboard',
                          style: TextStyle(
                              color: AppColors.cyan, fontSize: 13)),
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
                    .collection('trainerAssignments')
                    .where('trainerId', isEqualTo: auth.userId)
                    .where('isActive', isEqualTo: true)
                    .snapshots(),
                builder: (_, snap) {
                  final count = snap.data?.docs.length ?? 0;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Row(children: [
                          _StatCard(label: 'My\nMembers',
                              value: '$count', color: AppColors.cyan),
                          const SizedBox(width: 12),
                          _StatCard(label: 'Pending\nBookings',
                              value: '0', color: AppColors.amber),
                          const SizedBox(width: 12),
                          _StatCard(label: 'Plans\nCreated',
                              value: '0', color: AppColors.lime),
                        ]),
                        const SizedBox(height: 28),
                        const Text('QUICK ACTIONS',
                            style: TextStyle(color: AppColors.textSecondary,
                                fontSize: 11, fontWeight: FontWeight.w700,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 10),
                        _ActionTile(
                          icon: Icons.people_rounded,
                          label: 'View My Members',
                          sub: '$count members assigned',
                          color: AppColors.cyan,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const MemberListScreen())),
                        ),
                        const SizedBox(height: 10),
                        _ActionTile(
                          icon: Icons.add_circle_rounded,
                          label: 'Create Workout Plan',
                          sub: 'Build a plan for a member',
                          color: AppColors.lime,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const CreatePlanScreen())),
                        ),
                        const SizedBox(height: 10),
                        _ActionTile(
                          icon: Icons.calendar_today_rounded,
                          label: 'Manage Appointments',
                          sub: 'Approve or reject bookings',
                          color: AppColors.amber,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) => const TrainerAppointmentsScreen())),
                        ),
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