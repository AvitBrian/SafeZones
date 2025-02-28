import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  final String uid;
  final String email;
  final String username;
  final String location;
  final String profileImageUrl;
  final bool emailVerified;
  final List<dynamic> flags;
  final Timestamp createdAt;
  final User? firebaseUser;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.location,
    required this.profileImageUrl,
    required this.emailVerified,
    required this.flags,
    required this.createdAt,
    this.firebaseUser,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, {User? firebaseUser}) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      username: data['username'] ?? 'User',
      location: data['location'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      emailVerified: data['emailVerified'] ?? false,
      flags: List<dynamic>.from(data['flags'] ?? []),
      createdAt: data['createdAt'],
      firebaseUser: firebaseUser,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'location': location,
      'profileImageUrl': profileImageUrl,
      'emailVerified': emailVerified,
      'flags': flags,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
