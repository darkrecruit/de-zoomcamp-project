/* @bruin

name: maddison_project_marts.regional_gdp_growth
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
    description: Region name
    checks:
      - name: not_null
  - name: year
    type: date
    description: Decade of the observation
    checks:
      - name: not_null
  - name: gdp
    type: float64
    description: Total GDP
    checks:
      - name: non_negative

@bruin */
with
    spine as (
        select date(format('%04d-01-01', cast(yr as int64))) as year
        from
            unnest(
                generate_array(
                    (select min(year) from `maddison_project_staging.gdp_population`),
                    (select max(year) from `maddison_project_staging.gdp_population`),
                    1
                )
            ) as yr
    ),

    regions as (select distinct region from `maddison_project_staging.gdp_population`)

select
    s.year,
    r.region,
    sum(
        case
            when gdp_per_capita is not null and population is not null
            then gdp_per_capita * population * 1000
        end
    ) as gdp
from spine s
cross join regions r
left join
    `maddison_project_staging.gdp_population` p
    on date(format('%04d-01-01', p.year)) = s.year
    and p.region = r.region
group by s.year, r.region
order by s.year, r.region