part of 'contacts_cubit.dart';

enum ContactsStatus { initial, loading, loaded, error }

class ContactsState extends Equatable {
  final ContactsStatus status;
  final List<Contact> contacts;
  final String? errorMessage;

  const ContactsState({
    this.status = ContactsStatus.initial,
    this.contacts = const [],
    this.errorMessage,
  });

  ContactsState copyWith({
    ContactsStatus? status,
    List<Contact>? contacts,
    String? errorMessage,
  }) {
    return ContactsState(
      status: status ?? this.status,
      contacts: contacts ?? this.contacts,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, contacts, errorMessage];
}
