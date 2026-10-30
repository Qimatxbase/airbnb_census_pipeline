"""Raw ingestion only. Run dbt explicitly after this manual DAG succeeds."""

from datetime import datetime, timezone

from airflow import DAG
from airflow.operators.python import PythonOperator

from pipeline.ingest import load_airbnb, load_reference


with DAG(
    dag_id="airbnb_census_ingestion",
    start_date=datetime(2025, 10, 21, tzinfo=timezone.utc),
    schedule=None,
    catchup=False,
    max_active_runs=1,
    default_args={"owner": "portfolio", "retries": 0},
    tags=["academic", "airbnb", "census", "bronze"],
) as dag:
    lga_codes = PythonOperator(task_id="load_lga_codes", python_callable=load_reference,
                               op_kwargs={"kind": "lga_code"})
    suburbs = PythonOperator(task_id="load_suburbs", python_callable=load_reference,
                             op_kwargs={"kind": "lga_suburb"})
    listings = PythonOperator(task_id="load_monthly_listings", python_callable=load_airbnb)
    census_g01 = PythonOperator(task_id="load_census_g01", python_callable=load_reference,
                                op_kwargs={"kind": "census_g01"})
    census_g02 = PythonOperator(task_id="load_census_g02", python_callable=load_reference,
                                op_kwargs={"kind": "census_g02"})
    lga_codes >> suburbs >> listings >> census_g01 >> census_g02
