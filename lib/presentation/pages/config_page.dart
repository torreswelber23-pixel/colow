import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/app_colors.dart';
import '../bloc/config/config_cubit.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  final _codeWordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final word = context.read<ConfigCubit>().state.codeWord;
    if (word != null) {
      _codeWordController.text = word;
    }
  }

  @override
  void dispose() {
    _codeWordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Configuracoes'),
        backgroundColor: AppColors.bg,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Palavra-codigo',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Escolha uma frase secreta. Se voce falar durante a corrida, o COLOW dispara o alerta sozinho.',
              style: TextStyle(
                color: AppColors.ink2,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeWordController,
              decoration: const InputDecoration(
                hintText: 'Ex: "passa na casa da tia Cleide"',
              ),
            ),
            const SizedBox(height: 12),
            BlocConsumer<ConfigCubit, ConfigState>(
              listenWhen: (prev, curr) => prev.saveSuccess != curr.saveSuccess,
              listener: (context, state) {
                if (state.saveSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Palavra-código salva com sucesso!'),
                      backgroundColor: AppColors.green,
                    ),
                  );
                }
              },
              builder: (context, state) {
                return ElevatedButton(
                  onPressed: state.isSaving
                      ? null
                      : () {
                          context.read<ConfigCubit>().saveCodeWord(_codeWordController.text);
                          FocusScope.of(context).unfocus();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: state.isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Salvar palavra-codigo'),
                );
              },
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: AppColors.primaryDeep),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Escolha um nome incomum (Cleide, Girassol). Palavras curtas tipo "sim" ou "casa" disparam errado.',
                      style: TextStyle(
                        color: AppColors.ink2,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
