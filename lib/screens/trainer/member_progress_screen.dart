import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';

class MemberProgressScreen extends StatefulWidget {
  final String memberId;
  final String memberName;
  const MemberProgressScreen({
    super.key,
    required this.memberId,
    required this.memberName,
  });
  @override
  State<MemberProgressScreen> createState() => _MemberProgressScreenState();
}

class _MemberProgressScreenState extends State<MemberProgressScreen> {
  final _db = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _logs          = [];
  List<String>               _exerciseNames = [];
  String?                    _selectedEx;
  bool                       _loading       = true;

  List<FlSpot> _spots         = [];
  List<String> _dates         = [];
  double       _bestKg        = 0;
  int          _sessions      = 0;
  double       _totalCalories = 0;
  double       _exCalories    = 0;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final snap = await _db
        .collection('workoutLogs')
        .where('memberId', isEqualTo: widget.memberId)
        .get();

    final logs = snap.docs.map((d) => d.data()).toList();
    logs.sort((a, b) =>
        (b['loggedDate'] as String).compareTo(a['loggedDate'] as String));

    final names = <String>{};
    for (final l in logs) {
      if (l['exerciseName'] != null) names.add(l['exerciseName']);
    }

    double totalCal = 0;
    for (final l in logs) {
      totalCal += (l['caloriesBurnt'] as num?)?.toDouble() ?? 0;
    }

    setState(() {
      _logs          = logs;
      _exerciseNames = names.toList();
      _totalCalories = double.parse(totalCal.toStringAsFixed(1));
      _loading       = false;
    });
  }

  void _buildChart(String exerciseName) {
    final filtered = _logs
        .where((l) =>
    l['exerciseName'] == exerciseName &&
        l['weightKg'] != null)
        .toList()
      ..sort((a, b) =>
          (a['loggedDate'] as String).compareTo(b['loggedDate'] as String));

    final grouped = <String, double>{};
    for (final l in filtered) {
      final date   = l['loggedDate'] as String;
      final weight = (l['weightKg'] as num).toDouble();
      if (!grouped.containsKey(date) || grouped[date]! < weight) {
        grouped[date] = weight;
      }
    }

    final entries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final exLogs = _logs.where((l) => l['exerciseName'] == exerciseName);
    final exCal  = exLogs.fold<double>(0, (sum, l) =>
    sum + ((l['caloriesBurnt'] as num?)?.toDouble() ?? 0));

    setState(() {
      _selectedEx  = exerciseName;
      _spots       = entries.asMap().entries
          .map((e) => FlSpot(e.key.toDouble(), e.value.value))
          .toList();
      _dates       = entries.map((e) => e.key).toList();
      _bestKg      = entries.isEmpty ? 0
          : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
      _sessions    = entries.length;
      _exCalories  = double.parse(exCal.toStringAsFixed(1));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.memberName,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800, fontSize: 16)),
            const Text('Member Progress',
                style: TextStyle(
                    color: AppColors.cyan, fontSize: 12)),
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
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Stats row ─────────────────────────────────
            Row(children: [
              _StatCard(
                  label: 'Total\nSessions',
                  value: '${_logs.length}',
                  color: AppColors.lime),
              const SizedBox(width: 12),
              _StatCard(
                  label: 'Exercises\nDone',
                  value: '${_exerciseNames.length}',
                  color: AppColors.cyan),
              const SizedBox(width: 12),
              _StatCard(
                  label: 'Calories\nBurned',
                  value: '${_totalCalories}',
                  color: AppColors.amber),
            ]),
            const SizedBox(height: 16),

            // ── Total calories banner ─────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.amber.withOpacity(0.25), width: 0.5),
              ),
              child: Row(children: [
                const Icon(Icons.local_fire_department_rounded,
                    color: AppColors.amber, size: 28),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_totalCalories} kcal burned total',
                        style: const TextStyle(
                            color: AppColors.amber,
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('across ${_logs.length} workout sessions',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ]),
            ),
            const SizedBox(height: 28),

            // ── Recent logs ───────────────────────────────
            const Text('RECENT ACTIVITY',
                style: TextStyle(color: AppColors.textSecondary,
                    fontSize: 11, fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 10),

            if (_logs.isEmpty)
              const Text('No workouts logged yet.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13))
            else
              ..._logs.take(5).map((l) {
                final cat   = l['category'] as String? ?? '';
                final color = _catColor(cat);
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
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.fitness_center_rounded,
                          color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l['exerciseName'] ?? '',
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 3),
                        Text(_logSummary(l),
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11)),
                      ],
                    )),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(l['loggedDate'] ?? '',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11)),
                        const SizedBox(height: 3),
                        if (l['caloriesBurnt'] != null)
                          Row(children: [
                            const Icon(
                                Icons.local_fire_department_rounded,
                                color: AppColors.amber, size: 12),
                            const SizedBox(width: 3),
                            Text(
                                '${(l['caloriesBurnt'] as num).toStringAsFixed(1)} kcal',
                                style: const TextStyle(
                                    color: AppColors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ]),
                      ],
                    ),
                  ]),
                );
              }),
            const SizedBox(height: 28),

            // ── Progress chart selector ───────────────────
            const Text('WEIGHT PROGRESS',
                style: TextStyle(color: AppColors.textSecondary,
                    fontSize: 11, fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 10),

            if (_exerciseNames.isEmpty)
              const Text('No exercises logged yet.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13))
            else
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _exerciseNames.map((name) {
                  final isSel = _selectedEx == name;
                  return GestureDetector(
                    onTap: () => _buildChart(name),
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
                      child: Text(name,
                          style: TextStyle(
                              color: isSel
                                  ? AppColors.lime : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),

            // ── Chart ─────────────────────────────────────
            if (_selectedEx != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.border, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(_selectedEx!,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                        ),
                        Text('$_sessions sessions',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Weight over time (kg)',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 20),

                    if (_spots.isEmpty)
                      const Text(
                          'No weight data for this exercise.',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13))
                    else
                      SizedBox(
                        height: 200,
                        child: LineChart(LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) => FlLine(
                                color: AppColors.border, strokeWidth: 0.5),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles:   true,
                                reservedSize: 44,
                                getTitlesWidget: (v, _) => Text(
                                    '${v.toInt()}kg',
                                    style: const TextStyle(
                                        color:    AppColors.textSecondary,
                                        fontSize: 10)),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles:   true,
                                reservedSize: 28,
                                interval: (_spots.length / 4)
                                    .ceilToDouble().clamp(1, 99),
                                getTitlesWidget: (v, _) {
                                  final idx = v.toInt();
                                  if (idx < 0 || idx >= _dates.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final dt = DateTime.tryParse(_dates[idx]);
                                  return Text(
                                      dt != null
                                          ? DateFormat('dd/MM').format(dt)
                                          : _dates[idx],
                                      style: const TextStyle(
                                          color:    AppColors.textSecondary,
                                          fontSize: 10));
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots:            _spots,
                              isCurved:         true,
                              color:            AppColors.cyan,
                              barWidth:         2.5,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (_, __, ___, ____) =>
                                    FlDotCirclePainter(
                                      radius:      4,
                                      color:       AppColors.cyan,
                                      strokeColor: AppColors.bg,
                                      strokeWidth: 2,
                                    ),
                              ),
                              belowBarData: BarAreaData(
                                show:  true,
                                color: AppColors.cyan.withOpacity(0.1),
                              ),
                            ),
                          ],
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (_) => AppColors.surface,
                              getTooltipItems: (spots) => spots.map((s) {
                                final idx = s.x.toInt();
                                final date = idx < _dates.length
                                    ? _dates[idx] : '';
                                final dt = DateTime.tryParse(date);
                                return LineTooltipItem(
                                    '${dt != null ? DateFormat('dd MMM').format(dt) : date}\n${s.y}kg',
                                    const TextStyle(
                                        color:      AppColors.cyan,
                                        fontWeight: FontWeight.w700,
                                        fontSize:   12));
                              }).toList(),
                            ),
                          ),
                        )),
                      ),

                    if (_bestKg > 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.lime.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.lime.withOpacity(0.2),
                              width: 0.5),
                        ),
                        child: Row(children: [
                          const Icon(Icons.emoji_events_rounded,
                              color: AppColors.lime, size: 18),
                          const SizedBox(width: 8),
                          Text('${_bestKg}kg personal best',
                              style: const TextStyle(
                                  color: AppColors.lime,
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.amber.withOpacity(0.2),
                            width: 0.5),
                      ),
                      child: Row(children: [
                        const Icon(Icons.local_fire_department_rounded,
                            color: AppColors.amber, size: 18),
                        const SizedBox(width: 8),
                        Text('$_exCalories kcal from $_selectedEx',
                            style: const TextStyle(
                                color: AppColors.amber,
                                fontWeight: FontWeight.w700, fontSize: 14)),
                      ]),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _logSummary(Map<String, dynamic> l) {
    final type = l['inputType'] as String? ?? 'strength';
    if (type == 'cardio') {
      return '${l['durationMins']} mins · ${l['distanceKm']} km';
    } else if (type == 'timed') {
      return '${l['setsCompleted']} sets · ${l['durationSecs']} secs hold';
    }
    return '${l['setsCompleted']} sets × ${l['repsCompleted']} reps · ${l['weightKg']}kg';
  }

  Color _catColor(String? cat) => switch (cat?.toLowerCase()) {
    'compound'  => AppColors.lime,
    'isolation' => AppColors.cyan,
    'cardio'    => AppColors.amber,
    'strength'  => AppColors.violet,
    _           => AppColors.textSecondary,
  };
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
              color: color, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
        ]),
      ),
    );
  }
}