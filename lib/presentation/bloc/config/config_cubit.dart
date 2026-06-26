import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../data/datasources/local_storage_datasource.dart';

part 'config_state.dart';

class ConfigCubit extends Cubit<ConfigState> {
  final LocalStorageDatasource _storage;

  ConfigCubit(this._storage) : super(const ConfigState());

  Future<void> loadConfig() async {
    final word = await _storage.getCodeWord();
    emit(state.copyWith(codeWord: word));
  }

  Future<void> saveCodeWord(String word) async {
    emit(state.copyWith(isSaving: true, clearSuccess: true));
    await _storage.saveCodeWord(word.trim());
    emit(state.copyWith(
      isSaving: false,
      saveSuccess: true,
      codeWord: word.trim(),
    ));
  }
}
