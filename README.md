# Meridian: a secure cloud-native AI assistant

From threat model to built, tested controls. Meridian is an AI assistant for benefits caseworkers with tool access to policy documents and synthetic constituent case records. It runs on AWS, reaches the model (Gemini) through a single gateway function, uses Azure for the guard layer (Prompt Shields, Content Safety) and the SIEM (Sentinel), and is deployed from GitHub Actions through OIDC and Terraform.

The design rule: **the model is never the security boundary.** Identity, network and encryption decide what it can reach; classifiers and detection sit on top.

![Architecture, as built](docs/architecture.drawio.png)

Editable source: `docs/architecture.drawio`. The design-time v1 diagram, with flows F1 to F18 and boundaries B1 to B9, is `docs/architecture-v1.png`.

## Results

- **Same attack, three configurations.** A caseworker asks for another caseworker's case. With no guards it leaked. With Prompt Shields and Content Safety on, it *still* leaked. With the tool role scoped to the caller's own partition key, DynamoDB refused it. Across 30 scored attacks: **9/30, 8/30, 3/30** (`evidence/M4/SI-10-results-summary.md`).
- **Detection.** Three rules, each fired and timed: R1 (unapproved region) 6 min, R2 (model key read) 10 to 30 min, R3 (injection spike) 1 min 40 s (`evidence/M5/AU-6-mttd.md`).
- **Controls.** NIST 800-53 moderate, milestones M1 to M5: 38 implemented, 3 partial, 2 planned. Every implemented control has an evidence file, and every shortcut is a POA&M line.

## Source of truth

| What | Where |
|---|---|
| Architecture, as built | `docs/architecture.drawio` (`.png` export) |
| Architecture, design-time v1 | `docs/architecture-v1.png` |
| Threat register T-01 to T-35, v1 | `docs/threat-model-v1.docx` |
| Controls: status, milestone, threats, evidence | `compliance/controls.yaml` |
| Control summary | `compliance/CIS.md`, generated, never hand-edit |
| Open risks and shortcuts | `compliance/poam.md` |
| Evidence | `evidence/M1` to `evidence/M5` |
| Detection rules, MTTD, runbooks | `detections/` |

Edit `controls.yaml`, then `./make.ps1 render`. Render fails if a control is `implemented` without an existing evidence file.

## Layout

| Path | What |
|---|---|
| `envs/persistent/org` | AWS Organization: SCPs, org trail, log archive |
| `envs/persistent/workload` | Workload account: KMS keys, corpus, cases, tool roles, gateway role, model key, detection |
| `envs/persistent/azure` | Azure: Entra, policy, Key Vault, storage, Content Safety, Sentinel rules |
| `envs/ephemeral` | The network and both functions: VPC, endpoints, Lambdas, Azure private endpoints. Destroyed when idle |
| `envs/app` | What the pipeline deploys (model id) |
| `app/` | `handler.py` (the assistant and its tools), `gateway.py` (the only path to the model) |
| `tests/` | Offline tests, the 30-payload attack harness, CloudTrail checks |
| `detections/` | KQL rules, MTTD, runbooks R1 to R3 |

## Milestones

| | Focus | Controls |
|---|---|---|
| M0 | Threat model (v1) | PL-8, RA-3, SA-8 |
| M1 | Identity and access | AC-2/3/6/17, IA-2/5/8, AU-2, CM-5 |
| M2 | Configuration baseline | CM-2/6/7/8, AC-7 |
| M3 | Network and crypto | AC-4, IA-3, SC-5/7/8/12/13/23/28 |
| M4 | AI input and output guardrails | SI-3/10/11/12/15, AC-24, SC-18/24 |
| M5 | Logging, detection, response | AU-3/5/6/9/10/11/12, CM-3, IR-4/5, SI-4, AC-20 |
| M6 | Assessment and supply chain | Out of scope, not built |

## Not built

- **An API front door** (API Management with the caller's Entra identity). The assistant trusts the `caller_id` it is invoked with (T-17, POA&M).
- **Bedrock and Azure OpenAI.** AWS refused Bedrock model access, so the model is Gemini behind the gateway.
- **M6:** Prowler scans, SBOM, code signing, the assessment review.
- **Automated response.** Containment is manual, from the runbooks.
- **Threat model v2 and v3.** The v1 register stays the reference for each control's `threats`.

## Demo

With the ephemeral stack up (stage C) and `aws sso login --sso-session meridian`:

```powershell
.\scripts\demo.ps1              # about 12 minutes, pauses between steps
.\scripts\demo.ps1 -SkipAlarm   # without the 2 minute alarm step
```

Walkthrough and talking points: `docs/demo-walkthrough.md`.

## Commands

```powershell
./make.ps1 render    # controls.yaml -> compliance/CIS.md
./make.ps1 evidence  # dist/evidence-pack.zip
./make.ps1 clean
```
