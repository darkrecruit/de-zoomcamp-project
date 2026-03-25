# Plan: Deploy Bruin Pipeline as GitHub Action

## Context

Deploy the Bruin data pipeline as an ad-hoc GitHub Action with full Terraform lifecycle (create → run → destroy). The workflow must handle GCP authentication for both Terraform (infra management) and Bruin (pipeline execution with BigQuery/GCS connections).

### Key Constraints
- **Trigger**: `workflow_dispatch` (ad-hoc, manual)
- **Lifecycle**: Terraform apply → Bruin run → Terraform destroy (all in one run)
- **Auth chain**: GitHub secret (CI SA key) → Terraform creates Bruin SA → Bruin uses Bruin SA key
- **Terraform state**: Local (ephemeral per run) — uploaded as artifact for disaster recovery
- **Bruin connections**: `.bruin.yml` generated dynamically from Terraform-created SA key
- **Python deps**: `uv sync` in CI for `download_to_gcs.py` dependencies

### Architecture

```
GitHub Secret (GCP_SA_KEY) ─── broad perms: create/destroy resources
        │
        ├── google-github-actions/auth ── sets ADC for Terraform
        │
        ├── terraform apply ─── creates BQ datasets, GCS bucket, Bruin SA + key
        │       │
        │       └── secrets/gcp-sa.json ── narrow perms: BQ data + GCS objects
        │               │
        │               └── .bruin.yml ── generated dynamically from SA key
        │                       │
        │                       └── bruin run ── executes pipeline
        │
        └── terraform destroy ── tears down everything (always, even on failure)
```

### Secrets & Variables (user must configure in GitHub repo settings)

| Name | Type | Value |
|------|------|-------|
| `GCP_SA_KEY` | Secret | SA key JSON with project-level permissions (editor + IAM admin) |
| `GCP_PROJECT_ID` | Variable | GCP project ID (e.g., `project-d79af39f-8a71-4f5d-812`) |
| `GCS_BUCKET_NAME` | Variable | Globally unique GCS bucket name |

---

## Tasks

- [x] **1. Create GitHub Actions workflow file**
  - Create `.github/workflows/pipeline.yml`
  - `workflow_dispatch` trigger (no inputs required, all config from secrets/variables)
  - Job steps in order:
    1. `actions/checkout@v4`
    2. `google-github-actions/auth@v2` with `credentials_json: ${{ secrets.GCP_SA_KEY }}`
    3. `hashicorp/setup-terraform@v3` (wrapper disabled for raw output)
    4. Terraform init + apply (pass `project_id` and `gcs_bucket_name` as `-var`)
    5. Upload Terraform state as artifact (disaster recovery if destroy fails)
    6. `actions/setup-python@v5` (Python 3.11)
    7. Install uv + run `uv sync` for Python dependencies
    8. `bruin-data/setup-bruin@main` to install Bruin CLI
    9. Read `secrets/gcp-sa.json` (created by Terraform) and generate `.bruin.yml`
    10. Run `bruin run maddison-project-pipeline`
    11. Terraform destroy with `if: always()` (runs even if pipeline fails)
  - Concurrency group to prevent parallel runs

- [x] **2. Generate `.bruin.yml` in the workflow**
  - The `.bruin.yml` needs two connections that assets reference:
    - `gcp` (BigQuery) — type `google_cloud_platform`, used by all SQL assets
    - `gcs` (Cloud Storage) — used by `gcs_to_bigquery.asset.yml` ingestr source
  - Read `secrets/gcp-sa.json` (Terraform output) and inject into `.bruin.yml` template
  - Write `.bruin.yml` to project root (gitignored already)
  - Verify with `bruin validate maddison-project-pipeline` before running

- [x] **3. Configure Python environment for Bruin**
  - Bruin executes Python assets (e.g., `download_to_gcs.py`) using a Python interpreter
  - `pipeline.yml` has a commented-out `python.executable` path — uncomment and set to `.venv/bin/python`
  - Ensure `GOOGLE_APPLICATION_CREDENTIALS` env var points to SA key file so `google.cloud.storage.Client()` authenticates
  - Set `BRUIN_VARS` env var with `gcs_bucket_name` and `gcp_project_id` for the Python asset

- [x] **4. Add Terraform state artifact upload**
  - After `terraform apply`, upload `.terraform` dir + `*.tfstate` as GitHub Actions artifact
  - Retention: 1 day (only needed if destroy fails)
  - This is a safety net — if destroy fails, state can be downloaded to manually clean up

- [x] **5. Update AGENTS.md with CI workflow documentation**
  - Add CI/CD section to root AGENTS.md
  - Document required GitHub secrets/variables
  - Document how to trigger the workflow (`gh workflow run` or UI)
  - Add entry to WHERE TO LOOK table

---

## Verification

- [x] Workflow YAML passes `actionlint` (if available) or at minimum valid YAML syntax
- [x] `.bruin.yml` generation covers both `gcp` and `gcs` connections
- [x] Terraform destroy runs with `if: always()` — never skipped
- [x] `secrets/gcp-sa.json` is never logged or exposed in workflow output
- [x] Concurrency group prevents parallel runs
- [x] Python venv + dependencies available for Bruin Python assets

## Risks

- **Orphaned resources**: If Terraform destroy fails AND state artifact upload also fails, resources are orphaned. Mitigated by artifact upload step.
- **Bruin GCS connection format**: Exact `.bruin.yml` format for `gcs` connection type needs verification against Bruin docs during implementation.
- **Python path**: Bruin must find the correct Python with `google-cloud-storage` installed. May need `pipeline.yml` update.
