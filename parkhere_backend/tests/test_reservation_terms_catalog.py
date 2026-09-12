import unittest

from app.modules.reservations.terms_catalog import (
    TERMS_VERSION,
    build_terms_snapshot,
)


class ReservationTermsCatalogTests(unittest.TestCase):
    def test_snapshot_contains_platform_and_selected_services_in_portuguese(self):
        snapshot = build_terms_snapshot(
            ["car_wash", "tour_guide", "car_wash"], "pt_BR"
        )

        self.assertEqual(
            [entry["service_type"] for entry in snapshot],
            ["platform", "parking", "car_wash", "tourism"],
        )
        self.assertTrue(all(entry["version"] == TERMS_VERSION for entry in snapshot))
        self.assertIn("estabelecimento", snapshot[1]["text"])

    def test_snapshot_localizes_service_terms_to_english(self):
        snapshot = build_terms_snapshot(
            ["hotel", "restaurant", "transport"], "en"
        )

        self.assertEqual(
            [entry["service_type"] for entry in snapshot],
            ["platform", "parking", "hotel", "restaurant", "transport"],
        )
        self.assertTrue(all(entry["text"] and "Revisei" not in entry["text"] for entry in snapshot))


if __name__ == "__main__":
    unittest.main()
