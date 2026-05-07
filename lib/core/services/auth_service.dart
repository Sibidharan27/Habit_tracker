import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authState => _auth.authStateChanges();

  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in with Google using the v7 singleton API.
  /// Returns null if the user cancels.
  Future<UserCredential?> signInWithGoogle() async {
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw Exception(
        'Google Sign-In is not configured yet.\n'
        'Please enable Google in Firebase Console and add your SHA-1 fingerprint.',
      );
    }

    final googleUser = await GoogleSignIn.instance.authenticate();
    final user = googleUser; // ignore: unnecessary_null_comparison
    // ignore: dead_code
    if (user == null) return null;

    // In google_sign_in v7, GoogleSignInAuthentication is synchronous (not Future)
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;

    // Firebase only needs the idToken for sign-in
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    return await _auth.signInWithCredential(credential);
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}