import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';

final partnerFeeStatementProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
      final token = ref.watch(authProvider).accessToken;
      if (token == null) throw Exception('Entre novamente.');
      return ApiService().getAuthorizedMap('/partners/fee-statement', token);
    });

class PartnerFeeStatementPage extends ConsumerWidget {
  const PartnerFeeStatementPage({super.key});

  String money(dynamic value) => 'R\$ ${(value as num).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Taxas e compensações'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(partnerFeeStatementProvider),
          ),
        ],
      ),
      body: ref
          .watch(partnerFeeStatementProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text('Não foi possível carregar o extrato: $error'),
            ),
            data: (data) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Taxas pendentes: ${money(data['pending_total'])}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Taxas recebidas em dinheiro são descontadas dos próximos repasses online. Se o repasse não cobrir tudo, o restante continua pendente.',
                ),
                const SizedBox(height: 16),
                if ((data['debts'] as List).isEmpty)
                  const Text('Nenhuma taxa de dinheiro registrada.'),
                for (final debt in data['debts'] as List)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(debt['description'] as String),
                          Text(
                            'Taxa: ${money(debt['amount'])} · Pendente: ${money(debt['remaining_amount'])}',
                          ),
                          for (final settlement
                              in (data['settlements'] as List).where(
                                (s) => s['debt_id'] == debt['id'],
                              ))
                            SelectableText(
                              'Compensado ${money(settlement['amount'])} no pagamento ${settlement['payment_id']}',
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}
