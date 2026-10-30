"""Execute the actual window-function history SQL against synthetic observations."""

from pathlib import Path
import sqlite3
import unittest

from jinja2 import Environment, StrictUndefined


ROOT = Path(__file__).resolve().parents[1]


class ObservationHistoryTests(unittest.TestCase):
    def test_historical_intervals_are_rebuilt_from_source_months(self):
        db = sqlite3.connect(":memory:")
        try:
            db.execute("create table dim_host_base(host_id int, host_is_superhost int, source_month text)")
            # Deliberately out of order: backfills must not use insertion order.
            db.executemany("insert into dim_host_base values(?,?,?)", [
                (7, 1, "2020-07-01"), (7, 0, "2020-05-01"), (7, 1, "2020-06-01"),
            ])
            template = Environment(undefined=StrictUndefined).from_string(
                (ROOT / "dbt/models/silver/host_history.sql").read_text())
            sql = template.render(config=lambda **kwargs: "", ref=lambda name: name)
            rows = db.execute(sql).fetchall()
            self.assertEqual(rows, [
                (7, 0, "2020-05-01", "2020-06-01"),
                (7, 1, "2020-06-01", "2020-07-01"),
                (7, 1, "2020-07-01", None),
            ])
        finally:
            db.close()


if __name__ == "__main__":
    unittest.main()
