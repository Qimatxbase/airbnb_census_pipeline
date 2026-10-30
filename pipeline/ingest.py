"""Manually triggered ingestion using configured Airflow connections."""

from __future__ import annotations

from datetime import datetime, timezone
import io
import os

from pipeline.months import chronological_sources, parse_observation_date, source_month


AIRBNB_COLUMNS = (
    "listing_id", "scrape_id", "scraped_date", "host_id", "host_name", "host_since",
    "host_is_superhost", "host_neighbourhood", "listing_neighbourhood", "property_type",
    "room_type", "accommodates", "price", "has_availability", "availability_30",
    "number_of_reviews", "review_scores_rating", "review_scores_accuracy",
    "review_scores_cleanliness", "review_scores_checkin", "review_scores_communication",
    "review_scores_value",
)


def _hooks():
    from airflow.providers.google.cloud.hooks.gcs import GCSHook
    from airflow.providers.postgres.hooks.postgres import PostgresHook
    return (
        GCSHook(gcp_conn_id=os.environ.get("AIRBNB_GCP_CONNECTION_ID", "google_cloud_default")),
        PostgresHook(postgres_conn_id=os.environ.get("AIRBNB_POSTGRES_CONNECTION_ID", "postgres_default")),
    )


def _read_csv(gcs, object_name, *, normalize_columns=True):
    import pandas as pd
    raw = gcs.download(bucket_name=os.environ["AIRBNB_GCS_BUCKET"], object_name=object_name)
    frame = pd.read_csv(io.BytesIO(raw), dtype=str, encoding="utf-8-sig", keep_default_na=False)
    frame.columns = [c.strip().lower() if normalize_columns else c.strip() for c in frame.columns]
    return frame


def replace_source(engine, frame, table, object_name, *, dtype=None):
    """Delete and replace one source within the same transaction.

    Table names are supplied only by the fixed loader definitions below.
    A failed insert rolls back its deletion rather than losing an earlier load.
    """
    from sqlalchemy import text
    allowed = {"airbnb_raw", "census_g01_raw", "census_g02_raw", "nsw_lga_code_raw", "nsw_lga_suburb_raw"}
    if table not in allowed:
        raise ValueError("Unknown ingestion table")
    with engine.begin() as connection:
        connection.execute(text(f"DELETE FROM bronze.{table} WHERE source_file = :source"),
                           {"source": object_name})
        frame.to_sql(table, schema="bronze", con=connection, if_exists="append", index=False,
                     chunksize=1000, method="multi", dtype=dtype)


def prepare_airbnb(frame, object_name):
    """Validate observation evidence and add explicit source/load provenance."""
    missing = {"listing_id", "host_id"} - set(frame.columns)
    if missing:
        raise ValueError("Missing required Airbnb identifier columns")
    if frame.empty:
        raise ValueError("Empty Airbnb file; refusing to replace a prior load")
    frame = frame.copy()
    for identifier in ("listing_id", "host_id"):
        frame[identifier] = frame[identifier].astype(str).str.strip()
        if not frame[identifier].str.fullmatch(r"[0-9]+").all():
            raise ValueError("Airbnb identifiers must be non-empty numeric values")
    if frame["listing_id"].astype(str).str.strip().eq("").any():
        raise ValueError("Missing listing_id")
    if frame["host_id"].astype(str).str.strip().eq("").any():
        raise ValueError("Missing host_id")
    if frame["listing_id"].duplicated().any():
        raise ValueError("Duplicate listing_id in one monthly input")
    if "availability_30" in frame:
        for value in frame["availability_30"]:
            if str(value).strip() and (not str(value).strip().isdigit() or not 0 <= int(value) <= 30):
                raise ValueError("availability_30 must be blank or an integer between 0 and 30")
    dates = frame["scraped_date"] if "scraped_date" in frame else []
    month = source_month(object_name, dates)
    result = frame.reindex(columns=AIRBNB_COLUMNS, fill_value="").copy()
    result["source_month"] = month
    result["source_observed_at"] = [
        parse_observation_date(v) if str(v).strip() else month
        for v in result["scraped_date"]
    ]
    result["source_file"] = object_name
    result["loaded_at"] = datetime.now(timezone.utc)
    return result


def load_airbnb():
    gcs, postgres = _hooks()
    engine = postgres.get_sqlalchemy_engine()
    try:
        objects = gcs.list(bucket_name=os.environ["AIRBNB_GCS_BUCKET"],
                           prefix=os.environ.get("AIRBNB_GCS_PREFIX", "data/raw/")) or []
        names = chronological_sources(objects)
        if not names:
            raise ValueError("No Airbnb CSV files found under the configured prefix")
        months_seen = set()
        for object_name in names:
            frame = prepare_airbnb(_read_csv(gcs, object_name), object_name)
            month = frame["source_month"].iloc[0]
            if month in months_seen:
                raise ValueError("Multiple Airbnb input files describe the same source month")
            months_seen.add(month)
            # One source file is atomic. A later-file failure preserves completed
            # earlier files; repair the source and rerun to replace them safely.
            replace_source(engine, frame, "airbnb_raw", object_name)
    finally:
        engine.dispose()


def load_reference(kind):
    import pandas as pd
    from sqlalchemy.dialects.postgresql import JSONB
    definitions = {
        "lga_code": ("LGA_CODE_OBJECT", "data/mapping/NSW_LGA_CODE.csv", "nsw_lga_code_raw"),
        "lga_suburb": ("LGA_SUBURB_OBJECT", "data/mapping/NSW_LGA_SUBURB.csv", "nsw_lga_suburb_raw"),
        "census_g01": ("CENSUS_G01_OBJECT", "data/census/2016Census_G01_NSW_LGA.csv", "census_g01_raw"),
        "census_g02": ("CENSUS_G02_OBJECT", "data/census/2016Census_G02_NSW_LGA.csv", "census_g02_raw"),
    }
    env_name, default_object, table = definitions[kind]
    object_name = os.environ.get(env_name, default_object)
    gcs, postgres = _hooks()
    engine = postgres.get_sqlalchemy_engine()
    try:
        frame = _read_csv(gcs, object_name, normalize_columns=not kind.startswith("census"))
        if frame.empty:
            raise ValueError("Empty reference file; refusing to replace a prior load")
        dtype = None
        if kind.startswith("census"):
            columns = {name.lower(): name for name in frame.columns}
            if "lga_code_2016" not in columns:
                raise ValueError("Census file requires LGA_CODE_2016")
            result = pd.DataFrame({"lga_code": frame[columns["lga_code_2016"]],
                                   "payload": frame.to_dict(orient="records")})
            dtype = {"payload": JSONB()}
        elif kind == "lga_code":
            result = frame[["lga_code", "lga_name"]].copy()
        else:
            result = frame[["lga_name", "suburb_name"]].copy()
        result["source_file"] = object_name
        result["loaded_at"] = datetime.now(timezone.utc)
        replace_source(engine, result, table, object_name, dtype=dtype)
    finally:
        engine.dispose()
