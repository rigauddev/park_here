import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class PartnerFinancialLockedPage extends StatelessWidget {
  const PartnerFinancialLockedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Financeiro')),
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
                      'Modulo financeiro Pro',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Relatorios de repasse, comissoes de guias, conciliacao e indicadores financeiros entram no plano pago.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    _FeatureLine(
                      icon: Icons.receipt_long_outlined,
                      label: 'Relatorio financeiro por periodo',
                    ),
                    _FeatureLine(
                      icon: Icons.tour_outlined,
                      label: 'Comissoes de guias e agentes de turismo',
                    ),
                    _FeatureLine(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Repasses e taxas da plataforma',
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.workspace_premium_outlined),
                      label: const Text('Disponivel no plano Pro'),
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
