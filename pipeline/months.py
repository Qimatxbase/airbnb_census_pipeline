"""Derive observation months from source evidence, independently of load time."""

from __future__ import annotations

from datetime import date, datetime
import re
from pathlib import PurePosixPath
from typing import Iterable


def parse_observation_date(value: str) -> date:
    """Read explicit ISO or day-first dates; reject ambiguous US-style guesses."""
    text = str(value).strip()
    if not text:
        raise ValueError("A source observation date is required")
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00")).date()
    except ValueError:
        pass
    for pattern in ("%d/%m/%Y", "%Y/%m/%d", "%d-%m-%Y", "%Y%m%d"):
        try:
            return datetime.strptime(text, pattern).date()
        except ValueError:
            pass
    raise ValueError("Unsupported source observation date; use ISO YYYY-MM-DD")


def filename_month(object_name: str) -> date | None:
    """Recognise YYYY-MM[-DD] and MM-YYYY filenames, including underscores.

    Only the basename is examined. Date-like directory names are not evidence
    of a file's observation period. Conflicting month tokens are rejected.
    """
    name = PurePosixPath(object_name).name
    candidates = set()
    year_first = r"(?<!\d)(20\d{2})[-_](0[1-9]|1[0-2])(?!\d)"
    month_first = r"(?<!\d)(0[1-9]|1[0-2])[-_](20\d{2})(?!\d)"
    for match in re.finditer(year_first, name):
        candidates.add(date(int(match[1]), int(match[2]), 1))
    for match in re.finditer(month_first, name):
        candidates.add(date(int(match[2]), int(match[1]), 1))
    if len(candidates) > 1:
        raise ValueError("Filename contains conflicting observation months")
    return next(iter(candidates), None)


def source_month(object_name: str, observed_dates: Iterable[str] = ()) -> date:
    """Require one evidenced month, with filename/date agreement when available."""
    from_name = filename_month(object_name)
    months = set()
    for value in observed_dates:
        if value is None or not str(value).strip():
            continue
        observed = parse_observation_date(value)
        months.add(observed.replace(day=1))
    if len(months) > 1:
        raise ValueError("One input file contains multiple observation months")
    from_rows = next(iter(months), None)
    if from_name and from_rows and from_name != from_rows:
        raise ValueError("Filename month and scraped_date month disagree")
    result = from_rows or from_name
    if result is None:
        raise ValueError("No source month: provide scraped_date or a YYYY-MM filename")
    return result


def chronological_sources(object_names: Iterable[str]) -> list[str]:
    """Sort evidenced filename months, then undated files by name.

    Files without dated names are permitted because their CSV may contain
    scraped_date. The loader validates their content before any database write.
    The SQL history models determine chronology from source_month, not load order.
    """
    names = {str(n) for n in object_names if str(n).lower().endswith(".csv")
             and not PurePosixPath(str(n)).name.startswith("_")}
    return sorted(names, key=lambda n: (filename_month(n) or date.max, n))
