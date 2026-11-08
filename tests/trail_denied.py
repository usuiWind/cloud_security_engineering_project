"""Denied GetItem calls on the cases table, from the org trail in the log archive.

AWS_PROFILE=mgmt-platform python tests/trail_denied.py 2026-10-21
Reads that UTC day's workload account CloudTrail files (data events included).
"""
import gzip
import json
import sys

import boto3

day = sys.argv[1].replace("-", "/")
s3 = boto3.client("s3", region_name="us-east-1")
bucket = "meridian-logs-797260139831"
prefix = f"AWSLogs/o-hsguteqhwe/622896097641/CloudTrail/us-east-1/{day}/"
found = 0
for page in s3.get_paginator("list_objects_v2").paginate(Bucket=bucket, Prefix=prefix):
    for o in page.get("Contents", []):
        records = json.loads(gzip.decompress(s3.get_object(Bucket=bucket, Key=o["Key"])["Body"].read()))["Records"]
        for r in records:
            if r.get("eventName") == "GetItem" and "AccessDenied" in (r.get("errorCode") or ""):
                found += 1
                print(json.dumps({k: r.get(k) for k in ("eventTime", "eventName", "errorCode", "errorMessage",
                                                         "requestParameters", "vpcEndpointId")}
                                 | {"principal": r["userIdentity"].get("arn")}))  # session name is the caller id
print(f"{found} denied GetItem events under {prefix}")
