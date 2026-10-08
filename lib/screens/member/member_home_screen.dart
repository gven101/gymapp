import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'workout_log_screen.dart';
import 'progress_screen.dart';
import 'book_appointment_screen.dart';
import 'my_plan_screen.dart';

String _formatDate(dynamic timestamp) {
  if (timestamp == null) return '';
  try {
    final dt = (timestamp as Timestamp).toDate();
    return '${dt.day}/${dt.month}/${dt.year}';
  } catch (_) {
    return '';
  }
}

class MemberHomeScreen extends StatelessWidget {
  const MemberHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              color: AppColors.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hello, ${auth.userName ?? 'Member'} 👋',
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      const Text('Member Dashboard',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
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
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Quick stats row
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('workoutLogs')
                          .where('memberId', isEqualTo: auth.userId)
                          .snapshots(),
                      builder: (_, logsSnap) {
                        final logCount = logsSnap.data?.docs.length ?? 0;
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('appointments')
                              .where('memberId', isEqualTo: auth.userId)
                              .snapshots(),
                          builder: (_, apptSnap) {
                            final apptCount = apptSnap.data?.docs.length ?? 0;

                            // Days active = unique logged dates
                            final dates = <String>{};
                            for (final doc in logsSnap.data?.docs ?? []) {
                              final d = doc.data() as Map<String, dynamic>;
                              if (d['loggedDate'] != null) {
                                dates.add(d['loggedDate']);
                              }
                            }

                            return Row(children: [
                              _StatCard(
                                  label: 'Workouts\nLogged',
                                  value: '$logCount',
                                  color: AppColors.lime),
                              const SizedBox(width: 12),
                              _StatCard(
                                  label: 'Sessions\nBooked',
                                  value: '$apptCount',
                                  color: AppColors.cyan),
                              const SizedBox(width: 12),
                              _StatCard(
                                  label: 'Days\nActive',
                                  value: '${dates.length}',
                                  color: AppColors.amber),
                            ]);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 28),

                    // My Trainer card
                    const Text('MY TRAINER',
                        style: TextStyle(color: AppColors.textSecondary,
                            fontSize: 11, fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 10),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('trainerAssignments')
                          .where('memberId',  isEqualTo: auth.userId)
                          .where('isActive', isEqualTo: true)
                          .limit(1)
                          .snapshots(),
                      builder: (_, snap) {
                        final hasTrainer =
                            snap.hasData && snap.data!.docs.isNotEmpty;
                        final data = hasTrainer
                            ? snap.data!.docs.first.data()
                        as Map<String, dynamic>
                            : null;
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: hasTrainer
                                    ? AppColors.cyan.withOpacity(0.4)
                                    : AppColors.border,
                                width: hasTrainer ? 1.0 : 0.5),
                          ),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: hasTrainer
                                  ? AppColors.cyan.withOpacity(0.15)
                                  : AppColors.textHint.withOpacity(0.1),
                              child: Icon(Icons.person_rounded,
                                  color: hasTrainer
                                      ? AppColors.cyan : AppColors.textHint,
                                  size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    hasTrainer
                                        ? data!['trainerName'] ?? 'Your Trainer'
                                        : 'No trainer assigned yet',
                                    style: TextStyle(
                                        color: hasTrainer
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                                const SizedBox(height: 3),
                                Text(
                                    hasTrainer
                                        ? 'Assigned on ${_formatDate(data!['assignedAt'])}'
                                        : 'Contact admin to get assigned',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12)),
                              ],
                            )),
                            if (hasTrainer)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.cyan.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('ASSIGNED',
                                    style: TextStyle(
                                        color: AppColors.cyan,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5)),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('UNASSIGNED',
                                    style: TextStyle(
                                        color: AppColors.red,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5)),
                              ),
                          ]),
                        );
                      },
                    ),
                    const SizedBox(height: 28),

                    // Quick actions
                    const Text('QUICK ACTIONS',
                        style: TextStyle(color: AppColors.textSecondary,
                            fontSize: 11, fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 10),
                    _ActionButton(
                      icon: Icons.edit_rounded,
                      label: 'Log Today\'s Workout',
                      color: AppColors.lime,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const WorkoutLogScreen())),
                    ),
                    const SizedBox(height: 10),
                    _ActionButton(
                      icon: Icons.assignment_rounded,
                      label: 'View My Workout Plan',
                      color: AppColors.lime,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const MyPlanScreen())),
                    ),
                    const SizedBox(height: 10),
                    _ActionButton(
                      icon: Icons.show_chart_rounded,
                      label: 'View My Progress',
                      color: AppColors.cyan,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const ProgressScreen())),
                    ),
                    const SizedBox(height: 10),
                    _ActionButton(
                      icon: Icons.calendar_month_rounded,
                      label: 'Book a Session',
                      color: AppColors.violet,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const BookAppointmentScreen())),
                    ),
                  ],
                ),
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
  const _StatCard({
    required this.label, required this.value, required this.color});

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

class _ActionButton extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label,
    required this.color, required this.onTap});

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
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600, fontSize: 14)),
          const Spacer(),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textSecondary, size: 20),
        ]),
      ),
    );
  }
}