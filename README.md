# Airbnb and Census Analytics Pipeline

An academic data engineering and socioeconomic analysis project by Khanh Hoang
Nguyen, originally submitted for UTS Big Data Engineering Assessment 3 in
October 2025. This cleaned portfolio version preserves the original layered SQL
and business questions while correcting source-date handling and history joins.

The intended inputs combine monthly Airbnb listing observations from May 2020
to April 2021, 2016 Australian Census G01/G02 tables and NSW LGA/suburb mappings.
No input data, private configurations, credentials, assessment PDFs or saved
business results are included.

## What the code does

- A **manually triggered Airflow DAG** loads files from Google Cloud Storage
  into PostgreSQL raw tables. It does not invoke dbt or run on a recurring schedule.
- Source filenames and `scraped_date` determine the observation month.
  `loaded_at` records ingestion time separately. Conflicting dates, repeated
  listing IDs and invalid 30-day availability values are rejected.
- Each input file is replaced in one database transaction, supporting safe
  reruns. The whole multi-file DAG is not a single transaction.
- Eighteen dbt SQL models cover raw views, cleaned dimensions, source-month
  history and reporting marts for listing neighbourhoods, property types and
  host neighbourhoods.
- Five analytical SQL queries compare regional estimated revenue, demographics,
  property configurations, host concentration and median mortgage repayments.

The project demonstrates SQL joins, window functions, data preparation,
multi-source integration and repeatable reporting. It is a portfolio version of
coursework; no commercial deployment or business impact is asserted.

## Source-date and history semantics

`source_month` comes from the file's observation dates or an explicit dated
basename such as `05_2020.csv` or `listings_2021-04-07.csv`. When both are present,
they must agree. Each file must describe one month; a unique database constraint
prevents duplicate observations for the same listing and month. Undated filenames
are accepted only when their rows provide valid `scraped_date` values.

`host_history` and `property_history` rebuild half-open monthly intervals
`[valid_from, valid_to)` from the source history with SQL `lead()`. They are
**monthly observation histories**, rather than exact change timestamps or dbt
snapshot executions. Unchanged attributes may appear in consecutive intervals.
The last observation remains open until a later observation is supplied.

The original submission used load timestamps for monthly grouping and dbt
snapshots. That could date historical backfills at ingestion time. This version
keeps source chronology separate and joins the reporting marts to the source
month. Original analytical findings have not been reproduced with this version.

## Setup

Use Python 3.11 in a virtual environment:

```bash
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt -r requirements-test.txt
cp .env.example .env
```

Set the values in your private `.env`, then export them in the processes running
Airflow and dbt. `.env` is a convenience template; the code does not load it
automatically. Store cloud/database credentials in Airflow Connections or a
secrets backend. No connection passwords belong in the DAG.

Install the Airflow dependencies into an Airflow 2.8+ environment using the
constraints file matching that Airflow/Python version. For a new environment,
resolve `requirements.txt` and `requirements-airflow.txt` together under those
constraints. Airflow and dbt may use separate environments if their dependency
constraints differ.

## Run the workflow

1. Create a dedicated PostgreSQL database and run
   `sql/create_raw_tables.sql` with your configured database client. The DDL
   targets a fresh schema; it does not migrate an existing assignment database.
2. Upload your authorised source CSVs to GCS. Put only monthly listing CSVs under
   `AIRBNB_GCS_PREFIX`; configure the reference object names from `.env.example`.
   The listing loader expects `listing_id` and `host_id`; optional listing
   fields follow `AIRBNB_COLUMNS` in `pipeline/ingest.py`.
3. Configure the Airflow Google and PostgreSQL connections using the IDs from
   the environment. Make this project root importable on Airflow workers
   (`PYTHONPATH=/absolute/path/to/airbnb_census_pipeline`) and place
   `dags/airbnb_census_ingestion.py` in the Airflow DAG folder. Trigger
   `airbnb_census_ingestion` manually and confirm all five tasks succeed.
4. Copy `dbt/profiles.example.yml` to a private profile directory as
   `profiles.yml`, then run:

   ```bash
   dbt debug --project-dir dbt --profiles-dir /path/to/private/profile
   dbt build --project-dir dbt --profiles-dir /path/to/private/profile
   ```

5. Execute `sql/business_analysis.sql` against the same database to inspect the
   five reporting questions. dbt uses the explicit schemas `bronze_views`,
   `silver` and `gold`; use a dedicated database to avoid schema collisions.

If two differently named files describe the same month, correct the source set
before loading. Replacing a filename is not an automatic deletion of a different
source filename. Source-file replacements are atomic; previously completed files
remain committed if a later file fails.

## Analytical limits

- Estimated stays use `30 - availability_30`; estimated revenue multiplies that
  proxy by the advertised price. Unavailability is not a verified booking, and
  the resulting measure is not actual revenue or profit. Missing availability
  remains unknown rather than becoming a fully booked month.
- Census measures are from 2016 while listing observations are from 2020–2021.
  Regional correlations describe associations, with a material time mismatch.
- Suburb names can be ambiguous. The inherited deterministic mapping selects
  one LGA for duplicate names; it should be reconciled with authoritative
  geographic identifiers before operational use.
- Questions A/B join listing geography by source month. Questions C–E retain
  the assignment's latest-observed geography/configuration summaries; these
  do not reconstruct every historical property configuration.
- Price cleaning, snapshot sampling and neighbourhood joins require validation
  against the supplied data. The cleaned pipeline has not been run against
  the original cloud services or full datasets.

## Verification

```bash
python -m unittest discover -s tests -v
dbt parse --project-dir dbt --profiles-dir /path/to/private/profile
```

The focused Python tests cover source-date conflicts, chronology, backfilled
monthly ingestion, duplicate identifiers, invalid availability and execution of
the actual history SQL against synthetic in-memory observations. Parsing checks
can validate dbt references and SQL structure without a warehouse connection.
Database data tests require `dbt build` against your configured inputs.

[Source mapping and corrections](docs/source_mapping.md) records which assessment
files this version derives from and how its behaviour differs.
