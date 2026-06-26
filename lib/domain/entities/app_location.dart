import 'package:equatable/equatable.dart';

class AppLocation extends Equatable {
  final double lat;
  final double lng;
  final DateTime? timestamp;

  const AppLocation({
    required this.lat,
    required this.lng,
    this.timestamp,
  });

  AppLocation copyWith({
    double? lat,
    double? lng,
    DateTime? timestamp,
  }) {
    return AppLocation(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [lat, lng, timestamp];
}
