import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key});
  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final _db = FirebaseFirestore.instance;

  Map<String, dynamic>? _trainer;
  DateTime?  _selectedDate;
  TimeOfDay? _selectedTime;
  final _notesCtrl = TextEditingController();
  bool _loading  = true;
  bool _saving   = false;
  String? _message;

  // My appointments
  List<Map<String, dynamic>> _appointments = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final uid = context.read<AuthProvider>().userId;

    // Get assigned trainer
    final assignSnap = await _db
        .collection('trainerAssignments')
        .where('memberId',  isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    Map<String, dynamic>? trainer;
    if (assignSnap.docs.isNotEmpty) {
      trainer = assignSnap.docs.first.data();
    }

    // Get my appointments
    final apptSnap = await _db
        .collection('appointments')
        .where('memberId', isEqualTo: uid)
        .get();

    final appointments = apptSnap.docs.map((d) => d.data()).toList();
    appointments.sort((a, b) =>
        (b['sessionDatetime'] as Timestamp)
            .compareTo(a['sessionDatetime'] as Timestamp));

    setState(() {
      _trainer      = trainer;
      _appointments = appointments;
      _loading      = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:      context,
      initialDate:  DateTime.now().add(const Duration(days: 1)),
      firstDate:    DateTime.now(),
      lastDate:     DateTime.now().add(const Duration(days: 60)),
      builder: (_, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary:   AppColors.lime,
            surface:   AppColors.card,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context:     context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (_, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary:   AppColors.lime,
            surface:   AppColors.card,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _book() async {
    if (_trainer == null) {
      setState(() => _message = 'No trainer assigned. Contact admin.');
      return;
    }
    if (_selectedDate == null) {
      setState(() => _message = 'Please select a date.');
      return;
    }
    if (_selectedTime == null) {
      setState(() => _message = 'Please select a time.');
      return;
    }

    setState(() { _saving = true; _message = null; });

    final auth = context.read<AuthProvider>();
    final sessionDt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    await _db.collection('appointments').add({
      'memberId':        auth.userId,
      'memberName':      auth.userName,
      'trainerId':       _trainer!['trainerId'],
      'trainerName':     _trainer!['trainerName'],
      'sessionDatetime': Timestamp.fromDate(sessionDt),
      'durationMins':    60,
      'status':          'pending',
      'memberNotes':     _notesCtrl.text.trim().isEmpty
          ? null : _notesCtrl.text.trim(),
      'requestedAt':     FieldValue.serverTimestamp(),
    });

    setState(() {
      _saving      = false;
      _message     = '✓ Session booked for ${DateFormat('EEE d MMM').format(sessionDt)} at ${_selectedTime!.format(context)}!';
      _selectedDate = null;
      _selectedTime = null;
      _notesCtrl.clear();
    });

    // Reload appointments
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Book a Session',
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

            // ── Trainer card ──────────────────────────────
            const Text('YOUR TRAINER',
                style: TextStyle(color: AppColors.textSecondary,
                    fontSize: 11, fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _trainer != null
                        ? AppColors.cyan.withOpacity(0.3)
                        : AppColors.border,
                    width: 0.5),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.cyan.withOpacity(0.15),
                  child: Text(
                    _trainer != null
                        ? (_trainer!['trainerName'] as String)
                        .substring(0, 1).toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: AppColors.cyan,
                        fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _trainer != null
                            ? _trainer!['trainerName']
                            : 'No trainer assigned',
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(
                        _trainer != null
                            ? 'Tap below to book a session'
                            : 'Contact admin to get assigned',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ]),
            ),
            const SizedBox(height: 28),

            // ── Date & Time pickers ───────────────────────
            const Text('SELECT DATE & TIME',
                style: TextStyle(color: AppColors.textSecondary,
                    fontSize: 11, fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _selectedDate != null
                              ? AppColors.lime : AppColors.border,
                          width: _selectedDate != null ? 1.5 : 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            color: _selectedDate != null
                                ? AppColors.lime : AppColors.textSecondary,
                            size: 20),
                        const SizedBox(height: 8),
                        Text(
                            _selectedDate != null
                                ? DateFormat('EEE, d MMM').format(_selectedDate!)
                                : 'Pick date',
                            style: TextStyle(
                                color: _selectedDate != null
                                    ? AppColors.lime : AppColors.textSecondary,
                                fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _pickTime,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _selectedTime != null
                              ? AppColors.lime : AppColors.border,
                          width: _selectedTime != null ? 1.5 : 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.access_time_rounded,
                            color: _selectedTime != null
                                ? AppColors.lime : AppColors.textSecondary,
                            size: 20),
                        const SizedBox(height: 8),
                        Text(
                            _selectedTime != null
                                ? _selectedTime!.format(context)
                                : 'Pick time',
                            style: TextStyle(
                                color: _selectedTime != null
                                    ? AppColors.lime : AppColors.textSecondary,
                                fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Notes for trainer (optional)…',
                prefixIcon: Icon(Icons.edit_note_rounded,
                    color: AppColors.textSecondary, size: 18),
              ),
            ),
            const SizedBox(height: 24),

            // Message
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

            // Book button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _book,
                child: _saving
                    ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.bg))
                    : const Text('BOOK SESSION'),
              ),
            ),
            const SizedBox(height: 32),

            // ── My appointments ───────────────────────────
            const Text('MY BOOKINGS',
                style: TextStyle(color: AppColors.textSecondary,
                    fontSize: 11, fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 10),

            if (_appointments.isEmpty)
              const Text('No bookings yet.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13))
            else
              ..._appointments.map((a) {
                final dt = (a['sessionDatetime'] as Timestamp).toDate();
                final status = a['status'] as String;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _statusColor(status).withOpacity(0.3),
                        width: 0.5),
                  ),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.calendar_month_rounded,
                          color: _statusColor(status), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            DateFormat('EEE, d MMM yyyy · h:mm a').format(dt),
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 3),
                        Text('with ${a['trainerName']}',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    )),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(status.toUpperCase(),
                          style: TextStyle(
                              color: _statusColor(status),
                              fontSize: 9, fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                    ),
                  ]),
                );
              }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) => switch (status) {
    'approved'  => AppColors.green,
    'rejected'  => AppColors.red,
    'cancelled' => AppColors.textSecondary,
    _           => AppColors.amber,
  };
}