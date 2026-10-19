# One intent, both clouds. The Azure stack reads it with -var-file; the AWS SCPs read it in M2.
allowed_regions    = { aws = ["us-east-1", "us-west-2"], azure = ["eastus", "westus2"] }
required_tags      = ["project", "owner", "milestone", "data_class"]
protected_services = ["cloudtrail", "guardduty", "kms"]
