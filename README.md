# PowerShell System Administrator Toolkit

A comprehensive collection of PowerShell scripts for Windows system administrators managing Active Directory, Entra ID (Azure AD), Azure, and Windows infrastructure.

## 📁 Repository Structure

```
powershell-sysadmin-toolkit/
├── ActiveDirectory/          # On-premises AD management scripts
├── EntraID/                   # Entra ID (Azure AD) management
├── Azure/                     # Azure resource management
├── Windows/                   # Windows OS and server management
├── Hybrid/                    # Hybrid cloud scenarios
├── Reporting/                 # Reporting and auditing scripts
├── Utilities/                 # Helper functions and utilities
└── Templates/                 # Script templates
```

## 🚀 Prerequisites

### Required PowerShell Modules

```powershell
# Install required modules
Install-Module -Name Az -AllowClobber -Scope CurrentUser
Install-Module -Name AzureAD -AllowClobber -Scope CurrentUser
Install-Module -Name Microsoft.Graph -AllowClobber -Scope CurrentUser
Install-Module -Name ExchangeOnlineManagement -AllowClobber -Scope CurrentUser
Install-Module -Name MSOnline -AllowClobber -Scope CurrentUser
```

### Active Directory Module
- Requires RSAT (Remote Server Administration Tools) on Windows 10/11
- Or run from Domain Controller/Management Server

## 📋 Script Categories

### Active Directory
- User management (creation, modification, bulk operations)
- Group management and membership
- Computer account management
- OU structure management
- Password policies and resets
- AD health checks

### Entra ID (Azure AD)
- User and guest management
- License assignment
- Conditional access policies
- Application management
- MFA status and configuration
- Directory synchronization

### Azure
- Resource group management
- VM operations
- Storage account management
- Network configuration
- Cost analysis
- Tag management

### Windows Management
- Service monitoring
- Event log analysis
- Patch management
- Performance monitoring
- Registry management
- Scheduled tasks

### Reporting
- User activity reports
- License usage reports
- Security auditing
- Compliance reporting
- Resource utilization

## 🔐 Security Best Practices

1. **Never hardcode credentials** - Use secure credential storage
2. **Use least privilege** - Run scripts with minimum required permissions
3. **Enable logging** - All scripts include transcript logging
4. **Test in non-production** - Always test scripts in a safe environment first
5. **Use -WhatIf** - Scripts support WhatIf parameter for dry runs

## 📖 Usage Examples

### Basic Usage
```powershell
# Import a script
. .\ActiveDirectory\New-ADUserBulk.ps1

# Run with parameters
New-ADUserBulk -CSVPath "users.csv" -WhatIf
```

### Authentication
```powershell
# Connect to Azure/Entra ID
Connect-AzAccount
Connect-AzureAD

# Connect to Exchange Online
Connect-ExchangeOnline -UserPrincipalName admin@domain.com
```

## 🤝 Contributing

1. Test all scripts thoroughly
2. Include proper error handling
3. Add comprehensive comments
4. Follow PowerShell best practices
5. Include help documentation

## ⚠️ Disclaimer

These scripts are provided as-is. Always review and test scripts before running in production environments. Ensure you have proper backups and recovery procedures in place.

## 📝 License

MIT License - See LICENSE file for details

## 🔗 Useful Resources

- [Microsoft PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)
- [Azure PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/azure/)
- [Microsoft Graph PowerShell](https://docs.microsoft.com/en-us/graph/powershell/get-started)
- [Active Directory PowerShell Module](https://docs.microsoft.com/en-us/powershell/module/activedirectory/)
