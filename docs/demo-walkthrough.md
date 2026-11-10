# Meridian demo walkthrough

**One line:** an AI assistant for benefits caseworkers, with tool access to real-shaped
constituent records, built so that the model is never the security boundary. Identity,
network and encryption controls decide what it can reach; classifiers and detection sit on top.

Script: `.\scripts\demo.ps1` (about 12 minutes). Every number below comes from a file in `evidence/`.

## Before you start (15 minutes ahead)

1. `aws sso login --sso-session meridian` and `az login`.
2. Stack up at stage C:
   `aws lambda get-function-configuration --function-name meridian-app --query Environment.Variables.STAGE --profile workload-engineer` prints `"C"`.
   If not, `terraform apply` in `envs\ephemeral` (about 5 minutes).
3. Open these tabs:
   - `CloudSecurityProj.png` (architecture)
   - Defender portal, Incidents: the newest *Meridian R1-region* and *Meridian R2-model-key-read*
   - CloudWatch (account ending 7641, N. Virginia), Alarms, `meridian-injection-spike`
   - `compliance/CIS.md`
4. Fallback if anything is down: the screenshots in `evidence/M5/` and the CSVs in `evidence/M4/`.

Step 6 makes a real key read attempt, so a new R2 incident appears 10 to 30 minutes later.
If you have time, run the demo once beforehand so a fresh one is waiting.

## Run of show

| Min | Step | Show |
| --- | --- | --- |
| 1 | The system | Architecture diagram |
| 1 | 1. It works | Live policy answer |
| 1 | 2. Own case, redacted | Live case summary |
| 3 | 3. Same attack, three configurations | Recorded A and B, then live C |
| 1 | 4. Scoreboard | 30 attacks x 3 runs |
| 2 | 5. Guard layer: what it stops, what it costs | Live injection blocked, live false positive |
| 1 | 6. Key theft | Live refusal, Sentinel incident tab |
| 2 | 7. Alarm | Live: narrate while it trips |
| 1 | 8. Paper trail | Control counts, CIS.md, POA&M |

## Talking points

### The system (architecture diagram)
- Two clouds. AWS runs the app; Azure provides the guard layer (Prompt Shields, Content Safety) and the SIEM (Sentinel).
- The app Lambda sits in a private subnet with **no internet route**. It reaches S3, DynamoDB and STS through VPC endpoints whose policies name the exact bucket, table and roles.
- The model (Gemini) is reached only through one gateway function, which holds the only read access to the API key.
- Each tool runs under its own IAM role, assumed per call. The case tool carries the caller as a session tag.

### 1. It works
- A normal question, answered from the policy corpus through the `search_policies` tool.
- The corpus bucket is encrypted with its own KMS key. Only the document tool role can decrypt, and only through S3.

### 2. Own case, redacted
- The case comes from DynamoDB under a second KMS key, usable only by the case tool role.
- SSN, phone and email are replaced on the way out: `[SSN]`, `[PHONE]`, `[EMAIL]`.

### 3. Same attack, three configurations (the centerpiece)
- cw-001 asks for cw-002's case. In run A, no guards: the model fetched it and leaked Synthetic Person 9's TANF case.
- Run B added Prompt Shields and Content Safety. **It still leaked.** "Show me case-3 for cw-002" isn't an attack to a text classifier; it's a polite question.
- Run C scoped the tool role: the case tool may only read rows whose partition key matches the caller's session tag. The model still tries, and DynamoDB refuses. The `tool_denied` line is IAM's answer, not the model's.
- **Point:** classifiers judge text; the role judges the key. Put the boundary where the data is.

### 4. Scoreboard
- 30 payloads in 5 categories, scored by canaries, run three times.
- Total attack success: **9/30, then 8/30, then 3/30**. Coercion: **4/6, then 3/6, then 0/6**. Link exfiltration and extraction also dropped.
- Runs were never rerun to get better numbers. B and C were redone once because the first attempts were misconfigured; that is recorded (POA&M M4-2).

### 5. The guard layer: what it stops, and what it costs
- A direct injection is stopped before the model sees it: `Blocked by Meridian policy.`
- The gateway signs in to Azure with **no stored secret**: AWS outbound identity federation issues a signed token, Entra trusts that issuer and the gateway role only, and Content Safety has local (key) auth disabled.
- The cost: Prompt Shields wrongly flags the legitimate income-limit document as an attack, so every search result is withheld and the assistant runs out of tool turns (`Tool limit reached`). It fails safe, but it fails. Recorded as M4-3.
- **Point:** every guard has a false positive rate. Measure it and write it down instead of tuning it away before a demo.

### 6. Key theft
- Only the gateway role can read the Gemini key. An engineer can store a new value but never read it back.
- The refusal is the secret's own resource policy: `explicit deny in a resource-based policy`.
- CloudTrail goes to an org-level archive, into Sentinel. Rule R2 fires on any key read that isn't the gateway, and the gateway's own reads are filtered out.
- Detection took 10 and 30 minutes on two runs: S3 delivery plus the 5 minute schedule.

### 7. Alarm
- Five or more guard interventions in 10 minutes put `meridian-injection-spike` into ALARM. Measured: 1 minute 40 seconds from the first attack.
- It's a CloudWatch alarm rather than a Sentinel rule because Sentinel's S3 connector doesn't ingest Lambda logs. Recorded, with "no notification action yet", as M5-3.
- While waiting: R1 catches any denied call in an unapproved region (6 minutes measured). Each rule has a runbook in `detections/runbooks/` with first checks and containment.

### 8. Paper trail
- 43 NIST 800-53 moderate controls in scope (M1 to M5): **38 implemented, 3 partial, 2 planned**, each with its threats and an evidence file. `make.ps1 render` fails if an implemented control has no evidence.
- Every shortcut is a POA&M line with its control: single AZ, the free-tier model, the gateway's open egress, the manual setup steps.
- Audit trail integrity: CloudTrail log validation, 73 of 73 files valid.

## Likely questions

**Why Gemini and not Bedrock?** AWS refused Bedrock model access for both accounts. The model sits behind a gateway Lambda, so the rest of the design didn't change. Recorded as M3-10.

**What still gets through in run C?** 3 of 30: one direct, one indirect, one system prompt extraction (P6 still reveals the canary). Each is a POA&M line (M4-1).

**Could a caseworker see another caseworker's case another way?** Not through the case tool: the key condition is evaluated by DynamoDB. Document search is not entitlement scoped yet; every caseworker can read every policy document (T-04, M4-7).

**How fast is detection?** 1 to 2 minutes for the app-log alarm, 6 to 30 minutes for CloudTrail-based rules. No real-time path (M5-2).

**What would production need?**
- Caller identity from the edge (APIM forwarding the Entra claim) instead of trusting `caller_id` (T-17).
- A NAT and firewall allow list for the gateway, instead of only pinning the host in code (M3-13).
- A paid model tier with a data processing agreement (M3-12).
- Multi-AZ, alert routing to a person, and code signing (M6, not built).

**What does it cost?** About $0.04 an hour while the network is up; about $3.40 a month for the keys and the secret at rest. Sentinel ingestion is capped at 1 GB a day. The model is on the free tier.

## Numbers cheat sheet

| What | Number | Evidence |
| --- | --- | --- |
| Attack success A / B / C | 9 / 8 / 3 of 30 | `evidence/M4/SI-10-results-summary.md` |
| Coercion A / B / C | 4 / 3 / 0 of 6 | same |
| MTTD R1 / R2 / R3 | 6 min / 10 and 30 min / 1 min 40 s | `evidence/M5/AU-6-mttd.md` |
| CloudTrail and flow records in Sentinel | 5,891 / 11,965 | `evidence/M5/AU-12-aws-in-sentinel.txt` |
| Log files validated | 73 / 73 | `evidence/M5/AU-10-validate-logs.txt` |
| Controls M1 to M5 | 38 implemented, 3 partial, 2 planned | `compliance/CIS.md` |

## After the demo

`terraform destroy` in `envs\ephemeral`. Then check that no VPC endpoints, Lambda ENIs or private endpoints remain (runbook 3.13).
