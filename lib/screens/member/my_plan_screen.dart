import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'workout_log_screen.dart';

class MyPlanScreen extends StatefulWidget {
  const MyPlanScreen({super.key});
  @override
  State<MyPlanScreen> createState() => _MyPlanScreenState();
}

class _MyPlanScreenState extends State<MyPlanScreen> {
  final _db = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _plans   = [];
  bool                       _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final uid  = context.read<AuthProvider>().userId;
    final snap = await _db
        .collection('workoutPlans')
        .where('memberId', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .get();

    final plans = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    plans.sort((a, b) =>
        (b['createdAt'] as Timestamp).compareTo(a['createdAt'] as Timestamp));

    setState(() {
      _plans   = plans;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('My Workout Plans',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(color: AppColors.lime))
          : _plans.isEmpty
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.lime.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.assignment_outlined,
                  color: AppColors.lime, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('No plans yet',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
                'Your trainer will create a\nworkout plan for you.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary, height: 1.5)),
          ],
        ),
      )
          : ListView.builder(
        padding:     const EdgeInsets.all(16),
        itemCount:   _plans.length,
        itemBuilder: (_, i) => _PlanCard(plan: _plans[i]),
      ),
    );
  }
}

class _PlanCard extends StatefulWidget {
  final Map<String, dynamic> plan;
  const _PlanCard({required this.plan});
  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final plan  = widget.plan;
    final items = (plan['items'] as List<dynamic>? ?? [])
        .map((i) => i as Map<String, dynamic>)
        .toList();
    final goal  = plan['goal'] as String? ?? 'general_fitness';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.lime.withOpacity(0.2), width: 0.5),
      ),
      child: Column(
        children: [

          // ── Plan header ──────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.lime.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.assignment_rounded,
                      color: AppColors.lime, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan['planName'] ?? 'Workout Plan',
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text('by ${plan['trainerName'] ?? 'Trainer'}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.lime.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                            goal.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(
                                color: AppColors.lime,
                                fontSize: 8, fontWeight: FontWeight.w800,
                                letterSpacing: 0.5)),
                      ),
                    ]),
                  ],
                )),
                Column(children: [
                  Text('${items.length}',
                      style: const TextStyle(
                          color: AppColors.lime,
                          fontSize: 20, fontWeight: FontWeight.w800)),
                  const Text('exercises',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 10)),
                ]),
                const SizedBox(width: 8),
                Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary),
              ]),
            ),
          ),

          // ── Exercises list (expanded) ─────────────────────
          if (_expanded) ...[
            const Divider(color: AppColors.border, height: 0.5),
            ...items.asMap().entries.map((entry) {
              final i    = entry.key;
              final item = entry.value;
              final cat  = item['category'] as String? ?? '';
              final color = _catColor(cat);
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: i == items.length - 1
                              ? Colors.transparent : AppColors.border,
                          width: 0.5)),
                ),
                child: Row(children: [
                  // Exercise number
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('${i + 1}',
                          style: TextStyle(
                              color: color,
                              fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['exerciseName'] ?? '',
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 3),
                      Text(
                          (item['muscleGroup'] as String? ?? ''),
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  )),
                  // Target sets × reps @ weight
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                          '${item['targetSets']} × ${item['targetReps']}',
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                          (item['targetWeight'] as num? ?? 0) > 0
                              ? '${item['targetWeight']}kg'
                              : 'bodyweight',
                          style: TextStyle(
                              color: (item['targetWeight'] as num? ?? 0) > 0
                                  ? AppColors.lime : AppColors.textSecondary,
                              fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ]),
              );
            }),

            // Start workout button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const WorkoutLogScreen())),
                  icon: const Icon(Icons.play_arrow_rounded,
                      color: AppColors.bg, size: 20),
                  label: const Text('START WORKOUT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lime,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _catColor(String? cat) => switch (cat?.toLowerCase()) {
    'compound'  => AppColors.lime,
    'isolation' => AppColors.cyan,
    'cardio'    => AppColors.amber,
    'strength'  => AppColors.violet,
    _           => AppColors.textSecondary,
  };
}