import 'package:app_links/app_links.dart';

import '../config/app_constants.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();

  void listen(void Function(String path) onLink) {
    _appLinks.uriLinkStream.listen((uri) {
      onLink(uri.toString());
    });

    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        onLink(uri.toString());
      }
    });
  }

  static bool isSos(String url) =>
      url.toLowerCase().contains(AppConstants.sosDeepLink);

  static bool isPresence(String url) =>
      url.toLowerCase().contains(AppConstants.presenceDeepLink);
}
