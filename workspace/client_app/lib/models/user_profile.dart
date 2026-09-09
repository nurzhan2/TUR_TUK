/// Профиль клиента: имя, телефон, отель и номер комнаты.
///
/// Отель и комната лежат в профиле, а не только в заказе, потому что чекаут
/// подставляет их по умолчанию — гость живёт в одном отеле всю поездку
/// и вводить адрес доставки каждый раз не должен.
class UserProfile {
  const UserProfile({
    required this.name,
    required this.phone,
    required this.hotelName,
    required this.roomNumber,
    this.dob,
  });

  final String name;
  final String phone;
  final String hotelName;
  final String roomNumber;
  final DateTime? dob;

  UserProfile copyWith({
    String? name,
    String? phone,
    String? hotelName,
    String? roomNumber,
    DateTime? dob,
  }) {
    return UserProfile(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      hotelName: hotelName ?? this.hotelName,
      roomNumber: roomNumber ?? this.roomNumber,
      dob: dob ?? this.dob,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: (json['name'] as String?) ?? '',
        phone: (json['phone'] as String?) ?? '',
        hotelName: (json['hotel_name'] as String?) ?? '',
        roomNumber: (json['room_number'] as String?) ?? '',
        dob: DateTime.tryParse((json['dob'] as String?) ?? ''),
      );
}
