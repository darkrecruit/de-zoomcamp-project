/* @bruin

name: staging.gdp_population
type: bq.sql
connection: gcp

depends:
  - ingestion.download_to_gcs

dialect: bigquery

secrets:
  - key: GCS_BUCKET_NAME

@bruin */

LOAD DATA OVERWRITE `maddison_project_staging.gdp_population`
(
  country_code STRING,
  country STRING,
  region STRING,
  year INT64,
  gdp_per_capita INT64,
  population INT64
)
CLUSTER BY country_code, year
FROM FILES (
  format = 'CSV',
  uris = ['gs://{{ var.gcs_bucket_name }}/raw/data.csv'],
  skip_leading_rows = 1
);
