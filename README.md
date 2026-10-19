# Cloud-Native AI Application Threat Model

Threat model and control plan for a cross-cloud AI assistant: AWS (Bedrock + Guardrails, tool roles over S3 docs and DynamoDB case records) fronted by Azure (Entra ID, API Management, AI Content Safety), deployed from GitHub Actions via OIDC + Terraform, monitored by Sentinel.

## Source of truth

| What | Where |
|---|---|
| Architecture + data flows (F1–F18, B1–B9), v1 | `CloudSecurityProj.png` |
| Threat register T-01–T-35, v1 | `docs/threat-model-v1.docx` |
| Controls (NIST 800-53 moderate), status, milestone, threats, evidence | `compliance/controls.yaml` |
| Control summary | `compliance/CIS.md`, generated, never hand-edit |

Edit `controls.yaml`, then `./make.ps1 render`. Render fails if a control is `implemented` without an existing evidence file.

## Milestones

| | Focus | Controls |
|---|---|---|
| M0 | Threat model | PL-8, RA-3, SA-8 |
| M1 | Identity and access | AC-2/3/6/17, IA-2/5/8, AU-2, CM-5 |
| M2 | Configuration baseline | CM-2/6/7/8, AC-7 |
| M3 | Network and crypto | AC-4, IA-3, SC-5/7/8/12/13/23/28 |
| M4 | AI input/output guardrails | SI-3/10/11/12/15, AC-24, SC-18/24 |
| M5 | Logging, detection, response | AU-3/5/6/9/10/11/12, CM-3, IR-4/5, SI-4, AC-20 |
| M6 | Assessment and supply chain | CA-2/5/7, RA-5, SA-11, SR-4/11, SI-7 |

## Commands

```powershell
./make.ps1 render    # controls.yaml -> compliance/CIS.md
./make.ps1 evidence  # dist/evidence-pack.zip
./make.ps1 clean
```
