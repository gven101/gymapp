import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

class AssignTrainerScreen extends StatefulWidget {
  const AssignTrainerScreen({super.key});
  @override
  State<AssignTrainerScreen> createState() => _AssignTrainerScreenState();
}

class _AssignTrainerScreenState extends State<AssignTrainerScreen> {
  final _db = FirebaseFirestore.instance;

  Map<String, dynamic>? _selectedMember;
  Map<String, dynamic>? _selectedTrainer;
  List<Map<String, dynamic>> _members  = [];
  List<Map<String, dynamic>> _trainers = [];
  bool _loading    = false;
  bool _assigning  = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    final membersSnap = await _db.collection('users')
        .where('role', isEqualTo: 'member').get();
    final trainersSnap = await _db.collection('users')
        .where('role', isEqualTo: 'trainer').get();
    setState(() {
      _members  = membersSnap.docs
          .map((d) => {'id': d.id, ...d.data()}).toList();
      _trainers = trainersSnap.docs
          .map((d) => {'id': d.id, ...d.data()}).toList();
      _loading  = false;
    });
  }

  Future<void> _assign() async {
    if (_selectedMember == null || _selectedTrainer == null) {
      setState(() => _message = 'Please select both a member and a trainer.');
      return;
    }
    setState(() { _assigning = true; _message = null; });

    // Check if member already has an active trainer
    final existing = await _db.collection('trainerAssignments')
        .where('memberId',  isEqualTo: _selectedMember!['id'])
        .where('isActive', isEqualTo: true)
        .get();

    if (existing.docs.isNotEmpty) {
      final currentTrainer = existing.docs.first.data()['trainerName'];

      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Member Already Assigned',
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          content: Text(
              '${_selectedMember!['name']} is currently assigned to '
                  '$currentTrainer.\n\nDo you want to reassign them to '
                  '${_selectedTrainer!['name']}? The previous assignment '
                  'will be deactivated.',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lime,
                minimumSize: const Size(0, 40),
              ),
              child: const Text('Reassign',
                  style: TextStyle(color: AppColors.bg)),
            ),
          ],
        ),
      );

      if (confirm != true) {
        setState(() { _assigning = false; });
        return;
      }
    }

    // Proceed with assignment
    final batch = _db.batch();

    // Deactivate existing assignments
    for (final doc in existing.docs) {
      batch.update(doc.reference, {
        'isActive': false,
        'endedAt':  FieldValue.serverTimestamp(),
      });
    }

    // Create new assignment
    final newRef = _db.collection('trainerAssignments').doc();
    batch.set(newRef, {
      'memberId':    _selectedMember!['id'],
      'memberName':  _selectedMember!['name'],
      'memberEmail': _selectedMember!['email'],
      'trainerId':   _selectedTrainer!['id'],
      'trainerName': _selectedTrainer!['name'],
      'assignedBy':  context.read<AuthProvider>().userId,
      'isActive':    true,
      'assignedAt':  FieldValue.serverTimestamp(),
    });

    // Update member's user doc
    batch.update(_db.collection('users').doc(_selectedMember!['id']), {
      'assignedTrainerId':   _selectedTrainer!['id'],
      'assignedTrainerName': _selectedTrainer!['name'],
    });

    await batch.commit();

    setState(() {
      _assigning = false;
      _message   = '✓ ${_selectedMember!['name']} assigned to '
          '${_selectedTrainer!['name']}!';
      _selectedMember  = null;
      _selectedTrainer = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Assign Trainer',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.lime))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SELECT MEMBER',
                style: TextStyle(color: AppColors.textSecondary,
                    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            // Member list
            ..._members.map((m) => _UserTile(
              name:     m['name'] ?? '',
              email:    m['email'] ?? '',
              role:     'member',
              selected: _selectedMember?['id'] == m['id'],
              onTap:    () => setState(() => _selectedMember = m),
            )),
            if (_members.isEmpty)
              const Text('No members found.',
                  style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 28),
            const Text('SELECT TRAINER',
                style: TextStyle(color: AppColors.textSecondary,
                    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            // Trainer list
            ..._trainers.map((t) => _UserTile(
              name:     t['name'] ?? '',
              email:    t['email'] ?? '',
              role:     'trainer',
              selected: _selectedTrainer?['id'] == t['id'],
              onTap:    () => setState(() => _selectedTrainer = t),
            )),
            if (_trainers.isEmpty)
              const Text('No trainers found. Create a trainer account first.',
                  style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 32),
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
                      fontWeight: FontWeight.w600,
                    )),
              ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _assigning ? null : _assign,
                child: _assigning
                    ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.bg))
                    : const Text('ASSIGN TRAINER'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final bool   selected;
  final VoidCallback onTap;
  const _UserTile({required this.name, required this.email,
    required this.role, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = role == 'trainer' ? AppColors.cyan : AppColors.lime;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600, fontSize: 14)),
              Text(email, style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
            ],
          )),
          if (selected)
            Icon(Icons.check_circle_rounded, color: color, size: 20),
        ]),
      ),
    );
  }
}