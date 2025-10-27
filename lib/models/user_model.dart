class UserModel {
  final String uid;
  final String email;
  final String? name;
  final String role; // 'admin' | 'driver'

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    this.name,
  });

  Map<String, dynamic> toMap() => {
        'email': email,
        'name': name,
        'role': role,
      };

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      email: (map['email'] ?? '') as String,
      role: (map['role'] ?? 'driver') as String,
      name: map['name'] as String?,
    );
  }
}
