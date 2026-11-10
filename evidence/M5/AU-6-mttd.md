# MTTD (AU-6)

Times are UTC. Simulation times are the event times in the Sentinel `AWSCloudTrail` table
(R1, R2) and the first guard intervention in CloudWatch (R3). Incident times are `CreatedTime`
in `SecurityIncident`. The R1 incident's `FirstActivityTime` is the start of its 1 hour
lookback, not the event time, so it is not used.

| Rule | Simulation | Incident or alarm | MTTD |
| --- | --- | --- | --- |
| R1 unapproved region | 2026-11-10 01:23:43 (denied `CreateBucket`, eu-central-1) | incident 196, 01:29:43 | 6 min 0 s |
| R2 model key read | 2026-11-09 05:32:28 (Engineer, denied `GetSecretValue`) | incident 11, 06:02:30 | 30 min 2 s |
| R2 model key read, rerun | 2026-11-10 01:33:51 (demo step 5) | incident 197, 01:43:54 | 10 min 3 s |
| R3 injection spike | 2026-11-10 01:24:55 (7 guard interventions in 17 s) | alarm `ALARM`, 01:26:35 | 1 min 40 s |

R1 and R2 take the S3 delivery path (CloudTrail to S3 to the Sentinel connector, then a 5 minute rule schedule), so they ranged from 6 to 30 minutes over three runs; the runbook expected 5 to 20. R3 is a CloudWatch alarm on the app's own logs, so it has no S3 delay and fires in about two minutes.

R1 was rerun on 2026-11-10 after its rule was changed to match denied calls only and to suppress for 1 hour. Before that it made 187 incidents from AWS service activity in us-east-2, so its first run could not be timed. R2's 8 incidents from one event were also before suppression.
