import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class PartnerFinancialLockedPage extends StatelessWidget {
  const PartnerFinancialLockedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Financeiro e complementos')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: AppTheme.softCyan,
                      foregroundColor: AppTheme.primary,
                      child: Icon(Icons.lock_outline),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Financeiro Pro (complemento)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'O caixa e a visão operacional básica já estão incluídos. Este complemento adiciona análises e controles financeiros avançados.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    _FeatureLine(
                      icon: Icons.check_circle_outline,
                      label: 'Caixa, entradas, saídas e recebimentos incluídos',
                    ),
                    _FeatureLine(
                      icon: Icons.receipt_long_outlined,
                      label: 'Relatório financeiro avançado por período',
                    ),
                    _FeatureLine(
                      icon: Icons.tour_outlined,
                      label: 'Comissoes de guias e agentes de turismo',
                    ),
                    _FeatureLine(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Repasses, taxas e conciliação da plataforma',
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.workspace_premium_outlined),
                      label: const Text('Solicitar complemento Pro'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureLine({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
