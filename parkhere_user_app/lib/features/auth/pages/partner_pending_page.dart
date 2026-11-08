import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

class PartnerPendingPage extends ConsumerWidget {
  const PartnerPendingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final inspectionDone = auth.approvalStatus == 'waiting_inspection';
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.hourglass_top_rounded,
                          size: 56, color: Color(0xFF1479B8)),
                      const SizedBox(height: 12),
                      const Text(
                        'Conta em análise',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Seu acesso de parceiro será liberado após a validação da documentação e da vistoria do local.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      _Stage(
                        title: '1. Documentação',
                        description: 'Alvará, documento do responsável, comprovante do endereço e seguro quando informado.',
                        state: inspectionDone ? _StageState.done : _StageState.inProgress,
                      ),
                      _Stage(
                        title: '2. Imagens e vistoria',
                        description: 'Análise das imagens do estabelecimento ou vistoria por videochamada agendada.',
                        state: inspectionDone ? _StageState.inProgress : _StageState.waiting,
                      ),
                      if (auth.approvalMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(auth.approvalMessage!, style: TextStyle(color: Colors.grey.shade700)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => ref.read(authProvider.notifier).resetLoginFlow(),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Voltar ao login'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _StageState { waiting, inProgress, done }

class _Stage extends StatelessWidget {
  final String title;
  final String description;
  final _StageState state;
  const _Stage({required this.title, required this.description, required this.state});

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _StageState.done => Colors.green,
      _StageState.inProgress => const Color(0xFF1479B8),
      _StageState.waiting => Colors.grey,
    };
    final icon = switch (state) {
      _StageState.done => Icons.check_circle,
      _StageState.inProgress => Icons.pending,
      _StageState.waiting => Icons.radio_button_unchecked,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(description, style: TextStyle(color: Colors.grey.shade700, height: 1.35)),
        ])),
      ]),
    );
  }
}
