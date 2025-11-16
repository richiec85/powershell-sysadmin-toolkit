# Hybrid Cloud Management Scripts

PowerShell scripts for hybrid cloud scenarios combining on-premises and cloud resources.

## 📁 Directory Structure

- **Sync/** - Directory synchronization and Azure AD Connect
- **Migration/** - Workload migration scripts
- **Backup/** - Hybrid backup and recovery

## 🔧 Common Operations

### Directory Synchronization
- Azure AD Connect monitoring
- Sync troubleshooting
- Password hash sync verification
- Seamless SSO configuration

### Migration
- Mailbox migration to Exchange Online
- File server to SharePoint/OneDrive migration
- AD user to cloud-only conversion
- Hybrid identity setup

### Backup & Recovery
- Azure Backup configuration
- Hybrid backup reporting
- Recovery point management
- Disaster recovery testing

## Prerequisites

```powershell
# On-premises modules
Import-Module ActiveDirectory

# Cloud modules
Connect-AzAccount
Connect-ExchangeOnline
Connect-MgGraph

# Azure AD Connect (for sync operations)
Import-Module ADSync
```

## Common Scenarios

### Hybrid Exchange
- Mailbox moves (on-prem to cloud)
- Free/busy calendar sharing
- Mail flow configuration
- Hybrid configuration updates

### Hybrid Identity
- Password writeback
- Group writeback
- Device writeback
- Seamless Single Sign-On

## Important Notes

- Test migrations in pilot groups first
- Maintain hybrid configuration backup
- Monitor sync errors regularly
- Plan for coexistence period
