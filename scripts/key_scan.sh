#!/usr/bin/env bash
# Fails if the current account has any IAM user or any root access key, or
# if a Google API key (the Gemini key lives only in Secrets Manager) is in the
# repo. Runs as the first step of every pipeline, and by hand in each account.
set -euo pipefail
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  if git grep -nIE 'AIza[0-9A-Za-z_-]{35}' -- . ; then
    echo "FAIL Google API key in the repo"
    exit 1
  fi
  echo "PASS no Google API key in the repo"
fi
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
