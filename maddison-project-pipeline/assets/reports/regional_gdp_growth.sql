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

    regions as (select distinct region from `maddison_project_staging.gdp_population`),

    -- Aggregate known data points
    aggregated as (
        select
            s.year,
            r.region,
            sum(
                case
                    when p.gdp_per_capita is not null and p.population is not null
                    then p.gdp_per_capita * p.population * 1000
                end
            ) as gdp
        from spine s
        cross join regions r
        left join `maddison_project_staging.gdp_population` p
            on date(format('%04d-01-01', p.year)) = s.year
            and p.region = r.region
        group by s.year, r.region
    ),

    -- For each null, find the nearest known value before and after
    with_bounds as (
        select
            year,
            region,
            gdp,
            -- Last known value and its year
            last_value(gdp ignore nulls) over (
                partition by region
                order by year
                rows between unbounded preceding and current row
            ) as prev_gdp,
            last_value(year ignore nulls) over (
                partition by region
                order by year
                rows between unbounded preceding and current row
            ) as prev_year,
            -- Next known value and its year
            last_value(gdp ignore nulls) over (
                partition by region
                order by year
                rows between current row and unbounded following
            ) as next_gdp,
            last_value(year ignore nulls) over (
                partition by region
                order by year
                rows between current row and unbounded following
            ) as next_year
        from aggregated
    )

select
    year,
    region,
    case
        when gdp is not null then gdp
        when prev_gdp is null or next_gdp is null then 0
        else
            -- linear interpolation
            prev_gdp + (next_gdp - prev_gdp)
            * date_diff(year, prev_year, year)
            / date_diff(next_year, prev_year, year)
    end as gdp
from with_bounds
order by year, region