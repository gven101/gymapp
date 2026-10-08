import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

class TrainerAppointmentsScreen extends StatefulWidget {
  const TrainerAppointmentsScreen({super.key});
  @override
  State<TrainerAppointmentsScreen> createState() =>
      _TrainerAppointmentsScreenState();
}

class _TrainerAppointmentsScreenState
    extends State<TrainerAppointmentsScreen> {
  final _db     = FirebaseFirestore.instance;
  String _filter = 'pending'; // pending | approved | rejected | all

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().userId;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Appointments',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [

          // ── Filter tabs ────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: AppColors.surface,
            child: Row(children: [
              _FilterChip(
                label: 'Pending',
                active: _filter == 'pending',
                color: AppColors.amber,
                onTap: () => setState(() => _filter = 'pending'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Approved',
                active: _filter == 'approved',
                color: AppColors.green,
                onTap: () => setState(() => _filter = 'approved'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Rejected',
                active: _filter == 'rejected',
                color: AppColors.red,
                onTap: () => setState(() => _filter = 'rejected'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'All',
                active: _filter == 'all',
                color: AppColors.textSecondary,
                onTap: () => setState(() => _filter = 'all'),
              ),
            ]),
          ),

          // ── Appointments list ──────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _filter == 'all'
                  ? _db.collection('appointments')
                  .where('trainerId', isEqualTo: uid)
                  .snapshots()
                  : _db.collection('appointments')
                  .where('trainerId', isEqualTo: uid)
                  .where('status',    isEqualTo: _filter)
                  .snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.lime));
                }

                final docs = snap.data?.docs ?? [];

                // Sort by sessionDatetime descending
                docs.sort((a, b) {
                  final aT = (a.data() as Map)['sessionDatetime'] as Timestamp;
                  final bT = (b.data() as Map)['sessionDatetime'] as Timestamp;
                  return bT.compareTo(aT);
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            color: AppColors.textSecondary, size: 44),
                        const SizedBox(height: 12),
                        Text(
                            'No $_filter appointments.',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 14)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding:     const EdgeInsets.all(16),
                  itemCount:   docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final id   = docs[i].id;
                    return _AppointmentCard(
                      data:     data,
                      docId:    id,
                      onUpdate: (status, notes) =>
                          _updateStatus(id, status, notes),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(
      String docId, String status, String? notes) async {
    await _db.collection('appointments').doc(docId).update({
      'status':       status,
      'trainerNotes': notes,
      'updatedAt':    FieldValue.serverTimestamp(),
    });
  }
}


// ── Appointment Card ───────────────────────────────────────────
class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String               docId;
  final Function(String status, String? notes) onUpdate;

  const _AppointmentCard({
    required this.data,
    required this.docId,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final dt     = (data['sessionDatetime'] as Timestamp).toDate();
    final status = data['status'] as String? ?? 'pending';
    final color  = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Column(
        children: [

          // Card header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.calendar_month_rounded,
                    color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['memberName'] ?? 'Member',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                      DateFormat('EEE, d MMM yyyy · h:mm a').format(dt),
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('${data['durationMins'] ?? 60} mins session',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status.toUpperCase(),
                    style: TextStyle(
                        color: color,
                        fontSize: 10, fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              ),
            ]),
          ),

          // Member notes
          if (data['memberNotes'] != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.notes_rounded,
                    color: AppColors.textSecondary, size: 14),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(data['memberNotes'],
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12))),
              ]),
            ),

          // Action buttons — only show for pending
          if (status == 'pending')
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showResponseDialog(context, 'rejected'),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.red, size: 16),
                    label: const Text('Reject',
                        style: TextStyle(color: AppColors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: AppColors.red, width: 0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showResponseDialog(context, 'approved'),
                    icon: const Icon(Icons.check_rounded,
                        color: AppColors.bg, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
            ),

          // Mark complete button — only for approved
          if (status == 'approved')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton.icon(
                onPressed: () => onUpdate('completed', null),
                icon: const Icon(Icons.done_all_rounded,
                    color: AppColors.cyan, size: 16),
                label: const Text('Mark as Completed',
                    style: TextStyle(color: AppColors.cyan)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                      color: AppColors.cyan, width: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showResponseDialog(BuildContext context, String status) {
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(
            status == 'approved' ? 'Approve Appointment' : 'Reject Appointment',
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                status == 'approved'
                    ? 'Add a note for the member (optional):'
                    : 'Reason for rejection (optional):',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Add a note…',
                hintStyle: const TextStyle(color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: AppColors.border, width: 0.5)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: AppColors.border, width: 0.5)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: AppColors.lime, width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onUpdate(
                status,
                notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'approved'
                  ? AppColors.green : AppColors.red,
              minimumSize: const Size(0, 40),
            ),
            child: Text(
                status == 'approved' ? 'Approve' : 'Reject',
                style: const TextStyle(color: AppColors.bg)),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) => switch (status) {
    'approved'  => AppColors.green,
    'rejected'  => AppColors.red,
    'completed' => AppColors.cyan,
    _           => AppColors.amber,
  };
}


// ── Filter Chip ────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String       label;
  final bool         active;
  final Color        color;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active,
    required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? color : AppColors.border,
              width: active ? 1.5 : 0.5),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? color : AppColors.textSecondary,
                fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}