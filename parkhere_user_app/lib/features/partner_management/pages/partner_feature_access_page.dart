import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/partner_profile_model.dart';

class PartnerFeatureAccessPage extends ConsumerStatefulWidget {
  final PartnerProfileModel partner;
  final String featureKey;
  final int requestedQuantity;

  const PartnerFeatureAccessPage({
    super.key,
    required this.partner,
    required this.featureKey,
    this.requestedQuantity = 1,
  });

  @override
  ConsumerState<PartnerFeatureAccessPage> createState() =>
      _PartnerFeatureAccessPageState();
}

class _PartnerFeatureAccessPageState
    extends ConsumerState<PartnerFeatureAccessPage> {
  final _api = ApiService();
  late int _quantity;
  bool _submitting = false;
  bool _paymentCompleted = false;
  String? _message;
  String _billingPeriod = 'monthly';
  String _paymentMethod = 'direct_debit';
  double? _requestTotal;

  @override
  void initState() {
    super.initState();
    _quantity = widget.requestedQuantity.clamp(1, 100);
    final configured = widget.partner.featureDetails(widget.featureKey) ?? {};
    final configuredPeriod = configured['billing_period'] as String?;
    _billingPeriod = configuredPeriod == 'annual' ? 'annual' : 'monthly';
    _loadRequestStatus();
  }

  Future<void> _loadRequestStatus() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    try {
      final requests = await _api.getAuthorized(
        '/partners/feature-requests',
        token,
      );
      final request = requests
          .cast<Map<String, dynamic>>()
          .where(
            (row) =>
                row['feature_key'] == widget.featureKey &&
                (row['status'] == 'pending_review' ||
                    row['status'] == 'pending_payment'),
          )
          .firstOrNull;
      if (mounted) {
        setState(() {
          _paymentCompleted =
              request?['status'] == 'payment_received' ||
              request?['status'] == 'pending_review';
          if (request != null) {
            _billingPeriod =
                request['billing_period'] as String? ?? _billingPeriod;
            _paymentMethod =
                request['payment_method'] as String? ?? _paymentMethod;
            _requestTotal = (request['total_price'] as num?)?.toDouble();
          }
        });
      }
    } catch (_) {
      // The access summary remains usable if request history cannot be fetched.
    }
  }

  @override
  Widget build(BuildContext context) {
    final en = context.strings.isEnglish;
    final feature = widget.partner.featureDetails(widget.featureKey) ?? {};
    final paid = feature['is_paid'] == true;
    final prices = (feature['billing_prices'] as Map<String, dynamic>?) ?? {};
    final legacyPrice = (feature['price'] as num?)?.toDouble() ?? 0;
    final price =
        (prices[_billingPeriod] as num?)?.toDouble() ??
        ((feature['billing_period'] == _billingPeriod) ? legacyPrice : 0);
    final quantityBased = feature['quantity_based'] == true;
    final canRequest = widget.partner.role != 'operator';
    final resourceRequestsEnabled =
        !quantityBased || feature['is_enabled'] == true;
    final period = switch (_billingPeriod) {
      'annual' => en ? 'year' : 'ano',
      _ => en ? 'month' : 'mês',
    };
    final rawTerms = (feature['payment_terms'] as Map<String, dynamic>?) ?? {};
    final terms =
        (rawTerms[_billingPeriod] as Map<String, dynamic>?) ??
        <String, dynamic>{
          'minimum_months': _billingPeriod == 'monthly' ? 6 : 12,
          'installments': 1,
          'discounts': <String, dynamic>{},
        };
    final minMonths =
        (terms['minimum_months'] as num?)?.toInt() ??
        (_billingPeriod == 'monthly' ? 6 : 12);
    final installments = (terms['installments'] as num?)?.toInt() ?? 1;
    final discount =
        ((terms['discounts'] as Map<String, dynamic>?)?[_paymentMethod] as num?)
            ?.toDouble() ??
        0;
    final name = en
        ? (feature['name_en'] as String? ?? widget.featureKey)
        : (feature['name'] as String? ?? widget.featureKey);
    final description = en
        ? (feature['description_en'] as String? ?? '')
        : (feature['description'] as String? ?? '');
    return Scaffold(
      appBar: AppBar(
        title: Text(en ? 'Feature access' : 'Acesso à funcionalidade'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            shrinkWrap: true,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_outline, size: 36),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(description),
                      const SizedBox(height: 16),
                      ..._benefits(en, widget.featureKey).map(
                        (benefit) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle_outline, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(benefit)),
                            ],
                          ),
                        ),
                      ),
                      if (quantityBased) ...[
                        const SizedBox(height: 18),
                        Text(
                          en ? 'Additional quantity' : 'Quantidade adicional',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text(
                              '$_quantity',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            IconButton(
                              onPressed: _quantity < 100
                                  ? () => setState(() => _quantity++)
                                  : null,
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      if (widget.featureKey == 'additional_units')
                        Text(
                          en
                              ? 'Monthly recurring charge'
                              : 'Cobrança mensal recorrente',
                          style: Theme.of(context).textTheme.titleSmall,
                        )
                      else
                        DropdownButtonFormField<String>(
                          initialValue: _billingPeriod,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: en
                                ? 'Billing option'
                                : 'Modalidade de cobrança',
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'monthly',
                              child: Text(
                                en ? 'Monthly recurring' : 'Mensal recorrente',
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'annual',
                              child: Text(en ? 'Annual' : 'Anual'),
                            ),
                          ],
                          onChanged: (value) => setState(
                            () => _billingPeriod = value ?? 'monthly',
                          ),
                        ),
                      const SizedBox(height: 14),
                      // Seção de Teste Grátis de 30 Dias
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.stars, color: Colors.amber, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'Teste Grátis por 30 Dias',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Experimente todas as vantagens desta funcionalidade sem custo imediato durante 30 dias.',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade900),
                              onPressed: _submitting ? null : () => _activateDirectly('trial'),
                              icon: const Icon(Icons.timer_outlined, size: 16),
                              label: const Text('Iniciar Teste Grátis de 30 Dias'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        en ? 'Payment method' : 'Forma de Pagamento / Cobrança',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Débito Automático via Reservas'),
                            selected: _paymentMethod == 'direct_debit',
                            avatar: const Icon(Icons.sync_alt, size: 16),
                            onSelected: (_) => setState(() => _paymentMethod = 'direct_debit'),
                          ),
                          ChoiceChip(
                            label: const Text('PIX'),
                            selected: _paymentMethod == 'pix',
                            avatar: const Icon(Icons.pix, size: 16),
                            onSelected: (_) => setState(() => _paymentMethod = 'pix'),
                          ),
                          ChoiceChip(
                            label: const Text('Cartão de Crédito'),
                            selected: _paymentMethod == 'credit_card',
                            avatar: const Icon(Icons.credit_card, size: 16),
                            onSelected: (_) => setState(() => _paymentMethod = 'credit_card'),
                          ),
                          ChoiceChip(
                            label: const Text('Cartão de Débito'),
                            selected: _paymentMethod == 'debit_card',
                            avatar: const Icon(Icons.credit_card_outlined, size: 16),
                            onSelected: (_) => setState(() => _paymentMethod = 'debit_card'),
                          ),
                        ],
                      ),
                      if (_paymentMethod == 'direct_debit')
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, size: 18, color: Colors.blue),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Débito Automático: O valor da mensalidade da funcionalidade é guardado como débito. Ao ter uma reserva que cubra o valor do débito do estabelecimento, esse valor é cobrado nessa reserva e fica registrado como saída sobre o valor da mensalidade da funcionalidade.',
                                  style: TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Divider(height: 28),
                      Text(
                        paid
                            ? 'R\$ ${(_requestTotal ?? _requestAmount()).toStringAsFixed(2)} / $period'
                            : (en
                                  ? 'Access currently locked'
                                  : 'Acesso bloqueado no momento'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (paid) ...[
                        const SizedBox(height: 6),
                        Text(
                          en
                              ? 'Minimum commitment: $minMonths months · up to $installments installment(s) · ${discount.toStringAsFixed(0)}% discount for this method.'
                              : 'Contratação: $minMonths meses · até $installments parcela(s) · desconto de ${discount.toStringAsFixed(0)}% neste meio.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (widget.featureKey == 'additional_services') ...[
                        const SizedBox(height: 8),
                        Text(
                          en
                              ? 'One service is included. Each additional slot requires approval.'
                              : 'O primeiro serviço está incluído. Cada vaga adicional depende de aprovação.',
                        ),
                      ],
                      if (widget.featureKey == 'additional_units') ...[
                        const SizedBox(height: 8),
                        Text(
                          en
                              ? 'The first location is included. Each extra location includes two operator seats.'
                              : 'A primeira unidade está incluída. Cada unidade extra inclui duas vagas de operador.',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(_message!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue.shade900,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _submitting ? null : () => _activateDirectly(_paymentMethod),
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _submitting
                      ? (en ? 'Activating feature…' : 'Ativando funcionalidade…')
                      : (en ? 'Activate and Unlock Feature' : 'Contratar e Ativar Funcionalidade'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (!paid ||
                  price <= 0 ||
                  !resourceRequestsEnabled ||
                  !canRequest)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    en
                        ? (!canRequest
                              ? 'Only the partner manager can request this feature.'
                              : !resourceRequestsEnabled
                              ? 'System management has paused new quantity requests for this feature.'
                              : 'This feature is not configured as a paid add-on with a price yet. Contact system management.')
                        : (!canRequest
                              ? 'Somente o gestor do parceiro pode solicitar esta funcionalidade.'
                              : !resourceRequestsEnabled
                              ? 'A gestão do sistema pausou novas solicitações de quantidade para este recurso.'
                              : 'Esta funcionalidade ainda não está configurada como paga com valor. Procure a gestão do sistema.'),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                en
                    ? (_paymentCompleted
                          ? 'Payment registered. Attach the proof so ParkHere management can review and activate the feature.'
                          : 'Complete payment before attaching proof.')
                    : (_paymentCompleted
                          ? 'Pagamento registrado. Anexe o comprovante para a gestão ParkHere analisar e liberar a funcionalidade.'
                          : 'Conclua o pagamento antes de anexar o comprovante.'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _activateDirectly(String modality) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    setState(() => _submitting = true);
    try {
      final res = await _api.postAuthorized(
        '/partners/features/${widget.featureKey}/activate',
        {
          'modality': modality,
          'billing_period': _billingPeriod,
        },
        token,
      );

      if (!mounted) return;
      setState(() => _submitting = false);

      // Dialog de reinicialização e logout
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.restart_alt, size: 48, color: Colors.blue),
          title: const Text('Reinicialização Necessária'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                res['message'] as String? ?? 'Funcionalidade ativada com sucesso!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'O sistema precisa ser reiniciado para que todas as novas opções, permissões e menus sejam liberados no seu aplicativo.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Ao clicar em Confirmar, você será desconectado e os dados em cache serão limpos para refazer o login já com a funcionalidade liberada.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Confirmar e Reiniciar'),
              onPressed: () async {
                await LocalStorageService().clear();
                await ref.read(authProvider.notifier).logout();
                if (!ctx.mounted) return;
                Navigator.of(ctx).pushNamedAndRemoveUntil('/login', (route) => false);
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao ativar funcionalidade: $e')),
        );
      }
    }
  }

  double _requestAmount() {
    final feature = widget.partner.featureDetails(widget.featureKey) ?? {};
    final prices = (feature['billing_prices'] as Map<String, dynamic>?) ?? {};
    final legacy = (feature['price'] as num?)?.toDouble() ?? 0;
    final unit = (prices[_billingPeriod] as num?)?.toDouble() ?? legacy;
    final quantity = feature['quantity_based'] == true ? _quantity : 1;
    final months = _billingPeriod == 'monthly' ? 6 : 1;
    return unit * quantity * months;
  }

  List<String> _benefits(bool en, String key) {
    final values = switch (key) {
      'financial_management' => en
          ? [
              'Complete financial dashboard with custom calendar filter',
              'Cost centers management (Revenue, Expense, Mixed)',
              'Manual income and expense entries with payment method tracking',
              'Segregated revenue streams: Parking vs Convenience Store',
              'Reconciliation and net earnings real-time calculation',
            ]
          : [
              'Painel financeiro profissional com filtro por calendário e mês atual',
              'Gestão de Centros de Custo (Receitas, Despesas e Mistos)',
              'Lançamentos manuais de caixa com categoria e forma de pagamento',
              'Separação clara entre receitas de estacionamento e loja de conveniência',
              'Conciliação em tempo real e cálculo de lucro líquido real',
            ],
      'convenience_management' || 'convenience_store' => en
          ? [
              'Complete POS counter with barcode camera scanner',
              'Cash bleed / withdrawal (Sangria) with manager receipt',
              'Stock control, inventory alerts, and shift closing reports',
              'Discount limits, cancellation security and non-fiscal customer receipt',
            ]
          : [
              'Frente de caixa (PDV) moderna com leitor de código de barras por câmera',
              'Sangria de caixa com emissão de comprovante e identificação de responsável',
              'Controle de estoque, alerta de reposição e relatório de fechamento de turno',
              'Descontos controlados, cancelamento seguro e cupom não fiscal com CPF',
            ],
      'team_management' => en
          ? [
              'Granular permissions matrix for operators and managers',
              'Turn control, separate cash drawers for parking and store',
              'Audit log of all actions by operator',
            ]
          : [
              'Matriz granular de permissões para operadores e gestores',
              'Controle de turnos e abertura de caixas de estacionamento e conveniência',
              'Auditoria completa de operações por operador',
            ],
      'additional_units' =>
        en
            ? [
                'Centralized management for every branch',
                'Separate services and teams by unit',
                'Combined and individual financial reports',
                'Consistent fee rules applied across all branches',
              ]
            : [
                'Gestão centralizada de todas as filiais',
                'Serviços e equipes separados por unidade',
                'Relatórios financeiros consolidados e individuais',
                'Taxas padronizadas aplicadas igualmente a todas as filiais',
              ],
      'additional_services' => en
          ? [
              'Offer extra services (Car wash, valet, detailing, oil check)',
              'Automatic calculation of extra service fees',
              'Integrated billing on checkout',
            ]
          : [
              'Oferta de serviços extras (Lava-jato, valet, estética automotiva)',
              'Cálculo e cobrança automática de taxas sobre serviços extras',
              'Faturamento integrado no checkout do cliente',
            ],
      _ =>
        en
            ? [
                'Unlock the complete workflow for your partner',
                'Secure data and role-based access',
                'Support for future improvements',
              ]
            : [
                'Libere o fluxo completo para seu parceiro',
                'Dados seguros e acesso por perfil',
                'Suporte para futuras melhorias',
              ],
    };
    return values;
  }
}
