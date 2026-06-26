import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/datasources/local_storage_datasource.dart';
import 'data/datasources/supabase_datasource.dart';
import 'data/repositories/alert_repository_impl.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/contacts_repository_impl.dart';
import 'data/repositories/profile_repository_impl.dart';
import 'domain/repositories/alert_repository.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/contacts_repository.dart';
import 'domain/repositories/profile_repository.dart';
import 'presentation/bloc/auth/auth_cubit.dart';
import 'presentation/bloc/config/config_cubit.dart';
import 'presentation/bloc/contacts/contacts_cubit.dart';
import 'presentation/bloc/home/home_cubit.dart';
import 'presentation/bloc/emergency/emergency_cubit.dart';
import 'presentation/bloc/onboarding/onboarding_cubit.dart';
import 'presentation/bloc/profile/profile_cubit.dart';
import 'presentation/bloc/route/route_cubit.dart';
import 'presentation/bloc/tracking/tracking_cubit.dart';
import 'services/livekit_service.dart';
import 'domain/entities/profile.dart';
import 'services/location_service.dart';
import 'services/messaging_service.dart';
import 'services/push_service.dart';
import 'services/voice_service.dart';

final getIt = GetIt.instance;

Future<void> initDependencies() async {
  // Datasources
  final localStorage = LocalStorageDatasource();
  await localStorage.init();

  getIt.registerSingleton<LocalStorageDatasource>(localStorage);
  getIt.registerSingleton<SupabaseDatasource>(
    SupabaseDatasource(Supabase.instance.client),
  );

  // Services
  getIt.registerSingleton<LocationService>(LocationService());
  getIt.registerSingleton<MessagingService>(MessagingService());
  getIt.registerSingleton<PushService>(PushService());
  getIt.registerSingleton<LiveKitService>(LiveKitService());
  getIt.registerSingleton<VoiceService>(VoiceService());

  // Repositories
  getIt.registerSingleton<AuthRepository>(
    AuthRepositoryImpl(getIt(), getIt()),
  );
  getIt.registerSingleton<ProfileRepository>(
    ProfileRepositoryImpl(getIt(), getIt()),
  );
  getIt.registerSingleton<ContactsRepository>(
    ContactsRepositoryImpl(getIt()),
  );
  getIt.registerSingleton<AlertRepository>(
    AlertRepositoryImpl(getIt()),
  );

  // Cubits
  getIt.registerFactory(() => AuthCubit(getIt(), getIt()));
  getIt.registerFactory(() => OnboardingCubit(getIt()));
  getIt.registerFactory(() => ProfileCubit(getIt(), getIt()));
  getIt.registerFactory(() => ContactsCubit(getIt()));
  getIt.registerFactory(() => ConfigCubit(getIt()));
  getIt.registerFactory(() => HomeCubit(getIt(), getIt()));
  getIt.registerFactory(() => RouteCubit(getIt(), getIt(), getIt(), getIt(), getIt(), getIt(), getIt(), getIt()));
  getIt.registerFactory(() => EmergencyCubit(getIt(), getIt(), getIt(), getIt()));
  getIt.registerFactoryParam<TrackingCubit, Profile, void>(
    (alvo, _) => TrackingCubit(getIt(), getIt(), getIt(), alvo),
  );
}
