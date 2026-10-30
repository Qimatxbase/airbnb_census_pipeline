CREATE SCHEMA IF NOT EXISTS bronze;

-- =========================
-- 1️ Airbnb raw
-- =========================
CREATE TABLE IF NOT EXISTS bronze.airbnb_raw (
    listing_id                  TEXT,
    scrape_id                   TEXT,
    scraped_date                TEXT,
    host_id                     TEXT,
    host_name                   TEXT,
    host_since                  TEXT,
    host_is_superhost           TEXT,
    host_neighbourhood          TEXT,
    listing_neighbourhood       TEXT,
    property_type               TEXT,
    room_type                   TEXT,
    accommodates                TEXT,
    price                       TEXT,
    has_availability            TEXT,
    availability_30             TEXT,
    number_of_reviews           TEXT,
    review_scores_rating        TEXT,
    review_scores_accuracy      TEXT,
    review_scores_cleanliness   TEXT,
    review_scores_checkin       TEXT,
    review_scores_communication TEXT,
    review_scores_value         TEXT,
    source_month                DATE NOT NULL,
    source_observed_at          DATE NOT NULL,
    source_file                 TEXT,
    loaded_at                   TIMESTAMPTZ DEFAULT now(),
    UNIQUE (source_month, listing_id),
    CHECK (source_month = date_trunc('month', source_observed_at)::date)
);
-- =========================
-- 2️ Census G01
-- =========================
CREATE TABLE IF NOT EXISTS bronze.census_g01_raw (
    lga_code      TEXT,
    payload       JSONB,
    source_file   TEXT,
    loaded_at     TIMESTAMPTZ DEFAULT now()
);

-- =========================
-- 3️ Census G02
-- =========================
CREATE TABLE IF NOT EXISTS bronze.census_g02_raw (
    lga_code      TEXT,
    payload       JSONB,
    source_file   TEXT,
    loaded_at     TIMESTAMPTZ DEFAULT now()
);

-- =========================
-- 4️ NSW_LGA_CODE.csv
-- =========================
CREATE TABLE IF NOT EXISTS bronze.nsw_lga_code_raw (
    lga_code    TEXT,
    lga_name    TEXT,
    source_file TEXT,
    loaded_at   TIMESTAMPTZ DEFAULT now()
);

-- =========================
-- 5️ NSW_LGA_SUBURB.csv
-- =========================
CREATE TABLE IF NOT EXISTS bronze.nsw_lga_suburb_raw (
    lga_name    TEXT,
    suburb_name TEXT,
    source_file TEXT,
    loaded_at   TIMESTAMPTZ DEFAULT now()
);
