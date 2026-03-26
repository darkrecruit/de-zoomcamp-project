/* @bruin

name: maddison_project_marts.regional_gdp_share
type: bq.sql
connection: gcp
materialization:
  type: table
  strategy: create+replace

depends:
  - maddison_project_staging.gdp_population

columns:
  - name: region
    type: string
    description: World region
    checks:
      - name: not_null
  - name: year
    type: date
    description: Year of observation
    checks:
      - name: not_null
  - name: gdp
    type: float64
    description: Total regional GDP (gdp_per_capita * population * 1000)
    checks:
      - name: non_negative
  - name: world_gdp
    type: float64
    description: Total world GDP for the year
    checks:
      - name: positive
  - name: gdp_share
    type: float64
    description: Region share of world GDP as percentage
    checks:
      - name: non_negative
      - name: max
        value: 100

custom_checks:
  - name: shares_sum_to_100
    description: checks GDP shares sum to ~100% for each year
    query: |
      SELECT COUNT(*)
      FROM (
        SELECT year, round(sum(gdp_share), 1) AS total_share
        FROM `maddison_project_marts.regional_gdp_share`
        GROUP BY year
        HAVING total_share < 99.0 OR total_share > 101.0
      )

@bruin */
with
    regional_gdp as (
        select
            region,
            date(format('%04d-01-01', year)) as year,
            sum(gdp_per_capita * population * 1000) as gdp
        from `maddison_project_staging.gdp_population`
        where
            year >= 1960
            and gdp_per_capita is not null
            and population is not null
        group by region, year
    ),

    world_totals as (
        select
            year,
            sum(gdp) as world_gdp
        from regional_gdp
        group by year
    )

select
    r.region,
    r.year,
    r.gdp,
    w.world_gdp,
    round(r.gdp / w.world_gdp * 100, 2) as gdp_share
from regional_gdp r
inner join world_totals w on r.year = w.year
order by r.year, r.region
