import 'package:url_launcher/url_launcher.dart';

import '../domain/entities/app_location.dart';
import '../domain/entities/contact.dart';

/// Abre WhatsApp / SMS / discador para os contatos de confianca.
/// Porta a logica de `abrirParaContato` / `dispararSOS` do app antigo (lib/colow + App.js).
class MessagingService {
  /// Link do Google Maps para a localizacao (ou aviso de indisponivel).
  String mapsLink(AppLocation? location) {
    if (location == null) return '(local indisponivel)';
    return 'https://maps.google.com/?q=${location.lat},${location.lng}';
  }

  /// Mensagem de SOS para a familia: tenta WhatsApp, cai pra SMS.
  Future<void> sendSosToContacts(
    List<Contact> contacts,
    AppLocation? location,
  ) async {
    final msg =
        '🆘 SOS COLOW! Preciso de ajuda AGORA.\nMinha localizacao: ${mapsLink(location)}';
    await _openForContact(contacts, msg);
  }

  /// Aviso de chegada em seguranca.
  Future<void> sendArrivalToContacts(
    List<Contact> contacts,
    AppLocation? location,
  ) async {
    final link = location != null ? mapsLink(location) : '';
    await _openForContact(contacts, '✅ Cheguei em seguranca! $link');
  }

  /// Liga para a policia (190).
  Future<void> call190() async {
    final tel = Uri.parse('tel:190');
    if (await canLaunchUrl(tel)) {
      await launchUrl(tel, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openForContact(List<Contact> contacts, String message) async {
    final text = Uri.encodeComponent(message);

    if (contacts.isNotEmpty) {
      final numero = contacts.first.telefone.replaceAll(RegExp(r'\D'), '');
      final whatsapp = Uri.parse('whatsapp://send?phone=55$numero&text=$text');
      if (await canLaunchUrl(whatsapp)) {
        await launchUrl(whatsapp, mode: LaunchMode.externalApplication);
        return;
      }
      // fallback: SMS para o mesmo numero
      final sms = Uri.parse('sms:$numero?body=$text');
      await launchUrl(sms, mode: LaunchMode.externalApplication);
    } else {
      // sem contatos: abre o app de SMS sem destinatario
      final sms = Uri.parse('sms:?body=$text');
      await launchUrl(sms, mode: LaunchMode.externalApplication);
    }
  }
}
