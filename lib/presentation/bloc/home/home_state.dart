part of 'home_cubit.dart';

enum HomeStatus { initial, loading, loaded, error }

class HomeState extends Equatable {
  final HomeStatus status;
  final Profile? profile;
  final List<Contact> contacts;
  final AppLocation? location;
  final bool hasCodeWord;
  final String? errorMessage;

  const HomeState({
    this.status = HomeStatus.initial,
    this.profile,
    this.contacts = const [],
    this.location,
    this.hasCodeWord = false,
    this.errorMessage,
  });

  HomeState copyWith({
    HomeStatus? status,
    Profile? profile,
    List<Contact>? contacts,
    AppLocation? location,
    bool? hasCodeWord,
    String? errorMessage,
  }) {
    return HomeState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      contacts: contacts ?? this.contacts,
      location: location ?? this.location,
      hasCodeWord: hasCodeWord ?? this.hasCodeWord,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, profile, contacts, location, hasCodeWord, errorMessage];
}
