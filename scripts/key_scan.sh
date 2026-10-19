#!/usr/bin/env bash
# Fails if the current account has any IAM user or any root access key.
# Runs as the first step of every pipeline, and by hand in each account.
set -euo pipefail
acct=$(aws sts get-caller-identity --query Account --output text)
root_keys=$(aws iam get-account-summary --query 'SummaryMap.AccountAccessKeysPresent' --output text)
users=$(aws iam list-users --query 'length(Users)' --output text)
echo "account: $acct  root access keys: $root_keys  iam users: $users"
if [ "$root_keys" = "0" ] && [ "$users" = "0" ]; then
  echo "PASS no static credentials"
else
  echo "FAIL static credentials present"
  exit 1
fi
