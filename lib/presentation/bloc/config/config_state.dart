part of 'config_cubit.dart';

class ConfigState extends Equatable {
  final String? codeWord;
  final bool isSaving;
  final bool saveSuccess;

  const ConfigState({
    this.codeWord,
    this.isSaving = false,
    this.saveSuccess = false,
  });

  ConfigState copyWith({
    String? codeWord,
    bool? isSaving,
    bool? saveSuccess,
    bool clearSuccess = false,
  }) {
    return ConfigState(
      codeWord: codeWord ?? this.codeWord,
      isSaving: isSaving ?? this.isSaving,
      saveSuccess: clearSuccess ? false : (saveSuccess ?? this.saveSuccess),
    );
  }

  @override
  List<Object?> get props => [codeWord, isSaving, saveSuccess];
}
