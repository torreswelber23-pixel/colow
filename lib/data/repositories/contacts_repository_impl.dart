import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/contact.dart';
import '../../domain/repositories/contacts_repository.dart';
import '../datasources/local_storage_datasource.dart';
import '../models/contact_model.dart';

class ContactsRepositoryImpl implements ContactsRepository {
  final LocalStorageDatasource _local;

  ContactsRepositoryImpl(this._local);

  @override
  Future<Result<List<Contact>>> getContacts() async {
    try {
      final contacts = await _local.getContacts();
      return Success(contacts);
    } catch (e) {
      return Error(CacheFailure('Erro ao carregar contatos: $e'));
    }
  }

  @override
  Future<Result<void>> saveContacts(List<Contact> contacts) async {
    try {
      await _local.saveContacts(contacts.map(ContactModel.fromEntity).toList());
      return const Success(null);
    } catch (e) {
      return Error(CacheFailure('Erro ao salvar contatos: $e'));
    }
  }
}
