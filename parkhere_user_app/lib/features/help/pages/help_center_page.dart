import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';

class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({super.key});

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  final _searchController = TextEditingController();
  String _query = '';
  String _audience = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final en = context.strings.isEnglish;
    final entries = _entries(en)
        .where(
          (entry) =>
              _audience == 'all' ||
              (_audience == 'customer'
                  ? entry.audience.contains(en ? 'Customer' : 'Cliente')
                  : entry.audience.contains(en ? 'Partner' : 'Parceiro')),
        )
        .where(
          (entry) =>
              entry.question.toLowerCase().contains(_query) ||
              entry.answer.toLowerCase().contains(_query) ||
              entry.category.toLowerCase().contains(_query),
        )
        .toList();
    final grouped = <String, List<_HelpEntry>>{};
    for (final entry in entries) {
      grouped.putIfAbsent(entry.category, () => []).add(entry);
    }

    return Scaffold(
      appBar: AppBar(title: Text(en ? 'Help center' : 'Central de ajuda')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.support_agent_outlined,
                        size: 34,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        en ? 'How can we help?' : 'Como podemos ajudar?',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        en
                            ? 'Find answers about reservations, payments and partner operations.'
                            : 'Encontre orientações sobre reservas, pagamentos e operação dos parceiros.',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: en ? 'Search help' : 'Buscar ajuda',
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: en ? 'Clear search' : 'Limpar busca',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'all',
                            label: Text(en ? 'Everyone' : 'Todos'),
                            icon: const Icon(Icons.groups_outlined),
                          ),
                          ButtonSegment(
                            value: 'customer',
                            label: Text(en ? 'Customer' : 'Cliente'),
                            icon: const Icon(Icons.directions_car_outlined),
                          ),
                          ButtonSegment(
                            value: 'partner',
                            label: Text(en ? 'Partner' : 'Parceiro'),
                            icon: const Icon(Icons.business_outlined),
                          ),
                        ],
                        selected: {_audience},
                        onSelectionChanged: (selection) =>
                            setState(() => _audience = selection.first),
                        showSelectedIcon: false,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    en
                        ? 'No help articles match your search.'
                        : 'Nenhum artigo corresponde à busca.',
                  ),
                ),
              for (final group in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
                  child: Text(
                    group.key,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < group.value.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        ExpansionTile(
                          title: Text(group.value[i].question),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            18,
                          ),
                          expandedCrossAxisAlignment: CrossAxisAlignment.start,
                          children: [Text(group.value[i].answer)],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                en
                    ? 'If the issue continues, contact your parking manager or ParkHere support.'
                    : 'Se o problema continuar, fale com o gestor do estacionamento ou com o suporte ParkHere.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_HelpEntry> _entries(bool en) => en
      ? const [
          _HelpEntry(
            'Reservations',
            'How do I create a reservation?',
            'Choose a parking location, spot category and plan. Review the total and terms, then start the route to create the pre-reservation.',
            'Customer',
          ),
          _HelpEntry(
            'Reservations',
            'Why did my pre-reservation expire?',
            'A pre-reservation holds a spot until its arrival deadline. After the deadline it is cancelled automatically, marked as expired and the spot is released.',
            'Customer',
          ),
          _HelpEntry(
            'Reservations',
            'Where can I find my reservation?',
            'Open Reservations from the app menu. The newest request appears first; open Details to see its status, amount and payment information.',
            'Customer',
          ),
          _HelpEntry(
            'Reservations',
            'Can I cancel a pre-reservation?',
            'You can cancel your own pre-reservation while its arrival hold is still valid and payment has not been approved. Once the hold expires, the system releases the spot automatically. A confirmed or paid reservation cannot be cancelled with this action. The refund request and review flow is not available in this version; contact the parking partner and ParkHere support for help.',
            'Customer',
          ),
          _HelpEntry(
            'Cancellation policy',
            'What are the cancellation rules?',
            'Customer: direct cancellation is available only for your unpaid pre-reservation before hold_expires_at, with no cancellation fee. After check-in, the customer cannot cancel. Paid or confirmed reservations are not cancelled through the pre-reservation button; this version does not yet process refund requests or refunds. Parking managers can cancel reservations within their own parking tenant; the API records the actor and may calculate the configured cancellation fee after the first five minutes, but that does not mean a refund or fee payment was processed. Expired holds are stored as cancelled with payment_status=expired and shown as Expired in the app.',
            'Customer and partner',
          ),
          _HelpEntry(
            'Payments',
            'Are card payments real?',
            'Card payments in the current local test environment are simulated. Do not enter real card details. The wallet stores only masked display data; real card storage must use a payment provider token.',
            'Customer',
          ),
          _HelpEntry(
            'Payments',
            'Why do I need to add my old card again?',
            'Cards saved before account sync existed were stored only on that device. For privacy, they are not copied to another account automatically. Add the masked test card again; new wallet entries sync with your account.',
            'Customer',
          ),
          _HelpEntry(
            'Check-in and checkout',
            'The camera upload failed. What should I do?',
            'Allow camera access, take clear photos of all required sides and retry on a stable connection. If the error remains, share the displayed message and reservation number with support.',
            'Customer',
          ),
          _HelpEntry(
            'Parking operations',
            'How do I update spot availability?',
            'Open the parking map and select a spot to review its status. Available spots are shown in green; a blocked spot is excluded from new reservations.',
            'Partner and operator',
          ),
          _HelpEntry(
            'Parking operations',
            'Where do I see shifts?',
            'Open My schedule to see assigned dates and hours. Managers can create, edit and cancel schedules from the scheduling screen.',
            'Partner and operator',
          ),
          _HelpEntry(
            'Tour guides',
            'What does a guide affiliation mean?',
            'A guide is an independent partner with their own services. An affiliation lets the guide refer another partner’s service under that partner’s commission terms.',
            'Partner',
          ),
          _HelpEntry(
            'Partner management',
            'How do I manage my units and services?',
            'Open My company to manage units, opening hours, spot categories, prices and services. Each active service contributes to the operator capacity; additional operators can be requested as a paid package.',
            'Partner',
          ),
          _HelpEntry(
            'Partner management',
            'How do I create an operator schedule?',
            'Open Schedules, choose the unit and period, then assign enabled operators. The system prevents overlapping shifts across units; unassigned shifts can be filled later.',
            'Partner',
          ),
          _HelpEntry(
            'Partner management',
            'How do I use the parking map?',
            'Select your unit, open a spot and review reservations, check-in and checkout actions. Operators only see units where they are enabled and scheduled.',
            'Partner and operator',
          ),
        ]
      : const [
          _HelpEntry(
            'Reservas',
            'Como criar uma reserva?',
            'Escolha um estacionamento, a categoria da vaga e o plano. Confira o total e os termos; depois inicie a rota para criar a pré-reserva.',
            'Cliente',
          ),
          _HelpEntry(
            'Reservas',
            'Por que minha pré-reserva expirou?',
            'A pré-reserva segura uma vaga até o prazo de chegada. Depois desse prazo, ela é cancelada automaticamente, marcada como expirada e a vaga é liberada.',
            'Cliente',
          ),
          _HelpEntry(
            'Reservas',
            'Onde encontro minha reserva?',
            'Abra Reservas pelo menu do app. A solicitação mais recente aparece primeiro; em Detalhes você vê status, valor e pagamento.',
            'Cliente',
          ),
          _HelpEntry(
            'Reservas',
            'Posso cancelar uma pré-reserva?',
            'Você pode cancelar a sua pré-reserva enquanto o prazo de chegada estiver válido e o pagamento não tiver sido aprovado. Quando o prazo termina, o sistema libera a vaga automaticamente. Uma reserva confirmada ou paga não pode ser cancelada por essa ação. O fluxo de solicitação e análise de reembolso ainda não está disponível nesta versão; fale com o estacionamento e o suporte ParkHere.',
            'Cliente',
          ),
          _HelpEntry(
            'Política de cancelamento',
            'Quais são as regras para cancelar?',
            'Cliente: o cancelamento direto está disponível somente para a própria pré-reserva não paga, antes de hold_expires_at, sem taxa de cancelamento. Depois do check-in, o cliente não pode cancelar. Reservas confirmadas ou pagas não são canceladas pelo botão de pré-reserva; esta versão ainda não processa solicitações nem reembolsos. Gestores podem cancelar reservas do próprio parceiro; a API registra quem cancelou e pode calcular a taxa configurada após os primeiros cinco minutos, mas isso não significa que o reembolso ou a cobrança da taxa foram processados. O prazo vencido é salvo como cancelado com payment_status=expired e aparece como Expirada no app.',
            'Cliente e parceiro',
          ),
          _HelpEntry(
            'Pagamentos',
            'Os pagamentos com cartão são reais?',
            'Os pagamentos com cartão no ambiente local de testes são simulados. Não informe dados reais. A carteira guarda apenas dados mascarados para exibição; o armazenamento real deve usar token do meio de pagamento.',
            'Cliente',
          ),
          _HelpEntry(
            'Pagamentos',
            'Por que preciso cadastrar meu cartão antigo novamente?',
            'Cartões salvos antes da sincronização da conta existiam somente naquele aparelho. Por privacidade, eles não são copiados automaticamente para outra conta. Cadastre novamente o cartão mascarado de teste; os novos registros da carteira sincronizam com sua conta.',
            'Cliente',
          ),
          _HelpEntry(
            'Check-in e checkout',
            'O envio pela câmera falhou. O que faço?',
            'Permita o acesso à câmera, tire fotos nítidas de todos os lados solicitados e tente novamente com conexão estável. Se o erro continuar, envie a mensagem exibida e o número da reserva ao suporte.',
            'Cliente',
          ),
          _HelpEntry(
            'Operação do estacionamento',
            'Como atualizo a disponibilidade das vagas?',
            'Abra o mapa de vagas e selecione uma vaga para consultar o status. Vagas disponíveis aparecem em verde; vagas bloqueadas não recebem novas reservas.',
            'Parceiro e operador',
          ),
          _HelpEntry(
            'Operação do estacionamento',
            'Onde vejo os turnos?',
            'Abra Minha escala para consultar dias e horários. Gestores podem criar, editar e cancelar escalas na tela de gestão de escalas.',
            'Parceiro e operador',
          ),
          _HelpEntry(
            'Guias turísticos',
            'O que significa uma afiliação de guia?',
            'O guia é um parceiro independente, com serviços próprios. A afiliação permite indicar serviços de outro parceiro conforme as regras de comissão definidas por esse parceiro.',
            'Parceiro',
          ),
          _HelpEntry(
            'Gestão do parceiro',
            'Como gerencio minhas unidades e serviços?',
            'Abra Minha empresa para gerenciar unidades, horários de funcionamento, categorias de vagas, preços e serviços. Cada serviço ativo compõe a capacidade de operadores; operadores adicionais podem ser solicitados em pacotes pagos.',
            'Parceiro',
          ),
          _HelpEntry(
            'Gestão do parceiro',
            'Como crio uma escala de operadores?',
            'Abra Escalas, escolha a unidade e o período e atribua os operadores habilitados. O sistema impede sobreposição de turnos entre unidades; turnos sem responsável podem ser preenchidos depois.',
            'Parceiro',
          ),
          _HelpEntry(
            'Gestão do parceiro',
            'Como uso o mapa de vagas?',
            'Selecione a unidade, abra uma vaga e consulte as ações de reservas, check-in e checkout. O operador só visualiza unidades em que está habilitado e escalado.',
            'Parceiro e operador',
          ),
        ];
}

class _HelpEntry {
  final String category;
  final String question;
  final String answer;
  final String audience;

  const _HelpEntry(this.category, this.question, this.answer, this.audience);
}
