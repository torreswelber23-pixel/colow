import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/utils/result.dart';
import '../../../data/datasources/local_storage_datasource.dart';
import '../../../domain/entities/app_location.dart';
import '../../../domain/entities/contact.dart';
import '../../../domain/entities/profile.dart';
import '../../../domain/repositories/contacts_repository.dart';
import '../../../domain/repositories/profile_repository.dart';

part 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final ContactsRepository _contactsRepository;
  final ProfileRepository _profileRepository;
  final LocalStorageDatasource _storage;

  HomeCubit(this._contactsRepository, this._profileRepository, this._storage)
      : super(const HomeState());

  Future<void> loadHome() async {
    emit(state.copyWith(status: HomeStatus.loading));

    final contactsResult = await _contactsRepository.getContacts();
    final profileResult = await _profileRepository.getCurrentProfile();

    final contacts = switch (contactsResult) {
      Success(data: final list) => list,
      Error() => <Contact>[],
    };

    final profile = switch (profileResult) {
      Success(data: final p) => p,
      Error() => null,
    };

    final codeWord = await _storage.getCodeWord();
    final location = await _getLocation();

    emit(state.copyWith(
      status: HomeStatus.loaded,
      contacts: contacts,
      profile: profile,
      location: location,
      hasCodeWord: codeWord != null && codeWord.isNotEmpty,
    ));
  }

  Future<AppLocation?> _getLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          return null;
        }
      }

      final position = await Geolocator.getCurrentPosition();
      return AppLocation(
        lat: position.latitude,
        lng: position.longitude,
        timestamp: position.timestamp,
      );
    } catch (_) {
      return null;
    }
  }
}
