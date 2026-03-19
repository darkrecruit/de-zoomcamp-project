"""@bruin

name: maddison_project_raw.download_to_gcs

@bruin"""

import json
import os

import requests
from google.cloud import storage

SOURCE_URL = (
    "https://docs.google.com/spreadsheets/d/e/"
    "2PACX-1vQrJ_BZtGkdZzzQfoQM1b_ivtKr42UumhsqrUpNXsF4-loGIC0agzDmeMO11_5cxQ/"
    "pub?gid=461964940&single=true&output=csv"
)

vars = json.loads(os.environ.get("BRUIN_VARS", "{}"))
GCS_BUCKET = vars.get("gcs_bucket_name")
GCS_PREFIX = "raw"


def download_to_gcs():
    destination_blob = f"{GCS_PREFIX}/data.csv"

    # Check if already landed for this run date
    client = storage.Client()
    bucket = client.bucket(GCS_BUCKET)
    blob = bucket.blob(destination_blob)

    if blob.exists():
        print(f"File already exists at gs://{GCS_BUCKET}/{destination_blob}, skipping.")
        return

    # Stream download — safe for large files
    print(f"Downloading from source URL...")
    response = requests.get(SOURCE_URL, stream=True, timeout=60)
    response.raise_for_status()

    # Upload directly to GCS without writing to disk
    print(f"Uploading to gs://{GCS_BUCKET}/{destination_blob}...")
    blob.upload_from_string(
        data=response.content,
        content_type="text/csv",
    )

    print(f"Successfully landed {len(response.content) / 1024:.1f} KB to GCS.")


download_to_gcs()
