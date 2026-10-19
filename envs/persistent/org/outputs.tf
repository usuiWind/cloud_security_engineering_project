output "org_id" {
  value = aws_organizations_organization.this.id
}

output "workload_account_id" {
  value = aws_organizations_account.workload.id
}

output "log_bucket" {
  value = module.log_archive.id
}

output "org_trail_arn" {
  value = aws_cloudtrail.org.arn
}
