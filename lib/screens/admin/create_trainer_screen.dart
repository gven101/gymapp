import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import 'package:firebase_core/firebase_core.dart';

class CreateTrainerScreen extends StatefulWidget {
  const CreateTrainerScreen({super.key});
  @override
  State<CreateTrainerScreen> createState() => _CreateTrainerScreenState();
}

class _CreateTrainerScreenState extends State<CreateTrainerScreen> {
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  bool    _obscure = true;
  bool    _saving  = false;
  String? _message;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _createTrainer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _message = null; });

    try {
      // Save current admin user
      final currentUser = FirebaseAuth.instance.currentUser;
      final currentEmail    = currentUser?.email ?? '';

      // Create secondary Firebase app to avoid logging out admin
      final secondaryApp = await Firebase.initializeApp(
        name:    'secondary_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );

      try {
        // Create trainer auth account
        final cred = await FirebaseAuth.instanceFor(app: secondaryApp)
            .createUserWithEmailAndPassword(
          email:    _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );

        // Create Firestore user document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({
          'name':      _nameCtrl.text.trim(),
          'email':     _emailCtrl.text.trim(),
          'role':      'trainer',
          'phone':     _phoneCtrl.text.trim().isEmpty
              ? null : _phoneCtrl.text.trim(),
          'isActive':  true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Sign out secondary app and delete it
        await FirebaseAuth.instanceFor(app: secondaryApp).signOut();
        await secondaryApp.delete();

        setState(() {
          _saving  = false;
          _message = '✓ Trainer ${_nameCtrl.text.trim()} created successfully!';
          _nameCtrl.clear();
          _emailCtrl.clear();
          _passwordCtrl.clear();
          _phoneCtrl.clear();
        });

      } catch (e) {
        await secondaryApp.delete();
        rethrow;
      }

    } on FirebaseAuthException catch (e) {
      setState(() {
        _saving  = false;
        _message = _authError(e.code);
      });
    } catch (e) {
      setState(() {
        _saving  = false;
        _message = 'Error: ${e.toString()}';
      });
    }
  }

  String _authError(String code) => switch (code) {
    'email-already-in-use' => 'This email is already registered.',
    'weak-password'        => 'Password must be at least 6 characters.',
    'invalid-email'        => 'Please enter a valid email address.',
    _                      => 'Failed to create trainer. Try again.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Create Trainer Account',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Info banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.cyan.withOpacity(0.2), width: 0.5),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.cyan, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                        'Creating a trainer account will not log you out. '
                            'The trainer can log in immediately after creation.',
                        style: TextStyle(
                            color: AppColors.cyan, fontSize: 12, height: 1.5)),
                  ),
                ]),
              ),
              const SizedBox(height: 28),

              // Name
              const Text('FULL NAME',
                  style: TextStyle(color: AppColors.textSecondary,
                      fontSize: 11, fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Trainer full name',
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      color: AppColors.textSecondary, size: 20),
                ),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter name' : null,
              ),
              const SizedBox(height: 18),

              // Email
              const Text('EMAIL',
                  style: TextStyle(color: AppColors.textSecondary,
                      fontSize: 11, fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              const SizedBox(height: 6),
              TextFormField(
                controller:  _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'trainer@example.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded,
                      color: AppColors.textSecondary, size: 20),
                ),
                validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter valid email' : null,
              ),
              const SizedBox(height: 18),

              // Phone
              const Text('PHONE (OPTIONAL)',
                  style: TextStyle(color: AppColors.textSecondary,
                      fontSize: 11, fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              const SizedBox(height: 6),
              TextFormField(
                controller:  _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: '+91 98765 43210',
                  prefixIcon: Icon(Icons.phone_outlined,
                      color: AppColors.textSecondary, size: 20),
                ),
              ),
              const SizedBox(height: 18),

              // Password
              const Text('PASSWORD',
                  style: TextStyle(color: AppColors.textSecondary,
                      fontSize: 11, fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              const SizedBox(height: 6),
              TextFormField(
                controller:  _passwordCtrl,
                obscureText: _obscure,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Min 6 characters',
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      color: AppColors.textSecondary, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textSecondary, size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) =>
                (v == null || v.length < 6)
                    ? 'Minimum 6 characters' : null,
              ),
              const SizedBox(height: 32),

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
                  child: Row(children: [
                    Icon(
                        _message!.startsWith('✓')
                            ? Icons.check_circle_outline_rounded
                            : Icons.error_outline_rounded,
                        color: _message!.startsWith('✓')
                            ? AppColors.green : AppColors.red,
                        size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(_message!,
                            style: TextStyle(
                                color: _message!.startsWith('✓')
                                    ? AppColors.green : AppColors.red,
                                fontWeight: FontWeight.w600))),
                  ]),
                ),

              // Create button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _createTrainer,
                  child: _saving
                      ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: AppColors.bg))
                      : const Text('CREATE TRAINER ACCOUNT'),
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