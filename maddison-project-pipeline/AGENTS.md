# BRUIN PIPELINE

## OVERVIEW

Bruin data pipeline: CSV ingestion → BigQuery staging → mart reports. Weekly schedule (Mondays 6am).

## STRUCTURE

```
assets/
├── ingestion/
│   ├── download_to_gcs.py          # Python: Google Sheets CSV → GCS blob
│   └── gcs_to_bigquery.asset.yml   # Ingestr: GCS CSV → BQ raw table
├── staging/
│   └── gdp_population.sql          # Clean, cast, rename → staging table
└── reports/
    ├── latest_report.sql           # Latest year snapshot per country
    ├── regional_gdp_growth.sql     # Regional GDP with linear interpolation
    └── gdp_bubble_map.sql          # Per-country GDP time series for visualization
```

## DAG FLOW

```
download_to_gcs → gcs_csv_load → gdp_population → latest_report
                                                  → regional_gdp_growth
                                                  → gdp_bubble_map
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add ingestion source | `assets/ingestion/` | Python for custom logic, `.asset.yml` for ingestr |
| Add staging transform | `assets/staging/` | SQL with `@bruin` metadata block |
| Add report/mart | `assets/reports/` | Depends on staging, uses `create+replace` |
| Change schedule/vars | `pipeline.yml` | `gcs_bucket_name`, `gcp_project_id` available |

## ASSET ANATOMY

**SQL asset** — metadata in `/* @bruin ... @bruin */`, query below:
```sql
/* @bruin
name: maddison_project_{layer}.{asset_name}
type: bq.sql
connection: gcp
materialization:
  type: table
  strategy: create+replace
depends:
  - {upstream_asset}
columns:
  - name: {col}
    type: {bq_type}
    checks:
      - name: not_null
@bruin */
SELECT ... FROM `{upstream_table}`
```

**Python asset** — metadata in `"""@bruin ... @bruin"""`, function call at module level.

**Ingestr asset** — YAML-only `.asset.yml` with `type: ingestr`, `parameters.source_connection`, `parameters.source_table`.

## CONVENTIONS

- Column checks: `not_null`, `positive`, `non_negative` — declared per-column in metadata.
- Custom checks: `custom_checks` block with raw BigQuery SQL; use fully-qualified table names.
- Staging renames `countrycode` → `country_code`, casts float → INT64 for GDP/population.
- Reports reference staging tables via backtick-quoted BQ names: `` `maddison_project_staging.gdp_population` ``.
- No Jinja templating — plain SQL with BigQuery functions.

## GOTCHAS

- `regional_gdp_growth.sql` uses complex windowed linear interpolation to fill GDP gaps — do not simplify or refactor without understanding the math.
- `ANY_VALUE()` in `latest_report.sql` assumes country/region are consistent per country_code — validated by `data_integrity_check` in staging.
- `gcs_to_bigquery.asset.yml` hardcodes the GCS bucket path in `source_table` — must match Terraform's bucket name.
- Pipeline variables accessed in Python via `BRUIN_VARS` env var (JSON), not direct env vars.
