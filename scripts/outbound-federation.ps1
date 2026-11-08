# Runbook 4.3 step 1: turn on IAM outbound identity federation in the workload
# account and print the issuer. Account setting, made by hand (POA&M).
# Temporary admin keys live only in this script's process.
$role = "arn:aws:iam::622896097641:role/OrganizationAccountAccessRole"
$c = aws sts assume-role --role-arn $role --role-session-name enable-outbound-federation `
  --profile mgmt-platform --query Credentials --output json | ConvertFrom-Json
if (-not $c) { throw "assume-role failed" }
try {
  $env:AWS_ACCESS_KEY_ID = $c.AccessKeyId
  $env:AWS_SECRET_ACCESS_KEY = $c.SecretAccessKey
  $env:AWS_SESSION_TOKEN = $c.SessionToken
  Remove-Item Env:AWS_PROFILE -ErrorAction SilentlyContinue
  aws iam enable-outbound-web-identity-federation
  aws iam get-outbound-web-identity-federation-info
} finally {
  Remove-Item Env:AWS_ACCESS_KEY_ID, Env:AWS_SECRET_ACCESS_KEY, Env:AWS_SESSION_TOKEN -ErrorAction SilentlyContinue
}
