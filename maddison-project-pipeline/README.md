# Maddison Project Pipeline

Bruin pipeline that ingests historical GDP and population data from the Maddison Project into BigQuery, transforming it through raw, staging, and marts layers.

## DAG

```
download_to_gcs → gcs_csv_load → gdp_population → regional_gdp_growth
                                                  → regional_gdp_share
                                                  → gdp_bubble_map
```

## Assets

| Asset | Type | Layer | Description |
|---|---|---|---|
| `download_to_gcs` | Python | Raw | Streams CSV from Google Sheets to GCS bucket |
| `gcs_csv_load` | Ingestr | Raw | Loads CSV from GCS into BigQuery raw table |
| `gdp_population` | SQL | Staging | Cleans, casts, renames columns; clustered by (country_code, year) |
| `regional_gdp_growth` | SQL | Marts | Aggregates GDP by region with linear interpolation for gaps |
| `regional_gdp_share` | SQL | Marts | Regional share of world GDP from 1960 onward |
| `gdp_bubble_map` | SQL | Marts | Per-country GDP time series for map visualization |

## Schedule

Weekly on Mondays at 6:00 AM UTC (configured in `pipeline.yml`).

## Running

```shell
# Full pipeline
bruin run .

# Single asset with downstreams
bruin run assets/ingestion/download_to_gcs.py --downstream

# Validate without executing
bruin validate .
```

## Pipeline Variables

| Variable | Description |
|---|---|
| `gcs_bucket_name` | GCS bucket for raw CSV landing zone |
| `gcp_project_id` | GCP project ID |

Override at runtime:
```shell
bruin run . --var gcs_bucket_name='"my-bucket"' --var gcp_project_id='"my-project"'
```
