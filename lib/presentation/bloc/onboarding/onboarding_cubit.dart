import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../data/datasources/local_storage_datasource.dart';

part 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  final LocalStorageDatasource _local;

  OnboardingCubit(this._local) : super(const OnboardingState());

  Future<void> checkOnboarding() async {
    final onboarded = await _local.getOnboarded();
    emit(state.copyWith(isOnboarded: onboarded));
  }

  Future<void> completeOnboarding() async {
    await _local.setOnboarded(true);
    emit(state.copyWith(isOnboarded: true));
  }
}
