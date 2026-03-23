/* @bruin

name: maddison_project_marts.gdp_bubble_map
type: bq.sql
connection: gcp
materialization:
  type: table
  strategy: create+replace

depends:
  - maddison_project_staging.gdp_population


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
    description: Region to which the country belongs
    checks:
      - name: not_null
  - name: year
    type: date
    description: Year of the observation
    checks:
      - name: not_null
  - name: gdp
    type: float64
    description: Total GDP
    checks:
      - name: non_negative
  - name: gdp_per_capita
    type: float64
    description: GDP per capita
    checks:
      - name: non_negative
  - name: population
    type: int64
    description: Population in thousands
    checks:
      - name: positive

@bruin */
with
    computed as (
        select
            country_code,
            country,
            region,
            year,
            gdp_per_capita,
            population,
            safe_multiply(
                cast(gdp_per_capita as float64), cast(population * 1000 as float64)
            ) as gdp
        from `maddison_project_staging.gdp_population`
        where gdp_per_capita is not null and population is not null
    ),

    all_countries as (
        select
            country_code,
            country,
            max(gdp) as peak_gdp
        from computed
        group by country_code, country
    )

select
    c.country_code,
    c.country,
    c.region,
    date(format('%04d-01-01', cast(c.year as int64))) as year,
    c.gdp_per_capita,
    c.population,
    round(c.gdp) as gdp
from computed c
inner join all_countries a on c.country_code = a.country_code
order by c.country, c.year