"""Partner add-ons that have a working app surface and data source.

Capacity limits (units/operators/services) are managed by their own quota
workflows and must not be duplicated as feature entitlements here.
"""

PARTNER_FEATURE_CATALOG = (
    {
        'key': 'financial_management',
        'name': 'Financeiro Pro',
        'name_en': 'Finance Pro',
        'description': (
            'Relatórios por período de reservas, recebimentos e taxas '
            'administrativas do estacionamento.'
        ),
        'description_en': (
            'Period reports for parking reservations, received payments and '
            'administrative fees.'
        ),
        'service_types': ('parking',),
    },
)


def features_for_service_type(service_type: str | None) -> tuple[dict, ...]:
    """Return only add-ons currently backed by the partner's service module."""
    return tuple(
        feature
        for feature in PARTNER_FEATURE_CATALOG
        if service_type in feature['service_types']
    )
