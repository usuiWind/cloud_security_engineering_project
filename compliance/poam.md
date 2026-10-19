# POA&M

| ID | Weakness | Control | Source |
| --- | --- | --- | --- |
| M1-1 | CKV_AWS_26 skip: break glass SNS topic has no CMK, because EventBridge cannot publish to the AWS managed SNS key. Alert holds no sensitive data. | SC-28 | M1 |
| M1-2 | PlatformAdmin reaches the workload account through OrganizationAccountAccessRole, which is full admin there. Replace with a scoped role later. | AC-6 | M1 |
| M1-3 | Management account root cannot be removed. MFA on, no keys, not used. | IA-5 | M1 |
| M1-4 | One person holds every role, so separation of duties cannot be shown in the lab. | AC-5 | M1 |
| M1-5 | Actions added by hand to the scoped deploy policy in 1.9: one line per action with its commit (to fill in). | AC-6 | M1 |
