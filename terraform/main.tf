terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ── Enable required APIs ──────────────────────────────────────────
resource "google_project_service" "bigquery" {
  service            = "bigquery.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "storage" {
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam" {
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

# ── GCS Bucket (raw data lake) ────────────────────────────────────
resource "google_storage_bucket" "raw_lake" {
  name                        = var.gcs_bucket_name
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90 # keep raw files for 90 days
    }
    action {
      type = "Delete"
    }
  }
}

# ── BigQuery Datasets ─────────────────────────────────────────────
resource "google_bigquery_dataset" "raw" {
  dataset_id                 = var.bq_dataset_raw
  location                   = var.region
  delete_contents_on_destroy = true
  depends_on                 = [google_project_service.bigquery]
}

resource "google_bigquery_dataset" "staging" {
  dataset_id                 = var.bq_dataset_staging
  location                   = var.region
  delete_contents_on_destroy = true
  depends_on                 = [google_project_service.bigquery]
}

resource "google_bigquery_dataset" "marts" {
  dataset_id = var.bq_dataset_marts
  location   = var.region
  lifecycle {
    prevent_destroy = true
  }
  depends_on = [google_project_service.bigquery]
}

# ── Service Account for Bruin ─────────────────────────────────────
resource "google_service_account" "bruin_sa" {
  account_id   = "bruin-pipeline-sa"
  display_name = "Bruin Pipeline Service Account"
  depends_on   = [google_project_service.iam]
}

# IAM bindings — least privilege
locals {
  bruin_roles = [
    "roles/bigquery.dataEditor", # create/write BQ tables
    "roles/bigquery.jobUser",    # run BQ jobs/queries
    "roles/storage.objectAdmin", # read/write GCS objects
  ]
}

resource "google_project_iam_member" "bruin_sa_roles" {
  for_each = toset(local.bruin_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.bruin_sa.email}"
}

# ── Service Account Key ───────────────────────────────────────────
resource "google_service_account_key" "bruin_sa_key" {
  service_account_id = google_service_account.bruin_sa.name
}

resource "local_file" "bruin_sa_key_file" {
  content         = base64decode(google_service_account_key.bruin_sa_key.private_key)
  filename        = "${path.module}/../secrets/gcp-sa.json"
  file_permission = "0600"
}
