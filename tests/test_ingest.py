import unittest
from datetime import date

import pandas as pd

from pipeline.ingest import prepare_airbnb


class MonthlyIngestionTests(unittest.TestCase):
    def test_backfill_keeps_observation_month_separate_from_load_time(self):
        frame = pd.DataFrame({"listing_id": ["101"], "host_id": ["7"],
                              "scraped_date": ["2020-05-17"], "availability_30": ["12"]})
        output = prepare_airbnb(frame, "listings_2020-05.csv")
        self.assertEqual(output.loc[0, "source_month"], date(2020, 5, 1))
        self.assertEqual(output.loc[0, "source_observed_at"], date(2020, 5, 17))
        self.assertGreater(output.loc[0, "loaded_at"].year, 2020)

    def test_filename_provides_explicit_fallback_for_missing_scraped_date(self):
        frame = pd.DataFrame({"listing_id": ["101"], "host_id": ["7"]})
        output = prepare_airbnb(frame, "04_2021.csv")
        self.assertEqual(output.loc[0, "source_observed_at"], date(2021, 4, 1))

    def test_identifier_duplicates_fail_after_whitespace_normalisation(self):
        frame = pd.DataFrame({"listing_id": ["101", " 101 "], "host_id": ["7", "7"]})
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            prepare_airbnb(frame, "2020-05.csv")

    def test_invalid_availability_cannot_create_negative_or_excess_stay_estimates(self):
        for value in ("31", "-1", "unknown"):
            frame = pd.DataFrame({"listing_id": ["101"], "host_id": ["7"], "availability_30": [value]})
            with self.assertRaisesRegex(ValueError, "availability"):
                prepare_airbnb(frame, "2020-05.csv")


if __name__ == "__main__":
    unittest.main()
