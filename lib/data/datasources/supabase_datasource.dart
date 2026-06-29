import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_model.dart';

class SupabaseDatasource {
  final SupabaseClient _client;

  SupabaseDatasource(this._client);

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<bool> signInWithGoogle(String redirectUrl) async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectUrl,
    );
  }

  Future<User> signInWithEmail(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) throw Exception('Login falhou');
    return user;
  }

  Future<User> signUpWithEmail(String email, String password) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) throw Exception('Cadastro falhou');
    return user;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<ProfileModel?> getProfileByDeviceId(String deviceId) async {
    final response = await _client
        .from('perfis')
        .select()
        .eq('device_id', deviceId)
        .maybeSingle();

    if (response == null) return null;
    return ProfileModel.fromJson(response);
  }

  Future<ProfileModel?> getProfileByUserId(String userId) async {
    final response = await _client
        .from('perfis')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return ProfileModel.fromJson(response);
  }

  Future<ProfileModel> createProfile({
    required String deviceId,
    required String nome,
    String? userId,
  }) async {
    final codigo = _gerarCodigo();
    final response = await _client
        .from('perfis')
        .insert({
          'device_id': deviceId,
          'user_id': userId,
          'nome': nome,
          'codigo': codigo,
        })
        .select()
        .single();

    return ProfileModel.fromJson(response);
  }

  Future<ProfileModel> updateProfile(ProfileModel profile) async {
    final response = await _client
        .from('perfis')
        .update({
          'nome': profile.nome,
          'push_token': profile.pushToken,
        })
        .eq('id', profile.id)
        .select()
        .single();

    return ProfileModel.fromJson(response);
  }

  Future<ProfileModel?> addByCode(String meuId, String codigo) async {
    final alvo = await _client
        .from('perfis')
        .select()
        .eq('codigo', codigo.trim().toUpperCase())
        .maybeSingle();

    if (alvo == null) return null;

    final alvoId = alvo['id'] as String;
    if (alvoId == meuId) throw Exception('proprio_codigo');

    await _client.from('vinculos').insert({
      'protegido_id': alvoId,
      'acompanhante_id': meuId,
    });

    return ProfileModel.fromJson(alvo);
  }

  Future<List<ProfileModel>> getCircle(String meuId) async {
    final response = await _client
        .from('vinculos')
        .select('protegido:protegido_id (id, nome, codigo)')
        .eq('acompanhante_id', meuId);

    return (response as List)
        .map((e) {
          final protegido = e['protegido'];
          if (protegido == null) return null;
          return ProfileModel.fromJson(protegido as Map<String, dynamic>);
        })
        .whereType<ProfileModel>()
        .toList();
  }

  Future<void> updateLocation({
    required String perfilId,
    required double lat,
    required double lng,
    required bool emRota,
  }) async {
    await _client.from('localizacoes').upsert({
      'perfil_id': perfilId,
      'lat': lat,
      'lng': lng,
      'em_rota': emRota,
      'atualizado_em': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getLocation({
    required String solicitanteId,
    required String alvoId,
  }) async {
    final result = await _client.functions.invoke(
      'pegar-local',
      body: {
        'solicitante_id': solicitanteId,
        'alvo_id': alvoId,
      },
    );

    return result.data['local'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>> sendAlert({
    required double lat,
    required double lng,
    required String nome,
    required String mensagem,
    required String? protegidoId,
    String? tipo,
  }) async {
    final result = await _client.functions.invoke(
      'enviar-alerta',
      body: {
        'lat': lat,
        'lng': lng,
        'nome': nome,
        'mensagem': mensagem,
        'protegido_id': protegidoId,
        if (tipo != null) 'tipo': tipo,
      },
    );

    return result.data as Map<String, dynamic>;
  }

  /// Solicita um token JWT do LiveKit à Edge Function `livekit-token`.
  ///
  /// [roomName] — nome da sala (ex: 'colow-{userId}')
  /// [participantName] — nome exibido na sala (nome do perfil)
  Future<String> getLiveKitToken({
    required String roomName,
    required String participantName,
  }) async {
    final result = await _client.functions.invoke(
      'livekit-token',
      body: {
        'roomName': roomName,
        'participantName': participantName,
      },
    );

    final data = result.data as Map<String, dynamic>;
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Token LiveKit não retornado pela Edge Function');
    }
    return token;
  }

  // ===== Alertas em tempo real (Realtime, sem depender de FCM) =====

  /// Insere uma linha de alerta para cada familiar (acompanhante) vinculado
  /// ao [protegidoId]. O app da familia recebe via Realtime instantaneamente.
  /// Retorna quantos familiares foram notificados.
  Future<int> insertFamilyAlerts({
    required String protegidoId,
    required String nome,
    required double lat,
    required double lng,
    String tipo = 'sos',
    String? room,
  }) async {
    final vinc = await _client
        .from('vinculos')
        .select('acompanhante_id')
        .eq('protegido_id', protegidoId);

    final rows = (vinc as List)
        .map((v) => {
              'protegido_id': protegidoId,
              'acompanhante_id': v['acompanhante_id'],
              'nome': nome,
              'lat': lat,
              'lng': lng,
              'tipo': tipo,
              'room': room ?? 'colow-$protegidoId',
            })
        .toList();

    if (rows.isEmpty) return 0;
    await _client.from('alertas_familia').insert(rows);
    return rows.length;
  }

  /// Marca um alerta como recebido (sinal de diagnostico + "visto").
  Future<void> markAlertReceived(String alertId) async {
    await _client
        .from('alertas_familia')
        .update({'status': 'recebido'}).eq('id', alertId);
  }

  /// Grava um marcador de diagnostico (aparece no banco para eu inspecionar).
  Future<void> debugMarker(String profileId, String nota) async {
    try {
      await _client.from('alertas_familia').insert({
        'protegido_id': profileId,
        'acompanhante_id': profileId,
        'nome': nota,
        'lat': 0,
        'lng': 0,
        'tipo': 'debug',
        'status': nota,
      });
    } catch (e) {
      // ignora
    }
  }

  /// Assina o Realtime da localizacao de [perfilId] (estilo Uber). Chama
  /// [onLocation] com lat/lng sempre que a posicao da pessoa atualiza.
  RealtimeChannel subscribeLocation(
    String perfilId,
    void Function(double lat, double lng) onLocation,
  ) {
    final token = _client.auth.currentSession?.accessToken;
    if (token != null) {
      _client.realtime.setAuth(token);
    }

    final channel = _client.channel('loc_$perfilId');
    void handle(Map<String, dynamic> row) {
      final lat = (row['lat'] as num?)?.toDouble();
      final lng = (row['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) onLocation(lat, lng);
    }

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'localizacoes',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'perfil_id',
        value: perfilId,
      ),
      callback: (payload) => handle(payload.newRecord),
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'localizacoes',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'perfil_id',
        value: perfilId,
      ),
      callback: (payload) => handle(payload.newRecord),
    );
    channel.subscribe();
    return channel;
  }

  /// Le a ultima localizacao conhecida de [perfilId] (para o primeiro frame).
  Future<Map<String, dynamic>?> getLastLocation(String perfilId) async {
    final r = await _client
        .from('localizacoes')
        .select('lat, lng')
        .eq('perfil_id', perfilId)
        .maybeSingle();
    return r;
  }

  /// Assina o canal Realtime de alertas destinados a [acompanhanteId].
  /// Chama [onAlert] com os dados da linha sempre que um alerta novo chega.
  RealtimeChannel subscribeFamilyAlerts(
    String acompanhanteId,
    void Function(Map<String, dynamic> alerta) onAlert,
  ) {
    // Essencial: aplica o token do usuario no Realtime, senao a RLS bloqueia
    // a entrega dos eventos (o canal conecta mas nunca recebe nada).
    final token = _client.auth.currentSession?.accessToken;
    if (token != null) {
      _client.realtime.setAuth(token);
    }

    final channel = _client.channel('alertas_familia_$acompanhanteId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'alertas_familia',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'acompanhante_id',
        value: acompanhanteId,
      ),
      callback: (payload) => onAlert(payload.newRecord),
    );
    channel.subscribe((status, error) {
      // Grava o status da assinatura no banco para diagnostico.
      debugMarker(acompanhanteId, 'sub_${status.name}${error != null ? '_err' : ''}');
    });
    return channel;
  }

  String _gerarCodigo() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
