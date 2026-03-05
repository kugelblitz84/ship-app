class HomeModel {
  String? name;
  String? organization;
  String? email;
  String? phone;
  HomeModel({this.name, this.organization, this.email, this.phone});

  factory HomeModel.fromMap(Map<String, dynamic> map) {
    return HomeModel(
      name: map['username'] as String?,
      organization: map['org'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
    );
  }
}
