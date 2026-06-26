# COLOW Flutter

Reescrita do app COLOW em Flutter. Seguranca pessoal em corridas.

## Arquitetura

- **Framework:** Flutter 3.x + Dart
- **Backend:** Supabase (Auth + Postgres + Edge Functions)
- **State management:** flutter_bloc + Cubits
- **DI:** get_it
- **Local storage:** Hive
- **Mapas:** Mapbox Maps Flutter
- **Audio ao vivo:** LiveKit
- **Voz:** speech_to_text (online, com espaco pra Vosk offline futuro)
- **Push notifications:** Firebase Cloud Messaging + flutter_local_notifications

## Estrutura

```
lib/
├── config/         # cores, tema, constantes, env
├── core/           # errors, result, usecases
├── data/           # datasources, models, repositories
├── domain/         # entities e contratos de repositories
├── presentation/   # blocs, pages, widgets
├── services/       # location, audio, push, deep links
├── app.dart
├── injection.dart
└── main.dart
```

## Como rodar

1. Copie `.env.example` para `.env` e preencha as chaves:
   ```
   cp .env.example .env
   ```

2. Instale as dependencias:
   ```
   flutter pub get
   ```

3. Configure o Firebase para push notifications (google-services.json / GoogleService-Info.plist).

4. Rode:
   ```
   flutter run
   ```

## Funcionalidades implementadas

- [x] Onboarding
- [x] Login com Google via Supabase
- [x] Perfil e circulo de confianca
- [x] Contatos de emergencia
- [x] Home com status de protecao
- [x] Rota protegida com SOS e "cheguei"
- [x] Localizacao via geolocator
- [x] Servico de localizacao
- [ ] Mapa Mapbox nativo
- [ ] Audio ao vivo LiveKit
- [ ] Reconhecimento de voz offline (Vosk)
- [ ] Notificacoes push completas
- [ ] Modo guardiao
- [ ] Acompanhamento ao vivo

## Configuracao nativa

### Android
Permissoes ja adicionadas em `android/app/src/main/AndroidManifest.xml`:
- Localizacao foreground/background
- Microfone
- Foreground service
- Notificacoes

Core library desugaring habilitado em `android/app/build.gradle.kts`.

### iOS
Permissoes ja adicionadas em `ios/Runner/Info.plist`:
- Localizacao (always + when in use)
- Microfone
- Background modes (location, audio, fetch, remote-notification)

## Problemas conhecidos

- O build nativo completo exige espaco em disco suficiente (LiveKit + Mapbox + Firebase sao pesados).
- `vosk_flutter` foi removido temporariamente por conflitos de dependencia (`http ^0.13.5`).
  A solucao atual e `speech_to_text` online, com interface preparada para trocar por Vosk depois.
