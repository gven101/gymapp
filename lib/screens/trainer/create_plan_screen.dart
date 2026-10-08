import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

class CreatePlanScreen extends StatefulWidget {
  const CreatePlanScreen({super.key});
  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  final _db = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _members   = [];
  List<Map<String, dynamic>> _exercises = [];

  Map<String, dynamic>? _selectedMember;
  final _planNameCtrl = TextEditingController();
  String _selectedGoal = 'general_fitness';

  // Selected exercises with their targets
  final List<Map<String, dynamic>> _planItems = [];

  bool    _loading = true;
  bool    _saving  = false;
  String? _message;

  final _goals = [
    {'value': 'general_fitness', 'label': 'General Fitness'},
    {'value': 'strength',        'label': 'Strength'},
    {'value': 'hypertrophy',     'label': 'Hypertrophy'},
    {'value': 'fat_loss',        'label': 'Fat Loss'},
    {'value': 'endurance',       'label': 'Endurance'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _planNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final uid = context.read<AuthProvider>().userId;

    // Get assigned members
    final assignSnap = await _db
        .collection('trainerAssignments')
        .where('trainerId', isEqualTo: uid)
        .where('isActive',  isEqualTo: true)
        .get();

    final members = assignSnap.docs.map((d) => d.data()).toList();

    // Get exercises
    final exSnap = await _db
        .collection('exercises')
        .orderBy('muscleGroup')
        .get();
    final exercises = exSnap.docs
        .map((d) => {'id': d.id, ...d.data()})
        .toList();

    setState(() {
      _members   = members;
      _exercises = exercises;
      _loading   = false;
    });
  }

  void _addExercise(Map<String, dynamic> ex) {
    final index = _planItems.indexWhere((i) => i['exerciseId'] == ex['id']);

    if (index != -1) {
      // Already added — remove it (deselect)
      setState(() => _planItems.removeAt(index));
    } else {
      // Not added — add it
      setState(() {
        _planItems.add({
          'exerciseId':   ex['id'],
          'exerciseName': ex['name'],
          'muscleGroup':  ex['muscleGroup'],
          'category':     ex['category'],
          'targetSets':   3,
          'targetReps':   10,
          'targetWeight': 0.0,
          'sortOrder':    _planItems.length,
        });
      });
    }
  }

  void _removeExercise(int index) {
    setState(() => _planItems.removeAt(index));
  }

  Future<void> _savePlan() async {
    if (_selectedMember == null) {
      setState(() => _message = 'Please select a member.');
      return;
    }
    if (_planNameCtrl.text.trim().isEmpty) {
      setState(() => _message = 'Please enter a plan name.');
      return;
    }
    if (_planItems.isEmpty) {
      setState(() => _message = 'Please add at least one exercise.');
      return;
    }

    setState(() { _saving = true; _message = null; });

    final auth = context.read<AuthProvider>();

    await _db.collection('workoutPlans').add({
      'trainerId':   auth.userId,
      'trainerName': auth.userName,
      'memberId':    _selectedMember!['memberId'],
      'memberName':  _selectedMember!['memberName'],
      'planName':    _planNameCtrl.text.trim(),
      'goal':        _selectedGoal,
      'isActive':    true,
      'items':       _planItems,
      'createdAt':   FieldValue.serverTimestamp(),
    });

    setState(() {
      _saving        = false;
      _message       = '✓ Plan "${_planNameCtrl.text.trim()}" created successfully!';
      _selectedMember = null;
      _planNameCtrl.clear();
      _selectedGoal  = 'general_fitness';
      _planItems.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Create Workout Plan',
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
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Select Member ─────────────────────────────
            const Text('SELECT MEMBER',
                style: TextStyle(color: AppColors.textSecondary,
                    fontSize: 11, fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 10),
            if (_members.isEmpty)
              const Text('No members assigned to you yet.',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              ..._members.map((m) {
                final isSel =
                    _selectedMember?['memberId'] == m['memberId'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedMember = m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSel
                          ? AppColors.cyan.withOpacity(0.1)
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isSel ? AppColors.cyan : AppColors.border,
                          width: isSel ? 1.5 : 0.5),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor:
                        AppColors.cyan.withOpacity(0.15),
                        child: Text(
                            (m['memberName'] as String)
                                .substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                                color: AppColors.cyan,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(m['memberName'],
                          style: TextStyle(
                              color: isSel
                                  ? AppColors.cyan : AppColors.textPrimary,
                              fontWeight: FontWeight.w600, fontSize: 14))),
                      if (isSel)
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.cyan, size: 20),
                    ]),
                  ),
                );
              }),
            const SizedBox(height: 24),

            // ── Plan Name ─────────────────────────────────
            const Text('PLAN NAME',
                style: TextStyle(color: AppColors.textSecondary,
                    fontSize: 11, fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _planNameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'e.g. Push Day A, Full Body Week 1…',
                prefixIcon: Icon(Icons.assignment_rounded,
                    color: AppColors.textSecondary, size: 20),
              ),
            ),
            const SizedBox(height: 20),

            // ── Goal ──────────────────────────────────────
            const Text('GOAL',
                style: TextStyle(color: AppColors.textSecondary,
                    fontSize: 11, fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _goals.map((g) {
                final isSel = _selectedGoal == g['value'];
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedGoal = g['value']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel
                          ? AppColors.lime.withOpacity(0.12)
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isSel ? AppColors.lime : AppColors.border,
                          width: isSel ? 1.5 : 0.5),
                    ),
                    child: Text(g['label']!,
                        style: TextStyle(
                            color: isSel
                                ? AppColors.lime : AppColors.textSecondary,
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Exercise Picker ───────────────────────────
            const Text('ADD EXERCISES',
                style: TextStyle(color: AppColors.textSecondary,
                    fontSize: 11, fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection:  Axis.horizontal,
                itemCount:        _exercises.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final ex    = _exercises[i];
                  final added = _planItems
                      .any((p) => p['exerciseId'] == ex['id']);
                  final cat   = ex['category'] as String? ?? '';
                  final color = _catColor(cat);
                  return GestureDetector(
                    onTap: () => _addExercise(ex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 120,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: added
                            ? color.withOpacity(0.12) : AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: added ? color : AppColors.border,
                            width: added ? 1.5 : 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment:  MainAxisAlignment.center,
                        children: [
                          Text(
                              (ex['muscleGroup'] as String).toUpperCase(),
                              style: TextStyle(
                                  color: added ? color : AppColors.textHint,
                                  fontSize: 9, fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 4),
                          Text(ex['name'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: added
                                      ? color : AppColors.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3)),
                          if (added)
                            const Text('Added ✓',
                                style: TextStyle(
                                    color: AppColors.green,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // ── Plan Items ────────────────────────────────
            if (_planItems.isNotEmpty) ...[
              const Text('PLAN EXERCISES',
                  style: TextStyle(color: AppColors.textSecondary,
                      fontSize: 11, fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
              const SizedBox(height: 8),
              ..._planItems.asMap().entries.map((entry) {
                final i    = entry.key;
                final item = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.border, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(item['exerciseName'],
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_rounded,
                              color: AppColors.red, size: 20),
                          onPressed: () => _removeExercise(i),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        _TargetField(
                          label: 'Sets',
                          value: item['targetSets'],
                          onChanged: (v) => setState(() =>
                          _planItems[i]['targetSets'] = v),
                        ),
                        const SizedBox(width: 10),
                        _TargetField(
                          label: 'Reps',
                          value: item['targetReps'],
                          onChanged: (v) => setState(() =>
                          _planItems[i]['targetReps'] = v),
                        ),
                        const SizedBox(width: 10),
                        _TargetField(
                          label: 'Weight (kg)',
                          value: item['targetWeight'],
                          isDecimal: true,
                          onChanged: (v) => setState(() =>
                          _planItems[i]['targetWeight'] = v),
                        ),
                      ]),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],

            // ── Message ───────────────────────────────────
            if (_message != null)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _message!.startsWith('✓')
                      ? AppColors.green.withOpacity(0.1)
                      : AppColors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _message!.startsWith('✓')
                        ? AppColors.green.withOpacity(0.3)
                        : AppColors.red.withOpacity(0.3),
                  ),
                ),
                child: Text(_message!,
                    style: TextStyle(
                        color: _message!.startsWith('✓')
                            ? AppColors.green : AppColors.red,
                        fontWeight: FontWeight.w600)),
              ),

            // ── Save button ───────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _savePlan,
                child: _saving
                    ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.bg))
                    : Text(
                    'CREATE PLAN'
                        '${_planItems.isNotEmpty ? " (${_planItems.length} exercises)" : ""}'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
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

// ── Target Field ───────────────────────────────────────────────
class _TargetField extends StatelessWidget {
  final String   label;
  final dynamic  value;
  final bool     isDecimal;
  final Function(dynamic) onChanged;

  const _TargetField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.isDecimal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.remove_rounded,
                    color: AppColors.textSecondary, size: 16),
                onPressed: () {
                  final current = isDecimal
                      ? (value as double) : (value as int);
                  if (current > 0) {
                    onChanged(isDecimal
                        ? (current - 2.5) : (current - 1));
                  }
                },
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
              Expanded(
                child: Text(
                    isDecimal
                        ? '${(value as double).toStringAsFixed(1)}'
                        : '$value',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded,
                    color: AppColors.textSecondary, size: 16),
                onPressed: () {
                  final current = isDecimal
                      ? (value as double) : (value as int);
                  onChanged(isDecimal
                      ? (current + 2.5) : (current + 1));
                },
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}