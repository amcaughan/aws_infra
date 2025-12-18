#!/usr/bin/env bash
set -euo pipefail

REGION="us-east-2"
PROFILE="default"
BUCKET_NAME="amcaughan-tf-state-us-east-2"

# Safety gate:
# Set CONFIRM_NUKE to the bucket name to proceed, e.g.
#   CONFIRM_NUKE="amcaughan-tf-state-us-east-2" ./teardown_state_bucket.sh
CONFIRM_NUKE="${CONFIRM_NUKE:-}"

aws_cmd() {
  aws --region "$REGION" --profile "$PROFILE" "$@"
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

echo_hdr() {
  echo
  echo "===> $*"
}

require_cmd aws
require_cmd python3

if [[ -z "$BUCKET_NAME" ]]; then
  die "BUCKET_NAME is empty"
fi

if [[ "$CONFIRM_NUKE" != "$BUCKET_NAME" ]]; then
  cat >&2 <<EOF
Refusing to run without explicit confirmation.

This script will PERMANENTLY delete:
  - all object versions
  - all delete markers
  - the bucket itself

To proceed, run:
  CONFIRM_NUKE="$BUCKET_NAME" $0

EOF
  exit 1
fi

echo_hdr "About to PERMANENTLY delete bucket and all versions: $BUCKET_NAME"
echo "Region:  $REGION"
echo "Profile: $PROFILE"
echo

# Quick existence check
if ! aws_cmd s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  die "Bucket does not exist or you don't have access: $BUCKET_NAME"
fi

# Versions + Delete Markers
echo_hdr "Deleting all object versions and delete markers (this may take a while)"

python3 - <<'PY'
import json
import os
import subprocess
import sys
from typing import List, Dict, Any, Optional

REGION = os.environ["REGION"]
PROFILE = os.environ["PROFILE"]
BUCKET = os.environ["BUCKET_NAME"]

def aws_cmd(args: List[str]) -> str:
  cmd = ["aws", "--region", REGION, "--profile", PROFILE] + args
  res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
  if res.returncode != 0:
    sys.stderr.write(res.stderr)
    raise SystemExit(res.returncode)
  return res.stdout

def chunked(items: List[Dict[str, Any]], size: int):
  for i in range(0, len(items), size):
    yield items[i:i+size]

def delete_batch(objs: List[Dict[str, str]]):
  payload = {"Objects": objs, "Quiet": True}
  aws_cmd(["s3api", "delete-objects", "--bucket", BUCKET, "--delete", json.dumps(payload)])

def drain_object_versions(kind: str):
  # kind: "Versions" or "DeleteMarkers"
  key_token: Optional[str] = None
  ver_token: Optional[str] = None
  total = 0

  while True:
    args = ["s3api", "list-object-versions", "--bucket", BUCKET, "--output", "json"]
    if key_token is not None:
      args += ["--key-marker", key_token]
    if ver_token is not None:
      args += ["--version-id-marker", ver_token]

    data = json.loads(aws_cmd(args))

    items = data.get(kind, []) or []
    objs = [{"Key": it["Key"], "VersionId": it["VersionId"]} for it in items]

    # Delete in batches of 1000 (AWS limit)
    for batch in chunked(objs, 1000):
      delete_batch(batch)
      total += len(batch)
      print(f"Deleted {len(batch)} {kind} (running total: {total})")

    key_token = data.get("NextKeyMarker")
    ver_token = data.get("NextVersionIdMarker")

    # If no further pages, stop
    if not key_token and not ver_token:
      break

  return total

versions_deleted = drain_object_versions("Versions")
markers_deleted = drain_object_versions("DeleteMarkers")

print(f"Done deleting versions: {versions_deleted}")
print(f"Done deleting delete markers: {markers_deleted}")
PY

echo_hdr "Deleting bucket: $BUCKET_NAME"
aws_cmd s3api delete-bucket --bucket "$BUCKET_NAME"

echo_hdr "Bucket deleted: $BUCKET_NAME"
