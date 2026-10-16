"""Partner capabilities and quantity-based add-ons exposed in Minha empresa.

Operator seat packages keep their existing request and approval workflow.
"""

PARTNER_FEATURE_CATALOG = (
    {
        'key': 'dashboard',
        'name': 'Dashboard',
        'name_en': 'Dashboard',
        'description': 'Visão operacional do parceiro.',
        'description_en': 'Partner operating overview.',
        'service_types': ('parking', 'tour_guide'),
        'default_is_enabled': True,
        'default_is_paid': False,
        'default_billing_period': 'monthly',
        'requestable': True,
    },
    {
        'key': 'parking_management',
        'name': 'Gestão de estacionamentos',
        'name_en': 'Parking management',
        'description': 'Cadastro e gestão das unidades do parceiro.',
        'description_en': 'Register and manage partner parking units.',
        'service_types': ('parking',),
        'default_is_enabled': True,
        'default_is_paid': False,
        'default_billing_period': 'monthly',
        'requestable': True,
    },
    {
        'key': 'parking_operations',
        'name': 'Mapa e reservas',
        'name_en': 'Parking map and reservations',
        'description': 'Mapa de vagas e reservas recebidas.',
        'description_en': 'Parking spot map and received reservations.',
        'service_types': ('parking',),
        'default_is_enabled': True,
        'default_is_paid': False,
        'default_billing_period': 'monthly',
        'requestable': True,
    },
    {
        'key': 'services_management',
        'name': 'Serviços cadastrados',
        'name_en': 'Registered services',
        'description': 'Gestão dos serviços oferecidos pelo parceiro.',
        'description_en': 'Manage services offered by the partner.',
        'service_types': ('parking', 'tour_guide'),
        'default_is_enabled': True,
        'default_is_paid': False,
        'default_billing_period': 'monthly',
        'requestable': True,
    },
    {
        'key': 'convenience_management',
        'name': 'Conveniências',
        'name_en': 'Convenience products',
        'description': 'Cadastro de produtos e serviços extras da unidade.',
        'description_en': 'Register products and extra services for each unit.',
        'service_types': ('parking',),
        'default_is_enabled': False,
        'default_is_paid': True,
        'default_billing_period': 'monthly',
        'requestable': True,
    },
    {
        'key': 'additional_services',
        'name': 'Serviços adicionais',
        'name_en': 'Additional services',
        'description': 'Cadastro de serviços extras; o primeiro serviço é incluído.',
        'description_en': 'Extra service slots; the first service is included.',
        'service_types': ('parking', 'tour_guide'),
        'default_is_enabled': True,
        'default_is_paid': True,
        'default_billing_period': 'one_time',
        'requestable': True,
        'quantity_based': True,
    },
    {
        'key': 'team_management',
        'name': 'Gestão de usuários',
        'name_en': 'Team management',
        'description': 'Cadastro e gestão dos operadores do parceiro.',
        'description_en': 'Register and manage partner operators.',
        'service_types': ('parking',),
        'default_is_enabled': True,
        'default_is_paid': False,
        'default_billing_period': 'monthly',
        'requestable': True,
    },
    {
        'key': 'guide_affiliations',
        'name': 'Afiliações e indicações',
        'name_en': 'Affiliations and referrals',
        'description': 'Afiliação de guias e gestão das indicações.',
        'description_en': 'Guide affiliations and referral management.',
        'service_types': ('parking', 'tour_guide'),
        'default_is_enabled': True,
        'default_is_paid': False,
        'default_billing_period': 'monthly',
        'requestable': True,
    },
    {
        'key': 'additional_units',
        'name': 'Unidades adicionais',
        'name_en': 'Additional units',
        'description': 'Unidades além da primeira, com dois operadores incluídos por unidade.',
        'description_en': 'Units beyond the first; two operators are included per unit.',
        'service_types': ('parking',),
        'default_is_enabled': True,
        'default_is_paid': True,
        'default_billing_period': 'one_time',
        'requestable': True,
        'quantity_based': True,
    },
    {
        'key': 'cash_management_basic',
        'name': 'Caixa e movimentações básico',
        'name_en': 'Basic cash management',
        'description': 'Caixa diário, entradas, saídas e fechamento operacional.',
        'description_en': 'Daily cash, inflows, outflows and shift closing.',
        'service_types': ('parking',),
        'default_is_enabled': True,
        'default_is_paid': False,
        'default_billing_period': 'monthly',
        'requestable': True,
    },
    {
        'key': 'financial_management',
        'name': 'Caixa e movimentações Pro',
        'name_en': 'Finance Pro',
        'description': (
            'Relatórios detalhados por período, recebimentos e taxas administrativas.'
        ),
        'description_en': (
            'Detailed period reports for reservations, receipts and administrative fees.'
        ),
        'service_types': ('parking',),
        'default_is_enabled': False,
        'default_is_paid': True,
        'default_billing_period': 'monthly',
        'requestable': True,
    },
)


def features_for_service_type(service_type: str | None) -> tuple[dict, ...]:
    """Return only add-ons currently backed by the partner's service module."""
    return tuple(
        feature
        for feature in PARTNER_FEATURE_CATALOG
        if service_type in feature['service_types']
    )


def feature_by_key(service_type: str | None, key: str) -> dict | None:
    return next(
        (feature for feature in features_for_service_type(service_type) if feature['key'] == key),
        None,
    )
