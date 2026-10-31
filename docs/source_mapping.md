# Source mapping and portfolio corrections

The source is Khanh Hoang Nguyen's individual UTS Big Data Engineering
Assessment 3, dated 22 October 2025. It is stored locally beneath
`Subject /Big Data Engineering/As3_NguyenKhanhHoang/` (the `Subject ` directory
has a trailing space). The source directory was read only during this extraction.
The submitted report identifies Airbnb/Census data integration and socioeconomic
business analysis as the assessment topic. It is coursework, not employment.

Only code needed for this standalone version was copied or adapted. No PDFs,
raw data, host records, original cloud configuration or credentials were copied.

## Behaviour changes

- Extracted configuration into environment variables and Airflow Connections.
  The DAG remains manually triggered and performs raw ingestion only. dbt is a
  separate command, not a hidden Airflow task.
- Validated a distinct observation month from `scraped_date` and/or the source
  basename. Kept audit ingestion timestamps separate from source event dates.
- Replaced separate delete/commit/insert operations with one transaction per
  source file. Added a listing/source-month uniqueness constraint.
- Replaced load-time snapshot assumptions with deterministic SQL history
  intervals over complete monthly source observations. These are not exact SCD2
  attribute-change times and are not advertised as dbt snapshots.
- Joined reporting geography by source month and history using half-open
  intervals. Mapped host location independently of listing location.
- Preserved the three reporting marts and five business questions. Corrected
  active-listing KPI filters, left missing availability unknown and removed
  monthly-row duplication from single-listing-host mortgage comparisons.
- Preserved the latest-observed summary assumption in business questions C–E,
  and the deterministic suburb-name mapping, with their limits documented.
- Added focused source-month, ingestion and history tests, dbt data tests and
  environment-based examples. Removed assignment identifiers from executable
  filenames. dbt configuration was recreated for this isolated project rather
  than copying a user's runtime profile.

The report's numerical findings are not distributed as outputs of this cleaned
code. Validation against original data and cloud systems remains outstanding.

## Original source checksums

Paths in this table are relative to the local assessment directory above.
SHA-256 values identify the untouched source versions, not byte-equivalence of
adapted outputs. The snapshot files map to redesigned SQL history models.

| Original source | Clean destination | Original SHA-256 |
| --- | --- | --- |
| `Dbt_AS3_[student-id-removed]_KhanhHoangNguyen/models/bronze/bronze_airbnb_raw.sql` | `dbt/models/bronze/bronze_airbnb_raw.sql` | `79c3d6493b24bb5561bd0d956d7a81fe271d802a6c41404ae20a76e361b175c3` |
| `Dbt_AS3_[student-id-removed]_KhanhHoangNguyen/models/bronze/bronze_census_g01_raw.sql` | `dbt/models/bronze/bronze_census_g01_raw.sql` | `4f3828aa7ec4e5dbd5c6a01bed76c4e5b4bc755f6f3590e42d4a14cfddf21342` |
| `Dbt_AS3_[student-id-removed]_KhanhHoangNguyen/models/bronze/bronze_census_g02_raw.sql` | `dbt/models/bronze/bronze_census_g02_raw.sql` | `a26806c82ed2b3f8054577359975306db48f219d6268bb85e1cc7a3d1e218fd9` |
| `Dbt_AS3_[student-id-removed]_KhanhHoangNguyen/models/bronze/bronze_lga_code_raw.sql` | `dbt/models/bronze/bronze_lga_code_raw.sql` | `4e4388ebbfd7f8550df3f5ab2acb41649a0418031a0c4f38fb67ba79f73978ac` |
| `Dbt_AS3_[student-id-removed]_KhanhHoangNguyen/models/bronze/bronze_lga_suburb_raw.sql` | `dbt/models/bronze/bronze_lga_suburb_raw.sql` | `444e9d42fa14bcf3f143fcb0b61f8c343a4e55b94cd1de638b09742cf33906e8` |
| `Dbt_AS3_[student-id-removed]_KhanhHoangNguyen/models/gold/dm_host_neighbourhood.sql` | `dbt/models/gold/dm_host_neighbourhood.sql` | `64dc4d96b8cd3b950be0d2944c09dc054fe6f545f6e33b3b0879d34758949588` |
| `Dbt_AS3_[student-id-removed]_KhanhHoangNguyen/models/gold/dm_listing_neighbourhood.sql` | `dbt/models/gold/dm_listing_neighbourhood.sql` | `1fad74323448088a7a72abb176c7125c881f87c341e08e0dd9624a76c564f557` |
| `Dbt_AS3_[student-id-removed]_KhanhHoangNguyen/models/gold/dm_property_type.sql` | `dbt/models/gold/dm_property_type.sql` | `5120615e2ef700d5079b6c8ac29c170f0a3e0de92d9b045c8734cf21ae490043` |
| `Dbt_AS3_[student-id-removed]_KhanhHoangNguyen/models/gold/ref_census_g01.sql` | `dbt/models/gold/ref_census_g01.sql` | `6d4aa93dd696d6cb0231d541dc4118889a3f5405e33f566c9b84aba1f1eb686f` |
| `Dbt_AS3_[student-id-removed]_KhanhHoangNguyen/models/gold/ref_census_g02.sql` | `dbt/models/gold/ref_census_g02.sql` | `9da2cbf627d0b2e87b0eb5fdaca64f5f857d3025976981585d31ab4bb7df16d6` |
| `Dbt_AS3_[student-id-removed]_KhanhHoangNguyen/models/silver/dim_host_base.sql` | `dbt/models/silver/dim_host_base.sql` | `3c6ed2d93b2fa2fd9d787cd36627fe84e4d8290695fa89d40d76ebc1e454c86e` |
| `Dbt_AS3_[student-id-removed]_KhanhHoangNguyen/models/silver/dim_lga.sql` | `dbt/models/silver/dim_lga.sql` | `76a80f8ac6358eba8dd8e224eff0e9abad2c8340ae7355a06f1cdb0a791041b6` |
| `Dbt_AS3_[student-id-removed]_KhanhHoangNguyen/models/silver/dim_property_base.sql` | `dbt/models/silver/dim_property_base.sql` | `240f4a7a5ece193a01802bca70861e2c712d930d0ed7a8122a85faab817f09fc` |
| `Dbt_AS3_[student-id-removed]_KhanhHoangNguyen/models/silver/dim_suburb.sql` | `dbt/models/silver/dim_suburb.sql` | `f273733e1182522477e0d9d2c3ac65532ce56b5775031e0d60cd679a19361dab` |
| `Dbt_AS3_[student-id-removed]_KhanhHoangNguyen/models/silver/dim_suburb_base.sql` | `dbt/models/silver/dim_suburb_base.sql` | `c4a0462658d3dd8f44d1f9170004c06221ce58b38fddd5324e4b6a81c866404e` |
| `Dbt_AS3_[student-id-removed]_KhanhHoangNguyen/models/silver/fact_listing.sql` | `dbt/models/silver/fact_listing.sql` | `99ad04f127b53514b002a25d1e04295599c618e6d7562e5ca3d2723fee14a011` |
| `DAG_Part1-3_[student-id-removed]_KhanhHoangNguyen.py` | `dags/airbnb_census_ingestion.py and pipeline/` | `6b9fc2ba11878aea17268b3db4c896bbc4ec0887f35534a27c0addab2c76280f` |
| `Part1_[student-id-removed]_KhanhHoangNguyen.sql` | `sql/create_raw_tables.sql` | `0ebe50d6f8f8aa2bd08d2f26e09bbb635a9402b6d4521d20955d369f47461fda` |
| `Part4_[student-id-removed]_KhanhHoangNguyen.sql` | `sql/business_analysis.sql` | `370213c3e7109d1836049a56a1f8bb2d937facc9da9241e16d1aef4b078efca7` |
| `Dbt_AS3_[student-id-removed]_KhanhHoangNguyen/snapshots/host_snapshot.sql` | `dbt/models/silver/host_history.sql` | `f84a324b26cf1c9d051febf753fafce61103a58092d7ab9227ca9de28f88aa03` |
| `Dbt_AS3_[student-id-removed]_KhanhHoangNguyen/snapshots/property_snapshot.sql` | `dbt/models/silver/property_history.sql` | `a32759f689d6359b6758cfd726c7d2e0556366a29277a1533f5414424c56a262` |
