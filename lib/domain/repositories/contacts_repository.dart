import '../entities/contact.dart';
import '../../core/utils/result.dart';

abstract class ContactsRepository {
  Future<Result<List<Contact>>> getContacts();
  Future<Result<void>> saveContacts(List<Contact> contacts);
}
