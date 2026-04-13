# On-Call and Disaster Recovery Notes

## Backup Strategy

### Frequency
- **Automated Backups**: Daily snapshots at midnight.
- **Manual Backups**: Before major deployments or schema changes.

### Retention
- **Daily Backups**: Retained for 7 days.
- **Weekly Backups**: Retained for 30 days.
- **Monthly Backups**: Retained for 1 year.

### Restore Procedure
1. Identify the backup snapshot from AWS RDS console or CLI.
2. Create a new DB instance from the snapshot.
3. Update application configuration to point to the restored DB.
4. Test connectivity and data integrity.
5. Switch traffic to the restored instance.
6. Monitor for 24 hours post-restore.

## DR Concept: CloudFront Origin Failover and State Considerations

### CloudFront Origin Failover
Use CloudFront origin groups for automatic failover between primary and secondary origins.

- **Primary Origin**: ALB in us-east-1.
- **Secondary Origin**: Static site in S3 with CloudFront Functions for basic API fallback.
- **Failover Trigger**: On 5xx errors or timeouts.

### State Considerations
- **Stateless Services**: ECS tasks are stateless; failover doesn't affect session state.
- **Stateful Elements**: If DB existed, use RDS read replicas or Aurora Global Database for cross-region failover.
- **DNS/Route53**: Use Route53 health checks to failover DNS to secondary region.
- **Testing**: Regularly test failover with synthetic canaries.
- **RTO/RPO**: Aim for RTO < 1 hour, RPO < 15 minutes (based on backup frequency).

## On-Call Runbook

### First 15-Minutes Checklist
1. **Acknowledge Alert**: Confirm via Teams/Slack/email.
2. **Assess Severity**: Check error rates, latency, user impact.
3. **Gather Context**: Review recent deploys, logs, metrics.
4. **Initial Triage**: Is it a code issue, infra failure or external dependency?
5. **Communicate**: Update incident channel with status.
6. **Escalate if Needed**: If unresolved in 15 min, page secondary on-call.

### Comms Template
**Incident Start:**
"Hey team, (Incident Description) at (Time). Impact: (User Impact). Investigating now. Updates every 15 min."

**Updates:**
"Update: (Findings). Next steps: (Actions). ETA: (Time)."

**Resolution:**
"Resolved: (Root Cause). Rollback/Deploy: (Details). Postmortem: (Link)."

### Rollback Steps
1. Identify last known good deploy (e.g., via GitHub releases or Terraform state).
2. Roll back ECS service to previous task definition.
3. If code change, revert commit and redeploy.
4. Monitor metrics for recovery.

### Postmortem Template
**Incident Summary:**
- **Date/Time**: (Details)
- **Duration**: (Time)
- **Impact**: (Users affected, business impact)
- **Root Cause**: (Analysis)
- **Timeline**:
  - (Time): Incident started
  - (Time): Detected
  - (Time): Resolved
- **Actions Taken**: (Steps)
- **Lessons Learned**: (Improvements)
- **Preventive Measures**: [Tasks to implement]