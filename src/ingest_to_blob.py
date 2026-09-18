"""
Usage:
    conda activate dbt-taxi-nyc
    pip install azure-storage-blob requests
    $env:AZURE_STORAGE_CONNECTION_STRING="..."   (already set from before)
    python ingest_13f_to_blob.py
"""

import io
import logging
import os
import sys
import zipfile

import requests
from azure.storage.blob import BlobServiceClient, ContentSettings

# ---- Config -----------------------------------------------------------

# Paste the real quarterly ZIP URLs here, copied from:
# https://www.sec.gov/data-research/sec-markets-data/form-13f-data-sets
ZIP_URLS = [
    "https://www.sec.gov/files/structureddata/data/form-13f-data-sets/01jun2025-31aug2025_form13f.zip",
    "https://www.sec.gov/files/structureddata/data/form-13f-data-sets/01sep2025-30nov2025_form13f.zip",
    "https://www.sec.gov/files/structureddata/data/form-13f-data-sets/01dec2025-28feb2026_form13f.zip",
    "https://www.sec.gov/files/structureddata/data/form-13f-data-sets/01mar2026-31may2026_form13f.zip",
]

# Files inside each zip we actually want to keep for this project.
FILES_TO_EXTRACT = ["INFOTABLE.tsv", "COVERPAGE.tsv"]

CONTAINER_NAME = "sec-13f-raw"
CONNECTION_STRING_ENV_VAR = "AZURE_STORAGE_CONNECTION_STRING"

# The SEC blocks generic/empty User-Agents on purpose (its fair-access
# policy). Use a real identifying string, ideally with contact info.
SEC_HEADERS = {"User-Agent": "Alexandre Cardoso Data Engineering Project alexandre.cardoso.data@gmail.com"}

# ---- Logging ------------------------------------------------------------

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger("ingest_13f_to_blob")


def get_blob_service_client() -> BlobServiceClient:
    conn_str = os.environ.get(CONNECTION_STRING_ENV_VAR)
    if not conn_str:
        log.error("Environment variable %s is not set.", CONNECTION_STRING_ENV_VAR)
        sys.exit(1)
    return BlobServiceClient.from_connection_string(conn_str)


def ensure_container(blob_service_client: BlobServiceClient, container_name: str):
    container_client = blob_service_client.get_container_client(container_name)
    if not container_client.exists():
        log.info("Container '%s' does not exist yet, creating it.", container_name)
        container_client.create_container()
    return container_client


def period_label_from_url(url: str) -> str:
    """Turn '.../01jun2025-31aug2025_form13f.zip' into '01jun2025-31aug2025'."""
    filename = url.rstrip("/").split("/")[-1]
    return filename.replace("_form13f.zip", "").replace(".zip", "")


def process_quarter(container_client, url: str) -> bool:
    period = period_label_from_url(url)
    log.info("Downloading 13F data set for period %s...", period)

    try:
        response = requests.get(url, headers=SEC_HEADERS, timeout=120)
        response.raise_for_status()
    except requests.exceptions.RequestException as exc:
        log.error("Failed to download %s: %s", url, exc)
        return False

    try:
        zip_bytes = io.BytesIO(response.content)
        with zipfile.ZipFile(zip_bytes) as zf:
            names_in_zip = {n.upper(): n for n in zf.namelist()}
            for wanted in FILES_TO_EXTRACT:
                actual_name = names_in_zip.get(wanted.upper())
                if not actual_name:
                    log.warning("%s not found in zip for period %s, skipping it.", wanted, period)
                    continue

                file_bytes = zf.read(actual_name)
                blob_name = f"{period}/{wanted}"
                blob_client = container_client.get_blob_client(blob_name)

                if blob_client.exists():
                    log.info("%s already uploaded, skipping.", blob_name)
                    continue

                blob_client.upload_blob(
                    file_bytes,
                    overwrite=False,
                    content_settings=ContentSettings(content_type="text/tab-separated-values"),
                )
                log.info("Uploaded %s (%d bytes).", blob_name, len(file_bytes))
        return True
    except zipfile.BadZipFile:
        log.error("Downloaded content for period %s is not a valid zip file.", period)
        return False
    except Exception as exc:  # noqa: BLE001
        log.error("Failed to process period %s: %s", period, exc)
        return False


def main():
    if not ZIP_URLS:
        log.error(
            "ZIP_URLS is empty. Copy quarterly zip URLs from "
            "https://www.sec.gov/data-research/sec-markets-data/form-13f-data-sets "
            "and add them to the list before running."
        )
        sys.exit(1)

    blob_service_client = get_blob_service_client()
    container_client = ensure_container(blob_service_client, CONTAINER_NAME)

    results = {url: process_quarter(container_client, url) for url in ZIP_URLS}

    succeeded = [u for u, ok in results.items() if ok]
    failed = [u for u, ok in results.items() if not ok]

    log.info("Done. %d succeeded, %d failed.", len(succeeded), len(failed))
    if failed:
        log.warning("Failed URLs: %s", ", ".join(failed))
        sys.exit(1)


if __name__ == "__main__":
    main()