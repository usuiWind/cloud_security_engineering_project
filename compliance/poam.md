# POA&M

| ID | Weakness | Control | Source |
| --- | --- | --- | --- |
| M1-1 | CKV_AWS_26 skip: break glass SNS topic has no CMK, because EventBridge cannot publish to the AWS managed SNS key. Alert holds no sensitive data. | SC-28 | M1 |
| M1-2 | PlatformAdmin reaches the workload account through OrganizationAccountAccessRole, which is full admin there. Replace with a scoped role later. | AC-6 | M1 |
| M1-3 | Management account root cannot be removed. MFA on, no keys, not used. | IA-5 | M1 |
| M1-4 | One person holds every role, so separation of duties cannot be shown in the lab. | AC-5 | M1 |
| M1-5 | Actions added by hand to the scoped deploy policy in 1.9: one line per action with its commit (to fill in). | AC-6 | M1 |
| M2-1 | PIM not configured. Threat model B9 claims time bound activation; the breakglass group has no standing role and the hand-made emergency account is the real break glass. Revisit after M5. | AC-2 | M2 |
| M2-2 | Emergency account sign in is not alerted. It needs Entra sign-in logs in Sentinel, and exporting them needs Entra ID P1/P2, which this tenant cannot activate (M2-3). | AC-2 | M2 |
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
| M2-16 | CKV2_AWS_34: `/meridian/config/model_id` (the Gemini model name) is a String, not a SecureString; it is not a secret. | SC-28 | M2 |
| M2-17 | SCPs do not apply to the management account by AWS design; it holds no workload and is reached only through PlatformAdmin and BreakGlass. | CM-7 | M2 |
| M2-18 | Protected service actions are exempt for BreakGlass, so the day 4 GuardDuty teardown runs as BreakGlass and triggers the alert. | AU-9 | M2 |
| M3-1 | Single AZ, single private subnet; an AZ outage takes the assistant down. | SC-7 | M3 |
| M3-2 | The assistant trusts `caller_id` from whoever invokes it, until APIM forwards the Entra claim (T-17). | IA-3 | M3 |
| M3-3 | Key administrators hold `kms:PutKeyPolicy` and could rewrite a policy to grant themselves use. Alert on PutKeyPolicy in M5. | SC-12 | M3 |
| M3-4 | The Terraform role can use the keys through S3, DynamoDB and Secrets Manager, to seed data. A separate loader role is the production pattern. | SC-28 | M3 |
| M3-5 | Gateway endpoint policies allow any principal in the VPC on the named resources. The tool roles are the principal control. | AC-4 | M3 |
| M3-6 | Lambda skips: CKV_AWS_116 (no DLQ, synchronous only, both functions); CKV_AWS_173 (no secrets in the environment); CKV_AWS_272 (code signing in M6); CKV_AWS_50 (no X-Ray endpoint); CKV_AWS_117 (the gateway is outside a VPC by design). | SI-4 | M3 |
| M3-7 | Azure data account skips: CKV_AZURE_206 (LRS), CKV_AZURE_33 (no queues), CKV2_AZURE_38 (no soft delete), CKV2_AZURE_41 (shared key off, so no SAS). CKV2_AZURE_33 and CKV2_AZURE_32: private endpoints live in the ephemeral stack. CKV2_AZURE_21: blob logging arrives in M5. | SC-28 | M3 |
| M3-8 | Flow log storage account: Microsoft managed keys, shared key at the default, public network on with default Deny and only the trusted service bypass, 7 day retention (CKV2_AZURE_1, CKV2_AZURE_40, CKV_AZURE_59, CKV_AZURE_12, plus CKV_AZURE_33, CKV_AZURE_206, CKV2_AZURE_38, CKV2_AZURE_41). | AU-9 | M3 |
| M3-9 | Concurrency cap of 5 comes from the workload account's Lambda limit (5), not reserved concurrency, which AWS refuses below 10 unreserved. Each request uses 2 (app and gateway). If AWS raises the limit, set `reserved_concurrency = 5` in envs/ephemeral. | SC-5 | M3 |
| M3-10 | Bedrock model access refused by AWS for both accounts (support case denied, 2026-10). Model moved to the Gemini API behind `meridian-ai-gateway`. | SA-9, AC-20 | M3 |
| M3-11 | The Gemini API key is a static credential. It is in Secrets Manager under `alias/meridian-secrets`; only the gateway reads it, and Engineer can write but not read it. Rotation is manual (CKV2_AWS_57 skip). | IA-5 | M3 |
| M3-12 | Free tier: Google may use prompts to improve its products. All data is synthetic. | AC-20, SA-9 | M3 |
| M3-13 | The gateway has unrestricted internet egress; only its code pins the host. | SC-7 | M3 |
| M3-14 | Model calls are not in CloudTrail. The gateway logs `model_call` (model, finish reason, tokens); Google's usage page is the provider side. | AU-2 | M3 |
| M3-15 | Google spend is outside the AWS budget. The free tier is $0; if billing is ever linked, set a Google Cloud budget alert. | SA-9 | M3 |
| M3-16 | The storage CMK's rotation policy is under `ignore_changes`: Azure echoes action types capitalised and the azapi schema accepts only lowercase, so it would drift on every plan. A policy edit in code is not applied; change it with `az keyvault key rotation-policy update`. | SC-12 | M3 |
| M3-17 | With the lambda endpoint gone the app fails slow: the 5 s connect timeout is per attempt, so it runs to its 120 s Lambda timeout, and the CLI's 60 s read timeout re-invokes it (duplicate billed runs). Bound the gateway call's total time in `app/handler.py`. | SC-5 | M3 |
| M4-1 | Run C residual success: direct 1/6, indirect 1/6, extraction 1/6 (3/30 total; coercion 0/6 and link 0/6). Prompt Shields did not stop every attack, and the model's own filters are on in every run. Scoring is by canary only; the CSVs keep every answer. | SI-10 | M4 |
| M4-2 | Runs B and C were redone on 2026-11-08. The first runs were invalid: run B never had STAGE set to B, run C hit a gateway KeyError on documents-only Prompt Shields calls (19/30 errors), and `scoped_tools` was never applied, so the coercion denial was not real. The gateway was fixed and tested, and the evidence recaptured with STAGE read back before each run. | SI-10, CM-3 | M4 |
| M4-3 | False positive: Prompt Shields flagged the legitimate income-limit policy doc as a document attack on all three `search_policies` calls (`guardrail_intervened`, category `document_attack`, stage `tool:search_policies`). The benign question q1 got no answer (`SI-10-benign-ok.txt`). The benign case-summary question q2 worked, with SSN, phone and email redacted. Not tuned this session. | SI-10 | M4 |
| M4-4 | Bedrock Guardrails were unavailable. The guard layer is Azure Content Safety through the gateway, with no grounding or relevance check and no denied topics. The model's tool-call arguments are not checked; IAM scoping is the control there. | SI-10, SI-15 | M4 |
| M4-5 | Tool output goes through Prompt Shields as a document. Indirect injection that does not read as an attack still reaches the model. In the `sh-bad` test the user prompt was not flagged either. | SI-10, SI-3 | M4 |
| M4-6 | PII redaction is regex for the synthetic formats (SSN, 555 phones, email), not a managed detector. No false negatives were seen in q2; the q1 failure is not a PII issue. | SI-15 | M4 |
| M4-7 | T-04: document search is not entitlement scoped; every caseworker can retrieve every doc. | AC-24 | M4 |
| M4-8 | Gemini's built-in safety filters are on in every run, so run A measures Gemini alone, not an unprotected model. | SI-10 | M4 |
| M4-9 | Content Safety is reached over its public endpoint; keyless is the control (CKV_AZURE_134, CKV_AZURE_247). CKV2_AZURE_22: no customer managed key on the free tier. | SC-7, SC-28 | M4 |
| M4-10 | CKV_AZURE_249 skip: the check assumes a GitHub issuer. The federated credential trusts one AWS issuer and one role ARN. | IA-5 | M4 |
| M4-11 | AWS outbound identity federation was turned on by hand (`scripts/outbound-federation.ps1`), not in Terraform. The gateway's `sts:GetWebIdentityToken` has no audience condition yet. | CM-2, AC-6 | M4 |
| M4-12 | Content Safety F0 rate limits and monthly caps. A throttle past the retries refuses the request (fail closed), which shows as an error in a run, not a pass. Model rate limits (HTTP 429) also cost requests in run A (3/30 lost). | SC-5 | M4 |
| M5-1 | The Sentinel connector role, queues and notifications were made by Microsoft's script, not Terraform; the log archive bucket policy statement for it is in `trail.tf`, narrowed to two prefixes. | AC-20, CM-2 | M5 |
| M5-2 | Detection lag is 6 to 30 minutes (R1 6, R2 30) because of S3 delivery plus the 5 minute schedule. There is no real-time path. | AU-6, SI-4 | M5 |
| M5-3 | R3 is a CloudWatch alarm on `guardrail_intervened`, not a Sentinel rule: the S3 connector does not ingest Lambda logs. The alarm has no notification action. | SI-4 | M5 |
| M5-4 | R1 matches denied calls only (the region SCP's denial); a successful call in an unapproved region by an exempt service would not alert. Before this filter it made 187 incidents from AWS service activity in us-east-2. | SI-4 | M5 |
| M5-5 | R1 and R2 suppress for 1 hour after firing, so a second distinct event inside the hour is not a new incident. R2 also matches any denied `GetSecretValue`, which is fine with one secret. | SI-4 | M5 |
| M5-6 | R2 sees key reads, not model use. Model calls are logged only by the gateway (`model_call` lines in CloudWatch), which Sentinel does not ingest. | AU-2, SI-4 | M5 |
| M5-7 | Detection skips: CKV2_AWS_3 (no GuardDuty org admin), CKV2_AWS_48 and CKV2_AWS_45 (Config records eight lab types only, by design). | SI-4, CM-8 | M5 |
| M5-8 | The diagnostic settings DeployIfNotExists switch was never built; M2 has no diagnostic settings policy. The Activity log goes to the workspace directly. | AU-2, CA-7 | M5 |
| M5-9 | Sentinel onboarding writes the SecurityInsights solution without tags, which the tag deny refuses. Terraform tags it, and a policy exemption waives the tag rules on that one resource. | CM-6 | M5 |
| M5-10 | The M3 line on alerting for `PutKeyPolicy` (M3-3) stays open. No rule was built for it. | SC-12 | M5 |
| M5-11 | AU-5 (audit failure response) has no build step: no trail delivery failure alarm. Status stays planned. | AU-5 | M5 |
| M5-12 | `terraform plan` in the workload stack always shows two GuardDuty feature changes (RDS_LOGIN_EVENTS, RUNTIME_MONITORING): AWS returns extra DISABLED settings the code does not declare. No security effect. | CM-3 | M5 |
| M3-18 | The Key Vault public-network denial could not be shown cleanly: `az keyvault key list` from the laptop is refused by RBAC (`ForbiddenByRbac`), because the caller has no data-plane role, so the network layer is not what answers. Proof is the vault config (`publicNetwork: Disabled`) and the Approved private endpoint. Granting a read role would make the network denial show. | SC-7 | M3 |
