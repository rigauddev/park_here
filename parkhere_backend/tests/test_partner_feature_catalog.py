import unittest

from app.modules.platform_fees.feature_catalog import features_for_service_type


class PartnerFeatureCatalogTests(unittest.TestCase):
    def test_parking_catalog_covers_current_company_actions(self):
        keys = {feature['key'] for feature in features_for_service_type('parking')}
        self.assertEqual(
            keys,
            {
                'dashboard',
                'parking_management',
                'parking_operations',
                'services_management',
                'additional_services',
                'team_management',
                'guide_affiliations',
                'additional_units',
                'cash_management_basic',
                'financial_management',
            },
        )

    def test_guide_has_own_services_and_affiliate_capabilities(self):
        features = features_for_service_type('tour_guide')
        keys = {feature['key'] for feature in features}
        self.assertEqual(
            keys,
            {'dashboard', 'services_management', 'additional_services', 'guide_affiliations'},
        )
        self.assertTrue(all(feature['name'] and feature['name_en'] for feature in features))

    def test_first_service_and_unit_are_included_and_extras_are_quantity_based(self):
        catalog = {
            feature['key']: feature
            for feature in features_for_service_type('parking')
        }
        for key in ('additional_services', 'additional_units'):
            self.assertTrue(catalog[key]['default_is_paid'])
            self.assertTrue(catalog[key]['requestable'])
            self.assertTrue(catalog[key]['quantity_based'])
            self.assertEqual(catalog[key]['default_billing_period'], 'one_time')
        self.assertFalse(catalog['cash_management_basic']['default_is_paid'])
        self.assertFalse(catalog['financial_management']['default_is_enabled'])


if __name__ == '__main__':
    unittest.main()
