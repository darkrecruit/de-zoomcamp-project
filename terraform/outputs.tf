output "gcs_bucket_name" {
  value = google_storage_bucket.raw_lake.name
}

output "service_account_email" {
  value = google_service_account.bruin_sa.email
}

output "bigquery_datasets" {
  value = {
    raw     = google_bigquery_dataset.raw.dataset_id
    staging = google_bigquery_dataset.staging.dataset_id
  }
}