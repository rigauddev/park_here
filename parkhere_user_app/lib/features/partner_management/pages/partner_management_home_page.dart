import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/partner_profile_model.dart';
import '../providers/partner_profile_provider.dart';
import 'partner_financial_locked_page.dart';
import 'partner_parking_map_page.dart';
import 'partner_reservations_page.dart';
import 'partner_users_page.dart';
import 'parking_management_page.dart';
import 'parking_dashboard_page.dart';

class PartnerManagementHomePage extends ConsumerWidget {
  const PartnerManagementHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(partnerProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha empresa'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: () => ref.invalidate(partnerProfileProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (partner) => _PartnerManagementBody(partner: partner),
      ),
    );
  }
}

class _PartnerManagementBody extends StatelessWidget {
  final PartnerProfileModel partner;

  const _PartnerManagementBody({required this.partner});

  @override
  Widget build(BuildContext context) {
    final actions = _actionsFor(context, partner);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _PartnerHeader(partner: partner),
        const SizedBox(height: 16),
        Text(
          'Gestao disponivel',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.sizeOf(context).width >= 760 ? 3 : 1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 142,
          ),
          itemBuilder: (context, index) =>
              _ManagementActionCard(action: actions[index]),
        ),
        const SizedBox(height: 18),
        _ScopeNotice(serviceTypeLabel: partner.serviceTypeLabel),
      ],
    );
  }

  List<_ManagementAction> _actionsFor(
    BuildContext context,
    PartnerProfileModel partner,
  ) {
    switch (partner.serviceType) {
      case 'parking':
        if (partner.role == 'operator') {
          return [
            _ManagementAction(
              icon: Icons.map_outlined,
              title: 'Mapa de vagas',
              description: 'Vagas livres, pre-reservadas e ocupadas.',
              onTap: () => _open(context, const PartnerParkingMapPage()),
            ),
            _ManagementAction(
              icon: Icons.confirmation_number_outlined,
              title: 'Reservas recebidas',
              description: 'Acompanhar reservas, pagamentos e entrada.',
              onTap: () => _open(context, const PartnerReservationsPage()),
            ),
            _ManagementAction(
              icon: Icons.lock_outline,
              title: 'Financeiro Pro',
              description: 'Relatorios ficam bloqueados para o plano pago.',
              onTap: () => _open(context, const PartnerFinancialLockedPage()),
            ),
          ];
        }

        return [
          _ManagementAction(
            icon: Icons.dashboard_outlined,
            title: 'Dashboard',
            description: 'Reservas, recebimentos e ticket médio.',
            onTap: () => _open(context, const ParkingDashboardPage()),
          ),
          _ManagementAction(
            icon: Icons.local_parking,
            title: 'Estacionamento',
            description: 'Vagas, areas cobertas, tarifas e disponibilidade.',
            onTap: () => _open(context, const ParkingManagementPage()),
          ),
          _ManagementAction(
            icon: Icons.map_outlined,
            title: 'Mapa de vagas',
            description:
                'Painel visual das vagas livres, pre-reservadas e ocupadas.',
            onTap: () => _open(context, const PartnerParkingMapPage()),
          ),
          _ManagementAction(
            icon: Icons.design_services_outlined,
            title: 'Servicos cadastrados',
            description: 'Lava jato, seguro, transporte e servicos extras.',
            onTap: () => _open(context, const ParkingManagementPage()),
          ),
          _ManagementAction(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Conta de repasse',
            description: _paymentDescription(partner),
            onTap: () => _showPending(context),
          ),
          _ManagementAction(
            icon: Icons.group_outlined,
            title: 'Usuarios',
            description: 'Crie ate 2 operadores no plano atual.',
            onTap: () => _open(context, const PartnerUsersPage()),
          ),
          _ManagementAction(
            icon: Icons.lock_outline,
            title: 'Financeiro Pro',
            description:
                'Relatorios, repasses e comissoes entram no plano pago.',
            onTap: () => _open(context, const PartnerFinancialLockedPage()),
          ),
        ];
      case 'car_wash':
        return [
          _ManagementAction(
            icon: Icons.local_car_wash,
            title: 'Servicos de lavagem',
            description: 'Tipos de lavagem, precos e tempo de execucao.',
            onTap: () => _showPending(context),
          ),
          _ManagementAction(
            icon: Icons.event_available_outlined,
            title: 'Agenda',
            description: 'Horarios, fila operacional e confirmacao do servico.',
            onTap: () => _showPending(context),
          ),
          _ManagementAction(
            icon: Icons.receipt_long_outlined,
            title: 'Financeiro',
            description: 'Relatorios e repasses entram no modulo pago.',
            onTap: () => _showPending(context),
          ),
        ];
      case 'hotel':
      case 'restaurant':
        return [
          _ManagementAction(
            icon: Icons.campaign_outlined,
            title: 'Banners',
            description: 'Propagandas e ofertas exibidas no app.',
            onTap: () => _showPending(context),
          ),
          _ManagementAction(
            icon: Icons.storefront_outlined,
            title: 'Pagina do servico',
            description: 'Dados comerciais, redes sociais e contratacao.',
            onTap: () => _showPending(context),
          ),
          _ManagementAction(
            icon: Icons.receipt_long_outlined,
            title: 'Financeiro',
            description: 'Modulo adicional para campanhas e vendas.',
            onTap: () => _showPending(context),
          ),
        ];
      case 'tour_guide':
      case 'tourism_company':
        return [
          _ManagementAction(
            icon: Icons.tour_outlined,
            title: 'Pacotes',
            description: 'Roteiros, idiomas, capacidade e valores.',
            onTap: () => _showPending(context),
          ),
          _ManagementAction(
            icon: Icons.event_note_outlined,
            title: 'Agenda',
            description: 'Datas, horarios e pontos de encontro.',
            onTap: () => _showPending(context),
          ),
          _ManagementAction(
            icon: Icons.receipt_long_outlined,
            title: 'Financeiro',
            description: 'Relatorios e repasses entram no modulo pago.',
            onTap: () => _showPending(context),
          ),
        ];
      default:
        return [
          _ManagementAction(
            icon: Icons.assignment_late_outlined,
            title: 'Cadastro pendente',
            description: 'Complete o perfil da empresa para liberar a gestao.',
            onTap: () => _showPending(context),
          ),
        ];
    }
  }

  String _paymentDescription(PartnerProfileModel partner) {
    final account = partner.paymentAccount;
    if (account == null) return 'Cadastre a conta Mercado Pago do parceiro.';
    return '${account.provider}: ${account.status}';
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _showPending(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Modulo planejado no roadmap.')),
    );
  }
}

class _PartnerHeader extends StatelessWidget {
  final PartnerProfileModel partner;

  const _PartnerHeader({required this.partner});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.softCyan,
            foregroundColor: AppTheme.primary,
            child: const Icon(Icons.business_center_outlined),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partner.companyName ?? 'Empresa parceira',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${partner.serviceTypeLabel} | ${partner.approvalStatusLabel}',
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementActionCard extends StatelessWidget {
  final _ManagementAction action;

  const _ManagementActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(action.icon, color: AppTheme.secondary, size: 28),
              const Spacer(),
              Text(
                action.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                action.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScopeNotice extends StatelessWidget {
  final String serviceTypeLabel;

  const _ScopeNotice({required this.serviceTypeLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.softCyan,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Painel ativo: $serviceTypeLabel. O parceiro administra apenas a propria empresa. Taxas globais, aprovacao, vistoria e relatorios gerais ficam na gestao do admin do sistema.',
        style: const TextStyle(
          color: AppTheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ManagementAction {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ManagementAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });
}
