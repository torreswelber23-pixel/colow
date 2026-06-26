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

  String _gerarCodigo() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
