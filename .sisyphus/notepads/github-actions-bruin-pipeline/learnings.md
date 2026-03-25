
## [2026-03-24] Task: workflow-creation
- GCS connection in .bruin.yml uses key `gcs:` under connections
- service_account_file path is relative to bruin project root (workspace root)
- python.executable changed from Docker path to relative .venv/bin/python
- Terraform state upload uses if:always() to ensure capture even on failure
- Heredoc with leading whitespace from YAML indentation is valid — YAML ignores consistent leading spaces
- Single-quoted heredoc delimiter ('BRUINYML') prevents shell expansion but GitHub Actions ${{ }} expressions expand before shell runs
- terraform_wrapper: false is critical — wrapper breaks raw terraform output parsing
