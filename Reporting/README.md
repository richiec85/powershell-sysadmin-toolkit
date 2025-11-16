# Reporting & Auditing Scripts

PowerShell scripts for generating reports and auditing across all platforms.

## 📁 Directory Structure

- **Users/** - User activity and account reports
- **Licenses/** - License usage and compliance reports
- **Security/** - Security auditing and compliance
- **Compliance/** - Regulatory compliance reports
- **Resources/** - Resource utilization and inventory

## 🔧 Report Types

### User Reports
- Active/inactive user accounts
- Last logon reports
- User creation audit
- Password expiration reports
- MFA enrollment status

### License Reports
- License assignment by user
- Available vs. assigned licenses
- Cost per user/department
- License type distribution

### Security Reports
- Admin role assignments
- Privileged access review
- Sign-in logs and anomalies
- Conditional access policy compliance
- Guest user access review

### Compliance Reports
- Data retention compliance
- Access certification
- Audit log exports
- Policy violation reports

### Resource Reports
- Azure resource inventory
- VM utilization reports
- Storage capacity reports
- Cost by resource/tag
- Unused or orphaned resources

## Output Formats

Scripts support multiple output formats:
- CSV for Excel analysis
- HTML for email reports
- JSON for integration
- PDF for executive summaries

## Scheduling Reports

```powershell
# Create scheduled task for daily reports
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-File C:\Scripts\DailyReport.ps1'
$trigger = New-ScheduledTaskTrigger -Daily -At 6am
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "DailyUserReport"
```

## Best Practices

- Archive old reports regularly
- Protect sensitive report data
- Automate report distribution
- Version control report queries
- Include timestamp in filenames
