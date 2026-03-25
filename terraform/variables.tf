variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "bq_dataset_raw" {
  description = "BigQuery raw dataset name"
  type        = string
  default     = "maddison_project_raw"
}

variable "bq_dataset_staging" {
  description = "BigQuery staging dataset name"
  type        = string
  default     = "maddison_project_staging"
}

variable "gcs_bucket_name" {
  description = "GCS bucket name (must be globally unique)"
  type        = string
}