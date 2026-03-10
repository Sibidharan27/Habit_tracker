class UserModel {
  final String uid;
  final String name;
  final int age;
  final String phone;
  final String email;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.age,
    required this.phone,
    required this.email,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'age': age,
      'phone': phone,
      'email': email,
      'createdAt': createdAt,
    };
  }
}