import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  AuthStatus _status = AuthStatus.loading;
  User?      _fbUser;
  Map<String, dynamic>? _userData;
  String?    _error;

  AuthStatus            get status   => _status;
  User?                 get fbUser   => _fbUser;
  Map<String, dynamic>? get userData => _userData;
  String?               get error    => _error;
  String?               get userId   => _fbUser?.uid;
  String?               get userName => _userData?['name'];
  String?               get userRole => _userData?['role'];
  bool get isAdmin   => userRole == 'admin';
  bool get isTrainer => userRole == 'trainer';
  bool get isMember  => userRole == 'member';

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    _fbUser = user;
    if (user == null) {
      _userData = null;
      _status   = AuthStatus.unauthenticated;
    } else {
      final doc = await _db.collection('users').doc(user.uid).get();
      _userData = doc.exists ? doc.data() : null;
      _status   = AuthStatus.authenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _error = null;
    notifyListeners();
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _authError(e.code);
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _error = null;
    notifyListeners();
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _db.collection('users').doc(cred.user!.uid).set({
        'name':      name.trim(),
        'email':     email.trim(),
        'role':      'member',
        'isActive':  true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _authError(e.code);
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  String _authError(String code) => switch (code) {
    'user-not-found'       => 'No account found with this email.',
    'wrong-password'       => 'Incorrect password.',
    'invalid-credential'   => 'Invalid email or password.',
    'email-already-in-use' => 'An account with this email already exists.',
    'weak-password'        => 'Password must be at least 6 characters.',
    'invalid-email'        => 'Please enter a valid email address.',
    _                      => 'Authentication failed. Please try again.',
  };
}