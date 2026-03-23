/* @bruin

name: maddison_project_staging.gdp_population
type: bq.sql
connection: gcp
materialization:
  type: table
  cluster_by:
    - country_code
    - year
  strategy: create+replace

depends:
  - maddison_project_raw.gcs_csv_load

columns:
  - name: country_code
    type: string
    description: "3 letter country code"
    checks:
    - name: not_null
  - name: country
    type: string
    description: "Country name"
    checks:
    - name: not_null
  - name: region
    type: string
    description: "Region name"
    checks:
    - name: not_null
  - name: year
    type: int64
    description: "Year"
    checks:
    - name: positive
  - name: gdp_per_capita
    type: int64
    description: "GDP per capita"
    checks:
    - name: positive
  - name: population
    type: int64
    description: "Population in thousands"
    checks:
    - name: positive

custom_checks:
  - name: data_integrity_check
    description: checks country code, country, and region values are consistent with each other
    query: |
      SELECT
        COUNT(DISTINCT country) as country_count,
        COUNT(DISTINCT region) as region_count
      FROM `maddison_project_staging.gdp_population`
      GROUP BY country_code
      HAVING country_count > 1 OR region_count > 1
    count: 0
  - name: year_consistency_check
    description: checks the same number of records exists for each year
    query: |
      WITH year_counts AS (
        SELECT
          year,
          COUNT(*) AS record_count
        FROM `project-d79af39f-8a71-4f5d-812.maddison_project_staging.gdp_population`
        GROUP BY year
      )
      SELECT
        CASE
          WHEN COUNT(DISTINCT record_count) = 1 THEN 0
          ELSE 1
        END AS result
      FROM `year_counts`

@bruin */

SELECT
  countrycode AS country_code,
  -- Rename Taiwan's country name so its geolocation doesn't map to China.
  CASE 
    WHEN country = 'Taiwan, Province of China' THEN 'Taiwan'
    ELSE country
  END AS country,
  region AS region,
  year AS year,
  CAST(gdppc AS INT64) AS gdp_per_capita, -- column is checked in previous asset
  CAST(pop AS INT64) AS population        -- column is checked in previous asset
FROM `maddison_project_raw.gcs_csv_load`