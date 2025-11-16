# Entra ID (Azure AD) Scripts

PowerShell scripts for managing Microsoft Entra ID (formerly Azure Active Directory).

## 📁 Directory Structure

- **Users/** - User and guest account management
- **Groups/** - Group creation and membership
- **Licenses/** - License assignment and management
- **ConditionalAccess/** - Conditional access policy management
- **Applications/** - App registrations and enterprise apps
- **MFA/** - Multi-factor authentication configuration

## 🔧 Common Operations

### User Management
- User provisioning and deprovisioning
- Guest user management
- Bulk operations from CSV
- User attribute updates

### License Management
- License assignment and removal
- Available license reporting
- Bulk license operations

### Security
- MFA status reporting and enforcement
- Conditional access policy creation
- Sign-in log analysis
- Risky user detection

## Prerequisites

```powershell
# Install required modules
Install-Module -Name AzureAD
Install-Module -Name Microsoft.Graph

# Connect to Entra ID
Connect-AzureAD
# OR
Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All"
```

## Important Notes

- Microsoft Graph is the preferred API (AzureAD module is deprecated)
- Ensure proper admin roles and permissions
- Be cautious with bulk operations
- Always use -WhatIf when available
