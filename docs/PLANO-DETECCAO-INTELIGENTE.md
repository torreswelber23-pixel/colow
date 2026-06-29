# COLOW — Plano técnico: detecção inteligente, background, áudio e telefonia

> Documento de arquitetura. Objetivo: sistema que escuta uma palavra-chave em
> segundo plano (mesmo com a tela bloqueada), e ao detectá-la dispara
> automaticamente áudio ao vivo para a família, push com localização em tempo
> real, e opcionalmente uma ligação telefônica via SIP.

---

## 0. Resumo executivo

| Requisito | Situação hoje | Esforço | Bloqueio |
|-----------|---------------|---------|----------|
| Detectar palavra no meio de outra | ✅ Já implementado (`contains`) | — | — |
| Disparar áudio + push + localização | 🟡 Peças prontas, falta ligar o gatilho | Baixo | — |
| Rodar em background (tela bloqueada) | 🟡 `flutter_foreground_task` instalado, não usado | Médio | iOS restritivo |
| Escuta contínua de wake-word | 🔴 `speech_to_text` é o motor errado | Médio | iOS proíbe escuta infinita |
| "Celular desligado" | 🔴 Impossível fisicamente | — | Reformular p/ "tela bloqueada" |
| SIP trunk + ramal por cliente | 🔴 Não existe | Alto | Infra + custo recorrente |

**Recomendação de ordem:** (1) wake-word offline + foreground service →
(2) ligar gatilho ao áudio/push/local → (3) SIP via LiveKit SIP.

---

## 1. Detecção da palavra-chave (wake-word)

### Problema com a solução atual
`lib/services/voice_service.dart` usa `speech_to_text`, que é:
- **Online** — precisa de internet, manda áudio pro Google/Apple.
- **Não-contínuo** — o SO derruba após ~30–60s de silêncio; o código tenta
  reiniciar num loop (`_scheduleRestart`), mas isso é frágil e gasta bateria.
- **Não roda em background** de forma confiável.

A parte boa: a lógica de match já está certa —
`recognized.contains(_targetWord)` (voice_service.dart:93) detecta a palavra
mesmo no meio de outra. **Isso se mantém.**

### Solução recomendada: Picovoice Porcupine
Motor de wake-word **offline**, baixo consumo, feito exatamente pra "sempre
ouvindo". SDK Flutter oficial (`porcupine_flutter`).

- ✅ Roda offline, sem mandar áudio pra lugar nenhum (privacidade real).
- ✅ Baixíssimo consumo de CPU/bateria (foi feito pra isso).
- ✅ Treina-se uma frase customizada no console da Picovoice.
- ⚠️ **Custo:** plano free cobre desenvolvimento; produção com muitos usuários
  exige plano pago (por MAU). Avaliar custo vs. Vosk.
- ⚠️ Wake-word é uma **frase fixa treinada**, não "qualquer palavra digitada
  pelo usuário". Se cada cliente quiser sua própria frase livre, Porcupine não
  serve direto — aí entra Vosk.

### Alternativa: Vosk (STT offline)
- ✅ Offline, **palavra-chave livre** (cada cliente define a sua) — combina com
  o fluxo atual de "palavra-código personalizada".
- ✅ Permite o `contains` no meio da palavra que você já quer.
- ⚠️ Mais pesado que Porcupine (modelo de ~50MB, mais CPU).
- ⚠️ Já foi removido antes por conflito de dependência (`http ^0.13.5`) —
  precisa reavaliar com versões atuais ou isolar via plugin.

### Decisão sugerida
Como o produto vende **palavra-código personalizada por cliente**, o caminho
natural é **Vosk** (palavra livre). Porcupine só se aceitarmos 1 frase fixa
global ou um conjunto pequeno de frases pré-treinadas.

---

## 2. Execução em background ("tela bloqueada / celular no bolso")

> ⚠️ "Celular **desligado**" é fisicamente impossível — sem energia nenhum app
> roda. O alcance real é: **app fechado/minimizado, tela bloqueada, no bolso.**

### Android — viável
- Usar **`flutter_foreground_task`** (já no `pubspec.yaml`) para rodar um serviço
  em primeiro plano com notificação fixa ("COLOW protegendo você").
- O serviço mantém o microfone + motor Vosk/Porcupine ativos.
- Permissões já declaradas no `AndroidManifest.xml`:
  `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE`, `RECORD_AUDIO`,
  `POST_NOTIFICATIONS`, `WAKE_LOCK`.
- Atenção a otimização de bateria (Doze): pedir
  `ignoreBatteryOptimizations` via `permission_handler`.

### iOS — bloqueio sério
- A Apple **não aprova** apps que escutam o microfone indefinidamente em
  background (motivo de privacidade). O background mode `audio` existe, mas é
  para reprodução/chamadas, não para vigilância de microfone.
- Caminhos possíveis no iOS:
  1. Detecção só com **app aberto/tela ativa** (degradação aceita).
  2. Ativação manual ("Iniciar proteção") + push de SOS — sem wake-word
     passivo.
  3. Aceitar que o recurso pleno é **Android-only** num primeiro momento.

**Recomendação:** lançar wake-word em background **primeiro no Android**, com
fallback manual no iOS.

---

## 3. Gatilho → áudio + push + localização (o "acionamento")

Quando o wake-word dispara, executar em sequência (a maioria já existe):

1. **Áudio ao vivo** — `LiveKitService.connect()` com microfone ligado.
   Já implementado e **testado com sucesso** (sala `colow-{perfilId}`).
2. **Push para a família** — Edge Function `enviar-alerta` +
   `PushService`/FCM. A notificação de emergência tela-cheia já existe
   (`push_service.dart` → `_showEmergencyCall`).
3. **Localização em tempo real** — `LocationService` + tabela `localizacoes`
   no Supabase (já há `updateLocation`/`getLocation`). Subir a cadência de
   updates durante o alerta (ex: a cada 4s, já configurado em
   `trackingLocationIntervalSeconds`).

➡️ **Trabalho real aqui:** criar um `EmergencyTriggerCoordinator` que, ao
receber o callback do wake-word, orquestra os 3 passos acima de forma atômica
e resiliente (retry, offline-queue). A maior parte do código já está nos
cubits `EmergencyCubit` e `RouteCubit`.

---

## 4. Telefonia via SIP trunk com ramal por cliente

Objetivo: a família **liga de um telefone comum** (ou recebe uma ligação) e
ouve o áudio do cliente em perigo.

### Caminho recomendado: LiveKit SIP
O LiveKit (que você **já usa**) tem módulo **SIP** nativo. Isso evita montar
Asterisk/FreeSWITCH do zero.

- **Inbound:** família liga para um número → cai numa sala LiveKit
  (`colow-{perfilId}`) → ouve o áudio ao vivo.
- **Outbound:** ao disparar o SOS, o sistema **liga para o telefone** da
  família e conecta na sala.
- Precisa de um **provedor de SIP trunk** (Twilio, Telnyx, Plivo) ligado ao
  LiveKit SIP.

### Ramal personalizado por cliente
- "Ramal por cliente" = mapear cada cliente a um identificador SIP
  (`sip:cliente123@seu-dominio`) ou a um número/DID dedicado.
- Implica **provisionamento** (criar ramal ao cadastrar cliente) +
  **billing** (DID dedicado custa por número/mês).
- Tabela nova no Supabase: `ramais (perfil_id, sip_uri, did_number, status)`.

### Custos a mapear (recorrentes)
- Trunk SIP: por minuto + por número (DID).
- LiveKit: por minuto de áudio/participante.
- Picovoice (se usado): por MAU.

### Alternativa mais simples (sem SIP)
Se o objetivo é só "família ouvir", o **link web do LiveKit** (testado hoje) já
resolve sem custo de telefonia. SIP só compensa se for requisito ligar de
telefone burro/sem internet.

---

## 5. Roadmap sugerido

**Fase 1 — Wake-word confiável (Android)**
- [ ] Integrar Vosk (ou Porcupine) offline.
- [ ] Foreground service com `flutter_foreground_task`.
- [ ] Pedir exclusão de otimização de bateria.
- [ ] Manter o `contains` (match no meio da palavra).

**Fase 2 — Acionamento automático**
- [ ] `EmergencyTriggerCoordinator`: wake-word → áudio + push + localização.
- [ ] Subir cadência de localização durante alerta.
- [ ] Fila offline (dispara assim que voltar a internet).

**Fase 3 — iOS (degradado)**
- [ ] Detecção com app aberto + acionamento manual.
- [ ] Validar política da App Store.

**Fase 4 — Telefonia SIP**
- [ ] LiveKit SIP + provedor de trunk.
- [ ] Provisionamento de ramal por cliente + tabela `ramais`.
- [ ] Inbound (família liga) e/ou outbound (sistema liga).

---

## 6. Riscos e decisões em aberto

1. **iOS background** — o recurso-chave (escuta passiva) é limitado pela Apple.
   Decidir: Android-first? iOS degradado? só ativação manual no iOS?
2. **Custo recorrente** — Picovoice (MAU), SIP trunk (DID + minutos), LiveKit
   (minutos). Modelar antes de prometer ao cliente.
3. **Privacidade/legal** — gravar/transmitir áudio ambiente tem implicações
   legais (LGPD). Precisa de consentimento explícito e política clara.
4. **Bateria** — escuta contínua + GPS + foreground service drena bateria.
   Testar consumo real e comunicar ao usuário.
5. **Palavra livre vs. frase treinada** — define Vosk vs. Porcupine.
