import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _isSignedIn = false;
  bool _showSignIn = true;
  String? _errorMessage;
  User? _currentUser;
  UserModel? _userData;

  bool get isLoading => _isLoading;
  bool get isSignedIn => _isSignedIn;
  bool get showSignIn => _showSignIn;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _currentUser;
  UserModel? get userData => _userData;

  AuthService() {
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _isSignedIn = true;
      await _fetchUserData();
      notifyListeners();
    }
  }

  Future<void> _fetchUserData() async {
    if (_currentUser == null) return;

    final doc = await _firestore.collection('users').doc(_currentUser!.uid).get();
    if (doc.exists) {
      _userData = UserModel.fromMap(doc.data()!);
      notifyListeners();
    }
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _currentUser = userCredential.user;
      _isSignedIn = true;
      await _fetchUserData();
      return _currentUser;
    } on FirebaseAuthException catch (e) {
      _setError(_getErrorMessage(e));
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      _setLoading(true);
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      _currentUser = userCredential.user;
      _isSignedIn = true;

      if (userCredential.additionalUserInfo!.isNewUser) {
        await saveUserData(UserModel(
          uid: _currentUser!.uid,
          email: _currentUser!.email!,
          username: googleUser.displayName ?? 'User',
          location: '',
          profileImageUrl: googleUser.photoUrl ?? '',
          emailVerified: _currentUser!.emailVerified,
          flags: [],
          createdAt: Timestamp.now(),
          firebaseUser: _currentUser,
        ),
        '',
          googleUser.photoUrl ?? '',
          createdAt: Timestamp.now()
        );
      }

      await _fetchUserData();
      return _currentUser;
    } on FirebaseAuthException catch (e) {
      _setError(_getErrorMessage(e));
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<UserModel?> signUpWithEmail(String email, String password) async {
    try {
      _setLoading(true);

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      _currentUser = userCredential.user;
      _isSignedIn = true;

      if (_currentUser != null) {
        UserModel userModel = UserModel(
          uid: _currentUser!.uid,
          email: _currentUser!.email ?? '',
          username: _currentUser!.displayName ?? 'User',
          location: '', // Set default location here or leave empty
          profileImageUrl: _currentUser!.photoURL ?? '',
          emailVerified: _currentUser!.emailVerified,
          flags: [],
          createdAt: Timestamp.now(),
          firebaseUser: _currentUser, // We associate the Firebase User with UserModel
        );

        // Save user data in Firestore
        final success = await saveUserData(userModel, userModel.location, userModel.profileImageUrl, createdAt: userModel.createdAt);
        if (success) {
          return userModel;
        } else {
          return null;
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      _setError(_getErrorMessage(e));
      return null;
    } finally {
      _setLoading(false);
    }
  }


  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    _currentUser = null;
    _isSignedIn = false;
    _userData = null;
    notifyListeners();
  }

  Future<bool> saveUserData(UserModel user, String location, String profileImageUrl, {required Timestamp createdAt}) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'username': user.username,
        'location': location,
        'profileImageUrl': profileImageUrl,
        'emailVerified': user.emailVerified,
        'flags': user.flags,
        'createdAt': createdAt,
        'firebaseUser': user.firebaseUser!.uid,
      });
      return true;
    } catch (e) {
      debugPrint('Error saving user data: $e');
      return false;
    }
  }

  Future<void> updateUserData(Map<String, dynamic> data) async {
    if (_currentUser == null) return;

    try {
      await _firestore.collection('users').doc(_currentUser!.uid).update(data);
      await _fetchUserData();
    } catch (e) {
      debugPrint('Error updating user data: $e');
    }
  }

  void toggleAuthState() {
    _showSignIn = !_showSignIn;
    notifyListeners();
  }

  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email format';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'This email is already registered';
      case 'weak-password':
        return 'Password is too weak';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
