import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/utils/result.dart';
import '../../../domain/entities/contact.dart';
import '../../../domain/repositories/contacts_repository.dart';

part 'contacts_state.dart';

class ContactsCubit extends Cubit<ContactsState> {
  final ContactsRepository _contactsRepository;

  ContactsCubit(this._contactsRepository) : super(const ContactsState());

  Future<void> loadContacts() async {
    emit(state.copyWith(status: ContactsStatus.loading));
    final result = await _contactsRepository.getContacts();
    switch (result) {
      case Success(data: final contacts):
        emit(state.copyWith(
          status: ContactsStatus.loaded,
          contacts: contacts,
        ));
      case Error(failure: final failure):
        emit(state.copyWith(
          status: ContactsStatus.error,
          errorMessage: failure.message,
        ));
    }
  }

  Future<void> addContact(String nome, String telefone) async {
    if (nome.trim().isEmpty || telefone.trim().isEmpty) {
      emit(state.copyWith(errorMessage: 'Preencha nome e telefone'));
      return;
    }

    final updated = List<Contact>.from(state.contacts)
      ..add(Contact(nome: nome.trim(), telefone: telefone.trim()));

    await _save(updated);
  }

  Future<void> removeContact(int index) async {
    final updated = List<Contact>.from(state.contacts)..removeAt(index);
    await _save(updated);
  }

  Future<void> _save(List<Contact> contacts) async {
    final result = await _contactsRepository.saveContacts(contacts);
    switch (result) {
      case Success():
        emit(state.copyWith(
          status: ContactsStatus.loaded,
          contacts: contacts,
          errorMessage: null,
        ));
      case Error(failure: final failure):
        emit(state.copyWith(errorMessage: failure.message));
    }
  }
}
