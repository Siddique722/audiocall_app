class UserModel {
  final String id;
  final String name;
  final String email;
  final String? fcmToken;

  UserModel(
      {required this.id,
      required this.name,
      required this.email,
      this.fcmToken});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      if (fcmToken != null) 'fcm_token': fcmToken,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'].toString(),
      name: map['name'],
      email: map['email'],
      fcmToken: map['fcm_token'],
    );
  }
}
