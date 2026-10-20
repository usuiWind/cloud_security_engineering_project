# POA&M

| ID | Weakness | Control | Source |
| --- | --- | --- | --- |
| M1-1 | CKV_AWS_26 skip: break glass SNS topic has no CMK, because EventBridge cannot publish to the AWS managed SNS key. Alert holds no sensitive data. | SC-28 | M1 |
| M1-2 | PlatformAdmin reaches the workload account through OrganizationAccountAccessRole, which is full admin there. Replace with a scoped role later. | AC-6 | M1 |
| M1-3 | Management account root cannot be removed. MFA on, no keys, not used. | IA-5 | M1 |
| M1-4 | One person holds every role, so separation of duties cannot be shown in the lab. | AC-5 | M1 |
| M1-5 | Actions added by hand to the scoped deploy policy in 1.9: one line per action with its commit (to fill in). | AC-6 | M1 |
| M2-1 | PIM not configured. Threat model B9 claims time bound activation; the breakglass group has no standing role and the hand-made emergency account is the real break glass. Revisit after M5. | AC-2 | M2 |
| M2-2 | Emergency account sign in is not yet alerted. Alert on it in Session 5 (Sentinel). | AC-2 | M2 |
| M2-3 | MFA is enforced by Entra Security Defaults, not Conditional Access: the P1/P2 trial cannot be activated on a tenant created by a personal Microsoft account. Covers every user, emergency account included; no per-app or per-location conditions, and the setting is a tenant switch, not code. Revisit if a P1 license becomes available. | IA-2 | M2 |
| M2-4 | `meridian-deploy` custom role adds `Microsoft.Resources` resource group and deployment actions beyond the plan's five namespaces; the pipeline cannot create a resource group without them. | AC-6 | M2 |
| M2-5 | NIST SP 800-53 Rev. 5 initiative assigned with enforcement off (audit only). | CA-7 | M2 |
| M2-6 | Required tag Deny can block resource groups that Azure services create automatically; handled by hand. | CM-8 | M2 |
| M2-7 | Policy gate scans Terraform source, not a plan: pull requests have no cloud credentials by design (M1). Plan level checks run only where a plan exists. | CM-6 | M2 |
| M2-8 | CKV_AWS_145: state, log and pipeline buckets use SSE-S3, not a CMK, to avoid locking CloudTrail or Terraform out through a key policy. Data buckets get CMKs in M3. | SC-28 | M2 |
| M2-9 | CKV_AWS_144: no cross region replication on lab buckets; versioning covers recovery. | CP-9 | M2 |
| M2-10 | CKV_AWS_18: no S3 access logging; the org trail records bucket management calls. | AU-2 | M2 |
| M2-11 | CKV2_AWS_61: no lifecycle rules; lab lifetime under 30 days. | SI-12 | M2 |
| M2-12 | CKV2_AWS_62: no S3 event notifications; no consumer. | SI-4 | M2 |
| M2-13 | CKV_AWS_35: org trail logs on SSE-S3, not a CMK. | AU-9 | M2 |
| M2-14 | CKV2_AWS_10: org trail not sent to CloudWatch Logs; Sentinel reads the S3 archive in M5. | AU-6 | M2 |
| M2-15 | CKV_AWS_252: no SNS on trail delivery; break glass alerting is EventBridge. | AU-5 | M2 |
| M2-16 | CKV2_AWS_34: `/meridian/config/model_id` is a String, not a SecureString; it is not a secret. | SC-28 | M2 |
| M2-17 | SCPs do not apply to the management account by AWS design; it holds no workload and is reached only through PlatformAdmin and BreakGlass. | CM-7 | M2 |
| M2-18 | Protected service actions are exempt for BreakGlass, so the day 4 GuardDuty teardown runs as BreakGlass and triggers the alert. | AU-9 | M2 |
