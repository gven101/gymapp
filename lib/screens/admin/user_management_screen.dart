import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});
  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _db         = FirebaseFirestore.instance;
  String _filter    = 'all';
  String _search    = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Manage Users',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(children: [

        // ── Search + Filter ─────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: AppColors.surface,
          child: Column(children: [

            // Search bar
            TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                hintText:  'Search by name or email…',
                hintStyle: const TextStyle(
                    color: AppColors.textHint, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textSecondary, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AppColors.textSecondary, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                  },
                )
                    : null,
                filled:    true,
                fillColor: AppColors.card,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 16),
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
            const SizedBox(height: 10),

            // Role filter chips
            Row(children: [
              _FilterChip(
                label:  'All',
                active: _filter == 'all',
                color:  AppColors.textSecondary,
                onTap:  () => setState(() => _filter = 'all'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label:  'Members',
                active: _filter == 'member',
                color:  AppColors.lime,
                onTap:  () => setState(() => _filter = 'member'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label:  'Trainers',
                active: _filter == 'trainer',
                color:  AppColors.cyan,
                onTap:  () => setState(() => _filter = 'trainer'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label:  'Admins',
                active: _filter == 'admin',
                color:  AppColors.red,
                onTap:  () => setState(() => _filter = 'admin'),
              ),
            ]),
          ]),
        ),

        // ── User List ───────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('users').snapshots(),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.lime));
              }

              var docs = snap.data?.docs ?? [];

              // Filter by role locally
              if (_filter != 'all') {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return data['role'] == _filter;
                }).toList();
              }

              // Sort by createdAt descending locally
              docs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aT = aData['createdAt'];
                final bT = bData['createdAt'];
                if (aT == null || bT == null) return 0;
                return (bT as Timestamp).compareTo(aT as Timestamp);
              });

              // Apply search filter locally
              if (_search.isNotEmpty) {
                docs = docs.where((d) {
                  final data  = d.data() as Map<String, dynamic>;
                  final name  = (data['name']  as String? ?? '').toLowerCase();
                  final email = (data['email'] as String? ?? '').toLowerCase();
                  return name.contains(_search) || email.contains(_search);
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_search_rounded,
                          color: AppColors.textSecondary, size: 44),
                      const SizedBox(height: 12),
                      Text(
                          _search.isNotEmpty
                              ? 'No users found for "$_search"'
                              : 'No ${_filter == 'all' ? 'users' : '${_filter}s'} found.',
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
                  final uid  = docs[i].id;
                  return _UserCard(
                    uid:      uid,
                    data:     data,
                    onToggle: (isActive) =>
                        _toggleStatus(uid, isActive, data['name']),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  Future<void> _toggleStatus(
      String uid, bool currentStatus, String name) async {
    final action = currentStatus ? 'deactivate' : 'activate';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(
            '${action[0].toUpperCase()}${action.substring(1)} User',
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
            'Are you sure you want to $action $name?'
                '${currentStatus ? '\n\nThey will not be able to log in.' : ''}',
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
              backgroundColor: currentStatus
                  ? AppColors.red : AppColors.green,
              minimumSize: const Size(0, 40),
            ),
            child: Text(
                action[0].toUpperCase() + action.substring(1),
                style: const TextStyle(color: AppColors.bg)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _db.collection('users').doc(uid).update({
      'isActive': !currentStatus,
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          '$name ${!currentStatus ? 'activated' : 'deactivated'} successfully.',
          style: const TextStyle(color: AppColors.bg)),
      backgroundColor: !currentStatus ? AppColors.green : AppColors.amber,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }
}

// ── User Card ────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final String               uid;
  final Map<String, dynamic> data;
  final Function(bool)       onToggle;

  const _UserCard({
    required this.uid,
    required this.data,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final name     = data['name']     as String? ?? 'Unknown';
    final email    = data['email']    as String? ?? '';
    final role     = data['role']     as String? ?? 'member';
    final isActive = data['isActive'] as bool?   ?? true;
    final phone    = data['phone']    as String?;

    final initials = name.split(' ')
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
        .join();

    final roleColor = switch (role) {
      'admin'   => AppColors.red,
      'trainer' => AppColors.cyan,
      _         => AppColors.lime,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.card
            : AppColors.card.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isActive
                ? roleColor.withOpacity(0.2)
                : AppColors.border,
            width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [

          // Avatar
          Stack(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: isActive
                  ? roleColor.withOpacity(0.12)
                  : AppColors.border,
              child: Text(initials,
                  style: TextStyle(
                      color:      isActive ? roleColor : AppColors.textHint,
                      fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            if (!isActive)
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                      color:  AppColors.red,
                      shape:  BoxShape.circle,
                      border: Border.all(
                          color: AppColors.card, width: 1.5)),
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.bg, size: 8),
                ),
              ),
          ]),
          const SizedBox(width: 12),

          // Info
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(name,
                      style: TextStyle(
                          color: isActive
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(role.toUpperCase(),
                      style: TextStyle(
                          color:      roleColor,
                          fontSize:   9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                ),
              ]),
              const SizedBox(height: 3),
              Text(email,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              if (phone != null) ...[
                const SizedBox(height: 2),
                Text(phone,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.green.withOpacity(0.1)
                      : AppColors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                    isActive ? 'ACTIVE' : 'INACTIVE',
                    style: TextStyle(
                        color:      isActive ? AppColors.green : AppColors.red,
                        fontSize:   9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              ),
            ],
          )),
          const SizedBox(width: 8),

          // Toggle button
          GestureDetector(
            onTap: () => onToggle(isActive),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.red.withOpacity(0.1)
                    : AppColors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isActive
                        ? AppColors.red.withOpacity(0.3)
                        : AppColors.green.withOpacity(0.3),
                    width: 0.5),
              ),
              child: Icon(
                  isActive
                      ? Icons.block_rounded
                      : Icons.check_circle_outline_rounded,
                  color: isActive ? AppColors.red : AppColors.green,
                  size: 20),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Filter Chip ──────────────────────────────────────────────
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
                color:      active ? color : AppColors.textSecondary,
                fontSize:   12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}