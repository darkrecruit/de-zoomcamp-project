# Maddison Project GDP & Population Pipeline

### Problem Description
The Maddison Project provides historical GDP per capita and population data spanning 2000+ years across 169 countries. The data is published as a Google Sheets CSV, which is not query-friendly and lacks a data quality or transformation layer. This project builds an end-to-end pipeline to ingest data from Google Sheets into a GCS data lake and a BigQuery warehouse (raw, staging, and marts layers). The final dashboard visualizes regional GDP trends over time and per-country GDP on a bubble map.

### Architecture Diagram
```
Google Sheets CSV
    │
    ▼
[download_to_gcs.py]  ── Python: stream download → GCS bucket
    │
    ▼
[gcs_to_bigquery]      ── Ingestr: GCS CSV → BigQuery raw table
    │
    ▼
[gdp_population]       ── SQL: clean, cast, rename → staging table (clustered by country_code, year)
    │
    ├──► [regional_gdp_growth]  ── SQL: aggregate by region + linear interpolation for gaps
    │
    ├──► [regional_gdp_share]   ── SQL: regional share of world GDP (1960+)
    │
    └──► [gdp_bubble_map]       ── SQL: per-country GDP time series for visualization
              │
              ▼
      Looker Studio Dashboard
```

### Technologies
| Technology | Purpose |
|---|---|
| **Google Cloud Platform** | Cloud provider |
| **Google Cloud Storage** | Data lake (raw CSV landing zone) |
| **BigQuery** | Data warehouse (raw → staging → marts) |
| **Terraform** | Infrastructure as Code (GCS bucket, BQ datasets, service accounts) |
| **Bruin** | Pipeline orchestration — ingestion, transformation, data quality |
| **GitHub Actions** | CI/CD — ad-hoc pipeline execution with Terraform lifecycle |
| **Looker Studio** | Dashboard visualization |
| **Python** | Custom ingestion script (Google Sheets → GCS) |
| **uv** | Python package management |

### About Bruin
Bruin handles the full pipeline: Python ingestion, SQL transformations with data quality checks, and DAG orchestration.

### Data Warehouse Design
The pipeline uses a 3-layer architecture in BigQuery:
- **Raw** (maddison_project_raw): Landing zone where the CSV is loaded as-is from GCS via ingestr. Column checks validate not_null on all dimension columns, positive years, and non-negative numeric values. Custom checks verify integer-only values in population and GDP columns.
- **Staging** (maddison_project_staging): Cleaned data layer. Columns are renamed (e.g., countrycode to country_code), floats are cast to INT64, and Taiwan is renamed for geolocation accuracy. Tables are clustered by (country_code, year), which are the primary filter and group-by columns in downstream queries. Quality checks include: country_code format validation (3-letter ISO pattern), year range bounds, primary key uniqueness on (country_code, year), cross-column consistency, year record count consistency, and Taiwan rename verification.
- **Marts** (maddison_project_marts): Report-ready tables. regional_gdp_growth aggregates GDP by region with linear interpolation to fill historical gaps. regional_gdp_share computes each region's percentage of world GDP from 1960 onward, where all regions have reliable data coverage. gdp_bubble_map computes total GDP per country per year for visualization. Each mart includes primary key uniqueness checks. This dataset is persistent and not destroyed between pipeline runs.

Partitioning is not used because the Maddison dataset is a static historical dataset of approximately 30,000 rows that is fully replaced on each run. BigQuery partitioning adds overhead for small tables and provides no benefit when the entire table is scanned. Clustering on (country_code, year) is sufficient for query optimization.

### Dashboard
- Link: https://lookerstudio.google.com/reporting/13b631dd-5208-489e-9495-5daa65c832af
- Built with Looker Studio connected to the BigQuery marts dataset.
- The dashboard is publicly shared — no Google account required to view.
- Tiles:
  1. **Regional GDP Over Time** (time series line chart): Shows GDP growth by world region from the regional_gdp_growth mart, with linear interpolation filling historical gaps.
  2. **Share of World GDP by Region** (stacked area chart): Shows how each region's share of global GDP has shifted from 1960 onward, from the regional_gdp_share mart.
  3. **GDP Bubble Map** (geo chart): Shows per-country GDP from the gdp_bubble_map mart, with bubble size representing total GDP.

### Reproduction Instructions

**Prerequisites:**
- GCP account with a project
- GitHub account
- gcloud CLI installed

**Steps:**

1. **Fork/clone the repository**
   ```bash
   git clone https://github.com/darkrecruit/de-zoomcamp-project.git
   cd de-zoomcamp-project
   ```

2. **GCP Setup — enable required APIs:**
   ```bash
   gcloud services enable bigquery.googleapis.com storage.googleapis.com iam.googleapis.com \
     --project=YOUR_PROJECT_ID
   ```

3. **Create the persistent marts dataset** (one-time, not managed by Terraform):
   ```bash
   bq mk --dataset --location=us-central1 YOUR_PROJECT_ID:maddison_project_marts
   ```

4. **Set up Workload Identity Federation for GitHub Actions:**
   - Create a workload identity pool and provider for GitHub.
   - Create a service account with these roles: roles/storage.admin, roles/bigquery.admin, roles/iam.serviceAccountAdmin, roles/iam.serviceAccountKeyAdmin, roles/resourcemanager.projectIamAdmin.
   - Bind the service account to the workload identity pool.

5. **Configure GitHub repository variables** (Settings → Environments → create "default" environment):
   | Variable | Value |
   |---|---|
   | GCP_WIF_PROVIDER | projects/PROJECT_NUM/locations/global/workloadIdentityPools/POOL/providers/PROVIDER |
   | GCP_SA_EMAIL | Service account email |
   | GCP_PROJECT_ID | Your GCP project ID |
   | GCS_BUCKET_NAME | Globally unique bucket name |

6. **Run the pipeline:**
   ```bash
   gh workflow run pipeline.yml
   ```
   Or: GitHub → Actions tab → "Run Bruin Pipeline" → Run workflow.

7. **View the dashboard:** Connect Looker Studio to the maddison_project_marts dataset in BigQuery.

### CI/CD Pipeline
The pipeline is triggered ad-hoc via workflow_dispatch and uses Workload Identity Federation to avoid stored secrets. The lifecycle follows a sequence of Terraform apply, bruin validate, bruin run, and finally Terraform destroy. Terraform creates ephemeral infrastructure, including the GCS bucket, BigQuery raw and staging datasets, and a service account with its key for each run. Terraform state is uploaded as an artifact with a 1-day retention period as a safety net if the destroy step fails. The maddison_project_marts dataset remains persistent and is not managed by Terraform.
