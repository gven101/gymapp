import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

class WorkoutLogScreen extends StatefulWidget {
  const WorkoutLogScreen({super.key});
  @override
  State<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends State<WorkoutLogScreen> {
  final _db = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _exercises = [];
  Map<String, dynamic>?      _selected;

  final _setsCtrl      = TextEditingController(text: '3');
  final _repsCtrl      = TextEditingController(text: '10');
  final _weightCtrl    = TextEditingController(text: '0');
  final _durationCtrl  = TextEditingController(text: '20');
  final _distanceCtrl  = TextEditingController(text: '0');
  final _timedSetsCtrl = TextEditingController(text: '3');
  final _secsCtrl      = TextEditingController(text: '30');
  final _notesCtrl     = TextEditingController();
  final _formKey       = GlobalKey<FormState>();

  bool    _loading = false;
  bool    _saving  = false;
  String? _message;

  String _inputType(Map<String, dynamic>? ex) {
    if (ex == null) return 'strength';
    final cat  = (ex['category'] as String? ?? '').toLowerCase();
    final name = (ex['name']     as String? ?? '').toLowerCase();
    if (cat == 'cardio')                                   return 'cardio';
    if (name.contains('plank') || name.contains('hold'))   return 'timed';
    return 'strength';
  }

  double _estimateCalories({
    required Map<String, dynamic> exercise,
    required String inputType,
    int sets = 0, int reps = 0,
    double durationMins = 0,
    int durationSecs = 0,
  }) {
    final met        = (exercise['metValue'] as num?)?.toDouble() ?? 3.5;
    const bodyWeight = 70.0;
    double durationHr;

    if (inputType == 'cardio') {
      durationHr = durationMins / 60;
    } else if (inputType == 'timed') {
      durationHr = (sets * durationSecs + sets * 30) / 3600;
    } else {
      durationHr = (sets * reps * 3 + sets * 90) / 3600;
    }

    return double.parse((met * bodyWeight * durationHr).toStringAsFixed(1));
  }

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  @override
  void dispose() {
    _setsCtrl.dispose();
    _repsCtrl.dispose();
    _weightCtrl.dispose();
    _durationCtrl.dispose();
    _distanceCtrl.dispose();
    _timedSetsCtrl.dispose();
    _secsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    setState(() => _loading = true);
    final snap = await _db.collection('exercises').orderBy('muscleGroup').get();
    setState(() {
      _exercises = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      _loading   = false;
    });
  }

  Future<void> _save() async {
    if (_selected == null) {
      setState(() => _message = 'Please select an exercise first.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _message = null; });

    final auth = context.read<AuthProvider>();
    final type = _inputType(_selected);

    // Calculate calories
    double calories = 0;
    if (type == 'cardio') {
      calories = _estimateCalories(
        exercise:     _selected!,
        inputType:    type,
        durationMins: double.tryParse(_durationCtrl.text) ?? 0,
      );
    } else if (type == 'timed') {
      calories = _estimateCalories(
        exercise:     _selected!,
        inputType:    type,
        sets:         int.tryParse(_timedSetsCtrl.text) ?? 1,
        durationSecs: int.tryParse(_secsCtrl.text) ?? 30,
      );
    } else {
      calories = _estimateCalories(
        exercise:  _selected!,
        inputType: type,
        sets:      int.tryParse(_setsCtrl.text) ?? 3,
        reps:      int.tryParse(_repsCtrl.text) ?? 10,
      );
    }

    final Map<String, dynamic> logData = {
      'memberId':      auth.userId,
      'memberName':    auth.userName,
      'exerciseId':    _selected!['id'],
      'exerciseName':  _selected!['name'],
      'muscleGroup':   _selected!['muscleGroup'],
      'category':      _selected!['category'],
      'inputType':     type,
      'caloriesBurnt': calories,
      'loggedDate':    DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'createdAt':     FieldValue.serverTimestamp(),
      'notes':         _notesCtrl.text.trim().isEmpty
          ? null : _notesCtrl.text.trim(),
    };

    if (type == 'cardio') {
      logData['durationMins'] = double.tryParse(_durationCtrl.text) ?? 0;
      logData['distanceKm']   = double.tryParse(_distanceCtrl.text) ?? 0;
    } else if (type == 'timed') {
      logData['setsCompleted'] = int.tryParse(_timedSetsCtrl.text) ?? 1;
      logData['durationSecs']  = int.tryParse(_secsCtrl.text) ?? 30;
    } else {
      logData['setsCompleted'] = int.tryParse(_setsCtrl.text)     ?? 0;
      logData['repsCompleted'] = int.tryParse(_repsCtrl.text)     ?? 0;
      logData['weightKg']      = double.tryParse(_weightCtrl.text) ?? 0;
    }

    await _db.collection('workoutLogs').add(logData);

    HapticFeedback.mediumImpact();
    setState(() {
      _saving  = false;
      _message = '✓ ${_selected!['name']} logged! ~${calories} kcal burned';
      _selected = null;
      _notesCtrl.clear();
      _setsCtrl.text      = '3';
      _repsCtrl.text      = '10';
      _weightCtrl.text    = '0';
      _durationCtrl.text  = '20';
      _distanceCtrl.text  = '0';
      _timedSetsCtrl.text = '3';
      _secsCtrl.text      = '30';
    });
  }

  Color _catColor(String? cat) => switch (cat?.toLowerCase()) {
    'compound'  => AppColors.lime,
    'isolation' => AppColors.cyan,
    'cardio'    => AppColors.amber,
    'strength'  => AppColors.violet,
    _           => AppColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final type = _inputType(_selected);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily Log',
                style: TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
            Text(DateFormat('EEE, d MMM').format(DateTime.now()),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(color: AppColors.lime))
          : Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Exercise picker ──────────────────────
              const Text('SELECT EXERCISE',
                  style: TextStyle(color: AppColors.textSecondary,
                      fontSize: 11, fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
              const SizedBox(height: 10),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection:  Axis.horizontal,
                  itemCount:        _exercises.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final ex    = _exercises[i];
                    final isSel = _selected?['id'] == ex['id'];
                    final cat   = (ex['category'] as String? ?? '');
                    final color = _catColor(cat);
                    return GestureDetector(
                      onTap: () => setState(() => _selected = ex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 120,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSel
                              ? color.withOpacity(0.12) : AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSel ? color : AppColors.border,
                            width: isSel ? 1.5 : 0.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment:  MainAxisAlignment.center,
                          children: [
                            Text(
                              (ex['muscleGroup'] as String).toUpperCase(),
                              style: TextStyle(
                                  color: isSel ? color : AppColors.textHint,
                                  fontSize: 9, fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 5),
                            Text(ex['name'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: isSel
                                      ? color : AppColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(cat.toUpperCase(),
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // ── Selected exercise banner ─────────────
              if (_selected != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _catColor(_selected!['category'])
                            .withOpacity(0.3),
                        width: 0.5),
                  ),
                  child: Row(children: [
                    Icon(Icons.fitness_center_rounded,
                        color: _catColor(_selected!['category']), size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_selected!['name'],
                        style: TextStyle(
                            color: _catColor(_selected!['category']),
                            fontWeight: FontWeight.w700, fontSize: 14))),
                    Text(_selected!['muscleGroup'],
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ]),
                ),
                const SizedBox(height: 16),

                // Calorie estimate preview
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.amber.withOpacity(0.25),
                        width: 0.5),
                  ),
                  child: Row(children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: AppColors.amber, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      type == 'cardio'
                          ? 'Calories calculated from duration'
                          : type == 'timed'
                          ? 'Calories calculated from hold time'
                          : 'Calories calculated from sets × reps',
                      style: const TextStyle(
                          color: AppColors.amber, fontSize: 12),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
              ],

              // ── Dynamic input fields ─────────────────
              if (_selected != null) ...[
                Text(
                  type == 'cardio' ? 'LOG YOUR CARDIO' :
                  type == 'timed'  ? 'LOG HOLD TIME'   :
                  'LOG YOUR SETS',
                  style: const TextStyle(color: AppColors.textSecondary,
                      fontSize: 11, fontWeight: FontWeight.w700,
                      letterSpacing: 1.2),
                ),
                const SizedBox(height: 12),

                if (type == 'cardio')
                  Row(children: [
                    Expanded(child: _NumField(
                        ctrl: _durationCtrl, label: 'Duration',
                        unit: 'mins', isDecimal: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _NumField(
                        ctrl: _distanceCtrl, label: 'Distance',
                        unit: 'km', isDecimal: true)),
                  ]),

                if (type == 'timed')
                  Row(children: [
                    Expanded(child: _NumField(
                        ctrl: _timedSetsCtrl, label: 'Sets', unit: '×')),
                    const SizedBox(width: 12),
                    Expanded(child: _NumField(
                        ctrl: _secsCtrl, label: 'Hold Time', unit: 'secs')),
                  ]),

                if (type == 'strength')
                  Row(children: [
                    Expanded(child: _NumField(
                        ctrl: _setsCtrl, label: 'Sets', unit: '×')),
                    const SizedBox(width: 12),
                    Expanded(child: _NumField(
                        ctrl: _repsCtrl, label: 'Reps', unit: 'reps')),
                    const SizedBox(width: 12),
                    Expanded(child: _NumField(
                        ctrl: _weightCtrl, label: 'Weight',
                        unit: 'kg', isDecimal: true)),
                  ]),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Notes (optional)…',
                    prefixIcon: Icon(Icons.edit_note_rounded,
                        color: AppColors.textSecondary, size: 18),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Message ──────────────────────────────
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
                  child: Row(children: [
                    Icon(
                      _message!.startsWith('✓')
                          ? Icons.local_fire_department_rounded
                          : Icons.error_outline_rounded,
                      color: _message!.startsWith('✓')
                          ? AppColors.green : AppColors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_message!,
                        style: TextStyle(
                            color: _message!.startsWith('✓')
                                ? AppColors.green : AppColors.red,
                            fontWeight: FontWeight.w600))),
                  ]),
                ),

              // ── Save button ──────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: AppColors.bg))
                      : const Text('LOG WORKOUT'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String unit;
  final bool   isDecimal;
  const _NumField({required this.ctrl, required this.label,
    required this.unit, this.isDecimal = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        TextFormField(
          controller:   ctrl,
          textAlign:    TextAlign.center,
          keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                isDecimal ? RegExp(r'^\d+\.?\d{0,2}') : RegExp(r'\d+')),
          ],
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800, fontSize: 20),
          decoration: InputDecoration(
            hintText:    '0',
            suffixText:  unit,
            suffixStyle: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11),
            contentPadding: const EdgeInsets.symmetric(
                vertical: 14, horizontal: 8),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            if (isDecimal && double.tryParse(v) == null) return 'Invalid';
            if (!isDecimal && int.tryParse(v) == null)   return 'Invalid';
            return null;
          },
        ),
      ],
    );
  }
}