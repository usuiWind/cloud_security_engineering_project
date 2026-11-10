# Control Implementation Summary

| ID | Title | Status | Milestone | Evidence |
|---|---|---|---|---|
| PL-8 | Security and Privacy Architectures | partial | M0 | docs/threat-model-v1.docx |
| RA-3 | Risk Assessment | partial | M0 | docs/threat-model-v1.docx |
| SA-8 | Security and Privacy Engineering Principles | partial | M0 | docs/threat-model-v1.docx |
| AC-2 | Account Management | implemented | M1 | evidence/M1/AC-2-permission-sets.txt |
| AC-3 | Access Enforcement | implemented | M1 | evidence/M1/AC-3-oidc-pr-denied.txt |
| AC-6 | Least Privilege | partial | M1 | evidence/M1/AC-6-deploy-role-after.txt |
| AC-17 | Remote Access | implemented | M1 | evidence/M1/AC-17-mfa-required.png |
| IA-2 | Identification and Authentication of Organizational Users | implemented | M1 | evidence/M1/AC-17-mfa-required.png |
| IA-5 | Authenticator Management | implemented | M1 | evidence/M1/IA-5-key-scan-workload.txt |
| IA-8 | Identification and Authentication of Non Organizational Users | implemented | M1 | evidence/M1/IA-8-oidc-main-success.txt |
| AU-2 | Event Logging | implemented | M1 | evidence/M1/AU-2-org-trail.txt |
| CM-5 | Access Restrictions for Change | partial | M1 | evidence/M1/AC-3-oidc-pr-denied.txt |
| CM-2 | Baseline Configuration | implemented | M2 | evidence/M2/CM-2-effective-policies.txt |
| CM-6 | Configuration Settings | implemented | M2 | evidence/M2/CM-6-checkov-blocked.txt |
| CM-7 | Least Functionality | implemented | M2 | evidence/M2/CM-7-aws-region-denied.txt |
| CM-8 | System Component Inventory | implemented | M2 | evidence/M2/CM-8-aws-untagged-denied.txt |
| AC-7 | Unsuccessful Logon Attempts | implemented | M2 | evidence/M2/AC-7-entra-lockout.png |
| AC-4 | Information Flow Enforcement | implemented | M3 | evidence/M3/AC-4-endpoint-policy-deny.txt |
| IA-3 | Device Identification and Authentication | partial | M3 | evidence/M3/IA-3-lambda-resource-policy.txt |
| SC-5 | Denial of Service Protection | implemented | M3 | evidence/M3/SC-5-lambda-limits.txt |
| SC-7 | Boundary Protection | implemented | M3 | evidence/M3/SC-7-no-path-without-endpoint.txt |
| SC-8 | Transmission Confidentiality and Integrity | implemented | M3 | evidence/M3/SC-8-gateway-via-vpce.txt |
| SC-12 | Cryptographic Key Establishment and Management | implemented | M3 | evidence/M3/SC-12-key-config.txt |
| SC-13 | Cryptographic Protection | implemented | M3 | evidence/M3/SC-12-key-config.txt |
| SC-28 | Protection of Information at Rest | implemented | M3 | evidence/M3/SC-28-kms-denied.txt |
| SC-23 | Session Authenticity | planned | M3 |  |
| SI-10 | Information Input Validation | implemented | M4 | evidence/M4/SI-10-results-summary.md |
| SI-11 | Error Handling | implemented | M4 | evidence/M4/SI-11-error-response.txt |
| SI-15 | Information Output Filtering | implemented | M4 | evidence/M4/SI-15-guard-config.txt |
| AC-24 | Access Control Decisions | implemented | M4 | evidence/M4/AC-6-tool-coercion-denied.txt |
| SC-18 | Mobile Code | implemented | M4 | evidence/M4/run-C-full.csv |
| SC-24 | Fail in Known State | implemented | M4 | evidence/M4/SC-24-guardrail-fail-closed.txt |
| SI-3 | Malicious Code Protection | implemented | M4 | evidence/M4/SI-3-shields-in-path.txt |
| SI-12 | Information Management and Retention | implemented | M4 | evidence/M4/SI-15-guard-config.txt |
| AU-3 | Content of Audit Records | implemented | M5 | evidence/M5/AU-3-guardrail-signal.txt |
| AU-5 | Response to Audit Logging Process Failures | planned | M5 |  |
| AU-6 | Audit Record Review Analysis and Reporting | implemented | M5 | evidence/M5/AU-6-mttd.md |
| AU-9 | Protection of Audit Information | implemented | M5 | evidence/M5/AU-9-protected-services-denied.txt |
| AU-10 | Non Repudiation | implemented | M5 | evidence/M5/AU-10-validate-logs.txt |
| AU-11 | Audit Record Retention | implemented | M5 | evidence/M5/AU-11-log-retention.txt |
| AU-12 | Audit Record Generation | implemented | M5 | evidence/M5/AU-12-aws-in-sentinel.txt |
| CM-3 | Configuration Change Control | implemented | M5 | evidence/M2/CM-6-checkov-blocked.txt |
| IR-4 | Incident Handling | implemented | M5 | detections/runbooks/R1.md |
| IR-5 | Incident Monitoring | implemented | M5 | evidence/M5/SI-4-R1-incident.png |
| SI-4 | System Monitoring | implemented | M5 | evidence/M5/SI-4-incidents.txt |
| AC-20 | Use of External Systems | implemented | M5 | evidence/M5/AC-20-sentinel-role.txt |
| CA-2 | Control Assessments | planned | M6 | evidence/M6/RA-5-prowler-after |
| CA-5 | Plan of Action and Milestones | planned | M6 | compliance/poam.md |
| CA-7 | Continuous Monitoring | planned | M6 | evidence/M6/CA-7-azure-compliance.txt |
| RA-5 | Vulnerability Monitoring and Scanning | planned | M6 | evidence/M6/RA-5-prowler-after |
| SA-11 | Developer Testing and Evaluation | planned | M6 | evidence/M6/SA-11-ci-security-tests.txt |
| SR-4 | Provenance | planned | M6 | evidence/M6/SR-4-sbom.spdx.json |
| SR-11 | Component Authenticity | planned | M6 | evidence/M6/SR-11-unsigned-deploy-denied.txt |
| SI-7 | Software Firmware and Information Integrity | planned | M6 | evidence/M6/SR-11-unsigned-deploy-denied.txt |

## Coverage by milestone

| Milestone | Implemented | Cumulative |
|---|---|---|
| M0 | 0 | 0 |
| M1 | 7 | 7 |
| M2 | 5 | 12 |
| M3 | 7 | 19 |
| M4 | 8 | 27 |
| M5 | 11 | 38 |
| M6 | 0 | 38 |
