import unittest
from datetime import date

from pipeline.months import chronological_sources, filename_month, source_month


class SourceMonthTests(unittest.TestCase):
    def test_historical_file_is_not_dated_at_reload_time(self):
        self.assertEqual(source_month("data/raw/05_2020.csv", ["2020-05-17"]), date(2020, 5, 1))
        self.assertEqual(source_month("data/raw/listings_2021-04-07.csv"), date(2021, 4, 1))

    def test_sources_sort_by_observation_month_not_lexically(self):
        names = ["12_2020.csv", "04_2021.csv", "05_2020.csv", "_ignore.csv", "notes.txt"]
        self.assertEqual(chronological_sources(names), ["05_2020.csv", "12_2020.csv", "04_2021.csv"])

    def test_conflicting_filename_and_rows_fail(self):
        with self.assertRaisesRegex(ValueError, "disagree"):
            source_month("2020-05.csv", ["2021-04-01"])
        with self.assertRaisesRegex(ValueError, "multiple"):
            source_month("listings.csv", ["2020-05-01", "2020-06-01"])

    def test_missing_and_ambiguous_evidence_fail(self):
        with self.assertRaises(ValueError):
            source_month("listings.csv")
        with self.assertRaises(ValueError):
            filename_month("2020-05_to_2021-04.csv")
        self.assertIsNone(filename_month("2026-10/listings.csv"))

    def test_scrape_dates_are_allowed_without_dated_filename(self):
        self.assertEqual(source_month("listings.csv", ["17/05/2020", "2020-05-18"]), date(2020, 5, 1))
        with self.assertRaises(ValueError):
            source_month("2020-05.csv", ["not-a-date"])


if __name__ == "__main__":
    unittest.main()
