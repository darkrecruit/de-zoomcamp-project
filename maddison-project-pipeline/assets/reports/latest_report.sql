/* @bruin

name: maddison_project_marts.latest_report
type: bq.sql
connection: gcp
materialization:
  type: table
  strategy: create+replace

depends:
  - maddison_project_staging.gdp_population

secrets:
  - key: gcp
    inject_as: gcp

columns:
  - name: country_code
    type: string
    description: 3 letter country code
    checks:
      - name: not_null
  - name: country
    type: string
    description: Country name
    checks:
      - name: not_null
  - name: region
    type: string
    description: Region name
    checks:
      - name: not_null
  - name: year
    type: int64
    description: Year of the observation
    checks:
      - name: positive
  - name: gdp_per_capita
    type: int64
    description: GDP per capita
    checks:
      - name: positive
  - name: population
    type: int64
    description: Population in thousands
    checks:
      - name: positive

@bruin */

SELECT
  country_code,
  ANY_VALUE(country) AS country, -- country should always be the same for a given country code, so we can select any value
  ANY_VALUE(region) AS region,  -- region should always be the same for a given country code, so we can select any value
  MAX(year) AS year,
  MAX_BY(gdp_per_capita, year) AS gdp_per_capita,
  MAX_BY(population, year) AS population
FROM `maddison_project_staging.gdp_population`
GROUP BY country_code
